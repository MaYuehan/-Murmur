import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/pages/calendar/reminder_detail_page.dart';
import 'package:murmur/providers/notification_navigation_provider.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/widgets/app_date_picker.dart';
import 'package:murmur/widgets/app_slidable_action_button.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/widgets/create_reminder_sheet.dart';
import 'package:murmur/widgets/reminder_card.dart';
import 'package:table_calendar/table_calendar.dart';

enum _CalendarViewMode { month, week }

enum _WeekAgendaScope { week, day }

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static final DateTime _calendarFirstDay = DateTime(2020, 1, 1);
  static final DateTime _calendarLastDay = DateTime(2035, 12, 31);

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _highlightedReminderId;
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  _WeekAgendaScope _weekAgendaScope = _WeekAgendaScope.week;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyNotificationTargetIfNeeded();
    });
  }

  void _openCreateReminderSheet() {
    CreateReminderSheet.show(context, initialDate: _selectedDay);
  }

  void _openReminderDetail(Reminder reminder) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReminderDetailPage(reminderId: reminder.id),
      ),
    );
  }

  Future<void> _editReminder(Reminder reminder) async {
    await CreateReminderSheet.show(
      context,
      initialDate: reminder.scheduledTime ?? _selectedDay,
      editingReminder: reminder,
    );
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.calendarDeleteTitle),
          content: Text(l10n.calendarDeleteMessage(reminder.title)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.destructiveColor,
              ),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(reminderListProvider.notifier).deleteReminder(reminder.id);
    if (!mounted) {
      return;
    }
    if (_highlightedReminderId == reminder.id) {
      setState(() => _highlightedReminderId = null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.calendarDeletedSnack)),
    );
  }

  Widget _buildSlidableReminderCard(Reminder reminder) {
    return Slidable(
      key: ValueKey<String>('calendar_${reminder.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.24,
        children: <Widget>[
          AppSlidableActionButton(
            onPressed: () => _editReminder(reminder),
            icon: Icons.edit_outlined,
            iconColor: AppTheme.primaryColor,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
          AppSlidableActionButton(
            onPressed: () => _deleteReminder(reminder),
            icon: Icons.delete_outline,
            iconColor: AppTheme.destructiveColor,
            backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
          ),
        ],
      ),
      child: ReminderCard(
        reminder: reminder,
        isHighlighted: reminder.id == _highlightedReminderId,
        onTap: () => _openReminderDetail(reminder),
      ),
    );
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
  }

  void _shiftWeek(int weekDelta) {
    setState(() {
      _selectedDay = _selectedDay.add(Duration(days: 7 * weekDelta));
      _focusedDay = _selectedDay;
    });
  }

  void _goToCurrentWeek() {
    final DateTime today = DateTimeUtils.startOfDay(DateTime.now());
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });
  }

  bool _isCurrentWeek(DateTime day) {
    final DateTime today = DateTimeUtils.startOfDay(DateTime.now());
    return DateTimeUtils.startOfWeek(day) == DateTimeUtils.startOfWeek(today);
  }

  String _formatMonthYearHeader(DateTime day) {
    final String localeName = Localizations.localeOf(context).toString();
    return DateFormat.yMMMM(localeName).format(day);
  }

  void _shiftMonth(int monthDelta) {
    setState(() {
      final DateTime anchor = DateTime(_focusedDay.year, _focusedDay.month + monthDelta, 1);
      final int maxDay = DateTime(anchor.year, anchor.month + 1, 0).day;
      final int day = _selectedDay.day <= maxDay ? _selectedDay.day : maxDay;
      _focusedDay = DateTime(anchor.year, anchor.month, day);
      _selectedDay = _focusedDay;
    });
  }

  void _applyMonthYear(DateTime monthYear) {
    final int year = monthYear.year;
    final int month = monthYear.month;
    final int maxDay = DateTime(year, month + 1, 0).day;
    final int day = _selectedDay.day <= maxDay ? _selectedDay.day : maxDay;
    setState(() {
      _focusedDay = DateTime(year, month, day);
      _selectedDay = _focusedDay;
    });
  }

  Future<void> _pickMonthYear(BuildContext anchorContext) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? picked = await showAppCupertinoWheelPicker(
      context: context,
      anchorContext: anchorContext,
      title: l10n.calendarPickMonthYear,
      initialDateTime: _focusedDay,
      minimumDate: _calendarFirstDay,
      maximumDate: _calendarLastDay,
      mode: CupertinoDatePickerMode.monthYear,
    );
    if (picked == null || !mounted) {
      return;
    }
    _applyMonthYear(picked);
  }

  Future<void> _pickWeek(BuildContext anchorContext) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? picked = await showAppCupertinoWheelPicker(
      context: context,
      anchorContext: anchorContext,
      title: l10n.calendarPickWeek,
      initialDateTime: _selectedDay,
      minimumDate: _calendarFirstDay,
      maximumDate: _calendarLastDay,
      mode: CupertinoDatePickerMode.date,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDay = DateTimeUtils.startOfDay(picked);
      _focusedDay = _selectedDay;
    });
  }

  Widget _buildTappablePeriodTitle({
    required String label,
    required Future<void> Function(BuildContext anchorContext) onTap,
    TextStyle? style,
  }) {
    return Builder(
      builder: (BuildContext anchorContext) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(anchorContext),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderListProvider);
    ref.watch(notificationNavigationTargetProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyNotificationTargetIfNeeded();
    });
    final reminderNotifier = ref.read(reminderListProvider.notifier);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: <Widget>[
          AppBarTextAction(
            label: l10n.commonCreate,
            onPressed: _openCreateReminderSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppSegmentedControl<_CalendarViewMode>(
                options: <AppSegmentOption<_CalendarViewMode>>[
                  AppSegmentOption(value: _CalendarViewMode.month, label: l10n.calendarViewMonth),
                  AppSegmentOption(value: _CalendarViewMode.week, label: l10n.calendarViewWeek),
                ],
                selected: _viewMode,
                onChanged: (_CalendarViewMode mode) {
                  setState(() => _viewMode = mode);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _viewMode == _CalendarViewMode.month
                          ? _buildMonthCalendar(reminderNotifier)
                          : _buildWeekStrip(reminderNotifier),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    ..._buildAgendaSlivers(reminderNotifier),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthCalendar(ReminderNotifier notifier) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

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
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => _shiftMonth(-1),
                      icon: const Icon(
                        Icons.chevron_left,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Center(
                        child: _buildTappablePeriodTitle(
                          label: _formatMonthYearHeader(_focusedDay),
                          onTap: _pickMonthYear,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _shiftMonth(1),
                      icon: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                TableCalendar<void>(
            firstDay: _calendarFirstDay,
            lastDay: _calendarLastDay,
            focusedDay: _focusedDay,
            headerVisible: false,
            sixWeekMonthsEnforced: true,
            rowHeight: 48,
            daysOfWeekHeight: 16,
            selectedDayPredicate: (DateTime day) => isSameDay(_selectedDay, day),
            onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (DateTime focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            eventLoader: (DateTime day) {
              final int count = notifier.fixedReminderCountForDay(day);
              return List<void>.filled(count, null, growable: false);
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              cellMargin: const EdgeInsets.all(2),
              defaultTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimaryColor,
              ),
              weekendTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimaryColor,
              ),
              selectedTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimary,
              ),
              todayTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
              markerSize: 4,
              markerMargin: const EdgeInsets.only(top: 4),
              markersMaxCount: 1,
              markerDecoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders<void>(
              dowBuilder: (BuildContext context, DateTime day) {
                return Center(
                  child: Text(
                    DateTimeUtils.shortWeekdayLabel(day.weekday),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.secondaryLabelColor,
                        ),
                  ),
                );
              },
            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<DateTime> weekDays = DateTimeUtils.daysInWeek(_selectedDay);
    final DateTime weekStart = weekDays.first;
    final DateTime weekEnd = weekDays.last;
    final bool isCurrentWeek = _isCurrentWeek(_selectedDay);

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
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => _shiftWeek(-1),
                    icon: const Icon(Icons.chevron_left, color: AppTheme.primaryColor),
                    tooltip: l10n.calendarPrevWeek,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Center(
                      child: _buildTappablePeriodTitle(
                        label:
                            '${DateTimeUtils.formatDate(weekStart)} - ${DateTimeUtils.formatDate(weekEnd)}',
                        onTap: _pickWeek,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shiftWeek(1),
                    icon: const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
                    tooltip: l10n.calendarNextWeek,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (!isCurrentWeek)
                Center(
                  child: TextButton(
                    onPressed: _goToCurrentWeek,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppTheme.primaryColor,
                    ),
                    child: Text(
                      l10n.calendarBackToCurrentWeek,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: weekDays.map((DateTime day) {
                  final bool isSelected = isSameDay(day, _selectedDay);
                  final bool isToday = isSameDay(day, DateTime.now());
                  final int count = notifier.fixedReminderCountForDay(day);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDay(day),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isToday
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.15)
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: <Widget>[
                            Text(
                              DateTimeUtils.shortWeekdayLabel(day.weekday),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : null,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day.day}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : null,
                                  ),
                            ),
                            if (count > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }

  SliverPersistentHeader _pinnedAgendaDateHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedAgendaDateHeaderDelegate(title: title),
    );
  }

  List<Widget> _buildAgendaSlivers(ReminderNotifier notifier) {
    if (_viewMode == _CalendarViewMode.month) {
      return _buildMonthDayAgendaSlivers(notifier);
    }
    return _buildWeekAgendaSlivers(notifier);
  }

  List<Widget> _buildMonthDayAgendaSlivers(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Reminder> reminders =
        notifier.getFixedRemindersByDay(_selectedDay);
    final String dateTitle = DateTimeUtils.formatDate(_selectedDay);

    return <Widget>[
      _pinnedAgendaDateHeader(dateTitle),
      if (reminders.isEmpty)
        SliverToBoxAdapter(
          child: AppEmptyState(
            icon: Icons.event_available_outlined,
            title: l10n.calendarEmptyDayTitle,
            subtitle: l10n.calendarEmptyDaySubtitle,
          ),
        )
      else
        _buildReminderListSliver(reminders),
    ];
  }

  List<Widget> _buildWeekAgendaSlivers(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: <Widget>[
              if (_weekAgendaScope == _WeekAgendaScope.week)
                Expanded(
                  child: Text(
                    l10n.calendarWeekAgendaTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                )
              else
                const Spacer(),
              SizedBox(
                width: 128,
                child: AppSegmentedControl<_WeekAgendaScope>(
                  compact: true,
                  options: <AppSegmentOption<_WeekAgendaScope>>[
                    AppSegmentOption(
                      value: _WeekAgendaScope.week,
                      label: l10n.calendarScopeThisWeek,
                    ),
                    AppSegmentOption(
                      value: _WeekAgendaScope.day,
                      label: l10n.calendarScopeSelectedDay,
                    ),
                  ],
                  selected: _weekAgendaScope,
                  onChanged: (_WeekAgendaScope scope) {
                    setState(() => _weekAgendaScope = scope);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      if (_weekAgendaScope == _WeekAgendaScope.day)
        ..._buildSelectedDayAgendaSlivers(notifier)
      else
        ..._buildWeekAgendaContentSlivers(notifier),
    ];
  }

  List<Widget> _buildSelectedDayAgendaSlivers(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Reminder> reminders =
        notifier.getFixedRemindersByDay(_selectedDay);
    final String dateTitle = DateTimeUtils.formatDate(_selectedDay);

    return <Widget>[
      _pinnedAgendaDateHeader(dateTitle),
      if (reminders.isEmpty)
        SliverToBoxAdapter(
          child: AppEmptyState(
            icon: Icons.event_available_outlined,
            title: l10n.calendarEmptyDayNamedTitle(dateTitle),
            subtitle: l10n.calendarEmptyDaySubtitle,
          ),
        )
      else
        _buildReminderListSliver(reminders),
    ];
  }

  List<Widget> _buildWeekAgendaContentSlivers(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<DateTime> weekDays = DateTimeUtils.daysInWeek(_selectedDay);
    final List<Widget> slivers = <Widget>[];
    var hasAnyReminders = false;

    for (final DateTime day in weekDays) {
      final List<Reminder> reminders = notifier.getFixedRemindersByDay(day);
      if (reminders.isEmpty) {
        continue;
      }
      hasAnyReminders = true;
      final String dateTitle =
          '${DateTimeUtils.weekdayLabel(day.weekday)} ${DateTimeUtils.formatDate(day)}';
      slivers.add(
        SliverMainAxisGroup(
          slivers: <Widget>[
            _pinnedAgendaDateHeader(dateTitle),
            _buildReminderListSliver(reminders),
          ],
        ),
      );
    }

    if (!hasAnyReminders) {
      slivers.add(
        SliverToBoxAdapter(
          child: AppEmptyState(
            icon: Icons.date_range_outlined,
            title: l10n.calendarEmptyWeekTitle,
            subtitle: l10n.calendarEmptyWeekSubtitle,
          ),
        ),
      );
    }

    return slivers;
  }

  List<Widget> _collectReminderListChildren(List<Reminder> reminders) {
    final List<Reminder> deadlineReminders = reminders
        .where((Reminder reminder) => reminder.isTodoDeadline)
        .toList();
    final List<Reminder> normalReminders = reminders
        .where((Reminder reminder) => !reminder.isTodoDeadline)
        .toList();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextStyle deadlineSectionTitleStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.deadlineColor,
              fontWeight: FontWeight.w600,
            ) ??
            const TextStyle(
              fontSize: 12,
              color: AppTheme.deadlineColor,
              fontWeight: FontWeight.w600,
            );
    final TextStyle scheduleSectionTitleStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ) ??
            const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            );

    final List<Widget> items = <Widget>[];
    if (deadlineReminders.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 2),
          child: Text(
            l10n.calendarDeadlineSection,
            style: deadlineSectionTitleStyle,
          ),
        ),
      );
      for (final Reminder reminder in deadlineReminders) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildSlidableReminderCard(reminder),
          ),
        );
      }
    }

    if (normalReminders.isNotEmpty) {
      items.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: 8,
            top: deadlineReminders.isNotEmpty ? 2 : 2,
          ),
          child: Text(
            l10n.calendarScheduleSection,
            style: scheduleSectionTitleStyle,
          ),
        ),
      );
    }

    for (final Reminder reminder in normalReminders) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildSlidableReminderCard(reminder),
        ),
      );
    }

    return items;
  }

  Widget _buildReminderListSliver(List<Reminder> reminders) {
    final List<Widget> items = _collectReminderListChildren(reminders);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => items[index],
        childCount: items.length,
      ),
    );
  }

  void _applyNotificationTargetIfNeeded() {
    final target = ref.read(notificationNavigationTargetProvider);
    if (target == null) {
      return;
    }

    final Reminder? reminder = ref
        .read(reminderListProvider.notifier)
        .getReminderById(target.reminderId);
    if (reminder == null || reminder.scheduledTime == null) {
      ref.read(notificationNavigationTargetProvider.notifier).state = null;
      return;
    }

    final DateTime day = DateTimeUtils.startOfDay(reminder.scheduledTime!);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
      _highlightedReminderId = reminder.id;
    });
    ref.read(notificationNavigationTargetProvider.notifier).state = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _openReminderDetail(reminder);
    });
  }
}

class _PinnedAgendaDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedAgendaDateHeaderDelegate({required this.title});

  final String title;
  static const double _extent = 36;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppTheme.groupedBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedAgendaDateHeaderDelegate oldDelegate) {
    return oldDelegate.title != title;
  }
}
