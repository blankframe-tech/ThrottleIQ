import 'dart:math' as math;
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
    final deltaT = currentTime.difference(prev.timestamp).inMilliseconds / 1000.0;
    if (deltaT <= 0) {
      return MotionResult(speedMs: currentSpeedMs, distanceDeltaM: 0);
    }

    final dtForDeriv = math.max(0.1, deltaT);
    final accel = (currentSpeedMs - prev.speedMs) / dtForDeriv;
    final jerk = prev.acceleration != null ? (accel - prev.acceleration!) / dtForDeriv : null;
    final dist = haversineMeters(prev.lat, prev.lng, currentLat, currentLng);

    return MotionResult(
      speedMs: currentSpeedMs,
      acceleration: accel,
      jerk: jerk,
      distanceDeltaM: dist,
    );
  }
}
