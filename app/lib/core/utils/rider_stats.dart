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

  /// Oldest → newest, capped to the last [computeRiderStats]'s `chartLimit`
  /// rides — feeds the Rides tab's distance/speed-over-time charts, which
  /// read left-to-right chronologically rather than most-recent-first like
  /// [recentRides].
  final List<RideEntity> chartRides;

  /// EVERY ride, newest first — uncapped.
  ///
  /// [recentRides] is truncated, which is right for "here are your last few"
  /// but wrong the moment the list can be re-sorted: ordering a
  /// already-truncated list by top speed would surface the fastest of your
  /// last ten rides while calling it your fastest, which is a lie the rider
  /// can't see. Sorting reads from here and truncates afterwards.
  final List<RideEntity> allRides;

  const RiderStatsSummary({
    required this.allTimeAvgSpeedKmh,
    required this.allTimeTopSpeedKmh,
    required this.avgRidingScore,
    required this.mostUsedBike,
    required this.totalRides,
    required this.totalDistanceKm,
    required this.recentRides,
    this.chartRides = const [],
    this.allRides = const [],
  });

  static const empty = RiderStatsSummary(
    allTimeAvgSpeedKmh: 0,
    allTimeTopSpeedKmh: 0,
    avgRidingScore: 0,
    mostUsedBike: null,
    totalRides: 0,
    totalDistanceKm: 0,
    recentRides: [],
    chartRides: [],
    allRides: [],
  );
}

RiderStatsSummary computeRiderStats({
  required List<RideEntity> rides,
  required List<BikeEntity> bikes,
  int recentLimit = 10,
  int chartLimit = 20,
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
  final sortedChronologically = sortedByRecency.reversed.toList();

  return RiderStatsSummary(
    allTimeAvgSpeedKmh: avgSpeedSum / rides.length,
    allTimeTopSpeedKmh: topSpeed,
    avgRidingScore: scoreSum / rides.length,
    mostUsedBike: mostUsedBike,
    totalRides: rides.length,
    totalDistanceKm: totalDistanceKm,
    recentRides: sortedByRecency.take(recentLimit).toList(),
    allRides: sortedByRecency,
    chartRides: sortedChronologically.length > chartLimit
        ? sortedChronologically.sublist(sortedChronologically.length - chartLimit)
        : sortedChronologically,
  );
}

/// Null when no bike has any recorded rides yet — "most used" isn't a
/// meaningful answer until at least one ride exists.
BikeEntity? _mostUsedBike(List<BikeEntity> bikes) {
  if (bikes.isEmpty) return null;
  final top = bikes.reduce((a, b) => b.rideCount > a.rideCount ? b : a);
  return top.rideCount > 0 ? top : null;
}
