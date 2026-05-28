import 'package:flutter/material.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/models/reminder.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    this.isHighlighted = false,
  });

  final Reminder reminder;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final DateTime? scheduledTime = reminder.scheduledTime;
    final String timeLabel;
    if (reminder.isAllDay) {
      timeLabel = '全天';
    } else if (scheduledTime == null) {
      timeLabel = '--:--';
    } else if (reminder.endTime != null) {
      timeLabel =
          '${DateTimeUtils.formatTime(scheduledTime)}-${DateTimeUtils.formatTime(reminder.endTime!)}';
    } else {
      timeLabel = DateTimeUtils.formatTime(scheduledTime);
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isHighlighted
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.6,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 58,
              child: Text(
                timeLabel,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    reminder.title,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
