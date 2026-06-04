import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/core/utils/calendar_layout_utils.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:table_calendar/table_calendar.dart';

class AppCalendarStyles {
  AppCalendarStyles._();

  /// Empty cell decoration (avoids table_calendar's default circle shape).
  static const Decoration monthDayCellDecoration = BoxDecoration();

  /// Light yellow background for today when it is not the selected day.
  static Color todayLightHighlightColor(Color primary) {
    return primary.withValues(alpha: 0.14);
  }

  static BoxDecoration monthDayHighlightDecoration(Color color) {
    return BoxDecoration(
      color: color,
      shape: BoxShape.circle,
    );
  }

  static const double monthDayHighlightSize = 40;

  static Widget monthDayCell({
    required int dayNumber,
    required Decoration decoration,
    required TextStyle textStyle,
  }) {
    // Use [Container] not [AnimatedContainer]: decoration tween cannot mix
    // circle and borderRadius (e.g. after hot reload or style changes).
    return Center(
      child: Container(
        width: monthDayHighlightSize,
        height: monthDayHighlightSize,
        alignment: Alignment.center,
        decoration: decoration,
        child: Text('$dayNumber', style: textStyle),
      ),
    );
  }

  static const HeaderStyle headerStyle = HeaderStyle(
    titleCentered: true,
    formatButtonVisible: false,
    headerPadding: EdgeInsets.symmetric(vertical: 4),
    titleTextStyle: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: AppTheme.textPrimaryColor,
    ),
    leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.primaryColor, size: 24),
    rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.primaryColor, size: 24),
  );

  static CalendarStyle calendarStyle(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return CalendarStyle(
      outsideDaysVisible: false,
      cellMargin: const EdgeInsets.all(2),
      defaultDecoration: monthDayCellDecoration,
      weekendDecoration: monthDayCellDecoration,
      outsideDecoration: monthDayCellDecoration,
      disabledDecoration: monthDayCellDecoration,
      withinRangeDecoration: monthDayCellDecoration,
      rangeStartDecoration: monthDayCellDecoration,
      rangeEndDecoration: monthDayCellDecoration,
      defaultTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppTheme.textPrimaryColor,
      ),
      weekendTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppTheme.textPrimaryColor,
      ),
      selectedTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onPrimary,
      ),
      todayTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimaryColor,
      ),
      markerSize: 4,
      markerMargin: EdgeInsets.zero,
      markersAnchor: 0.65,
      tablePadding: const EdgeInsets.only(bottom: 4),
      canMarkersOverflow: true,
      markersMaxCount: 1,
      markerDecoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
      ),
      selectedDecoration: monthDayHighlightDecoration(AppTheme.primaryColor),
      todayDecoration: monthDayHighlightDecoration(
        todayLightHighlightColor(AppTheme.primaryColor),
      ),
    );
  }

  static CalendarBuilders calendarBuilders(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle baseDayStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimaryColor,
        ) ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimaryColor,
        );

    return CalendarBuilders<void>(
      dowBuilder: (BuildContext context, DateTime day) {
        return Center(
          child: Text(
            DateTimeUtils.shortWeekdayLabel(day.weekday),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryLabelColor,
                ),
          ),
        );
      },
      todayBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
        return monthDayCell(
          dayNumber: day.day,
          decoration: monthDayHighlightDecoration(
            todayLightHighlightColor(AppTheme.primaryColor),
          ),
          textStyle: baseDayStyle.copyWith(fontWeight: FontWeight.w700),
        );
      },
      selectedBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
        return monthDayCell(
          dayNumber: day.day,
          decoration: monthDayHighlightDecoration(AppTheme.primaryColor),
          textStyle: baseDayStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onPrimary,
          ),
        );
      },
    );
  }

  static TableCalendar<void> monthCalendar({
    required BuildContext context,
    required DateTime focusedDay,
    required DateTime selectedDay,
    required DateTime firstDay,
    required DateTime lastDay,
    required void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected,
    void Function(DateTime focusedDay)? onPageChanged,
    List<void> Function(DateTime day)? eventLoader,
  }) {
    final bool weekStartsOnMonday = AppSettingsStorage.weekStartsOnMonday;

    return TableCalendar<void>(
      firstDay: firstDay,
      lastDay: lastDay,
      focusedDay: focusedDay,
      startingDayOfWeek: weekStartsOnMonday
          ? StartingDayOfWeek.monday
          : StartingDayOfWeek.sunday,
      selectedDayPredicate: (DateTime day) => isSameDay(selectedDay, day),
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
      eventLoader: eventLoader,
      sixWeekMonthsEnforced: false,
      rowHeight: CalendarLayoutUtils.monthRowHeight,
      daysOfWeekHeight: CalendarLayoutUtils.daysOfWeekHeight,
      headerStyle: headerStyle,
      calendarStyle: calendarStyle(context),
      calendarBuilders: calendarBuilders(context),
    );
  }
}
