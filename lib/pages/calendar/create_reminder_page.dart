import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/services/emotion_service.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/widgets/inline_date_picker.dart';
import 'package:murmur/widgets/inline_datetime_picker.dart';
import 'package:murmur/widgets/inline_repeat_days_picker.dart';
import 'package:murmur/widgets/inline_time_picker.dart';
import 'package:murmur/widgets/inline_time_range_picker.dart';

enum _VoiceRemindMode { textAndPreset, record }

enum _ExpandedField { none, eventDate, eventTime, customRemindTime }

class CreateReminderPage extends ConsumerStatefulWidget {
  const CreateReminderPage({
    super.key,
    this.initialDate,
    this.editingReminder,
  });

  final DateTime? initialDate;
  final Reminder? editingReminder;

  static Future<bool?> show(
    BuildContext context, {
    DateTime? initialDate,
    Reminder? editingReminder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: AppTheme.groupedBackgroundColor,
      builder: (BuildContext sheetContext) {
        final double sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
        return SizedBox(
          height: sheetHeight,
          child: CreateReminderPage(
            initialDate: initialDate,
            editingReminder: editingReminder,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<CreateReminderPage> createState() => _CreateReminderPageState();
}

class _CreateReminderPageState extends ConsumerState<CreateReminderPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _remindTextController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  late DateTime _eventDate;
  late bool _isAllDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _remindEnabled;
  late bool _voiceRemindEnabled;
  late String _remindOffset;
  DateTime? _customRemindAt;
  late String _remindFrequency;
  List<int> _remindRepeatDays = <int>[];
  late String _voiceSelection;
  late _VoiceRemindMode _voiceRemindMode;
  String? _recordingPath;
  bool _isRecording = false;
  _ExpandedField _expandedField = _ExpandedField.none;

  bool get _isEditing => widget.editingReminder != null;

  bool get _isEditingTodoDeadline =>
      widget.editingReminder?.isTodoDeadline ?? false;

  DateTime get _dateFirst => DateTime(DateTime.now().year - 1, 1, 1);
  DateTime get _dateLast => DateTime(DateTime.now().year + 3, 12, 31);

  @override
  void initState() {
    super.initState();
    _initFromReminderOrDefaults();
  }

  void _initFromReminderOrDefaults() {
    final Reminder? existing = widget.editingReminder;
    final DateTime now = DateTime.now();
    final DateTime baseDay = widget.initialDate ?? now;

    if (existing != null) {
      _titleController.text = existing.title;
      _notesController.text = existing.notes ?? '';
      _remindTextController.text = existing.remindText ?? '';
      _eventDate = DateTimeUtils.startOfDay(existing.scheduledTime ?? baseDay);
      if (existing.isTodoDeadline) {
        _isAllDay = false;
        _startTime = existing.scheduledTime != null
            ? TimeOfDay.fromDateTime(existing.scheduledTime!)
            : const TimeOfDay(hour: 23, minute: 59);
        _endTime = _startTime;
      } else {
        _isAllDay = existing.isAllDay;
        if (existing.scheduledTime != null && !existing.isAllDay) {
          _startTime = TimeOfDay.fromDateTime(existing.scheduledTime!);
          _endTime = existing.endTime != null
              ? TimeOfDay.fromDateTime(existing.endTime!)
              : TimeOfDay.fromDateTime(
                  existing.scheduledTime!.add(const Duration(hours: 1)),
                );
        } else {
          _startTime = const TimeOfDay(hour: 9, minute: 0);
          _endTime = const TimeOfDay(hour: 10, minute: 0);
        }
      }
      _remindEnabled = existing.remindEnabled;
      _voiceRemindEnabled = existing.voiceRemindEnabled;
      _remindFrequency = existing.remindFrequency;
      _customRemindAt = existing.remindAt;
      _remindRepeatDays = List<int>.from(existing.remindRepeatDays);
      if (_remindRepeatDays.isEmpty && existing.remindAt != null) {
        _remindRepeatDays = ReminderTimeRules.defaultRepeatDaysForFrequency(
          frequency: existing.remindFrequency,
          anchorDate: existing.remindAt,
        );
      }
      _remindOffset = _inferOffset(existing);
      _voiceSelection = _voiceSelectionFromReminder(existing);
      if (existing.voiceRemindEnabled &&
          existing.isCustomVoice &&
          existing.voicePath != null &&
          existing.voicePath!.isNotEmpty) {
        _voiceRemindMode = _VoiceRemindMode.record;
        _recordingPath = existing.voicePath;
      } else {
        _voiceRemindMode = _VoiceRemindMode.textAndPreset;
      }
      return;
    }

    _eventDate = DateTimeUtils.startOfDay(baseDay);
    _isAllDay = true;
    _startTime = TimeOfDay.fromDateTime(now);
    _endTime = TimeOfDay(
      hour: (now.hour + 1) % 24,
      minute: now.minute,
    );
    _remindEnabled = true;
    _voiceRemindEnabled = false;
    _voiceRemindMode = _VoiceRemindMode.textAndPreset;
    _remindOffset = ReminderTimeRules.offsetAtTime;
    _remindFrequency = 'once';
    _voiceSelection = VoiceService.defaultVoiceId;
  }

  String _voiceSelectionFromReminder(Reminder reminder) {
    if (reminder.isCustomVoice &&
        reminder.voicePath != null &&
        reminder.voicePath!.isNotEmpty) {
      return reminder.voicePath!;
    }
    return reminder.remindVoiceId ?? reminder.voiceId ?? VoiceService.defaultVoiceId;
  }

  ({String soundId, String voiceId, String? voicePath, bool isCustomVoice, String remindVoiceId})
      _resolveVoiceFields() {
    return (
      soundId: _voiceSelection,
      voiceId: _voiceSelection,
      voicePath: null,
      isCustomVoice: false,
      remindVoiceId: _voiceSelection,
    );
  }

  String _inferOffset(Reminder reminder) {
    if (!reminder.remindEnabled || reminder.remindAt == null) {
      return ReminderTimeRules.offsetAtTime;
    }
    final DateTime base = reminder.isAllDay
        ? DateTime(
            reminder.scheduledTime!.year,
            reminder.scheduledTime!.month,
            reminder.scheduledTime!.day,
            9,
            0,
          )
        : reminder.scheduledTime!;
    final Duration diff = base.difference(reminder.remindAt!);
    if (diff == Duration.zero) {
      return ReminderTimeRules.offsetAtTime;
    }
    if (diff == const Duration(minutes: 15)) {
      return ReminderTimeRules.offsetBefore15m;
    }
    if (diff == const Duration(hours: 1)) {
      return ReminderTimeRules.offsetBefore1h;
    }
    return ReminderTimeRules.offsetCustom;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _remindTextController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  DateTime? get _startDateTime {
    if (_isAllDay) {
      return null;
    }
    return DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _startTime.hour,
      _startTime.minute,
    );
  }

  DateTime? get _endDateTime {
    if (_isAllDay) {
      return null;
    }
    return DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _endTime.hour,
      _endTime.minute,
    );
  }

  DateTime? get _computedRemindAt {
    return ReminderTimeRules.computeRemindAt(
      remindEnabled: _remindEnabled,
      offset: _remindOffset,
      customRemindAt: _customRemindAt,
      eventDate: _eventDate,
      isAllDay: _isAllDay,
      startDateTime: _startDateTime,
    );
  }

  bool get _presetVoiceValid =>
      VoiceService.presetVoices.any((VoiceOption v) => v.id == _voiceSelection);

  void _toggleExpandedField(_ExpandedField field) {
    _setStatePreservingScroll(() {
      _expandedField = _expandedField == field ? _ExpandedField.none : field;
    });
  }

  void _restoreScrollOffset(double offset) {
    void apply() {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final double maxExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(0.0, maxExtent));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      apply();
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    });
  }

  double get _currentScrollOffset =>
      _scrollController.hasClients ? _scrollController.offset : 0.0;

  void _setStatePreservingScroll(VoidCallback fn) {
    final double scrollOffset = _currentScrollOffset;
    setState(fn);
    _restoreScrollOffset(scrollOffset);
  }

  void _copyRemindTextFromTitle() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).reminderSnackFillContent)),
      );
      return;
    }
    _setStatePreservingScroll(() => _remindTextController.text = title);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final String? path = await VoiceService.stopRecording();
      if (!mounted) {
        return;
      }
      _setStatePreservingScroll(() {
        _isRecording = false;
        if (path != null && path.isNotEmpty) {
          _recordingPath = path;
        }
      });
      return;
    }

    try {
      await VoiceService.startRecording();
      if (!mounted) {
        return;
      }
      _setStatePreservingScroll(() => _isRecording = true);

      Future<void>.delayed(const Duration(seconds: 30), () async {
        if (_isRecording && mounted) {
          await _toggleRecording();
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).reminderSnackMicPermission)),
      );
    }
  }

  Future<void> _previewRecording() async {
    if (_recordingPath == null || _recordingPath!.isEmpty) {
      return;
    }
    await VoiceService.play(voicePath: _recordingPath);
  }

  bool _isVoiceRemindReady() {
    if (!_voiceRemindEnabled) {
      return true;
    }
    if (_voiceRemindMode == _VoiceRemindMode.textAndPreset) {
      return _remindTextController.text.trim().isNotEmpty &&
          VoiceService.presetVoices.any((VoiceOption v) => v.id == _voiceSelection);
    }
    return _recordingPath != null && _recordingPath!.isNotEmpty;
  }

  String _eventTimeRangeSummary(BuildContext context) {
    return '${_startTime.format(context)} – ${_endTime.format(context)}';
  }

  String? _eventDurationSummary() {
    final AppLocalizations l10n = AppLocalizationsBinding.instance;
    final int diff = timeRangeMinutes(_endTime) - timeRangeMinutes(_startTime);
    if (diff <= 0) {
      return null;
    }
    if (diff % 60 == 0) {
      return l10n.reminderDurationHours(diff ~/ 60);
    }
    if (diff < 60) {
      return l10n.reminderDurationMinutes(diff);
    }
    return l10n.reminderDurationHoursMinutes(diff ~/ 60, diff % 60);
  }

  String _remindOffsetLabel(String offset) => ReminderTimeRules.offsetLabel(offset);

  String _remindFrequencyLabel(String frequency) =>
      ReminderTimeRules.frequencyLabel(frequency);

  String _presetVoiceLabel(String voiceId) {
    for (final VoiceOption voice in VoiceService.presetVoices) {
      if (voice.id == voiceId) {
        return voice.name;
      }
    }
    return AppLocalizationsBinding.instance.voiceDefaultPreset;
  }

  DateTime _defaultCustomRemindAt() {
    if (_startDateTime != null) {
      return _startDateTime!;
    }
    return DateTime(_eventDate.year, _eventDate.month, _eventDate.day, 9, 0);
  }

  Future<void> _pickRemindOffset() async {
    final double scrollOffset = _currentScrollOffset;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<AppPickerOption<String>> options = <AppPickerOption<String>>[
      AppPickerOption(value: ReminderTimeRules.offsetAtTime, label: l10n.remindOffsetOnTime),
      AppPickerOption(value: ReminderTimeRules.offsetBefore15m, label: l10n.remindOffsetBefore15m),
      AppPickerOption(value: ReminderTimeRules.offsetBefore1h, label: l10n.remindOffsetBefore1h),
      AppPickerOption(value: ReminderTimeRules.offsetCustom, label: l10n.remindOffsetCustom),
    ];
    final String? picked = await showAppOptionPicker<String>(
      context: context,
      title: l10n.reminderRemindOffset,
      options: options,
      current: _remindOffset,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _remindOffset = picked;
      if (picked == ReminderTimeRules.offsetCustom) {
        _customRemindAt ??= _defaultCustomRemindAt();
        _expandedField = _ExpandedField.customRemindTime;
      } else if (_expandedField == _ExpandedField.customRemindTime) {
        _expandedField = _ExpandedField.none;
      }
    });
    _restoreScrollOffset(scrollOffset);
  }

  Future<void> _pickRemindFrequency() async {
    final double scrollOffset = _currentScrollOffset;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<AppPickerOption<String>> options = <AppPickerOption<String>>[
      AppPickerOption(value: 'once', label: l10n.remindFrequencyOnce),
      AppPickerOption(value: 'daily', label: l10n.remindFrequencyDaily),
      AppPickerOption(value: 'weekly', label: l10n.remindFrequencyWeekly),
      AppPickerOption(value: 'monthly', label: l10n.remindFrequencyMonthly),
    ];
    final String? picked = await showAppOptionPicker<String>(
      context: context,
      title: l10n.reminderRepeat,
      options: options,
      current: _remindFrequency,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _remindFrequency = picked;
      if (_remindOffset == ReminderTimeRules.offsetCustom) {
        final DateTime current = _customRemindAt ?? _defaultCustomRemindAt();
        _customRemindAt = ReminderTimeRules.normalizeCustomRemindForFrequency(
          current: current,
          frequency: picked,
          anchorDate: _eventDate,
        );
      }
      if (ReminderTimeRules.usesRepeatDaySelection(picked)) {
        _remindRepeatDays = ReminderTimeRules.defaultRepeatDaysForFrequency(
          frequency: picked,
          anchorDate: _remindOffset == ReminderTimeRules.offsetCustom
              ? (_customRemindAt ?? _defaultCustomRemindAt())
              : (_startDateTime ?? _eventDate),
        );
      } else {
        _remindRepeatDays = <int>[];
      }
    });
    _restoreScrollOffset(scrollOffset);
  }

  Future<void> _pickPresetVoice() async {
    final double scrollOffset = _currentScrollOffset;
    final List<AppPickerOption<String>> options = VoiceService.presetVoices
        .map(
          (VoiceOption voice) => AppPickerOption<String>(
            value: voice.id,
            label: voice.name,
          ),
        )
        .toList();
    final String current = VoiceService.presetVoices
            .any((VoiceOption v) => v.id == _voiceSelection)
        ? _voiceSelection
        : VoiceService.defaultVoiceId;
    final String? picked = await showAppOptionPicker<String>(
      context: context,
      title: AppLocalizations.of(context).reminderVoiceSound,
      options: options,
      current: current,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _voiceSelection = picked);
    _restoreScrollOffset(scrollOffset);
  }

  bool get _canSave {
    if (_remindEnabled &&
        ReminderTimeRules.usesRepeatDaySelection(_remindFrequency) &&
        _remindRepeatDays.isEmpty) {
      return false;
    }
    if (_remindEnabled && _remindOffset == ReminderTimeRules.offsetCustom) {
      return _customRemindAt != null;
    }
    if (_remindEnabled && _computedRemindAt == null) {
      return false;
    }
    if (_remindEnabled && _voiceRemindEnabled && !_isVoiceRemindReady()) {
      return false;
    }
    if (!_isEditingTodoDeadline &&
        !_isAllDay &&
        _endDateTime != null &&
        _startDateTime != null) {
      if (!_endDateTime!.isAfter(_startDateTime!)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveReminder() async {
    if (!(_formKey.currentState?.validate() ?? false) || !_canSave) {
      return;
    }

    final String title = _titleController.text.trim();
    final String emotionTag = EmotionService.detectEmotionTag(title);
    final DateTime finalStart;
    final DateTime? finalEnd;
    final bool saveAsAllDay;

    if (_isEditingTodoDeadline) {
      finalStart = DateTime(
        _eventDate.year,
        _eventDate.month,
        _eventDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      finalEnd = null;
      saveAsAllDay = false;
    } else {
      finalStart = ReminderTimeRules.eventStart(
        eventDate: _eventDate,
        isAllDay: _isAllDay,
        startDateTime: _startDateTime,
      );
      finalEnd = ReminderTimeRules.eventEnd(
        eventDate: _eventDate,
        isAllDay: _isAllDay,
        startDateTime: _startDateTime,
        endDateTime: _endDateTime,
      );
      saveAsAllDay = _isAllDay;
    }
    final DateTime? finalRemindAt = _computedRemindAt;
    final String notes = _notesController.text.trim();
    final String? remindText = _voiceRemindEnabled &&
            _voiceRemindMode == _VoiceRemindMode.textAndPreset
        ? _remindTextController.text.trim()
        : null;
    final voiceFields = _voiceRemindEnabled
        ? (_voiceRemindMode == _VoiceRemindMode.record
            ? (
                soundId: 'my_recorded_voice',
                voiceId: 'my_recorded_voice',
                voicePath: _recordingPath,
                isCustomVoice: true,
                remindVoiceId: 'my_recorded_voice',
              )
            : _resolveVoiceFields())
        : (
            soundId: 'default',
            voiceId: null as String?,
            voicePath: null as String?,
            isCustomVoice: false,
            remindVoiceId: null as String?,
          );
    final notifier = ref.read(reminderListProvider.notifier);

    if (_isEditing) {
      await notifier.updateReminder(
        reminderId: widget.editingReminder!.id,
        title: title,
        scheduledTime: finalStart,
        endTime: finalEnd,
        clearEndTime: _isEditingTodoDeadline,
        isAllDay: saveAsAllDay,
        timeType: 'fixed',
        soundId: voiceFields.soundId,
        voiceId: voiceFields.voiceId,
        voicePath: voiceFields.voicePath,
        isCustomVoice: voiceFields.isCustomVoice,
        emotionTag: emotionTag,
        remindEnabled: _remindEnabled,
        remindAt: finalRemindAt,
        clearRemindAt: !_remindEnabled,
        remindFrequency: _remindEnabled ? _remindFrequency : 'once',
        remindRepeatDays: _remindEnabled ? _remindRepeatDays : const <int>[],
        remindText: remindText?.isEmpty == true ? null : remindText,
        remindVoiceId: voiceFields.remindVoiceId,
        voiceRemindEnabled: _voiceRemindEnabled,
        notes: notes.isEmpty ? null : notes,
        clearNotes: notes.isEmpty,
      );
    } else {
      await notifier.addReminder(
        title: title,
        scheduledTime: finalStart,
        endTime: finalEnd,
        isAllDay: saveAsAllDay,
        timeType: 'fixed',
        soundId: voiceFields.soundId,
        voiceId: voiceFields.voiceId,
        voicePath: voiceFields.voicePath,
        isCustomVoice: voiceFields.isCustomVoice,
        emotionTag: emotionTag,
        remindEnabled: _remindEnabled,
        remindAt: finalRemindAt,
        remindFrequency: _remindEnabled ? _remindFrequency : 'once',
        remindRepeatDays: _remindEnabled ? _remindRepeatDays : const <int>[],
        remindText: remindText?.isEmpty == true ? null : remindText,
        remindVoiceId: voiceFields.remindVoiceId,
        voiceRemindEnabled: _voiceRemindEnabled,
        notes: notes.isEmpty ? null : notes,
      );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _selectVoiceRemindMode(_VoiceRemindMode mode) {
    _setStatePreservingScroll(() {
      _voiceRemindMode = mode;
      if (_voiceRemindMode == _VoiceRemindMode.textAndPreset &&
          !VoiceService.presetVoices.any((VoiceOption v) => v.id == _voiceSelection)) {
        _voiceSelection = VoiceService.defaultVoiceId;
      }
    });
  }

  Widget _buildVoiceModeButton({
    required String label,
    required _VoiceRemindMode mode,
  }) {
    final bool selected = _voiceRemindMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectVoiceRemindMode(mode),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : const Color(0xFFE5E5EA),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceModeSelector() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(child: _buildVoiceModeButton(label: l10n.reminderVoiceModeText, mode: _VoiceRemindMode.textAndPreset)),
          const SizedBox(width: 10),
          Expanded(child: _buildVoiceModeButton(label: l10n.reminderVoiceModeRecord, mode: _VoiceRemindMode.record)),
        ],
      ),
    );
  }

  Widget _buildCustomRemindPicker() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime base = _customRemindAt ?? _defaultCustomRemindAt();
    if (_remindFrequency == 'daily') {
      return AppInlineTimePicker(
        time: TimeOfDay.fromDateTime(base),
        sectionLabel: l10n.reminderSectionLabelRemindTime,
        onChanged: (TimeOfDay picked) {
          _setStatePreservingScroll(() {
            _customRemindAt = DateTime(
              base.year,
              base.month,
              base.day,
              picked.hour,
              picked.minute,
            );
          });
        },
      );
    }
    if (ReminderTimeRules.usesRepeatDaySelection(_remindFrequency)) {
      return AppInlineTimePicker(
        time: TimeOfDay.fromDateTime(base),
        sectionLabel: l10n.reminderSectionLabelRemindTime,
        onChanged: (TimeOfDay picked) {
          _setStatePreservingScroll(() {
            _customRemindAt = DateTime(
              base.year,
              base.month,
              base.day,
              picked.hour,
              picked.minute,
            );
          });
        },
      );
    }

    return AppInlineDateTimePicker(
      selectedDateTime: base,
      firstDate: _dateFirst,
      lastDate: _dateLast,
      onChanged: (DateTime value) {
        _setStatePreservingScroll(() => _customRemindAt = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? remindPreview = _computedRemindAt;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  Expanded(
                    child: Text(
                      _isEditing ? l10n.reminderSheetEdit : l10n.reminderSheetCreate,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _canSave ? _saveReminder : null,
                    child: Text(
                      l10n.commonSave,
                      style: TextStyle(
                        color: _canSave ? scheme.primary : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
              AppSectionHeader(
                title: l10n.reminderSectionEvent,
                style: AppSectionHeaderStyle.caption,
              ),
              AppDetailSection(
                children: <Widget>[
                  AppDetailTextField(
                    icon: Icons.edit_outlined,
                    iconColor: scheme.primary,
                    label: l10n.reminderFieldContent,
                    controller: _titleController,
                    hintText: l10n.reminderHintContent,
                    textInputAction: TextInputAction.next,
                    validator: (String? value) {
                      if ((value ?? '').trim().isEmpty) {
                        return l10n.reminderValidationContent;
                      }
                      return null;
                    },
                  ),
                  AppDetailTextField(
                    icon: Icons.notes_outlined,
                    iconColor: AppTheme.secondaryLabelColor,
                    label: l10n.reminderFieldNotes,
                    controller: _notesController,
                    hintText: l10n.reminderHintNotes,
                    maxLines: 2,
                    showDivider: false,
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppSectionHeader(
                title: l10n.reminderSectionTime,
                style: AppSectionHeaderStyle.caption,
              ),
              AppDetailSection(
                children: <Widget>[
                  if (!_isEditingTodoDeadline)
                    AppDetailSwitchTile(
                      icon: Icons.wb_sunny_outlined,
                      iconColor: scheme.primary,
                      title: l10n.reminderAllDay,
                      value: _isAllDay,
                      onChanged: (bool value) {
                        _setStatePreservingScroll(() {
                          _isAllDay = value;
                          if (value && _expandedField == _ExpandedField.eventTime) {
                            _expandedField = _ExpandedField.none;
                          }
                        });
                      },
                    ),
                  AppDetailTile(
                    icon: Icons.calendar_today_outlined,
                    iconColor: scheme.primary,
                    title: l10n.reminderFieldDate,
                    value: inlineDatePickerSummary(_eventDate),
                    onTap: () => _toggleExpandedField(_ExpandedField.eventDate),
                    expanded: _expandedField == _ExpandedField.eventDate,
                    showDivider: _expandedField != _ExpandedField.eventDate &&
                        (_isEditingTodoDeadline || _isAllDay),
                  ),
                  if (_expandedField == _ExpandedField.eventDate)
                    AppInlineDatePicker(
                      selectedDate: _eventDate,
                      firstDate: _dateFirst,
                      lastDate: _dateLast,
                      onChanged: (DateTime date) {
                        _setStatePreservingScroll(() => _eventDate = date);
                      },
                    ),
                  if (_isEditingTodoDeadline) ...<Widget>[
                    AppDetailTile(
                      icon: Icons.access_time,
                      iconColor: AppTheme.deadlineColor,
                      title: l10n.reminderFieldDeadline,
                      value: _startTime.format(context),
                      onTap: () => _toggleExpandedField(_ExpandedField.eventTime),
                      expanded: _expandedField == _ExpandedField.eventTime,
                      showDivider: _expandedField != _ExpandedField.eventTime,
                    ),
                    if (_expandedField == _ExpandedField.eventTime)
                      AppInlineTimePicker(
                        time: _startTime,
                        sectionLabel: l10n.reminderFieldDeadline,
                        onChanged: (TimeOfDay time) {
                          _setStatePreservingScroll(() => _startTime = time);
                        },
                      ),
                  ] else if (!_isAllDay) ...<Widget>[
                    AppDetailTile(
                      icon: Icons.access_time,
                      iconColor: AppTheme.iosBlue,
                      title: l10n.reminderFieldTime,
                      value: _eventTimeRangeSummary(context),
                      subtitle: _expandedField == _ExpandedField.eventTime
                          ? null
                          : _eventDurationSummary(),
                      onTap: () => _toggleExpandedField(_ExpandedField.eventTime),
                      expanded: _expandedField == _ExpandedField.eventTime,
                      showDivider: _expandedField != _ExpandedField.eventTime,
                    ),
                    if (_expandedField == _ExpandedField.eventTime)
                      AppInlineTimeRangePicker(
                        start: _startTime,
                        end: _endTime,
                        onChanged: (TimeOfDay start, TimeOfDay end) {
                          _setStatePreservingScroll(() {
                            _startTime = start;
                            _endTime = end;
                          });
                        },
                      ),
                  ],
                ],
              ),
              if (!_isEditingTodoDeadline &&
                  !_isAllDay &&
                  _startDateTime != null &&
                  _endDateTime != null &&
                  !_endDateTime!.isAfter(_startDateTime!))
                AppFootnote(
                  text: l10n.reminderTimeRangeInvalid,
                  color: scheme.error,
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                ),
              const SizedBox(height: 12),
              AppSectionHeader(
                title: l10n.reminderSectionRemind,
                style: AppSectionHeaderStyle.caption,
              ),
              AppDetailSection(
                children: <Widget>[
                  AppDetailSwitchTile(
                    icon: Icons.notifications_outlined,
                    iconColor: AppTheme.destructiveColor,
                    title: l10n.reminderNeedRemind,
                    subtitle: l10n.reminderNeedRemindSubtitleEvent,
                    value: _remindEnabled,
                    showDivider: _remindEnabled,
                    onChanged: (bool value) {
                      _setStatePreservingScroll(() {
                        _remindEnabled = value;
                        if (!value) {
                          _voiceRemindEnabled = false;
                        }
                      });
                    },
                  ),
                  if (_remindEnabled) ...<Widget>[
                    AppDetailTile(
                      icon: Icons.schedule_outlined,
                      iconColor: AppTheme.iosBlue,
                      title: l10n.reminderRemindOffset,
                      value: _remindOffsetLabel(_remindOffset),
                      onTap: _pickRemindOffset,
                    ),
                    if (_remindOffset == ReminderTimeRules.offsetCustom) ...<Widget>[
                      AppDetailTile(
                        icon: Icons.notifications_active_outlined,
                        iconColor: AppTheme.destructiveColor,
                        title: l10n.reminderCustomTime,
                        value: ReminderTimeRules.customRemindTileValue(
                          remindAt: _customRemindAt,
                          frequency: _remindFrequency,
                          repeatDays: _remindRepeatDays,
                        ),
                        placeholder: _customRemindAt == null,
                        onTap: () => _toggleExpandedField(_ExpandedField.customRemindTime),
                        expanded: _expandedField == _ExpandedField.customRemindTime,
                        showDivider: _expandedField != _ExpandedField.customRemindTime,
                      ),
                      if (_expandedField == _ExpandedField.customRemindTime)
                        _buildCustomRemindPicker(),
                    ],
                    AppDetailTile(
                      icon: Icons.repeat,
                      iconColor: AppTheme.secondaryLabelColor,
                      title: l10n.reminderRepeat,
                      value: _remindFrequencyLabel(_remindFrequency),
                      subtitle: remindPreview != null
                          ? ReminderTimeRules.remindPreviewLabel(
                              remindAt: remindPreview,
                              frequency: _remindFrequency,
                              repeatDays: _remindRepeatDays,
                            )
                          : null,
                      onTap: _pickRemindFrequency,
                      expanded: ReminderTimeRules.usesRepeatDaySelection(_remindFrequency),
                      showDivider:
                          !ReminderTimeRules.usesRepeatDaySelection(_remindFrequency),
                    ),
                    if (ReminderTimeRules.usesRepeatDaySelection(_remindFrequency))
                      AppInlineRepeatDaysPicker(
                        frequency: _remindFrequency,
                        selectedDays: _remindRepeatDays,
                        onChanged: (List<int> days) {
                          _setStatePreservingScroll(() => _remindRepeatDays = days);
                        },
                      ),
                  ],
                ],
              ),
              if (_remindEnabled) ...<Widget>[
                const SizedBox(height: 12),
                AppSectionHeader(
                  title: l10n.reminderSectionVoice,
                  style: AppSectionHeaderStyle.caption,
                ),
                AppDetailSection(
                  children: <Widget>[
                    AppDetailSwitchTile(
                      icon: Icons.graphic_eq_rounded,
                      iconColor: scheme.primary,
                      title: l10n.reminderVoiceRemind,
                      subtitle: l10n.reminderVoiceRemindSubtitle,
                      value: _voiceRemindEnabled,
                      showDivider: _voiceRemindEnabled,
                      onChanged: (bool value) {
                        _setStatePreservingScroll(() => _voiceRemindEnabled = value);
                      },
                    ),
                    if (_voiceRemindEnabled) ...<Widget>[
                      _buildVoiceModeSelector(),
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 56,
                        color: AppTheme.separatorColor,
                      ),
                      if (_voiceRemindMode == _VoiceRemindMode.textAndPreset) ...<Widget>[
                        AppDetailTextField(
                          icon: Icons.chat_bubble_outline,
                          iconColor: AppTheme.secondaryLabelColor,
                          label: l10n.reminderRemindText,
                          controller: _remindTextController,
                          hintText: l10n.reminderRemindTextHint,
                          onChanged: (_) => setState(() {}),
                        ),
                        AppDetailActionTile(
                          icon: Icons.content_copy_outlined,
                          label: l10n.reminderSameAsEvent,
                          compact: true,
                          onTap: _copyRemindTextFromTitle,
                        ),
                        AppDetailTile(
                          icon: Icons.record_voice_over_outlined,
                          iconColor: scheme.primary,
                          title: l10n.reminderVoiceSound,
                          value: _presetVoiceValid
                              ? _presetVoiceLabel(_voiceSelection)
                              : l10n.commonPleaseSelect,
                          placeholder: !_presetVoiceValid,
                          onTap: _pickPresetVoice,
                          showDivider: false,
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: <Widget>[
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _toggleRecording,
                                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                                  label: Text(_isRecording ? l10n.reminderRecordStop : l10n.reminderRecordStart),
                                ),
                              ),
                              if (_recordingPath != null &&
                                  _recordingPath!.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _previewRecording,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text(l10n.reminderPreviewRecording),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
                if (_voiceRemindEnabled &&
                    _voiceRemindMode == _VoiceRemindMode.textAndPreset &&
                    (_remindTextController.text.trim().isEmpty || !_presetVoiceValid))
                  AppFootnote(
                    text: l10n.reminderValidationVoice,
                    color: scheme.error,
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  ),
                if (_voiceRemindEnabled && _voiceRemindMode == _VoiceRemindMode.record)
                  AppFootnote(
                    text: _isRecording
                        ? l10n.reminderRecordingInProgress
                        : (_recordingPath != null && _recordingPath!.isNotEmpty
                            ? l10n.reminderRecordingSaved
                            : l10n.reminderRecordingRequired),
                    color: _isRecording
                        ? AppTheme.primaryColor
                        : (_recordingPath != null && _recordingPath!.isNotEmpty
                            ? null
                            : scheme.error),
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _saveReminder : null,
                  child: Text(_isEditing ? l10n.reminderSaveChanges : l10n.commonSave),
                ),
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backward-compatible entry point.
class CreateReminderSheet {
  CreateReminderSheet._();

  static Future<bool?> show(
    BuildContext context, {
    DateTime? initialDate,
    Reminder? editingReminder,
  }) {
    return CreateReminderPage.show(
      context,
      initialDate: initialDate,
      editingReminder: editingReminder,
    );
  }
}
