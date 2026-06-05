import 'package:murmur/models/todo_sub_item.dart';

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
    this.remindRepeatDays = const <int>[],
    this.remindText,
    this.remindVoiceId,
    this.voiceRemindEnabled = false,
    this.notes,
    this.deadlineAt,
    this.calendarLinkedId,
    this.isTodoDeadline = false,
    this.linkedTodoId,
    required this.isCompleted,
    required this.createdAt,
    List<TodoSubItem>? subItems,
  }) : _subItems = subItems;

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
  final List<int> remindRepeatDays;
  final String? remindText;
  final String? remindVoiceId;
  final bool voiceRemindEnabled;
  final String? notes;
  final DateTime? deadlineAt;
  final String? calendarLinkedId;
  final bool isTodoDeadline;
  final String? linkedTodoId;
  final bool isCompleted;
  final DateTime createdAt;
  final List<TodoSubItem>? _subItems;

  List<TodoSubItem> get subItems => _subItems ?? const <TodoSubItem>[];

  bool get isFixed => timeType == 'fixed' && scheduledTime != null;
  bool get isFlexible => timeType == 'flexible';
  bool get hasDeadline => deadlineAt != null;
  bool get isSyncedToCalendar => calendarLinkedId != null;
  bool get hasSubItems => subItems.isNotEmpty;
  int get subItemCompletedCount => subItems.where((TodoSubItem item) => item.isCompleted).length;
  bool get allSubItemsCompleted =>
      subItems.isNotEmpty && subItems.every((TodoSubItem item) => item.isCompleted);

  Reminder copyWith({
    String? id,
    String? title,
    DateTime? scheduledTime,
    DateTime? endTime,
    bool clearEndTime = false,
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
    bool clearRemindAt = false,
    String? remindFrequency,
    List<int>? remindRepeatDays,
    bool clearRemindRepeatDays = false,
    String? remindText,
    String? remindVoiceId,
    bool? voiceRemindEnabled,
    String? notes,
    bool clearNotes = false,
    DateTime? deadlineAt,
    bool clearDeadlineAt = false,
    String? calendarLinkedId,
    bool clearCalendarLinkedId = false,
    bool? isTodoDeadline,
    String? linkedTodoId,
    bool clearLinkedTodoId = false,
    bool? isCompleted,
    DateTime? createdAt,
    List<TodoSubItem>? subItems,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledTime: clearScheduledTime ? null : (scheduledTime ?? this.scheduledTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      isAllDay: isAllDay ?? this.isAllDay,
      timeType: timeType ?? this.timeType,
      soundId: soundId ?? this.soundId,
      voiceId: voiceId ?? this.voiceId,
      voicePath: voicePath ?? this.voicePath,
      isCustomVoice: isCustomVoice ?? this.isCustomVoice,
      emotionTag: emotionTag ?? this.emotionTag,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
      remindFrequency: remindFrequency ?? this.remindFrequency,
      remindRepeatDays:
          clearRemindRepeatDays ? const <int>[] : (remindRepeatDays ?? this.remindRepeatDays),
      remindText: remindText ?? this.remindText,
      remindVoiceId: remindVoiceId ?? this.remindVoiceId,
      voiceRemindEnabled: voiceRemindEnabled ?? this.voiceRemindEnabled,
      notes: clearNotes ? null : (notes ?? this.notes),
      deadlineAt: clearDeadlineAt ? null : (deadlineAt ?? this.deadlineAt),
      calendarLinkedId:
          clearCalendarLinkedId ? null : (calendarLinkedId ?? this.calendarLinkedId),
      isTodoDeadline: isTodoDeadline ?? this.isTodoDeadline,
      linkedTodoId: clearLinkedTodoId ? null : (linkedTodoId ?? this.linkedTodoId),
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      subItems: subItems ?? _subItems,
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
      'remindRepeatDays': remindRepeatDays,
      'remindText': remindText,
      'remindVoiceId': remindVoiceId,
      'voiceRemindEnabled': voiceRemindEnabled,
      'notes': notes,
      'deadlineAt': deadlineAt?.toIso8601String(),
      'calendarLinkedId': calendarLinkedId,
      'isTodoDeadline': isTodoDeadline,
      'linkedTodoId': linkedTodoId,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'subItems': subItems.map((TodoSubItem item) => item.toMap()).toList(),
    };
  }

  factory Reminder.fromMap(Map<dynamic, dynamic> map) {
    final String? scheduledTimeRaw = map['scheduledTime'] as String?;
    final String? endTimeRaw = map['endTime'] as String?;
    final String? deadlineAtRaw = map['deadlineAt'] as String?;
    final bool? isAllDayRaw = map['isAllDay'] as bool?;
    final String? soundIdRaw = map['soundId'] as String?;
    final bool? isCustomVoiceRaw = map['isCustomVoice'] as bool?;
    final bool? remindEnabledRaw = map['remindEnabled'] as bool?;
    final String? remindAtRaw = map['remindAt'] as String?;
    final String? remindFrequencyRaw = map['remindFrequency'] as String?;
    final List<int> remindRepeatDaysRaw =
        (map['remindRepeatDays'] as List<dynamic>?)
                ?.map((dynamic value) => value as int)
                .toList() ??
            const <int>[];
    final bool? voiceRemindEnabledRaw = map['voiceRemindEnabled'] as bool?;
    final bool? isTodoDeadlineRaw = map['isTodoDeadline'] as bool?;
    final bool isCustomVoice = isCustomVoiceRaw ?? false;
    final String? remindVoiceIdRaw = map['remindVoiceId'] as String?;

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
      isCustomVoice: isCustomVoice,
      emotionTag: map['emotionTag'] as String?,
      remindEnabled: remindEnabledRaw ?? false,
      remindAt: remindAtRaw == null ? null : DateTime.parse(remindAtRaw),
      remindFrequency:
          remindFrequencyRaw == null || remindFrequencyRaw.isEmpty
              ? 'once'
              : remindFrequencyRaw,
      remindRepeatDays: remindRepeatDaysRaw,
      remindText: map['remindText'] as String?,
      remindVoiceId: remindVoiceIdRaw,
      voiceRemindEnabled: voiceRemindEnabledRaw ??
          (remindVoiceIdRaw != null || isCustomVoice),
      notes: map['notes'] as String?,
      deadlineAt: deadlineAtRaw == null ? null : DateTime.parse(deadlineAtRaw),
      calendarLinkedId: map['calendarLinkedId'] as String?,
      isTodoDeadline: isTodoDeadlineRaw ?? false,
      linkedTodoId: map['linkedTodoId'] as String?,
      isCompleted: map['isCompleted'] as bool,
      createdAt: DateTime.parse(map['createdAt'] as String),
      subItems: (map['subItems'] as List<dynamic>?)
              ?.whereType<Map<dynamic, dynamic>>()
              .map(TodoSubItem.fromMap)
              .toList() ??
          const <TodoSubItem>[],
    );
  }
}
