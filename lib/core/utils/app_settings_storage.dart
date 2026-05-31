import 'package:hive_flutter/hive_flutter.dart';

class AppSettingsStorage {
  static const String _boxName = 'app_settings_box';
  static const String _voiceRemindMutedKey = 'voice_remind_muted';

  static Future<void> init() async {
    await Hive.openBox<bool>(_boxName);
  }

  static bool get voiceRemindMuted {
    final Box<bool> box = Hive.box<bool>(_boxName);
    return box.get(_voiceRemindMutedKey) ?? false;
  }

  static Future<void> setVoiceRemindMuted(bool value) async {
    final Box<bool> box = Hive.box<bool>(_boxName);
    await box.put(_voiceRemindMutedKey, value);
  }
}
