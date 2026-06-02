import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/providers/todo_display_settings_provider.dart';
import 'package:murmur/widgets/app_date_picker.dart';
import 'package:murmur/widgets/app_slidable_action_button.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/widgets/create_todo_sheet.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  bool _showCompleted = false;
  bool _showDeadlineTodos = true;
  bool _showNormalTodos = true;

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
      return '${DateTimeUtils.formatDate(linked.scheduledTime!)} ${l10n.reminderAllDay}';
    }
    return DateTimeUtils.formatDateTime(linked.scheduledTime!);
  }

  Future<void> _createTaskManually() async {
    await CreateTodoSheet.show(context);
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

  Future<void> _showInlineTitleEdit(Reminder reminder) async {
    final TextEditingController controller = TextEditingController(text: reminder.title);
    final String? text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final AppLocalizations l10n = AppLocalizations.of(context);
        final MediaQueryData mediaQuery = MediaQuery.of(sheetContext);
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: mediaQuery.viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.todoEditTitleLabel),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(controller.text.trim()),
                    child: Text(l10n.commonSave),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    final String value = (text ?? '').trim();
    if (value.isEmpty) {
      return;
    }
    await ref.read(reminderListProvider.notifier).updateReminder(
          reminderId: reminder.id,
          title: value,
          syncLinkedCalendar: reminder.isSyncedToCalendar,
        );
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

  Widget _buildPendingTodoItem(
    Reminder reminder,
    ReminderNotifier reminderNotifier, {
    required bool showCreatedDate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey<String>('todo_${reminder.id}'),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.36,
          children: <Widget>[
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
        child: _TodoCard(
          reminder: reminder,
          showCreatedDate: showCreatedDate,
          calendarScheduleLabel: _calendarScheduleLabel(reminder, reminderNotifier),
          onTapText: () => _showInlineTitleEdit(reminder),
          onCheckChanged: (bool? checked) => _toggleComplete(reminder, checked),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderListProvider);
    final bool showTodoCreatedDate = ref.watch(showTodoCreatedDateProvider);
    final reminderNotifier = ref.read(reminderListProvider.notifier);
    final List<Reminder> pending = reminderNotifier.getFlexibleReminders(includeCompleted: false);
    final List<Reminder> pendingDeadline =
        pending.where((Reminder item) => item.hasDeadline).toList();
    final List<Reminder> pendingNormal =
        pending.where((Reminder item) => !item.hasDeadline).toList();
    final List<Reminder> completed = reminderNotifier
        .getFlexibleReminders(includeCompleted: true)
      ..removeWhere((Reminder item) => !item.isCompleted);

    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color deadlineHeaderColor = pendingDeadline.isEmpty
        ? AppTheme.secondaryLabelColor
        : AppTheme.deadlineColor;
    final Color normalHeaderColor = pendingNormal.isEmpty
        ? AppTheme.secondaryLabelColor
        : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.todoPageTitle),
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
              AppSectionHeader(
                title: l10n.todoSectionTitle,
                trailing: pending.isNotEmpty
                    ? Text(
                        '${pending.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
              ),
              Expanded(
                child: pending.isEmpty && completed.isEmpty
                    ? AppEmptyState(
                        icon: Icons.checklist_outlined,
                        title: l10n.todoEmptyTitle,
                        subtitle: l10n.todoEmptySubtitle,
                      )
                    : ListView(
                        children: <Widget>[
                          ...<Widget>[
                            (_showDeadlineTodos
                                ? Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        setState(() => _showDeadlineTodos = !_showDeadlineTodos);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
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
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: deadlineHeaderColor,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              '${pendingDeadline.length}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: deadlineHeaderColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : AppGroupedSection(
                                    children: <Widget>[
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() => _showDeadlineTodos = !_showDeadlineTodos);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
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
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(color: deadlineHeaderColor),
                                                  ),
                                                ),
                                                Text(
                                                  '${pendingDeadline.length}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(color: deadlineHeaderColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )),
                          
                            if (_showDeadlineTodos && pendingDeadline.isNotEmpty)
                              ...pendingDeadline.map(
                                (Reminder reminder) =>
                                    _buildPendingTodoItem(
                                      reminder,
                                      reminderNotifier,
                                      showCreatedDate: showTodoCreatedDate,
                                    ),
                              ),
                            
                          ],
                          ...<Widget>[
                            (_showNormalTodos
                                ? Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        setState(() => _showNormalTodos = !_showNormalTodos);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
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
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: normalHeaderColor,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            Text(
                                              '${pendingNormal.length}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: normalHeaderColor,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : AppGroupedSection(
                                    children: <Widget>[
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() => _showNormalTodos = !_showNormalTodos);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
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
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(color: normalHeaderColor),
                                                  ),
                                                ),
                                                Text(
                                                  '${pendingNormal.length}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(color: normalHeaderColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )),
                      
                            if (_showNormalTodos && pendingNormal.isNotEmpty)
                              ...pendingNormal.map(
                                (Reminder reminder) =>
                                    _buildPendingTodoItem(
                                      reminder,
                                      reminderNotifier,
                                      showCreatedDate: showTodoCreatedDate,
                                    ),
                              ),
                            const SizedBox(height: 6),
                          ],
                          if (completed.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            AppGroupedSection(
                              children: <Widget>[
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _showCompleted = !_showCompleted;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          Icon(
                                            _showCompleted
                                                ? Icons.keyboard_arrow_down
                                                : Icons.keyboard_arrow_right,
                                            size: 22,
                                            color: AppTheme.secondaryLabelColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              l10n.todoCompletedSection,
                                              style: Theme.of(context).textTheme.titleSmall,
                                            ),
                                          ),
                                          Text(
                                            '${completed.length}',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (_showCompleted)
                                  Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    color: AppTheme.separatorColor,
                                  ),
                                if (_showCompleted)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _clearCompleted,
                                        child: Text(l10n.todoClearCompleted),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_showCompleted) ...<Widget>[
                              const SizedBox(height: 8),
                              ...completed.map((Reminder reminder) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Slidable(
                                    key: ValueKey<String>('todo_done_${reminder.id}'),
                                    endActionPane: ActionPane(
                                      motion: const DrawerMotion(),
                                      extentRatio: 0.14,
                                      children: <Widget>[
                                        AppSlidableActionButton(
                                          onPressed: () => _deleteTodo(reminder),
                                          icon: Icons.delete_outline,
                                          iconColor: AppTheme.destructiveColor,
                                          backgroundColor: AppTheme.destructiveColor
                                              .withValues(alpha: 0.16),
                                        ),
                                      ],
                                    ),
                                    child: _TodoCard(
                                      reminder: reminder,
                                      showCreatedDate: showTodoCreatedDate,
                                      calendarScheduleLabel:
                                          _calendarScheduleLabel(reminder, reminderNotifier),
                                      onTapText: () => _showInlineTitleEdit(reminder),
                                      onCheckChanged: (bool? checked) =>
                                          _toggleComplete(reminder, checked),
                                    ),
                                  ),
                                );
                              }),
                            ],
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
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.reminder,
    required this.showCreatedDate,
    this.calendarScheduleLabel,
    this.onTapText,
    this.onCheckChanged,
  });

  final Reminder reminder;
  final bool showCreatedDate;
  final String? calendarScheduleLabel;
  final VoidCallback? onTapText;
  final ValueChanged<bool?>? onCheckChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color textColor = reminder.isCompleted
        ? AppTheme.secondaryLabelColor
        : AppTheme.textPrimaryColor;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Checkbox(
                  value: reminder.isCompleted,
                  onChanged: onCheckChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: onTapText,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            reminder.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: textColor,
                                  decoration: reminder.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  height: 1.3,
                                ),
                          ),
                          if (reminder.hasDeadline) ...<Widget>[
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.flag_outlined,
                                  size: 13,
                                  color: reminder.isCompleted
                                      ? AppTheme.secondaryLabelColor
                                      : AppTheme.deadlineColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.todoDeadlineLabel(
                                    DateTimeUtils.formatDateTime(reminder.deadlineAt!),
                                  ),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: reminder.isCompleted
                                            ? AppTheme.secondaryLabelColor
                                            : AppTheme.deadlineColor,
                                        fontWeight: FontWeight.w600,
                                        decoration: reminder.isCompleted
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                ),
                                if (reminder.isSyncedToCalendar) ...<Widget>[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 12,
                                    color: AppTheme.secondaryLabelColor,
                                  ),
                                ],
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
                                  color: AppTheme.secondaryLabelColor,
                                ),
                                if (calendarScheduleLabel != null) ...<Widget>[
                                  const SizedBox(width: 4),
                                  Text(
                                    calendarScheduleLabel!,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppTheme.secondaryLabelColor,
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
                                const SizedBox(width: 4),
                                Text(
                                  reminder.remindAt != null
                                      ? ReminderTimeRules.remindPreviewLabel(
                                          remindAt: reminder.remindAt,
                                          frequency: reminder.remindFrequency,
                                          repeatDays: reminder.remindRepeatDays,
                                        )
                                      : l10n.todoReminderSet,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                          ],
                          if (showCreatedDate) ...<Widget>[
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
