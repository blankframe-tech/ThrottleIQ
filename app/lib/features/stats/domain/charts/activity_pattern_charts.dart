/// Activity patterns: the riding-days calendar, hour of day and weekday.
///
/// All three compare periods on ride count.
library;

import '../../../ride/domain/entities/ride_entity.dart';
import '../ride_analytics.dart';

abstract final class ActivityPatternCharts {
  static const activityCalendar = _ActivityCalendarChart();
  static const hourOfDay = _BucketChart(
    'hourOfDay',
    ridesByHour,
    peakHourInsight,
  );
  static const weekday = _BucketChart(
    'weekday',
    ridesByWeekday,
    peakWeekdayInsight,
  );

  static const List<AnalyticsChart> all = [
    activityCalendar,
    hourOfDay,
    weekday,
  ];
}

/// Current streak ([AnalyticsInsight.value]) and longest
/// ([AnalyticsInsight.value2]), in days.
const streakInsight = InsightKind('streak');

/// The busiest start hour, 0–23, in [AnalyticsInsight.value].
const peakHourInsight = InsightKind('peakHour');

/// The busiest ISO weekday in [AnalyticsInsight.value].
const peakWeekdayInsight = InsightKind('peakWeekday');

/// Distance per calendar day from [from] to [to] inclusive, zero days
/// included, oldest first. [AnalyticsPoint.secondary] is the day's ride
/// count.
List<AnalyticsPoint> dailyDistance(
  List<RideEntity> rides, {
  required DateTime from,
  required DateTime to,
}) {
  final start = dayOf(from);
  final end = dayOf(to);
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final r in rides) {
    final k = isoDayKey(dayOf(r.startTime));
    totals[k] = (totals[k] ?? 0) + r.distanceKm;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final out = <AnalyticsPoint>[];
  for (var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)) {
    final k = isoDayKey(d);
    out.add(
      AnalyticsPoint(
        key: k,
        date: d,
        value: totals[k] ?? 0,
        secondary: (counts[k] ?? 0).toDouble(),
      ),
    );
  }
  return out;
}

/// Consecutive riding days: the run ending today (or yesterday, so a streak
/// isn't "broken" before today's ride) and the longest run ever.
({int current, int longest}) ridingStreaks(
  List<RideEntity> rides, {
  required DateTime now,
}) {
  if (rides.isEmpty) return (current: 0, longest: 0);
  final days = rides.map((r) => dayOf(r.startTime)).toSet().toList()..sort();
  var longest = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    final expected = DateTime(
      days[i - 1].year,
      days[i - 1].month,
      days[i - 1].day + 1,
    );
    run = days[i] == expected ? run + 1 : 1;
    if (run > longest) longest = run;
  }
  final today = dayOf(now);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final daySet = days.toSet();
  var cursor = daySet.contains(today) ? today : yesterday;
  var current = 0;
  while (daySet.contains(cursor)) {
    current++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return (current: current, longest: longest);
}

/// Ride count per start hour, 24 buckets (0–23). [AnalyticsPoint.secondary]
/// is the bucket's distance in km.
List<AnalyticsPoint> ridesByHour(List<RideEntity> rides) {
  final counts = List<int>.filled(24, 0);
  final km = List<double>.filled(24, 0);
  for (final r in rides) {
    counts[r.startTime.hour]++;
    km[r.startTime.hour] += r.distanceKm;
  }
  return [
    for (var h = 0; h < 24; h++)
      AnalyticsPoint(
        key: 'h$h',
        bucket: h,
        value: counts[h].toDouble(),
        secondary: km[h],
      ),
  ];
}

/// Ride count per weekday, Monday first. [AnalyticsPoint.secondary] is the
/// bucket's distance in km.
List<AnalyticsPoint> ridesByWeekday(List<RideEntity> rides) {
  final counts = List<int>.filled(7, 0);
  final km = List<double>.filled(7, 0);
  for (final r in rides) {
    counts[r.startTime.weekday - 1]++;
    km[r.startTime.weekday - 1] += r.distanceKm;
  }
  return [
    for (var d = 1; d <= 7; d++)
      AnalyticsPoint(
        key: 'd$d',
        bucket: d,
        value: counts[d - 1].toDouble(),
        secondary: km[d - 1],
      ),
  ];
}

class _ActivityCalendarChart extends RideChart {
  const _ActivityCalendarChart() : super('activityCalendar');

  @override
  List<AnalyticsPoint> series(
    List<RideEntity> rides, {
    required DateTime now,
    AnalyticsWindow? window,
  }) {
    if (window != null) {
      return dailyDistance(
        rides,
        from: window.start,
        to: window.end.subtract(const Duration(days: 1)),
      );
    }
    if (rides.isEmpty) return const [];
    final earliest =
        rides.map((r) => r.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
    return dailyDistance(rides, from: earliest, to: now);
  }

  /// The last [previewWeekCount] weeks, Monday first.
  @override
  List<AnalyticsPoint> previewSeries(
    List<RideEntity> rides, {
    required DateTime now,
  }) {
    final firstWeek = weekStartOf(now);
    final from = DateTime(
      firstWeek.year,
      firstWeek.month,
      firstWeek.day - 7 * (previewWeekCount - 1),
    );
    return dailyDistance(rides, from: from, to: now);
  }

  @override
  double? aggregateRides(List<RideEntity> rides) => rides.length.toDouble();

  @override
  List<AnalyticsInsight> shapeInsights(
    List<RideEntity> rides,
    List<AnalyticsPoint> series, {
    required DateTime now,
  }) {
    final s = ridingStreaks(rides, now: now);
    return [
      AnalyticsInsight(
        streakInsight,
        value: s.current.toDouble(),
        value2: s.longest.toDouble(),
      ),
    ];
  }
}

/// Ride counts in fixed buckets (hours, weekdays); the insight names the
/// busiest bucket.
class _BucketChart extends RideChart {
  final List<AnalyticsPoint> Function(List<RideEntity> rides) buckets;
  final InsightKind peakKind;

  const _BucketChart(super.id, this.buckets, this.peakKind);

  @override
  List<AnalyticsPoint> series(
    List<RideEntity> rides, {
    required DateTime now,
    AnalyticsWindow? window,
  }) =>
      buckets(rides);

  @override
  double? aggregateRides(List<RideEntity> rides) => rides.length.toDouble();

  @override
  List<AnalyticsInsight> shapeInsights(
    List<RideEntity> rides,
    List<AnalyticsPoint> series, {
    required DateTime now,
  }) {
    final peak = series.reduce((a, b) => b.value > a.value ? b : a);
    return [
      AnalyticsInsight(
        peakKind,
        value: peak.bucket?.toDouble(),
        value2: peak.value,
      ),
    ];
  }
}
