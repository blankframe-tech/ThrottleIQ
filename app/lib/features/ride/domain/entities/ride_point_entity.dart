class RidePointEntity {
  final String rideId;
  final DateTime timestamp;
  final double lat;
  final double lng;
  final double speedMs;
  final double? acceleration;
  final double? jerk;
  final double? altitudeM;
  final String periodType;
  final double? accuracyM;

  /// Fused heading in degrees from true north, from [VehicleStateEstimator].
  /// Null until the estimator has a usable GPS course to blend from.
  final double? headingDeg;

  /// 0-100 — how much to trust this point (see [VehicleStateEstimator]).
  final int? confidence;

  /// 0-100 sub-score of [confidence], IMU-signal-quality only.
  final int? imuQuality;

  /// Whether sustained gyro yaw-rate indicated cornering at this point.
  /// `isBraking`/`isAccelerating`/`isMoving`/`isStopped` are deliberately
  /// NOT persisted here — they're exactly reproducible from `acceleration`/
  /// `periodType`, which are already stored.
  final bool? isCornering;

  const RidePointEntity({
    required this.rideId,
    required this.timestamp,
    required this.lat,
    required this.lng,
    required this.speedMs,
    this.acceleration,
    this.jerk,
    this.altitudeM,
    this.periodType = 'moving',
    this.accuracyM,
    this.headingDeg,
    this.confidence,
    this.imuQuality,
    this.isCornering,
  });
}
