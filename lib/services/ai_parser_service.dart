class ParsedReminder {
  const ParsedReminder({
    required this.title,
    required this.time,
    required this.confidence,
    required this.timeType,
  });

  final String title;
  final DateTime? time;
  final double confidence;
  final String timeType;
}

class AIParserService {
  static ParsedReminder parse(String input, {DateTime? now}) {
    final DateTime base = now ?? DateTime.now();
    final String text = input.trim();
    if (text.isEmpty) {
      return const ParsedReminder(
        title: '',
        time: null,
        confidence: 0,
        timeType: 'none',
      );
    }

    final int? hour = _extractHour(text);
    DateTime? parsedTime;
    String timeType = 'none';
    double confidence = 0.55;

    if (text.contains('明天')) {
      final DateTime day = base.add(const Duration(days: 1));
      if (hour != null) {
        parsedTime = DateTime(day.year, day.month, day.day, hour, 0);
        timeType = 'fixed';
        confidence = 0.92;
      } else {
        parsedTime = DateTime(day.year, day.month, day.day, 9, 0);
        timeType = 'flexible';
        confidence = 0.78;
      }
    } else if (text.contains('今晚')) {
      final int eveningHour = hour ?? 20;
      parsedTime = DateTime(base.year, base.month, base.day, eveningHour, 0);
      timeType = hour != null ? 'fixed' : 'flexible';
      confidence = hour != null ? 0.9 : 0.74;
    } else if (text.contains('下周')) {
      final DateTime nextWeek = base.add(const Duration(days: 7));
      final int weekHour = hour ?? 9;
      parsedTime = DateTime(nextWeek.year, nextWeek.month, nextWeek.day, weekHour, 0);
      timeType = hour != null ? 'fixed' : 'flexible';
      confidence = hour != null ? 0.85 : 0.7;
    } else if (hour != null) {
      parsedTime = DateTime(base.year, base.month, base.day, hour, 0);
      timeType = 'fixed';
      confidence = 0.82;
    }

    return ParsedReminder(
      title: text,
      time: parsedTime,
      confidence: confidence,
      timeType: timeType,
    );
  }

  static int? _extractHour(String text) {
    final RegExp explicit = RegExp(r'(\d{1,2})\s*点');
    final Match? explicitMatch = explicit.firstMatch(text);
    if (explicitMatch != null) {
      final int? value = int.tryParse(explicitMatch.group(1) ?? '');
      if (value != null && value >= 0 && value <= 23) {
        return value;
      }
    }
    if (text.contains('早上')) {
      return 9;
    }
    if (text.contains('中午')) {
      return 12;
    }
    if (text.contains('下午')) {
      return 15;
    }
    return null;
  }
}
