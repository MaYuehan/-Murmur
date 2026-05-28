import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:murmur/models/reminder.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

typedef OnNotificationTap = Future<void> Function(String? payload);

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

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

  static Future<void> scheduleReminderNotification(Reminder reminder) async {
    if (kIsWeb) {
      return;
    }
    final DateTime? when = reminder.remindAt ?? reminder.scheduledTime;
    if (when == null || when.isBefore(DateTime.now())) {
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

    await _plugin.zonedSchedule(
      reminder.id.hashCode,
      reminder.title,
      reminder.remindText?.trim().isNotEmpty == true
          ? reminder.remindText!
          : '亲声提醒你该做这件事了',
      tz.TZDateTime.from(when, tz.local),
      details,
      payload: reminder.id,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: _matchComponents(reminder.remindFrequency),
    );
  }

  static Future<void> rescheduleFixedReminders(List<Reminder> reminders) async {
    if (kIsWeb) {
      return;
    }
    await _plugin.cancelAll();
    for (final Reminder reminder in reminders) {
      if (!reminder.remindEnabled) {
        continue;
      }
      final DateTime? when = reminder.remindAt ?? reminder.scheduledTime;
      if (when == null || when.isBefore(DateTime.now())) {
        continue;
      }
      await scheduleReminderNotification(reminder);
    }
  }

  static DateTimeComponents? _matchComponents(String frequency) {
    switch (frequency) {
      case 'daily':
        return DateTimeComponents.time;
      case 'weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'once':
      default:
        return null;
    }
  }
}
