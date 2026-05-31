import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/l10n/app_localizations.dart';

class AppInlineRepeatDaysPicker extends StatelessWidget {
  const AppInlineRepeatDaysPicker({
    super.key,
    required this.frequency,
    required this.selectedDays,
    required this.onChanged,
  });

  final String frequency;
  final List<int> selectedDays;
  final ValueChanged<List<int>> onChanged;

  bool get _isWeekly => frequency == 'weekly';

  void _toggleDay(int day) {
    final List<int> next = List<int>.from(selectedDays);
    if (next.contains(day)) {
      next.remove(day);
    } else {
      next.add(day);
    }
    next.sort();
    onChanged(next);
  }

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
          padding: const EdgeInsets.fromLTRB(56, 10, 14, 8),
          child: Text(
            _isWeekly ? l10n.remindFrequencyWeekly : l10n.remindFrequencyMonthly,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 14, 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _isWeekly
                ? List<Widget>.generate(7, (int index) {
                    final int weekday = index + 1;
                    return _RepeatDayChip(
                      label: DateTimeUtils.shortWeekdayLabel(weekday),
                      selected: selectedDays.contains(weekday),
                      onTap: () => _toggleDay(weekday),
                    );
                  })
                : List<Widget>.generate(31, (int index) {
                    final int day = index + 1;
                    return _RepeatDayChip(
                      label: '$day',
                      selected: selectedDays.contains(day),
                      onTap: () => _toggleDay(day),
                    );
                  }),
          ),
        ),
      ],
    );
  }
}

class _RepeatDayChip extends StatelessWidget {
  const _RepeatDayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.12) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.primary : const Color(0xFFE5E5EA),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? scheme.primary : AppTheme.textPrimaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
