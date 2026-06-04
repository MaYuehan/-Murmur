import 'package:flutter/material.dart';

/// Runtime holder for strings when [BuildContext] is unavailable.
class AppLocalizationsBinding {
  AppLocalizationsBinding._();

  static AppLocalizations instance = AppLocalizations(const Locale('zh'));
}

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  bool get isZh => locale.languageCode != 'en';

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String _t(String zh, String en) => isZh ? zh : en;

  // App & navigation
  String get appTitle => _t('亲声', 'Murmur');
  String get appWindowTitle => _t('亲声 Murmur', 'Murmur');
  String get comingSoon => _t('即将推出', 'Coming Soon');
  String get navCalendar => _t('日历', 'Calendar');
  String get navTodo => _t('待办', 'Tasks');
  String get navVoice => _t('声音', 'Voice');
  String get navProfile => _t('我的', 'Profile');

  // Common actions
  String get commonCancel => _t('取消', 'Cancel');
  String get commonDone => _t('完成', 'Done');
  String get commonSave => _t('保存', 'Save');
  String get commonDelete => _t('删除', 'Delete');
  String get commonCreate => _t('新建', 'New');
  String get commonEdit => _t('编辑', 'Edit');
  String get commonRefresh => _t('刷新', 'Refresh');
  String get commonPleaseSelect => _t('请选择', 'Please select');

  // Profile
  String get profilePageTitle => _t('我的', 'Profile');
  String get profileSectionReminders => _t('提醒', 'Reminders');
  String get profileVoiceMuteTitle => _t('亲声静音', 'Mute voice reminders');
  String get profileVoiceMuteSubtitle => _t(
        '开启后，到点只显示通知，不自动播放亲声',
        'When on, notifications appear without auto-playing voice',
      );
  String get profileShowTodoCreatedDateTitle =>
      _t('显示待办创建日期', 'Show task created date');
  String get profileShowTodoCreatedDateSubtitle => _t(
        '在待办列表卡片底部显示创建日期',
        'Show the created date at the bottom of task cards',
      );
  String get profileSectionCalendar => _t('日历', 'Calendar');
  String get profileWeekStartTitle => _t('每周起始日', 'Week starts on');
  String get profileWeekStartMonday => _t('星期一', 'Monday');
  String get profileWeekStartSunday => _t('星期日', 'Sunday');
  String get profileSectionLanguage => _t('语言', 'Language');
  String get profileLanguageChinese => _t('中文', 'Chinese');
  String get profileLanguageEnglish => 'English';
  String get profileSectionComingSoon => _t('即将推出', 'Coming Soon');
  String get profileHabitLearningTitle => _t('习惯学习', 'Habit learning');
  String get profileHabitLearningSubtitle =>
      _t('了解你的提醒偏好', 'Learn your reminder preferences');
  String get profileVoiceLibraryTitle => _t('亲声库管理', 'Voice library');
  String get profileVoiceLibrarySubtitle =>
      _t('统一管理录音与预设', 'Manage recordings and presets');
  String get profileSyncBackupTitle => _t('同步与备份', 'Sync & backup');
  String get profileSyncBackupSubtitle =>
      _t('跨设备保留你的亲声', 'Keep your voices across devices');

  // Calendar
  String get calendarViewMonth => _t('月', 'Month');
  String get calendarViewWeek => _t('周', 'Week');
  String get calendarPrevWeek => _t('上一周', 'Previous week');
  String get calendarNextWeek => _t('下一周', 'Next week');
  String get calendarBackToToday => _t('回到今天', 'Back to today');
  String get calendarToday => _t('今天', 'Today');
  String get calendarPickMonthYear => _t('选择年月', 'Select month');
  String get calendarPickWeek => _t('选择周', 'Select week');
  String get calendarEmptyDayTitle => _t('当天暂无日程', 'No events today');
  String get calendarEmptyDaySubtitle =>
      _t('点击右上角「新建」添加', 'Tap “New” at top right to add');
  String calendarScopeWeek(bool isCurrentWeek) =>
      isCurrentWeek ? _t('本周', 'Week') : _t('当周', 'Week');
  String get calendarScopeSelectedDay => _t('当天', 'Day');
  String get calendarDeadlineSection => _t('截止', 'Deadline');
  String get calendarScheduleSection => _t('日程', 'Schedule');
  String calendarEmptyDayNamedTitle(String date) =>
      _t('$date 暂无日程', 'No events on $date');
  String calendarEmptyWeekTitle(bool isCurrentWeek) => isCurrentWeek
      ? _t('本周暂无日程', 'No events this week')
      : _t('当周暂无日程', 'No events this week');
  String get calendarEmptyWeekSubtitle =>
      _t('切换其他周或新建日程', 'Switch week or create an event');
  String get calendarDeleteTitle => _t('删除日程', 'Delete event');
  String calendarDeleteMessage(String title) => _t(
        '确定删除「$title」吗？此操作无法撤销。',
        'Delete “$title”? This cannot be undone.',
      );
  String get calendarDeletedSnack => _t('已删除日程', 'Event deleted');

  // Todo
  String get todoPageTitle => _t('待办', 'Tasks');
  String get todoSectionTitle => _t('待办', 'Tasks');
  String get todoDeadlineSection => _t('截止待办', 'Deadline Tasks');
  String get todoNormalSection => _t('普通待办', 'Tasks');
  String get todoEmptyTitle => _t('还没有待办事项', 'No tasks yet');
  String get todoEmptySubtitle =>
      _t('点击右上角「新建」添加', 'Tap “New” at top right to add');
  String get todoCompletedSection => _t('已完成', 'Completed');
  String get todoClearCompleted => _t('清除已完成', 'Clear completed');
  String get todoClearCompletedConfirmTitle =>
      _t('清除已完成？', 'Clear completed tasks?');
  String todoClearCompletedConfirmBody(int count) => _t(
        '确定要清除 $count 项已完成待办吗？',
        'Clear $count completed task(s)?',
      );
  String todoDeadlineLabel(String datetime) => _t('截止 $datetime', 'Due $datetime');
  String get todoReminderSet => _t('已设提醒', 'Reminder set');
  String todoCreatedAt(String date) => _t('创建于 $date', 'Created $date');
  String get todoDeleteFromCalendarTitle => _t('同时从日历移除？', 'Also remove from calendar?');
  String get todoDeleteFromCalendarBodySingle => _t(
        '此待办已同步到日历，是否一并删除日历中的截止事项？',
        'This task is synced to the calendar. Also delete the calendar deadline?',
      );
  String todoDeleteFromCalendarBodyMultiple(int count) => _t(
        '其中有 $count 项已同步到日历，是否一并删除日历中的截止事项？',
        '$count synced tasks are on the calendar. Delete their calendar entries too?',
      );
  String get todoDeleteTodoOnly => _t('仅删待办', 'Task only');
  String get todoDeleteTodoAndCalendar => _t('一并删除', 'Delete both');
  String get todoUnlinkTitle => _t('取消添加到日程？', 'Remove from calendar?');
  String get todoUnlinkBody => _t(
        '此待办已同步到日历，是否从日历中移除对应日程？待办本身会保留。',
        'Remove the linked calendar event? The task will stay.',
      );
  String get todoKeepInCalendar => _t('保留', 'Keep');
  String get todoRemoveFromCalendar => _t('从日历移除', 'Remove');
  String get todoRemovedFromCalendarSnack => _t('已从日历移除', 'Removed from calendar');
  String get scheduleAddToCalendarTitle => _t('添加到日程', 'Add to calendar');
  String get todoSyncedToCalendarSnack => _t('已同步到日历', 'Synced to calendar');
  String get todoSyncedDeadlineSnack => _t('已同步截止日程到日历', 'Deadline synced to calendar');
  String get todoEditTitleLabel => _t('编辑任务标题', 'Edit task title');
  String get todoClearedCompletedSnack => _t('已清除完成事项', 'Completed tasks cleared');
  String get todoSheetCreate => _t('创建待办', 'New task');
  String get todoSheetEdit => _t('编辑待办', 'Edit task');
  String get todoHintContent => _t('添加待办事项…', 'Add a task…');
  String get todoValidationContent => _t('请填写待办内容', 'Please enter task content');
  String get todoSnackFillFirst => _t('请先填写待办内容', 'Please enter task content first');
  String get todoSectionDeadline => _t('截止', 'Deadline');
  String get todoDeadlineDate => _t('截止日期', 'Due date');
  String get todoDeadlineEndOfDay => _t('当天 23:59', 'End of day 23:59');
  String get todoSpecificTime => _t('具体时间', 'Specific time');
  String get todoSpecificTimeOffSubtitle =>
      _t('未开启时默认为当天 23:59', 'Defaults to 23:59 when off');
  String get todoFieldTime => _t('时间', 'Time');
  String get todoSyncToCalendar => _t('同步到日历', 'Sync to calendar');
  String get todoSyncToCalendarSubtitle =>
      _t('在日历中以红色截止事项显示', 'Show as red deadline on calendar');
  String get todoNeedRemindSubtitle =>
      _t('提醒时间可以与截止时间不同', 'Reminder time can differ from deadline');
  String get todoRemindTime => _t('提醒时间', 'Reminder time');
  String get todoSameAsContent => _t('与待办内容相同', 'Same as task content');
  String get todoAdd => _t('添加', 'Add');

  // Reminder / schedule
  String get reminderAllDay => _t('全天', 'All day');
  String get reminderFieldDate => _t('日期', 'Date');
  String get reminderFieldTime => _t('时间', 'Time');
  String get reminderFieldDeadline => _t('截止时间', 'Deadline');
  String get reminderTimeRangeInvalid =>
      _t('结束时间必须晚于开始时间', 'End time must be after start time');
  String get reminderSheetCreate => _t('创建日程', 'New event');
  String get reminderSheetEdit => _t('编辑日程', 'Edit event');
  String get reminderSectionEvent => _t('日程', 'Event');
  String get reminderFieldContent => _t('内容', 'Content');
  String get reminderHintContent => _t('例如：给妈妈打电话', 'e.g. Call mom');
  String get reminderValidationContent => _t('请填写提醒内容', 'Please enter content');
  String get reminderFieldNotes => _t('备注', 'Notes');
  String get reminderHintNotes => _t('例如：妈妈的手机号', 'e.g. Mom’s phone number');
  String get reminderSectionTime => _t('时间', 'Time');
  String get reminderSectionRemind => _t('提醒', 'Reminder');
  String get reminderNeedRemind => _t('需要提醒', 'Reminder');
  String get reminderNeedRemindSubtitleEvent => _t(
        '提醒时间可以与日程时间不同',
        'Reminder time can differ from event time',
      );
  String get reminderRemindOffset => _t('提醒时机', 'When to remind');
  String get reminderCustomTime => _t('自定义时间', 'Custom time');
  String get reminderRepeat => _t('重复', 'Repeat');
  String get reminderSectionVoice => _t('亲声提醒', 'Voice reminder');
  String get reminderVoiceRemind => _t('语音提醒', 'Voice reminder');
  String get reminderVoiceRemindSubtitle =>
      _t('文案亲声或录制亲声', 'Preset text voice or recording');
  String get reminderVoiceModeText => _t('文案亲声', 'Text voice');
  String get reminderVoiceModeRecord => _t('录制亲声', 'Record voice');
  String get reminderRemindText => _t('提醒文案', 'Reminder text');
  String get reminderRemindTextHint => _t('亲声播报时朗读', 'Spoken when voice plays');
  String get reminderSameAsEvent => _t('与日程内容相同', 'Same as event content');
  String get reminderVoiceSound => _t('提醒声音', 'Reminder voice');
  String get reminderRecordStop => _t('停止录音', 'Stop recording');
  String get reminderRecordStart => _t('开始录音', 'Start recording');
  String get reminderPreviewRecording => _t('试听录音', 'Preview recording');
  String get reminderValidationVoice =>
      _t('请填写提醒文案并选择提醒声音', 'Enter reminder text and choose a voice');
  String get reminderRecordingInProgress =>
      _t('正在录音…最多 30 秒', 'Recording… up to 30 seconds');
  String get reminderRecordingSaved =>
      _t('已录制亲声，保存后将用于提醒', 'Recording saved for reminders');
  String get reminderRecordingRequired =>
      _t('请先录制亲声后再保存', 'Record a voice before saving');
  String get reminderSaveChanges => _t('保存修改', 'Save changes');
  String get reminderSnackFillContent => _t('请先填写日程内容', 'Please enter event content first');
  String get reminderSnackMicPermission =>
      _t('录音权限不可用', 'Microphone permission unavailable');
  String get reminderUnscheduled => _t('未安排时间', 'Not scheduled');
  String get reminderRemindNone => _t('无', 'None');
  String get reminderRemindUnset => _t('未设置', 'Not set');
  String get reminderDetailTodoDeadline => _t('待办截止', 'Task deadline');
  String get reminderDetailTodo => _t('待办', 'Task');
  String get reminderTodoCompletedInList => _t('已在待办中完成', 'Completed in tasks');
  String get reminderFromTodoSync => _t('来自待办同步', 'Synced from task');
  String get reminderVoiceSection => _t('亲声', 'Voice');
  String get reminderVoiceOff => _t('未开启', 'Off');
  String get reminderVoicePlayAtTime => _t('到点播放亲声', 'Play voice at reminder time');
  String get reminderTextOnlyNotify => _t('仅文字通知', 'Text notification only');
  String get reminderRemindContent => _t('提醒内容', 'Reminder content');
  String get reminderDeleteEvent => _t('删除日程', 'Delete event');
  String get reminderPlaying => _t('正在播放', 'Playing');
  String get reminderVoicePreview => _t('亲声预览', 'Voice preview');
  String get reminderRemindSection => _t('提醒', 'Reminder');
  String get reminderTodoDeadline => _t('待办截止', 'Task deadline');
  String get reminderTodoDone => _t('待办已完成', 'Task completed');
  String get reminderTodo => _t('待办', 'Task');
  String get reminderVoiceRemindBadge => _t('亲声提醒', 'Voice reminder');
  String get reminderSectionLabelRemindTime => _t('提醒时间', 'Reminder time');

  String reminderDurationHours(int hours) =>
      _t('时长 $hours 小时', 'Duration $hours h');
  String reminderDurationMinutes(int minutes) =>
      _t('时长 $minutes 分钟', 'Duration $minutes min');
  String reminderDurationHoursMinutes(int hours, int minutes) => _t(
        '时长 $hours 小时 $minutes 分钟',
        'Duration $hours h $minutes min',
      );

  // Schedule picker
  String get scheduleSpecificTime => _t('具体时间', 'Specific time');
  String get scheduleAllDayWhenOff => _t('未开启时为全天日程', 'All-day event when off');
  String get datePickerSelectDate => _t('选择日期', 'Select date');

  // Remind rules
  String get remindOffsetOnTime => _t('准时', 'On time');
  String get remindOffsetBefore15m => _t('提前 15 分钟', '15 minutes before');
  String get remindOffsetBefore1h => _t('提前 1 小时', '1 hour before');
  String get remindOffsetCustom => _t('自定义', 'Custom');
  String get remindFrequencyOnce => _t('不重复', 'Never');
  String get remindFrequencyDaily => _t('每天', 'Daily');
  String get remindFrequencyWeekly => _t('每周', 'Weekly');
  String get remindFrequencyMonthly => _t('每月', 'Monthly');
  String get remindPreviewWeeklyNeedDays => _t('请选择每周提醒日', 'Select weekly days');
  String get remindPreviewMonthlyNeedDays => _t('请选择每月提醒日', 'Select monthly days');
  String remindPreviewDaily(String time) => _t('每天 $time 提醒', 'Daily at $time');
  String remindPreviewWeekly(String days, String time) =>
      _t('每周$days $time 提醒', 'Weekly on $days at $time');
  String remindPreviewMonthly(String days, String time) =>
      _t('每月${days}日 $time 提醒', 'Monthly on day $days at $time');
  String remindPreviewOnce(String datetime) =>
      _t('将在 $datetime 通知', 'Notify at $datetime');

  // Time range
  String get timeRangeStart => _t('开始', 'Start');
  String get timeRangeEnd => _t('结束', 'End');
  String get timeRangeQuickDuration => _t('快捷时长', 'Quick duration');
  String get timeRangeDuration30m => _t('30 分钟', '30 min');
  String get timeRangeDuration1h => _t('1 小时', '1 hour');
  String get timeRangeDuration2h => _t('2 小时', '2 hours');
  String get timeRangeInvalidShort => _t('结束时间需晚于开始时间', 'End must be after start');
  String timeRangeTotalHours(int hours) => _t('共 $hours 小时', '$hours h total');
  String timeRangeTotalMinutes(int minutes) =>
      _t('共 $minutes 分钟', '$minutes min total');
  String timeRangeTotalHoursMinutes(int hours, int minutes) =>
      _t('共 $hours 小时 $minutes 分钟', '$hours h $minutes min total');
  String get timeRangeSheetTitle => _t('选择时间', 'Select time');

  // Date picker modes
  String get datePickerModeCalendar => _t('日历', 'Calendar');
  String get datePickerModeWheel => _t('滚轮', 'Wheel');

  // Voice page
  String get voicePageTitle => _t('声音', 'Voice');
  String get voicePlaying => _t('正在播放...', 'Playing...');
  String get voiceSectionPresets => _t('预设亲声', 'Preset voices');
  String get voiceTapToPreview => _t('点击预览', 'Tap to preview');
  String get voiceSectionRecordings => _t('我的录音', 'My recordings');
  String get voiceEmptyRecordings => _t(
        '还没有录音\n可在创建日程时录制',
        'No recordings yet\nRecord when creating an event',
      );
  String get voiceLocalRecording => _t('本地录音', 'Local recording');
  String get voiceMyRecording => _t('我的录音', 'My recording');
  String get voiceDefaultPreset => _t('默认亲声', 'Default voice');

  // Voice selector widget
  String get voiceSelectorTitle => _t('选择声音', 'Voice Selection');
  String get voiceMyRecordedVoice => _t('我的录音', 'My Recorded Voice');
  String get voiceRecordMax30s => _t('录音（最多30秒）', 'Record (max 30s)');
  String get voiceStop => _t('停止', 'Stop');
  String get voicePreviewButton => _t('预览', 'Preview');
  String get voiceRecordingShort => _t('正在录音...', 'Recording...');
  String voiceMyRecordingsCount(int count) =>
      _t('我的录音：$count', 'My recordings: $count');

  // Notifications
  String get notificationDefaultBody => _t(
        '亲声提醒你该做这件事了',
        'Voice reminder: time for this task',
      );

  // Weekdays
  String weekdayLabel(int weekday) {
    if (isZh) {
      const List<String> labels = <String>[
        '周一',
        '周二',
        '周三',
        '周四',
        '周五',
        '周六',
        '周日',
      ];
      return labels[weekday - 1];
    }
    const List<String> labels = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return labels[weekday - 1];
  }

  String shortWeekdayLabel(int weekday) {
    if (isZh) {
      const List<String> labels = <String>['一', '二', '三', '四', '五', '六', '日'];
      return labels[weekday - 1];
    }
    return weekdayLabel(weekday);
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'zh' || locale.languageCode == 'en';
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final AppLocalizations l10n = AppLocalizations(locale);
    AppLocalizationsBinding.instance = l10n;
    return l10n;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
