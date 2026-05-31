import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/core/utils/notification_service.dart';
import 'package:murmur/core/utils/reminder_storage.dart';
import 'package:murmur/models/reminder.dart';

final initialReminderListProvider =
    Provider<List<Reminder>>((ref) => const <Reminder>[]);

final reminderListProvider =
    StateNotifierProvider<ReminderNotifier, List<Reminder>>(
  (ref) => ReminderNotifier(ref.watch(initialReminderListProvider)),
);

class ReminderNotifier extends StateNotifier<List<Reminder>> {
  ReminderNotifier(List<Reminder> initialState) : super(initialState);

  bool _isLinkedCalendarEntry(Reminder reminder) {
    return reminder.linkedTodoId != null;
  }

  bool _shouldScheduleNotifications(Reminder reminder) {
    if (!reminder.remindEnabled || reminder.isCompleted) {
      return false;
    }
    return !_isLinkedCalendarEntry(reminder);
  }

  Future<void> _scheduleNotificationsIfNeeded(Reminder reminder) async {
    if (_shouldScheduleNotifications(reminder)) {
      await NotificationService.scheduleReminderNotification(reminder);
    }
  }

  Future<void> _cancelReminderNotifications(String reminderId) async {
    await NotificationService.cancelReminderNotification(reminderId);
  }

  Future<void> _cancelLinkedPairNotifications(Reminder reminder) async {
    await _cancelReminderNotifications(reminder.id);
    if (reminder.calendarLinkedId != null) {
      await _cancelReminderNotifications(reminder.calendarLinkedId!);
    }
  }

