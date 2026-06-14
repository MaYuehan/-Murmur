import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/list_sort_order.dart';
import 'package:murmur/core/utils/reminder_storage.dart';
import 'package:murmur/core/utils/todo_section_id.dart';
import 'package:murmur/models/todo_group.dart';

final initialTodoGroupListProvider =
    Provider<List<TodoGroup>>((ref) => const <TodoGroup>[]);

final todoGroupListProvider =
    StateNotifierProvider<TodoGroupNotifier, List<TodoGroup>>(
  (ref) => TodoGroupNotifier(ref.watch(initialTodoGroupListProvider)),
);

class TodoGroupNotifier extends StateNotifier<List<TodoGroup>> {
  TodoGroupNotifier(List<TodoGroup> initialState)
      : super(_normalizeGroups(initialState));

  static List<TodoGroup> _normalizeGroups(List<TodoGroup> groups) {
    final List<TodoGroup> sorted = List<TodoGroup>.from(groups)
      ..sort((TodoGroup a, TodoGroup b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted
        .asMap()
        .entries
        .map(
          (MapEntry<int, TodoGroup> entry) => entry.value.copyWith(
            sortOrder: (entry.key + 1) * 1000,
          ),
        )
        .toList();
  }

  Future<void> _persist() async {
    await ReminderStorage.saveTodoGroups(state);
  }

  Future<TodoGroup> addTodoGroup(String name) async {
    final String trimmed = name.trim();
    final int sortOrder = state.isEmpty
        ? ListSortOrder.defaultNow()
        : ListSortOrder.afterLast(state.last.sortOrder);
    final TodoGroup group = TodoGroup(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: DateTime.now(),
      sortOrder: sortOrder,
    );
    state = <TodoGroup>[...state, group];
    await _persist();
    return group;
  }

  Future<void> renameTodoGroup({
    required String groupId,
    required String name,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = state
        .map(
          (TodoGroup group) =>
              group.id == groupId ? group.copyWith(name: trimmed) : group,
        )
        .toList();
    await _persist();
  }

  Future<void> reorderTodoGroups(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= state.length ||
        newIndex >= state.length ||
        oldIndex == newIndex) {
      return;
    }
    final List<TodoGroup> groups = List<TodoGroup>.from(state);
    final TodoGroup moved = groups.removeAt(oldIndex);
    groups.insert(newIndex, moved);
    state = groups
        .asMap()
        .entries
        .map(
          (MapEntry<int, TodoGroup> entry) => entry.value.copyWith(
            sortOrder: (entry.key + 1) * 1000,
          ),
        )
        .toList();
    await _persist();
  }

  Future<void> syncSortOrderFromSectionOrder(List<String> sectionOrder) async {
    int nextOrder = 1000;
    final Map<String, int> groupOrders = <String, int>{};
    for (final String sectionId in sectionOrder) {
      if (!isTodoGroupSectionId(sectionId)) {
        continue;
      }
      final String? groupId = groupIdFromSectionId(sectionId);
      if (groupId == null) {
        continue;
      }
      groupOrders[groupId] = nextOrder;
      nextOrder += 1000;
    }

    if (groupOrders.isEmpty) {
      return;
    }

    state = state
        .map(
          (TodoGroup group) => groupOrders.containsKey(group.id)
              ? group.copyWith(sortOrder: groupOrders[group.id])
              : group,
        )
        .toList()
      ..sort((TodoGroup a, TodoGroup b) => a.sortOrder.compareTo(b.sortOrder));
    await _persist();
  }

  Future<void> deleteTodoGroup(String groupId) async {
    state = state.where((TodoGroup group) => group.id != groupId).toList();
    await _persist();
  }
}
