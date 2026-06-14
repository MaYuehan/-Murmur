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
  static const double monthMarkerSize = 4;
  static const double monthMarkerGap = 2;

  static Widget monthDayCell({
    required int dayNumber,
    required Decoration decoration,
    required TextStyle textStyle,
    bool hasMarker = false,
    Color? markerColor,
  }) {
    return Center(
      child: Container(
        width: monthDayHighlightSize,
        height: monthDayHighlightSize,
        alignment: Alignment.center,
        decoration: decoration,
        child: _monthDayCellContent(
          dayNumber: dayNumber,
          textStyle: textStyle,
          hasMarker: hasMarker,
          markerColor: markerColor,
        ),
      ),
    );
  }

  static Widget monthDayCellPlain({
    required int dayNumber,
    required TextStyle textStyle,
    bool hasMarker = false,
    Color? markerColor,
  }) {
    return Center(
      child: _monthDayCellContent(
        dayNumber: dayNumber,
        textStyle: textStyle,
        hasMarker: hasMarker,
        markerColor: markerColor,
      ),
    );
  }

  static Widget _monthDayCellContent({
    required int dayNumber,
    required TextStyle textStyle,
    required bool hasMarker,
    Color? markerColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$dayNumber', style: textStyle),
        if (hasMarker) ...<Widget>[
          const SizedBox(height: monthMarkerGap),
          Container(
            width: monthMarkerSize,
            height: monthMarkerSize,
            decoration: BoxDecoration(
              color: markerColor ?? AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
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
      markerSize: 0,
      markerMargin: EdgeInsets.zero,
      markersAnchor: 0.5,
      tablePadding: EdgeInsets.zero,
      canMarkersOverflow: false,
      markersMaxCount: 0,
      selectedDecoration: monthDayHighlightDecoration(AppTheme.primaryColor),
      todayDecoration: monthDayHighlightDecoration(
        todayLightHighlightColor(AppTheme.primaryColor),
      ),
    );
  }

  static CalendarBuilders<void> calendarBuilders(
    BuildContext context, {
    int Function(DateTime day)? eventCountForDay,
  }) {
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

    bool hasEvents(DateTime day) => (eventCountForDay?.call(day) ?? 0) > 0;

    return CalendarBuilders<void>(
      markerBuilder: (BuildContext context, DateTime day, List<void> events) {
        if (events.isEmpty) {
          return null;
        }
        return const SizedBox.shrink();
      },
      defaultBuilder: (BuildContext context, DateTime day, DateTime focusedDay) {
        return monthDayCellPlain(
          dayNumber: day.day,
          textStyle: baseDayStyle,
          hasMarker: hasEvents(day),
          markerColor: scheme.primary,
        );
      },
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
          hasMarker: hasEvents(day),
          markerColor: scheme.primary,
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
          hasMarker: hasEvents(day),
          markerColor: scheme.onPrimary,
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
    int Function(DateTime day)? eventCountForDay,
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
      calendarBuilders: calendarBuilders(
        context,
        eventCountForDay: eventCountForDay ??
            (eventLoader == null
                ? null
                : (DateTime day) => eventLoader(day).length),
      ),
    );
  }
}