  bool _shouldRemoveLinkedCalendar({
    required Reminder linkedCalendar,
    DateTime? deadlineAt,
    required bool syncToCalendar,
  }) {
    if (!linkedCalendar.isTodoDeadline) {
      return false;
    }
    if (deadlineAt == null) {
      return true;
    }
    return !syncToCalendar;
  }

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
    List<int> remindRepeatDays = const <int>[],
    String? remindText,
    String? remindVoiceId,
    bool voiceRemindEnabled = false,
    String? notes,
    DateTime? deadlineAt,
    String? calendarLinkedId,
    bool isTodoDeadline = false,
    String? linkedTodoId,
    bool isCompleted = false,
    String? id,
  }) async {
    final DateTime now = DateTime.now();

    final Reminder reminder = Reminder(
      id: id ?? now.microsecondsSinceEpoch.toString(),
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
      remindRepeatDays: remindRepeatDays,
      remindText: remindText,
      remindVoiceId: remindVoiceId,
      voiceRemindEnabled: voiceRemindEnabled,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      deadlineAt: deadlineAt,
      calendarLinkedId: calendarLinkedId,
      isTodoDeadline: isTodoDeadline,
      linkedTodoId: linkedTodoId,
      isCompleted: isCompleted,
      createdAt: now,
    );

    state = <Reminder>[...state, reminder];
    await ReminderStorage.saveReminders(state);

    await _scheduleNotificationsIfNeeded(reminder);
  }

  Future<void> addFlexibleTodo({
    required String title,
    DateTime? deadlineAt,
    bool syncToCalendar = false,
    bool remindEnabled = false,
    DateTime? remindAt,
    String remindFrequency = 'once',
    List<int> remindRepeatDays = const <int>[],
    String? remindText,
    String? remindVoiceId,
    bool voiceRemindEnabled = false,
    String soundId = 'default',
    String? voiceId,
    String? voicePath,
    bool isCustomVoice = false,
  }) async {
    final DateTime now = DateTime.now();
    final String todoId = now.microsecondsSinceEpoch.toString();
    String? calendarLinkedId;

    if (deadlineAt != null && syncToCalendar) {
      calendarLinkedId = '${todoId}_cal';
      await addReminder(
        id: calendarLinkedId,
        title: title,
        scheduledTime: deadlineAt,
        timeType: 'fixed',
        isTodoDeadline: true,
        linkedTodoId: todoId,
        remindEnabled: remindEnabled,
        remindAt: remindAt,
        remindFrequency: remindFrequency,
        remindRepeatDays: remindRepeatDays,
        remindText: remindText,
        remindVoiceId: remindVoiceId,
        voiceRemindEnabled: voiceRemindEnabled,
        soundId: soundId,
        voiceId: voiceId,
        voicePath: voicePath,
        isCustomVoice: isCustomVoice,
      );
    }

    await addReminder(
      id: todoId,
      title: title,
      scheduledTime: null,
      timeType: 'flexible',
      deadlineAt: deadlineAt,
      calendarLinkedId: calendarLinkedId,
      remindEnabled: remindEnabled,
      remindAt: remindAt,
      remindFrequency: remindFrequency,
      remindRepeatDays: remindRepeatDays,
      remindText: remindText,
      remindVoiceId: remindVoiceId,
      voiceRemindEnabled: voiceRemindEnabled,
      soundId: soundId,
      voiceId: voiceId,
      voicePath: voicePath,
      isCustomVoice: isCustomVoice,
    );
  }

  Future<void> updateFlexibleTodo({
    required String reminderId,
    required String title,
    DateTime? deadlineAt,
    bool syncToCalendar = false,
    bool remindEnabled = false,
    DateTime? remindAt,
    String remindFrequency = 'once',
    List<int> remindRepeatDays = const <int>[],
    String? remindText,
    String? remindVoiceId,
    bool voiceRemindEnabled = false,
    String soundId = 'default',
    String? voiceId,
    String? voicePath,
    bool isCustomVoice = false,
  }) async {
    final Reminder? existing = getReminderById(reminderId);
    if (existing == null || !existing.isFlexible) {
      return;
    }

    String? calendarLinkedId = existing.calendarLinkedId;
    final bool wantsDeadlineCalendarSync = syncToCalendar && deadlineAt != null;

    if (calendarLinkedId != null) {
      final Reminder? linkedCalendar = getReminderById(calendarLinkedId);
      if (linkedCalendar != null &&
          _shouldRemoveLinkedCalendar(
            linkedCalendar: linkedCalendar,
            deadlineAt: deadlineAt,
            syncToCalendar: syncToCalendar,
          )) {
        await deleteReminder(calendarLinkedId);
        calendarLinkedId = null;
      }
    } else if (wantsDeadlineCalendarSync) {
      calendarLinkedId = '${reminderId}_cal';
      await addReminder(
        id: calendarLinkedId,
        title: title,
        scheduledTime: deadlineAt,
        timeType: 'fixed',
        isTodoDeadline: true,
        linkedTodoId: reminderId,
        remindEnabled: remindEnabled,
        remindAt: remindAt,
        remindFrequency: remindFrequency,
        remindRepeatDays: remindRepeatDays,
        remindText: remindText,
        remindVoiceId: remindVoiceId,
        voiceRemindEnabled: voiceRemindEnabled,
        soundId: soundId,
        voiceId: voiceId,
        voicePath: voicePath,
        isCustomVoice: isCustomVoice,
      );
    }

    await updateReminder(
      reminderId: reminderId,
      title: title,
      deadlineAt: deadlineAt,
      clearDeadlineAt: deadlineAt == null,
      calendarLinkedId: calendarLinkedId,
      clearCalendarLinkedId: calendarLinkedId == null,
      remindEnabled: remindEnabled,
      remindAt: remindAt,
      clearRemindAt: !remindEnabled || remindAt == null,
      remindFrequency: remindEnabled ? remindFrequency : 'once',
      remindRepeatDays: remindEnabled ? remindRepeatDays : const <int>[],
      clearRemindRepeatDays: !remindEnabled ||
          !ReminderTimeRules.usesRepeatDaySelection(remindFrequency),
      remindText: remindText,
      remindVoiceId: remindVoiceId,
      voiceRemindEnabled: voiceRemindEnabled,
      soundId: soundId,
      voiceId: voiceId,
      voicePath: voicePath,
      isCustomVoice: isCustomVoice,
      syncLinkedCalendar: calendarLinkedId != null,
    );
  }

  List<Reminder> getFixedRemindersByDay(DateTime selectedDay) {
    final DateTime target = DateTimeUtils.startOfDay(selectedDay);

    return state.where((Reminder reminder) {
      if (!reminder.isFixed) {
        return false;
      }
      final DateTime day = DateTimeUtils.startOfDay(reminder.scheduledTime!);
      return day == target;
    }).toList()
      ..sort((Reminder a, Reminder b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (a.isAllDay != b.isAllDay) {
          return a.isAllDay ? -1 : 1;
        }
        return a.scheduledTime!.compareTo(b.scheduledTime!);
      });
  }

  int fixedReminderCountForDay(DateTime day) {
    return getFixedRemindersByDay(day).where((Reminder r) => !r.isCompleted).length;
  }

  List<Reminder> getFixedRemindersForWeek(DateTime anchorDay) {
    final DateTime weekStart = DateTimeUtils.startOfWeek(anchorDay);
    final DateTime weekEnd = weekStart.add(const Duration(days: 7));

    return state.where((Reminder reminder) {
      if (!reminder.isFixed) {
        return false;
      }
      final DateTime day = DateTimeUtils.startOfDay(reminder.scheduledTime!);
      return !day.isBefore(weekStart) && day.isBefore(weekEnd);
    }).toList()
      ..sort((Reminder a, Reminder b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        final int dayCompare = a.scheduledTime!.compareTo(b.scheduledTime!);
        if (dayCompare != 0) {
          return dayCompare;
        }
        if (a.isAllDay != b.isAllDay) {
          return a.isAllDay ? -1 : 1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  List<Reminder> getFlexibleReminders({bool includeCompleted = true}) {
    final List<Reminder> list = state.where((Reminder reminder) {
      if (!reminder.isFlexible) {
        return false;
      }
      if (!includeCompleted && reminder.isCompleted) {
        return false;
      }
      return true;
    }).toList()
      ..sort((Reminder a, Reminder b) {
        if (a.deadlineAt != null && b.deadlineAt == null) {
          return -1;
        }
        if (a.deadlineAt == null && b.deadlineAt != null) {
          return 1;
        }
        if (a.deadlineAt != null && b.deadlineAt != null) {
          final int deadlineCompare = a.deadlineAt!.compareTo(b.deadlineAt!);
          if (deadlineCompare != 0) {
            return deadlineCompare;
          }
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    return list;
  }

  Future<void> syncFlexibleTodoToCalendar({
    required String reminderId,
    DateTime? scheduledTime,
    DateTime? endTime,
    bool isAllDay = false,
  }) async {
    final Reminder? existing = getReminderById(reminderId);
    if (existing == null ||
        !existing.isFlexible ||
        existing.calendarLinkedId != null) {
      return;
    }

    final bool isTodoDeadline = existing.hasDeadline;
    late final DateTime start;
    late final DateTime? finish;
    late final bool allDay;

    if (isTodoDeadline) {
      start = existing.deadlineAt!;
      finish = null;
      allDay = false;
    } else {
      if (scheduledTime == null) {
        return;
      }
      start = scheduledTime;
      finish = endTime ??
          ReminderTimeRules.eventEnd(
            eventDate: DateTimeUtils.startOfDay(scheduledTime),
            isAllDay: isAllDay,
            startDateTime: isAllDay ? null : scheduledTime,
            endDateTime: null,
          );
      allDay = isAllDay;
    }

    final String calendarLinkedId = '${reminderId}_cal';
    await addReminder(
      id: calendarLinkedId,
      title: existing.title,
      scheduledTime: start,
      endTime: finish,
      isAllDay: allDay,
      timeType: 'fixed',
      isTodoDeadline: isTodoDeadline,
      linkedTodoId: reminderId,
      isCompleted: existing.isCompleted,
      remindEnabled: existing.remindEnabled,
      remindAt: existing.remindAt,
      remindFrequency: existing.remindFrequency,
      remindRepeatDays: existing.remindRepeatDays,
      remindText: existing.remindText,
      remindVoiceId: existing.remindVoiceId,
      voiceRemindEnabled: existing.voiceRemindEnabled,
      soundId: existing.soundId,
      voiceId: existing.voiceId,
      voicePath: existing.voicePath,
      isCustomVoice: existing.isCustomVoice,
    );
    await updateReminder(
      reminderId: reminderId,
      calendarLinkedId: calendarLinkedId,
    );
  }

  Future<void> markReminderCompleted(String reminderId) async {
    await setReminderCompleted(reminderId: reminderId, isCompleted: true);
  }

  Future<void> setReminderCompleted({
    required String reminderId,
    required bool isCompleted,
  }) async {
    Reminder? updatedReminder;
    state = state.map((Reminder reminder) {
      if (reminder.id != reminderId) {
        return reminder;
      }
      updatedReminder = reminder.copyWith(isCompleted: isCompleted);
      return updatedReminder!;
    }).toList();

    if (updatedReminder?.calendarLinkedId != null) {
      final String linkedId = updatedReminder!.calendarLinkedId!;
      state = state.map((Reminder reminder) {
        if (reminder.id != linkedId) {
          return reminder;
        }
        return reminder.copyWith(isCompleted: isCompleted);
      }).toList();
    }

    await ReminderStorage.saveReminders(state);

    if (updatedReminder == null) {
      return;
    }

    if (isCompleted) {
      await _cancelLinkedPairNotifications(updatedReminder!);
      return;
    }

    await _scheduleNotificationsIfNeeded(updatedReminder!);
  }

  Future<void> updateReminder({
    required String reminderId,
    String? title,
    DateTime? scheduledTime,
    DateTime? endTime,
    bool clearEndTime = false,
    bool clearScheduledTime = false,
    bool? isAllDay,
    String? timeType,
    String? soundId,
    String? voiceId,
    String? voicePath,
    bool? isCustomVoice,
    String? emotionTag,
    bool? remindEnabled,
    DateTime? remindAt,
    bool clearRemindAt = false,
    String? remindFrequency,
    List<int>? remindRepeatDays,
    bool clearRemindRepeatDays = false,
    String? remindText,
    String? remindVoiceId,
    bool? voiceRemindEnabled,
    String? notes,
    bool clearNotes = false,
    DateTime? deadlineAt,
    bool clearDeadlineAt = false,
    String? calendarLinkedId,
    bool clearCalendarLinkedId = false,
    bool? isTodoDeadline,
    String? linkedTodoId,
    bool clearLinkedTodoId = false,
    bool? isCompleted,
    bool syncLinkedTodo = true,
    bool syncLinkedCalendar = false,
  }) async {
    final Reminder? existing = getReminderById(reminderId);
    if (existing != null) {
      await _cancelLinkedPairNotifications(existing);
    } else {
      await _cancelReminderNotifications(reminderId);
    }

    Reminder? updated;
    state = state.map((Reminder reminder) {
      if (reminder.id != reminderId) {
        return reminder;
      }
      updated = reminder.copyWith(
        title: title,
        scheduledTime: scheduledTime,
        endTime: endTime,
        clearEndTime: clearEndTime,
        clearScheduledTime: clearScheduledTime,
        isAllDay: isAllDay,
        timeType: timeType,
        soundId: soundId,
        voiceId: voiceId,
        voicePath: voicePath,
        isCustomVoice: isCustomVoice,
        emotionTag: emotionTag,
        remindEnabled: remindEnabled,
        remindAt: remindAt,
        clearRemindAt: clearRemindAt,
        remindFrequency: remindFrequency,
        remindRepeatDays: remindRepeatDays,
        clearRemindRepeatDays: clearRemindRepeatDays,
        remindText: remindText,
        remindVoiceId: remindVoiceId,
        voiceRemindEnabled: voiceRemindEnabled,
        notes: notes,
        clearNotes: clearNotes,
        deadlineAt: deadlineAt,
        clearDeadlineAt: clearDeadlineAt,
        calendarLinkedId: calendarLinkedId,
        clearCalendarLinkedId: clearCalendarLinkedId,
        isTodoDeadline: isTodoDeadline,
        linkedTodoId: linkedTodoId,
        clearLinkedTodoId: clearLinkedTodoId,
        isCompleted: isCompleted,
      );
      return updated!;
    }).toList();
    await ReminderStorage.saveReminders(state);
    if (updated != null) {
      await _scheduleNotificationsIfNeeded(updated!);
    }

    if (syncLinkedTodo && updated?.linkedTodoId != null) {
      final Reminder? linkedTodo = getReminderById(updated!.linkedTodoId!);
      if (linkedTodo != null) {
        await _syncFlexibleTodoFromLinkedCalendar(updated!, linkedTodo);
      }
    }

    if (syncLinkedCalendar &&
        updated?.isFlexible == true &&
        updated?.calendarLinkedId != null) {
      await _syncLinkedCalendarFromFlexibleTodo(updated!);
    }
  }

  Future<void> _syncLinkedCalendarFromFlexibleTodo(Reminder todo) async {
    final String? calendarId = todo.calendarLinkedId;
    if (calendarId == null || !todo.isFlexible) {
      return;
    }

    final Reminder? calendar = getReminderById(calendarId);
    if (calendar == null) {
      return;
    }

    final String? notes = todo.notes?.trim();
    final bool remindEnabled = todo.remindEnabled;
    final String frequency = remindEnabled ? todo.remindFrequency : 'once';
    final List<int> repeatDays =
        remindEnabled ? todo.remindRepeatDays : const <int>[];

    if (calendar.isTodoDeadline) {
      await updateReminder(
        reminderId: calendarId,
        title: todo.title,
        scheduledTime: todo.deadlineAt,
        clearEndTime: true,
        isAllDay: false,
        remindEnabled: remindEnabled,
        remindAt: todo.remindAt,
        clearRemindAt: !remindEnabled || todo.remindAt == null,
        remindFrequency: frequency,
        remindRepeatDays: repeatDays,
        clearRemindRepeatDays:
            !remindEnabled || !ReminderTimeRules.usesRepeatDaySelection(frequency),
        remindText: todo.remindText,
        remindVoiceId: todo.remindVoiceId,
        voiceRemindEnabled: todo.voiceRemindEnabled,
        soundId: todo.soundId,
        voiceId: todo.voiceId,
        voicePath: todo.voicePath,
        isCustomVoice: todo.isCustomVoice,
        notes: notes?.isEmpty == true ? null : notes,
        clearNotes: notes == null || notes.isEmpty,
        syncLinkedTodo: false,
      );
      return;
    }

    await updateReminder(
      reminderId: calendarId,
      title: todo.title,
      remindEnabled: remindEnabled,
      remindAt: todo.remindAt,
      clearRemindAt: !remindEnabled || todo.remindAt == null,
      remindFrequency: frequency,
      remindRepeatDays: repeatDays,
      clearRemindRepeatDays:
          !remindEnabled || !ReminderTimeRules.usesRepeatDaySelection(frequency),
      remindText: todo.remindText,
      remindVoiceId: todo.remindVoiceId,
      voiceRemindEnabled: todo.voiceRemindEnabled,
      soundId: todo.soundId,
      voiceId: todo.voiceId,
      voicePath: todo.voicePath,
      isCustomVoice: todo.isCustomVoice,
      notes: notes?.isEmpty == true ? null : notes,
      clearNotes: notes == null || notes.isEmpty,
      syncLinkedTodo: false,
    );
  }

  Future<void> _syncFlexibleTodoFromLinkedCalendar(
    Reminder calendarEntry,
    Reminder linkedTodo,
  ) async {
    if (!linkedTodo.isFlexible) {
      return;
    }

    final String? notes = calendarEntry.notes?.trim();
    final bool remindEnabled = calendarEntry.remindEnabled;
    final String frequency =
        remindEnabled ? calendarEntry.remindFrequency : 'once';
    final List<int> repeatDays =
        remindEnabled ? calendarEntry.remindRepeatDays : const <int>[];

    await updateReminder(
      reminderId: linkedTodo.id,
      title: calendarEntry.title,
      deadlineAt:
          calendarEntry.isTodoDeadline ? calendarEntry.scheduledTime : null,
      remindEnabled: remindEnabled,
      remindAt: calendarEntry.remindAt,
      clearRemindAt: !remindEnabled || calendarEntry.remindAt == null,
      remindFrequency: frequency,
      remindRepeatDays: repeatDays,
      clearRemindRepeatDays: !remindEnabled ||
          !ReminderTimeRules.usesRepeatDaySelection(frequency),
      remindText: calendarEntry.remindText,
      remindVoiceId: calendarEntry.remindVoiceId,
      voiceRemindEnabled: calendarEntry.voiceRemindEnabled,
      soundId: calendarEntry.soundId,
      voiceId: calendarEntry.voiceId,
      voicePath: calendarEntry.voicePath,
      isCustomVoice: calendarEntry.isCustomVoice,
      notes: notes?.isEmpty == true ? null : notes,
      clearNotes: notes == null || notes.isEmpty,
      syncLinkedCalendar: false,
    );
  }

  Future<void> deleteReminder(String reminderId) async {
    final Reminder? target = getReminderById(reminderId);
    if (target?.linkedTodoId != null) {
      await updateReminder(
        reminderId: target!.linkedTodoId!,
        clearCalendarLinkedId: true,
        syncLinkedCalendar: false,
        syncLinkedTodo: false,
      );
    }

    if (target != null && target.calendarLinkedId != null) {
      await _cancelLinkedPairNotifications(target);
    } else {
      await _cancelReminderNotifications(reminderId);
    }

    state = state.where((Reminder reminder) => reminder.id != reminderId).toList();
    await ReminderStorage.saveReminders(state);
  }

  Future<void> unlinkFlexibleTodoFromCalendar({
    required String reminderId,
  }) async {
    final Reminder? existing = getReminderById(reminderId);
    if (existing == null ||
        !existing.isFlexible ||
        existing.calendarLinkedId == null) {
      return;
    }

    await deleteReminder(existing.calendarLinkedId!);
    await updateReminder(
      reminderId: reminderId,
      clearCalendarLinkedId: true,
      syncLinkedCalendar: false,
      syncLinkedTodo: false,
    );
  }

  Future<void> deleteFlexibleTodo({
    required String reminderId,
    bool alsoRemoveFromCalendar = false,
  }) async {
    final Reminder? todo = getReminderById(reminderId);
    if (todo == null) {
      return;
    }

    if (todo.calendarLinkedId != null) {
      await deleteReminder(todo.calendarLinkedId!);
    }

    await deleteReminder(reminderId);
  }

  Future<void> clearCompletedFlexibleReminders({
    bool alsoRemoveFromCalendar = false,
  }) async {
    final List<Reminder> completedTodos = state
        .where(
          (Reminder reminder) => reminder.isFlexible && reminder.isCompleted,
        )
        .toList();
    final List<String> linkedCalendarIds = completedTodos
        .where((Reminder reminder) => reminder.calendarLinkedId != null)
        .map((Reminder reminder) => reminder.calendarLinkedId!)
        .toList();

    for (final Reminder reminder in completedTodos) {
      await _cancelLinkedPairNotifications(reminder);
    }

    state = state.where((Reminder reminder) {
      if (linkedCalendarIds.contains(reminder.id)) {
        return false;
      }
      return !(reminder.isFlexible && reminder.isCompleted);
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

  Reminder? getLinkedTodoForCalendarReminder(String calendarReminderId) {
    final Reminder? calendarReminder = getReminderById(calendarReminderId);
    if (calendarReminder?.linkedTodoId == null) {
      return null;
    }
    return getReminderById(calendarReminder!.linkedTodoId!);
  }
}
