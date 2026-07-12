import '../../domain/entities/ride_entity.dart';

class RideModel {
  static RideEntity fromMap(Map<String, dynamic> m) => RideEntity(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        bikeId: m['bike_id'] as String,
        startTime: DateTime.parse(m['start_time'] as String),
        endTime: m['end_time'] != null ? DateTime.parse(m['end_time'] as String) : null,
        distanceM: (m['distance_m'] as num).toDouble(),
        avgSpeedMs: m['avg_speed_ms'] != null ? (m['avg_speed_ms'] as num).toDouble() : null,
        maxSpeedMs: m['max_speed_ms'] != null ? (m['max_speed_ms'] as num).toDouble() : null,
        durationSeconds: m['duration_s'] as int?,
        hardBrakeCount: m['hard_brake_count'] as int,
        rapidAccelCount: m['rapid_accel_count'] as int,
        highJerkCount: m['high_jerk_count'] as int,
        status: _statusFromString(m['status'] as String),
        mapSnapshotPath: m['map_snapshot_path'] as String?,
      );

  static Map<String, dynamic> toMap(RideEntity e) => {
        'id': e.id,
        'user_id': e.userId,
        'bike_id': e.bikeId,
        'start_time': e.startTime.toIso8601String(),
        'end_time': e.endTime?.toIso8601String(),
        'distance_m': e.distanceM,
        'avg_speed_ms': e.avgSpeedMs,
        'max_speed_ms': e.maxSpeedMs,
        'duration_s': e.durationSeconds,
        'hard_brake_count': e.hardBrakeCount,
        'rapid_accel_count': e.rapidAccelCount,
        'high_jerk_count': e.highJerkCount,
        'status': e.status.name,
        'map_snapshot_path': e.mapSnapshotPath,
        'synced': 0,
        'created_at': e.startTime.toIso8601String(),
      };

  static RideStatus _statusFromString(String s) =>
      RideStatus.values.firstWhere((e) => e.name == s, orElse: () => RideStatus.active);
}
