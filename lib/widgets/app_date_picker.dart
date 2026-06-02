import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/l10n/app_localizations.dart';
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
  String? title,
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
            final AppLocalizations l10n = AppLocalizations.of(context);
            final ColorScheme scheme = Theme.of(context).colorScheme;
            final bool isTimeRangeValid = !hasSpecificTime ||
                timeRangeMinutes(endTime) > timeRangeMinutes(startTime);
            final String sheetTitle = title ?? l10n.scheduleAddToCalendarTitle;
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
                        child: Text(l10n.commonCancel),
                      ),
                      Expanded(
                        child: Text(
                          sheetTitle,
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
                          l10n.commonDone,
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
                              title: l10n.reminderFieldDate,
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
                              title: l10n.scheduleSpecificTime,
                              subtitle: hasSpecificTime ? null : l10n.scheduleAllDayWhenOff,
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
                                title: l10n.reminderFieldTime,
                                value: timeRangeSummary(),
                                subtitle: isTimeRangeValid
                                    ? timeRangeDurationLabel(startTime, endTime)
                                    : l10n.reminderTimeRangeInvalid,
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
                            text: l10n.reminderTimeRangeInvalid,
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

const double _anchoredWheelPanelWidthMin = 280;
const double _anchoredWheelPanelWidthMax = 340;
const double _anchoredWheelHeight = 196;
const double _anchoredWheelToolbarHeight = 44;

Future<DateTime?> showAppCupertinoWheelPicker({
  required BuildContext context,
  required BuildContext anchorContext,
  required String title,
  required DateTime initialDateTime,
  required DateTime minimumDate,
  required DateTime maximumDate,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.date,
}) {
  final RenderBox? anchorBox = anchorContext.findRenderObject() as RenderBox?;
  final RenderBox? overlayBox =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (anchorBox == null || overlayBox == null || !anchorBox.hasSize) {
    return Future<DateTime?>.value();
  }

  DateTime selected = initialDateTime;
  final Size screenSize = overlayBox.size;
  final double panelWidth = (anchorBox.size.width + 48)
      .clamp(_anchoredWheelPanelWidthMin, _anchoredWheelPanelWidthMax)
      .clamp(0, screenSize.width - 24);
  final double panelHeight = _anchoredWheelToolbarHeight + _anchoredWheelHeight;
  final Offset anchorTopLeft =
      anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final double anchorBottom = anchorTopLeft.dy + anchorBox.size.height;

  double left =
      anchorTopLeft.dx + (anchorBox.size.width - panelWidth) / 2;
  left = left.clamp(12.0, screenSize.width - panelWidth - 12.0);

  double top = anchorBottom + 6;
  if (top + panelHeight > screenSize.height - 12) {
    top = anchorTopLeft.dy - panelHeight - 6;
    if (top < 12) {
      top = 12;
    }
  }

  return showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (BuildContext dialogContext, Animation<double> _, Animation<double> __) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final AppLocalizations l10n = AppLocalizations.of(context);
          final ColorScheme scheme = Theme.of(context).colorScheme;

          return Stack(
            children: <Widget>[
              Positioned(
                left: left,
                top: top,
                width: panelWidth,
                child: Material(
                  color: AppTheme.cardColor,
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        height: _anchoredWheelToolbarHeight,
                        child: Row(
                          children: <Widget>[
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: Text(l10n.commonCancel),
                            ),
                            Expanded(
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(selected),
                              child: Text(
                                l10n.commonDone,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppTheme.separatorColor,
                      ),
                      SizedBox(
                        height: _anchoredWheelHeight,
                        child: CupertinoTheme(
                          data: inlineCupertinoTheme(context),
                          child: CupertinoDatePicker(
                            mode: mode,
                            initialDateTime: selected,
                            minimumDate: minimumDate,
                            maximumDate: maximumDate,
                            onDateTimeChanged: (DateTime value) {
                              setModalState(() => selected = value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
    transitionBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
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
  String? title,
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
          final AppLocalizations l10n = AppLocalizations.of(context);
          final ColorScheme scheme = Theme.of(context).colorScheme;
          final String sheetTitle = title ?? l10n.datePickerSelectDate;

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
                        child: Text(l10n.commonCancel),
                      ),
                      Expanded(
                        child: Text(
                          sheetTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(selectedDay),
                        child: Text(
                          l10n.commonDone,
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
                      title: l10n.reminderFieldDate,
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
