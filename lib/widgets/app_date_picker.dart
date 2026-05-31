import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/widgets/inline_date_picker.dart';
import 'package:murmur/widgets/inline_time_range_picker.dart';

class AppScheduleSelection {
  const AppScheduleSelection({
    required this.eventDate,
    required this.isAllDay,
    this.startTime,
    this.endTime,
  });

  final DateTime eventDate;
  final bool isAllDay;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
}

Future<AppScheduleSelection?> showAppSchedulePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = '添加到日程',
}) {
  DateTime selectedDay = DateTimeUtils.startOfDay(initialDate);
  final DateTime minDay = DateTimeUtils.startOfDay(firstDate);
  final DateTime maxDay = DateTimeUtils.startOfDay(lastDate);
  bool hasSpecificTime = false;
  final DateTime now = DateTime.now();
  TimeOfDay startTime = TimeOfDay.fromDateTime(now);
  TimeOfDay endTime = TimeOfDay(
    hour: (now.hour + 1) % 24,
    minute: now.minute,
  );

  return showModalBottomSheet<AppScheduleSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.groupedBackgroundColor,
    builder: (BuildContext sheetContext) {
      final double sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;

      return SizedBox(
        height: sheetHeight,
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final ColorScheme scheme = Theme.of(context).colorScheme;
            final bool isTimeRangeValid = !hasSpecificTime ||
                timeRangeMinutes(endTime) > timeRangeMinutes(startTime);
            String timeRangeSummary() {
              return '${startTime.format(context)} – ${endTime.format(context)}';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                  child: Row(
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('取消'),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: isTimeRangeValid
                            ? () => Navigator.of(sheetContext).pop(
                                  AppScheduleSelection(
                                    eventDate: selectedDay,
                                    isAllDay: !hasSpecificTime,
                                    startTime: hasSpecificTime ? startTime : null,
                                    endTime: hasSpecificTime ? endTime : null,
                                  ),
                                )
                            : null,
                        child: Text(
                          '完成',
                          style: TextStyle(
                            color: isTimeRangeValid
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AppDetailSection(
                          children: <Widget>[
                            AppDetailTile(
                              icon: Icons.calendar_today_outlined,
                              iconColor: scheme.primary,
                              title: '日期',
                              value: inlineDatePickerSummary(selectedDay),
                              showDivider: false,
                            ),
                            AppInlineDatePicker(
                              selectedDate: selectedDay,
                              firstDate: minDay,
                              lastDate: maxDay,
                              showModeToggle: true,
                              onChanged: (DateTime day) {
                                setModalState(() => selectedDay = day);
                              },
                            ),
                            AppDetailSwitchTile(
                              icon: Icons.access_time,
                              iconColor: AppTheme.iosBlue,
                              title: '具体时间',
                              subtitle: hasSpecificTime ? null : '未开启时为全天日程',
                              value: hasSpecificTime,
                              showDivider: hasSpecificTime,
                              onChanged: (bool value) {
                                setModalState(() {
                                  hasSpecificTime = value;
                                  if (value) {
                                    final DateTime current = DateTime.now();
                                    startTime = TimeOfDay.fromDateTime(current);
                                    endTime = TimeOfDay(
                                      hour: (current.hour + 1) % 24,
                                      minute: current.minute,
                                    );
                                  }
                                });
                              },
                            ),
                            if (hasSpecificTime) ...<Widget>[
                              AppDetailTile(
                                icon: Icons.access_time,
                                iconColor: AppTheme.iosBlue,
                                title: '时间',
                                value: timeRangeSummary(),
                                subtitle: isTimeRangeValid
                                    ? timeRangeDurationLabel(startTime, endTime)
                                    : '结束时间必须晚于开始时间',
                                showDivider: false,
                              ),
                              AppInlineTimeRangePicker(
                                start: startTime,
                                end: endTime,
                                onChanged: (TimeOfDay start, TimeOfDay end) {
                                  setModalState(() {
                                    startTime = start;
                                    endTime = end;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                        if (hasSpecificTime && !isTimeRangeValid)
                          AppFootnote(
                            text: '结束时间必须晚于开始时间',
                            color: scheme.error,
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = '选择日期',
}) {
  DateTime selectedDay = DateTimeUtils.startOfDay(initialDate);
  final DateTime minDay = DateTimeUtils.startOfDay(firstDate);
  final DateTime maxDay = DateTimeUtils.startOfDay(lastDate);

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.groupedBackgroundColor,
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final ColorScheme scheme = Theme.of(context).colorScheme;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(selectedDay),
                        child: Text(
                          '完成',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppDetailSection(
                  children: <Widget>[
                    AppDetailTile(
                      icon: Icons.calendar_today_outlined,
                      iconColor: scheme.primary,
                      title: '日期',
                      value: inlineDatePickerSummary(selectedDay),
                      showDivider: false,
                    ),
                    AppInlineDatePicker(
                      selectedDate: selectedDay,
                      firstDate: minDay,
                      lastDate: maxDay,
                      showModeToggle: true,
                      onChanged: (DateTime day) {
                        setModalState(() => selectedDay = day);
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
