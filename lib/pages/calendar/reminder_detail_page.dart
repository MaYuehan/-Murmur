import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
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
    final AppLocalizations l10n = AppLocalizationsBinding.instance;
    if (reminder.isCustomVoice) {
      return l10n.voiceMyRecording;
    }
    final String voiceId = _resolveVoiceId(reminder);
    for (final VoiceOption voice in VoiceService.presetVoices) {
      if (voice.id == voiceId) {
        return voice.name;
      }
    }
    return l10n.voiceDefaultPreset;
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.calendarDeleteTitle),
          content: Text(l10n.calendarDeleteMessage(reminder.title)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.commonDelete),
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
      return AppLocalizationsBinding.instance.reminderUnscheduled;
    }
    return DateTimeUtils.formatDate(reminder.scheduledTime!);
  }

  String? _scheduleSecondary(Reminder reminder) {
    if (reminder.scheduledTime == null) {
      return null;
    }
    if (reminder.isAllDay) {
      return AppLocalizationsBinding.instance.reminderAllDay;
    }
    if (reminder.endTime != null) {
      return '${DateTimeUtils.formatTime(reminder.scheduledTime!)} – '
          '${DateTimeUtils.formatTime(reminder.endTime!)}';
    }
    return DateTimeUtils.formatTime(reminder.scheduledTime!);
  }

  String _remindPrimary(Reminder reminder) {
    if (!reminder.remindEnabled) {
      return AppLocalizationsBinding.instance.reminderRemindNone;
    }
    final DateTime? when = reminder.remindAt ?? reminder.scheduledTime;
    if (when == null) {
      return AppLocalizationsBinding.instance.reminderRemindUnset;
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
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.groupedBackgroundColor,
      appBar: AppBar(
        title: const Text(''),
        actions: <Widget>[
          TextButton(
            onPressed: () => _edit(reminder),
            child: Text(
              l10n.commonEdit,
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
                    ? l10n.reminderDetailTodoDeadline
                    : (reminder.linkedTodoId != null ? l10n.reminderDetailTodo : l10n.reminderFieldDate),
                value: _schedulePrimary(reminder),
                subtitle: reminder.isTodoDeadline || reminder.linkedTodoId != null
                    ? (reminder.isCompleted ? l10n.reminderTodoCompletedInList : l10n.reminderFromTodoSync)
                    : _scheduleSecondary(reminder),
              ),
              if (reminder.notes?.trim().isNotEmpty == true)
                AppDetailTile(
                  icon: Icons.notes_outlined,
                  iconColor: const Color(0xFF8E8E93),
                  title: l10n.reminderFieldNotes,
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
                title: l10n.reminderRemindSection,
                value: _remindPrimary(reminder),
                subtitle: _remindSecondary(reminder),
              ),
              AppDetailTile(
                icon: Icons.graphic_eq_rounded,
                iconColor: scheme.primary,
                title: l10n.reminderVoiceSection,
                value: reminder.voiceRemindEnabled ? _voiceName(reminder) : l10n.reminderVoiceOff,
                subtitle: reminder.voiceRemindEnabled ? l10n.reminderVoicePlayAtTime : l10n.reminderTextOnlyNotify,
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
                  title: l10n.reminderRemindContent,
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
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Center(
                      child: Text(
                        l10n.reminderDeleteEvent,
                        style: const TextStyle(
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
    final AppLocalizations l10n = AppLocalizations.of(context);
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
                  isPlaying ? l10n.reminderPlaying : l10n.reminderVoicePreview,
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
