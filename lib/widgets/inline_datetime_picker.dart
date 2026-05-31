import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/widgets/inline_date_picker.dart';

class AppInlineDateTimePicker extends StatelessWidget {
  const AppInlineDateTimePicker({
    super.key,
    required this.selectedDateTime,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.timeSectionLabel,
  });

  final DateTime selectedDateTime;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;
  final String? timeSectionLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final DateTime date = DateTimeUtils.startOfDay(selectedDateTime);
    final TimeOfDay time = TimeOfDay.fromDateTime(selectedDateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppInlineDatePicker(
          selectedDate: date,
          firstDate: firstDate,
          lastDate: lastDate,
          onChanged: (DateTime pickedDate) {
            onChanged(
              DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                time.hour,
                time.minute,
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 14, 6),
          child: Text(
            timeSectionLabel ?? l10n.reminderSectionLabelRemindTime,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        buildInlineCupertinoWheel(
          context: context,
          picker: CupertinoTheme(
            data: inlineCupertinoTheme(context),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: DateTime(2020, 1, 1, time.hour, time.minute),
              onDateTimeChanged: (DateTime value) {
                onChanged(
                  DateTime(
                    date.year,
                    date.month,
                    date.day,
                    value.hour,
                    value.minute,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
