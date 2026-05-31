import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/calendar_layout_utils.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:table_calendar/table_calendar.dart';

class AppCalendarStyles {
  AppCalendarStyles._();

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
      markerMargin: const EdgeInsets.only(top: 4),
      markersMaxCount: 1,
      markerDecoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
      ),
      selectedDecoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
      ),
      todayDecoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
    );
  }

  static CalendarBuilders calendarBuilders(BuildContext context) {
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
    return TableCalendar<void>(
      firstDay: firstDay,
      lastDay: lastDay,
      focusedDay: focusedDay,
      selectedDayPredicate: (DateTime day) => isSameDay(selectedDay, day),
      onDaySelected: onDaySelected,
      onPageChanged: onPageChanged,
      eventLoader: eventLoader,
      sixWeekMonthsEnforced: true,
      rowHeight: CalendarLayoutUtils.rowHeight,
      daysOfWeekHeight: CalendarLayoutUtils.daysOfWeekHeight,
      headerStyle: headerStyle,
      calendarStyle: calendarStyle(context),
      calendarBuilders: calendarBuilders(context),
    );
  }
}
