import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/core/utils/voice_recording_storage.dart';
import 'package:murmur/models/voice_recording_entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceOption {
  const VoiceOption({
    required this.id,
    required this.name,
    this.assetPath,
    this.filePath,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String? assetPath;
  final String? filePath;
  final bool isCustom;
}

enum MicrophonePermissionStatus {
  granted,
  denied,
}

class VoiceService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final AudioRecorder _recorder = AudioRecorder();
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsReady = false;
  static String? _activeRecordingPath;
  static final StreamController<void> _recordingsChangedController =
      StreamController<void>.broadcast();

  static Stream<void> get onRecordingsChanged =>
      _recordingsChangedController.stream;

  static void notifyRecordingsChanged() {
    if (!_recordingsChangedController.isClosed) {
      _recordingsChangedController.add(null);
    }
  }

  static const List<VoiceOption> presetVoices = <VoiceOption>[
    VoiceOption(id: 'default', name: 'Default Voice'),
    VoiceOption(id: 'warm_female', name: 'Warm Female Voice'),
    VoiceOption(id: 'calm_male', name: 'Calm Male Voice'),
  ];

  static String get defaultVoiceId => AppSettingsStorage.defaultVoiceId;

  static Future<void> bootstrap() async {
    final Directory voiceRoot = await voiceRootDir();
    await VoiceRecordingStorage.migrateLegacyRecordings(voiceRoot);
  }

  static Future<void> setDefaultVoice(String voiceId) async {
    await AppSettingsStorage.setDefaultVoiceId(voiceId);
  }

  static Future<Directory> voiceRootDir() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory voiceDir = Directory('${dir.path}/voices');
    if (!voiceDir.existsSync()) {
      await voiceDir.create(recursive: true);
    }
    return voiceDir;
  }

  static Future<MicrophonePermissionStatus> ensureRecordingPermission() async {
    if (await _recorder.hasPermission(request: false)) {
      return MicrophonePermissionStatus.granted;
    }
    final bool granted = await _recorder.hasPermission(request: true);
    if (granted) {
      return MicrophonePermissionStatus.granted;
    }
    return MicrophonePermissionStatus.denied;
  }

  static Future<String> startRecording() async {
    final MicrophonePermissionStatus status = await ensureRecordingPermission();
    if (status != MicrophonePermissionStatus.granted) {
      throw StateError('Microphone permission denied');
    }
    final Directory voiceRoot = await voiceRootDir();
    final Directory tempDir = await VoiceRecordingStorage.tempDir(voiceRoot);
    final String path =
        '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _activeRecordingPath = path;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      path: path,
    );
    return path;
  }

  static Future<String?> stopRecording() async {
    final String? stoppedPath = await _recorder.stop();
    String? result = stoppedPath;
    if (result == null || result.isEmpty) {
      result = _activeRecordingPath;
    }
    _activeRecordingPath = null;
    if (result != null && result.isNotEmpty && File(result).existsSync()) {
      await VoiceRecordingStorage.registerTempRecording(result);
      notifyRecordingsChanged();
    }
    return result;
  }

  static Future<void> _ensureTts() async {
    if (_ttsReady) {
      return;
    }
    await _tts.setLanguage('zh-CN');
    await _tts.awaitSpeakCompletion(true);
    _ttsReady = true;
  }

  static Future<void> _applyPresetVoice(String? voiceId) async {
    switch (voiceId) {
      case 'warm_female':
        await _tts.setPitch(1.1);
        await _tts.setSpeechRate(0.45);
        return;
      case 'calm_male':
        await _tts.setPitch(0.85);
        await _tts.setSpeechRate(0.42);
        return;
      default:
        await _tts.setPitch(1.0);
        await _tts.setSpeechRate(0.45);
    }
  }

  static Future<void> _playPresetVoice({
    required String? voiceId,
    required String text,
  }) async {
    await _ensureTts();
    await _audioPlayer.stop();
    await _applyPresetVoice(voiceId);
    await _tts.speak(text);
  }

  static Future<void> play({
    String? voicePath,
    String? voiceId,
    String? text,
  }) async {
    if (voicePath != null && voicePath.isNotEmpty && File(voicePath).existsSync()) {
      await _tts.stop();
      await _audioPlayer.play(DeviceFileSource(voicePath));
      return;
    }

    final String speech = text?.trim() ?? '';
    if (speech.isNotEmpty) {
      await _playPresetVoice(voiceId: voiceId, text: speech);
    }
  }

  static Future<void> stop() async {
    await _audioPlayer.stop();
    await _tts.stop();
  }

  static Stream<void> get onPlaybackComplete =>
      _audioPlayer.onPlayerComplete.map((_) {});

  static Future<List<VoiceRecordingEntry>> loadTemporaryRecordings() async {
    final Directory voiceRoot = await voiceRootDir();
    return VoiceRecordingStorage.loadTemporaryRecordings(voiceRoot);
  }

  static Future<List<VoiceRecordingEntry>> loadSavedRecordings() async {
    final Directory voiceRoot = await voiceRootDir();
    return VoiceRecordingStorage.loadSavedRecordings(voiceRoot);
  }

  static Future<VoiceRecordingEntry> saveRecordingToLibrary({
    required String tempPath,
    required String displayName,
  }) async {
    final Directory voiceRoot = await voiceRootDir();
    final VoiceRecordingEntry entry = await VoiceRecordingStorage.saveRecording(
      voiceRoot: voiceRoot,
      tempPath: tempPath,
      displayName: displayName,
    );
    notifyRecordingsChanged();
    return entry;
  }

  static Future<VoiceRecordingEntry> removeRecordingFromLibrary({
    required String savedPath,
  }) async {
    final Directory voiceRoot = await voiceRootDir();
    final VoiceRecordingEntry entry = await VoiceRecordingStorage.unsaveRecording(
      voiceRoot: voiceRoot,
      savedPath: savedPath,
    );
    notifyRecordingsChanged();
    return entry;
  }

  static Future<VoiceRecordingEntry> renameRecording({
    required String filePath,
    required String displayName,
  }) async {
    final VoiceRecordingEntry entry = await VoiceRecordingStorage.renameRecording(
      filePath: filePath,
      displayName: displayName,
    );
    notifyRecordingsChanged();
    return entry;
  }

  static Future<void> deleteRecording(String filePath) async {
    await VoiceRecordingStorage.deleteRecording(filePath);
    notifyRecordingsChanged();
  }

  static Future<void> purgeExpiredRecordings(Set<String> protectedPaths) async {
    final Directory voiceRoot = await voiceRootDir();
    await VoiceRecordingStorage.purgeExpiredRecordings(
      voiceRoot: voiceRoot,
      protectedPaths: protectedPaths,
    );
    notifyRecordingsChanged();
  }

  static Future<List<VoiceOption>> loadRecordings() async {
    final Directory voiceRoot = await voiceRootDir();
    final List<VoiceRecordingEntry> entries =
        await VoiceRecordingStorage.loadAllPlayableRecordings(voiceRoot);
    return entries
        .map(
          (VoiceRecordingEntry entry) => VoiceOption(
            id: entry.filePath,
            name: entry.displayName,
            filePath: entry.filePath,
            isCustom: true,
          ),
        )
        .toList();
  }
}
