import '../../domain/entities/ride_entity.dart';

class RideModel {
  static RideEntity fromMap(Map<String, dynamic> m) => RideEntity(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        bikeId: m['bike_id'] as String,
        startTime: DateTime.parse(m['start_time'] as String),
        endTime: m['end_time'] != null
            ? DateTime.parse(m['end_time'] as String)
            : null,
        distanceM: (m['distance_m'] as num).toDouble(),
        avgSpeedMs: m['avg_speed_ms'] != null
            ? (m['avg_speed_ms'] as num).toDouble()
            : null,
        maxSpeedMs: m['max_speed_ms'] != null
            ? (m['max_speed_ms'] as num).toDouble()
            : null,
        durationSeconds: m['duration_s'] as int?,
        movingSeconds: m['moving_s'] as int?,
        hardBrakeCount: m['hard_brake_count'] as int,
        rapidAccelCount: m['rapid_accel_count'] as int,
        highJerkCount: m['high_jerk_count'] as int,
        // Null on rides finalized before schema v25: unknown, not zero.
        overspeedCount: (m['overspeed_count'] as num?)?.toInt(),
        // Null on rides finalized before schema v26 (and elevation on rides
        // the backfill couldn't measure): unknown, not zero.
        maxLeanDeg: (m['max_lean_deg'] as num?)?.toDouble(),
        peakLateralG: (m['peak_lateral_g'] as num?)?.toDouble(),
        peakAccelG: (m['peak_accel_g'] as num?)?.toDouble(),
        peakBrakeG: (m['peak_brake_g'] as num?)?.toDouble(),
        elevationGainM: (m['elevation_gain_m'] as num?)?.toDouble(),
        elevationLossM: (m['elevation_loss_m'] as num?)?.toDouble(),
        status: _statusFromString(m['status'] as String),
        mapSnapshotPath: m['map_snapshot_path'] as String?,
        // Null-tolerant rather than `as int`: rides written before schema v11
        // have no value here, and a ride recorded by the rider is the correct
        // reading of "this column didn't exist yet".
        isAuto: (m['is_auto'] as int?) == 1,
        bikeConfidence:
            BikeAttributionConfidence.fromName(m['bike_confidence'] as String?),
        // Null on every ride recorded before schema v17, and on every ride
        // that wasn't following a saved route — which is the honest reading
        // of "this column didn't exist yet" either way.
        routeId: m['route_id'] as String?,
        routeName: m['route_name'] as String?,
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
        'moving_s': e.movingSeconds,
        'hard_brake_count': e.hardBrakeCount,
        'rapid_accel_count': e.rapidAccelCount,
        'high_jerk_count': e.highJerkCount,
        'overspeed_count': e.overspeedCount,
        'max_lean_deg': e.maxLeanDeg,
        'peak_lateral_g': e.peakLateralG,
        'peak_accel_g': e.peakAccelG,
        'peak_brake_g': e.peakBrakeG,
        'elevation_gain_m': e.elevationGainM,
        'elevation_loss_m': e.elevationLossM,
        'status': e.status.name,
        'map_snapshot_path': e.mapSnapshotPath,
        'is_auto': e.isAuto ? 1 : 0,
        'bike_confidence': e.bikeConfidence.name,
        'route_id': e.routeId,
        'route_name': e.routeName,
        'synced': 0,
        'created_at': e.startTime.toIso8601String(),
      };

  static RideStatus _statusFromString(String s) => RideStatus.values
      .firstWhere((e) => e.name == s, orElse: () => RideStatus.active);
}
