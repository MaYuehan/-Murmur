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
  String get navFamily => _t('亲友', 'Family');
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
  String get profileSectionVoice => _t('亲声', 'Voice');
  String get profileOpenVoices => _t('声音', 'Voices');
  String get profileOpenVoicesSubtitle =>
      _t('预设声线与自定义声线', 'Preset and custom voices');
  String get profileOpenRecordings => _t('我的录音', 'My recordings');
  String get profileOpenRecordingsSubtitle =>
      _t('近 7 天录音，可收藏命名', 'Last 7 days; save favorites');
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
  String get calendarPrevMonth => _t('上一月', 'Previous month');
  String get calendarNextMonth => _t('下一月', 'Next month');
  String get calendarPrevWeek => _t('上一周', 'Previous week');
  String get calendarNextWeek => _t('下一周', 'Next week');
  String get calendarBackToToday => _t('回到今天', 'Back to today');
  String get calendarToday => _t('今天', 'Today');
  String get calendarPinView => _t('定住日历', 'Pin calendar');
  String get calendarUnpinView => _t('取消定住', 'Unpin calendar');
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
  String get todoAllPending => _t('全部待办', 'All tasks');
  String get todoAllCompleted => _t('全部已完成', 'All completed');
  String get todoDeadlineSection => _t('截止待办', 'Deadline Tasks');
  String get todoNormalSection => _t('普通待办', 'Tasks');
  String get todoGroupSection => _t('待办组', 'Task groups');
  String get todoAddGroup => _t('添加待办组', 'Add task group');
  String get todoGroupNameHint => _t('待办组名称', 'Group name');
  String get todoGroupRenameTitle => _t('修改待办组名称', 'Rename task group');
  String get todoFieldGroup => _t('待办组', 'Task group');
  String get todoGroupNone => _t('无', 'None');
  String get todoGroupPickerTitle => _t('选择待办组', 'Select task group');
  String get todoDeleteGroupTitle => _t('删除待办组', 'Delete task group');
  String todoDeleteGroupMessage(String name) =>
      _t('确定删除「$name」吗？', 'Delete “$name”?');
  String todoDeleteGroupMessageWithTodos(String name, int count) => _t(
        '确定删除「$name」吗？组内有 $count 项待办，是否一并删除？',
        'Delete “$name”? It contains $count task(s). Delete them too?',
      );
  String get todoDeleteGroupKeepTodos => _t('保留待办', 'Keep tasks');
  String get todoDeleteGroupDeleteTodos => _t('一并删除', 'Delete all');
  String get todoEmptyTitle => _t('还没有待办事项', 'No tasks yet');
  String get todoEmptySubtitle =>
      _t('点击右上角「新建」添加', 'Tap “New” at top right to add');
  String get todoCompletedEmptyTitle => _t('还没有已完成事项', 'No completed tasks yet');
  String get todoCompletedSection => _t('已完成', 'Completed');
  String get todoCompletedSectionToday => _t('今天', 'Today');
  String get todoCompletedSectionYesterday => _t('昨天', 'Yesterday');
  String get todoCompletedSectionThisWeek => _t('本周', 'This week');
  String get todoCompletedSectionThisMonth => _t('本月', 'This month');
  String get todoCompletedSectionEarlier => _t('更早', 'Earlier');
  String get todoClearCompleted => _t('清除已完成', 'Clear completed');
  String get todoClearCompletedScopeTitle => _t('清除已完成事项', 'Clear completed tasks');
  String get todoClearCompletedScopeAll => _t('清除所有', 'Clear all');
  String get todoClearCompletedScopeAllSubtitle => _t(
        '删除全部已完成待办',
        'Delete all completed tasks',
      );
  String get todoClearCompletedScopeBeforeThisWeek => _t('清除本周前', 'Clear before this week');
  String get todoClearCompletedScopeBeforeThisWeekSubtitle => _t(
        '保留本周完成记录，清除上周日及更早',
        'Keep this week’s tasks; clear through last Sunday',
      );
  String get todoClearCompletedScopeBeforeThisMonth => _t('清除本月前', 'Clear before this month');
  String get todoClearCompletedScopeBeforeThisMonthSubtitle => _t(
        '保留本月完成记录，清除上月底及更早',
        'Keep this month’s tasks; clear through last month-end',
      );
  String get todoClearCompletedConfirmTitle =>
      _t('清除已完成？', 'Clear completed tasks?');
  String todoClearCompletedConfirmBody(int count) => _t(
        '确定要清除 $count 项已完成待办吗？',
        'Clear $count completed task(s)?',
      );
  String todoClearCompletedScopeConfirmBody(String scopeLabel, int count) => _t(
        '确定要$scopeLabel $count 项已完成待办吗？',
        'Clear $count completed task(s) ($scopeLabel)?',
      );
  String get todoClearCompletedNothingToClear =>
      _t('没有符合条件的已完成待办', 'No completed tasks match this range');
  String todoClearedCompletedCountSnack(int count) => _t(
        '已清除 $count 项已完成待办',
        'Cleared $count completed task(s)',
      );
  String get todoUncompleteConfirmTitle => _t('移回待办？', 'Move back to tasks?');
  String todoUncompleteConfirmBody(String title) => _t(
        '确定将「$title」移回待办列表吗？',
        'Move “$title” back to your task list?',
      );
  String get todoUncompleteConfirmAction => _t('移回待办', 'Move back');
  String todoDeadlineLabel(String datetime) => _t('截止 $datetime', 'Due $datetime');
  String get todoDeadlineDueToday => _t('今天', 'Tdy');
  String get todoDeadlineDueTomorrow => _t('明天', 'Tmr');
  String todoDeadlineDaysLeft(int days) => _t('$days天', '${days}d');
  String todoDeadlineOverdue(int days) => _t('已逾期', 'Overdue');
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
  String get todoSubItemsPageTitle => _t('子项', 'Subtasks');
  String get todoSubItemsEmptyTitle => _t('还没有子项', 'No subtasks yet');
  String get todoSubItemsEmptySubtitle =>
      _t('点击右上角加号添加', 'Tap + at top right to add');
  String todoSubItemsProgress(int completed, int total) =>
      _t('$completed/$total', '$completed/$total');
  String get todoSubItemsSelect => _t('选择', 'Select');
  String get todoSubItemsCancelSelect => _t('取消', 'Cancel');
  String get todoSubItemsDeleteSelected => _t('删除', 'Delete');
  String get todoSubItemsDeleteTitle => _t('删除子项', 'Delete subtask');
  String todoSubItemsDeleteMessage(String title) => _t(
        '确定删除「$title」吗？',
        'Delete “$title”?',
      );
  String get todoSubItemsDeleteSelectedTitle => _t('删除所选子项？', 'Delete selected subtasks?');
  String todoSubItemsDeleteSelectedBody(int count) => _t(
        '确定要删除 $count 项子项吗？',
        'Delete $count selected subtask(s)?',
      );
  String get todoSubItemHint => _t('添加子项…', 'Add subtask…');
  String get todoSubItemValidation => _t('请填写子项内容', 'Please enter subtask content');
  String get todoSubItemNewDefault => _t('新子项', 'New subtask');

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
  String get reminderHintContent => _t('填写内容', 'Add content');
  String get reminderValidationContent => _t('请填写提醒内容', 'Please enter content');
  String get reminderFieldNotes => _t('备注', 'Notes');
  String get reminderHintNotes => _t('添加备注', 'Add notes');
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
  String get reminderHoldToRecord => _t('按住说话', 'Hold to talk');
  String get reminderReleaseToStop => _t('松开结束', 'Release to stop');
  String get reminderRerecord => _t('重录', 'Re-record');
  String get reminderPreviewRecording => _t('试听录音', 'Preview recording');
  String get reminderPreviewPlay => _t('预览播放', 'Preview play');
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
  String get reminderMicPermissionTitle =>
      _t('需要麦克风权限', 'Microphone access needed');
  String get reminderMicPermissionBody => _t(
        '请在系统设置中允许 Murmur 使用麦克风，以便录制亲声提醒。',
        'Allow Murmur to use the microphone in Settings to record voice reminders.',
      );
  String get reminderMicPermissionOpenSettings => _t('去设置', 'Open Settings');
  String get notificationTapToPlayVoice =>
      _t('亲声提醒 · 点开播放', 'Voice reminder · tap to play');
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
  String get voiceSectionPresets => _t('预设声线', 'Preset voices');
  String get voiceSectionCustom => _t('自定义声线', 'Custom voice');
  String get voiceCustomCloneHint => _t(
        '文案亲声目前使用系统 TTS 朗读。录制亲声可直接使用你的声音。完整声音克隆（用少量样本生成专属声线）正在筹备中。',
        'Text reminders use system TTS. Recorded voice uses your own audio. Full voice cloning from short samples is coming soon.',
      );
  String get voicePresetDefault => _t('默认', 'Default');
  String get voicePresetWarmFemale => _t('温柔女声', 'Warm female');
  String get voicePresetCalmMale => _t('沉稳男声', 'Calm male');
  String get voiceTapToPreview => _t('点击预览', 'Tap to preview');
  String get voiceSectionRecordings => _t('我的录音', 'My recordings');
  String get voiceRecordingsRetentionHint => _t(
        '录音保留近 7 天，过期自动删除。收藏后可永久保存并命名。',
        'Recordings are kept for 7 days, then removed. Save favorites to keep them.',
      );
  String get voiceSectionSavedRecordings => _t('已收藏', 'Saved');
  String get voiceSectionRecentRecordings => _t('近 7 天', 'Last 7 days');
  String get voiceEmptyRecordings => _t(
        '还没有录音\n可在创建日程或待办时录制',
        'No recordings yet\nRecord when creating an event or task',
      );
  String get voiceEmptySavedRecordings => _t('暂无收藏录音', 'No saved recordings');
  String voiceRecordingExpiresIn(int days) =>
      _t('还剩 $days 天', '$days days left');
  String get voiceSaveRecording => _t('收藏', 'Save');
  String get voiceSaveRecordingTitle => _t('收藏录音', 'Save recording');
  String get voiceSaveRecordingNameHint => _t('给录音起个名字', 'Name this recording');
  String get voiceRenameRecordingTitle => _t('重命名录音', 'Rename recording');
  String get voiceRecordingSavedToast => _t('已收藏', 'Saved');
  String get voiceUnsaveRecordingTitle => _t('取消收藏', 'Remove from saved');
  String voiceUnsaveRecordingMessage(String name) =>
      _t('确定取消收藏「$name」吗？录音将移回近 7 天列表。', 'Remove "$name" from saved? It will move back to your last 7 days list.');
  String get voiceUnsaveRecordingConfirm => _t('取消收藏', 'Remove');
  String get voiceRecordingUnsavedToast => _t('已取消收藏', 'Removed from saved');
  String get voicePickSavedRecording => _t('收藏录音', 'Saved recording');
  String get voicePickSavedRecordingTitle => _t('选择收藏录音', 'Choose saved recording');
  String get voiceRecordInputTab => _t('录制', 'Record');
  String get voiceSavedInputTab => _t('收藏', 'Saved');
  String get voiceOrDivider => _t('或', 'or');
  String get voiceLocalRecording => _t('临时录音', 'Temporary recording');
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

  // Family page
  String get familyPageTitle => _t('亲友', 'Family');
  String get familyPlaceholderTitle => _t('亲友功能即将推出', 'Family features coming soon');
  String get familyPlaceholderSubtitle => _t(
        '在这里关心家人朋友的日程与提醒',
        'Stay connected with loved ones’ schedules and reminders',
      );

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
