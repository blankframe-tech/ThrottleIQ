import '../../features/garage/domain/entities/bike_entity.dart';
import '../../features/ride/domain/entities/ride_entity.dart';
import 'riding_score.dart';

/// All-time rider stats, computed purely from local ride/bike records —
/// backs the Rider Stats Hub (replaces the old placeholder AI tab).
class RiderStatsSummary {
  final double allTimeAvgSpeedKmh;
  final double allTimeTopSpeedKmh;
  final double avgRidingScore;
  final BikeEntity? mostUsedBike;
  final int totalRides;
  final double totalDistanceKm;
  final List<RideEntity> recentRides;

  const RiderStatsSummary({
    required this.allTimeAvgSpeedKmh,
    required this.allTimeTopSpeedKmh,
    required this.avgRidingScore,
    required this.mostUsedBike,
    required this.totalRides,
    required this.totalDistanceKm,
    required this.recentRides,
  });

  static const empty = RiderStatsSummary(
    allTimeAvgSpeedKmh: 0,
    allTimeTopSpeedKmh: 0,
    avgRidingScore: 0,
    mostUsedBike: null,
    totalRides: 0,
    totalDistanceKm: 0,
    recentRides: [],
  );
}

RiderStatsSummary computeRiderStats({
  required List<RideEntity> rides,
  required List<BikeEntity> bikes,
  int recentLimit = 10,
}) {
  final mostUsedBike = _mostUsedBike(bikes);

  if (rides.isEmpty) {
    return RiderStatsSummary(
      allTimeAvgSpeedKmh: 0,
      allTimeTopSpeedKmh: 0,
      avgRidingScore: 0,
      mostUsedBike: mostUsedBike,
      totalRides: 0,
      totalDistanceKm: 0,
      recentRides: const [],
    );
  }

  final avgSpeedSum = rides.fold<double>(0, (sum, r) => sum + r.avgSpeedKmh);
  final topSpeed = rides.fold<double>(
      0, (max, r) => r.maxSpeedKmh > max ? r.maxSpeedKmh : max);
  final scoreSum = rides.fold<int>(
      0,
      (sum, r) =>
          sum +
          computeRidingScore(
            hardBrakes: r.hardBrakeCount,
            rapidAccel: r.rapidAccelCount,
            highJerk: r.highJerkCount,
          ));
  final totalDistanceKm = rides.fold<double>(0, (sum, r) => sum + r.distanceKm);

  // Sort defensively rather than trusting caller order, so this stays a
  // pure function of its inputs regardless of what order they arrive in.
  final sortedByRecency = [...rides]
    ..sort((a, b) => b.startTime.compareTo(a.startTime));

  return RiderStatsSummary(
    allTimeAvgSpeedKmh: avgSpeedSum / rides.length,
    allTimeTopSpeedKmh: topSpeed,
    avgRidingScore: scoreSum / rides.length,
    mostUsedBike: mostUsedBike,
    totalRides: rides.length,
    totalDistanceKm: totalDistanceKm,
    recentRides: sortedByRecency.take(recentLimit).toList(),
  );
}

/// Null when no bike has any recorded rides yet — "most used" isn't a
/// meaningful answer until at least one ride exists.
BikeEntity? _mostUsedBike(List<BikeEntity> bikes) {
  if (bikes.isEmpty) return null;
  final top = bikes.reduce((a, b) => b.rideCount > a.rideCount ? b : a);
  return top.rideCount > 0 ? top : null;
}
