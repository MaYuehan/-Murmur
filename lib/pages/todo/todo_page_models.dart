part of 'todo_page.dart';

const String _todoDeadlineListKey = 'todo_deadline';
const String _todoNormalListKey = 'todo_normal';

enum _DeleteTodoGroupChoice {
  cancel,
  keepTodos,
  deleteTodos,
  confirmEmptyGroup,
}

class _SectionDragVisualState {
  const _SectionDragVisualState({
    this.draggingSectionId,
    this.hoverIndex,
    this.insertAtTop = false,
  });

  final String? draggingSectionId;
  final int? hoverIndex;
  final bool insertAtTop;

  bool get isActive =>
      draggingSectionId != null || hoverIndex != null || insertAtTop;
}

class _TodoDragVisualState {
  const _TodoDragVisualState({
    this.draggingTodoId,
    this.sourceListKey,
    this.targetListKey,
    this.hoverRowIndex,
    this.insertAtTop = false,
  });

  final String? draggingTodoId;
  final String? sourceListKey;
  final String? targetListKey;
  final int? hoverRowIndex;
  final bool insertAtTop;

  bool get isActive =>
      draggingTodoId != null ||
      targetListKey != null ||
      hoverRowIndex != null ||
      insertAtTop;
}

class _TodoDropListContext {
  const _TodoDropListContext({
    required this.todos,
    required this.targetTodoGroupId,
  });

  final List<Reminder> todos;
  final String? targetTodoGroupId;
}

class _SectionDragOrderContext {
  const _SectionDragOrderContext({
    required this.orderedSectionIds,
    required this.todoGroups,
  });

  final List<String> orderedSectionIds;
  final List<TodoGroup> todoGroups;
}
