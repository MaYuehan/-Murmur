import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/l10n/app_localizations.dart';

class ReminderTimeRules {
  static const String offsetAtTime = 'at_time';
  static const String offsetBefore15m = 'before_15m';
  static const String offsetBefore1h = 'before_1h';
  static const String offsetCustom = 'custom';

  static DateTime eventStart({
    required DateTime eventDate,
    required bool isAllDay,
    required DateTime? startDateTime,
  }) {
    if (isAllDay) {
      return DateTime(eventDate.year, eventDate.month, eventDate.day);
    }
    return startDateTime!;
  }

  static DateTime eventEnd({
    required DateTime eventDate,
    required bool isAllDay,
    required DateTime? startDateTime,
    required DateTime? endDateTime,
  }) {
    if (isAllDay) {
      return DateTime(eventDate.year, eventDate.month, eventDate.day, 23, 59);
    }
    if (endDateTime != null && endDateTime.isAfter(startDateTime!)) {
      return endDateTime;
    }
    return startDateTime!.add(const Duration(hours: 1));
  }

  static DateTime combineDateAndTime(DateTime date, DateTime timeSource) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      timeSource.hour,
      timeSource.minute,
    );
  }

  static DateTime? computeRemindAt({
    required bool remindEnabled,
    required String offset,
    DateTime? customRemindAt,
    required DateTime eventDate,
    required bool isAllDay,
    required DateTime? startDateTime,
  }) {
    if (!remindEnabled) {
      return null;
    }
    if (offset == offsetCustom) {
      return customRemindAt;
    }

    final DateTime base = isAllDay
        ? DateTime(eventDate.year, eventDate.month, eventDate.day, 9, 0)
        : startDateTime!;

    switch (offset) {
      case offsetBefore15m:
        return base.subtract(const Duration(minutes: 15));
      case offsetBefore1h:
        return base.subtract(const Duration(hours: 1));
      case offsetAtTime:
      default:
        return base;
    }
  }

  static String offsetLabel(String offset) {
    final AppLocalizations l10n = AppLocalizationsBinding.instance;
    switch (offset) {
      case offsetBefore15m:
        return l10n.remindOffsetBefore15m;
      case offsetBefore1h:
        return l10n.remindOffsetBefore1h;
      case offsetCustom:
        return l10n.remindOffsetCustom;
      case offsetAtTime:
      default:
        return l10n.remindOffsetOnTime;
    }
  }

  static String frequencyLabel(String frequency) {
    final AppLocalizations l10n = AppLocalizationsBinding.instance;
    switch (frequency) {
      case 'daily':
        return l10n.remindFrequencyDaily;
      case 'weekly':
        return l10n.remindFrequencyWeekly;
      case 'monthly':
        return l10n.remindFrequencyMonthly;
      case 'once':
      default:
        return l10n.remindFrequencyOnce;
    }
  }

  static bool isRepeatingFrequency(String frequency) {
    return frequency == 'daily' ||
        frequency == 'weekly' ||
        frequency == 'monthly';
  }

  static bool usesTimeOnlyCustomPicker(String frequency) {
    return frequency == 'daily';
  }

  static bool usesRepeatDaySelection(String frequency) {
    return frequency == 'weekly' || frequency == 'monthly';
  }

  static List<int> effectiveRepeatDays({
    required String frequency,
    required List<int> repeatDays,
    DateTime? remindAt,
  }) {
    if (repeatDays.isNotEmpty) {
      return List<int>.from(repeatDays)..sort();
    }
    if (remindAt == null) {
      return const <int>[];
    }
    switch (frequency) {
      case 'weekly':
        return <int>[remindAt.weekday];
      case 'monthly':
        return <int>[remindAt.day];
      default:
        return const <int>[];
    }
  }

  static String formatRepeatDaysLabel({
    required String frequency,
    required List<int> repeatDays,
    DateTime? remindAt,
  }) {
    final List<int> days = effectiveRepeatDays(
      frequency: frequency,
      repeatDays: repeatDays,
      remindAt: remindAt,
    );
    if (days.isEmpty) {
      return AppLocalizationsBinding.instance.commonPleaseSelect;
    }
    if (frequency == 'weekly') {
      final String separator =
          AppLocalizationsBinding.instance.isZh ? '、' : ', ';
      return days.map(DateTimeUtils.weekdayLabel).join(separator);
    }
    if (frequency == 'monthly') {
      return days.map((int day) => '$day').join('、');
    }
    return '';
  }

  static String remindPreviewLabel({
    required DateTime? remindAt,
    required String frequency,
    List<int> repeatDays = const <int>[],
  }) {
    if (remindAt == null) {
      return '';
    }
    final AppLocalizations l10n = AppLocalizationsBinding.instance;
    final String time = DateTimeUtils.formatTime(remindAt);
    switch (frequency) {
      case 'daily':
        return l10n.remindPreviewDaily(time);
      case 'weekly':
        final List<int> days = effectiveRepeatDays(
          frequency: frequency,
          repeatDays: repeatDays,
          remindAt: remindAt,
        );
        if (days.isEmpty) {
          return l10n.remindPreviewWeeklyNeedDays;
        }
        final String separator = l10n.isZh ? '、' : ', ';
        return l10n.remindPreviewWeekly(
          days.map(DateTimeUtils.weekdayLabel).join(separator),
          time,
        );
      case 'monthly':
        final List<int> days = effectiveRepeatDays(
          frequency: frequency,
          repeatDays: repeatDays,
          remindAt: remindAt,
        );
        if (days.isEmpty) {
          return l10n.remindPreviewMonthlyNeedDays;
        }
        final String separator = l10n.isZh ? '、' : ', ';
        return l10n.remindPreviewMonthly(days.join(separator), time);
      case 'once':
      default:
        return l10n.remindPreviewOnce(DateTimeUtils.formatCardDateTime(remindAt));
    }
  }

  static String customRemindTileValue({
    required DateTime? remindAt,
    required String frequency,
    List<int> repeatDays = const <int>[],
  }) {
    if (remindAt == null) {
      return AppLocalizationsBinding.instance.commonPleaseSelect;
    }
    if (frequency == 'once') {
      return DateTimeUtils.formatDateTime(remindAt);
    }
    if (frequency == 'daily') {
      return DateTimeUtils.formatTime(remindAt);
    }
    if (frequency == 'weekly' || frequency == 'monthly') {
      final String days = formatRepeatDaysLabel(
        frequency: frequency,
        repeatDays: repeatDays,
        remindAt: remindAt,
      );
      return '$days ${DateTimeUtils.formatTime(remindAt)}';
    }
    return DateTimeUtils.formatDateTime(remindAt);
  }

  static List<int> defaultRepeatDaysForFrequency({
    required String frequency,
    DateTime? anchorDate,
  }) {
    final DateTime anchor = anchorDate ?? DateTime.now();
    switch (frequency) {
      case 'weekly':
        return <int>[anchor.weekday];
      case 'monthly':
        return <int>[anchor.day];
      default:
        return const <int>[];
    }
  }

  static DateTime normalizeCustomRemindForFrequency({
    required DateTime current,
    required String frequency,
    DateTime? anchorDate,
  }) {
    if (frequency == 'once') {
      return current;
    }

    final DateTime anchor = DateTimeUtils.startOfDay(anchorDate ?? current);
    return DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
      current.hour,
      current.minute,
    );
  }

  static String inferOffsetFromRemindAt({
    required bool remindEnabled,
    required DateTime? remindAt,
    required DateTime eventBase,
  }) {
    if (!remindEnabled || remindAt == null) {
      return offsetAtTime;
    }

    final Duration diff = eventBase.difference(remindAt);
    if (diff == Duration.zero) {
      return offsetAtTime;
    }
    if (diff == const Duration(minutes: 15)) {
      return offsetBefore15m;
    }
    if (diff == const Duration(hours: 1)) {
      return offsetBefore1h;
    }
    return offsetCustom;
  }
}
