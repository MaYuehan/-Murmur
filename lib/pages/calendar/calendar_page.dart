import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/core/utils/calendar_layout_utils.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/pages/calendar/reminder_detail_page.dart';
import 'package:murmur/providers/calendar_week_start_provider.dart';
import 'package:murmur/providers/notification_navigation_provider.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/widgets/app_calendar_styles.dart';
import 'package:murmur/widgets/app_date_picker.dart';
import 'package:murmur/widgets/app_slidable_action_button.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/widgets/create_reminder_sheet.dart';
import 'package:murmur/widgets/reminder_card.dart';
import 'package:table_calendar/table_calendar.dart';

enum _CalendarViewMode { month, week }

enum _WeekAgendaScope { week, day }

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  static final DateTime _calendarFirstDay = DateTime(2020, 1, 1);
  static final DateTime _calendarLastDay = DateTime(2035, 12, 31);

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _highlightedReminderId;
  _CalendarViewMode _viewMode = _CalendarViewMode.month;
  _WeekAgendaScope _weekAgendaScope = _WeekAgendaScope.week;
  bool _calendarViewPinned = AppSettingsStorage.calendarViewPinned;

  static const double _weekDaysRowHeight = 84;

  late final PageController _weekPageController = PageController(
    initialPage: _weekPageIndexFor(DateTime.now()),
  );

  int get _weekPageCount {
    final DateTime start = DateTimeUtils.startOfWeek(_calendarFirstDay);
    final DateTime end = DateTimeUtils.startOfWeek(_calendarLastDay);
    return end.difference(start).inDays ~/ 7 + 1;
  }

  static int _weekPageIndexFor(DateTime day) {
    final DateTime start = DateTimeUtils.startOfWeek(_calendarFirstDay);
    final DateTime target = DateTimeUtils.startOfWeek(day);
    return target.difference(start).inDays ~/ 7;
  }

  DateTime _weekStartForPageIndex(int index) {
    return DateTimeUtils.startOfWeek(_calendarFirstDay).add(Duration(days: 7 * index));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyNotificationTargetIfNeeded();
    });
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  void _openCreateReminderSheet() {
    CreateReminderSheet.show(context, initialDate: _selectedDay);
  }

  void _openReminderDetail(Reminder reminder) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReminderDetailPage(reminderId: reminder.id),
      ),
    );
  }

  Future<void> _editReminder(Reminder reminder) async {
    await CreateReminderSheet.show(
      context,
      initialDate: reminder.scheduledTime ?? _selectedDay,
      editingReminder: reminder,
    );
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.calendarDeleteTitle),
          content: Text(l10n.calendarDeleteMessage(reminder.title)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.destructiveColor,
              ),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(reminderListProvider.notifier).deleteReminder(reminder.id);
    if (!mounted) {
      return;
    }
    if (_highlightedReminderId == reminder.id) {
      setState(() => _highlightedReminderId = null);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.calendarDeletedSnack)),
    );
  }

  Widget _buildSlidableReminderCard(Reminder reminder) {
    return Slidable(
      key: ValueKey<String>('calendar_${reminder.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.24,
        children: <Widget>[
          AppSlidableActionButton(
            onPressed: () => _editReminder(reminder),
            icon: Icons.edit_outlined,
            iconColor: AppTheme.primaryColor,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
          AppSlidableActionButton(
            onPressed: () => _deleteReminder(reminder),
            icon: Icons.delete_outline,
            iconColor: AppTheme.destructiveColor,
            backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
          ),
        ],
      ),
      child: ReminderCard(
        reminder: reminder,
        isHighlighted: reminder.id == _highlightedReminderId,
        onTap: () => _openReminderDetail(reminder),
      ),
    );
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
  }

  void _onWeekPageChanged(int index) {
    final DateTime weekStart = DateTimeUtils.startOfWeek(_selectedDay);
    final int dayOffset = _selectedDay.difference(weekStart).inDays;
    final DateTime newSelected = _weekStartForPageIndex(index).add(Duration(days: dayOffset));
    if (isSameDay(newSelected, _selectedDay)) {
      return;
    }
    setState(() {
      _selectedDay = newSelected;
      _focusedDay = newSelected;
    });
  }

  void _syncWeekPageControllerToSelectedDay({bool animate = false}) {
    final int index = _weekPageIndexFor(_selectedDay);
    if (!_weekPageController.hasClients) {
      return;
    }
    final double? page = _weekPageController.page;
    if (page != null && page.round() == index) {
      return;
    }
    if (animate) {
      _weekPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      _weekPageController.jumpToPage(index);
    }
  }

  void _goToToday() {
    final DateTime today = DateTimeUtils.startOfDay(DateTime.now());
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWeekPageControllerToSelectedDay(animate: true);
    });
  }

  bool _isCurrentWeek(DateTime day) {
    final DateTime today = DateTimeUtils.startOfDay(DateTime.now());
    return DateTimeUtils.startOfWeek(day) == DateTimeUtils.startOfWeek(today);
  }

  bool _isCurrentMonth(DateTime day) {
    final DateTime today = DateTimeUtils.startOfDay(DateTime.now());
    return day.year == today.year && day.month == today.month;
  }

  Widget _buildBackToTodayButton(AppLocalizations l10n) {
    return TextButton(
      onPressed: _goToToday,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppTheme.primaryColor,
      ),
      child: Text(
        l10n.calendarBackToToday,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  static const TextStyle _calendarPeriodTitleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimaryColor,
  );

  /// Month name only, e.g. `六月` / `June`.
  String _formatMonthHeader(DateTime day) {
    final String localeName = Localizations.localeOf(context).toString();
    return DateFormat.MMMM(localeName).format(day);
  }

  String _formatAppBarYear() {
    final int year = _viewMode == _CalendarViewMode.month
        ? _focusedDay.year
        : _selectedDay.year;
    final String localeName = Localizations.localeOf(context).toString();
    return DateFormat.y(localeName).format(DateTime(year));
  }

  TextStyle _appBarYearTextStyle(BuildContext context) {
    return Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ) ??
        const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        );
  }

  String _formatMonthDay(DateTime day) {
    final String localeName = Localizations.localeOf(context).toString();
    return DateFormat.MMMd(localeName).format(day);
  }

  /// Month agenda section header: `今天 · 6月1日` or e.g. `6月1日`.
  String _formatMonthAgendaDateHeader(DateTime day, AppLocalizations l10n) {
    final String monthDay = _formatMonthDay(day);
    if (isSameDay(day, DateTime.now())) {
      return '${l10n.calendarToday} · $monthDay';
    }
    return monthDay;
  }

  /// Week agenda section header: `今天 · 6月1日` or e.g. `周一 · 6月1日`.
  String _formatWeekAgendaDateHeader(DateTime day, AppLocalizations l10n) {
    final String monthDay = _formatMonthDay(day);
    if (isSameDay(day, DateTime.now())) {
      return '${l10n.calendarToday} · $monthDay';
    }
    return '${DateTimeUtils.weekdayLabel(day.weekday)} · $monthDay';
  }

  void _applyMonthYear(DateTime monthYear) {
    final int year = monthYear.year;
    final int month = monthYear.month;
    final int maxDay = DateTime(year, month + 1, 0).day;
    final int day = _selectedDay.day <= maxDay ? _selectedDay.day : maxDay;
    setState(() {
      _focusedDay = DateTime(year, month, day);
      _selectedDay = _focusedDay;
    });
  }

  Future<void> _pickMonthYear(BuildContext anchorContext) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? picked = await showAppCupertinoWheelPicker(
      context: context,
      anchorContext: anchorContext,
      title: l10n.calendarPickMonthYear,
      initialDateTime: _focusedDay,
      minimumDate: _calendarFirstDay,
      maximumDate: _calendarLastDay,
      mode: CupertinoDatePickerMode.monthYear,
    );
    if (picked == null || !mounted) {
      return;
    }
    _applyMonthYear(picked);
  }

  Future<void> _pickWeek(BuildContext anchorContext) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime? picked = await showAppCupertinoWheelPicker(
      context: context,
      anchorContext: anchorContext,
      title: l10n.calendarPickWeek,
      initialDateTime: _selectedDay,
      minimumDate: _calendarFirstDay,
      maximumDate: _calendarLastDay,
      mode: CupertinoDatePickerMode.date,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDay = DateTimeUtils.startOfDay(picked);
      _focusedDay = _selectedDay;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWeekPageControllerToSelectedDay();
    });
  }

  Future<void> _toggleCalendarViewPinned() async {
    setState(() => _calendarViewPinned = !_calendarViewPinned);
    await AppSettingsStorage.setCalendarViewPinned(_calendarViewPinned);
  }

  Widget _buildPinViewButton(AppLocalizations l10n) {
    return IconButton(
      onPressed: _toggleCalendarViewPinned,
      icon: Icon(
        _calendarViewPinned ? Icons.push_pin : Icons.push_pin_outlined,
        size: 18,
        color: _calendarViewPinned
            ? AppTheme.primaryColor
            : AppTheme.secondaryLabelColor,
      ),
      tooltip: _calendarViewPinned ? l10n.calendarUnpinView : l10n.calendarPinView,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }

  Widget _buildCalendarPeriodHeader({
    required AppLocalizations l10n,
    required String label,
    required Future<void> Function(BuildContext anchorContext) onTap,
    required bool showBackToToday,
    TextStyle? titleStyle,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (showBackToToday) _buildBackToTodayButton(l10n),
              const Spacer(),
              _buildPinViewButton(l10n),
            ],
          ),
          _buildTappablePeriodTitle(
            label: label,
            onTap: onTap,
            style: titleStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildTappablePeriodTitle({
    required String label,
    required Future<void> Function(BuildContext anchorContext) onTap,
    TextStyle? style,
  }) {
    return Builder(
      builder: (BuildContext anchorContext) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(anchorContext),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 10, 4),
              child: AppChalkUnderlineLabel(
                label: label,
                style: style,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderListProvider);
    ref.watch(calendarWeekStartsOnMondayProvider);
    ref.watch(notificationNavigationTargetProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyNotificationTargetIfNeeded();
    });
    final reminderNotifier = ref.read(reminderListProvider.notifier);
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: kToolbarHeight,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  AppUnderlineTabControl<_CalendarViewMode>(
                    options: <AppSegmentOption<_CalendarViewMode>>[
                      AppSegmentOption(
                        value: _CalendarViewMode.month,
                        label: l10n.calendarViewMonth,
                      ),
                      AppSegmentOption(
                        value: _CalendarViewMode.week,
                        label: l10n.calendarViewWeek,
                      ),
                    ],
                    selected: _viewMode,
                    onChanged: (_CalendarViewMode mode) {
                      setState(() => _viewMode = mode);
                    },
                  ),
                  Positioned(
                    left: AppTheme.pagePadding,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Text(
                        _formatAppBarYear(),
                        style: _appBarYearTextStyle(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          AppBarTextAction(
            label: l10n.commonCreate,
            onPressed: _openCreateReminderSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _buildCalendarBody(reminderNotifier)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarPanel(ReminderNotifier notifier) {
    return _viewMode == _CalendarViewMode.month
        ? _buildMonthCalendar(notifier)
        : _buildWeekStrip(notifier);
  }

  Widget _buildWeekAgendaScopeTabControl({
    required String weekLabel,
    required String dayLabel,
    required _WeekAgendaScope selected,
    required ValueChanged<_WeekAgendaScope> onChanged,
  }) {
    return AppChipSegmentedControl<_WeekAgendaScope>(
      options: <AppSegmentOption<_WeekAgendaScope>>[
        AppSegmentOption(
          value: _WeekAgendaScope.week,
          label: weekLabel,
        ),
        AppSegmentOption(
          value: _WeekAgendaScope.day,
          label: dayLabel,
        ),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }

  Widget _buildWeekAgendaScopeControl() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isCurrentWeek = _isCurrentWeek(_selectedDay);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: _buildWeekAgendaScopeTabControl(
          weekLabel: l10n.calendarScopeWeek(isCurrentWeek),
          dayLabel: l10n.calendarScopeSelectedDay,
          selected: _weekAgendaScope,
          onChanged: (_WeekAgendaScope scope) {
            setState(() => _weekAgendaScope = scope);
          },
        ),
      ),
    );
  }

  SliverPersistentHeader _pinnedWeekAgendaScopeHeader() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isCurrentWeek = _isCurrentWeek(_selectedDay);

    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedWeekAgendaScopeHeaderDelegate(
        weekLabel: l10n.calendarScopeWeek(isCurrentWeek),
        dayLabel: l10n.calendarScopeSelectedDay,
        selected: _weekAgendaScope,
        onChanged: (_WeekAgendaScope scope) {
          setState(() => _weekAgendaScope = scope);
        },
      ),
    );
  }

  Widget _buildCalendarBody(ReminderNotifier notifier) {
    final Widget calendarPanel = _buildCalendarPanel(notifier);
    final List<Widget> agendaSlivers = _buildAgendaSlivers(notifier);
    final bool showWeekScope = _viewMode == _CalendarViewMode.week;

    if (_calendarViewPinned) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          calendarPanel,
          const SizedBox(height: 12),
          if (showWeekScope) _buildWeekAgendaScopeControl(),
          Expanded(
            child: CustomScrollView(
              slivers: <Widget>[
                ...agendaSlivers,
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: calendarPanel),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (showWeekScope) _pinnedWeekAgendaScopeHeader(),
        ...agendaSlivers,
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _buildMonthCalendar(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isCurrentMonth = _isCurrentMonth(_focusedDay);
    final bool weekStartsOnMonday = ref.watch(calendarWeekStartsOnMondayProvider);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppGroupedSection(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Column(
              children: <Widget>[
                _buildCalendarPeriodHeader(
                  l10n: l10n,
                  label: _formatMonthHeader(_focusedDay),
                  onTap: _pickMonthYear,
                  showBackToToday: !isCurrentMonth,
                  titleStyle: _calendarPeriodTitleStyle,
                ),
                AppInsetPanel(
                  child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  child: TableCalendar<void>(
                    key: ValueKey<String>(
                      'month_${_focusedDay.year}_${_focusedDay.month}_$weekStartsOnMonday',
                    ),
                    firstDay: _calendarFirstDay,
                    lastDay: _calendarLastDay,
                    focusedDay: _focusedDay,
                    startingDayOfWeek: weekStartsOnMonday
                        ? StartingDayOfWeek.monday
                        : StartingDayOfWeek.sunday,
                    headerVisible: false,
                    sixWeekMonthsEnforced: false,
                    rowHeight: CalendarLayoutUtils.monthRowHeight,
                    daysOfWeekHeight: CalendarLayoutUtils.daysOfWeekHeight,
            selectedDayPredicate: (DateTime day) => isSameDay(_selectedDay, day),
            onDaySelected: (DateTime selectedDay, DateTime focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (DateTime focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            eventLoader: (DateTime day) {
              final int count = notifier.fixedReminderCountForDay(day);
              return List<void>.filled(count, null, growable: false);
            },
            calendarStyle: AppCalendarStyles.calendarStyle(context),
            calendarBuilders: AppCalendarStyles.calendarBuilders(
              context,
              eventCountForDay: notifier.fixedReminderCountForDay,
            ),
                  ),
                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDaysRow({
    required DateTime weekStart,
    required ReminderNotifier notifier,
    required int selectedDayOffset,
  }) {
    final List<DateTime> weekDays = List<DateTime>.generate(
      7,
      (int index) => weekStart.add(Duration(days: index)),
    );
    final DateTime selectedInWeek = weekStart.add(Duration(days: selectedDayOffset));

    return Row(
      children: weekDays.map((DateTime day) {
        final bool isSelected = isSameDay(day, selectedInWeek);
        final bool isToday = isSameDay(day, DateTime.now());
        final int count = notifier.fixedReminderCountForDay(day);

        return Expanded(
          child: GestureDetector(
            onTap: () => _selectDay(day),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isToday
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    DateTimeUtils.shortWeekdayLabel(day.weekday),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : null,
                        ),
                  ),
                  if (count > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekStrip(ReminderNotifier notifier) {
    ref.watch(calendarWeekStartsOnMondayProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isCurrentWeek = _isCurrentWeek(_selectedDay);
    final DateTime weekStart = DateTimeUtils.startOfWeek(_selectedDay);
    final int selectedDayOffset = _selectedDay.difference(weekStart).inDays;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppGroupedSection(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
            child: Column(
            children: <Widget>[
              _buildCalendarPeriodHeader(
                l10n: l10n,
                label: _formatMonthHeader(_selectedDay),
                onTap: _pickWeek,
                showBackToToday: !isCurrentWeek,
                titleStyle: _calendarPeriodTitleStyle,
              ),
              AppInsetPanel(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  height: _weekDaysRowHeight,
                  child: PageView.builder(
                    controller: _weekPageController,
                    itemCount: _weekPageCount,
                    onPageChanged: _onWeekPageChanged,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildWeekDaysRow(
                        weekStart: _weekStartForPageIndex(index),
                        notifier: notifier,
                        selectedDayOffset: selectedDayOffset,
                      );
                    },
                  ),
                ),
              ),
            ],
            ),
          ),
        ],
      ),
    );
  }

  SliverPersistentHeader _pinnedAgendaDateHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedAgendaDateHeaderDelegate(title: title),
    );
  }

  List<Widget> _buildAgendaSlivers(ReminderNotifier notifier) {
    if (_viewMode == _CalendarViewMode.month) {
      return _buildMonthDayAgendaSlivers(notifier);
    }
    return _buildWeekAgendaSlivers(notifier);
  }

  List<Widget> _buildMonthDayAgendaSlivers(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Reminder> reminders =
        notifier.getFixedRemindersByDay(_selectedDay);
    final String dateTitle = _formatMonthAgendaDateHeader(_selectedDay, l10n);

    return <Widget>[
      _pinnedAgendaDateHeader(dateTitle),
      if (reminders.isEmpty)
        SliverToBoxAdapter(
          child: AppEmptyState(
            icon: Icons.event_available_outlined,
            title: l10n.calendarEmptyDayTitle,
            subtitle: l10n.calendarEmptyDaySubtitle,
          ),
        )
      else
        _buildReminderListSliver(reminders),
    ];
  }

  List<Widget> _buildWeekAgendaSlivers(ReminderNotifier notifier) {
    if (_weekAgendaScope == _WeekAgendaScope.day) {
      return _buildSelectedDayAgendaSlivers(notifier);
    }
    return _buildWeekAgendaContentSlivers(notifier);
  }

  List<Widget> _buildSelectedDayAgendaSlivers(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Reminder> reminders =
        notifier.getFixedRemindersByDay(_selectedDay);
    final String dateTitle = _formatWeekAgendaDateHeader(_selectedDay, l10n);

    return <Widget>[
      _pinnedAgendaDateHeader(dateTitle),
      if (reminders.isEmpty)
        SliverToBoxAdapter(
          child: AppEmptyState(
            icon: Icons.event_available_outlined,
            title: l10n.calendarEmptyDayNamedTitle(dateTitle),
            subtitle: l10n.calendarEmptyDaySubtitle,
          ),
        )
      else
        _buildReminderListSliver(reminders),
    ];
  }

  List<Widget> _buildWeekAgendaContentSlivers(ReminderNotifier notifier) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isCurrentWeek = _isCurrentWeek(_selectedDay);
    final List<DateTime> weekDays = DateTimeUtils.daysInWeek(_selectedDay);
    final List<Widget> slivers = <Widget>[];
    var hasAnyReminders = false;

    for (final DateTime day in weekDays) {
      final List<Reminder> reminders = notifier.getFixedRemindersByDay(day);
      if (reminders.isEmpty) {
        continue;
      }
      hasAnyReminders = true;
      final String dateTitle = _formatWeekAgendaDateHeader(day, l10n);
      slivers.add(
        SliverMainAxisGroup(
          slivers: <Widget>[
            _pinnedAgendaDateHeader(dateTitle),
            _buildReminderListSliver(reminders),
          ],
        ),
      );
    }

    if (!hasAnyReminders) {
      slivers.add(
        SliverToBoxAdapter(
          child: AppEmptyState(
            icon: Icons.date_range_outlined,
            title: l10n.calendarEmptyWeekTitle(isCurrentWeek),
            subtitle: l10n.calendarEmptyWeekSubtitle,
          ),
        ),
      );
    }

    return slivers;
  }

  List<Widget> _collectReminderListChildren(List<Reminder> reminders) {
    final List<Reminder> deadlineReminders = reminders
        .where((Reminder reminder) => reminder.isTodoDeadline)
        .toList();
    final List<Reminder> normalReminders = reminders
        .where((Reminder reminder) => !reminder.isTodoDeadline)
        .toList();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextStyle deadlineSectionTitleStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.deadlineColor,
              fontWeight: FontWeight.w600,
            ) ??
            const TextStyle(
              fontSize: 12,
              color: AppTheme.deadlineColor,
              fontWeight: FontWeight.w600,
            );
    final TextStyle scheduleSectionTitleStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ) ??
            const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            );

    final bool showSectionTitles = deadlineReminders.isNotEmpty;
    final List<Widget> items = <Widget>[];

    if (deadlineReminders.isNotEmpty) {
      if (showSectionTitles) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: Text(
              l10n.calendarDeadlineSection,
              style: deadlineSectionTitleStyle,
            ),
          ),
        );
      }
      for (final Reminder reminder in deadlineReminders) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildSlidableReminderCard(reminder),
          ),
        );
      }
    }

    if (normalReminders.isNotEmpty) {
      if (showSectionTitles) {
        items.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: 8,
              top: deadlineReminders.isNotEmpty ? 2 : 2,
            ),
            child: Text(
              l10n.calendarScheduleSection,
              style: scheduleSectionTitleStyle,
            ),
          ),
        );
      }
    }

    for (final Reminder reminder in normalReminders) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildSlidableReminderCard(reminder),
        ),
      );
    }

    return items;
  }

  Widget _buildReminderListSliver(List<Reminder> reminders) {
    final List<Widget> items = _collectReminderListChildren(reminders);
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) => items[index],
        childCount: items.length,
      ),
    );
  }

  void _applyNotificationTargetIfNeeded() {
    final target = ref.read(notificationNavigationTargetProvider);
    if (target == null) {
      return;
    }

    final Reminder? reminder = ref
        .read(reminderListProvider.notifier)
        .getReminderById(target.reminderId);
    if (reminder == null || reminder.scheduledTime == null) {
      ref.read(notificationNavigationTargetProvider.notifier).state = null;
      return;
    }

    final DateTime day = DateTimeUtils.startOfDay(reminder.scheduledTime!);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
      _highlightedReminderId = reminder.id;
    });
    ref.read(notificationNavigationTargetProvider.notifier).state = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncWeekPageControllerToSelectedDay();
      _openReminderDetail(reminder);
    });
  }
}

class _PinnedWeekAgendaScopeHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedWeekAgendaScopeHeaderDelegate({
    required this.weekLabel,
    required this.dayLabel,
    required this.selected,
    required this.onChanged,
  });

  final String weekLabel;
  final String dayLabel;
  final _WeekAgendaScope selected;
  final ValueChanged<_WeekAgendaScope> onChanged;
  static const double _extent = 44;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppTheme.groupedBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: AppChipSegmentedControl<_WeekAgendaScope>(
            options: <AppSegmentOption<_WeekAgendaScope>>[
              AppSegmentOption(
                value: _WeekAgendaScope.week,
                label: weekLabel,
              ),
              AppSegmentOption(
                value: _WeekAgendaScope.day,
                label: dayLabel,
              ),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedWeekAgendaScopeHeaderDelegate oldDelegate) {
    return oldDelegate.weekLabel != weekLabel ||
        oldDelegate.dayLabel != dayLabel ||
        oldDelegate.selected != selected;
  }
}

class _PinnedAgendaDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedAgendaDateHeaderDelegate({required this.title});

  final String title;
  static const double _extent = 36;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppTheme.groupedBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedAgendaDateHeaderDelegate oldDelegate) {
    return oldDelegate.title != title;
  }
}
