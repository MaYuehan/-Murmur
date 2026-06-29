import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:murmur/models/voice_recording_entry.dart';

class VoiceRecordingStorage {
  VoiceRecordingStorage._();

  static const String _boxName = 'app_settings_box';
  static const String _metaKey = 'voice_recording_meta';
  static const int retentionDays = 7;

  static Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  static Future<Directory> tempDir(Directory voiceRoot) async {
    final Directory dir = Directory('${voiceRoot.path}/temp');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> savedDir(Directory voiceRoot) async {
    final Directory dir = Directory('${voiceRoot.path}/saved');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Map<String, dynamic> _loadMetaMap() {
    final dynamic raw = _box.get(_metaKey);
    if (raw is! Map) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(raw);
  }

  static Map<String, dynamic>? _metaEntryForPath(
    Map<String, dynamic> meta,
    String path,
  ) {
    final dynamic raw = meta[path];
    if (raw is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(raw);
  }

  static Future<void> _saveMetaMap(Map<String, dynamic> meta) async {
    await _box.put(_metaKey, meta);
  }

  static VoiceRecordingEntry? _entryFromMeta(String filePath, Map<String, dynamic> raw) {
    final String? createdAtRaw = raw['createdAt'] as String?;
    if (createdAtRaw == null) {
      return null;
    }
    final String? savedName = raw['savedName'] as String?;
    return VoiceRecordingEntry(
      filePath: filePath,
      createdAt: DateTime.parse(createdAtRaw),
      savedName: savedName?.trim().isEmpty == true ? null : savedName,
      isSaved: raw['isSaved'] as bool? ?? savedName != null,
    );
  }

  static Future<void> migrateLegacyRecordings(Directory voiceRoot) async {
    final Directory temp = await tempDir(voiceRoot);
    final Map<String, dynamic> meta = _loadMetaMap();
    var changed = false;

    for (final FileSystemEntity entity in voiceRoot.listSync()) {
      if (entity is! File || !entity.path.endsWith('.m4a')) {
        continue;
      }
      if (entity.path.contains('/temp/') || entity.path.contains('/saved/')) {
        continue;
      }
      final String destPath = '${temp.path}/${entity.path.split('/').last}';
      await entity.rename(destPath);
      if (!meta.containsKey(destPath)) {
        meta[destPath] = <String, dynamic>{
          'createdAt': DateTime.now().toIso8601String(),
          'savedName': null,
          'isSaved': false,
        };
        changed = true;
      }
    }

    if (changed) {
      await _saveMetaMap(meta);
    }
  }

  static Future<void> registerTempRecording(String filePath) async {
    final Map<String, dynamic> meta = _loadMetaMap();
    meta[filePath] = <String, dynamic>{
      'createdAt': DateTime.now().toIso8601String(),
      'savedName': null,
      'isSaved': false,
    };
    await _saveMetaMap(meta);
  }

  static Future<VoiceRecordingEntry> saveRecording({
    required Directory voiceRoot,
    required String tempPath,
    required String displayName,
  }) async {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'cannot be empty');
    }
    final File source = File(tempPath);
    if (!source.existsSync()) {
      throw StateError('Recording file not found');
    }

    final Directory saved = await savedDir(voiceRoot);
    final String savedPath =
        '${saved.path}/saved_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await source.rename(savedPath);
    } on FileSystemException {
      await source.copy(savedPath);
      await source.delete();
    }

    final Map<String, dynamic> meta = _loadMetaMap();
    final Map<String, dynamic>? tempMeta = _metaEntryForPath(meta, tempPath);
    final DateTime createdAt = tempMeta?['createdAt'] != null
        ? DateTime.parse(tempMeta!['createdAt'] as String)
        : DateTime.now();

    meta.remove(tempPath);
    meta[savedPath] = <String, dynamic>{
      'createdAt': createdAt.toIso8601String(),
      'savedName': trimmed,
      'isSaved': true,
    };
    await _saveMetaMap(meta);

    return VoiceRecordingEntry(
      filePath: savedPath,
      createdAt: createdAt,
      savedName: trimmed,
      isSaved: true,
    );
  }

  static Future<VoiceRecordingEntry> unsaveRecording({
    required Directory voiceRoot,
    required String savedPath,
  }) async {
    final File source = File(savedPath);
    if (!source.existsSync()) {
      throw StateError('Recording file not found');
    }

    final Directory temp = await tempDir(voiceRoot);
    final String tempPath =
        '${temp.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await source.rename(tempPath);
    } on FileSystemException {
      await source.copy(tempPath);
      await source.delete();
    }

    final Map<String, dynamic> meta = _loadMetaMap();
    final Map<String, dynamic>? savedMeta = _metaEntryForPath(meta, savedPath);
    final DateTime createdAt = savedMeta?['createdAt'] != null
        ? DateTime.parse(savedMeta!['createdAt'] as String)
        : DateTime.now();
    final String? savedName = savedMeta?['savedName'] as String?;
    final String? displayName =
        savedName?.trim().isEmpty == true ? null : savedName?.trim();

