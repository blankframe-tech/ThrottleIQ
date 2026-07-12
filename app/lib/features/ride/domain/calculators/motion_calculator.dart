import 'dart:math';
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

    final accel = (currentSpeedMs - prev.speedMs) / deltaT;
    final jerk = prev.acceleration != null ? (accel - prev.acceleration!) / deltaT : null;
    final dist = _haversine(prev.lat, prev.lng, currentLat, currentLng);

    return MotionResult(
      speedMs: currentSpeedMs,
      acceleration: accel,
      jerk: jerk,
      distanceDeltaM: dist,
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dPhi = (lat2 - lat1) * pi / 180;
    final dLambda = (lon2 - lon1) * pi / 180;
    final a = sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
