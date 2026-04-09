import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/shifts/domain/shift_model.dart';
import '../../services/mock_data_service.dart';
import '../../core/utils/validation_utils.dart';
import 'providers.dart';

final shiftsProvider = StateNotifierProvider<ShiftsNotifier, List<ShiftModel>>((
  ref,
) {
  final authState = ref.watch(authProvider);
  return ShiftsNotifier(authState.user?.id ?? '');
});

class ShiftsNotifier extends StateNotifier<List<ShiftModel>> {
  final String _userId;
  final MockDataService _mockDataService = MockDataService();

  ShiftsNotifier(this._userId) : super([]) {
    _loadShifts();
  }

  void _loadShifts() {
    if (_userId.isNotEmpty) {
      state = _mockDataService.getMockShifts(_userId);
    }
  }

  Future<bool> addShift({
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    required String role,
    String? notes,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final newShift = ShiftModel(
        id: ValidationUtils.generateId(),
        userId: _userId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        role: role,
        status: ShiftStatus.upcoming,
        notes: notes,
        createdAt: DateTime.now(),
      );

      state = [...state, newShift];
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateShift(ShiftModel shift) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.map((s) => s.id == shift.id ? shift : s).toList();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteShift(String shiftId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.where((s) => s.id != shiftId).toList();
      return true;
    } catch (e) {
      return false;
    }
  }

  List<ShiftModel> getShiftsByDate(DateTime date) {
    return state
        .where(
          (shift) =>
              shift.date.year == date.year &&
              shift.date.month == date.month &&
              shift.date.day == date.day,
        )
        .toList();
  }

  List<ShiftModel> getUpcomingShifts() {
    return state.where((shift) => shift.status == ShiftStatus.upcoming).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<ShiftModel> getTodayShifts() {
    final today = DateTime.now();
    return getShiftsByDate(today);
  }

  double getTotalHoursWorked() {
    return _mockDataService.calculateTotalHours(state);
  }
}

final todayShiftsProvider = Provider<List<ShiftModel>>((ref) {
  final shifts = ref.watch(shiftsProvider);
  final today = DateTime.now();
  return shifts
      .where(
        (shift) =>
            shift.date.year == today.year &&
            shift.date.month == today.month &&
            shift.date.day == today.day,
      )
      .toList();
});

final totalHoursProvider = Provider<double>((ref) {
  final shifts = ref.watch(shiftsProvider);
  return shifts
      .where((s) => s.status == ShiftStatus.completed)
      .fold(0.0, (sum, shift) => sum + shift.hoursWorked);
});

final upcomingShiftsProvider = Provider<List<ShiftModel>>((ref) {
  final shifts = ref.watch(shiftsProvider);
  final now = DateTime.now();
  return shifts
      .where(
        (s) =>
            s.status == ShiftStatus.upcoming &&
            s.date.isAfter(now.subtract(const Duration(days: 1))),
      )
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
});
