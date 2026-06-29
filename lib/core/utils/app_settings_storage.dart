import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

class AppSettingsStorage {
  static const String _boxName = 'app_settings_box';
  static const String _voiceRemindMutedKey = 'voice_remind_muted';
  static const String _appLocaleKey = 'app_locale';
  static const String _showTodoCreatedDateKey = 'show_todo_created_date';
  static const String _weekStartsOnMondayKey = 'week_starts_on_monday';
  static const String _calendarViewPinnedKey = 'calendar_view_pinned';
  static const String _todoSectionOrderKey = 'todo_section_order';
  static const String _showDeadlineTodosKey = 'show_deadline_todos';
  static const String _showNormalTodosKey = 'show_normal_todos';
  static const String _expandedTodoGroupsKey = 'expanded_todo_groups';
  static const String _defaultVoiceIdKey = 'default_voice_id';

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

  static bool get showTodoCreatedDate {
    return _box.get(_showTodoCreatedDateKey) as bool? ?? true;
  }

  static Future<void> setShowTodoCreatedDate(bool value) async {
    await _box.put(_showTodoCreatedDateKey, value);
  }

  /// When true, weeks run Monday–Sunday; when false, Sunday–Saturday.
  static bool get weekStartsOnMonday {
    return _box.get(_weekStartsOnMondayKey) as bool? ?? true;
  }

  static Future<void> setWeekStartsOnMonday(bool value) async {
    await _box.put(_weekStartsOnMondayKey, value);
  }

  /// When true, the calendar header/grid stays fixed while the agenda scrolls.
  static bool get calendarViewPinned {
    return _box.get(_calendarViewPinnedKey) as bool? ?? false;
  }

  static Future<void> setCalendarViewPinned(bool value) async {
    await _box.put(_calendarViewPinnedKey, value);
  }

  static List<String> get todoSectionOrder {
    final List<dynamic>? raw = _box.get(_todoSectionOrderKey) as List<dynamic>?;
    if (raw == null) {
      return const <String>[];
    }
    return raw.cast<String>();
  }

  static Future<void> setTodoSectionOrder(List<String> order) async {
    await _box.put(_todoSectionOrderKey, order);
  }

  static bool get showDeadlineTodos {
    return _box.get(_showDeadlineTodosKey) as bool? ?? true;
  }

  static Future<void> setShowDeadlineTodos(bool value) async {
    await _box.put(_showDeadlineTodosKey, value);
  }

  static bool get showNormalTodos {
    return _box.get(_showNormalTodosKey) as bool? ?? true;
  }

  static Future<void> setShowNormalTodos(bool value) async {
    await _box.put(_showNormalTodosKey, value);
  }

  static Map<String, bool> get expandedTodoGroups {
    final Map<dynamic, dynamic>? raw =
        _box.get(_expandedTodoGroupsKey) as Map<dynamic, dynamic>?;
    if (raw == null) {
      return <String, bool>{};
    }
    return raw.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value == true),
    );
  }

  static Future<void> setExpandedTodoGroups(Map<String, bool> value) async {
    await _box.put(_expandedTodoGroupsKey, value);
  }

  static String get defaultVoiceId {
    return _box.get(_defaultVoiceIdKey) as String? ?? 'default';
  }

  static Future<void> setDefaultVoiceId(String voiceId) async {
    await _box.put(_defaultVoiceIdKey, voiceId);
  }
}
