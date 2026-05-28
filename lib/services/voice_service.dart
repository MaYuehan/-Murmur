import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
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

class VoiceService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final AudioRecorder _recorder = AudioRecorder();

  static const List<VoiceOption> presetVoices = <VoiceOption>[
    VoiceOption(id: 'default', name: 'Default Voice'),
    VoiceOption(id: 'warm_female', name: 'Warm Female Voice'),
    VoiceOption(id: 'calm_male', name: 'Calm Male Voice'),
  ];
  static String _defaultVoiceId = 'default';

  static String get defaultVoiceId => _defaultVoiceId;

  static void setDefaultVoice(String voiceId) {
    _defaultVoiceId = voiceId;
  }

  static Future<Directory> _voiceDir() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final Directory voiceDir = Directory('${dir.path}/voices');
    if (!voiceDir.existsSync()) {
      await voiceDir.create(recursive: true);
    }
    return voiceDir;
  }

  static Future<String> startRecording() async {
    final bool hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }
    final Directory voiceDir = await _voiceDir();
    final String path =
        '${voiceDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    return _recorder.stop();
  }

  static Future<void> play({
    String? voicePath,
    String? voiceId,
  }) async {
    if (voicePath != null && voicePath.isNotEmpty) {
      await _audioPlayer.play(DeviceFileSource(voicePath));
      return;
    }

    // Preset playback placeholder: keep behavior stable without bundled assets yet.
    // ignore: avoid_print
    print('Playing preset voice: ${voiceId ?? 'default'}');
  }

  static Future<void> stop() async {
    await _audioPlayer.stop();
  }

  static Future<List<VoiceOption>> loadRecordings() async {
    final Directory dir = await _voiceDir();
    final List<FileSystemEntity> entities = dir.listSync();
    final List<File> files = entities.whereType<File>().toList()
      ..sort((File a, File b) => b.path.compareTo(a.path));

    return files.map((File file) {
      final String fileName = file.path.split('/').last;
      return VoiceOption(
        id: file.path,
        name: fileName,
        filePath: file.path,
        isCustom: true,
      );
    }).toList();
  }
}
