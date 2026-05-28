import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationNavigationTarget {
  const NotificationNavigationTarget({
    required this.reminderId,
  });

  final String reminderId;
}

final notificationNavigationTargetProvider =
    StateProvider<NotificationNavigationTarget?>(
  (ref) => null,
);
