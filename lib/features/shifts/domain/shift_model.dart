enum ShiftStatus { upcoming, completed, missed }

class WorkLocation {
  final double latitude;
  final double longitude;
  final int radiusMeters;

  WorkLocation({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory WorkLocation.fromJson(Map<String, dynamic> json) {
    return WorkLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: json['radius_meters'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
    };
  }
}

class ClockInEvent {
  final String id;
  final String shiftId;
  final String workerId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double distanceFromZone;
  final bool isOnSite;

  ClockInEvent({
    required this.id,
    required this.shiftId,
    required this.workerId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.distanceFromZone,
    required this.isOnSite,
  });

  factory ClockInEvent.fromJson(Map<String, dynamic> json) {
    return ClockInEvent(
      id: json['id'] as String,
      shiftId: json['shift_id'] as String,
      workerId: json['worker_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceFromZone: (json['distance_from_zone'] as num).toDouble(),
      isOnSite: json['is_on_site'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shift_id': shiftId,
      'worker_id': workerId,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'distance_from_zone': distanceFromZone,
      'is_on_site': isOnSite,
    };
  }
}

class ShiftModel {
  final String id;
  final String userId;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final String role;
  final ShiftStatus status;
  final String? notes;
  final WorkLocation? workLocation;
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
    this.workLocation,
    required this.createdAt,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    WorkLocation? wl;
    if (json['work_location'] != null) {
      wl = WorkLocation.fromJson(json['work_location'] as Map<String, dynamic>);
    }
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
      workLocation: wl,
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
      'work_location': workLocation?.toJson(),
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
    WorkLocation? workLocation,
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
      workLocation: workLocation ?? this.workLocation,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
