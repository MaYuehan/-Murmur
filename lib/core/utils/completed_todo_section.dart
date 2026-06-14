import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';

enum CompletedTodoSection {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  earlier,
}

class CompletedTodoSectionUtils {
  CompletedTodoSectionUtils._();

  static const List<CompletedTodoSection> displayOrder = <CompletedTodoSection>[
    CompletedTodoSection.today,
    CompletedTodoSection.yesterday,
    CompletedTodoSection.thisWeek,
    CompletedTodoSection.thisMonth,
    CompletedTodoSection.earlier,
  ];

  static DateTime completionDay(Reminder reminder) {
    return DateTimeUtils.startOfDay(reminder.completedAt ?? reminder.createdAt);
  }

  static CompletedTodoSection sectionFor(
    DateTime completionDay, {
    DateTime? now,
  }) {
    final DateTime today = DateTimeUtils.startOfDay(now ?? DateTime.now());

    if (completionDay == today) {
      return CompletedTodoSection.today;
    }

    final DateTime yesterday = today.subtract(const Duration(days: 1));
    if (completionDay == yesterday) {
      return CompletedTodoSection.yesterday;
    }

    final DateTime weekStart = DateTimeUtils.startOfWeek(today);
    final DateTime weekEnd = weekStart.add(const Duration(days: 7));
    if (!completionDay.isBefore(weekStart) && completionDay.isBefore(weekEnd)) {
      return CompletedTodoSection.thisWeek;
    }

    final DateTime monthStart = DateTime(today.year, today.month, 1);
    final DateTime monthEnd = DateTime(today.year, today.month + 1, 1);
    if (!completionDay.isBefore(monthStart) && completionDay.isBefore(monthEnd)) {
      return CompletedTodoSection.thisMonth;
    }

    return CompletedTodoSection.earlier;
  }

  static Map<CompletedTodoSection, List<Reminder>> groupCompleted(
    List<Reminder> completed, {
    DateTime? now,
  }) {
    final Map<CompletedTodoSection, List<Reminder>> groups =
        <CompletedTodoSection, List<Reminder>>{};
    for (final Reminder reminder in completed) {
      final CompletedTodoSection section =
          sectionFor(completionDay(reminder), now: now);
      groups.putIfAbsent(section, () => <Reminder>[]).add(reminder);
    }
    return groups;
  }

  static String sectionTitle(
    CompletedTodoSection section,
    AppLocalizations l10n,
  ) {
    switch (section) {
      case CompletedTodoSection.today:
        return l10n.todoCompletedSectionToday;
      case CompletedTodoSection.yesterday:
        return l10n.todoCompletedSectionYesterday;
      case CompletedTodoSection.thisWeek:
        return l10n.todoCompletedSectionThisWeek;
      case CompletedTodoSection.thisMonth:
        return l10n.todoCompletedSectionThisMonth;
      case CompletedTodoSection.earlier:
        return l10n.todoCompletedSectionEarlier;
    }
  }

  static String sectionKey(CompletedTodoSection section) {
    switch (section) {
      case CompletedTodoSection.today:
        return 'today';
      case CompletedTodoSection.yesterday:
        return 'yesterday';
      case CompletedTodoSection.thisWeek:
        return 'this_week';
      case CompletedTodoSection.thisMonth:
        return 'this_month';
      case CompletedTodoSection.earlier:
        return 'earlier';
    }
  }
}
