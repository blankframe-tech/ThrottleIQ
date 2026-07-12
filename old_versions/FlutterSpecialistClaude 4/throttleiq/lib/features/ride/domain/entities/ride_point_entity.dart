class RidePointEntity {
  final String rideId;
  final DateTime timestamp;
  final double lat;
  final double lng;
  final double speedMs;
  final double? acceleration;
  final double? jerk;
  final double? altitudeM;

  const RidePointEntity({
    required this.rideId,
    required this.timestamp,
    required this.lat,
    required this.lng,
    required this.speedMs,
    this.acceleration,
    this.jerk,
    this.altitudeM,
  });
}
