/// Bikes and records: distance per bike, and the longest rides.
library;

import '../../../ride/domain/entities/ride_entity.dart';
import '../ride_analytics.dart';

abstract final class BikeCharts {
  static const distanceByBike = _DistanceByBikeChart();
  static const longestRides = _LongestRidesChart();

  static const List<AnalyticsChart> all = [distanceByBike, longestRides];
}

/// The top bike ([AnalyticsInsight.key]) and its share of the distance in
/// percent ([AnalyticsInsight.value]).
const topBikeInsight = InsightKind('topBike');

/// The longest ride's distance ([AnalyticsInsight.value]) and date.
const longestRideInsight = InsightKind('longestRide');

/// Distance per bike, largest first. [AnalyticsPoint.key] is the bike id;
/// [AnalyticsPoint.secondary] is that bike's ride count.
List<AnalyticsPoint> distanceByBike(List<RideEntity> rides) {
  final km = <String, double>{};
  final counts = <String, int>{};
  for (final r in rides) {
    km[r.bikeId] = (km[r.bikeId] ?? 0) + r.distanceKm;
    counts[r.bikeId] = (counts[r.bikeId] ?? 0) + 1;
  }
  final out = [
    for (final e in km.entries)
      AnalyticsPoint(
        key: e.key,
        value: e.value,
        secondary: counts[e.key]!.toDouble(),
      ),
  ]..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return out;
}

/// The [limit] longest rides by distance, longest first.
List<AnalyticsPoint> longestRides(List<RideEntity> rides, {int limit = 5}) {
  final sorted = [...rides]..sort((a, b) {
      final c = b.distanceM.compareTo(a.distanceM);
      return c != 0 ? c : b.startTime.compareTo(a.startTime);
    });
  return [
    for (final r in sorted.take(limit))
      AnalyticsPoint(key: r.id, date: r.startTime, value: r.distanceKm),
  ];
}

class _DistanceByBikeChart extends RideChart {
  const _DistanceByBikeChart() : super('distanceByBike');

  @override
  List<AnalyticsPoint> series(
    List<RideEntity> rides, {
    required DateTime now,
    AnalyticsWindow? window,
  }) =>
      distanceByBike(rides);

  @override
  List<AnalyticsInsight> shapeInsights(
    List<RideEntity> rides,
    List<AnalyticsPoint> series, {
    required DateTime now,
  }) {
    final total = series.fold<double>(0, (s, p) => s + p.value);
    return [
      if (total > 0)
        AnalyticsInsight(
          topBikeInsight,
          key: series.first.key,
          value: series.first.value / total * 100,
        ),
    ];
  }
}

class _LongestRidesChart extends RideChart {
  const _LongestRidesChart() : super('longestRides');

  @override
  List<AnalyticsPoint> series(
    List<RideEntity> rides, {
    required DateTime now,
    AnalyticsWindow? window,
  }) =>
      longestRides(rides);

  /// The single longest ride.
  @override
  double? aggregateRides(List<RideEntity> rides) =>
      rides.map((r) => r.distanceKm).reduce((a, b) => a > b ? a : b);

  @override
  List<AnalyticsInsight> shapeInsights(
    List<RideEntity> rides,
    List<AnalyticsPoint> series, {
    required DateTime now,
  }) =>
      [
        AnalyticsInsight(
          longestRideInsight,
          value: series.first.value,
          date: series.first.date,
        ),
      ];
}
