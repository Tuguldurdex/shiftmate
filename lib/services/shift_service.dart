import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shiftServiceProvider = Provider<ShiftService>((ref) => ShiftService());

class ShiftService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get shifts collection reference
  CollectionReference get _shiftsRef => _db.collection('shifts');

  // Get workers collection reference
  CollectionReference get _workersRef => _db.collection('users');

  // Get shifts assigned to a specific worker
  Future<List<Shift>> getWorkerShifts(String workerId) async {
    debugPrint('ShiftService.getWorkerShifts: Querying for workerId: $workerId');
    // Query without orderBy to avoid composite index requirement
    final snapshot = await _shiftsRef
        .where('assigned_workers', arrayContains: workerId)
        .get();
    final shifts = snapshot.docs.map((doc) => Shift.fromDoc(doc)).toList();
    // Sort by date in Dart instead of Firestore query
    shifts.sort((a, b) => b.date.compareTo(a.date));
    debugPrint('ShiftService.getWorkerShifts: Found ${shifts.length} shifts');
    return shifts;
  }

  // Get all shifts (for admins)
  Future<List<Shift>> getAllShifts() async {
    final snapshot = await _shiftsRef.get();
    final shifts = snapshot.docs.map((doc) => Shift.fromDoc(doc)).toList();
    // Sort by date in Dart instead of Firestore query
    shifts.sort((a, b) => b.date.compareTo(a.date));
    return shifts;
  }

  // Get all workers
  Future<List<WorkerProfile>> getWorkers() async {
    final snapshot = await _workersRef.where('role', isEqualTo: 'worker').get();
    final workers = snapshot.docs.map((doc) => WorkerProfile.fromDoc(doc)).toList();
    debugPrint('ShiftService.getWorkers: Found ${workers.length} workers');
    for (final w in workers) {
      debugPrint('  - Worker: ${w.id} (${w.name}, ${w.email})');
    }
    return workers;
  }

  // Create a new shift with assigned workers
  Future<DocumentReference> createShift({
    required String title,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> assignedWorkers,
    required String createdBy,
    String? notes,
  }) async {
    return await _shiftsRef.add({
      'title': title,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'assigned_workers': assignedWorkers,
      'created_by': createdBy,
      'notes': notes ?? '',
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // Update a shift
  Future<void> updateShift(String shiftId, Map<String, dynamic> data) async {
    await _shiftsRef.doc(shiftId).update(data);
  }

  // Delete a shift
  Future<void> deleteShift(String shiftId) async {
    await _shiftsRef.doc(shiftId).delete();
  }

  // Get worker name by ID
  Future<String> getWorkerName(String workerId) async {
    final doc = await _workersRef.doc(workerId).get();
    if (!doc.exists) return 'Unknown';
    return (doc.data() as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown';
  }

  // Get worker names for a list of IDs
  Future<Map<String, String>> getWorkerNames(List<String> workerIds) async {
    final names = <String, String>{};
    for (final id in workerIds) {
      names[id] = await getWorkerName(id);
    }
    return names;
  }
}

// Shift model
class Shift {
  final String id;
  final String title;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> assignedWorkers;
  final String createdBy;
  final String notes;
  final String status;
  final DateTime? createdAt;

  Shift({
    required this.id,
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.assignedWorkers,
    required this.createdBy,
    required this.notes,
    required this.status,
    this.createdAt,
  });

  factory Shift.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final shift = Shift(
      id: doc.id,
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: (data['start_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (data['end_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedWorkers: (data['assigned_workers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdBy: data['created_by'] ?? '',
      notes: data['notes'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : null,
    );
    debugPrint('Shift.fromDoc: Loaded shift "${shift.title}" with assigned_workers: ${shift.assignedWorkers}');
    return shift;
  }

  Duration get duration => endTime.difference(startTime);
  
  double get hoursWorked => duration.inMinutes / 60;
}

// Worker profile model
class WorkerProfile {
  final String id;
  final String name;
  final String email;

  WorkerProfile({
    required this.id,
    required this.name,
    required this.email,
  });

  factory WorkerProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    debugPrint('WorkerProfile.fromDoc: doc.id = ${doc.id}, data = $data');
    return WorkerProfile(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
    );
  }
}

// Providers
final workerShiftsProvider = FutureProvider.family<List<Shift>, String>((ref, userId) {
  return ref.watch(shiftServiceProvider).getWorkerShifts(userId);
});

final allShiftsProvider = FutureProvider<List<Shift>>((ref) {
  return ref.watch(shiftServiceProvider).getAllShifts();
});

final workersListProvider = FutureProvider<List<WorkerProfile>>((ref) {
  return ref.watch(shiftServiceProvider).getWorkers();
});