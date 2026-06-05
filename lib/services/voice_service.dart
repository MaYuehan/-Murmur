import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
