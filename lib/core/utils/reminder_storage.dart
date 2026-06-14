import 'package:hive_flutter/hive_flutter.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/models/todo_group.dart';

class ReminderStorage {
  static const String _boxName = 'reminders_box';
  static const String _allRemindersKey = 'all_reminders';
  static const String _allTodoGroupsKey = 'all_todo_groups';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<List<dynamic>>(_boxName);
  }

  static List<Reminder> loadReminders() {
    final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_boxName);
    final List<dynamic> rawList = box.get(_allRemindersKey) ?? <dynamic>[];

    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map(Reminder.fromMap)
        .toList();
  }

  static Future<void> saveReminders(List<Reminder> reminders) async {
    final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_boxName);
    final List<Map<String, dynamic>> data =
        reminders.map((Reminder reminder) => reminder.toMap()).toList();
    await box.put(_allRemindersKey, data);
  }

  static List<TodoGroup> loadTodoGroups() {
    final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_boxName);
    final List<dynamic> rawList = box.get(_allTodoGroupsKey) ?? <dynamic>[];

    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map(TodoGroup.fromMap)
        .toList()
      ..sort((TodoGroup a, TodoGroup b) => a.createdAt.compareTo(b.createdAt));
  }

  static Future<void> saveTodoGroups(List<TodoGroup> groups) async {
    final Box<List<dynamic>> box = Hive.box<List<dynamic>>(_boxName);
    final List<Map<String, dynamic>> data =
        groups.map((TodoGroup group) => group.toMap()).toList();
    await box.put(_allTodoGroupsKey, data);
  }
}
