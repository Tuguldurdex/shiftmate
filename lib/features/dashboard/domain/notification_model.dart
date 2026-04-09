import '../../shifts/domain/shift_model.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String? shiftId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.shiftId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      shiftId: json['shift_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'shift_id': shiftId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? shiftId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      shiftId: shiftId ?? this.shiftId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static NotificationModel fromShift(ShiftModel shift, String message) {
    return NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: shift.userId,
      title: 'Shift Reminder',
      message: message,
      shiftId: shift.id,
      createdAt: DateTime.now(),
    );
  }
}
