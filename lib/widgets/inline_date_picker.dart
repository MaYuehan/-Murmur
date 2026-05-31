import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/widgets/app_calendar_styles.dart';
import 'package:murmur/widgets/app_ui.dart';

String inlineDatePickerSummary(DateTime date) {
  return '${DateTimeUtils.formatDate(date)} ${DateTimeUtils.weekdayLabel(date.weekday)}';
}

const double _inlineWheelHeight = 148;
const double _inlineWheelFontSize = 20;
const double _inlineDateWheelFontSize = 16;

class AppInlineDatePicker extends StatefulWidget {
  const AppInlineDatePicker({
    super.key,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.showModeToggle = true,
  });

  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;
  final bool showModeToggle;

  @override
  State<AppInlineDatePicker> createState() => _AppInlineDatePickerState();
}

class _AppInlineDatePickerState extends State<AppInlineDatePicker> {
  late DateTime _focusedDay;
  bool _wheelMode = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTimeUtils.startOfDay(widget.selectedDate);
  }

  @override
  void didUpdateWidget(AppInlineDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateTimeUtils.startOfDay(oldWidget.selectedDate)
        .isAtSameMomentAs(DateTimeUtils.startOfDay(widget.selectedDate))) {
      _focusedDay = DateTimeUtils.startOfDay(widget.selectedDate);
    }
  }

  DateTime get _minDay => DateTimeUtils.startOfDay(widget.firstDate);
  DateTime get _maxDay => DateTimeUtils.startOfDay(widget.lastDate);

  void _selectDay(DateTime day) {
    final DateTime normalized = DateTimeUtils.startOfDay(day);
    widget.onChanged(normalized);
    setState(() => _focusedDay = normalized);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime selectedDay = DateTimeUtils.startOfDay(widget.selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(
          height: 1,
          thickness: 0.5,
          indent: 56,
          color: AppTheme.separatorColor,
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.showModeToggle)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  child: Align(
                    alignment: Alignment.center,
                    child: AppSegmentedControl<bool>(
                      compact: true,
                      options: const <AppSegmentOption<bool>>[
                        AppSegmentOption(value: false, label: '日历'),
                        AppSegmentOption(value: true, label: '滚轮'),
                      ],
                      selected: _wheelMode,
                      onChanged: (bool value) => setState(() => _wheelMode = value),
                    ),
                  ),
                ),
              if (_wheelMode)
                SizedBox(
                  height: _inlineWheelHeight,
                  width: double.infinity,
                  child: Center(
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Brightness.light,
                        primaryColor: scheme.primary,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontSize: _inlineDateWheelFontSize,
                                height: 1.2,
                              ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: selectedDay,
                        minimumDate: _minDay,
                        maximumDate: _maxDay,
                        onDateTimeChanged: _selectDay,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Material(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                      child: AppCalendarStyles.monthCalendar(
                        context: context,
                        focusedDay: _focusedDay,
                        selectedDay: selectedDay,
                        firstDay: _minDay,
                        lastDay: _maxDay,
                        onDaySelected: (DateTime day, DateTime focused) {
                          _selectDay(day);
                          setState(() => _focusedDay = focused);
                        },
                        onPageChanged: (DateTime focused) {
                          setState(() => _focusedDay = focused);
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared compact Cupertino wheel wrapper for inline pickers.
Widget buildInlineCupertinoWheel({
  required BuildContext context,
  required Widget picker,
  double height = _inlineWheelHeight,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    decoration: BoxDecoration(
      color: AppTheme.backgroundColor,
      borderRadius: BorderRadius.circular(10),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(height: height, child: picker),
  );
}

CupertinoThemeData inlineCupertinoTheme(BuildContext context) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: scheme.primary,
    textTheme: CupertinoTextThemeData(
      dateTimePickerTextStyle: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontSize: _inlineWheelFontSize),
    ),
  );
}
