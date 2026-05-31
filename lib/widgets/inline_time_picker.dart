import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/widgets/inline_date_picker.dart';

class AppInlineTimePicker extends StatelessWidget {
  const AppInlineTimePicker({
    super.key,
    required this.time,
    required this.onChanged,
    this.sectionLabel,
  });

  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;
  final String? sectionLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(
          height: 1,
          thickness: 0.5,
          indent: 56,
          color: AppTheme.separatorColor,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 10, 14, 6),
          child: Text(
            sectionLabel ?? l10n.reminderSectionLabelRemindTime,
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
                onChanged(TimeOfDay(hour: value.hour, minute: value.minute));
              },
            ),
          ),
        ),
      ],
    );
  }
}
