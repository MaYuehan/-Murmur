import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/notification_service.dart';
import 'package:murmur/core/utils/reminder_storage.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/pages/calendar/calendar_page.dart';
import 'package:murmur/pages/profile/profile_page.dart';
import 'package:murmur/pages/todo/todo_page.dart';
import 'package:murmur/pages/voice/voice_page.dart';
import 'package:murmur/providers/notification_navigation_provider.dart';
import 'package:murmur/providers/reminder_provider.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
late final ProviderContainer _bootstrapContainer;
final ValueNotifier<int> appTabIndexNotifier = ValueNotifier<int>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderStorage.init();

  final List<Reminder> initialReminders = ReminderStorage.loadReminders();
  _bootstrapContainer = ProviderContainer(
    overrides: <Override>[
      initialReminderListProvider.overrideWithValue(initialReminders),
    ],
  );

  await NotificationService.init(
    onNotificationTap: (String? payload) async {
      if (payload == null || payload.isEmpty) {
        return;
      }
      final Reminder? reminder = _bootstrapContainer
          .read(reminderListProvider.notifier)
          .getReminderById(payload);
      if (reminder == null) {
        return;
      }
      _bootstrapContainer
          .read(notificationNavigationTargetProvider.notifier)
          .state = NotificationNavigationTarget(reminderId: payload);
      appTabIndexNotifier.value = 0;
      appNavigatorKey.currentState?.popUntil((Route<dynamic> route) {
        return route.isFirst;
      });
    },
  );
  await NotificationService.requestPermissions();
  await NotificationService.rescheduleFixedReminders(initialReminders);

  runApp(
    UncontrolledProviderScope(
      container: _bootstrapContainer,
      child: const MurmurApp(),
    ),
  );
}

class MurmurApp extends StatelessWidget {
  const MurmurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: '亲声 Murmur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    CalendarPage(),
    TodoPage(),
    VoicePage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    appTabIndexNotifier.addListener(_syncTabFromNotifier);
  }

  @override
  void dispose() {
    appTabIndexNotifier.removeListener(_syncTabFromNotifier);
    super.dispose();
  }

  void _syncTabFromNotifier() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = appTabIndexNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '待办',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic),
            label: '声音',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