    meta.remove(savedPath);
    meta[tempPath] = <String, dynamic>{
      'createdAt': createdAt.toIso8601String(),
      'savedName': displayName,
      'isSaved': false,
    };
    await _saveMetaMap(meta);

    return VoiceRecordingEntry(
      filePath: tempPath,
      createdAt: createdAt,
      savedName: displayName,
      isSaved: false,
    );
  }

  static Future<VoiceRecordingEntry> renameRecording({
    required String filePath,
    required String displayName,
  }) async {
    final String trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'cannot be empty');
    }
    if (!File(filePath).existsSync()) {
      throw StateError('Recording file not found');
    }

    final Map<String, dynamic> meta = _loadMetaMap();
    final Map<String, dynamic>? existing = _metaEntryForPath(meta, filePath);
    final DateTime createdAt = existing?['createdAt'] != null
        ? DateTime.parse(existing!['createdAt'] as String)
        : File(filePath).lastModifiedSync();
    final bool isSaved =
        existing?['isSaved'] as bool? ?? filePath.contains('/saved/');

    meta[filePath] = <String, dynamic>{
      'createdAt': createdAt.toIso8601String(),
      'savedName': trimmed,
      'isSaved': isSaved,
    };
    await _saveMetaMap(meta);

    return VoiceRecordingEntry(
      filePath: filePath,
      createdAt: createdAt,
      savedName: trimmed,
      isSaved: isSaved,
    );
  }

  static Future<void> deleteRecording(String filePath) async {
    final File file = File(filePath);
    if (file.existsSync()) {
      await file.delete();
    }
    final Map<String, dynamic> meta = _loadMetaMap();
    meta.remove(filePath);
    await _saveMetaMap(meta);
  }

  static VoiceRecordingEntry _entryForFile(
    File file,
    Map<String, dynamic> meta, {
    required bool savedOnly,
  }) {
    final Map<String, dynamic>? raw = _metaEntryForPath(meta, file.path);
    if (raw != null) {
      final VoiceRecordingEntry? entry = _entryFromMeta(file.path, raw);
      if (entry != null) {
        return entry;
      }
    }
    return VoiceRecordingEntry(
      filePath: file.path,
      createdAt: file.lastModifiedSync(),
      isSaved: savedOnly,
      savedName: savedOnly ? file.path.split('/').last.replaceAll('.m4a', '') : null,
    );
  }

  static Future<List<VoiceRecordingEntry>> loadTemporaryRecordings(
    Directory voiceRoot,
  ) async {
    final Directory temp = await tempDir(voiceRoot);
    if (!temp.existsSync()) {
      return <VoiceRecordingEntry>[];
    }
    final Map<String, dynamic> meta = _loadMetaMap();
    final List<File> files = temp
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.endsWith('.m4a'))
        .toList()
      ..sort((File a, File b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return files
        .map(
          (File file) => _entryForFile(file, meta, savedOnly: false),
        )
        .where((VoiceRecordingEntry entry) => !entry.isSaved && !entry.isExpired)
        .toList();
  }

  static Future<List<VoiceRecordingEntry>> loadSavedRecordings(
    Directory voiceRoot,
  ) async {
    final Directory saved = await savedDir(voiceRoot);
    if (!saved.existsSync()) {
      return <VoiceRecordingEntry>[];
    }
    final Map<String, dynamic> meta = _loadMetaMap();
    final List<File> files = saved
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.endsWith('.m4a'))
        .toList()
      ..sort((File a, File b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return files
        .map((File file) => _entryForFile(file, meta, savedOnly: true))
        .toList();
  }

  static Future<List<VoiceRecordingEntry>> loadAllPlayableRecordings(
    Directory voiceRoot,
  ) async {
    final List<VoiceRecordingEntry> saved = await loadSavedRecordings(voiceRoot);
    final List<VoiceRecordingEntry> temp = await loadTemporaryRecordings(voiceRoot);
    return <VoiceRecordingEntry>[...saved, ...temp];
  }

  static Future<void> purgeExpiredRecordings({
    required Directory voiceRoot,
    required Set<String> protectedPaths,
  }) async {
    final Directory temp = await tempDir(voiceRoot);
    if (!temp.existsSync()) {
      return;
    }

    final Map<String, dynamic> meta = _loadMetaMap();
    var changed = false;
    final DateTime now = DateTime.now();

    for (final FileSystemEntity entity in temp.listSync()) {
      if (entity is! File || !entity.path.endsWith('.m4a')) {
        continue;
      }
      if (protectedPaths.contains(entity.path)) {
        continue;
      }

      final Map<String, dynamic>? raw = _metaEntryForPath(meta, entity.path);
      if (raw?['isSaved'] == true) {
        continue;
      }

      final DateTime createdAt = raw?['createdAt'] != null
          ? DateTime.parse(raw!['createdAt'] as String)
          : entity.lastModifiedSync();
      if (now.difference(createdAt).inDays < retentionDays) {
        continue;
      }

      await entity.delete();
      meta.remove(entity.path);
      changed = true;
    }

    if (changed) {
      await _saveMetaMap(meta);
    }
  }
}
