import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/core/utils/todo_section_id.dart';
import 'package:murmur/models/todo_group.dart';
import 'package:murmur/providers/todo_group_provider.dart';

final todoSectionOrderProvider =
    StateNotifierProvider<TodoSectionOrderNotifier, List<String>>(
  (ref) => TodoSectionOrderNotifier(ref),
);

class TodoSectionOrderNotifier extends StateNotifier<List<String>> {
  TodoSectionOrderNotifier(this._ref) : super(AppSettingsStorage.todoSectionOrder);

  final Ref _ref;

  List<String> normalizedOrder(List<TodoGroup> groups) {
    final List<String> result = <String>[];
    final Set<String> seen = <String>{};

    void addIfValid(String sectionId) {
      if (seen.contains(sectionId)) {
        return;
      }
      if (sectionId == kTodoDeadlineSectionId ||
          sectionId == kTodoNormalSectionId) {
        result.add(sectionId);
        seen.add(sectionId);
        return;
      }
      if (isTodoGroupSectionId(sectionId)) {
        final String? groupId = groupIdFromSectionId(sectionId);
        if (groupId != null &&
            groups.any((TodoGroup group) => group.id == groupId)) {
          result.add(sectionId);
          seen.add(sectionId);
        }
      }
    }

    for (final String sectionId in state) {
      addIfValid(sectionId);
    }

    if (!seen.contains(kTodoDeadlineSectionId)) {
      result.insert(0, kTodoDeadlineSectionId);
    }
    if (!seen.contains(kTodoNormalSectionId)) {
      final int deadlineIndex = result.indexOf(kTodoDeadlineSectionId);
      result.insert(deadlineIndex + 1, kTodoNormalSectionId);
    }

    final List<TodoGroup> sortedGroups = List<TodoGroup>.from(groups)
      ..sort((TodoGroup a, TodoGroup b) => a.sortOrder.compareTo(b.sortOrder));
    for (final TodoGroup group in sortedGroups) {
      addIfValid(todoGroupSectionId(group.id));
    }

    return result;
  }

  Future<void> _persistNormalized(List<TodoGroup> groups) async {
    final List<String> normalized = normalizedOrder(groups);
    if (normalized.length == state.length &&
        _sameOrder(normalized, state)) {
      return;
    }
    state = normalized;
    await AppSettingsStorage.setTodoSectionOrder(normalized);
  }

  Future<void> reorderSections({
    required int fromIndex,
    required int toIndex,
    required List<TodoGroup> groups,
  }) async {
    final List<String> order = normalizedOrder(groups);
    if (fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= order.length ||
        toIndex >= order.length ||
        fromIndex == toIndex) {
      return;
    }

    final String moved = order.removeAt(fromIndex);
    order.insert(toIndex, moved);
    state = order;
    await AppSettingsStorage.setTodoSectionOrder(order);
    await _ref
        .read(todoGroupListProvider.notifier)
        .syncSortOrderFromSectionOrder(order);
  }

  Future<void> appendGroupSection(String groupId) async {
    final String sectionId = todoGroupSectionId(groupId);
    if (state.contains(sectionId)) {
      return;
    }
    state = <String>[...state, sectionId];
    await AppSettingsStorage.setTodoSectionOrder(state);
  }

  Future<void> removeGroupSection(String groupId) async {
    final String sectionId = todoGroupSectionId(groupId);
    final List<String> next =
        state.where((String item) => item != sectionId).toList();
    if (next.length == state.length) {
      return;
    }
    state = next;
    await AppSettingsStorage.setTodoSectionOrder(state);
  }

  Future<void> ensureNormalized(List<TodoGroup> groups) async {
    await _persistNormalized(groups);
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}
