/// Ride basics: distance, speed and duration.
library;

import '../../../ride/domain/entities/ride_entity.dart';
import '../ride_analytics.dart';

abstract final class RideBasicsCharts {
  static const distancePerRide = PerRideChart(
    'distancePerRide',
    value: _distanceKm,
  );
  static const weeklyDistance = _WeeklyDistanceChart();
  static const avgSpeed = PerRideChart(
    'avgSpeed',
    value: _avgKmh,
    aggregation: Aggregation.mean,
  );
  static const topSpeed = PerRideChart(
    'topSpeed',
    value: _maxKmh,
    aggregation: Aggregation.mean,
  );
  static const rideDuration = PerRideChart('rideDuration', value: _durationMin);

  static const List<AnalyticsChart> all = [
    distancePerRide,
    weeklyDistance,
    avgSpeed,
    topSpeed,
    rideDuration,
  ];
}

double? _distanceKm(RideEntity r) => r.distanceKm;
double? _avgKmh(RideEntity r) => r.avgSpeedMs == null ? null : r.avgSpeedKmh;
double? _maxKmh(RideEntity r) => r.maxSpeedMs == null ? null : r.maxSpeedKmh;
double? _durationMin(RideEntity r) {
  final d = r.durationSeconds;
  return d == null ? null : d / 60;
}

/// Distance per calendar week (Monday start), oldest first, including weeks
/// with no riding, for the [weeks] weeks ending with the week of [now].
/// When [weeks] is null the series starts at the first ride's week.
List<AnalyticsPoint> weeklyDistance(
  List<RideEntity> rides, {
  required DateTime now,
  int? weeks,
}) {
  final lastWeek = weekStartOf(now);
  DateTime firstWeek;
  if (weeks != null) {
    firstWeek = DateTime(
      lastWeek.year,
      lastWeek.month,
      lastWeek.day - 7 * (weeks - 1),
    );
  } else {
    if (rides.isEmpty) return const [];
    final earliest =
        rides.map((r) => r.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
    firstWeek = weekStartOf(earliest);
  }
  final totals = <String, double>{};
  for (final r in rides) {
    final k = isoDayKey(weekStartOf(r.startTime));
    totals[k] = (totals[k] ?? 0) + r.distanceKm;
  }
  final out = <AnalyticsPoint>[];
  for (var w = firstWeek;
      !w.isAfter(lastWeek);
      w = DateTime(w.year, w.month, w.day + 7)) {
    final k = isoDayKey(w);
    out.add(AnalyticsPoint(key: k, date: w, value: totals[k] ?? 0));
  }
  return out;
}

class _WeeklyDistanceChart extends RideChart {
  const _WeeklyDistanceChart() : super('weeklyDistance');

  @override
  List<AnalyticsPoint> series(
    List<RideEntity> rides, {
    required DateTime now,
    AnalyticsWindow? window,
  }) {
    if (window == null) return weeklyDistance(rides, now: now);
    final weeks =
        (weekStartOf(now).difference(weekStartOf(window.start)).inDays ~/ 7) +
            1;
    return weeklyDistance(rides, now: now, weeks: weeks);
  }

  /// The last [previewWeekCount] weeks.
  @override
  List<AnalyticsPoint> previewSeries(
    List<RideEntity> rides, {
    required DateTime now,
  }) =>
      weeklyDistance(rides, now: now, weeks: previewWeekCount);
}
