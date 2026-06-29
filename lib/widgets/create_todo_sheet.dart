import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/models/todo_group.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/providers/todo_group_provider.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/widgets/inline_date_picker.dart';
import 'package:murmur/widgets/inline_datetime_picker.dart';
import 'package:murmur/widgets/inline_repeat_days_picker.dart';
import 'package:murmur/widgets/inline_time_picker.dart';
import 'package:murmur/widgets/voice_record_panel.dart';
import 'package:murmur/widgets/voice_text_preview_panel.dart';

enum _VoiceRemindMode { textAndPreset, record }

enum _ExpandedField { none, deadlineDate, deadlineTime, customRemindTime }

const String _noTodoGroupPickerValue = '';

class CreateTodoSheet extends ConsumerStatefulWidget {
  const CreateTodoSheet({
    super.key,
    this.editingReminder,
    this.initialTodoGroupId,
    this.initialHasDeadline = false,
  });

  final Reminder? editingReminder;
  final String? initialTodoGroupId;
  final bool initialHasDeadline;

  static Future<bool?> show(
    BuildContext context, {
    Reminder? editingReminder,
    String? initialTodoGroupId,
    bool initialHasDeadline = false,
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
          child: CreateTodoSheet(
            editingReminder: editingReminder,
            initialTodoGroupId: initialTodoGroupId,
            initialHasDeadline: initialHasDeadline,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<CreateTodoSheet> createState() => _CreateTodoSheetState();
}

class _CreateTodoSheetState extends ConsumerState<CreateTodoSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _remindTextController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool _hasDeadline = false;
  bool _syncToCalendar = false;
  DateTime _deadlineDate = DateTimeUtils.startOfDay(DateTime.now());
  bool _hasDeadlineSpecificTime = false;
  TimeOfDay _deadlineTime = TimeOfDay.now();
  bool _remindEnabled = false;
  bool _voiceRemindEnabled = false;
  String _remindOffset = ReminderTimeRules.offsetAtTime;
  DateTime? _customRemindAt;
  String _remindFrequency = 'once';
  List<int> _remindRepeatDays = <int>[];
  String _voiceSelection = VoiceService.defaultVoiceId;
  _VoiceRemindMode _voiceRemindMode = _VoiceRemindMode.textAndPreset;
  _VoiceRemindMode _effectiveVoiceRemindMode = _VoiceRemindMode.textAndPreset;
  String? _recordingPath;
  bool _isRecording = false;
  VoiceRecordPanelStatus _voiceRecordStatus = const VoiceRecordPanelStatus(
    inputMode: VoiceRecordInputMode.record,
    hasSelection: false,
  );
  String? _selectedTodoGroupId;
  _ExpandedField _expandedField = _ExpandedField.none;

  bool get _isEditing => widget.editingReminder != null;

  @override
  void initState() {
    super.initState();
    _initFromReminderOrDefaults();
  }

  void _initFromReminderOrDefaults() {
    final Reminder? existing = widget.editingReminder;
    if (existing == null) {
      _selectedTodoGroupId = widget.initialTodoGroupId;
      if (widget.initialHasDeadline) {
        _hasDeadline = true;
        _deadlineDate = DateTimeUtils.startOfDay(DateTime.now());
      }
      return;
    }

    _titleController.text = existing.title;
    _notesController.text = existing.notes ?? '';
    _selectedTodoGroupId = existing.todoGroupId;
    _remindTextController.text = existing.remindText ?? '';
    _hasDeadline = existing.hasDeadline;
    if (existing.deadlineAt != null) {
      _deadlineDate = DateTimeUtils.startOfDay(existing.deadlineAt!);
      final DateTime deadline = existing.deadlineAt!;
      _hasDeadlineSpecificTime = deadline.hour != 23 || deadline.minute != 59;
      if (_hasDeadlineSpecificTime) {
        _deadlineTime = TimeOfDay.fromDateTime(deadline);
      }
    }
    _syncToCalendar = existing.isSyncedToCalendar;
    _remindEnabled = existing.remindEnabled;
    _remindFrequency = existing.remindFrequency;
    _customRemindAt = existing.remindAt;
    _remindRepeatDays = List<int>.from(existing.remindRepeatDays);
    if (_remindRepeatDays.isEmpty && existing.remindAt != null) {
      _remindRepeatDays = ReminderTimeRules.defaultRepeatDaysForFrequency(
        frequency: existing.remindFrequency,
        anchorDate: existing.remindAt,
      );
    }
    _voiceRemindEnabled = existing.voiceRemindEnabled;
    _voiceSelection =
        existing.remindVoiceId ?? existing.voiceId ?? VoiceService.defaultVoiceId;
    if (existing.voiceRemindEnabled &&
        existing.isCustomVoice &&
        existing.voicePath != null &&
        existing.voicePath!.isNotEmpty) {
      _voiceRemindMode = _VoiceRemindMode.record;
      _effectiveVoiceRemindMode = _VoiceRemindMode.record;
      _recordingPath = existing.voicePath;
    }
    if (existing.hasDeadline && existing.remindEnabled) {
      _remindOffset = ReminderTimeRules.inferOffsetFromRemindAt(
        remindEnabled: true,
        remindAt: existing.remindAt,
        eventBase: existing.deadlineAt!,
      );
    } else if (existing.remindEnabled) {
      _remindOffset = ReminderTimeRules.offsetCustom;
    }
  }

  DateTime get _dateFirst => DateTime(DateTime.now().year - 1, 1, 1);
  DateTime get _dateLast => DateTime(DateTime.now().year + 3, 12, 31);

  DateTime get _deadlineAt {
    if (_hasDeadlineSpecificTime) {
      return DateTime(
        _deadlineDate.year,
        _deadlineDate.month,
        _deadlineDate.day,
        _deadlineTime.hour,
        _deadlineTime.minute,
      );
    }
    return DateTime(
      _deadlineDate.year,
      _deadlineDate.month,
      _deadlineDate.day,
      23,
      59,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _remindTextController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleExpandedField(_ExpandedField field) {
    _setStatePreservingScroll(() {
      _expandedField = _expandedField == field ? _ExpandedField.none : field;
    });
  }

  double get _currentScrollOffset =>
      _scrollController.hasClients ? _scrollController.offset : 0.0;

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

  void _setStatePreservingScroll(VoidCallback fn) {
    final double scrollOffset = _currentScrollOffset;
    setState(fn);
    _restoreScrollOffset(scrollOffset);
  }

  DateTime _defaultCustomRemindAt() {
    if (_hasDeadline) {
      return _deadlineAt;
    }
    return DateTime.now().add(const Duration(hours: 1));
  }

  DateTime? get _computedRemindAt {
    if (!_remindEnabled) {
      return null;
    }
    if (_hasDeadline) {
      return ReminderTimeRules.computeRemindAt(
        remindEnabled: true,
        offset: _remindOffset,
        customRemindAt: _customRemindAt,
        eventDate: DateTimeUtils.startOfDay(_deadlineAt),
        isAllDay: false,
        startDateTime: _deadlineAt,
      );
    }
    if (_remindOffset == ReminderTimeRules.offsetCustom) {
      return _customRemindAt;
    }
    return null;
  }

  bool get _presetVoiceValid =>
      VoiceService.presetVoices.any((VoiceOption v) => v.id == _voiceSelection);

  void _commitTextVoiceMode() {
    if (_effectiveVoiceRemindMode == _VoiceRemindMode.textAndPreset) {
      return;
    }
    _effectiveVoiceRemindMode = _VoiceRemindMode.textAndPreset;
    _recordingPath = null;
  }

  void _commitRecordVoiceMode(String path) {
    if (_effectiveVoiceRemindMode == _VoiceRemindMode.record &&
        _recordingPath == path) {
      return;
    }
    _effectiveVoiceRemindMode = _VoiceRemindMode.record;
    _recordingPath = path;
    _remindTextController.clear();
  }

  void _onRecordingPathChanged(String? path) {
    if (path != null && path.isNotEmpty) {
      _setStatePreservingScroll(() => _commitRecordVoiceMode(path));
      return;
    }
    _setStatePreservingScroll(() => _recordingPath = path);
  }

  bool _isVoiceRemindReady() {
    if (!_voiceRemindEnabled) {
      return true;
    }
    if (_effectiveVoiceRemindMode == _VoiceRemindMode.textAndPreset) {
      return _remindTextController.text.trim().isNotEmpty && _presetVoiceValid;
    }
    return _recordingPath != null && _recordingPath!.isNotEmpty;
  }

  bool get _canSave {
    if (_titleController.text.trim().isEmpty) {
      return false;
    }
    if (_remindEnabled) {
      if (ReminderTimeRules.usesRepeatDaySelection(_remindFrequency) &&
          _remindRepeatDays.isEmpty) {
        return false;
      }
      if (_usesCustomRemindPicker && _customRemindAt == null) {
        return false;
      }
      if (_computedRemindAt == null) {
        return false;
      }
      if (_voiceRemindEnabled && !_isVoiceRemindReady()) {
        return false;
      }
    }
    return true;
  }

  void _ensureRemindDefaultsOnEnable() {
    if (!_hasDeadline) {
      _remindOffset = ReminderTimeRules.offsetCustom;
      _customRemindAt ??= _defaultCustomRemindAt();
    }
    if (ReminderTimeRules.usesRepeatDaySelection(_remindFrequency) &&
        _remindRepeatDays.isEmpty) {
      _remindRepeatDays = ReminderTimeRules.defaultRepeatDaysForFrequency(
        frequency: _remindFrequency,
        anchorDate: _customRemindAt ??
            (_hasDeadline ? _deadlineDate : _defaultCustomRemindAt()),
      );
    }
  }

  void _copyRemindTextFromTitle() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).todoSnackFillFirst)),
      );
      return;
    }
    _setStatePreservingScroll(() {
      _commitTextVoiceMode();
      _remindTextController.text = title;
    });
  }

  Future<void> _pickRemindOffset() async {
    if (!_hasDeadline) {
      return;
    }
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

  String _todoGroupPickerValue(List<TodoGroup> groups) {
    if (_selectedTodoGroupId == null) {
      return _noTodoGroupPickerValue;
    }
    final bool exists = groups.any((TodoGroup group) => group.id == _selectedTodoGroupId);
    return exists ? _selectedTodoGroupId! : _noTodoGroupPickerValue;
  }

  String _todoGroupDisplayLabel(AppLocalizations l10n, List<TodoGroup> groups) {
    if (_selectedTodoGroupId == null) {
      return l10n.todoGroupNone;
    }
    for (final TodoGroup group in groups) {
      if (group.id == _selectedTodoGroupId) {
        return group.name;
      }
    }
    return l10n.todoGroupNone;
  }

  Future<void> _pickTodoGroup(List<TodoGroup> groups) async {
    final double scrollOffset = _currentScrollOffset;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<AppPickerOption<String>> options = <AppPickerOption<String>>[
      AppPickerOption<String>(value: _noTodoGroupPickerValue, label: l10n.todoGroupNone),
      ...groups.map(
        (TodoGroup group) => AppPickerOption<String>(value: group.id, label: group.name),
      ),
    ];
    final String? picked = await showAppOptionPicker<String>(
      context: context,
      title: l10n.todoGroupPickerTitle,
      options: options,
      current: _todoGroupPickerValue(groups),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedTodoGroupId =
          picked == _noTodoGroupPickerValue ? null : picked;
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
      if (_usesCustomRemindPicker) {
        final DateTime current = _customRemindAt ?? _defaultCustomRemindAt();
        _customRemindAt = ReminderTimeRules.normalizeCustomRemindForFrequency(
          current: current,
          frequency: picked,
          anchorDate: _hasDeadline ? _deadlineDate : current,
        );
        if (ReminderTimeRules.usesRepeatDaySelection(picked)) {
          _remindRepeatDays = ReminderTimeRules.defaultRepeatDaysForFrequency(
            frequency: picked,
            anchorDate: _hasDeadline ? _deadlineDate : current,
          );
        } else {
          _remindRepeatDays = <int>[];
        }
      } else if (ReminderTimeRules.usesRepeatDaySelection(picked)) {
        _remindRepeatDays = ReminderTimeRules.defaultRepeatDaysForFrequency(
          frequency: picked,
          anchorDate: _hasDeadline ? _deadlineDate : DateTime.now(),
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
    final String current = _presetVoiceValid ? _voiceSelection : VoiceService.defaultVoiceId;
    final String? picked = await showAppOptionPicker<String>(
      context: context,
      title: AppLocalizations.of(context).reminderVoiceSound,
      options: options,
      current: current,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _commitTextVoiceMode();
      _voiceSelection = picked;
    });
    _restoreScrollOffset(scrollOffset);
  }

  String _presetVoiceLabel(String voiceId) {
    for (final VoiceOption voice in VoiceService.presetVoices) {
      if (voice.id == voiceId) {
        return voice.name;
      }
    }
    return AppLocalizationsBinding.instance.voiceDefaultPreset;
  }

  void _selectVoiceRemindMode(_VoiceRemindMode mode) {
    _setStatePreservingScroll(() {
      _voiceRemindMode = mode;
      if (_voiceRemindMode == _VoiceRemindMode.textAndPreset && !_presetVoiceValid) {
        _voiceSelection = VoiceService.defaultVoiceId;
      }
    });
  }

  Widget _buildVoiceModeSelector() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Center(
        child: AppUnderlineTabControl<_VoiceRemindMode>(
          options: <AppSegmentOption<_VoiceRemindMode>>[
            AppSegmentOption(
              value: _VoiceRemindMode.textAndPreset,
              label: l10n.reminderVoiceModeText,
            ),
            AppSegmentOption(
              value: _VoiceRemindMode.record,
              label: l10n.reminderVoiceModeRecord,
            ),
          ],
          selected: _voiceRemindMode,
          onChanged: _selectVoiceRemindMode,
        ),
      ),
    );
  }

  bool get _usesCustomRemindPicker =>
      !_hasDeadline || _remindOffset == ReminderTimeRules.offsetCustom;

  String get _customRemindFrequency =>
      _usesCustomRemindPicker ? _remindFrequency : 'once';

  Widget _buildCustomRemindPicker() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime base = _customRemindAt ?? _defaultCustomRemindAt();
    if (_customRemindFrequency == 'daily') {
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
    if (ReminderTimeRules.usesRepeatDaySelection(_customRemindFrequency)) {
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

  Widget _buildDeadlineTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(
          height: 1,
          thickness: 0.5,
          indent: 56,
          color: AppTheme.separatorColor,
        ),
        buildInlineCupertinoWheel(
          context: context,
          picker: CupertinoTheme(
            data: inlineCupertinoTheme(context),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: DateTime(
                2020,
                1,
                1,
                _deadlineTime.hour,
                _deadlineTime.minute,
              ),
              onDateTimeChanged: (DateTime value) {
                _setStatePreservingScroll(
                  () => _deadlineTime = TimeOfDay(
                    hour: value.hour,
                    minute: value.minute,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      _formKey.currentState?.validate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).todoValidationContent)),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false) || !_canSave) {
      return;
    }

    final String title = _titleController.text.trim();
    final String notes = _notesController.text.trim();
    final DateTime? finalRemindAt = _computedRemindAt;
    final String? remindText = _voiceRemindEnabled &&
            _effectiveVoiceRemindMode == _VoiceRemindMode.textAndPreset
        ? _remindTextController.text.trim()
        : null;

    String soundId = 'default';
    String? voiceId;
    String? voicePath;
    String? remindVoiceId;
    bool isCustomVoice = false;

    if (_voiceRemindEnabled) {
      if (_effectiveVoiceRemindMode == _VoiceRemindMode.record) {
        soundId = 'my_recorded_voice';
        voiceId = 'my_recorded_voice';
        voicePath = _recordingPath;
        remindVoiceId = 'my_recorded_voice';
        isCustomVoice = true;
      } else {
        soundId = _voiceSelection;
        voiceId = _voiceSelection;
        remindVoiceId = _voiceSelection;
      }
    }

    if (_isEditing) {
      await ref.read(reminderListProvider.notifier).updateFlexibleTodo(
            reminderId: widget.editingReminder!.id,
            title: title,
            deadlineAt: _hasDeadline ? _deadlineAt : null,
            syncToCalendar: _hasDeadline && _syncToCalendar,
            remindEnabled: _remindEnabled,
            remindAt: finalRemindAt,
            remindFrequency: _remindEnabled ? _remindFrequency : 'once',
            remindRepeatDays: _remindEnabled ? _remindRepeatDays : const <int>[],
            remindText: remindText?.isEmpty == true ? null : remindText,
            remindVoiceId: remindVoiceId,
            voiceRemindEnabled: _voiceRemindEnabled,
            soundId: soundId,
            voiceId: voiceId,
            voicePath: voicePath,
            isCustomVoice: isCustomVoice,
            notes: notes.isEmpty ? null : notes,
            todoGroupId: _selectedTodoGroupId,
            clearTodoGroupId: _selectedTodoGroupId == null,
          );
    } else {
      await ref.read(reminderListProvider.notifier).addFlexibleTodo(
            title: title,
            deadlineAt: _hasDeadline ? _deadlineAt : null,
            syncToCalendar: _hasDeadline && _syncToCalendar,
            remindEnabled: _remindEnabled,
            remindAt: finalRemindAt,
            remindFrequency: _remindEnabled ? _remindFrequency : 'once',
            remindRepeatDays: _remindEnabled ? _remindRepeatDays : const <int>[],
            remindText: remindText?.isEmpty == true ? null : remindText,
            remindVoiceId: remindVoiceId,
            voiceRemindEnabled: _voiceRemindEnabled,
            soundId: soundId,
            voiceId: voiceId,
            voicePath: voicePath,
            isCustomVoice: isCustomVoice,
            notes: notes.isEmpty ? null : notes,
            todoGroupId: _selectedTodoGroupId,
          );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<TodoGroup> todoGroups = ref.watch(todoGroupListProvider);
    final DateTime? remindPreview = _computedRemindAt;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? voiceRecordFootnote =
        _effectiveVoiceRemindMode == _VoiceRemindMode.record
        ? VoiceRecordPanelStatus.footnoteFor(
            l10n: l10n,
            status: _voiceRecordStatus,
            isRecording: _isRecording,
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                    _isEditing ? l10n.todoSheetEdit : l10n.todoSheetCreate,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _canSave ? _save : null,
                  child: Text(
                    _isEditing ? l10n.commonSave : l10n.todoAdd,
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
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                  AppDetailSection(
                    children: <Widget>[
                      AppDetailTextField(
                        icon: Icons.checklist_outlined,
                        iconColor: scheme.primary,
                        label: l10n.reminderFieldContent,
                        controller: _titleController,
                        hintText: l10n.todoHintContent,
                        textInputAction: TextInputAction.next,
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return l10n.todoValidationContent;
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
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
                  if (todoGroups.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    AppSectionHeader(
                      title: l10n.todoFieldGroup,
                      style: AppSectionHeaderStyle.caption,
                    ),
                    AppDetailSection(
                      children: <Widget>[
                        AppDetailTile(
                          icon: Icons.folder_outlined,
                          iconColor: AppTheme.secondaryLabelColor,
                          title: l10n.todoFieldGroup,
                          value: _todoGroupDisplayLabel(l10n, todoGroups),
                          onTap: () => _pickTodoGroup(todoGroups),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppSectionHeader(
                    title: l10n.todoSectionDeadline,
                    style: AppSectionHeaderStyle.caption,
                  ),
                  AppDetailSection(
                    children: <Widget>[
                      AppDetailSwitchTile(
                        icon: Icons.flag_outlined,
                        iconColor: AppTheme.deadlineColor,
                        title: l10n.todoDeadlineDate,
                        value: _hasDeadline,
                        showDivider: _hasDeadline,
                        onChanged: (bool value) {
                          _setStatePreservingScroll(() {
                            _hasDeadline = value;
                            if (value) {
                              _deadlineDate = DateTimeUtils.startOfDay(DateTime.now());
                              _hasDeadlineSpecificTime = false;
                            } else {
                              _syncToCalendar = false;
                              _hasDeadlineSpecificTime = false;
                              if (_remindEnabled) {
                                _remindOffset = ReminderTimeRules.offsetCustom;
                              }
                              if (_expandedField == _ExpandedField.deadlineDate ||
                                  _expandedField == _ExpandedField.deadlineTime) {
                                _expandedField = _ExpandedField.none;
                              }
                            }
                          });
                        },
                      ),
                      if (_hasDeadline) ...<Widget>[
                        AppDetailTile(
                          icon: Icons.event_outlined,
                          iconColor: AppTheme.deadlineColor,
                          title: l10n.todoDeadlineDate,
                          value: inlineDatePickerSummary(_deadlineDate),
                          subtitle: _hasDeadlineSpecificTime
                              ? null
                              : l10n.todoDeadlineEndOfDay,
                          onTap: () => _toggleExpandedField(_ExpandedField.deadlineDate),
                          expanded: _expandedField == _ExpandedField.deadlineDate,
                          showDivider: _expandedField != _ExpandedField.deadlineDate,
                        ),
                        if (_expandedField == _ExpandedField.deadlineDate)
                          AppInlineDatePicker(
                            selectedDate: _deadlineDate,
                            firstDate: _dateFirst,
                            lastDate: _dateLast,
                            onChanged: (DateTime date) {
                              _setStatePreservingScroll(
                                () => _deadlineDate = DateTimeUtils.startOfDay(date),
                              );
                            },
                          ),
                        AppDetailSwitchTile(
                          icon: Icons.access_time,
                          iconColor: AppTheme.iosBlue,
                          title: l10n.todoSpecificTime,
                          subtitle: _hasDeadlineSpecificTime ? null : l10n.todoSpecificTimeOffSubtitle,
                          value: _hasDeadlineSpecificTime,
                          showDivider: _hasDeadlineSpecificTime,
                          onChanged: (bool value) {
                            _setStatePreservingScroll(() {
                              _hasDeadlineSpecificTime = value;
                              if (value) {
                                _deadlineTime = TimeOfDay.fromDateTime(DateTime.now());
                                _expandedField = _ExpandedField.deadlineTime;
                              } else if (_expandedField == _ExpandedField.deadlineTime) {
                                _expandedField = _ExpandedField.none;
                              }
                            });
                          },
                        ),
                        if (_hasDeadlineSpecificTime) ...<Widget>[
                          AppDetailTile(
                            icon: Icons.schedule_outlined,
                            iconColor: AppTheme.iosBlue,
                            title: l10n.todoFieldTime,
                            value: _deadlineTime.format(context),
                            onTap: () => _toggleExpandedField(_ExpandedField.deadlineTime),
                            expanded: _expandedField == _ExpandedField.deadlineTime,
                            showDivider: _expandedField != _ExpandedField.deadlineTime,
                          ),
                          if (_expandedField == _ExpandedField.deadlineTime)
                            _buildDeadlineTimePicker(),
                        ],
                        AppDetailSwitchTile(
                          icon: Icons.calendar_today_outlined,
                          iconColor: scheme.primary,
                          title: l10n.todoSyncToCalendar,
                          subtitle: l10n.todoSyncToCalendarSubtitle,
                          value: _syncToCalendar,
                          showDivider: false,
                          onChanged: (bool value) {
                            _setStatePreservingScroll(() => _syncToCalendar = value);
                          },
                        ),
                      ],
                    ],
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
                        subtitle: l10n.todoNeedRemindSubtitle,
                        value: _remindEnabled,
                        showDivider: _remindEnabled,
                        onChanged: (bool value) {
                          _setStatePreservingScroll(() {
                            _remindEnabled = value;
                            if (!value) {
                              _voiceRemindEnabled = false;
                            } else {
                              _ensureRemindDefaultsOnEnable();
                            }
                          });
                        },
                      ),
                      if (_remindEnabled) ...<Widget>[
                        if (_hasDeadline)
                          AppDetailTile(
                            icon: Icons.schedule_outlined,
                            iconColor: AppTheme.iosBlue,
                            title: l10n.reminderRemindOffset,
                            value: ReminderTimeRules.offsetLabel(_remindOffset),
                            onTap: _pickRemindOffset,
                          ),
                        if (_usesCustomRemindPicker) ...<Widget>[
                          AppDetailTile(
                            icon: Icons.notifications_active_outlined,
                            iconColor: AppTheme.destructiveColor,
                            title: _hasDeadline ? l10n.reminderCustomTime : l10n.todoRemindTime,
                            value: ReminderTimeRules.customRemindTileValue(
                              remindAt: _customRemindAt,
                              frequency: _customRemindFrequency,
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
                          value: ReminderTimeRules.frequencyLabel(_remindFrequency),
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
                              onChanged: (_) {
                                _setStatePreservingScroll(_commitTextVoiceMode);
                              },
                            ),
                            AppDetailActionTile(
                              icon: Icons.content_copy_outlined,
                              label: l10n.todoSameAsContent,
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
                            VoiceTextPreviewPanel(
                              text: _remindTextController.text,
                              voiceId: _voiceSelection,
                            ),
                          ] else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                              child: VoiceRecordPanel(
                                recordingPath: _recordingPath,
                                onRecordingPathChanged: _onRecordingPathChanged,
                                onRecordingStateChanged: (bool recording) {
                                  _setStatePreservingScroll(() => _isRecording = recording);
                                },
                                onStatusChanged: (VoiceRecordPanelStatus status) {
                                  _setStatePreservingScroll(() => _voiceRecordStatus = status);
                                },
                              ),
                            ),
                        ],
                      ],
                    ),
                    if (_voiceRemindEnabled &&
                        _effectiveVoiceRemindMode == _VoiceRemindMode.textAndPreset &&
                        (_remindTextController.text.trim().isEmpty ||
                            !_presetVoiceValid))
                      AppFootnote(
                        text: l10n.reminderValidationVoice,
                        color: scheme.error,
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      ),
                    if (_voiceRemindEnabled &&
                        _effectiveVoiceRemindMode == _VoiceRemindMode.record &&
                        voiceRecordFootnote != null)
                      AppFootnote(
                        text: voiceRecordFootnote,
                        color: _isRecording
                            ? AppTheme.primaryColor
                            : (_voiceRecordStatus.hasSelection ? null : scheme.error),
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canSave ? _save : null,
                      child: Text(_isEditing ? l10n.reminderSaveChanges : l10n.todoAdd),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
