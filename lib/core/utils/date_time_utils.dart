import 'package:intl/intl.dart';
import 'package:murmur/l10n/app_localizations.dart';

class DateTimeUtils {
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');

  static String formatTime(DateTime value) => _timeFormat.format(value);
  static String formatDate(DateTime value) => _dateFormat.format(value);

  static String formatDateTime(DateTime value) => _dateTimeFormat.format(value);

  static DateTime startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime startOfWeek(DateTime value) {
    final DateTime day = startOfDay(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static List<DateTime> daysInWeek(DateTime anchorDay) {
    final DateTime weekStart = startOfWeek(anchorDay);
    return List<DateTime>.generate(
      7,
      (int index) => weekStart.add(Duration(days: index)),
    );
  }

  static String weekdayLabel(int weekday) =>
      AppLocalizationsBinding.instance.weekdayLabel(weekday);

  static String shortWeekdayLabel(int weekday) =>
      AppLocalizationsBinding.instance.shortWeekdayLabel(weekday);
}
