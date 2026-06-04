import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';

final calendarWeekStartsOnMondayProvider =
    StateNotifierProvider<CalendarWeekStartNotifier, bool>(
  (ref) => CalendarWeekStartNotifier(),
);

class CalendarWeekStartNotifier extends StateNotifier<bool> {
  CalendarWeekStartNotifier() : super(AppSettingsStorage.weekStartsOnMonday);

  Future<void> setWeekStartsOnMonday(bool value) async {
    if (state == value) {
      return;
    }
    await AppSettingsStorage.setWeekStartsOnMonday(value);
    state = value;
  }
}
