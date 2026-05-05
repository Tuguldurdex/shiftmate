import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../shifts_provider.dart';
import '../../../../notifications_provider.dart';
import '../../../shifts/domain/shift_model.dart';
import '../../../group_chat/presentation/screens/group_chat_screen.dart';
import '../../../group_chat/presentation/providers/chat_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const i18n = {
    'mn': {
      'greeting': 'Сайн байна уу,',
      'dashboard': 'Миний хуваарь',
      'today': 'Өнөөдөр',
      'upcoming': 'Удахгүй',
      'hoursWorked': 'Ажилласан цаг',
      'notifications': 'Мэдэгдэл',
      'viewAll': 'Бүгд харах',
      'noShiftsToday': 'Өнөөдөр ээлж байхгүй',
      'noUpcomingShifts': 'Ирэх ээлж байхгүй',
      'aiAssistant': 'AI Туслах',
      'aiReady': 'LlamaBot бэлэн байна',
      'chatWithAI': 'Ярилцах',
      'todayShifts': 'Өнөөдөр',
      'upcomingShifts': 'Ирэх ээлжүүд',
      'active': 'Идэвхтэй',
      'upcomingLabel': 'Удахгүй',
      'completed': 'Дууссан',
    },
    'en': {
      'greeting': 'Hello,',
      'dashboard': 'My Schedule',
      'today': 'Today',
      'upcoming': 'Upcoming',
      'hoursWorked': 'Hours Worked',
      'notifications': 'Notifications',
      'viewAll': 'View All',
      'noShiftsToday': 'No shifts today',
      'noUpcomingShifts': 'No upcoming shifts',
      'aiAssistant': 'AI Assistant',
      'aiReady': 'LlamaBot is ready',
      'chatWithAI': 'Chat',
      'todayShifts': 'Today',
      'upcomingShifts': 'Upcoming Shifts',
      'active': 'Active',
      'upcomingLabel': 'Upcoming',
      'completed': 'Completed',
    },
  };

  String t(String key) {
    final lang = ref.watch(localeProvider).languageCode;
    return i18n[lang]?[key] ?? i18n['en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final todayShifts = ref.watch(todayShiftsProvider);
    final totalHours = ref.watch(totalHoursProvider);
    final upcomingShifts = ref.watch(upcomingShiftsProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    final userName = authState.user?.name.split(' ').first ?? 'User';
    final initials = _getInitials(authState.user?.name ?? 'U');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context, ref, userName, initials, unreadNotifications),
                const SizedBox(height: 20),
                _buildStatsGrid(context, todayShifts.length, totalHours, upcomingShifts.length, unreadNotifications),
                const SizedBox(height: 20),
                _buildAiAssistantCard(context),
                const SizedBox(height: 24),
                _buildTodaySection(context, todayShifts),
                const SizedBox(height: 24),
                _buildUpcomingSection(context, upcomingShifts),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref, String userName, String initials, int unreadCount) {
    final currentLang = ref.watch(localeProvider).languageCode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t('greeting')} $userName',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('dashboard'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildLanguageToggle(context, ref, currentLang),
            const SizedBox(width: 8),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, size: 24),
                  onPressed: () => context.go('/notifications'),
                  color: AppTheme.textSecondary,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.coral,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unreadCount',
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
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showProfileMenu(context, ref),
              child: CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                radius: 18,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageToggle(BuildContext context, WidgetRef ref, String currentLang) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLangPill('MN', currentLang == 'mn', () => ref.read(localeProvider.notifier).setLocale('mn')),
          Container(width: 0.5, height: 20, color: const Color(0xFFE2E8F0)),
          _buildLangPill('EN', currentLang == 'en', () => ref.read(localeProvider.notifier).setLocale('en')),
        ],
      ),
    );
  }

  Widget _buildLangPill(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, int todayCount, double hours, int upcomingCount, int notificationCount) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.calendar_today,
                iconColor: AppTheme.primaryColor,
                iconBg: AppTheme.primaryColor.withValues(alpha: 0.1),
                value: '$todayCount',
                label: t('today'),
                progress: todayCount > 0 ? 1.0 : 0.0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.access_time,
                iconColor: AppTheme.teal,
                iconBg: AppTheme.teal.withValues(alpha: 0.1),
                value: '${hours.toStringAsFixed(1)}h',
                label: t('hoursWorked'),
                progress: (hours / 40).clamp(0.0, 1.0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.upcoming,
                iconColor: AppTheme.amber,
                iconBg: AppTheme.amber.withValues(alpha: 0.1),
                value: '$upcomingCount',
                label: t('upcoming'),
                progress: upcomingCount / 10,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.notifications,
                iconColor: AppTheme.coral,
                iconBg: AppTheme.coral.withValues(alpha: 0.1),
                value: '$notificationCount',
                label: t('notifications'),
                progress: notificationCount / 20,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to first available group chat or show group list
        final groups = ref.read(chatProvider).groups;
        if (groups.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GroupChatScreen(groupId: groups.first.id)),
          );
        } else {
          context.go('/group-chat');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AI Туслах',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('aiReady'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      final groups = ref.read(chatProvider).groups;
                      if (groups.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GroupChatScreen(groupId: groups.first.id),
                          ),
                        );
                      } else {
                        context.go('/group-chat');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(t('chatWithAI')),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'llama3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '🤖',
                  style: TextStyle(fontSize: 48),
                ),
              ],
            ),
          ],
        ),
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
            Text(t('todayShifts'), style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/shifts'),
              child: Text(t('viewAll')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shifts.isEmpty)
          _buildEmptyState(
            icon: Icons.event_available,
            message: t('noShiftsToday'),
          )
        else
          ...shifts.map(
            (shift) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildShiftCard(shift, showDate: false),
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
            Text(t('upcomingShifts'), style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/shifts'),
              child: Text(t('viewAll')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shifts.isEmpty)
          _buildEmptyState(
            icon: Icons.event_busy,
            message: t('noUpcomingShifts'),
          )
        else
          ...shifts.take(3).map(
            (shift) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildShiftCard(shift, showDate: true),
            ),
          ),
      ],
    );
  }

  Widget _buildShiftCard(ShiftModel shift, {required bool showDate}) {
    final isCompleted = shift.status == ShiftStatus.completed;
    final isMissed = shift.status == ShiftStatus.missed;

    Color dotColor;
    Color statusBg;
    Color statusText;
    String statusLabel;

    if (isCompleted) {
      dotColor = AppTheme.textLight;
      statusBg = AppTheme.statusCompletedBg;
      statusText = AppTheme.statusCompletedText;
      statusLabel = t('completed');
    } else if (isMissed) {
      dotColor = AppTheme.coral;
      statusBg = AppTheme.coral.withValues(alpha: 0.1);
      statusText = AppTheme.coral;
      statusLabel = 'Missed';
    } else {
      dotColor = AppTheme.amber;
      statusBg = AppTheme.statusUpcomingBg;
      statusText = AppTheme.statusUpcomingText;
      statusLabel = t('upcomingLabel');
    }

    final startTimeStr = '${shift.startTime.hour.toString().padLeft(2, '0')}:${shift.startTime.minute.toString().padLeft(2, '0')}';
    final endTimeStr = '${shift.endTime.hour.toString().padLeft(2, '0')}:${shift.endTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.role,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$startTimeStr - $endTimeStr',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (showDate) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${shift.date.year}-${shift.date.month.toString().padLeft(2, '0')}-${shift.date.day.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppTheme.textLight),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    return name.split(' ').map((part) => part[0].toUpperCase()).take(2).join();
  }

  void _showProfileMenu(BuildContext context, WidgetRef ref) {
    final user = ref.read(authProvider).user;
    final userName = user?.name ?? 'User';
    final userEmail = user?.email ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  radius: 24,
                  child: Text(
                    _getInitials(userName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon!')),
                );
              },
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.coral),
              title: const Text('Logout', style: TextStyle(color: AppTheme.coral)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
