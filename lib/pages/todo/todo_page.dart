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
          onTitleCommitted: (String title) => _commitTodoTitle(reminder, title),
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
                    : CustomScrollView(
                        slivers: _buildTodoListSlivers(
                          context: context,
                          l10n: l10n,
                          reminderNotifier: reminderNotifier,
                          showTodoCreatedDate: showTodoCreatedDate,
                          pendingDeadline: pendingDeadline,
                          pendingNormal: pendingNormal,
                          completed: completed,
                          deadlineHeaderColor: deadlineHeaderColor,
                          normalHeaderColor: normalHeaderColor,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _expandedSectionHeaderExtent(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return 40 * textScale + 12;
  }

  double _collapsedSectionHeaderExtent(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
    return 46 * textScale + 10;
  }

  double _expandedCompletedSectionHeaderExtent(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return _expandedSectionHeaderExtent(context) + 18 * textScale;
  }

  List<Widget> _buildTodoListSlivers({
    required BuildContext context,
    required AppLocalizations l10n,
    required ReminderNotifier reminderNotifier,
    required bool showTodoCreatedDate,
    required List<Reminder> pendingDeadline,
    required List<Reminder> pendingNormal,
    required List<Reminder> completed,
    required Color deadlineHeaderColor,
    required Color normalHeaderColor,
  }) {
    final List<Widget> slivers = <Widget>[
      SliverMainAxisGroup(
        slivers: <Widget>[
          _pinnedSectionHeader(
            extent: _showDeadlineTodos
                ? _expandedSectionHeaderExtent(context)
                : _collapsedSectionHeaderExtent(context),
            child: _buildDeadlineSectionHeader(
              context: context,
              l10n: l10n,
              deadlineHeaderColor: deadlineHeaderColor,
              count: pendingDeadline.length,
            ),
          ),
          if (_showDeadlineTodos && pendingDeadline.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => _buildPendingTodoItem(
                  pendingDeadline[index],
                  reminderNotifier,
                  showCreatedDate: showTodoCreatedDate,
                ),
                childCount: pendingDeadline.length,
              ),
            ),
        ],
      ),
      SliverMainAxisGroup(
        slivers: <Widget>[
          _pinnedSectionHeader(
            extent: _showNormalTodos
                ? _expandedSectionHeaderExtent(context)
                : _collapsedSectionHeaderExtent(context),
            child: _buildNormalSectionHeader(
              context: context,
              l10n: l10n,
              normalHeaderColor: normalHeaderColor,
              count: pendingNormal.length,
            ),
          ),
          if (_showNormalTodos && pendingNormal.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => _buildPendingTodoItem(
                  pendingNormal[index],
                  reminderNotifier,
                  showCreatedDate: showTodoCreatedDate,
                ),
                childCount: pendingNormal.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
        ],
      ),
    ];

    if (completed.isNotEmpty) {
      slivers.add(
        SliverMainAxisGroup(
          slivers: <Widget>[
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            _pinnedSectionHeader(
              extent: _showCompleted
                  ? _expandedCompletedSectionHeaderExtent(context)
                  : _collapsedSectionHeaderExtent(context),
              child: _buildCompletedSectionHeader(
                context: context,
                l10n: l10n,
                count: completed.length,
              ),
            ),
            if (_showCompleted)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final Reminder reminder = completed[index];
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
                              backgroundColor:
                                  AppTheme.destructiveColor.withValues(alpha: 0.16),
                            ),
                          ],
                        ),
                        child: _TodoCard(
                          reminder: reminder,
                          showCreatedDate: showTodoCreatedDate,
                          calendarScheduleLabel:
                              _calendarScheduleLabel(reminder, reminderNotifier),
                          onTitleCommitted: (String title) =>
                              _commitTodoTitle(reminder, title),
                          onCheckChanged: (bool? checked) =>
                              _toggleComplete(reminder, checked),
                        ),
                      ),
                    );
                  },
                  childCount: completed.length,
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

  Widget _buildDeadlineSectionHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required Color deadlineHeaderColor,
    required int count,
  }) {
    if (_showDeadlineTodos) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _showDeadlineTodos = !_showDeadlineTodos);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
      );
    }

    return AppGroupedSection(
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
    required int count,
  }) {
    if (_showNormalTodos) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _showNormalTodos = !_showNormalTodos);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
      );
    }

    return AppGroupedSection(
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

  Widget _buildCompletedSectionHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required int count,
  }) {
    const Color headerColor = AppTheme.secondaryLabelColor;

    if (_showCompleted) {
      final TextStyle? labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
            color: headerColor,
            fontWeight: FontWeight.w600,
          );
      final TextStyle? clearStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          );

      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _showCompleted = !_showCompleted);
                  },
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
                          l10n.todoCompletedSection,
                          style: labelStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  InkWell(
                    onTap: () {
                      setState(() => _showCompleted = !_showCompleted);
                    },
                    child: Text(
                      '$count',
                      style: labelStyle,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _onClearCompletedPressed(count),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      foregroundColor: AppTheme.primaryColor,
                      textStyle: clearStyle,
                    ),
                    child: Text(l10n.todoClearCompleted),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return AppGroupedSection(
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _showCompleted = !_showCompleted);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.keyboard_arrow_right,
                    size: 22,
                    color: headerColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.todoCompletedSection,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.bodySmall,
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
    required this.reminder,
    required this.showCreatedDate,
    this.calendarScheduleLabel,
    this.onTitleCommitted,
    this.onCheckChanged,
  });

  final Reminder reminder;
  final bool showCreatedDate;
  final String? calendarScheduleLabel;
  final ValueChanged<String>? onTitleCommitted;
  final ValueChanged<bool?>? onCheckChanged;

  @override
  State<_TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<_TodoCard> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  bool _editingTitle = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_onTitleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _TodoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editingTitle && oldWidget.reminder.title != widget.reminder.title) {
      _titleController.text = widget.reminder.title;
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus && _editingTitle) {
      _commitTitleEdit();
    }
  }

  void _startTitleEdit() {
    if (_editingTitle) {
      return;
    }
    _titleController.text = widget.reminder.title;
    setState(() => _editingTitle = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _titleFocusNode.requestFocus();
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    });
  }

  void _commitTitleEdit() {
    if (!_editingTitle) {
      return;
    }
    final String value = _titleController.text.trim();
    if (value.isEmpty) {
      _titleController.text = widget.reminder.title;
    } else if (value != widget.reminder.title) {
      widget.onTitleCommitted?.call(value);
    }
    setState(() => _editingTitle = false);
    _titleFocusNode.unfocus();
  }

  TextStyle? _titleTextStyle(BuildContext context) {
    final Color textColor = widget.reminder.isCompleted
        ? AppTheme.secondaryLabelColor
        : AppTheme.textPrimaryColor;
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          color: textColor,
          decoration:
              widget.reminder.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
          height: 1.3,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Reminder reminder = widget.reminder;
    final TextStyle? titleStyle = _titleTextStyle(context);

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
                        _editingTitle
                            ? TextField(
                                controller: _titleController,
                                focusNode: _titleFocusNode,
                                style: titleStyle,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _commitTitleEdit(),
                              )
                            : GestureDetector(
                                onTap: _startTitleEdit,
                                behavior: HitTestBehavior.opaque,
                                child: Text(
                                  reminder.title,
                                  style: titleStyle,
                                ),
                              ),
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
                                  Text(
                                    widget.calendarScheduleLabel!,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: reminder.isCompleted
                                              ? AppTheme.secondaryLabelColor
                                              : AppTheme.primaryColor,
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
                                Text(
                                  reminder.remindAt != null
                                      ? ReminderTimeRules.remindPreviewLabel(
                                          remindAt: reminder.remindAt,
                                          frequency: reminder.remindFrequency,
                                          repeatDays: reminder.remindRepeatDays,
                                        )
                                      : l10n.todoReminderSet,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppTheme.secondaryLabelColor,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
