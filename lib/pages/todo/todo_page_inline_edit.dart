part of 'todo_page.dart';

extension _TodoPageInlineEditExtension on _TodoPageState {
  void _beginInlineDraftEdit(String newTodoId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _draftTodoIds.add(newTodoId);
        _editingTodoId = newTodoId;
        _pendingFocusTodoId = newTodoId;
        _pendingFocusSelectAll = false;
      });
    });
  }
  Future<void> _commitTodoTitle(Reminder reminder, String title) async {
    final String value = title.trim();
    if (value.isEmpty || value == reminder.title) {
      return;
    }
    await ref.read(reminderListProvider.notifier).updateReminder(
          reminderId: reminder.id,
          title: value,
          syncLinkedCalendar: reminder.isSyncedToCalendar,
        );
  }

  int _sortOrderForInsertAfter(List<Reminder> list, int index) {
    final List<int> orders = list.map((Reminder item) => item.sortOrder).toList();
    return ListSortOrder.forInsertAfter(orders, index);
  }

  void _startTodoTitleEdit(String todoId, {required bool selectAll}) {
    setState(() {
      _editingTodoId = todoId;
      _pendingFocusTodoId = todoId;
      _pendingFocusSelectAll = selectAll;
    });
  }

  void _endTodoTitleEdit(String todoId) {
    setState(() {
      if (_editingTodoId == todoId) {
        _editingTodoId = null;
      }
      if (_pendingFocusTodoId == todoId) {
        _pendingFocusTodoId = null;
      }
    });
  }

  void _handleTodoFocusHandled(String todoId) {
    if (_pendingFocusTodoId != todoId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingFocusTodoId != todoId) {
        return;
      }
      setState(() => _pendingFocusTodoId = null);
    });
  }

  Future<void> _discardDraftTodo(String todoId) async {
    _draftTodoIds.remove(todoId);
    await ref.read(reminderListProvider.notifier).deleteFlexibleTodo(
          reminderId: todoId,
        );
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_editingTodoId == todoId) {
          _editingTodoId = null;
        }
        if (_pendingFocusTodoId == todoId) {
          _pendingFocusTodoId = null;
        }
      });
    });
  }

  Future<void> _navigateAdjacentTodoEdit({
    required Reminder current,
    required List<Reminder> listContext,
    required int currentIndex,
    required int delta,
    required String title,
  }) async {
    final int adjacentIndex = currentIndex + delta;
    if (adjacentIndex < 0 || adjacentIndex >= listContext.length) {
      return;
    }
    final String targetId = listContext[adjacentIndex].id;
    final String value = title.trim();

    if (value.isEmpty && _draftTodoIds.contains(current.id)) {
      await _discardDraftTodo(current.id);
      if (!mounted) {
        return;
      }
      _startTodoTitleEdit(targetId, selectAll: false);
      return;
    }

    if (value.isNotEmpty && value != current.title) {
      await _commitTodoTitle(current, value);
      _draftTodoIds.remove(current.id);
    }

    if (!mounted) {
      return;
    }
    _startTodoTitleEdit(targetId, selectAll: false);
  }

  Future<void> _createTodoBelow({
    required Reminder afterReminder,
    required List<Reminder> listContext,
    required int index,
  }) async {
    setState(() {
      _editingTodoId = null;
      _pendingFocusTodoId = null;
    });

    final int sortOrder = _sortOrderForInsertAfter(listContext, index);
    final String newTodoId = await ref.read(reminderListProvider.notifier).addFlexibleTodo(
          title: '',
          todoGroupId: afterReminder.todoGroupId,
          deadlineAt: afterReminder.deadlineAt,
          sortOrder: sortOrder,
        );
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _draftTodoIds.add(newTodoId);
        _editingTodoId = newTodoId;
        _pendingFocusTodoId = newTodoId;
        _pendingFocusSelectAll = false;
      });
    });
  }

}
