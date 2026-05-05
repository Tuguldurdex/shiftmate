import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as date_utils;
import '../../../../services/shift_service.dart';
import '../../../../services/user_service.dart';

class ShiftListScreen extends ConsumerStatefulWidget {
  const ShiftListScreen({super.key});

  @override
  ConsumerState<ShiftListScreen> createState() => _ShiftListScreenState();
}

class _ShiftListScreenState extends ConsumerState<ShiftListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, String> _workerNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerNames(List<String> workerIds) async {
    final shiftService = ref.read(shiftServiceProvider);
    final names = await shiftService.getWorkerNames(workerIds);
    if (mounted) {
      setState(() {
        _workerNames = names;
      });
    }
  }

  String _getWorkerNamesString(List<String> workerIds) {
    if (workerIds.isEmpty) return 'No workers assigned';
    return workerIds
        .map((id) => _workerNames[id] ?? 'Loading...')
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<String>(
      future: ref.read(userServiceProvider).getUserRole(user.uid),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data == 'admin';
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        if (isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Text(isAdmin ? 'All Shifts' : 'My Shifts'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/dashboard'),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textLight,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Past'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              isAdmin
                  ? _buildAllShifts(user.uid, true)
                  : _buildWorkerShifts(user.uid, true),
              isAdmin
                  ? _buildAllShifts(user.uid, false)
                  : _buildWorkerShifts(user.uid, false),
            ],
          ),
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  onPressed: () => context.go('/add-shift'),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

Widget _buildWorkerShifts(String userId, bool upcoming) {
    final db = FirebaseFirestore.instance;
    debugPrint('_buildWorkerShifts: Querying for worker uid: $userId');

    return FutureBuilder<QuerySnapshot>(
      future: db.collection('shifts')
          .where('assigned_workers', arrayContains: userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint('_buildWorkerShifts ERROR: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 60, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Error loading shifts: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        debugPrint('_buildWorkerShifts: Found ${docs.length} raw documents');

        // Parse shifts and sort in Dart
        final shifts = docs.map((doc) => Shift.fromDoc(doc)).toList();
        shifts.sort((a, b) => b.date.compareTo(a.date));
        debugPrint('_buildWorkerShifts: Parsed ${shifts.length} shifts');

        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);

        final filteredShifts = shifts.where((s) {
          final shiftDate = DateTime(s.date.year, s.date.month, s.date.day);
          return upcoming
              ? !shiftDate.isBefore(startOfToday)
              : shiftDate.isBefore(startOfToday);
        }).toList();

        debugPrint('_buildWorkerShifts: After filter ${upcoming ? "upcoming" : "past"}, ${filteredShifts.length} shifts');

        if (filteredShifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 80, color: AppTheme.textLight),
                const SizedBox(height: 16),
                Text(
                  upcoming 
                      ? 'No upcoming shifts assigned to you' 
                      : 'No past shifts assigned to you',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your UID: $userId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredShifts.length,
          itemBuilder: (context, index) => _buildShiftCard(filteredShifts[index], false),
        );
      },
    );
  }

  Widget _buildAllShifts(String userId, bool upcoming) {
    final shiftService = ref.read(shiftServiceProvider);

    return FutureBuilder<List<Shift>>(
      future: shiftService.getAllShifts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final shifts = snapshot.data ?? [];
        final now = DateTime.now();
        final startOfToday = DateTime(now.year, now.month, now.day);
        final filteredShifts = shifts.where((s) {
          final shiftDate = DateTime(s.date.year, s.date.month, s.date.day);
          return upcoming
              ? !shiftDate.isBefore(startOfToday)
              : shiftDate.isBefore(startOfToday);
        }).toList();

        if (filteredShifts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 80, color: AppTheme.textLight),
                const SizedBox(height: 16),
                Text(
                  upcoming ? 'No upcoming shifts' : 'No past shifts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Tap + to add a new shift',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }

        if (_workerNames.isEmpty && filteredShifts.isNotEmpty) {
          final allWorkerIds = <String>{};
          for (final shift in filteredShifts) {
            allWorkerIds.addAll(shift.assignedWorkers);
          }
          _loadWorkerNames(allWorkerIds.toList());
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredShifts.length,
          itemBuilder: (context, index) => _buildShiftCard(filteredShifts[index], true),
        );
      },
    );
  }

  Widget _buildShiftCard(Shift shift, bool showAdminControls) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shift.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: shift.status == 'confirmed'
                        ? AppTheme.accentColor
                        : AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shift.status.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppTheme.textLight),
                const SizedBox(width: 8),
                Text(date_utils.DateTimeUtils.formatDate(shift.date),
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppTheme.textLight),
                const SizedBox(width: 8),
                Text(
                  '${date_utils.DateTimeUtils.formatTime(shift.startTime)} - ${date_utils.DateTimeUtils.formatTime(shift.endTime)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                const Icon(Icons.timer, size: 16, color: AppTheme.textLight),
                const SizedBox(width: 8),
                Text('${shift.hoursWorked.toStringAsFixed(1)}h',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: AppTheme.textLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getWorkerNamesString(shift.assignedWorkers),
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (shift.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                shift.notes,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (showAdminControls) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                    onPressed: () => _showDeleteDialog(shift),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Shift shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shift'),
        content: Text('Are you sure you want to delete "${shift.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final shiftService = ref.read(shiftServiceProvider);
              await shiftService.deleteShift(shift.id);
              if (mounted) setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
