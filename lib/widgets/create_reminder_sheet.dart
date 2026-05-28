import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/services/ai_parser_service.dart';
import 'package:murmur/services/emotion_service.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/voice_selector.dart';

class CreateReminderSheet extends ConsumerStatefulWidget {
  const CreateReminderSheet({
    super.key,
    this.initialDate,
  });

  final DateTime? initialDate;

  @override
  ConsumerState<CreateReminderSheet> createState() => _CreateReminderSheetState();
}

class _CreateReminderSheetState extends ConsumerState<CreateReminderSheet> {
  final TextEditingController _titleController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  ParsedReminder _parsedReminder = const ParsedReminder(
    title: '',
    time: null,
    confidence: 0,
    timeType: 'none',
  );
  SelectedVoice _selectedVoice = const SelectedVoice(
    soundId: 'default',
    voiceId: 'default',
    label: 'Default Voice',
  );

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTimeRange() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 1, 1, 1);
    final DateTime lastDate = DateTime(now.year + 3, 12, 31);
    final DateTime initialDate = _startDateTime ?? widget.initialDate ?? now;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final TimeOfDay startInitial = _startDateTime != null
        ? TimeOfDay.fromDateTime(_startDateTime!)
        : TimeOfDay.fromDateTime(now);
    final TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: startInitial,
    );

    if (startTime == null) {
      return;
    }

    final TimeOfDay endInitial = TimeOfDay(
      hour: (startTime.hour + 1) % 24,
      minute: startTime.minute,
    );
    final TimeOfDay? endTime = await showTimePicker(
      context: context,
      initialTime: endInitial,
    );
    if (endTime == null) {
      return;
    }

    final DateTime startDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      startTime.hour,
      startTime.minute,
    );
    DateTime endDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      endTime.hour,
      endTime.minute,
    );
    if (!endDateTime.isAfter(startDateTime)) {
      endDateTime = startDateTime.add(const Duration(hours: 1));
    }

    setState(() {
      _startDateTime = startDateTime;
      _endDateTime = endDateTime;
    });
  }

  void _clearTimeRange() {
    setState(() {
      _startDateTime = null;
      _endDateTime = null;
    });
  }

  Future<void> _saveReminder() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final ParsedReminder parsed =
        AIParserService.parse(_titleController.text, now: DateTime.now());
    final String emotionTag = EmotionService.detectEmotionTag(parsed.title);
    final DateTime baseDay = widget.initialDate ?? DateTime.now();
    final bool useRange = _startDateTime != null && _endDateTime != null;
    final DateTime finalStart = useRange
        ? _startDateTime!
        : DateTime(baseDay.year, baseDay.month, baseDay.day);
    final DateTime? finalEnd = useRange
        ? _endDateTime
        : DateTime(baseDay.year, baseDay.month, baseDay.day, 23, 59);

    String finalSoundId = _selectedVoice.soundId;
    String? finalVoiceId = _selectedVoice.voiceId;
    String? finalVoicePath = _selectedVoice.voicePath;
    bool finalIsCustomVoice = _selectedVoice.isCustomVoice;

    final bool isUsingDefaultVoiceSelection =
        _selectedVoice.soundId == 'default' && !_selectedVoice.isCustomVoice;
    if (isUsingDefaultVoiceSelection) {
      final String suggestedVoiceId = EmotionService.suggestVoiceId(emotionTag);
      finalSoundId = suggestedVoiceId;
      finalVoiceId = suggestedVoiceId;
      finalVoicePath = null;
      finalIsCustomVoice = false;
    }

    await ref.read(reminderListProvider.notifier).addReminder(
          title: parsed.title,
          scheduledTime: finalStart,
          endTime: finalEnd,
          isAllDay: !useRange,
          timeType: 'fixed',
          soundId: finalSoundId,
          voiceId: finalVoiceId,
          voicePath: finalVoicePath,
          isCustomVoice: finalIsCustomVoice,
          emotionTag: emotionTag,
        );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + mediaQuery.viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '创建 Reminder',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.done,
                onChanged: (String value) {
                  setState(() {
                    _parsedReminder = AIParserService.parse(value);
                  });
                },
                decoration: const InputDecoration(
                  labelText: '内容',
                  hintText: '例如：给妈妈打电话',
                ),
                validator: (String? value) {
                  final String text = (value ?? '').trim();
                  if (text.isEmpty) {
                    return '请填写提醒内容';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _AISuggestionBox(parsedReminder: _parsedReminder),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTimeRange,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        (_startDateTime == null || _endDateTime == null)
                            ? '选择开始和结束时间（可选）'
                            : '${DateTimeUtils.formatDateTime(_startDateTime!)} - ${DateTimeUtils.formatTime(_endDateTime!)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_startDateTime != null || _endDateTime != null)
                    IconButton(
                      onPressed: _clearTimeRange,
                      icon: const Icon(Icons.close),
                      tooltip: '清除时间',
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                (_startDateTime == null || _endDateTime == null)
                    ? '不选择时间将创建为当天全天事项'
                    : '已选择开始与结束时间',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              VoiceSelector(
                onChanged: (SelectedVoice value) {
                  _selectedVoice = value;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveReminder,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AISuggestionBox extends StatelessWidget {
  const _AISuggestionBox({
    required this.parsedReminder,
  });

  final ParsedReminder parsedReminder;

  @override
  Widget build(BuildContext context) {
    final String timeText = parsedReminder.time == null
        ? '未识别到明确时间'
        : DateTimeUtils.formatDateTime(parsedReminder.time!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'AI Suggestion',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text('识别时间类型: ${parsedReminder.timeType}'),
          Text('建议时间: $timeText'),
          Text(
            '置信度: ${(parsedReminder.confidence * 100).toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }
}
