import 'dart:math';
import '../features/auth/domain/user_model.dart';
import '../features/shifts/domain/shift_model.dart';
import '../features/dashboard/domain/notification_model.dart';

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal();

  final Random _random = Random();

  UserModel getMockUser() {
    return UserModel(
      id: 'user_001',
      email: 'john.doe@company.com',
      name: 'John Doe',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    );
  }

  List<ShiftModel> getMockShifts(String userId) {
    final List<ShiftModel> shifts = [];
    final roles = ['Manager', 'Cashier', 'Server', 'Kitchen Staff', 'Security'];

    for (int i = -10; i <= 30; i++) {
      final date = DateTime.now().add(Duration(days: i));

      if (i < 0) {
        shifts.add(
          ShiftModel(
            id: 'shift_${-i}',
            userId: userId,
            date: date,
            startTime: DateTime(date.year, date.month, date.day, 9, 0),
            endTime: DateTime(date.year, date.month, date.day, 17, 0),
            role: roles[_random.nextInt(roles.length)],
            status: ShiftStatus.completed,
            notes: i % 3 == 0 ? 'Regular shift' : null,
            createdAt: date.subtract(const Duration(days: 7)),
          ),
        );
      } else if (i == 0) {
        shifts.add(
          ShiftModel(
            id: 'shift_0',
            userId: userId,
            date: date,
            startTime: DateTime(date.year, date.month, date.day, 9, 0),
            endTime: DateTime(date.year, date.month, date.day, 17, 0),
            role: roles[_random.nextInt(roles.length)],
            status: ShiftStatus.upcoming,
            notes: 'Today\'s shift',
            createdAt: date.subtract(const Duration(days: 7)),
          ),
        );
      } else {
        shifts.add(
          ShiftModel(
            id: 'shift_$i',
            userId: userId,
            date: date,
            startTime: DateTime(date.year, date.month, date.day, 9, 0),
            endTime: DateTime(date.year, date.month, date.day, 17, 0),
            role: roles[_random.nextInt(roles.length)],
            status: ShiftStatus.upcoming,
            notes: i % 5 == 0 ? 'Important shift' : null,
            createdAt: date.subtract(const Duration(days: 7)),
          ),
        );
      }
    }

    return shifts;
  }

  List<NotificationModel> getMockNotifications(String userId) {
    final now = DateTime.now();
    return [
      NotificationModel(
        id: 'notif_1',
        userId: userId,
        title: 'Shift Reminder',
        message: 'You have a shift tomorrow at 9:00 AM',
        shiftId: 'shift_1',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      NotificationModel(
        id: 'notif_2',
        userId: userId,
        title: 'Schedule Update',
        message: 'Your shift on Friday has been updated',
        shiftId: 'shift_5',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      NotificationModel(
        id: 'notif_3',
        userId: userId,
        title: 'Weekly Summary',
        message: 'You worked 40 hours this week',
        isRead: false,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  double calculateTotalHours(
    List<ShiftModel> shifts, {
    DateTime? from,
    DateTime? to,
  }) {
    double total = 0;
    for (final shift in shifts) {
      if (from != null && shift.date.isBefore(from)) continue;
      if (to != null && shift.date.isAfter(to)) continue;
      if (shift.status == ShiftStatus.completed) {
        total += shift.hoursWorked;
      }
    }
    return total;
  }
}
