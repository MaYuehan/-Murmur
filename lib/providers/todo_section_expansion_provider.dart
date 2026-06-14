import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';

class TodoSectionExpansionState {
  const TodoSectionExpansionState({
    required this.showDeadlineTodos,
    required this.showNormalTodos,
    required this.expandedTodoGroups,
  });

  final bool showDeadlineTodos;
  final bool showNormalTodos;
  final Map<String, bool> expandedTodoGroups;

  bool isGroupExpanded(String groupId) {
    return expandedTodoGroups[groupId] ?? true;
  }

  TodoSectionExpansionState copyWith({
    bool? showDeadlineTodos,
    bool? showNormalTodos,
    Map<String, bool>? expandedTodoGroups,
  }) {
    return TodoSectionExpansionState(
      showDeadlineTodos: showDeadlineTodos ?? this.showDeadlineTodos,
      showNormalTodos: showNormalTodos ?? this.showNormalTodos,
      expandedTodoGroups: expandedTodoGroups ?? this.expandedTodoGroups,
    );
  }
}

final todoSectionExpansionProvider =
    StateNotifierProvider<TodoSectionExpansionNotifier, TodoSectionExpansionState>(
  (ref) => TodoSectionExpansionNotifier(),
);

class TodoSectionExpansionNotifier extends StateNotifier<TodoSectionExpansionState> {
  TodoSectionExpansionNotifier()
      : super(
          TodoSectionExpansionState(
            showDeadlineTodos: AppSettingsStorage.showDeadlineTodos,
            showNormalTodos: AppSettingsStorage.showNormalTodos,
            expandedTodoGroups: AppSettingsStorage.expandedTodoGroups,
          ),
        );

  Future<void> setShowDeadlineTodos(bool value) async {
    if (state.showDeadlineTodos == value) {
      return;
    }
    await AppSettingsStorage.setShowDeadlineTodos(value);
    state = state.copyWith(showDeadlineTodos: value);
  }

  Future<void> setShowNormalTodos(bool value) async {
    if (state.showNormalTodos == value) {
      return;
    }
    await AppSettingsStorage.setShowNormalTodos(value);
    state = state.copyWith(showNormalTodos: value);
  }

  Future<void> toggleShowDeadlineTodos() {
    return setShowDeadlineTodos(!state.showDeadlineTodos);
  }

  Future<void> toggleShowNormalTodos() {
    return setShowNormalTodos(!state.showNormalTodos);
  }

  Future<void> setGroupExpanded(String groupId, bool expanded) async {
    if (state.isGroupExpanded(groupId) == expanded &&
        state.expandedTodoGroups.containsKey(groupId)) {
      return;
    }
    final Map<String, bool> next =
        Map<String, bool>.from(state.expandedTodoGroups);
    next[groupId] = expanded;
    await AppSettingsStorage.setExpandedTodoGroups(next);
    state = state.copyWith(expandedTodoGroups: next);
  }

  Future<void> toggleGroupExpanded(String groupId) {
    return setGroupExpanded(groupId, !state.isGroupExpanded(groupId));
  }

  Future<void> removeGroup(String groupId) async {
    if (!state.expandedTodoGroups.containsKey(groupId)) {
      return;
    }
    final Map<String, bool> next =
        Map<String, bool>.from(state.expandedTodoGroups)..remove(groupId);
    await AppSettingsStorage.setExpandedTodoGroups(next);
    state = state.copyWith(expandedTodoGroups: next);
  }
}
