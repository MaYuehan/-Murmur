import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:murmur/core/utils/notification_service.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/services/voice_remind_playback.dart';

class ReminderAlarmCoordinator {
  ReminderAlarmCoordinator._();

  static final Map<String, Timer> _timers = <String, Timer>{};

  static void cancel(String reminderId) {
    final List<String> keys = _timers.keys
        .where((String key) => key == reminderId || key.startsWith('$reminderId#'))
        .toList();
    for (final String key in keys) {
      _timers.remove(key)?.cancel();
    }
  }

  static void syncReminder(Reminder reminder) {
    cancel(reminder.id);
    if (kIsWeb) {
      return;
    }
    if (!reminder.remindEnabled || reminder.isCompleted) {
      return;
    }

    final List<DateTime> scheduleTimes =
        NotificationService.resolveAllScheduleTimes(reminder);
    if (scheduleTimes.isEmpty) {
      return;
    }

    for (int index = 0; index < scheduleTimes.length; index++) {
      final DateTime when = scheduleTimes[index];
      final Duration delay = when.difference(DateTime.now());
      if (delay.isNegative) {
        continue;
      }

      final String timerKey = '${reminder.id}#$index';
      _timers[timerKey] = Timer(delay, () async {
        _timers.remove(timerKey);
        await VoiceRemindPlayback.playForReminder(reminder);
        if (reminder.remindFrequency != 'once') {
          syncReminder(reminder);
        }
      });
    }
  }

  static void rescheduleAll(List<Reminder> reminders) {
    cancelAll();
    for (final Reminder reminder in reminders) {
      syncReminder(reminder);
    }
  }

  static void cancelAll() {
    for (final Timer timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
