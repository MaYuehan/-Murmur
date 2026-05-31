/// Shared month grid sizing aligned with [table_calendar] (Sunday week start).
class CalendarLayoutUtils {
  CalendarLayoutUtils._();

  /// Fixed height for the 6 week rows — keeps every month the same size.
  static const double weekRowsHeight = 210;

  /// Always reserve 6 rows (matches `sixWeekMonthsEnforced: true`).
  static const double rowHeight = weekRowsHeight / 6;

  static const double daysOfWeekHeight = 16;

  static const double headerHeight = 48;

  static const double innerPadding = 14;

  static double monthCalendarHeight({double outerPadding = 0}) {
    return headerHeight +
        daysOfWeekHeight +
        weekRowsHeight +
        innerPadding +
        outerPadding;
  }

  /// Row count logic copied from table_calendar (StartingDayOfWeek.sunday).
  static int monthWeekRowCount(DateTime month) {
    final DateTime first = DateTime(month.year, month.month);
    final DateTime last = DateTime(month.year, month.month + 1, 0);

    final int daysBefore = _daysBefore(first);
    final int daysAfter = _daysAfter(last);

    final DateTime firstVisible = first.subtract(Duration(days: daysBefore));
    final DateTime lastVisible = last.add(Duration(days: daysAfter));
    return (lastVisible.difference(firstVisible).inDays + 1) ~/ 7;
  }

  static int _daysBefore(DateTime firstDay) {
    return (firstDay.weekday + 7 - 7) % 7;
  }

  static int _daysAfter(DateTime lastDay) {
    const int invertedStartingWeekday = 1;
    final int trailing = 7 - ((lastDay.weekday + invertedStartingWeekday) % 7);
    return trailing == 7 ? 0 : trailing;
  }
}
