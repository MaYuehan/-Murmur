import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/core/utils/notification_service.dart';
import 'package:murmur/core/utils/reminder_storage.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/models/todo_group.dart';
import 'package:murmur/pages/calendar/calendar_page.dart';
import 'package:murmur/pages/family/family_page.dart';
import 'package:murmur/pages/profile/profile_page.dart';
import 'package:murmur/pages/todo/todo_page.dart';
import 'package:murmur/providers/locale_provider.dart';
import 'package:murmur/providers/notification_navigation_provider.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/providers/todo_group_provider.dart';
import 'package:murmur/services/voice_remind_playback.dart';
import 'package:murmur/services/voice_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
late final ProviderContainer _bootstrapContainer;
final ValueNotifier<int> appTabIndexNotifier = ValueNotifier<int>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderStorage.init();
  await AppSettingsStorage.init();
  AppLocalizationsBinding.instance = AppLocalizations(AppSettingsStorage.appLocale);

  final List<Reminder> initialReminders = ReminderStorage.loadReminders();
  final List<TodoGroup> initialTodoGroups = ReminderStorage.loadTodoGroups();
  _bootstrapContainer = ProviderContainer(
    overrides: <Override>[
      initialReminderListProvider.overrideWithValue(initialReminders),
      initialTodoGroupListProvider.overrideWithValue(initialTodoGroups),
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
      await VoiceRemindPlayback.playForReminder(reminder);
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

  await VoiceService.bootstrap();
  final Set<String> protectedRecordingPaths = initialReminders
      .map((Reminder r) => r.voicePath)
      .whereType<String>()
      .where((String path) => path.isNotEmpty)
      .toSet();
  await VoiceService.purgeExpiredRecordings(protectedRecordingPaths);

  runApp(
    UncontrolledProviderScope(
      container: _bootstrapContainer,
      child: const MurmurApp(),
    ),
  );
}

class MurmurApp extends ConsumerWidget {
  const MurmurApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Locale locale = ref.watch(localeProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: AppLocalizations(locale).appWindowTitle,
      locale: locale,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
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
    FamilyPage(),
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
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: l10n.navCalendar,
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: l10n.navTodo,
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: l10n.navFamily,
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: l10n.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
