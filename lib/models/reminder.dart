class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.scheduledTime,
    this.endTime,
    this.isAllDay = false,
    required this.timeType,
    required this.soundId,
    this.voiceId,
    this.voicePath,
    this.isCustomVoice = false,
    this.emotionTag,
    this.remindEnabled = false,
    this.remindAt,
    this.remindFrequency = 'once',
    this.remindText,
    this.remindVoiceId,
    required this.isCompleted,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime? scheduledTime;
  final DateTime? endTime;
  final bool isAllDay;
  final String timeType;
  final String soundId;
  final String? voiceId;
  final String? voicePath;
  final bool isCustomVoice;
  final String? emotionTag;
  final bool remindEnabled;
  final DateTime? remindAt;
  final String remindFrequency;
  final String? remindText;
  final String? remindVoiceId;
  final bool isCompleted;
  final DateTime createdAt;

  bool get isFixed => scheduledTime != null && timeType == 'fixed';
  bool get isFlexible => scheduledTime == null && timeType == 'flexible';

  Reminder copyWith({
    String? id,
    String? title,
    DateTime? scheduledTime,
    DateTime? endTime,
    bool clearScheduledTime = false,
    bool? isAllDay,
    String? timeType,
    String? soundId,
    String? voiceId,
    String? voicePath,
    bool? isCustomVoice,
    String? emotionTag,
    bool? remindEnabled,
    DateTime? remindAt,
    String? remindFrequency,
    String? remindText,
    String? remindVoiceId,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledTime: clearScheduledTime ? null : (scheduledTime ?? this.scheduledTime),
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      timeType: timeType ?? this.timeType,
      soundId: soundId ?? this.soundId,
      voiceId: voiceId ?? this.voiceId,
      voicePath: voicePath ?? this.voicePath,
      isCustomVoice: isCustomVoice ?? this.isCustomVoice,
      emotionTag: emotionTag ?? this.emotionTag,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      remindAt: remindAt ?? this.remindAt,
      remindFrequency: remindFrequency ?? this.remindFrequency,
      remindText: remindText ?? this.remindText,
      remindVoiceId: remindVoiceId ?? this.remindVoiceId,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isAllDay': isAllDay,
      'timeType': timeType,
      'soundId': soundId,
      'voiceId': voiceId,
      'voicePath': voicePath,
      'isCustomVoice': isCustomVoice,
      'emotionTag': emotionTag,
      'remindEnabled': remindEnabled,
      'remindAt': remindAt?.toIso8601String(),
      'remindFrequency': remindFrequency,
      'remindText': remindText,
      'remindVoiceId': remindVoiceId,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reminder.fromMap(Map<dynamic, dynamic> map) {
    final String? scheduledTimeRaw = map['scheduledTime'] as String?;
    final String? endTimeRaw = map['endTime'] as String?;
    final bool? isAllDayRaw = map['isAllDay'] as bool?;
    final String? soundIdRaw = map['soundId'] as String?;
    final bool? isCustomVoiceRaw = map['isCustomVoice'] as bool?;
    final bool? remindEnabledRaw = map['remindEnabled'] as bool?;
    final String? remindAtRaw = map['remindAt'] as String?;
    final String? remindFrequencyRaw = map['remindFrequency'] as String?;

    return Reminder(
      id: map['id'] as String,
      title: map['title'] as String,
      scheduledTime:
          scheduledTimeRaw == null ? null : DateTime.parse(scheduledTimeRaw),
      endTime: endTimeRaw == null ? null : DateTime.parse(endTimeRaw),
      isAllDay: isAllDayRaw ?? false,
      timeType: map['timeType'] as String,
      soundId: soundIdRaw == null || soundIdRaw.isEmpty ? 'default' : soundIdRaw,
      voiceId: map['voiceId'] as String?,
      voicePath: map['voicePath'] as String?,
      isCustomVoice: isCustomVoiceRaw ?? false,
      emotionTag: map['emotionTag'] as String?,
      remindEnabled: remindEnabledRaw ?? false,
      remindAt: remindAtRaw == null ? null : DateTime.parse(remindAtRaw),
      remindFrequency:
          remindFrequencyRaw == null || remindFrequencyRaw.isEmpty
              ? 'once'
              : remindFrequencyRaw,
      remindText: map['remindText'] as String?,
      remindVoiceId: map['remindVoiceId'] as String?,
      isCompleted: map['isCompleted'] as bool,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
