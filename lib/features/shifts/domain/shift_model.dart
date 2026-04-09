enum ShiftStatus { upcoming, completed, missed }

class ShiftModel {
  final String id;
  final String userId;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String role;
  final ShiftStatus status;
  final String? notes;
  final DateTime createdAt;

  ShiftModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.role,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      role: json['role'] as String,
      status: ShiftStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ShiftStatus.upcoming,
      ),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'role': role,
      'status': status.name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Duration get duration => endTime.difference(startTime);

  double get hoursWorked => duration.inMinutes / 60;

  ShiftModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    String? role,
    ShiftStatus? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      role: role ?? this.role,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
