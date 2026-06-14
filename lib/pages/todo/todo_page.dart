import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/list_sort_order.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/models/todo_group.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/providers/todo_display_settings_provider.dart';
import 'package:murmur/providers/todo_group_provider.dart';
import 'package:murmur/providers/todo_section_order_provider.dart';
import 'package:murmur/core/utils/todo_section_id.dart';
import 'package:murmur/widgets/app_date_picker.dart';
import 'package:murmur/widgets/app_slidable_action_button.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/pages/todo/todo_sub_items_page.dart';
import 'package:murmur/widgets/create_todo_sheet.dart';

enum _DeleteTodoGroupChoice {
  cancel,
  keepTodos,
  deleteTodos,
  confirmEmptyGroup,
}

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  static const double _todoGroupListBottomPadding = 8;
  static const double _todoGroupExpandedSectionGap = 14;
  static const double _todoGroupCollapsedSectionGap = 6;

  bool _isCompletedView = false;
  bool _showDeadlineTodos = true;
  bool _showNormalTodos = true;
  bool _isCreatingTodoGroup = false;
  final TextEditingController _newTodoGroupNameController = TextEditingController();
  final FocusNode _newTodoGroupFocusNode = FocusNode();
  final Map<String, bool> _expandedTodoGroups = <String, bool>{};
  String? _editingTodoId;
  String? _pendingFocusTodoId;
  bool _pendingFocusSelectAll = true;
  final Set<String> _draftTodoIds = <String>{};

  @override
  void dispose() {
    _newTodoGroupNameController.dispose();
    _newTodoGroupFocusNode.dispose();
    super.dispose();
  }

  bool _isTodoGroupExpanded(String groupId) {
    return _expandedTodoGroups[groupId] ?? true;
  }

  void _toggleTodoGroupExpanded(String groupId) {
    setState(() {
      _expandedTodoGroups[groupId] = !_isTodoGroupExpanded(groupId);
    });
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
      _expandedTodoGroups[group.id] = true;
    });
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
    setState(() {
      _expandedTodoGroups.remove(group.id);
    });
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

  Widget _buildReorderableSectionHeader({
    required String sectionId,
    required int sectionIndex,
    required List<String> orderedSectionIds,
    required List<TodoGroup> todoGroups,
    required Widget child,
  }) {
    final double headerWidth =
        MediaQuery.sizeOf(context).width - AppTheme.pagePadding * 2;
    return LongPressDraggable<String>(
      data: sectionId,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: headerWidth,
          child: Opacity(
            opacity: 0.92,
            child: child,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: child,
      ),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (DragTargetDetails<String> details) {
          return details.data != sectionId;
        },
        onAcceptWithDetails: (DragTargetDetails<String> details) {
          final int fromIndex = orderedSectionIds.indexOf(details.data);
          if (fromIndex < 0 || fromIndex == sectionIndex) {
            return;
          }
          ref.read(todoSectionOrderProvider.notifier).reorderSections(
                fromIndex: fromIndex,
                toIndex: sectionIndex,
                groups: todoGroups,
              );
        },
        builder: (
          BuildContext context,
          List<String?> candidateData,
          List<dynamic> rejectedData,
        ) {
          final bool isDropTarget = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: isDropTarget
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryColor, width: 1.5),
                  )
                : null,
            child: child,
          );
        },
      ),
    );
  }

  TodoGroup? _todoGroupForSectionId(String sectionId, List<TodoGroup> todoGroups) {
    final String? groupId = groupIdFromSectionId(sectionId);
    if (groupId == null) {
      return null;
    }
    for (final TodoGroup group in todoGroups) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  Widget _buildReorderableTodoRow({
    required Reminder reminder,
    required int index,
    required List<Reminder> todos,
    required bool reorderEnabled,
    required Widget child,
  }) {
    if (!reorderEnabled || _editingTodoId != null) {
      return child;
    }

    final double rowWidth =
        MediaQuery.sizeOf(context).width - AppTheme.pagePadding * 2;
    return LongPressDraggable<String>(
      data: reminder.id,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: rowWidth,
          child: Opacity(
            opacity: 0.92,
            child: child,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: child,
      ),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (DragTargetDetails<String> details) {
          return details.data != reminder.id;
        },
        onAcceptWithDetails: (DragTargetDetails<String> details) {
          final int fromIndex = todos.indexWhere(
            (Reminder item) => item.id == details.data,
          );
          if (fromIndex < 0 || fromIndex == index) {
            return;
          }
          ref.read(reminderListProvider.notifier).reorderFlexibleTodoInList(
                listContext: todos,
                fromIndex: fromIndex,
                toIndex: index,
              );
        },
        builder: (
          BuildContext context,
          List<String?> candidateData,
          List<dynamic> rejectedData,
        ) {
          final bool isDropTarget = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: isDropTarget
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryColor, width: 1.5),
                  )
                : null,
            child: child,
          );
        },
      ),
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

  List<Reminder> _pendingTodosForGroup(List<Reminder> pending, String groupId) {
    return pending
        .where((Reminder item) => item.todoGroupId == groupId)
        .toList();
  }

  bool _isDeadlineDueTodayOrOverdue(Reminder reminder) {
    if (!reminder.hasDeadline || reminder.isCompleted || reminder.deadlineAt == null) {
      return false;
    }
    return DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!) <= 0;
  }

  Color _deadlineSectionHeaderColor(List<Reminder> deadlineTodos) {
    if (deadlineTodos.isEmpty) {
      return AppTheme.secondaryLabelColor;
    }
    final bool hasUrgentDeadline =
        deadlineTodos.any(_isDeadlineDueTodayOrOverdue);
    return hasUrgentDeadline ? AppTheme.destructiveColor : AppTheme.primaryColor;
  }

  Color _todoGroupSectionHeaderColor(List<Reminder> groupTodos) {
    if (groupTodos.isEmpty) {
      return AppTheme.secondaryLabelColor;
    }
    final List<Reminder> deadlineTodos = groupTodos
        .where((Reminder item) => item.hasDeadline)
        .toList();
    if (deadlineTodos.isEmpty) {
      return AppTheme.textPrimaryColor;
    }
    return _deadlineSectionHeaderColor(deadlineTodos);
  }

  String? _calendarScheduleLabel(Reminder todo, ReminderNotifier notifier) {
    if (!todo.isSyncedToCalendar || todo.hasDeadline || todo.calendarLinkedId == null) {
      return null;
    }
    final Reminder? linked = notifier.getReminderById(todo.calendarLinkedId!);
    if (linked?.scheduledTime == null) {
      return null;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (linked!.isAllDay) {
      return '${DateTimeUtils.formatCardDate(linked.scheduledTime!)} ${l10n.reminderAllDay}';
    }
    return DateTimeUtils.formatCardDateTime(linked.scheduledTime!);
  }

  Future<void> _createTaskManually() async {
    await CreateTodoSheet.show(context);
  }

  bool _groupHasDraftTodo(String groupId) {
    if (_draftTodoIds.isEmpty) {
      return false;
    }
    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    for (final String todoId in _draftTodoIds) {
      final Reminder? todo = notifier.getReminderById(todoId);
      if (todo?.todoGroupId == groupId) {
        return true;
      }
    }
    return false;
  }

  bool _normalHasDraftTodo() {
    if (_draftTodoIds.isEmpty) {
      return false;
    }
    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    for (final String todoId in _draftTodoIds) {
      final Reminder? todo = notifier.getReminderById(todoId);
      if (todo != null && !todo.hasDeadline && todo.todoGroupId == null) {
        return true;
      }
    }
    return false;
  }

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
    setState(() => _expandedTodoGroups[group.id] = true);
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
    setState(() => _showDeadlineTodos = true);
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
    setState(() => _showNormalTodos = true);
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

  Future<bool?> _confirmClearCompleted(int count) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.todoClearCompletedConfirmTitle),
          content: Text(l10n.todoClearCompletedConfirmBody(count)),
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

  Future<void> _onClearCompletedPressed(int count) async {
    final bool? confirmed = await _confirmClearCompleted(count);
    if (confirmed != true || !mounted) {
      return;
    }
    await _clearCompleted();
  }

  Future<void> _clearCompleted() async {
    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    final List<Reminder> completedWithCalendar = notifier
        .getFlexibleReminders(includeCompleted: true)
        .where(
          (Reminder reminder) =>
              reminder.isCompleted && reminder.calendarLinkedId != null,
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

    await notifier.clearCompletedFlexibleReminders(
      alsoRemoveFromCalendar: alsoRemoveFromCalendar,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).todoClearedCompletedSnack)),
    );
  }

  Future<void> _toggleComplete(Reminder reminder, bool? checked) async {
    await ref.read(reminderListProvider.notifier).setReminderCompleted(
          reminderId: reminder.id,
          isCompleted: checked ?? false,
        );
  }

  Widget _buildTodoConnectedList({
    required List<Reminder> todos,
    required ReminderNotifier reminderNotifier,
    required bool showCreatedDate,
    String keyPrefix = 'todo_connected',
    double bottomPadding = _todoGroupListBottomPadding,
    bool deleteOnly = false,
    bool reorderEnabled = true,
  }) {
    final bool canReorder = reorderEnabled && !deleteOnly;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppGroupedSection(
        children: <Widget>[
          for (int index = 0; index < todos.length; index++) ...<Widget>[
            _buildReorderableTodoRow(
              reminder: todos[index],
              index: index,
              todos: todos,
              reorderEnabled: canReorder,
              child: _buildTodoSlidable(
                reminder: todos[index],
                reminderNotifier: reminderNotifier,
                keyPrefix: keyPrefix,
                deleteOnly: deleteOnly,
                child: _TodoCard(
                key: ValueKey<String>('todo_card_${todos[index].id}'),
                reminder: todos[index],
                showCreatedDate: showCreatedDate,
                grouped: true,
                inlineEditEnabled: !deleteOnly,
                editing: _editingTodoId == todos[index].id,
                requestFocus: _pendingFocusTodoId == todos[index].id,
                selectAllOnFocus: _pendingFocusSelectAll,
                isDraft: _draftTodoIds.contains(todos[index].id),
                calendarScheduleLabel:
                    _calendarScheduleLabel(todos[index], reminderNotifier),
                onFocusHandled: () => _handleTodoFocusHandled(todos[index].id),
                onEditStart: () =>
                    _startTodoTitleEdit(todos[index].id, selectAll: true),
                onEditEnd: () => _endTodoTitleEdit(todos[index].id),
                onTitleSave: (String title) async {
                  await _commitTodoTitle(todos[index], title);
                  _draftTodoIds.remove(todos[index].id);
                },
                onCreateBelow: () => _createTodoBelow(
                  afterReminder: todos[index],
                  listContext: todos,
                  index: index,
                ),
                onDiscardDraft: () => _discardDraftTodo(todos[index].id),
                onCheckChanged: (bool? checked) =>
                    _toggleComplete(todos[index], checked),
                onSubItemsTap: todos[index].hasSubItems
                    ? () => _openSubItems(todos[index])
                    : null,
              ),
            ),
            ),
            if (index < todos.length - 1)
              const Divider(
                height: 1,
                thickness: 0.5,
                indent: 16,
                color: AppTheme.separatorColor,
              ),
          ],
          if (bottomPadding > 0) SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  Widget _buildTodoSlidable({
    required Reminder reminder,
    required ReminderNotifier reminderNotifier,
    required Widget child,
    String keyPrefix = 'todo',
    bool deleteOnly = false,
  }) {
    return Slidable(
      key: ValueKey<String>('${keyPrefix}_${reminder.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: deleteOnly ? 0.14 : 0.48,
        children: deleteOnly
            ? <Widget>[
                AppSlidableActionButton(
                  onPressed: () => _deleteTodo(reminder),
                  icon: Icons.delete_outline,
                  iconColor: AppTheme.destructiveColor,
                  backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
                ),
              ]
            : <Widget>[
                AppSlidableActionButton(
                  onPressed: () => _openSubItems(reminder),
                  icon: Icons.checklist_outlined,
                  iconColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                ),
                AppSlidableActionButton(
                  onPressed: () => _onCalendarAction(reminder),
                  icon: reminder.isSyncedToCalendar
                      ? Icons.event_busy_outlined
                      : Icons.calendar_today_outlined,
                  iconColor: AppTheme.iosBlue,
                  backgroundColor: AppTheme.iosBlue.withValues(alpha: 0.16),
                ),
                AppSlidableActionButton(
                  onPressed: () => _editTodo(reminder),
                  icon: Icons.edit_outlined,
                  iconColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                ),
                AppSlidableActionButton(
                  onPressed: () => _deleteTodo(reminder),
                  icon: Icons.delete_outline,
                  iconColor: AppTheme.destructiveColor,
                  backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
                ),
              ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderListProvider);
    ref.watch(todoGroupListProvider);
    ref.watch(todoSectionOrderProvider);
    final bool showTodoCreatedDate = ref.watch(showTodoCreatedDateProvider);
    final reminderNotifier = ref.read(reminderListProvider.notifier);
    final List<TodoGroup> todoGroups = ref.watch(todoGroupListProvider);
    final List<Reminder> pending = reminderNotifier.getFlexibleReminders(includeCompleted: false);
    final List<Reminder> pendingDeadline =
        pending.where((Reminder item) => item.hasDeadline).toList();
    final List<Reminder> pendingNormal = pending
        .where((Reminder item) => !item.hasDeadline && item.todoGroupId == null)
        .toList();
    final List<Reminder> completed = reminderNotifier
        .getFlexibleReminders(includeCompleted: true)
        .where((Reminder item) => item.isCompleted)
        .toList()
      ..sort((Reminder a, Reminder b) {
        final DateTime aTime = a.completedAt ?? a.createdAt;
        final DateTime bTime = b.completedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color deadlineHeaderColor = _deadlineSectionHeaderColor(pendingDeadline);
    const Color normalHeaderColor = AppTheme.textPrimaryColor;
    final bool showEmptyState = !_isCompletedView &&
        pending.isEmpty &&
        todoGroups.isEmpty &&
        !_isCreatingTodoGroup;

    return Scaffold(
      appBar: AppBar(
        title: _buildTodoAppBarTitle(context: context, l10n: l10n),
        actions: <Widget>[
          AppBarTextAction(label: l10n.commonCreate, onPressed: _createTaskManually),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildTodoViewHeader(
                context: context,
                l10n: l10n,
                pendingCount: pending.length,
                completedCount: completed.length,
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: <Widget>[
                    if (_isCompletedView)
                      ..._buildCompletedTodoListSlivers(
                        context: context,
                        l10n: l10n,
                        reminderNotifier: reminderNotifier,
                        showTodoCreatedDate: showTodoCreatedDate,
                        completed: completed,
                      )
                    else ...<Widget>[
                      if (showEmptyState)
                        SliverToBoxAdapter(
                          child: AppEmptyState(
                            icon: Icons.checklist_outlined,
                            title: l10n.todoEmptyTitle,
                            subtitle: l10n.todoEmptySubtitle,
                          ),
                        ),
                      ..._buildTodoListSlivers(
                        context: context,
                        l10n: l10n,
                        reminderNotifier: reminderNotifier,
                        showTodoCreatedDate: showTodoCreatedDate,
                        pending: pending,
                        pendingDeadline: pendingDeadline,
                        pendingNormal: pendingNormal,
                        todoGroups: todoGroups,
                        deadlineHeaderColor: deadlineHeaderColor,
                        normalHeaderColor: normalHeaderColor,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoAppBarTitle({
    required BuildContext context,
    required AppLocalizations l10n,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _buildTodoViewTab(
          context: context,
          label: l10n.todoSectionTitle,
          selected: !_isCompletedView,
          onTap: () {
            if (_isCompletedView) {
              setState(() => _isCompletedView = false);
            }
          },
        ),
        const SizedBox(width: 16),
        _buildTodoViewTab(
          context: context,
          label: l10n.todoCompletedSection,
          selected: _isCompletedView,
          onTap: () {
            if (!_isCompletedView) {
              setState(() => _isCompletedView = true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTodoViewTab({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final TextStyle selectedStyle = Theme.of(context).textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.w700,
        );
    final TextStyle unselectedStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
          color: AppTheme.secondaryLabelColor,
          fontWeight: FontWeight.w500,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
          child: selected
              ? AppChalkUnderlineLabel(
                  label: label,
                  style: selectedStyle,
                  underlineColor: AppTheme.primaryColor,
                )
              : Text(label, style: unselectedStyle),
        ),
      ),
    );
  }

  Widget _buildTodoViewHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required int pendingCount,
    required int completedCount,
  }) {
    final TextStyle? countStyle = Theme.of(context).textTheme.bodySmall;
    final TextStyle? sectionLabelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.secondaryLabelColor,
          fontWeight: FontWeight.w600,
        );
    final TextStyle? clearStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _isCompletedView ? l10n.todoAllCompleted : l10n.todoAllPending,
                style: sectionLabelStyle,
              ),
              const Spacer(),
              if (!_isCompletedView && pendingCount > 0)
                Text('$pendingCount', style: countStyle),
              if (_isCompletedView && completedCount > 0)
                Text('$completedCount', style: countStyle),
            ],
          ),
          if (_isCompletedView && completedCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _onClearCompletedPressed(completedCount),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: AppTheme.primaryColor,
                  textStyle: clearStyle,
                ),
                child: Text(l10n.todoClearCompleted),
              ),
            ),
          if (!_isCompletedView && !_isCreatingTodoGroup)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _startCreateTodoGroup,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: AppTheme.primaryColor,
                  textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                child: Text(l10n.todoAddGroup),
              ),
            ),
          if (!_isCompletedView && _isCreatingTodoGroup)
            _buildNewTodoGroupEditor(l10n),
        ],
      ),
    );
  }

  List<Widget> _buildCompletedTodoListSlivers({
    required BuildContext context,
    required AppLocalizations l10n,
    required ReminderNotifier reminderNotifier,
    required bool showTodoCreatedDate,
    required List<Reminder> completed,
  }) {
    if (completed.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: AppEmptyState(
            icon: Icons.task_alt_outlined,
            title: l10n.todoCompletedEmptyTitle,
          ),
        ),
      ];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: _buildTodoConnectedList(
          todos: completed,
          reminderNotifier: reminderNotifier,
          showCreatedDate: showTodoCreatedDate,
          keyPrefix: 'todo_completed',
          deleteOnly: true,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ];
  }

  double _expandedSectionHeaderExtent(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return 40 * textScale + 12;
  }

  double _collapsedSectionHeaderExtent(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
    return 46 * textScale + 10;
  }

  double _todoGroupSectionGap({
    required bool isExpanded,
    required bool hasListItems,
  }) {
    return isExpanded && hasListItems
        ? _todoGroupExpandedSectionGap
        : _todoGroupCollapsedSectionGap;
  }

  List<Widget> _buildTodoListSlivers({
    required BuildContext context,
    required AppLocalizations l10n,
    required ReminderNotifier reminderNotifier,
    required bool showTodoCreatedDate,
    required List<Reminder> pending,
    required List<Reminder> pendingDeadline,
    required List<Reminder> pendingNormal,
    required List<TodoGroup> todoGroups,
    required Color deadlineHeaderColor,
    required Color normalHeaderColor,
  }) {
    final List<String> sectionOrder = ref
        .read(todoSectionOrderProvider.notifier)
        .normalizedOrder(todoGroups);
    final List<Widget> slivers = <Widget>[];

    for (int sectionIndex = 0; sectionIndex < sectionOrder.length; sectionIndex++) {
      final String sectionId = sectionOrder[sectionIndex];

      if (sectionId == kTodoDeadlineSectionId) {
        slivers.add(
          SliverMainAxisGroup(
            slivers: <Widget>[
              _pinnedSectionHeader(
                extent: _showDeadlineTodos
                    ? _expandedSectionHeaderExtent(context)
                    : _collapsedSectionHeaderExtent(context),
                child: _buildReorderableSectionHeader(
                  sectionId: sectionId,
                  sectionIndex: sectionIndex,
                  orderedSectionIds: sectionOrder,
                  todoGroups: todoGroups,
                  child: _buildDeadlineSectionHeader(
                    context: context,
                    l10n: l10n,
                    deadlineHeaderColor: deadlineHeaderColor,
                    count: pendingDeadline.length,
                  ),
                ),
              ),
              if (_showDeadlineTodos && pendingDeadline.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildTodoConnectedList(
                    todos: pendingDeadline,
                    reminderNotifier: reminderNotifier,
                    showCreatedDate: showTodoCreatedDate,
                    keyPrefix: 'todo_deadline',
                    reorderEnabled: false,
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _todoGroupSectionGap(
                    isExpanded: _showDeadlineTodos,
                    hasListItems: pendingDeadline.isNotEmpty,
                  ),
                ),
              ),
            ],
          ),
        );
        continue;
      }

      if (sectionId == kTodoNormalSectionId) {
        slivers.add(
          SliverMainAxisGroup(
            slivers: <Widget>[
              _pinnedSectionHeader(
                extent: _showNormalTodos
                    ? _expandedSectionHeaderExtent(context)
                    : _collapsedSectionHeaderExtent(context),
                child: _buildReorderableSectionHeader(
                  sectionId: sectionId,
                  sectionIndex: sectionIndex,
                  orderedSectionIds: sectionOrder,
                  todoGroups: todoGroups,
                  child: _buildNormalSectionHeader(
                    context: context,
                    l10n: l10n,
                    normalHeaderColor: normalHeaderColor,
                    pendingNormal: pendingNormal,
                    count: pendingNormal.length,
                  ),
                ),
              ),
              if (_showNormalTodos &&
                  (pendingNormal.isNotEmpty || _normalHasDraftTodo()))
                SliverToBoxAdapter(
                  child: _buildTodoConnectedList(
                    todos: pendingNormal,
                    reminderNotifier: reminderNotifier,
                    showCreatedDate: showTodoCreatedDate,
                    keyPrefix: 'todo_normal',
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _todoGroupSectionGap(
                    isExpanded: _showNormalTodos,
                    hasListItems:
                        pendingNormal.isNotEmpty || _normalHasDraftTodo(),
                  ),
                ),
              ),
            ],
          ),
        );
        continue;
      }

      final TodoGroup? group = _todoGroupForSectionId(sectionId, todoGroups);
      if (group == null) {
        continue;
      }

      final List<Reminder> groupTodos = _pendingTodosForGroup(pending, group.id);
      final bool isExpanded = _isTodoGroupExpanded(group.id);
      final Color groupHeaderColor = _todoGroupSectionHeaderColor(groupTodos);
      final bool showGroupList =
          isExpanded && (groupTodos.isNotEmpty || _groupHasDraftTodo(group.id));

      slivers.add(
        SliverMainAxisGroup(
          slivers: <Widget>[
            _pinnedSectionHeader(
              extent: isExpanded
                  ? _expandedSectionHeaderExtent(context)
                  : _collapsedSectionHeaderExtent(context),
              child: _buildReorderableSectionHeader(
                sectionId: sectionId,
                sectionIndex: sectionIndex,
                orderedSectionIds: sectionOrder,
                todoGroups: todoGroups,
                child: _buildTodoGroupSectionHeader(
                  context: context,
                  group: group,
                  groupTodos: groupTodos,
                  count: groupTodos.length,
                  headerColor: groupHeaderColor,
                  isExpanded: isExpanded,
                ),
              ),
            ),
            if (showGroupList)
              SliverToBoxAdapter(
                child: _buildTodoConnectedList(
                  todos: groupTodos,
                  reminderNotifier: reminderNotifier,
                  showCreatedDate: showTodoCreatedDate,
                  keyPrefix: 'todo_group_item',
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: _todoGroupSectionGap(
                  isExpanded: isExpanded,
                  hasListItems: showGroupList,
                ),
              ),
            ),
          ],
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 20)));
    return slivers;
  }

  Widget _pinnedSectionHeader({
    required double extent,
    required Widget child,
  }) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TodoPinnedSectionHeaderDelegate(
        extent: extent,
        child: child,
      ),
    );
  }

  Widget _buildNewTodoGroupEditor(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AppGroupedSection(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _newTodoGroupNameController,
                      focusNode: _newTodoGroupFocusNode,
                      style: Theme.of(context).textTheme.titleSmall,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.todoGroupNameHint,
                        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.secondaryLabelColor,
                            ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _commitNewTodoGroup(),
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelCreateTodoGroup,
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTheme.secondaryLabelColor,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: l10n.commonCancel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoGroupSectionHeader({
    required BuildContext context,
    required TodoGroup group,
    required List<Reminder> groupTodos,
    required int count,
    required Color headerColor,
    required bool isExpanded,
  }) {
    if (isExpanded) {
      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _toggleTodoGroupExpanded(group.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: headerColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            group.name,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: headerColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: headerColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSectionAddTodoButton(
                onPressed: () => _createTaskInGroup(group, groupTodos),
              ),
            ],
          ),
        ),
      );
    }

    return Slidable(
      key: ValueKey<String>('todo_group_${group.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: <Widget>[
          AppSlidableActionButton(
            onPressed: () => _renameTodoGroup(group),
            icon: Icons.edit_outlined,
            iconColor: AppTheme.primaryColor,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
          AppSlidableActionButton(
            onPressed: () => _deleteTodoGroup(group),
            icon: Icons.delete_outline,
            iconColor: AppTheme.destructiveColor,
            backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
          ),
        ],
      ),
      child: AppGroupedSection(
        backgroundColor: Colors.transparent,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleTodoGroupExpanded(group.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.keyboard_arrow_right,
                      size: 22,
                      color: headerColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: headerColor,
                            ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: headerColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineSectionHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required Color deadlineHeaderColor,
    required int count,
  }) {
    if (_showDeadlineTodos) {
      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _showDeadlineTodos = !_showDeadlineTodos);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: deadlineHeaderColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.todoDeadlineSection,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: deadlineHeaderColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: deadlineHeaderColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSectionAddTodoButton(
                onPressed: _createDeadlineTask,
              ),
            ],
          ),
        ),
      );
    }

    return AppGroupedSection(
      backgroundColor: Colors.transparent,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _showDeadlineTodos = !_showDeadlineTodos);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.keyboard_arrow_right,
                    size: 22,
                    color: deadlineHeaderColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.todoDeadlineSection,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: deadlineHeaderColor,
                          ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: deadlineHeaderColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalSectionHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required Color normalHeaderColor,
    required List<Reminder> pendingNormal,
    required int count,
  }) {
    if (_showNormalTodos) {
      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _showNormalTodos = !_showNormalTodos);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: normalHeaderColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.todoNormalSection,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: normalHeaderColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: normalHeaderColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSectionAddTodoButton(
                onPressed: () => _createNormalTask(pendingNormal),
              ),
            ],
          ),
        ),
      );
    }

    return AppGroupedSection(
      backgroundColor: Colors.transparent,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _showNormalTodos = !_showNormalTodos);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.keyboard_arrow_right,
                    size: 22,
                    color: normalHeaderColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.todoNormalSection,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: normalHeaderColor,
                          ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: normalHeaderColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodoPinnedSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TodoPinnedSectionHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppTheme.groupedBackgroundColor,
      child: SizedBox(
        height: extent,
        width: double.infinity,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TodoPinnedSectionHeaderDelegate oldDelegate) {
    return true;
  }
}

