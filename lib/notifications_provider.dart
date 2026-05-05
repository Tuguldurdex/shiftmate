import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/dashboard/domain/notification_model.dart';

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>((
      ref,
    ) {
      return NotificationsNotifier();
    });

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier() : super([]);

  void markAsRead(String notificationId) {
    state = state
        .map((n) => n.id == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void addNotification(NotificationModel notification) {
    state = [notification, ...state];
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

final unreadNotificationsProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});
