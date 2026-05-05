import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers.dart';
import '../../../../services/time_log_service.dart';
import '../../../../services/user_service.dart';
import '../../../../core/utils/date_utils.dart' as date_utils;

class TimeLogRequestScreen extends ConsumerStatefulWidget {
  const TimeLogRequestScreen({super.key});

  @override
  ConsumerState<TimeLogRequestScreen> createState() => _TimeLogRequestScreenState();
}

class _TimeLogRequestScreenState extends ConsumerState<TimeLogRequestScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _clockInTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _clockOutTime = const TimeOfDay(hour: 17, minute: 0);
  final _noteController = TextEditingController();
  bool _isLoading = false;
  late TabController _tabController;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _filterStatus = 'all';
            break;
          case 1:
            _filterStatus = 'pending';
            break;
          case 2:
            _filterStatus = 'approved';
            break;
          case 3:
            _filterStatus = 'rejected';
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(bool isClockIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isClockIn ? _clockInTime : _clockOutTime,
    );
    if (picked != null) {
      setState(() {
        if (isClockIn) {
          _clockInTime = picked;
        } else {
          _clockOutTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final workerName = await ref.read(userServiceProvider).getUser(user.uid);

    final clockIn = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _clockInTime.hour, _clockInTime.minute);
    final clockOut = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _clockOutTime.hour, _clockOutTime.minute);

    try {
      await ref.read(timeLogServiceProvider).createTimeLog(
        workerId: user.uid,
        workerEmail: user.email ?? '',
        workerName: workerName?.name ?? user.email?.split('@').first ?? 'Unknown',
        date: _selectedDate,
        clockIn: clockIn,
        clockOut: clockOut,
        note: _noteController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Time log submitted for review!'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        setState(() {
          _noteController.clear();
          _selectedDate = DateTime.now();
          _clockInTime = const TimeOfDay(hour: 9, minute: 0);
          _clockOutTime = const TimeOfDay(hour: 17, minute: 0);
        });
      }
    } catch (e) {
      debugPrint('Error submitting time log: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = ref.watch(isManagerProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Time Logs' : 'My Time Logs'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/dashboard')),
        bottom: isAdmin
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              )
            : null,
      ),
      body: isAdmin ? _buildAdminView(user) : _buildWorkerView(user),
      floatingActionButton: isAdmin ? null : FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildWorkerView(User user) {
    final timeLogsAsync = ref.watch(workerTimeLogsProvider(user.uid));

    return timeLogsAsync.when(
      data: (logs) {
        final weeklyHours = ref.read(timeLogServiceProvider).calculateWeeklyHours(logs);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: AppTheme.primaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text('This Week', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text('${weeklyHours.toStringAsFixed(1)} hours', 
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Submit New Time Log'),
                const SizedBox(height: 16),
                _buildDatePicker(),
                const SizedBox(height: 16),
                _buildTimePickers(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'Any notes for this shift...',
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Submit Time Log'),
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('My Time Log History'),
                const SizedBox(height: 16),
                if (logs.isEmpty)
                  _buildEmptyState('No time logs submitted yet')
                else
                  Column(children: logs.map((log) => _buildTimeLogCard(log, false)).toList()),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildAdminView(User user) {
    final allLogsAsync = ref.watch(allTimeLogsProvider);

    return allLogsAsync.when(
      data: (logs) {
        final filtered = _filterStatus == 'all' 
            ? logs 
            : logs.where((log) => log.status == _filterStatus).toList();
        
        // Sort pending first
        filtered.sort((a, b) {
          if (a.isPending && !b.isPending) return -1;
          if (!a.isPending && b.isPending) return 1;
          return b.submittedAt.compareTo(a.submittedAt);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildTimeLogCard(filtered[index], true),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionTitle('New Time Log'),
                const SizedBox(height: 16),
                _buildDatePicker(),
                const SizedBox(height: 16),
                _buildTimePickers(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    _submit();
                    Navigator.pop(context);
                  },
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: Theme.of(context).textTheme.titleLarge);

  Widget _buildDatePicker() => InkWell(
    onTap: _selectDate,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text(date_utils.DateTimeUtils.formatDate(_selectedDate)),
        const Spacer(),
        const Icon(Icons.chevron_right),
      ]),
    ),
  );

  Widget _buildTimePickers() => Row(
    children: [
      Expanded(child: _buildTimePicker('Clock In', _clockInTime, true)),
      const SizedBox(width: 12),
      Expanded(child: _buildTimePicker('Clock Out', _clockOutTime, false)),
    ],
  );

  Widget _buildTimePicker(String label, TimeOfDay time, bool isClockIn) => InkWell(
    onTap: () => _selectTime(isClockIn),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(time.format(context), style: Theme.of(context).textTheme.titleMedium),
      ]),
    ),
  );

  Widget _buildEmptyState(String message) => Container(
    padding: const EdgeInsets.all(32),
    child: Column(children: [
      Icon(Icons.history, size: 48, color: AppTheme.textLight),
      const SizedBox(height: 12),
      Text(message, style: Theme.of(context).textTheme.bodyMedium),
    ]),
  );

  Widget _buildTimeLogCard(TimeLogEntry log, bool isAdmin) {
    Color statusColor;
    switch (log.status) {
      case 'pending':
        statusColor = AppTheme.warningColor;
        break;
      case 'approved':
        statusColor = AppTheme.accentColor;
        break;
      case 'rejected':
        statusColor = AppTheme.errorColor;
        break;
      default:
        statusColor = AppTheme.textLight;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isAdmin && log.isPending ? () => _showReviewDialog(log) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAdmin) Text(log.workerName, style: Theme.of(context).textTheme.titleMedium),
                        Text(date_utils.DateTimeUtils.formatDate(log.date)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(log.status.toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: AppTheme.textLight),
                  const SizedBox(width: 8),
                  Text('${date_utils.DateTimeUtils.formatTime(log.clockIn)} - ${date_utils.DateTimeUtils.formatTime(log.clockOut)}'),
                  const SizedBox(width: 16),
                  const Icon(Icons.timer, size: 16, color: AppTheme.textLight),
                  const SizedBox(width: 8),
                  Text('${log.hoursWorked.toStringAsFixed(1)} hours'),
                ],
              ),
              if (log.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(log.note, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ],
              if (log.isRejected && log.rejectionReason != null) ...[
                const SizedBox(height: 8),
                Text('Rejection reason: ${log.rejectionReason}', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.errorColor)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDialog(TimeLogEntry log) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Review Time Log', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Worker: ${log.workerName}'),
            Text('Date: ${date_utils.DateTimeUtils.formatDate(log.date)}'),
            Text('Time: ${date_utils.DateTimeUtils.formatTime(log.clockIn)} - ${date_utils.DateTimeUtils.formatTime(log.clockOut)}'),
            Text('Hours: ${log.hoursWorked.toStringAsFixed(1)}'),
            if (log.note.isNotEmpty) Text('Note: ${log.note}'),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () => _approveLog(log),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
                child: const Text('APPROVE'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () => _showRejectReasonDialog(log),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
                child: const Text('REJECT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveLog(TimeLogEntry log) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await ref.read(timeLogServiceProvider).approve(log.id, user.uid);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Time log approved!'), backgroundColor: AppTheme.accentColor),
        );
        ref.invalidate(allTimeLogsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showRejectReasonDialog(TimeLogEntry log) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Time Log'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Rejection reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _rejectLog(log, reasonController.text);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectLog(TimeLogEntry log, String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await ref.read(timeLogServiceProvider).reject(log.id, user.uid, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Time log rejected!'), backgroundColor: AppTheme.errorColor),
        );
        ref.invalidate(allTimeLogsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}