import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../features/shifts/domain/shift_model.dart';

class ClockInService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference get _clockInsRef => _db.collection('clock_ins');

  Future<ClockInEvent?> clockIn({
    required String shiftId,
    required String workerId,
    required Position position,
    required WorkLocation workLocation,
  }) async {
    final distance = _calculateDistance(
      position.latitude,
      position.longitude,
      workLocation.latitude,
      workLocation.longitude,
    );

    final isOnSite = distance <= workLocation.radiusMeters;

    final clockInEvent = ClockInEvent(
      id: _uuid.v4(),
      shiftId: shiftId,
      workerId: workerId,
      timestamp: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      distanceFromZone: distance,
      isOnSite: isOnSite,
    );

    await _clockInsRef.doc(clockInEvent.id).set(clockInEvent.toJson());

    return clockInEvent;
  }

  Future<List<ClockInEvent>> getClockInsForShift(String shiftId) async {
    final snapshot = await _clockInsRef
        .where('shift_id', isEqualTo: shiftId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => ClockInEvent.fromJson(doc.data() as Map<String, dynamic>)).toList();
  }

  Future<List<ClockInEvent>> getClockInsForWorker(String workerId) async {
    final snapshot = await _clockInsRef
        .where('worker_id', isEqualTo: workerId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => ClockInEvent.fromJson(doc.data() as Map<String, dynamic>)).toList();
  }

  Future<ClockInEvent?> getTodayClockIn(String shiftId, String workerId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _clockInsRef
        .where('shift_id', isEqualTo: shiftId)
        .where('worker_id', isEqualTo: workerId)
        .where('timestamp', isGreaterThan: startOfDay.toIso8601String())
        .where('timestamp', isLessThan: endOfDay.toIso8601String())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ClockInEvent.fromJson(snapshot.docs.first.data() as Map<String, dynamic>);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) * _sin(dLon / 2) * _sin(dLon / 2);
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  double _sin(double x) => _taylorSin(x);
  double _cos(double x) => _taylorCos(x);
  double _sqrt(double x) => x > 0 ? _newtonSqrt(x) : 0;
  double _atan2(double y, double x) => _approximateAtan2(y, x);

  double _taylorSin(double x) {
    x = x % (2 * 3.141592653589793);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _taylorCos(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _newtonSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _approximateAtan2(double y, double x) {
    if (x == 0) {
      if (y > 0) return 3.141592653589793 / 2;
      if (y < 0) return -3.141592653589793 / 2;
      return 0;
    }
    double atan = _approximateAtan(y / x);
    if (x < 0) {
      if (y >= 0) return atan + 3.141592653589793;
      return atan - 3.141592653589793;
    }
    return atan;
  }

  double _approximateAtan(double x) {
    if (x > 1) return 3.141592653589793 / 2 - _approximateAtan(1 / x);
    if (x < -1) return -3.141592653589793 / 2 - _approximateAtan(1 / x);
    double result = x;
    double term = x;
    for (int i = 1; i <= 20; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }
}

final clockInServiceProvider = Provider<ClockInService>((ref) => ClockInService());

final clockInHistoryProvider = FutureProvider.family<List<ClockInEvent>, String>((ref, shiftId) async {
  return ref.read(clockInServiceProvider).getClockInsForShift(shiftId);
});

final todayClockInProvider = FutureProvider.family<ClockInEvent?, String>((ref, shiftId) async {
  return ref.read(clockInServiceProvider).getTodayClockIn(shiftId, '');
});