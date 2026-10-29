import 'package:throttleiq/core/utils/geo_math.dart';

import '../entities/ride_point_entity.dart';

class MotionResult {
  final double speedMs;
  final double? acceleration;
  final double? jerk;
  final double distanceDeltaM;

  const MotionResult({
    required this.speedMs,
    this.acceleration,
    this.jerk,
    required this.distanceDeltaM,
  });
}

class MotionCalculator {
  MotionResult calculate({
    required RidePointEntity prev,
    required double currentSpeedMs,
    required double currentLat,
    required double currentLng,
    required DateTime currentTime,
  }) {
    final deltaT =
        currentTime.difference(prev.timestamp).inMilliseconds / 1000.0;
    if (deltaT <= 0) {
      return MotionResult(speedMs: currentSpeedMs, distanceDeltaM: 0);
    }

    final dist = haversineMeters(prev.lat, prev.lng, currentLat, currentLng);
    // Under 0.1 s, dividing by deltaT (twice for jerk) turns GPS noise into
    // huge spikes; same floor as evaluateFix (issue #57).
    if (deltaT < 0.1) {
      return MotionResult(speedMs: currentSpeedMs, distanceDeltaM: dist);
    }

    final accel = (currentSpeedMs - prev.speedMs) / deltaT;
    final jerk = prev.acceleration != null
        ? (accel - prev.acceleration!) / deltaT
        : null;

    return MotionResult(
      speedMs: currentSpeedMs,
      acceleration: accel,
      jerk: jerk,
      distanceDeltaM: dist,
    );
  }
}
