import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/constants/app_strings.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/providers/notification_navigation_provider.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/widgets/create_reminder_sheet.dart';
import 'package:murmur/widgets/reminder_card.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _highlightedReminderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyNotificationTargetIfNeeded();
    });
  }

  void _openCreateReminderSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => CreateReminderSheet(initialDate: _selectedDay),
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
    final List<Reminder> remindersForSelectedDay =
        reminderNotifier.getFixedRemindersByDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        actions: <Widget>[
          IconButton(
            onPressed: _openCreateReminderSheet,
            icon: const Icon(Icons.add),
            tooltip: '新增',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  child: TableCalendar<void>(
                    firstDay: DateTime(2020, 1, 1),
                    lastDay: DateTime(2035, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (DateTime day) {
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (DateTime focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    eventLoader: (DateTime day) {
                      final int count = reminderNotifier.fixedReminderCountForDay(day);
                      return List<void>.filled(count, null, growable: false);
                    },
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      cellMargin: const EdgeInsets.all(4),
                      defaultTextStyle: Theme.of(context).textTheme.bodyMedium!,
                      markerDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                    ),
                    calendarBuilders: CalendarBuilders(
                      dowBuilder: (BuildContext context, DateTime day) {
                        final String text = _weekdayLabel(day.weekday);
                        return Center(
                          child: Text(
                            text,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                DateTimeUtils.formatDate(_selectedDay),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: remindersForSelectedDay.isEmpty
                    ? const Center(
                        child: Text('当天暂无 fixed reminders'),
                      )
                    : ListView.separated(
                        itemCount: remindersForSelectedDay.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          return ReminderCard(
                            reminder: remindersForSelectedDay[index],
                            isHighlighted: remindersForSelectedDay[index].id ==
                                _highlightedReminderId,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '一';
      case DateTime.tuesday:
        return '二';
      case DateTime.wednesday:
        return '三';
      case DateTime.thursday:
        return '四';
      case DateTime.friday:
        return '五';
      case DateTime.saturday:
        return '六';
      case DateTime.sunday:
        return '日';
      default:
        return '';
    }
  }

  void _applyNotificationTargetIfNeeded() {
    final target = ref.read(notificationNavigationTargetProvider);
    if (target == null) {
      return;
    }

    final reminder = ref.read(reminderListProvider.notifier).getReminderById(
          target.reminderId,
        );
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
  }
}
