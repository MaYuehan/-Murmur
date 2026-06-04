import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    this.isHighlighted = false,
    this.onTap,
  });

  final Reminder reminder;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime? scheduledTime = reminder.scheduledTime;
    final Color accentColor = reminder.isTodoDeadline
        ? AppTheme.deadlineColor
        : scheme.primary.withValues(alpha: 0.85);
    final String timeLabel;
    if (reminder.isAllDay) {
      timeLabel = l10n.reminderAllDay;
    } else if (scheduledTime == null) {
      timeLabel = '--:--';
    } else if (reminder.endTime != null) {
      timeLabel =
          '${DateTimeUtils.formatTime(scheduledTime)} ${DateTimeUtils.formatTime(reminder.endTime!)}';
    } else {
      timeLabel = DateTimeUtils.formatTime(scheduledTime);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
          decoration: BoxDecoration(
            border: isHighlighted
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 54,
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  timeLabel,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: reminder.isCompleted
                        ? AppTheme.secondaryLabelColor
                        : (reminder.isAllDay && !reminder.isTodoDeadline
                            ? scheme.primary
                            : (reminder.isTodoDeadline
                                ? AppTheme.deadlineColor
                                : AppTheme.textPrimaryColor)),
                    decoration: reminder.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              Container(
                width: 3,
                height: 42,
                margin: const EdgeInsets.only(right: 12, top: 2),
                decoration: BoxDecoration(
                  color: reminder.isCompleted
                      ? AppTheme.secondaryLabelColor.withValues(alpha: 0.5)
                      : accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      reminder.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: reminder.isCompleted
                            ? AppTheme.secondaryLabelColor
                            : AppTheme.textPrimaryColor,
                        decoration: reminder.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (reminder.isTodoDeadline) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            reminder.isCompleted
                                ? Icons.check_circle_outline
                                : Icons.flag_outlined,
                            size: 13,
                            color: reminder.isCompleted
                                ? AppTheme.secondaryLabelColor
                                : AppTheme.deadlineColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reminder.isCompleted
                                ? l10n.reminderTodoDone
                                : l10n.reminderTodoDeadline,
                            style: textTheme.labelSmall?.copyWith(
                              color: reminder.isCompleted
                                  ? AppTheme.secondaryLabelColor
                                  : AppTheme.deadlineColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ] else if (reminder.linkedTodoId != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        reminder.isCompleted ? l10n.reminderTodoDone : l10n.reminderTodo,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppTheme.secondaryLabelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (reminder.notes?.trim().isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        reminder.notes!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: reminder.isCompleted
                              ? AppTheme.secondaryLabelColor
                              : null,
                        ),
                      ),
                    ],
                    if (reminder.remindEnabled) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.notifications_outlined,
                            size: 13,
                            color: scheme.primary,
                          ),
                          if (reminder.voiceRemindEnabled) ...<Widget>[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.graphic_eq_rounded,
                              size: 13,
                              color: scheme.primary,
                            ),
                          ],
                          const SizedBox(width: 4),
                          Text(
                            reminder.remindAt != null
                                ? ReminderTimeRules.remindPreviewLabel(
                                    remindAt: reminder.remindAt,
                                    frequency: reminder.remindFrequency,
                                    repeatDays: reminder.remindRepeatDays,
                                  )
                                : l10n.todoReminderSet,
                            style: textTheme.labelSmall?.copyWith(
                              color: AppTheme.secondaryLabelColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (reminder.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppTheme.secondaryLabelColor,
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
