import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';

final showTodoCreatedDateProvider =
    StateNotifierProvider<TodoDisplaySettingsNotifier, bool>(
  (ref) => TodoDisplaySettingsNotifier(),
);

class TodoDisplaySettingsNotifier extends StateNotifier<bool> {
  TodoDisplaySettingsNotifier() : super(AppSettingsStorage.showTodoCreatedDate);

  Future<void> setShowTodoCreatedDate(bool value) async {
    if (state == value) {
      return;
    }
    await AppSettingsStorage.setShowTodoCreatedDate(value);
    state = value;
  }
}
