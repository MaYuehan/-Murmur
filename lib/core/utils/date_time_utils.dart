import 'package:intl/intl.dart';

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

  static String weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '周一';
      case DateTime.tuesday:
        return '周二';
      case DateTime.wednesday:
        return '周三';
      case DateTime.thursday:
        return '周四';
      case DateTime.friday:
        return '周五';
      case DateTime.saturday:
        return '周六';
      case DateTime.sunday:
        return '周日';
      default:
        return '';
    }
  }

  static String shortWeekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '一';
      case DateTime.tuesday:
        return '二';
      case DateTime.wednesday:
        return '三';
      case DateTime.thursday:
        return '四';
      case DateTime.friday:
        return '五';
      case DateTime.saturday:
        return '六';
      case DateTime.sunday:
        return '日';
      default:
        return '';
    }
  }
}
