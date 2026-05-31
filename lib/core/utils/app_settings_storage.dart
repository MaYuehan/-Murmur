import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

class AppSettingsStorage {
  static const String _boxName = 'app_settings_box';
  static const String _voiceRemindMutedKey = 'voice_remind_muted';
  static const String _appLocaleKey = 'app_locale';

  static Future<void> init() async {
    await Hive.openBox<dynamic>(_boxName);
  }

  static Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  static bool get voiceRemindMuted {
    return _box.get(_voiceRemindMutedKey) as bool? ?? false;
  }

  static Future<void> setVoiceRemindMuted(bool value) async {
    await _box.put(_voiceRemindMutedKey, value);
  }

  static Locale get appLocale {
    final String code = _box.get(_appLocaleKey) as String? ?? 'zh';
    return Locale(code == 'en' ? 'en' : 'zh');
  }

  static Future<void> setAppLocale(String languageCode) async {
    await _box.put(_appLocaleKey, languageCode);
  }
}
