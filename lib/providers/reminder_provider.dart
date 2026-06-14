import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/core/utils/notification_service.dart';
import 'package:murmur/core/utils/list_sort_order.dart';
import 'package:murmur/core/utils/reminder_storage.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/models/todo_sub_item.dart';

final initialReminderListProvider =
    Provider<List<Reminder>>((ref) => const <Reminder>[]);

final reminderListProvider =
    StateNotifierProvider<ReminderNotifier, List<Reminder>>(
  (ref) => ReminderNotifier(ref.watch(initialReminderListProvider)),
);

class ReminderNotifier extends StateNotifier<List<Reminder>> {
  ReminderNotifier(List<Reminder> initialState)
      : super(_normalizeReminders(initialState));

  static List<Reminder> _normalizeReminders(List<Reminder> reminders) {
    return reminders
        .map(
          (Reminder reminder) => reminder.copyWith(
            sortOrder: reminder.sortOrder,
            subItems: reminder.subItems
                .map(
                  (TodoSubItem item) => item.copyWith(sortOrder: item.sortOrder),
                )
                .toList(),
          ),
        )
        .toList();
  }

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
    String? todoGroupId,
    bool isCompleted = false,
    String? id,
    DateTime? createdAt,
    int? sortOrder,
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
      todoGroupId: todoGroupId,
      isCompleted: isCompleted,
      createdAt: createdAt ?? now,
      sortOrder: sortOrder,
    );

    state = <Reminder>[...state, reminder];
    await ReminderStorage.saveReminders(state);

    await _scheduleNotificationsIfNeeded(reminder);
  }

  Future<String> addFlexibleTodo({
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
    String? notes,
    String? todoGroupId,
    int? sortOrder,
  }) async {
    final String todoId = DateTime.now().microsecondsSinceEpoch.toString();
    String? calendarLinkedId;
    final String? normalizedNotes =
        notes?.trim().isEmpty == true ? null : notes?.trim();

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
        notes: normalizedNotes,
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
      notes: normalizedNotes,
      todoGroupId: todoGroupId,
      sortOrder: sortOrder,
    );
    return todoId;
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
    String? notes,
    String? todoGroupId,
    bool clearTodoGroupId = false,
  }) async {
    final Reminder? existing = getReminderById(reminderId);
    if (existing == null || !existing.isFlexible) {
      return;
    }

    String? calendarLinkedId = existing.calendarLinkedId;
    final bool wantsDeadlineCalendarSync = syncToCalendar && deadlineAt != null;
    final String? normalizedNotes =
        notes?.trim().isEmpty == true ? null : notes?.trim();

    if (calendarLinkedId != null) {
      final Reminder? linkedCalendar = getReminderById(calendarLinkedId);
      if (linkedCalendar != null) {
        // Deadline todo with sync turned off should remove linked calendar entry.
        if (deadlineAt != null && !syncToCalendar) {
          await deleteReminder(calendarLinkedId);
          calendarLinkedId = null;
        }

        if (calendarLinkedId != null) {
          // Convert linked calendar entry to deadline mode when todo becomes a deadline.
          if (deadlineAt != null && !linkedCalendar.isTodoDeadline) {
            await updateReminder(
              reminderId: calendarLinkedId,
              isTodoDeadline: true,
              scheduledTime: deadlineAt,
              clearEndTime: true,
              isAllDay: false,
              syncLinkedTodo: false,
            );
          }

          // Convert linked deadline entry back to normal calendar entry when deadline is removed.
          if (deadlineAt == null && linkedCalendar.isTodoDeadline) {
            final DateTime fallbackStart =
                linkedCalendar.scheduledTime ?? DateTime.now();
            await updateReminder(
              reminderId: calendarLinkedId,
              isTodoDeadline: false,
              scheduledTime: fallbackStart,
              endTime:
                  linkedCalendar.endTime ?? fallbackStart.add(const Duration(hours: 1)),
              isAllDay: false,
              syncLinkedTodo: false,
            );
          }
        }
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
        notes: normalizedNotes,
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
      notes: normalizedNotes,
      clearNotes: normalizedNotes == null,
      todoGroupId: todoGroupId,
      clearTodoGroupId: clearTodoGroupId,
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
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return list;
  }

  Future<void> reorderFlexibleTodoInList({
    required List<Reminder> listContext,
    required int fromIndex,
    required int toIndex,
  }) async {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= listContext.length ||
        toIndex >= listContext.length) {
      return;
    }

    final List<Reminder> items = List<Reminder>.from(listContext);
    final Reminder moved = items.removeAt(fromIndex);
    items.insert(toIndex, moved);

    final int newSortOrder;
    if (items.length == 1) {
      newSortOrder = moved.sortOrder;
    } else if (toIndex == 0) {
      newSortOrder = ListSortOrder.beforeFirst(items[1].sortOrder);
    } else if (toIndex == items.length - 1) {
      newSortOrder = ListSortOrder.afterLast(items[toIndex - 1].sortOrder);
    } else {
      newSortOrder = ListSortOrder.betweenOrdered(
        items[toIndex - 1].sortOrder,
        items[toIndex + 1].sortOrder,
      );
    }

    DateTime? newDeadlineAt;
    bool deadlineChanged = false;
    if (moved.hasDeadline) {
      DateTime? targetDeadline;
      if (toIndex > 0) {
        targetDeadline = items[toIndex - 1].deadlineAt;
      } else if (items.length > 1) {
        targetDeadline = items[1].deadlineAt;
      }
      if (targetDeadline != null &&
          moved.deadlineAt?.compareTo(targetDeadline) != 0) {
        newDeadlineAt = targetDeadline;
        deadlineChanged = true;
      }
    }

    await updateReminder(
      reminderId: moved.id,
      sortOrder: newSortOrder,
      deadlineAt: deadlineChanged ? newDeadlineAt : null,
      syncLinkedCalendar: deadlineChanged && moved.isSyncedToCalendar,
    );
  }

  Future<void> moveFlexibleTodoToInsertIndex({
    required String reminderId,
    required List<Reminder> targetList,
    required int insertIndex,
    String? targetTodoGroupId,
  }) async {
    final Reminder? moved = getReminderById(reminderId);
    if (moved == null || !moved.isFlexible || moved.hasDeadline) {
      return;
    }

    final List<Reminder> items = List<Reminder>.from(targetList);
    final int existingIndex =
        items.indexWhere((Reminder item) => item.id == reminderId);
    if (existingIndex >= 0) {
      items.removeAt(existingIndex);
    }

    int toIndex = insertIndex;
    if (existingIndex >= 0 && existingIndex < insertIndex) {
      toIndex = insertIndex - 1;
    }
    if (toIndex < 0) {
      toIndex = 0;
    }
    if (toIndex > items.length) {
      toIndex = items.length;
    }

    final bool sameMembership = moved.todoGroupId == targetTodoGroupId;
    if (existingIndex >= 0 && toIndex == existingIndex && sameMembership) {
      return;
    }

    items.insert(toIndex, moved);

    final int newSortOrder;
    if (items.length == 1) {
      newSortOrder = moved.sortOrder;
    } else if (toIndex == 0) {
      newSortOrder = ListSortOrder.beforeFirst(items[1].sortOrder);
    } else if (toIndex == items.length - 1) {
      newSortOrder = ListSortOrder.afterLast(items[toIndex - 1].sortOrder);
    } else {
      newSortOrder = ListSortOrder.betweenOrdered(
        items[toIndex - 1].sortOrder,
        items[toIndex + 1].sortOrder,
      );
    }

    await updateReminder(
      reminderId: reminderId,
      sortOrder: newSortOrder,
      todoGroupId: targetTodoGroupId,
      clearTodoGroupId: targetTodoGroupId == null,
    );
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
      notes: existing.notes,
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
    bool syncSubItems = true,
  }) async {
    Reminder? updatedReminder;
    state = state.map((Reminder reminder) {
      if (reminder.id != reminderId) {
        return reminder;
      }
      List<TodoSubItem> subItems = reminder.subItems;
      if (syncSubItems && subItems.isNotEmpty) {
        subItems = subItems
            .map((TodoSubItem item) => item.copyWith(isCompleted: isCompleted))
            .toList();
      }
      updatedReminder = reminder.copyWith(
        isCompleted: isCompleted,
        completedAt: isCompleted ? DateTime.now() : null,
        clearCompletedAt: !isCompleted,
        subItems: subItems,
      );
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
    String? todoGroupId,
    bool clearTodoGroupId = false,
    int? sortOrder,
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
        todoGroupId: todoGroupId,
        clearTodoGroupId: clearTodoGroupId,
        sortOrder: sortOrder,
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

  Future<void> clearTodoGroupMembership(String groupId) async {
    state = state
        .map((Reminder reminder) {
          if (reminder.todoGroupId == groupId) {
            return reminder.copyWith(clearTodoGroupId: true);
          }
          return reminder;
        })
        .toList();
    await ReminderStorage.saveReminders(state);
  }

  Future<void> deleteFlexibleTodosInGroup(String groupId) async {
    final List<Reminder> groupTodos = state
        .where(
          (Reminder reminder) =>
              reminder.isFlexible && reminder.todoGroupId == groupId,
        )
        .toList();
    for (final Reminder todo in groupTodos) {
      await deleteFlexibleTodo(reminderId: todo.id);
    }
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

  Future<String> addTodoSubItem({
    required String parentId,
    required String title,
    int? sortOrder,
  }) async {
    final Reminder? parent = getReminderById(parentId);
    if (parent == null || !parent.isFlexible) {
      return '';
    }
    final String itemId = DateTime.now().microsecondsSinceEpoch.toString();
    final TodoSubItem item = TodoSubItem(
      id: itemId,
      title: title,
      sortOrder: sortOrder,
    );
    final List<TodoSubItem> subItems = <TodoSubItem>[...parent.subItems, item]
      ..sort((TodoSubItem a, TodoSubItem b) => a.sortOrder.compareTo(b.sortOrder));
    await _saveTodoSubItems(parentId: parentId, subItems: subItems);
    return itemId;
  }

  Future<String> insertTodoSubItemAfter({
    required String parentId,
    required int afterIndex,
    required List<TodoSubItem> listContext,
    String title = '',
  }) async {
    final List<int> orders =
        listContext.map((TodoSubItem item) => item.sortOrder).toList();
    final int order = ListSortOrder.forInsertAfter(orders, afterIndex);
    return addTodoSubItem(parentId: parentId, title: title, sortOrder: order);
  }

  Future<void> updateTodoSubItemTitle({
    required String parentId,
    required String subItemId,
    required String title,
  }) async {
    final Reminder? parent = getReminderById(parentId);
    if (parent == null || !parent.isFlexible) {
      return;
    }
    final String trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final List<TodoSubItem> subItems = parent.subItems
        .map((TodoSubItem item) {
          if (item.id != subItemId) {
            return item;
          }
          return item.copyWith(title: trimmed);
        })
        .toList();
    await _saveTodoSubItems(parentId: parentId, subItems: subItems);
  }

  Future<void> toggleTodoSubItemCompleted({
    required String parentId,
    required String subItemId,
    required bool isCompleted,
  }) async {
    final Reminder? parent = getReminderById(parentId);
    if (parent == null || !parent.isFlexible) {
      return;
    }
    final List<TodoSubItem> subItems = parent.subItems
        .map((TodoSubItem item) {
          if (item.id != subItemId) {
            return item;
          }
          return item.copyWith(isCompleted: isCompleted);
        })
        .toList();
    await _saveTodoSubItems(parentId: parentId, subItems: subItems);
  }

  Future<void> deleteTodoSubItem({
    required String parentId,
    required String subItemId,
  }) async {
    await deleteTodoSubItems(parentId: parentId, subItemIds: <String>[subItemId]);
  }

  Future<void> deleteTodoSubItems({
    required String parentId,
    required List<String> subItemIds,
  }) async {
    if (subItemIds.isEmpty) {
      return;
    }
    final Reminder? parent = getReminderById(parentId);
    if (parent == null || !parent.isFlexible) {
      return;
    }
    final Set<String> ids = subItemIds.toSet();
    final List<TodoSubItem> subItems =
        parent.subItems.where((TodoSubItem item) => !ids.contains(item.id)).toList();
    await _saveTodoSubItems(parentId: parentId, subItems: subItems);
  }

  Future<void> _saveTodoSubItems({
    required String parentId,
    required List<TodoSubItem> subItems,
  }) async {
    Reminder? updated;
    state = state.map((Reminder reminder) {
      if (reminder.id != parentId) {
        return reminder;
      }
      updated = reminder.copyWith(subItems: subItems);
      return updated!;
    }).toList();
    await ReminderStorage.saveReminders(state);

    if (updated == null || subItems.isEmpty) {
      return;
    }

    final bool allDone = updated!.allSubItemsCompleted;
    if (allDone != updated!.isCompleted) {
      await setReminderCompleted(
        reminderId: parentId,
        isCompleted: allDone,
        syncSubItems: false,
      );
    }
  }
}
