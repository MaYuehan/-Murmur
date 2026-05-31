import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/widgets/inline_time_range_picker.dart';

class EventTimeRangeResult {
  const EventTimeRangeResult({
    required this.start,
    required this.end,
  });

  final TimeOfDay start;
  final TimeOfDay end;
}

Future<EventTimeRangeResult?> showEventTimeRangeSheet({
  required BuildContext context,
  required TimeOfDay initialStart,
  required TimeOfDay initialEnd,
}) {
  return showModalBottomSheet<EventTimeRangeResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.groupedBackgroundColor,
    builder: (BuildContext sheetContext) {
      TimeOfDay start = initialStart;
      TimeOfDay end = initialEnd;

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final ColorScheme scheme = Theme.of(context).colorScheme;
          final bool isValid = timeRangeMinutes(end) > timeRangeMinutes(start);

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      Expanded(
                        child: Text(
                          '选择时间',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: isValid
                            ? () => Navigator.of(sheetContext).pop(
                                  EventTimeRangeResult(start: start, end: end),
                                )
                            : null,
                        child: Text(
                          '完成',
                          style: TextStyle(
                            color: isValid ? scheme.primary : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppDetailSection(
                  children: <Widget>[
                    AppInlineTimeRangePicker(
                      start: start,
                      end: end,
                      onChanged: (TimeOfDay newStart, TimeOfDay newEnd) {
                        setModalState(() {
                          start = newStart;
                          end = newEnd;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}
