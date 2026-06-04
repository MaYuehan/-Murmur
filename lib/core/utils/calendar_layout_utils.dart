/// Month grid sizing aligned with [table_calendar] row-count logic.
class CalendarLayoutUtils {
  CalendarLayoutUtils._();

  /// Per-week row height used in month calendar UIs.
  static const double monthRowHeight = 52;

  static const double daysOfWeekHeight = 16;

  static const double headerHeight = 48;

  static const double innerPadding = 14;

  /// Week rows only (no weekday header).
  static double monthGridHeight(
    DateTime month, {
    required bool weekStartsOnMonday,
  }) {
    final int rows = monthWeekRowCount(
      month,
      weekStartsOnMonday: weekStartsOnMonday,
    );
    return daysOfWeekHeight + rows * monthRowHeight;
  }

  static double monthCalendarHeight(
    DateTime month, {
    required bool weekStartsOnMonday,
    double outerPadding = 0,
  }) {
    return headerHeight +
        monthGridHeight(month, weekStartsOnMonday: weekStartsOnMonday) +
        innerPadding +
        outerPadding;
  }

  /// Matches table_calendar when [sixWeekMonthsEnforced] is false.
  static int monthWeekRowCount(
    DateTime month, {
    required bool weekStartsOnMonday,
  }) {
    final DateTime first = DateTime(month.year, month.month);
    final DateTime last = DateTime(month.year, month.month + 1, 0);

    final int startingWeekday = weekStartsOnMonday ? 1 : 7;
    final int daysBefore = _daysBefore(first, startingWeekday);
    final int daysAfter = _daysAfter(last, startingWeekday);

    final DateTime firstVisible = first.subtract(Duration(days: daysBefore));
    final DateTime lastVisible = last.add(Duration(days: daysAfter));
    return (lastVisible.difference(firstVisible).inDays + 1) ~/ 7;
  }

  static int _daysBefore(DateTime firstDay, int startingWeekday) {
    return (firstDay.weekday + 7 - startingWeekday) % 7;
  }

  static int _daysAfter(DateTime lastDay, int startingWeekday) {
    final int invertedStartingWeekday = 8 - startingWeekday;
    final int trailing = 7 - ((lastDay.weekday + invertedStartingWeekday) % 7);
    return trailing == 7 ? 0 : trailing;
  }
}
