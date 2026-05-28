import 'package:flutter/material.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/services/voice_service.dart';

class ReminderDetailPage extends StatefulWidget {
  const ReminderDetailPage({
    super.key,
    required this.reminder,
  });

  final Reminder reminder;

  @override
  State<ReminderDetailPage> createState() => _ReminderDetailPageState();
}

class _ReminderDetailPageState extends State<ReminderDetailPage> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _play();
  }

  Future<void> _play() async {
    setState(() {
      _isPlaying = true;
    });
    await VoiceService.play(
      voicePath: widget.reminder.voicePath,
      voiceId: widget.reminder.voiceId ??
          (widget.reminder.soundId.isEmpty
              ? VoiceService.defaultVoiceId
              : widget.reminder.soundId),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _stop() async {
    await VoiceService.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Reminder reminder = widget.reminder;
    return Scaffold(
      appBar: AppBar(title: const Text('Reminder Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(reminder.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('类型: ${reminder.timeType}'),
            if (reminder.scheduledTime != null)
              Text('时间: ${DateTimeUtils.formatDateTime(reminder.scheduledTime!)}'),
            const SizedBox(height: 16),
            Text(_isPlaying ? 'Playing voice...' : 'Voice ready'),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _play,
                  icon: const Icon(Icons.replay),
                  label: const Text('Replay'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
