import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/services/reminder_alarm_coordinator.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

typedef OnNotificationTap = Future<void> Function(String? payload);

class ReminderScheduleSlot {
  const ReminderScheduleSlot({
    required this.when,
    required this.matchComponents,
  });

  final DateTime when;
  final DateTimeComponents? matchComponents;
}

class NotificationService {
  NotificationService._();

  static const int _maxRepeatSlots = 31;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static int notificationIdForReminder(String reminderId) => reminderId.hashCode;

  static int notificationIdForReminderSlot(String reminderId, int slot) =>
      '$reminderId#slot$slot'.hashCode;

  static Future<void> init({OnNotificationTap? onNotificationTap}) async {
    if (kIsWeb) {
      return;
    }
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        await onNotificationTap?.call(response.payload);
      },
    );
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) {
      return;
    }
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final MacOSFlutterLocalNotificationsPlugin? macPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
    await macPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> cancelReminderNotification(String reminderId) async {
    if (kIsWeb) {
      return;
    }
    ReminderAlarmCoordinator.cancel(reminderId);
    await _plugin.cancel(notificationIdForReminder(reminderId));
    for (int slot = 0; slot < _maxRepeatSlots; slot++) {
      await _plugin.cancel(notificationIdForReminderSlot(reminderId, slot));
    }
  }

  static String notificationBody(Reminder reminder) {
    if (reminder.remindText?.trim().isNotEmpty == true) {
      return reminder.remindText!.trim();
    }
    if (reminder.notes?.trim().isNotEmpty == true) {
      return reminder.notes!.trim();
    }
    return AppLocalizationsBinding.instance.notificationDefaultBody;
  }

  static List<ReminderScheduleSlot> buildScheduleSlots(Reminder reminder) {
    final DateTime? when = reminder.remindAt ?? reminder.scheduledTime;
    if (when == null || !reminder.remindEnabled || reminder.isCompleted) {
      return const <ReminderScheduleSlot>[];
    }

    final DateTime now = DateTime.now();
    switch (reminder.remindFrequency) {
      case 'daily':
        final DateTime? resolved = _resolveSingleSlot(
          template: when,
          frequency: 'daily',
          now: now,
        );
        if (resolved == null) {
          return const <ReminderScheduleSlot>[];
        }
        return <ReminderScheduleSlot>[
          ReminderScheduleSlot(
            when: resolved,
            matchComponents: DateTimeComponents.time,
          ),
        ];
      case 'weekly':
        final List<int> weekdays = ReminderTimeRules.effectiveRepeatDays(
          frequency: 'weekly',
          repeatDays: reminder.remindRepeatDays,
          remindAt: when,
        );
        if (weekdays.isEmpty) {
          return const <ReminderScheduleSlot>[];
        }
        return weekdays
            .map((int weekday) {
              final DateTime template = _templateForWeekday(weekday, when);
              final DateTime? resolved = _resolveSingleSlot(
                template: template,
                frequency: 'weekly',
                now: now,
              );
              if (resolved == null) {
                return null;
              }
              return ReminderScheduleSlot(
                when: resolved,
                matchComponents: DateTimeComponents.dayOfWeekAndTime,
              );
            })
            .whereType<ReminderScheduleSlot>()
            .toList();
      case 'monthly':
        final List<int> monthDays = ReminderTimeRules.effectiveRepeatDays(
          frequency: 'monthly',
          repeatDays: reminder.remindRepeatDays,
          remindAt: when,
        );
        if (monthDays.isEmpty) {
          return const <ReminderScheduleSlot>[];
        }
        return monthDays
            .map((int day) {
              final DateTime template = _templateForMonthDay(day, when);
              final DateTime? resolved = _resolveSingleSlot(
                template: template,
                frequency: 'monthly',
                now: now,
              );
              if (resolved == null) {
                return null;
              }
              return ReminderScheduleSlot(
                when: resolved,
                matchComponents: DateTimeComponents.dayOfMonthAndTime,
              );
            })
            .whereType<ReminderScheduleSlot>()
            .toList();
      case 'once':
      default:
        if (when.isBefore(now)) {
          return const <ReminderScheduleSlot>[];
        }
        return <ReminderScheduleSlot>[
          ReminderScheduleSlot(when: when, matchComponents: null),
        ];
    }
  }

  static DateTime? resolveScheduleTime(Reminder reminder) {
    final List<DateTime> times = resolveAllScheduleTimes(reminder);
    if (times.isEmpty) {
      return null;
    }
    times.sort();
    return times.first;
  }

  static List<DateTime> resolveAllScheduleTimes(Reminder reminder) {
    return buildScheduleSlots(reminder).map(( ReminderScheduleSlot slot) => slot.when).toList();
  }

  static DateTime? _resolveSingleSlot({
    required DateTime template,
    required String frequency,
    required DateTime now,
  }) {
    if (frequency == 'once') {
      return template.isBefore(now) ? null : template;
    }
    if (!template.isBefore(now)) {
      return template;
    }
    return _nextRepeatingOccurrence(
      template: template,
      frequency: frequency,
      now: now,
    );
  }

  static DateTime _templateForWeekday(int weekday, DateTime timeSource) {
    final DateTime now = DateTime.now();
    DateTime next = DateTime(
      now.year,
      now.month,
      now.day,
      timeSource.hour,
      timeSource.minute,
    );
    while (next.weekday != weekday) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  static DateTime _templateForMonthDay(int day, DateTime timeSource) {
    final DateTime now = DateTime.now();
    return _monthlyOccurrence(
      year: now.year,
      month: now.month,
      day: day,
      timeSource: timeSource,
    );
  }

  static DateTime _nextRepeatingOccurrence({
    required DateTime template,
    required String frequency,
    required DateTime now,
  }) {
    switch (frequency) {
      case 'daily':
        DateTime next = DateTime(
          now.year,
          now.month,
          now.day,
          template.hour,
          template.minute,
        );
        if (!next.isAfter(now)) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case 'weekly':
        DateTime next = DateTime(
          now.year,
          now.month,
          now.day,
          template.hour,
          template.minute,
        );
        while (next.weekday != template.weekday || !next.isAfter(now)) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case 'monthly':
        DateTime next = _monthlyOccurrence(
          year: now.year,
          month: now.month,
          day: template.day,
          timeSource: template,
        );
        if (!next.isAfter(now)) {
          final int month = now.month == 12 ? 1 : now.month + 1;
          final int year = now.month == 12 ? now.year + 1 : now.year;
          next = _monthlyOccurrence(
            year: year,
            month: month,
            day: template.day,
            timeSource: template,
          );
        }
        return next;
      case 'once':
      default:
        return template;
    }
  }

  static DateTime _monthlyOccurrence({
    required int year,
    required int month,
    required int day,
    required DateTime timeSource,
  }) {
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final int normalizedDay = day.clamp(1, daysInMonth);
    return DateTime(
      year,
      month,
      normalizedDay,
      timeSource.hour,
      timeSource.minute,
    );
  }

  static Future<void> scheduleReminderNotification(Reminder reminder) async {
    if (kIsWeb) {
      return;
    }
    await cancelReminderNotification(reminder.id);

    if (!reminder.remindEnabled || reminder.isCompleted) {
      return;
    }

    final List<ReminderScheduleSlot> slots = buildScheduleSlots(reminder);
    if (slots.isEmpty) {
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'murmur_reminder_channel',
      'Reminder Notifications',
      channelDescription: 'Notifications for fixed reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    for (int slot = 0; slot < slots.length; slot++) {
      final ReminderScheduleSlot schedule = slots[slot];
      await _plugin.zonedSchedule(
        notificationIdForReminderSlot(reminder.id, slot),
        reminder.title,
        notificationBody(reminder),
        tz.TZDateTime.from(schedule.when, tz.local),
        details,
        payload: reminder.id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: schedule.matchComponents,
      );
    }

    ReminderAlarmCoordinator.syncReminder(reminder);
  }

  static Future<void> syncReminderNotification(Reminder reminder) async {
    await scheduleReminderNotification(reminder);
  }

  static Future<void> rescheduleFixedReminders(List<Reminder> reminders) async {
    if (kIsWeb) {
      return;
    }
    await _plugin.cancelAll();
    ReminderAlarmCoordinator.cancelAll();
    for (final Reminder reminder in reminders) {
      if (!reminder.remindEnabled || reminder.isCompleted) {
        continue;
      }
      await scheduleReminderNotification(reminder);
    }
  }
}
