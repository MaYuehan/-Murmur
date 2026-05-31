import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/widgets/create_reminder_sheet.dart';

class ReminderDetailPage extends ConsumerStatefulWidget {
  const ReminderDetailPage({
    super.key,
    required this.reminderId,
  });

  final String reminderId;

  @override
  ConsumerState<ReminderDetailPage> createState() => _ReminderDetailPageState();
}

class _ReminderDetailPageState extends ConsumerState<ReminderDetailPage> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final Reminder? reminder = _findReminder();
      if (reminder != null && reminder.voiceRemindEnabled) {
        _play(reminder);
      }
    });
  }

  Reminder? _findReminder() {
    return ref.read(reminderListProvider.notifier).getReminderById(widget.reminderId);
  }

  String _resolveVoiceId(Reminder reminder) {
    return reminder.remindVoiceId ??
        reminder.voiceId ??
        (reminder.soundId.isEmpty ? VoiceService.defaultVoiceId : reminder.soundId);
  }

  String _voiceName(Reminder reminder) {
    if (reminder.isCustomVoice) {
      return '我的录音';
    }
    final String voiceId = _resolveVoiceId(reminder);
    for (final VoiceOption voice in VoiceService.presetVoices) {
      if (voice.id == voiceId) {
        return voice.name;
      }
    }
    return '默认亲声';
  }

  Future<void> _play(Reminder reminder) async {
    if (!reminder.voiceRemindEnabled) {
      return;
    }
    setState(() => _isPlaying = true);
    await VoiceService.play(
      voicePath: reminder.voicePath,
      voiceId: _resolveVoiceId(reminder),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isPlaying = false);
  }

  Future<void> _stop() async {
    await VoiceService.stop();
    if (!mounted) {
      return;
    }
    setState(() => _isPlaying = false);
  }

  Future<void> _edit(Reminder reminder) async {
    await CreateReminderSheet.show(
      context,
      initialDate: reminder.scheduledTime,
      editingReminder: reminder,
    );
  }

  Future<void> _delete(Reminder reminder) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除日程'),
          content: Text('确定删除「${reminder.title}」吗？此操作无法撤销。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(reminderListProvider.notifier).deleteReminder(reminder.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  String _schedulePrimary(Reminder reminder) {
    if (reminder.scheduledTime == null) {
      return '未安排时间';
    }
    return DateTimeUtils.formatDate(reminder.scheduledTime!);
  }

  String? _scheduleSecondary(Reminder reminder) {
    if (reminder.scheduledTime == null) {
      return null;
    }
    if (reminder.isAllDay) {
      return '全天';
    }
    if (reminder.endTime != null) {
      return '${DateTimeUtils.formatTime(reminder.scheduledTime!)} – '
          '${DateTimeUtils.formatTime(reminder.endTime!)}';
    }
    return DateTimeUtils.formatTime(reminder.scheduledTime!);
  }

  String _remindPrimary(Reminder reminder) {
    if (!reminder.remindEnabled) {
      return '无';
    }
    final DateTime? when = reminder.remindAt ?? reminder.scheduledTime;
    if (when == null) {
      return '未设置';
    }
    return DateTimeUtils.formatDateTime(when);
  }

  String? _remindSecondary(Reminder reminder) {
    if (!reminder.remindEnabled) {
      return null;
    }
    return ReminderTimeRules.frequencyLabel(reminder.remindFrequency);
  }

  String _notificationText(Reminder reminder) {
    if (reminder.remindText?.trim().isNotEmpty == true) {
      return reminder.remindText!.trim();
    }
    if (reminder.notes?.trim().isNotEmpty == true) {
      return reminder.notes!.trim();
    }
    return reminder.title;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderListProvider);
    final Reminder? reminder = _findReminder();

    if (reminder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.groupedBackgroundColor,
      appBar: AppBar(
        title: const Text(''),
        actions: <Widget>[
          TextButton(
            onPressed: () => _edit(reminder),
            child: Text(
              '编辑',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
            child: Text(
              reminder.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppTheme.textPrimaryColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          AppDetailSection(
            children: <Widget>[
              AppDetailTile(
                icon: Icons.calendar_today_outlined,
                iconColor: reminder.isTodoDeadline
                    ? AppTheme.deadlineColor
                    : (reminder.linkedTodoId != null
                        ? AppTheme.secondaryLabelColor
                        : scheme.primary),
                title: reminder.isTodoDeadline
                    ? '待办截止'
                    : (reminder.linkedTodoId != null ? '待办' : '日期'),
                value: _schedulePrimary(reminder),
                subtitle: reminder.isTodoDeadline || reminder.linkedTodoId != null
                    ? (reminder.isCompleted ? '已在待办中完成' : '来自待办同步')
                    : _scheduleSecondary(reminder),
              ),
              if (reminder.notes?.trim().isNotEmpty == true)
                AppDetailTile(
                  icon: Icons.notes_outlined,
                  iconColor: const Color(0xFF8E8E93),
                  title: '备注',
                  value: reminder.notes!.trim(),
                  multiline: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppDetailSection(
            children: <Widget>[
              AppDetailTile(
                icon: Icons.notifications_outlined,
                iconColor: const Color(0xFFFF3B30),
                title: '提醒',
                value: _remindPrimary(reminder),
                subtitle: _remindSecondary(reminder),
              ),
              AppDetailTile(
                icon: Icons.graphic_eq_rounded,
                iconColor: scheme.primary,
                title: '亲声',
                value: reminder.voiceRemindEnabled ? _voiceName(reminder) : '未开启',
                subtitle: reminder.voiceRemindEnabled ? '到点播放亲声' : '仅文字通知',
                showDivider: false,
              ),
            ],
          ),
          if (reminder.remindEnabled) ...<Widget>[
            const SizedBox(height: 12),
            AppDetailSection(
              children: <Widget>[
                AppDetailTile(
                  icon: Icons.chat_bubble_outline,
                  iconColor: const Color(0xFF8E8E93),
                  title: '提醒内容',
                  value: _notificationText(reminder),
                  multiline: true,
                  showDivider: false,
                ),
              ],
            ),
          ],
          if (reminder.voiceRemindEnabled) ...<Widget>[
            const SizedBox(height: 12),
            _VoicePlayerCard(
              isPlaying: _isPlaying,
              voiceName: _voiceName(reminder),
              onPlay: () => _play(reminder),
              onStop: _stop,
            ),
          ],
          const SizedBox(height: 20),
          AppDetailSection(
            children: <Widget>[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _delete(reminder),
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Center(
                      child: Text(
                        '删除日程',
                        style: TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoicePlayerCard extends StatelessWidget {
  const _VoicePlayerCard({
    required this.isPlaying,
    required this.voiceName,
    required this.onPlay,
    required this.onStop,
  });

  final bool isPlaying;
  final String voiceName;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.volume_up_rounded : Icons.mic_none_rounded,
              color: scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isPlaying ? '正在播放' : '亲声预览',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  voiceName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: isPlaying ? onStop : onPlay,
            icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
            style: IconButton.styleFrom(
              backgroundColor: scheme.primary.withValues(alpha: 0.16),
              foregroundColor: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
