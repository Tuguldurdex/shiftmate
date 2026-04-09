import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/dashboard/domain/notification_model.dart';
import '../../services/mock_data_service.dart';
import 'providers.dart';

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>((
      ref,
    ) {
      final authState = ref.watch(authProvider);
      return NotificationsNotifier(authState.user?.id ?? '');
    });

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  final String _userId;
  final MockDataService _mockDataService = MockDataService();

  NotificationsNotifier(this._userId) : super([]) {
    _loadNotifications();
  }

  void _loadNotifications() {
    if (_userId.isNotEmpty) {
      state = _mockDataService.getMockNotifications(_userId);
    }
  }

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