class _TodoCard extends StatefulWidget {
  const _TodoCard({
    super.key,
    required this.reminder,
    required this.showCreatedDate,
    this.grouped = false,
    this.inlineEditEnabled = true,
    this.editing = false,
    this.requestFocus = false,
    this.selectAllOnFocus = true,
    this.isDraft = false,
    this.calendarScheduleLabel,
    this.onFocusHandled,
    this.onEditStart,
    this.onEditEnd,
    this.onTitleSave,
    this.onCreateBelow,
    this.onDiscardDraft,
    this.onCheckChanged,
    this.onSubItemsTap,
  });

  final Reminder reminder;
  final bool showCreatedDate;
  final bool grouped;
  final bool inlineEditEnabled;
  final bool editing;
  final bool requestFocus;
  final bool selectAllOnFocus;
  final bool isDraft;
  final String? calendarScheduleLabel;
  final VoidCallback? onFocusHandled;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;
  final Future<void> Function(String title)? onTitleSave;
  final VoidCallback? onCreateBelow;
  final VoidCallback? onDiscardDraft;
  final ValueChanged<bool?>? onCheckChanged;
  final VoidCallback? onSubItemsTap;

  @override
  State<_TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<_TodoCard> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  String _lastSavedTitle = '';
  bool _notesExpanded = false;
  bool _suppressFocusExit = false;
  bool _isExitingEdit = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    _titleController.addListener(_onTitleTextChanged);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_onTitleFocusChange);
    _lastSavedTitle = widget.reminder.title;
    if (widget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    }
  }

  @override
  void didUpdateWidget(covariant _TodoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing && !oldWidget.editing) {
      _lastSavedTitle = widget.reminder.title;
      _titleController.text = widget.reminder.title;
      _suppressFocusExit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    } else if (!widget.editing && oldWidget.editing) {
      _suppressFocusExit = false;
      _titleController.text = widget.reminder.title;
      _lastSavedTitle = widget.reminder.title;
    } else if (!widget.editing && oldWidget.reminder.title != widget.reminder.title) {
      _titleController.text = widget.reminder.title;
      _lastSavedTitle = widget.reminder.title;
    }
    if (oldWidget.reminder.notes != widget.reminder.notes) {
      _notesExpanded = false;
    } else if (widget.editing &&
        widget.requestFocus &&
        !oldWidget.requestFocus &&
        oldWidget.editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    }
  }

  @override
  void dispose() {
    _suppressFocusExit = true;
    _titleController.removeListener(_onTitleTextChanged);
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _onTitleTextChanged() {
    if (!widget.editing) {
      return;
    }
    setState(() {});
  }

  bool get _hasUnsavedTitleEdit =>
      widget.editing && _titleController.text.trim() != _lastSavedTitle.trim();

  void _requestEditFocus() {
    if (!mounted || !widget.editing) {
      return;
    }
    _titleFocusNode.requestFocus();
    if (widget.selectAllOnFocus) {
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    } else {
      _titleController.selection = TextSelection.collapsed(
        offset: _titleController.text.length,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFocusHandled?.call();
    });
  }

  void _onTitleFocusChange() {
    if (_suppressFocusExit || !_titleFocusNode.hasFocus || !widget.editing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _suppressFocusExit ||
          _titleFocusNode.hasFocus ||
          !widget.editing) {
        return;
      }
      unawaited(_exitTitleEdit());
    });
  }

  void _startTitleEdit() {
    if (!widget.inlineEditEnabled || widget.editing) {
      return;
    }
    widget.onEditStart?.call();
  }

  Future<void> _onTitleSubmitted(String _) async {
    if (!widget.editing || _isExitingEdit) {
      return;
    }
    final String value = _titleController.text.trim();
    if (value.isEmpty) {
      if (widget.isDraft) {
        _suppressFocusExit = true;
        widget.onDiscardDraft?.call();
      }
      return;
    }
    if (value != _lastSavedTitle) {
      _suppressFocusExit = true;
      await widget.onTitleSave?.call(value);
      if (!mounted || !widget.editing) {
        _suppressFocusExit = false;
        return;
      }
      _lastSavedTitle = value;
      _suppressFocusExit = false;
      if (mounted) {
        setState(() {});
      }
      _titleFocusNode.requestFocus();
      return;
    }
    _suppressFocusExit = true;
    widget.onCreateBelow?.call();
  }

  Future<void> _exitTitleEdit() async {
    if (!widget.editing || _isExitingEdit) {
      return;
    }
    _isExitingEdit = true;
    try {
      final String value = _titleController.text.trim();
      if (value.isEmpty) {
        if (widget.isDraft) {
          widget.onDiscardDraft?.call();
        } else {
          _titleController.text = widget.reminder.title;
          widget.onEditEnd?.call();
        }
        return;
      }
      if (value != _lastSavedTitle) {
        await widget.onTitleSave?.call(value);
        if (!mounted) {
          return;
        }
        _lastSavedTitle = value;
      }
      widget.onEditEnd?.call();
    } finally {
      _isExitingEdit = false;
      _suppressFocusExit = false;
    }
  }

  TextStyle? _titleTextStyle(
    BuildContext context, {
    bool showEditUnderline = false,
  }) {
    final Color textColor = widget.reminder.isCompleted
        ? AppTheme.secondaryLabelColor
        : AppTheme.textPrimaryColor;
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          color: textColor,
          decoration: showEditUnderline
              ? TextDecoration.underline
              : (widget.reminder.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none),
          decorationColor:
              showEditUnderline ? AppTheme.primaryColor : textColor,
          height: 1.3,
        );
  }

  Widget _buildNotes(BuildContext context, String notes) {
    final TextStyle style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.secondaryLabelColor,
        ) ??
        const TextStyle(color: AppTheme.secondaryLabelColor);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter collapsedPainter = TextPainter(
          text: TextSpan(text: notes, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth - 20);
        final bool canExpand =
            notes.contains('\n') || collapsedPainter.didExceedMaxLines;

        if (!canExpand) {
          return Text(notes, style: style);
        }

        return GestureDetector(
          onTap: () => setState(() => _notesExpanded = !_notesExpanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  notes,
                  maxLines: _notesExpanded ? null : 1,
                  overflow: _notesExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              Icon(
                _notesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
                color: AppTheme.secondaryLabelColor,
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isDeadlineOverdue(Reminder reminder) {
    if (!reminder.hasDeadline || reminder.isCompleted || reminder.deadlineAt == null) {
      return false;
    }
    return DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!) < 0;
  }

  Color _deadlineAccentColor(Reminder reminder) {
    if (reminder.isCompleted) {
      return AppTheme.secondaryLabelColor;
    }
    if (!reminder.hasDeadline || reminder.deadlineAt == null) {
      return AppTheme.deadlineColor;
    }
    final int days = DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!);
    if (days <= 0) {
      return AppTheme.destructiveColor;
    }
    if (days == 1) {
      return AppTheme.primaryColor;
    }
    return AppTheme.textPrimaryColor;
  }

  Color _deadlineScheduleDateColor(Reminder reminder) {
    if (reminder.isCompleted) {
      return AppTheme.secondaryLabelColor;
    }
    if (!reminder.hasDeadline || reminder.deadlineAt == null) {
      return AppTheme.deadlineColor;
    }
    final int days = DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!);
    if (days <= 0) {
      return AppTheme.destructiveColor;
    }
    if (days == 1) {
      return AppTheme.primaryColor;
    }
    return AppTheme.secondaryLabelColor;
  }

  TextStyle? _scheduleDateTextStyle(
    BuildContext context, {
    required Color color,
    TextDecoration? decoration,
  }) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          decoration: decoration,
        );
  }

  Widget _buildDeadlineCountdown(BuildContext context, AppLocalizations l10n) {
    final Reminder reminder = widget.reminder;
    if (!reminder.hasDeadline || reminder.isCompleted || reminder.deadlineAt == null) {
      return const SizedBox.shrink();
    }

    final int days = DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!);
    final String label;
    if (days < 0) {
      label = l10n.todoDeadlineOverdue(-days);
    } else if (days == 0) {
      label = l10n.todoDeadlineDueToday;
    } else if (days == 1) {
      label = l10n.todoDeadlineDueTomorrow;
    } else {
      label = l10n.todoDeadlineDaysLeft(days);
    }

    return Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: _deadlineAccentColor(reminder).withValues(alpha: 0.88),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
    );
  }

  Widget _buildSubItemsShortcut(BuildContext context, AppLocalizations l10n) {
    final Reminder reminder = widget.reminder;
    final Color accentColor = reminder.isCompleted
        ? AppTheme.secondaryLabelColor
        : AppTheme.primaryColor;

    return Tooltip(
      message: l10n.todoSubItemsPageTitle,
      child: Material(
        color: accentColor.withValues(alpha: reminder.isCompleted ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: widget.onSubItemsTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.checklist_outlined, size: 15, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  l10n.todoSubItemsProgress(
                    reminder.subItemCompletedCount,
                    reminder.subItems.length,
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Icon(Icons.chevron_right, size: 16, color: accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Reminder reminder = widget.reminder;
    final TextStyle? titleStyle = _titleTextStyle(context);
    final TextStyle? editingTitleStyle = _titleTextStyle(
      context,
      showEditUnderline: _hasUnsavedTitleEdit,
    );

    final bool isOverdue = _isDeadlineOverdue(reminder);

    final bool showCountdown =
        reminder.hasDeadline && !reminder.isCompleted;
    final bool showSubItems =
        reminder.hasSubItems && widget.onSubItemsTap != null;
    final bool showSubItemsInColumn = showSubItems && reminder.hasDeadline;
    final bool showSubItemsOnRight = showSubItems && !reminder.hasDeadline;

    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      child: Stack(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Checkbox(
                value: reminder.isCompleted,
                onChanged: widget.onCheckChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                  widget.editing
                      ? TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          style: editingTitleStyle,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: 1,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _onTitleSubmitted,
                        )
                      : GestureDetector(
                          onTap: _startTitleEdit,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            reminder.title,
                            style: titleStyle,
                          ),
                        ),
                  if (showSubItemsInColumn) ...<Widget>[
                    const SizedBox(height: 6),
                    _buildSubItemsShortcut(context, l10n),
                  ],
                  if (reminder.notes?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 4),
                    _buildNotes(context, reminder.notes!.trim()),
                  ],
                  if (reminder.hasDeadline) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          if (reminder.isSyncedToCalendar) ...<Widget>[
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: reminder.isCompleted
                                  ? AppTheme.secondaryLabelColor
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Icon(
                            Icons.flag_outlined,
                            size: 12,
                            color: reminder.isCompleted
                                ? AppTheme.secondaryLabelColor
                                : AppTheme.deadlineColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.todoDeadlineLabel(
                                DateTimeUtils.formatCardDateTime(reminder.deadlineAt!),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _scheduleDateTextStyle(
                                context,
                                color: _deadlineScheduleDateColor(reminder),
                                decoration: reminder.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (reminder.isSyncedToCalendar && !reminder.hasDeadline) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: reminder.isCompleted
                                ? AppTheme.secondaryLabelColor
                                : AppTheme.primaryColor,
                          ),
                          if (widget.calendarScheduleLabel != null) ...<Widget>[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.calendarScheduleLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _scheduleDateTextStyle(
                                  context,
                                  color: reminder.isCompleted
                                      ? AppTheme.secondaryLabelColor
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (reminder.remindEnabled) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.notifications_outlined,
                            size: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          if (reminder.voiceRemindEnabled) ...<Widget>[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.graphic_eq_rounded,
                              size: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              reminder.remindAt != null
                                  ? ReminderTimeRules.remindPreviewLabel(
                                      remindAt: reminder.remindAt,
                                      frequency: reminder.remindFrequency,
                                      repeatDays: reminder.remindRepeatDays,
                                    )
                                  : l10n.todoReminderSet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.secondaryLabelColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  if (widget.showCreatedDate) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      l10n.todoCreatedAt(DateTimeUtils.formatDate(reminder.createdAt)),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
              if (showSubItemsOnRight)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _buildSubItemsShortcut(context, l10n),
                ),
              if (showCountdown) const SizedBox(width: 44),
            ],
          ),
          if (showCountdown)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 44,
              child: Center(
                child: _buildDeadlineCountdown(context, l10n),
              ),
            ),
        ],
      ),
    );

    if (widget.grouped) {
      if (!isOverdue) {
        return content;
      }
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(
            left: BorderSide(
              color: AppTheme.destructiveColor,
              width: 3,
            ),
          ),
        ),
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
        border: isOverdue
            ? Border.all(
                color: AppTheme.destructiveColor.withValues(alpha: 0.5),
                width: 1,
              )
            : null,
        boxShadow: isOverdue
            ? <BoxShadow>[
                BoxShadow(
                  color: AppTheme.destructiveColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: AppGroupedSection(
        children: <Widget>[content],
      ),
    );
  }
}
