import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/reminder_storage.dart';
import 'package:murmur/models/todo_group.dart';

final initialTodoGroupListProvider =
    Provider<List<TodoGroup>>((ref) => const <TodoGroup>[]);

final todoGroupListProvider =
    StateNotifierProvider<TodoGroupNotifier, List<TodoGroup>>(
  (ref) => TodoGroupNotifier(ref.watch(initialTodoGroupListProvider)),
);

class TodoGroupNotifier extends StateNotifier<List<TodoGroup>> {
  TodoGroupNotifier(List<TodoGroup> initialState) : super(initialState);

  Future<TodoGroup> addTodoGroup(String name) async {
    final String trimmed = name.trim();
    final TodoGroup group = TodoGroup(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    state = <TodoGroup>[...state, group];
    await ReminderStorage.saveTodoGroups(state);
    return group;
  }

  Future<void> deleteTodoGroup(String groupId) async {
    state = state.where((TodoGroup group) => group.id != groupId).toList();
    await ReminderStorage.saveTodoGroups(state);
  }
}
