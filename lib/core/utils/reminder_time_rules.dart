import 'package:murmur/core/utils/date_time_utils.dart';

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
    switch (offset) {
      case offsetBefore15m:
        return '提前 15 分钟';
      case offsetBefore1h:
        return '提前 1 小时';
      case offsetCustom:
        return '自定义';
      case offsetAtTime:
      default:
        return '准时';
    }
  }

  static String frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return '每天';
      case 'weekly':
        return '每周';
      case 'monthly':
        return '每月';
      case 'once':
      default:
        return '不重复';
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
      return '请选择';
    }
    if (frequency == 'weekly') {
      return days.map(DateTimeUtils.weekdayLabel).join('、');
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
    final String time = DateTimeUtils.formatTime(remindAt);
    switch (frequency) {
      case 'daily':
        return '每天 $time 提醒';
      case 'weekly':
        final List<int> days = effectiveRepeatDays(
          frequency: frequency,
          repeatDays: repeatDays,
          remindAt: remindAt,
        );
        if (days.isEmpty) {
          return '请选择每周提醒日';
        }
        return '每周${days.map(DateTimeUtils.weekdayLabel).join('、')} $time 提醒';
      case 'monthly':
        final List<int> days = effectiveRepeatDays(
          frequency: frequency,
          repeatDays: repeatDays,
          remindAt: remindAt,
        );
        if (days.isEmpty) {
          return '请选择每月提醒日';
        }
        return '每月${days.join('、')}日 $time 提醒';
      case 'once':
      default:
        return '将在 ${DateTimeUtils.formatDateTime(remindAt)} 通知';
    }
  }

  static String customRemindTileValue({
    required DateTime? remindAt,
    required String frequency,
    List<int> repeatDays = const <int>[],
  }) {
    if (remindAt == null) {
      return '请选择';
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
