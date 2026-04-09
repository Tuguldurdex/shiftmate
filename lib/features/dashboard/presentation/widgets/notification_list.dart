import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as date_utils;
import '../../../../notifications_provider.dart';
import '../../../dashboard/domain/notification_model.dart';

class NotificationList extends ConsumerWidget {
  final List<NotificationModel> notifications;

  const NotificationList({super.key, required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (notifications.any((n) => !n.isRead))
                      TextButton(
                        onPressed: () {
                          ref
                              .read(notificationsProvider.notifier)
                              .markAllAsRead();
                        },
                        child: const Text('Mark all read'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 64,
                              color: AppTheme.textLight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notifications yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return _NotificationItem(notification: notification);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead
            ? Colors.white
            : AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead
              ? Colors.grey.shade200
              : AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getIconColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getIcon(), color: _getIconColor()),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message),
            const SizedBox(height: 8),
            Text(
              date_utils.DateTimeUtils.getRelativeDay(notification.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        onTap: () {
          if (!notification.isRead) {
            ref
                .read(notificationsProvider.notifier)
                .markAsRead(notification.id);
          }
        },
      ),
    );
  }

  IconData _getIcon() {
    if (notification.title.toLowerCase().contains('reminder')) {
      return Icons.alarm;
    } else if (notification.title.toLowerCase().contains('schedule')) {
      return Icons.calendar_today;
    } else if (notification.title.toLowerCase().contains('summary')) {
      return Icons.assessment;
    }
    return Icons.notifications;
  }

  Color _getIconColor() {
    if (notification.title.toLowerCase().contains('reminder')) {
      return AppTheme.warningColor;
    } else if (notification.title.toLowerCase().contains('schedule')) {
      return AppTheme.primaryColor;
    } else if (notification.title.toLowerCase().contains('summary')) {
      return AppTheme.accentColor;
    }
    return AppTheme.textSecondary;
  }
}
