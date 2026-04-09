import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers.dart';
import '../../../../shifts_provider.dart';
import '../../../../notifications_provider.dart';
import '../../../shifts/domain/shift_model.dart';
import '../../../shifts/presentation/widgets/shift_card.dart';
import '../../../dashboard/presentation/widgets/overview_card.dart';
import '../../../dashboard/presentation/widgets/notification_list.dart';
import '../../../dashboard/domain/notification_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final todayShifts = ref.watch(todayShiftsProvider);
    final totalHours = ref.watch(totalHoursProvider);
    final upcomingShifts = ref.watch(upcomingShiftsProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${authState.user?.name.split(' ').first ?? 'User'}',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const Text('Dashboard', style: TextStyle(fontSize: 20)),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () =>
                    _showNotificationsBottomSheet(context, ref, notifications),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outlined),
            onPressed: () => context.go('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OverviewCard(
                      title: 'Today\'s Shifts',
                      value: '${todayShifts.length}',
                      icon: Icons.calendar_today,
                      color: AppTheme.primaryColor,
                      onTap: () => context.go('/shifts'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OverviewCard(
                      title: 'Hours Worked',
                      value: '${totalHours.toStringAsFixed(1)}h',
                      icon: Icons.access_time,
                      color: AppTheme.accentColor,
                      onTap: () => context.go('/shifts'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OverviewCard(
                      title: 'Upcoming',
                      value: '${upcomingShifts.length}',
                      icon: Icons.upcoming,
                      color: AppTheme.secondaryColor,
                      onTap: () => context.go('/shifts'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OverviewCard(
                      title: 'Notifications',
                      value: '$unreadNotifications',
                      icon: Icons.notifications,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTodaySection(context, todayShifts),
              const SizedBox(height: 24),
              _buildUpcomingSection(context, upcomingShifts.take(3).toList()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/add-shift'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodaySection(BuildContext context, List<ShiftModel> shifts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Shifts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => context.go('/shifts'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shifts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 48,
                      color: AppTheme.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No shifts today',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...shifts.map(
            (shift) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ShiftCard(shift: shift, showDate: false),
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingSection(BuildContext context, List<ShiftModel> shifts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Shifts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => context.go('/shifts'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shifts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 48, color: AppTheme.textLight),
                    const SizedBox(height: 12),
                    Text(
                      'No upcoming shifts',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...shifts.map(
            (shift) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ShiftCard(shift: shift, showDate: true),
            ),
          ),
      ],
    );
  }

  void _showNotificationsBottomSheet(
    BuildContext context,
    WidgetRef ref,
    List<NotificationModel> notifications,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NotificationList(notifications: notifications),
    );
  }
}
