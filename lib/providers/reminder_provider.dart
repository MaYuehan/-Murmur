import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/notification_service.dart';
import 'package:murmur/core/utils/reminder_storage.dart';
import 'package:murmur/core/utils/sound_service.dart';
import 'package:murmur/models/reminder.dart';

final initialReminderListProvider =
    Provider<List<Reminder>>((ref) => const <Reminder>[]);

final reminderListProvider =
    StateNotifierProvider<ReminderNotifier, List<Reminder>>(
  (ref) => ReminderNotifier(ref.watch(initialReminderListProvider)),
);

class ReminderNotifier extends StateNotifier<List<Reminder>> {
  ReminderNotifier(List<Reminder> initialState) : super(initialState);

  Future<void> addReminder({
    required String title,
    DateTime? scheduledTime,
    DateTime? endTime,
    bool isAllDay = false,
    String soundId = 'default',
    String? voiceId,
    String? voicePath,
    bool isCustomVoice = false,
    String? timeType,
    String? emotionTag,
    bool remindEnabled = false,
    DateTime? remindAt,
    String remindFrequency = 'once',
    String? remindText,
    String? remindVoiceId,
  }) async {
    final DateTime now = DateTime.now();

    final Reminder reminder = Reminder(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim(),
      scheduledTime: scheduledTime,
      endTime: endTime,
      isAllDay: isAllDay,
      timeType: timeType ?? (scheduledTime != null ? 'fixed' : 'flexible'),
      soundId: soundId,
      voiceId: voiceId,
      voicePath: voicePath,
      isCustomVoice: isCustomVoice,
      emotionTag: emotionTag,
      remindEnabled: remindEnabled,
      remindAt: remindAt,
      remindFrequency: remindFrequency,
      remindText: remindText,
      remindVoiceId: remindVoiceId,
      isCompleted: false,
      createdAt: now,
    );

    state = <Reminder>[...state, reminder];
    await ReminderStorage.saveReminders(state);

    if (reminder.remindEnabled) {
      await NotificationService.scheduleReminderNotification(reminder);
    } else {
      SoundService.play(reminder.soundId);
    }
  }

  List<Reminder> getFixedRemindersByDay(DateTime selectedDay) {
    final DateTime target = DateTimeUtils.startOfDay(selectedDay);

    return state.where((Reminder reminder) {
      final DateTime? scheduled = reminder.scheduledTime;
      if (scheduled == null) {
        return false;
      }
      final DateTime day = DateTimeUtils.startOfDay(scheduled);
      return day == target;
    }).toList()
      ..sort((Reminder a, Reminder b) {
        if (a.isAllDay != b.isAllDay) {
          return a.isAllDay ? -1 : 1;
        }
        return a.scheduledTime!.compareTo(b.scheduledTime!);
      });
  }

  int fixedReminderCountForDay(DateTime day) {
    return getFixedRemindersByDay(day).length;
  }

  List<Reminder> getFlexibleReminders({bool includeCompleted = true}) {
    final List<Reminder> list = state.where((Reminder reminder) {
      final bool isFlexible = reminder.scheduledTime == null;
      if (!isFlexible) {
        return false;
      }
      if (!includeCompleted && reminder.isCompleted) {
        return false;
      }
      return true;
    }).toList()
      ..sort((Reminder a, Reminder b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<void> promoteReminderToFixed({
    required String reminderId,
    required DateTime scheduledTime,
  }) async {
    Reminder? updated;
    state = state.map((Reminder reminder) {
      if (reminder.id != reminderId) {
        return reminder;
      }
      updated = reminder.copyWith(
        scheduledTime: scheduledTime,
        isAllDay: false,
        timeType: 'fixed',
        remindEnabled: true,
      );
      return updated!;
    }).toList();
    await ReminderStorage.saveReminders(state);
    if (updated != null && updated!.remindEnabled) {
      await NotificationService.scheduleReminderNotification(updated!);
    }
  }

  Future<void> markReminderCompleted(String reminderId) async {
    state = state.map((Reminder reminder) {
      if (reminder.id != reminderId) {
        return reminder;
      }
      return reminder.copyWith(isCompleted: true);
    }).toList();
    await ReminderStorage.saveReminders(state);
  }

  Future<void> setReminderCompleted({
    required String reminderId,
    required bool isCompleted,
  }) async {
    state = state.map((Reminder reminder) {
      if (reminder.id != reminderId) {
        return reminder;
      }
      return reminder.copyWith(isCompleted: isCompleted);
    }).toList();
    await ReminderStorage.saveReminders(state);
  }

  Future<void> updateReminder({
    required String reminderId,
    String? title,
    DateTime? scheduledTime,
    bool clearScheduledTime = false,
    String? timeType,
    String? voiceId,
    String? voicePath,
  }) async {
    Reminder? updated;
    state = state.map((Reminder reminder) {
      if (reminder.id != reminderId) {
        return reminder;
      }
      updated = reminder.copyWith(
        title: title,
        scheduledTime: scheduledTime,
        clearScheduledTime: clearScheduledTime,
        timeType: timeType,
        voiceId: voiceId,
        voicePath: voicePath,
      );
      return updated!;
    }).toList();
    await ReminderStorage.saveReminders(state);
    if (updated != null && updated!.isFixed) {
      await NotificationService.scheduleReminderNotification(updated!);
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    state = state.where((Reminder reminder) => reminder.id != reminderId).toList();
    await ReminderStorage.saveReminders(state);
  }

  Future<void> clearCompletedFlexibleReminders() async {
    state = state.where((Reminder reminder) {
      final bool isFlexible = reminder.scheduledTime == null;
      return !(isFlexible && reminder.isCompleted);
    }).toList();
    await ReminderStorage.saveReminders(state);
  }

  Reminder? getReminderById(String id) {
    for (final Reminder reminder in state) {
      if (reminder.id == id) {
        return reminder;
      }
    }
    return null;
  }
}
