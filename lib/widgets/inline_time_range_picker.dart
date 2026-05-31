import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/widgets/inline_date_picker.dart';

enum _ActiveTimeField { start, end }

class _DurationOption {
  const _DurationOption({required this.label, required this.duration});

  final String label;
  final Duration duration;
}

List<_DurationOption> _durationOptions(AppLocalizations l10n) {
  return <_DurationOption>[
    _DurationOption(label: l10n.timeRangeDuration30m, duration: const Duration(minutes: 30)),
    _DurationOption(label: l10n.timeRangeDuration1h, duration: const Duration(hours: 1)),
    _DurationOption(label: l10n.timeRangeDuration2h, duration: const Duration(hours: 2)),
  ];
}

const double _inlineTimeWheelHeight = 132;

int timeRangeMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

TimeOfDay minutesToTimeOfDay(int minutes) {
  final int normalized = minutes % (24 * 60);
  return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
}

TimeOfDay addDurationToTime(TimeOfDay start, Duration duration) {
  return minutesToTimeOfDay(timeRangeMinutes(start) + duration.inMinutes);
}

Duration? matchingDurationOption(TimeOfDay start, TimeOfDay end) {
  for (final _DurationOption option
      in _durationOptions(AppLocalizationsBinding.instance)) {
    final TimeOfDay expectedEnd = addDurationToTime(start, option.duration);
    if (timeRangeMinutes(expectedEnd) == timeRangeMinutes(end)) {
      return option.duration;
    }
  }
  return null;
}

String timeRangeDurationLabel(TimeOfDay start, TimeOfDay end) {
  final AppLocalizations l10n = AppLocalizationsBinding.instance;
  final int diff = timeRangeMinutes(end) - timeRangeMinutes(start);
  if (diff <= 0) {
    return l10n.timeRangeInvalidShort;
  }
  if (diff % 60 == 0) {
    return l10n.timeRangeTotalHours(diff ~/ 60);
  }
  if (diff < 60) {
    return l10n.timeRangeTotalMinutes(diff);
  }
  return l10n.timeRangeTotalHoursMinutes(diff ~/ 60, diff % 60);
}

class AppInlineTimeRangePicker extends StatefulWidget {
  const AppInlineTimeRangePicker({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
  });

  final TimeOfDay start;
  final TimeOfDay end;
  final void Function(TimeOfDay start, TimeOfDay end) onChanged;

  @override
  State<AppInlineTimeRangePicker> createState() => _AppInlineTimeRangePickerState();
}

class _AppInlineTimeRangePickerState extends State<AppInlineTimeRangePicker> {
  _ActiveTimeField _activeField = _ActiveTimeField.start;
  Duration? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDuration = matchingDurationOption(widget.start, widget.end);
  }

  @override
  void didUpdateWidget(AppInlineTimeRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      _selectedDuration = matchingDurationOption(widget.start, widget.end);
    }
  }

  void _applyDuration(Duration duration) {
    final TimeOfDay newEnd = addDurationToTime(widget.start, duration);
    setState(() => _selectedDuration = duration);
    widget.onChanged(widget.start, newEnd);
  }

  void _updateActiveTime(TimeOfDay value) {
    if (_activeField == _ActiveTimeField.start) {
      TimeOfDay newEnd = widget.end;
      Duration? newDuration = _selectedDuration;
      if (newDuration != null) {
        newEnd = addDurationToTime(value, newDuration);
      } else if (timeRangeMinutes(newEnd) <= timeRangeMinutes(value)) {
        newDuration = const Duration(hours: 1);
        newEnd = addDurationToTime(value, newDuration);
      }
      setState(() => _selectedDuration = newDuration);
      widget.onChanged(value, newEnd);
      return;
    }

    setState(() => _selectedDuration = matchingDurationOption(widget.start, value));
    widget.onChanged(widget.start, value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isValid = timeRangeMinutes(widget.end) > timeRangeMinutes(widget.start);
    final TimeOfDay activeTime =
        _activeField == _ActiveTimeField.start ? widget.start : widget.end;
    final List<_DurationOption> durationOptions = _durationOptions(l10n);

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
          child: Row(
            children: <Widget>[
              _TimeFieldTab(
                label: l10n.timeRangeStart,
                value: widget.start.format(context),
                selected: _activeField == _ActiveTimeField.start,
                onTap: () => setState(() => _activeField = _ActiveTimeField.start),
              ),
              const SizedBox(width: 6),
              _TimeFieldTab(
                label: l10n.timeRangeEnd,
                value: widget.end.format(context),
                selected: _activeField == _ActiveTimeField.end,
                onTap: () => setState(() => _activeField = _ActiveTimeField.end),
              ),
            ],
          ),
        ),
        buildInlineCupertinoWheel(
          context: context,
          height: _inlineTimeWheelHeight,
          picker: CupertinoTheme(
            data: inlineCupertinoTheme(context),
            child: CupertinoDatePicker(
              key: ValueKey<String>(
                '${_activeField.name}-${activeTime.hour}-${activeTime.minute}',
              ),
              mode: CupertinoDatePickerMode.time,
              use24hFormat: true,
              initialDateTime: DateTime(2020, 1, 1, activeTime.hour, activeTime.minute),
              onDateTimeChanged: (DateTime value) {
                _updateActiveTime(TimeOfDay(hour: value.hour, minute: value.minute));
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 0, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.timeRangeQuickDuration,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: durationOptions.map((_DurationOption option) {
                  return _DurationChip(
                    label: option.label,
                    selected: _selectedDuration == option.duration,
                    onTap: () => _applyDuration(option.duration),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                isValid
                    ? timeRangeDurationLabel(widget.start, widget.end)
                    : l10n.reminderTimeRangeInvalid,
                style: TextStyle(
                  fontSize: 13,
                  color: isValid ? scheme.onSurfaceVariant : scheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeFieldTab extends StatelessWidget {
  const _TimeFieldTab({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.12) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.primary : const Color(0xFFE5E5EA),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.primary : AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.12) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? scheme.primary : const Color(0xFFE5E5EA),
            ),
          ),
          child: Text(
            label,
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
