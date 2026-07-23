/// A single fused snapshot of the vehicle's motion at one instant —
/// the unifying output everything else (recording, event detection, future
/// ride analytics) should read from instead of computing speed/accel/heading
/// independently in multiple places.
///
/// `estimatedRoad` is always null for now — reserved for a future
/// map-matching layer, not built yet. `accelerationMs2` is still the
/// GPS-speed-derivative value (see [VehicleStateEstimator]'s doc comment for
/// why it isn't IMU-fused yet); the IMU is used here for heading, motion
/// classification, and confidence instead.
class VehicleState {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? altitude;

  final double speedMs;
  final double accelerationMs2;
  final double? headingDeg;
  final double? angularVelocityRadS;

  final int confidence; // 0-100
  final int imuQuality; // 0-100, a sub-score folded into confidence

  final bool isMoving;
  final bool isStopped;
  final bool isCornering;
  final bool isBraking;
  final bool isAccelerating;

  final double gpsAccuracyM;
  final String? estimatedRoad;

  const VehicleState({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.altitude,
    required this.speedMs,
    required this.accelerationMs2,
    this.headingDeg,
    this.angularVelocityRadS,
    required this.confidence,
    required this.imuQuality,
    required this.isMoving,
    required this.isStopped,
    required this.isCornering,
    required this.isBraking,
    required this.isAccelerating,
    required this.gpsAccuracyM,
    this.estimatedRoad,
  });
}
