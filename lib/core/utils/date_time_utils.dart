import 'package:intl/intl.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/l10n/app_localizations.dart';

class DateTimeUtils {
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm');
  static final DateFormat _cardDateZhFormat = DateFormat('yyyy年M月d日', 'zh');
  static final DateFormat _cardDateEnFormat = DateFormat('MMM d, yyyy', 'en_US');

  static bool get _isZh => AppLocalizationsBinding.instance.isZh;

  static String formatTime(DateTime value) => _timeFormat.format(value);
  static String formatDate(DateTime value) => _dateFormat.format(value);

  static String formatDateTime(DateTime value) => _dateTimeFormat.format(value);

  /// Card display: `2026年5月1日` / `May 1, 2026`
  static String formatCardDate(DateTime value) {
    if (_isZh) {
      return _cardDateZhFormat.format(value);
    }
    return _cardDateEnFormat.format(value);
  }

  /// Card display: `2026年5月1日 · 13:30` / `May 1, 2026 · 13:30`
  static String formatCardDateTime(DateTime value) {
    return '${formatCardDate(value)} · ${formatTime(value)}';
  }

  static DateTime startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  /// Calendar days from today to [target] (positive = future).
  static int calendarDaysUntil(DateTime target) {
    return startOfDay(target).difference(startOfDay(DateTime.now())).inDays;
  }

  static DateTime startOfWeek(DateTime value) {
    final DateTime day = startOfDay(value);
    if (AppSettingsStorage.weekStartsOnMonday) {
      return day.subtract(Duration(days: day.weekday - DateTime.monday));
    }
    return day.subtract(Duration(days: day.weekday % 7));
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
