import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as date_utils;
import '../../../../shifts_provider.dart';
import '../../domain/shift_model.dart';
import '../widgets/shift_card.dart';

class ShiftListScreen extends ConsumerStatefulWidget {
  const ShiftListScreen({super.key});

  @override
  ConsumerState<ShiftListScreen> createState() => _ShiftListScreenState();
}

class _ShiftListScreenState extends ConsumerState<ShiftListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shifts = ref.watch(shiftsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('My Shifts'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textLight,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Calendar'),
            Tab(text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllShifts(shifts),
          _buildCalendarView(shifts),
          _buildStatsView(shifts),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/add-shift'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllShifts(List<ShiftModel> shifts) {
    if (shifts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: AppTheme.textLight),
            const SizedBox(height: 16),
            Text(
              'No shifts scheduled',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add a new shift',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final sortedShifts = List<ShiftModel>.from(shifts)
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedShifts.length,
      itemBuilder: (context, index) {
        final shift = sortedShifts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ShiftCard(
            shift: shift,
            showDate: true,
            onTap: () => context.go('/edit-shift/${shift.id}'),
            onEdit: () => context.go('/edit-shift/${shift.id}'),
            onDelete: () => _showDeleteDialog(shift),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView(List<ShiftModel> shifts) {
    final daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final firstDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    final startingWeekday = firstDayOfMonth.weekday;

    final shiftsThisMonth = shifts
        .where(
          (s) =>
              s.date.year == _selectedDate.year &&
              s.date.month == _selectedDate.month,
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month - 1,
                    );
                  });
                },
              ),
              Text(
                date_utils.DateTimeUtils.formatDate(
                  _selectedDate,
                ).substring(0, 8),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (day) => SizedBox(
                    width: 40,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: 42,
              itemBuilder: (context, index) {
                final dayNumber = index - (startingWeekday - 1);
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox();
                }

                final date = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  dayNumber,
                );
                final hasShift = shiftsThisMonth.any(
                  (s) =>
                      s.date.year == date.year &&
                      s.date.month == date.month &&
                      s.date.day == date.day,
                );
                final isToday = date_utils.DateTimeUtils.isToday(date);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primaryColor
                          : hasShift
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? null
                          : Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text(
                        '$dayNumber',
                        style: TextStyle(
                          color: isToday ? Colors.white : AppTheme.textPrimary,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (shiftsThisMonth.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${shiftsThisMonth.length} shifts this month',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
      ],
    );
  }

  Widget _buildStatsView(List<ShiftModel> shifts) {
    final completedShifts = shifts
        .where((s) => s.status == ShiftStatus.completed)
        .toList();
    final upcomingShifts = shifts
        .where((s) => s.status == ShiftStatus.upcoming)
        .toList();
    final missedShifts = shifts
        .where((s) => s.status == ShiftStatus.missed)
        .toList();

    final totalHours = completedShifts.fold<double>(
      0,
      (sum, s) => sum + s.hoursWorked,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Total Hours Worked',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalHours.toStringAsFixed(1)}h',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  '${completedShifts.length}',
                  AppTheme.accentColor,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Upcoming',
                  '${upcomingShifts.length}',
                  AppTheme.primaryColor,
                  Icons.upcoming,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Missed',
                  '${missedShifts.length}',
                  AppTheme.errorColor,
                  Icons.cancel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total',
                  '${shifts.length}',
                  AppTheme.textSecondary,
                  Icons.list,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(ShiftModel shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text(
          'Are you sure you want to delete the ${shift.role} shift on ${date_utils.DateTimeUtils.formatDate(shift.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(shiftsProvider.notifier).deleteShift(shift.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
