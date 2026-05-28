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
}
