import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/core/utils/completed_todo_section.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/models/reminder.dart';

enum ClearCompletedScope {
  all,
  beforeThisWeek,
  beforeThisMonth,
}

class ClearCompletedScopeUtils {
  ClearCompletedScopeUtils._();

  static DateTime cutoffBeforeThisWeek(DateTime now) {
    final DateTime weekStart = DateTimeUtils.startOfWeek(
      DateTimeUtils.startOfDay(now),
    );
    if (AppSettingsStorage.weekStartsOnMonday) {
      return weekStart.subtract(const Duration(days: 1));
    }
    return weekStart.subtract(const Duration(days: 7));
  }

  static DateTime cutoffBeforeThisMonth(DateTime now) {
    final DateTime today = DateTimeUtils.startOfDay(now);
    return DateTime(today.year, today.month, 1)
        .subtract(const Duration(days: 1));
  }

  static bool matches(
    Reminder reminder, {
    required ClearCompletedScope scope,
    DateTime? now,
  }) {
    if (!reminder.isCompleted) {
      return false;
    }
    if (scope == ClearCompletedScope.all) {
      return true;
    }

    final DateTime completionDay = CompletedTodoSectionUtils.completionDay(reminder);
    final DateTime reference = DateTimeUtils.startOfDay(now ?? DateTime.now());
    final DateTime cutoff = scope == ClearCompletedScope.beforeThisWeek
        ? cutoffBeforeThisWeek(reference)
        : cutoffBeforeThisMonth(reference);
    return !completionDay.isAfter(cutoff);
  }

  static int countMatching(
    Iterable<Reminder> completed, {
    required ClearCompletedScope scope,
    DateTime? now,
  }) {
    return completed
        .where(
          (Reminder reminder) => matches(
            reminder,
            scope: scope,
            now: now,
          ),
        )
        .length;
  }
}
