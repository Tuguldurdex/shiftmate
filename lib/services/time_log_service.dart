import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final timeLogServiceProvider = Provider<TimeLogService>((ref) => TimeLogService());

class TimeLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _ref => _db.collection('time_logs');
  CollectionReference get _usersRef => _db.collection('users');

  // Create time log entry
  Future<DocumentReference> createTimeLog({
    required String workerId,
    required String workerEmail,
    required String workerName,
    required DateTime date,
    required DateTime clockIn,
    required DateTime clockOut,
    String? note,
  }) async {
    final hoursWorked = clockOut.difference(clockIn).inMinutes / 60.0;
    
    debugPrint('TimeLogService.createTimeLog: workerId=$workerId, date=$date, hours=$hoursWorked');
    
    return await _ref.add({
      'worker_id': workerId,
      'worker_email': workerEmail,
      'worker_name': workerName,
      'date': date,
      'clock_in': clockIn,
      'clock_out': clockOut,
      'hours_worked': hoursWorked,
      'note': note ?? '',
      'status': 'pending',
      'submitted_at': FieldValue.serverTimestamp(),
    });
  }

  // Get worker's time logs
  Future<List<TimeLogEntry>> getWorkerTimeLogs(String workerId) async {
    debugPrint('TimeLogService.getWorkerTimeLogs: workerId=$workerId');
    final snapshot = await _ref.where('worker_id', isEqualTo: workerId).get();
    final logs = snapshot.docs.map((doc) => TimeLogEntry.fromDoc(doc)).toList();
    logs.sort((a, b) => b.date.compareTo(a.date));
    debugPrint('TimeLogService.getWorkerTimeLogs: found ${logs.length} logs');
    return logs;
  }

  // Get ALL time logs (for admin)
  Future<List<TimeLogEntry>> getAllTimeLogs() async {
    debugPrint('TimeLogService.getAllTimeLogs: fetching all');
    final snapshot = await _ref.get();
    final logs = snapshot.docs.map((doc) => TimeLogEntry.fromDoc(doc)).toList();
    logs.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return logs;
  }

  // Get pending logs (for admin)
  Future<List<TimeLogEntry>> getPendingTimeLogs() async {
    final snapshot = await _ref.where('status', isEqualTo: 'pending').get();
    final logs = snapshot.docs.map((doc) => TimeLogEntry.fromDoc(doc)).toList();
    logs.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return logs;
  }

  // Approve time log
  Future<void> approve(String logId, String adminId) async {
    debugPrint('TimeLogService.approve: logId=$logId, adminId=$adminId');
    await _ref.doc(logId).update({
      'status': 'approved',
      'reviewed_by': adminId,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  // Reject time log
  Future<void> reject(String logId, String adminId, String reason) async {
    debugPrint('TimeLogService.reject: logId=$logId, adminId=$adminId, reason=$reason');
    await _ref.doc(logId).update({
      'status': 'rejected',
      'reviewed_by': adminId,
      'rejection_reason': reason,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  // Get worker name by ID
  Future<String> getWorkerName(String workerId) async {
    final doc = await _usersRef.doc(workerId).get();
    if (!doc.exists) return 'Unknown';
    return (doc.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown';
  }

  // Calculate weekly hours
  double calculateWeeklyHours(List<TimeLogEntry> logs) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekLogs = logs.where((log) {
      return log.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
             log.date.isBefore(now.add(const Duration(days: 1)));
    });
    return weekLogs.fold(0.0, (total, log) => total + log.hoursWorked);
  }
}

class TimeLogEntry {
  final String id;
  final String workerId;
  final String workerEmail;
  final String workerName;
  final DateTime date;
  final DateTime clockIn;
  final DateTime clockOut;
  final double hoursWorked;
  final String note;
  final String status;
  final DateTime submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  TimeLogEntry({
    required this.id,
    required this.workerId,
    required this.workerEmail,
    required this.workerName,
    required this.date,
    required this.clockIn,
    required this.clockOut,
    required this.hoursWorked,
    required this.note,
    required this.status,
    required this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory TimeLogEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimeLogEntry(
      id: doc.id,
      workerId: data['worker_id'] ?? '',
      workerEmail: data['worker_email'] ?? '',
      workerName: data['worker_name'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clockIn: (data['clock_in'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clockOut: (data['clock_out'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hoursWorked: (data['hours_worked'] as num?)?.toDouble() ?? 0.0,
      note: data['note'] ?? '',
      status: data['status'] ?? 'pending',
      submittedAt: (data['submitted_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: data['reviewed_by'],
      reviewedAt: data['reviewed_at'] != null ? (data['reviewed_at'] as Timestamp).toDate() : null,
      rejectionReason: data['rejection_reason'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

// Providers
final workerTimeLogsProvider = FutureProvider.family<List<TimeLogEntry>, String>((ref, workerId) {
  return ref.watch(timeLogServiceProvider).getWorkerTimeLogs(workerId);
});

final allTimeLogsProvider = FutureProvider<List<TimeLogEntry>>((ref) {
  return ref.watch(timeLogServiceProvider).getAllTimeLogs();
});

final pendingTimeLogsProvider = FutureProvider<List<TimeLogEntry>>((ref) {
  return ref.watch(timeLogServiceProvider).getPendingTimeLogs();
});