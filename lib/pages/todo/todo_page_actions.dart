part of 'todo_page.dart';

extension _TodoPageActionsExtension on _TodoPageState {
  bool _isTodoGroupExpanded(String groupId) {
    return ref.read(todoSectionExpansionProvider).isGroupExpanded(groupId);
  }

  void _toggleTodoGroupExpanded(String groupId) {
    ref.read(todoSectionExpansionProvider.notifier).toggleGroupExpanded(groupId);
  }

  void _startCreateTodoGroup() {
    setState(() => _isCreatingTodoGroup = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _newTodoGroupFocusNode.requestFocus();
    });
  }

  void _cancelCreateTodoGroup() {
    _newTodoGroupNameController.clear();
    _newTodoGroupFocusNode.unfocus();
    setState(() => _isCreatingTodoGroup = false);
  }

  Future<void> _commitNewTodoGroup() async {
    final String name = _newTodoGroupNameController.text.trim();
    if (name.isEmpty) {
      _cancelCreateTodoGroup();
      return;
    }

    final TodoGroup group =
        await ref.read(todoGroupListProvider.notifier).addTodoGroup(name);
    await ref.read(todoSectionOrderProvider.notifier).appendGroupSection(group.id);
    _newTodoGroupNameController.clear();
    _newTodoGroupFocusNode.unfocus();
    if (!mounted) {
      return;
    }
    setState(() {
      _isCreatingTodoGroup = false;
    });
    await ref
        .read(todoSectionExpansionProvider.notifier)
        .setGroupExpanded(group.id, true);
  }

  Future<void> _deleteTodoGroup(TodoGroup group) async {
    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    final int groupTodoCount = notifier
        .getFlexibleReminders(includeCompleted: true)
        .where((Reminder item) => item.todoGroupId == group.id)
        .length;

    final _DeleteTodoGroupChoice? choice = await _confirmDeleteTodoGroup(
      group: group,
      todoCount: groupTodoCount,
    );
    if (choice == null || choice == _DeleteTodoGroupChoice.cancel || !mounted) {
      return;
    }

    if (choice == _DeleteTodoGroupChoice.deleteTodos) {
      await notifier.deleteFlexibleTodosInGroup(group.id);
    } else {
      await notifier.clearTodoGroupMembership(group.id);
    }
    await ref.read(todoGroupListProvider.notifier).deleteTodoGroup(group.id);
    await ref.read(todoSectionOrderProvider.notifier).removeGroupSection(group.id);
    if (!mounted) {
      return;
    }
    await ref.read(todoSectionExpansionProvider.notifier).removeGroup(group.id);
  }

  Future<void> _renameTodoGroup(TodoGroup group) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextEditingController controller = TextEditingController(text: group.name);
    try {
      final String? newName = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(l10n.todoGroupRenameTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.todoGroupNameHint,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (String value) {
                Navigator.of(dialogContext).pop(value.trim());
              },
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: Text(l10n.commonSave),
              ),
            ],
          );
        },
      );
      if (newName == null || newName.isEmpty || !mounted || newName == group.name) {
        return;
      }
      await ref.read(todoGroupListProvider.notifier).renameTodoGroup(
            groupId: group.id,
            name: newName,
          );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
  }
  Widget _buildTodoListDivider() {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      color: AppTheme.separatorColor,
    );
  }
  Future<_DeleteTodoGroupChoice?> _confirmDeleteTodoGroup({
    required TodoGroup group,
    required int todoCount,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String content = todoCount > 0
        ? l10n.todoDeleteGroupMessageWithTodos(group.name, todoCount)
        : l10n.todoDeleteGroupMessage(group.name);

    return showDialog<_DeleteTodoGroupChoice>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.todoDeleteGroupTitle),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DeleteTodoGroupChoice.cancel),
              child: Text(l10n.commonCancel),
            ),
            if (todoCount > 0)
              TextButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(_DeleteTodoGroupChoice.keepTodos),
                child: Text(l10n.todoDeleteGroupKeepTodos),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                todoCount > 0
                    ? _DeleteTodoGroupChoice.deleteTodos
                    : _DeleteTodoGroupChoice.confirmEmptyGroup,
              ),
              child: Text(
                todoCount > 0 ? l10n.todoDeleteGroupDeleteTodos : l10n.commonDelete,
                style: todoCount > 0
                    ? const TextStyle(color: AppTheme.destructiveColor)
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createTaskManually() async {
    await CreateTodoSheet.show(context);
  }

  Future<void> _createFirstTodoInGroup(TodoGroup group) async {
    final String newTodoId = await ref.read(reminderListProvider.notifier).addFlexibleTodo(
          title: '',
          todoGroupId: group.id,
          sortOrder: ListSortOrder.defaultNow(),
        );
    if (!mounted || newTodoId.isEmpty) {
      return;
    }
    _beginInlineDraftEdit(newTodoId);
  }

  Future<void> _createTaskInGroupInline(
    TodoGroup group,
    List<Reminder> groupTodos,
  ) async {
    await ref
        .read(todoSectionExpansionProvider.notifier)
        .setGroupExpanded(group.id, true);
    if (groupTodos.isEmpty) {
      await _createFirstTodoInGroup(group);
      return;
    }
    await _createTodoBelow(
      afterReminder: groupTodos.last,
      listContext: groupTodos,
      index: groupTodos.length - 1,
    );
  }

  Future<void> _createTaskInGroup(TodoGroup group, List<Reminder> groupTodos) async {
    await _createTaskInGroupInline(group, groupTodos);
  }

  Future<void> _createDeadlineTask() async {
    await ref.read(todoSectionExpansionProvider.notifier).setShowDeadlineTodos(true);
    await CreateTodoSheet.show(context, initialHasDeadline: true);
  }

  Future<void> _createFirstNormalTodo() async {
    final String newTodoId = await ref.read(reminderListProvider.notifier).addFlexibleTodo(
          title: '',
          sortOrder: ListSortOrder.defaultNow(),
        );
    if (!mounted || newTodoId.isEmpty) {
      return;
    }
    _beginInlineDraftEdit(newTodoId);
  }

  Future<void> _createNormalTaskInline(List<Reminder> pendingNormal) async {
    await ref.read(todoSectionExpansionProvider.notifier).setShowNormalTodos(true);
    if (pendingNormal.isEmpty) {
      await _createFirstNormalTodo();
      return;
    }
    await _createTodoBelow(
      afterReminder: pendingNormal.last,
      listContext: pendingNormal,
      index: pendingNormal.length - 1,
    );
  }

  Future<void> _createNormalTask(List<Reminder> pendingNormal) async {
    await _createNormalTaskInline(pendingNormal);
  }

  Widget _buildSectionAddTodoButton({
    required VoidCallback onPressed,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: l10n.todoAdd,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.add,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
  Future<bool?> _confirmRemoveFromCalendar({int syncedCount = 1}) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String content = syncedCount > 1
        ? l10n.todoDeleteFromCalendarBodyMultiple(syncedCount)
        : l10n.todoDeleteFromCalendarBodySingle;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.todoDeleteFromCalendarTitle),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.todoDeleteTodoOnly),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.todoDeleteTodoAndCalendar,
                style: const TextStyle(color: AppTheme.destructiveColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTodo(Reminder reminder) async {
    bool alsoRemoveFromCalendar = false;
    if (reminder.calendarLinkedId != null) {
      final bool? confirmed = await _confirmRemoveFromCalendar();
      if (confirmed == null || !mounted) {
        return;
      }
      alsoRemoveFromCalendar = confirmed;
    }

    await ref.read(reminderListProvider.notifier).deleteFlexibleTodo(
          reminderId: reminder.id,
          alsoRemoveFromCalendar: alsoRemoveFromCalendar,
        );
  }

  Future<void> _editTodo(Reminder reminder) async {
    await CreateTodoSheet.show(context, editingReminder: reminder);
  }

  Future<void> _openSubItems(Reminder reminder) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => TodoSubItemsPage(todoId: reminder.id),
      ),
    );
  }

  Future<bool?> _confirmUnlinkFromCalendar() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.todoUnlinkTitle),
          content: Text(l10n.todoUnlinkBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.todoKeepInCalendar),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.todoRemoveFromCalendar,
                style: const TextStyle(color: AppTheme.destructiveColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onCalendarAction(Reminder reminder) async {
    if (reminder.isSyncedToCalendar) {
      final bool? confirmed = await _confirmUnlinkFromCalendar();
      if (confirmed != true || !mounted) {
        return;
      }
      await ref.read(reminderListProvider.notifier).unlinkFlexibleTodoFromCalendar(
            reminderId: reminder.id,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).todoRemovedFromCalendarSnack)),
      );
      return;
    }

    await _showPromoteSheet(reminder);
  }

  Future<void> _showPromoteSheet(Reminder reminder) async {
    DateTime? scheduledTime;
    DateTime? endTime;
    bool isAllDay = false;

    if (!reminder.hasDeadline) {
      final DateTime now = DateTime.now();
      final AppScheduleSelection? selection = await showAppSchedulePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year - 1, 1, 1),
        lastDate: DateTime(now.year + 3, 12, 31),
        title: AppLocalizations.of(context).scheduleAddToCalendarTitle,
      );
      if (selection == null || !mounted) {
        return;
      }

      if (selection.isAllDay) {
        scheduledTime = ReminderTimeRules.eventStart(
          eventDate: selection.eventDate,
          isAllDay: true,
          startDateTime: null,
        );
        endTime = ReminderTimeRules.eventEnd(
          eventDate: selection.eventDate,
          isAllDay: true,
          startDateTime: null,
          endDateTime: null,
        );
        isAllDay = true;
      } else {
        scheduledTime = DateTime(
          selection.eventDate.year,
          selection.eventDate.month,
          selection.eventDate.day,
          selection.startTime!.hour,
          selection.startTime!.minute,
        );
        endTime = DateTime(
          selection.eventDate.year,
          selection.eventDate.month,
          selection.eventDate.day,
          selection.endTime!.hour,
          selection.endTime!.minute,
        );
      }
    }

    await ref.read(reminderListProvider.notifier).syncFlexibleTodoToCalendar(
          reminderId: reminder.id,
          scheduledTime: scheduledTime,
          endTime: endTime,
          isAllDay: isAllDay,
        );
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reminder.hasDeadline ? l10n.todoSyncedDeadlineSnack : l10n.todoSyncedToCalendarSnack,
        ),
      ),
    );
  }
  Future<bool?> _confirmClearCompletedScope({
    required ClearCompletedScope scope,
    required int count,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.todoClearCompletedConfirmTitle),
          content: Text(
            l10n.todoClearCompletedScopeConfirmBody(
              _clearCompletedScopeLabel(scope, l10n),
              count,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.todoClearCompleted,
                style: const TextStyle(color: AppTheme.destructiveColor),
              ),
            ),
          ],
        );
      },
    );
  }

  String _clearCompletedScopeLabel(
    ClearCompletedScope scope,
    AppLocalizations l10n,
  ) {
    switch (scope) {
      case ClearCompletedScope.all:
        return l10n.todoClearCompletedScopeAll;
      case ClearCompletedScope.beforeThisWeek:
        return l10n.todoClearCompletedScopeBeforeThisWeek;
      case ClearCompletedScope.beforeThisMonth:
        return l10n.todoClearCompletedScopeBeforeThisMonth;
    }
  }

  Future<ClearCompletedScope?> _pickClearCompletedScope() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showAppActionDialog<ClearCompletedScope>(
      context: context,
      title: l10n.todoClearCompletedScopeTitle,
      cancelLabel: l10n.commonCancel,
      options: <AppActionDialogOption<ClearCompletedScope>>[
        AppActionDialogOption<ClearCompletedScope>(
          value: ClearCompletedScope.all,
          label: l10n.todoClearCompletedScopeAll,
          icon: Icons.delete_outline,
          iconColor: AppTheme.destructiveColor,
        ),
        AppActionDialogOption<ClearCompletedScope>(
          value: ClearCompletedScope.beforeThisWeek,
          label: l10n.todoClearCompletedScopeBeforeThisWeek,
          icon: Icons.calendar_today_outlined,
        ),
        AppActionDialogOption<ClearCompletedScope>(
          value: ClearCompletedScope.beforeThisMonth,
          label: l10n.todoClearCompletedScopeBeforeThisMonth,
          icon: Icons.calendar_month_outlined,
        ),
      ],
    );
  }

  Future<void> _onClearCompletedPressed() async {
    final ClearCompletedScope? scope = await _pickClearCompletedScope();
    if (scope == null || !mounted) {
      return;
    }

    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    final List<Reminder> completed = notifier
        .getFlexibleReminders(includeCompleted: true)
        .where((Reminder item) => item.isCompleted)
        .toList();
    final int count = ClearCompletedScopeUtils.countMatching(
      completed,
      scope: scope,
    );
    if (count == 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).todoClearCompletedNothingToClear),
        ),
      );
      return;
    }

    final bool? confirmed = await _confirmClearCompletedScope(
      scope: scope,
      count: count,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _clearCompleted(scope: scope);
  }

  Future<void> _clearCompleted({required ClearCompletedScope scope}) async {
    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    bool shouldClear(Reminder reminder) =>
        ClearCompletedScopeUtils.matches(reminder, scope: scope);

    final List<Reminder> completedWithCalendar = notifier
        .getFlexibleReminders(includeCompleted: true)
        .where(
          (Reminder reminder) =>
              reminder.isCompleted &&
              reminder.calendarLinkedId != null &&
              shouldClear(reminder),
        )
        .toList();

    bool alsoRemoveFromCalendar = false;
    if (completedWithCalendar.isNotEmpty) {
      final bool? confirmed = await _confirmRemoveFromCalendar(
        syncedCount: completedWithCalendar.length,
      );
      if (confirmed == null || !mounted) {
        return;
      }
      alsoRemoveFromCalendar = confirmed;
    }

    final int clearedCount = await notifier.clearCompletedFlexibleReminders(
      shouldClear: shouldClear,
      alsoRemoveFromCalendar: alsoRemoveFromCalendar,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).todoClearedCompletedCountSnack(clearedCount),
        ),
      ),
    );
  }

  Future<bool> _confirmUncompleteTodo(Reminder reminder) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String displayTitle = reminder.title.trim().isEmpty
        ? l10n.todoHintContent
        : reminder.title.trim();
    return showAppConfirmDialog(
      context: context,
      title: l10n.todoUncompleteConfirmTitle,
      message: l10n.todoUncompleteConfirmBody(displayTitle),
      cancelLabel: l10n.commonCancel,
      confirmLabel: l10n.todoUncompleteConfirmAction,
    );
  }

  Future<void> _onTodoCheckChanged(Reminder reminder, bool? checked) async {
    if (_isCompletedView && reminder.isCompleted && checked == false) {
      final bool confirmed = await _confirmUncompleteTodo(reminder);
      if (!confirmed || !mounted) {
        return;
      }
    }
    await _toggleComplete(reminder, checked);
  }

  Future<void> _toggleComplete(Reminder reminder, bool? checked) async {
    await ref.read(reminderListProvider.notifier).setReminderCompleted(
          reminderId: reminder.id,
          isCompleted: checked ?? false,
        );
  }

}
