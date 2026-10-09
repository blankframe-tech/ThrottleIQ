/// Pure metric computation behind the Rides tab's analytics charts.
///
/// Everything here is a function of a list of [RideEntity] plus an explicit
/// `now`, so it can be unit-tested without a clock, SQLite or Flutter (see
/// `test/features/stats/ride_analytics_test.dart`). The presentation layer
/// only turns these numbers into charts, labels and CSV cells.
///
/// Only data the app actually records is used: the ride row's distance,
/// speeds, duration, moving seconds, the harsh-event counters, the schema v26
/// lean/g/elevation figures, start time and bike. Metrics a ride doesn't carry (e.g. moving time on rides
/// finalized before it was tracked) are skipped for that ride rather than
/// guessed as zero.
///
/// The four fuel charts ([isFuelChart]) are the exception: they read the
/// rider's logged fill-ups ([FuelLogEntity]) instead of rides — see the
/// "Fuel charts" section at the end.
library;

import '../../../core/utils/riding_score.dart';
import '../../maintenance/domain/calculators/fuel_economy.dart';
import '../../maintenance/domain/entities/fuel_log.dart';
import '../../ride/domain/entities/ride_entity.dart';

/// Every chart on the analytics list, in display order.
enum AnalyticsChart {
  distancePerRide,
  weeklyDistance,
  avgSpeed,
  topSpeed,
  rideDuration,
  movingVsStopped,
  jamTime,
  ridingScore,
  hardBraking,
  rapidAccel,
  overspeed,
  maxLean,
  peakG,
  elevationGain,
  activityCalendar,
  hourOfDay,
  weekday,
  distanceByBike,
  longestRides,
  fuelSpend,
  fuelEfficiency,
  fuelCostPerKm,
  fuelLiters,
}

/// How a chart's points combine into one number when two periods are
/// compared (the "trend vs previous period" figure).
enum Aggregation { sum, mean }

/// The time windows offered in the chart detail view.
enum AnalyticsRange { days7, days30, days90, year, all }

extension AnalyticsRangeX on AnalyticsRange {
  /// Window length, or null for [AnalyticsRange.all].
  Duration? get length => switch (this) {
        AnalyticsRange.days7 => const Duration(days: 7),
        AnalyticsRange.days30 => const Duration(days: 30),
        AnalyticsRange.days90 => const Duration(days: 90),
        AnalyticsRange.year => const Duration(days: 365),
        AnalyticsRange.all => null,
      };
}

/// One value on a chart.
///
/// [key] is stable and unique within a series: a ride id, an ISO day, a
/// bucket number or a bike id. [secondary] carries the second stack of a
/// two-part bar (stopped minutes in moving-vs-stopped) or a companion figure
/// (peak acceleration g beside lateral g, elevation loss beside gain);
/// [tertiary] a third (peak braking g).
class AnalyticsPoint {
  final String key;
  final DateTime? date;
  final double value;
  final double? secondary;
  final double? tertiary;

  /// Hour (0–23) or ISO weekday (1 = Monday … 7 = Sunday) for bucketed
  /// charts; null otherwise.
  final int? bucket;

  const AnalyticsPoint({
    required this.key,
    required this.value,
    this.date,
    this.secondary,
    this.tertiary,
    this.bucket,
  });

  @override
  String toString() =>
      'AnalyticsPoint($key, $value${secondary == null ? '' : '/$secondary'})';
}

/// min / max / avg / total over a series' values.
class MetricSummary {
  final double min;
  final double max;
  final double avg;
  final double total;
  final int count;

  const MetricSummary({
    required this.min,
    required this.max,
    required this.avg,
    required this.total,
    required this.count,
  });

  static const empty =
      MetricSummary(min: 0, max: 0, avg: 0, total: 0, count: 0);

  bool get isEmpty => count == 0;

  factory MetricSummary.of(Iterable<double> values) {
    var count = 0;
    var total = 0.0;
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (final v in values) {
      count++;
      total += v;
      if (v < min) min = v;
      if (v > max) max = v;
    }
    if (count == 0) return empty;
    return MetricSummary(
        min: min, max: max, avg: total / count, total: total, count: count);
  }

  double aggregate(Aggregation a) => a == Aggregation.sum ? total : avg;
}

// ─── Per-ride metrics ──────────────────────────────────────────────────────

/// Seconds the ride spent stopped while recording, or null when unknown.
int? stoppedSeconds(RideEntity r) => r.jamSeconds;

/// Share of the ride clock spent moving, 0–100, or null when unknown.
double? movingSharePercent(RideEntity r) {
  final d = r.durationSeconds;
  final m = r.movingSeconds;
  if (d == null || m == null || d <= 0) return null;
  final share = m / d * 100;
  return share.clamp(0, 100).toDouble();
}

int rideScore(RideEntity r) => computeRidingScore(
      hardBrakes: r.hardBrakeCount,
      rapidAccel: r.rapidAccelCount,
      highJerk: r.highJerkCount,
    );

/// The per-ride value a chart plots, or null when this ride doesn't carry it
/// (or the chart isn't a per-ride chart).
double? perRideValue(AnalyticsChart chart, RideEntity r) {
  switch (chart) {
    case AnalyticsChart.distancePerRide:
      return r.distanceKm;
    case AnalyticsChart.avgSpeed:
      return r.avgSpeedMs == null ? null : r.avgSpeedKmh;
    case AnalyticsChart.topSpeed:
      return r.maxSpeedMs == null ? null : r.maxSpeedKmh;
    case AnalyticsChart.rideDuration:
      final d = r.durationSeconds;
      return d == null ? null : d / 60;
    case AnalyticsChart.movingVsStopped:
      return movingSharePercent(r);
    case AnalyticsChart.jamTime:
      final s = stoppedSeconds(r);
      return s == null ? null : s / 60;
    case AnalyticsChart.ridingScore:
      return rideScore(r).toDouble();
    case AnalyticsChart.hardBraking:
      return r.hardBrakeCount.toDouble();
    case AnalyticsChart.rapidAccel:
      return r.rapidAccelCount.toDouble();
    case AnalyticsChart.overspeed:
      // Null on rides recorded before it was counted (schema v25).
      return r.overspeedCount?.toDouble();
    // Null on rides recorded before schema v26 (elevation: unless backfilled).
    case AnalyticsChart.maxLean:
      return r.maxLeanDeg;
    case AnalyticsChart.peakG:
      return r.peakLateralG;
    case AnalyticsChart.elevationGain:
      return r.elevationGainM;
    case AnalyticsChart.weeklyDistance:
    case AnalyticsChart.activityCalendar:
    case AnalyticsChart.hourOfDay:
    case AnalyticsChart.weekday:
    case AnalyticsChart.distanceByBike:
    case AnalyticsChart.longestRides:
    case AnalyticsChart.fuelSpend:
    case AnalyticsChart.fuelEfficiency:
    case AnalyticsChart.fuelCostPerKm:
    case AnalyticsChart.fuelLiters:
      return null;
  }
}

bool isPerRideChart(AnalyticsChart c) => switch (c) {
      AnalyticsChart.distancePerRide ||
      AnalyticsChart.avgSpeed ||
      AnalyticsChart.topSpeed ||
      AnalyticsChart.rideDuration ||
      AnalyticsChart.movingVsStopped ||
      AnalyticsChart.jamTime ||
      AnalyticsChart.ridingScore ||
      AnalyticsChart.hardBraking ||
      AnalyticsChart.rapidAccel ||
      AnalyticsChart.overspeed ||
      AnalyticsChart.maxLean ||
      AnalyticsChart.peakG ||
      AnalyticsChart.elevationGain =>
        true,
      _ => false,
    };

Aggregation aggregationFor(AnalyticsChart c) => switch (c) {
      AnalyticsChart.avgSpeed ||
      AnalyticsChart.topSpeed ||
      AnalyticsChart.movingVsStopped ||
      AnalyticsChart.ridingScore ||
      AnalyticsChart.maxLean ||
      AnalyticsChart.peakG ||
      AnalyticsChart.fuelEfficiency ||
      AnalyticsChart.fuelCostPerKm =>
        Aggregation.mean,
      _ => Aggregation.sum,
    };

/// Per-ride series, oldest first. Rides missing the metric are skipped.
List<AnalyticsPoint> perRideSeries(
    AnalyticsChart chart, List<RideEntity> rides) {
  final sorted = _chronological(rides);
  final out = <AnalyticsPoint>[];
  for (final r in sorted) {
    final v = perRideValue(chart, r);
    if (v == null) continue;
    double? secondary;
    double? tertiary;
    if (chart == AnalyticsChart.movingVsStopped) {
      // value = moving share; secondary = stopped minutes, so the table and
      // CSV can show both halves of the bar.
      final s = stoppedSeconds(r);
      secondary = s == null ? null : s / 60;
    } else if (chart == AnalyticsChart.peakG) {
      // value = lateral; the longitudinal peaks ride along for the table.
      secondary = r.peakAccelG;
      tertiary = r.peakBrakeG;
    } else if (chart == AnalyticsChart.elevationGain) {
      secondary = r.elevationLossM;
    }
    out.add(AnalyticsPoint(
        key: r.id,
        date: r.startTime,
        value: v,
        secondary: secondary,
        tertiary: tertiary));
  }
  return out;
}

/// Moving and stopped minutes of a ride, for the stacked bar. Null when
/// either is unknown.
({double movingMin, double stoppedMin})? movingStoppedMinutes(RideEntity r) {
  final m = r.movingSeconds;
  final s = stoppedSeconds(r);
  if (m == null || s == null) return null;
  return (movingMin: m / 60, stoppedMin: s / 60);
}

// ─── Calendar metrics ──────────────────────────────────────────────────────

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Monday of the week containing [t], at local midnight.
DateTime weekStartOf(DateTime t) {
  final d = dayOf(t);
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Distance per calendar week (Monday start), oldest first, including weeks
/// with no riding, for the [weeks] weeks ending with the week of [now].
/// When [weeks] is null the series starts at the first ride's week.
List<AnalyticsPoint> weeklyDistance(List<RideEntity> rides,
    {required DateTime now, int? weeks}) {
  final lastWeek = weekStartOf(now);
  DateTime firstWeek;
  if (weeks != null) {
    firstWeek =
        DateTime(lastWeek.year, lastWeek.month, lastWeek.day - 7 * (weeks - 1));
  } else {
    if (rides.isEmpty) return const [];
    final earliest =
        rides.map((r) => r.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
    firstWeek = weekStartOf(earliest);
  }
  final totals = <String, double>{};
  for (final r in rides) {
    final k = _isoDay(weekStartOf(r.startTime));
    totals[k] = (totals[k] ?? 0) + r.distanceKm;
  }
  final out = <AnalyticsPoint>[];
  for (var w = firstWeek;
      !w.isAfter(lastWeek);
      w = DateTime(w.year, w.month, w.day + 7)) {
    final k = _isoDay(w);
    out.add(AnalyticsPoint(key: k, date: w, value: totals[k] ?? 0));
  }
  return out;
}

/// Distance per calendar day from [from] to [to] inclusive, zero days
/// included, oldest first.
List<AnalyticsPoint> dailyDistance(List<RideEntity> rides,
    {required DateTime from, required DateTime to}) {
  final start = dayOf(from);
  final end = dayOf(to);
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final r in rides) {
    final k = _isoDay(dayOf(r.startTime));
    totals[k] = (totals[k] ?? 0) + r.distanceKm;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final out = <AnalyticsPoint>[];
  for (var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)) {
    final k = _isoDay(d);
    out.add(AnalyticsPoint(
      key: k,
      date: d,
      value: totals[k] ?? 0,
      secondary: (counts[k] ?? 0).toDouble(),
    ));
  }
  return out;
}

/// Consecutive riding days: the run ending today (or yesterday, so a streak
/// isn't "broken" before today's ride) and the longest run ever.
({int current, int longest}) ridingStreaks(List<RideEntity> rides,
    {required DateTime now}) {
  if (rides.isEmpty) return (current: 0, longest: 0);
  final days = rides.map((r) => dayOf(r.startTime)).toSet().toList()..sort();
  var longest = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    final expected =
        DateTime(days[i - 1].year, days[i - 1].month, days[i - 1].day + 1);
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
          key: 'h$h', bucket: h, value: counts[h].toDouble(), secondary: km[h]),
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
          secondary: km[d - 1]),
  ];
}

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
          key: e.key, value: e.value, secondary: counts[e.key]!.toDouble()),
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

// ─── Ranges, series and trends ─────────────────────────────────────────────

/// `[start, end)` of [range] ending at [now]; null for
/// [AnalyticsRange.all].
({DateTime start, DateTime end})? rangeWindow(
    AnalyticsRange range, DateTime now) {
  final len = range.length;
  if (len == null) return null;
  final end = DateTime(now.year, now.month, now.day + 1);
  final start = DateTime(end.year, end.month, end.day - len.inDays);
  return (start: start, end: end);
}

/// The window immediately before [range]'s; null for [AnalyticsRange.all].
({DateTime start, DateTime end})? previousRangeWindow(
    AnalyticsRange range, DateTime now) {
  final w = rangeWindow(range, now);
  if (w == null) return null;
  final days = range.length!.inDays;
  return (
    start: DateTime(w.start.year, w.start.month, w.start.day - days),
    end: w.start,
  );
}

List<RideEntity> ridesInWindow(
    List<RideEntity> rides, ({DateTime start, DateTime end})? w) {
  if (w == null) return rides;
  return rides
      .where(
          (r) => !r.startTime.isBefore(w.start) && r.startTime.isBefore(w.end))
      .toList();
}

List<RideEntity> ridesInRange(
        List<RideEntity> rides, AnalyticsRange range, DateTime now) =>
    ridesInWindow(rides, rangeWindow(range, now));

/// The series [chart] plots for [rides] (already filtered to a range).
///
/// [window] bounds the calendar charts (weekly distance, riding days) so
/// empty weeks/days at either end of the range still show; when null they
/// span first ride → [now].
List<AnalyticsPoint> buildSeries(
  AnalyticsChart chart,
  List<RideEntity> rides, {
  required DateTime now,
  ({DateTime start, DateTime end})? window,
}) {
  if (isPerRideChart(chart)) return perRideSeries(chart, rides);
  switch (chart) {
    case AnalyticsChart.weeklyDistance:
      if (window == null) return weeklyDistance(rides, now: now);
      final weeks =
          (weekStartOf(now).difference(weekStartOf(window.start)).inDays ~/ 7) +
              1;
      return weeklyDistance(rides, now: now, weeks: weeks);
    case AnalyticsChart.activityCalendar:
      if (window != null) {
        return dailyDistance(rides,
            from: window.start,
            to: window.end.subtract(const Duration(days: 1)));
      }
      if (rides.isEmpty) return const [];
      final earliest =
          rides.map((r) => r.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
      return dailyDistance(rides, from: earliest, to: now);
    case AnalyticsChart.hourOfDay:
      return ridesByHour(rides);
    case AnalyticsChart.weekday:
      return ridesByWeekday(rides);
    case AnalyticsChart.distanceByBike:
      return distanceByBike(rides);
    case AnalyticsChart.longestRides:
      return longestRides(rides);
    default:
      return const [];
  }
}

/// How many rides / weeks the compact list cards show.
const int previewRideCount = 20;
const int previewWeekCount = 12;

/// The series a chart's compact card shows: the last [previewRideCount]
/// rides for per-ride charts, the last [previewWeekCount] weeks for the
/// calendar charts, and all rides for the bucketed/ranked ones.
List<AnalyticsPoint> buildPreviewSeries(
  AnalyticsChart chart,
  List<RideEntity> rides, {
  required DateTime now,
}) {
  if (isPerRideChart(chart)) {
    final s = perRideSeries(chart, rides);
    return s.length > previewRideCount
        ? s.sublist(s.length - previewRideCount)
        : s;
  }
  final firstWeek = weekStartOf(now);
  final from = DateTime(firstWeek.year, firstWeek.month,
      firstWeek.day - 7 * (previewWeekCount - 1));
  return switch (chart) {
    AnalyticsChart.weeklyDistance =>
      weeklyDistance(rides, now: now, weeks: previewWeekCount),
    AnalyticsChart.activityCalendar =>
      dailyDistance(rides, from: from, to: now),
    _ => buildSeries(chart, rides, now: now),
  };
}

/// The number two periods are compared on: per-ride charts aggregate their
/// values (sum or mean), calendar charts total their distance, and the
/// bucketed/ranked charts compare ride counts or distance.
double? periodAggregate(AnalyticsChart chart, List<RideEntity> rides) {
  // Fuel charts compare fill-ups, not rides: see [fuelPeriodAggregate].
  if (rides.isEmpty || isFuelChart(chart)) return null;
  if (isPerRideChart(chart)) {
    final s = MetricSummary.of(perRideSeries(chart, rides).map((p) => p.value));
    if (s.isEmpty) return null;
    return s.aggregate(aggregationFor(chart));
  }
  return switch (chart) {
    AnalyticsChart.hourOfDay ||
    AnalyticsChart.weekday ||
    AnalyticsChart.activityCalendar =>
      rides.length.toDouble(),
    AnalyticsChart.longestRides =>
      rides.map((r) => r.distanceKm).reduce((a, b) => a > b ? a : b),
    _ => rides.fold<double>(0, (s, r) => s + r.distanceKm),
  };
}

/// Percentage change from [previous] to [current]; null when there's no
/// honest baseline (no previous data, or a zero previous value).
double? trendPercent(double? current, double? previous) {
  if (current == null || previous == null || previous == 0) return null;
  return (current - previous) / previous.abs() * 100;
}

// ─── Insights ──────────────────────────────────────────────────────────────

enum InsightKind {
  notEnoughData,
  trendUp,
  trendDown,
  trendFlat,
  peakValue,
  peakHour,
  peakWeekday,
  topBike,
  streak,
  longestRide,
  cleanRides,
  stoppedShare,
  peakLean,
  totalClimb,

  /// Fuel: the highest month ([AnalyticsInsight.value], month in `date`).
  peakMonth,

  /// Fuel: distance-weighted average over [AnalyticsInsight.value2]
  /// full-tank stretches.
  fuelAverage,

  /// Fuel: fill-ups exist, but not two full-tank ones to measure between.
  fuelNeedFullFills,
}

/// A plain-language observation about a series, as numbers; the
/// presentation layer words it.
class AnalyticsInsight {
  final InsightKind kind;
  final double? value;
  final double? value2;
  final DateTime? date;
  final String? key;

  const AnalyticsInsight(this.kind,
      {this.value, this.value2, this.date, this.key});

  @override
  String toString() => 'AnalyticsInsight($kind, $value, $value2, $date, $key)';
}

/// Changes smaller than this (in percent) read as "about the same".
const double flatTrendThresholdPercent = 3;

/// Up to two insights for [chart] over [rides] (current range): one about
/// the shape of the data, one about the trend vs [trend] when there is one.
List<AnalyticsInsight> buildInsights(
  AnalyticsChart chart,
  List<RideEntity> rides,
  List<AnalyticsPoint> series, {
  required DateTime now,
  double? trend,
}) {
  if (rides.isEmpty || series.isEmpty) {
    return const [AnalyticsInsight(InsightKind.notEnoughData)];
  }
  final out = <AnalyticsInsight>[];
  switch (chart) {
    case AnalyticsChart.hourOfDay:
    case AnalyticsChart.weekday:
      final peak = series.reduce((a, b) => b.value > a.value ? b : a);
      out.add(AnalyticsInsight(
        chart == AnalyticsChart.hourOfDay
            ? InsightKind.peakHour
            : InsightKind.peakWeekday,
        value: peak.bucket?.toDouble(),
        value2: peak.value,
      ));
    case AnalyticsChart.distanceByBike:
      final total = series.fold<double>(0, (s, p) => s + p.value);
      if (total > 0) {
        out.add(AnalyticsInsight(InsightKind.topBike,
            key: series.first.key, value: series.first.value / total * 100));
      }
    case AnalyticsChart.activityCalendar:
      final s = ridingStreaks(rides, now: now);
      out.add(AnalyticsInsight(InsightKind.streak,
          value: s.current.toDouble(), value2: s.longest.toDouble()));
    case AnalyticsChart.longestRides:
      out.add(AnalyticsInsight(InsightKind.longestRide,
          value: series.first.value, date: series.first.date));
    case AnalyticsChart.hardBraking:
    case AnalyticsChart.rapidAccel:
    case AnalyticsChart.overspeed:
      final clean = series.where((p) => p.value == 0).length;
      out.add(AnalyticsInsight(InsightKind.cleanRides,
          value: clean.toDouble(), value2: series.length.toDouble()));
    case AnalyticsChart.jamTime:
    case AnalyticsChart.movingVsStopped:
      var dur = 0;
      var stopped = 0;
      for (final r in rides) {
        final s = stoppedSeconds(r);
        final d = r.durationSeconds;
        if (s == null || d == null || d <= 0) continue;
        dur += d;
        stopped += s;
      }
      if (dur > 0) {
        out.add(AnalyticsInsight(InsightKind.stoppedShare,
            value: stopped / dur * 100));
      }
    case AnalyticsChart.maxLean:
      // Worded as an estimate — see CorneringEstimator.
      final peak = series.reduce((a, b) => b.value > a.value ? b : a);
      out.add(AnalyticsInsight(InsightKind.peakLean,
          value: peak.value, date: peak.date));
    case AnalyticsChart.elevationGain:
      final total = series.fold<double>(0, (s, p) => s + p.value);
      out.add(AnalyticsInsight(InsightKind.totalClimb,
          value: total, value2: series.length.toDouble()));
    default:
      final peak = series.reduce((a, b) => b.value > a.value ? b : a);
      out.add(AnalyticsInsight(InsightKind.peakValue,
          value: peak.value, date: peak.date));
  }
  if (trend != null) {
    if (trend.abs() < flatTrendThresholdPercent) {
      out.add(const AnalyticsInsight(InsightKind.trendFlat));
    } else {
      out.add(AnalyticsInsight(
          trend > 0 ? InsightKind.trendUp : InsightKind.trendDown,
          value: trend.abs()));
    }
  }
  if (out.isEmpty) out.add(const AnalyticsInsight(InsightKind.notEnoughData));
  return out;
}

// ─── CSV ───────────────────────────────────────────────────────────────────

/// RFC 4180 CSV: fields containing a comma, quote or newline are quoted and
/// inner quotes doubled; lines end with CRLF.
String toCsv(List<String> header, List<List<Object?>> rows) {
  String cell(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(RegExp(r'[",\r\n]'))) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  final b = StringBuffer()
    ..write(header.map(cell).join(','))
    ..write('\r\n');
  for (final r in rows) {
    b
      ..write(r.map(cell).join(','))
      ..write('\r\n');
  }
  return b.toString();
}

// ─── Fuel charts ───────────────────────────────────────────────────────────

bool isFuelChart(AnalyticsChart c) => switch (c) {
      AnalyticsChart.fuelSpend ||
      AnalyticsChart.fuelEfficiency ||
      AnalyticsChart.fuelCostPerKm ||
      AnalyticsChart.fuelLiters =>
        true,
      _ => false,
    };

/// Spend and litres: one bar per calendar month.
bool isFuelMonthlyChart(AnalyticsChart c) =>
    c == AnalyticsChart.fuelSpend || c == AnalyticsChart.fuelLiters;

/// km/L and ৳/km: one point per full-to-full stretch (see [fuelSegments]).
bool isFuelSegmentChart(AnalyticsChart c) =>
    c == AnalyticsChart.fuelEfficiency || c == AnalyticsChart.fuelCostPerKm;

/// How many months the compact fuel cards show.
const int previewMonthCount = 6;

DateTime monthStartOf(DateTime t) => DateTime(t.year, t.month);

String _isoMonth(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

List<FuelLogEntity> fuelLogsInWindow(
    List<FuelLogEntity> logs, ({DateTime start, DateTime end})? w) {
  if (w == null) return logs;
  return logs
      .where((l) => !l.filledAt.isBefore(w.start) && l.filledAt.isBefore(w.end))
      .toList();
}

bool _endsInWindow(FuelSegment s, ({DateTime start, DateTime end})? w) =>
    w == null || (!s.end.isBefore(w.start) && s.end.isBefore(w.end));

/// Total spend (or litres) per calendar month from [from]'s month to [to]'s,
/// empty months included, oldest first. [AnalyticsPoint.secondary] is the
/// month's fill-up count.
List<AnalyticsPoint> fuelMonthly(
  AnalyticsChart chart,
  List<FuelLogEntity> logs, {
  required DateTime from,
  required DateTime to,
}) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final l in logs) {
    final k = _isoMonth(l.filledAt);
    totals[k] = (totals[k] ?? 0) +
        (chart == AnalyticsChart.fuelSpend ? l.totalCost : l.liters);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final last = monthStartOf(to);
  final out = <AnalyticsPoint>[];
  for (var m = monthStartOf(from);
      !m.isAfter(last);
      m = DateTime(m.year, m.month + 1)) {
    final k = _isoMonth(m);
    out.add(AnalyticsPoint(
      key: k,
      date: m,
      value: totals[k] ?? 0,
      secondary: (counts[k] ?? 0).toDouble(),
    ));
  }
  return out;
}

/// km/L or ৳/km per full-to-full stretch, oldest first, for stretches that
/// end inside [window]. Stretches are measured over every fill-up, so one
/// that started before the window still counts. [AnalyticsPoint.secondary]
/// is the stretch's distance in km.
List<AnalyticsPoint> fuelSegmentSeries(
  AnalyticsChart chart,
  List<FuelLogEntity> logs, {
  ({DateTime start, DateTime end})? window,
}) {
  return [
    for (final s in fuelSegments(logs))
      if (_endsInWindow(s, window))
        AnalyticsPoint(
          key: s.endLogId,
          date: s.end,
          value: chart == AnalyticsChart.fuelEfficiency
              ? s.kmPerLiter
              : s.costPerKm,
          secondary: s.distanceKm,
        ),
  ];
}

/// The series a fuel chart plots over every fill-up in [logs], limited to
/// [window] (the whole history when null, ending at [now]).
List<AnalyticsPoint> buildFuelSeries(
  AnalyticsChart chart,
  List<FuelLogEntity> logs, {
  required DateTime now,
  ({DateTime start, DateTime end})? window,
}) {
  if (isFuelSegmentChart(chart)) {
    return fuelSegmentSeries(chart, logs, window: window);
  }
  if (!isFuelMonthlyChart(chart) || logs.isEmpty) return const [];
  if (window != null) {
    return fuelMonthly(chart, fuelLogsInWindow(logs, window),
        from: window.start, to: now);
  }
  final earliest =
      logs.map((l) => l.filledAt).reduce((a, b) => a.isBefore(b) ? a : b);
  return fuelMonthly(chart, logs, from: earliest, to: now);
}

/// The compact card's series: the last [previewMonthCount] months, or the
/// last [previewRideCount] stretches. Empty with no fill-ups at all, so the
/// card shows its "log fuel" hint.
List<AnalyticsPoint> buildFuelPreviewSeries(
  AnalyticsChart chart,
  List<FuelLogEntity> logs, {
  required DateTime now,
}) {
  if (logs.isEmpty) return const [];
  if (isFuelSegmentChart(chart)) {
    final s = fuelSegmentSeries(chart, logs);
    return s.length > previewRideCount
        ? s.sublist(s.length - previewRideCount)
        : s;
  }
  final m = monthStartOf(now);
  return fuelMonthly(chart, logs,
      from: DateTime(m.year, m.month - (previewMonthCount - 1)), to: now);
}

/// The number two periods are compared on: total spend/litres for the
/// monthly charts, distance-weighted km/L or ৳/km for the stretch charts.
/// Null when [window] holds nothing to compare.
double? fuelPeriodAggregate(
  AnalyticsChart chart,
  List<FuelLogEntity> logs,
  ({DateTime start, DateTime end})? window,
) {
  if (isFuelMonthlyChart(chart)) {
    final inWindow = fuelLogsInWindow(logs, window);
    if (inWindow.isEmpty) return null;
    return inWindow.fold<double>(
        0,
        (s, l) =>
            s + (chart == AnalyticsChart.fuelSpend ? l.totalCost : l.liters));
  }
  var km = 0.0;
  var liters = 0.0;
  var cost = 0.0;
  for (final s in fuelSegments(logs)) {
    if (!_endsInWindow(s, window)) continue;
    km += s.distanceKm;
    liters += s.liters;
    cost += s.cost;
  }
  if (km <= 0 || liters <= 0) return null;
  return chart == AnalyticsChart.fuelEfficiency ? km / liters : cost / km;
}

/// Distance-weighted mean of a stretch series (whose secondary is the
/// stretch distance): total km over total litres for km/L, total ৳ over
/// total km for ৳/km.
double? _weightedSegmentAverage(
    AnalyticsChart chart, List<AnalyticsPoint> series) {
  var km = 0.0;
  var other = 0.0;
  for (final p in series) {
    final d = p.secondary ?? 0;
    if (d <= 0 || p.value <= 0) continue;
    km += d;
    other += chart == AnalyticsChart.fuelEfficiency ? d / p.value : p.value * d;
  }
  if (km <= 0 || other <= 0) return null;
  return chart == AnalyticsChart.fuelEfficiency ? km / other : other / km;
}

/// Up to two insights for a fuel chart: its shape (peak month, or the
/// average over the stretches shown) and the trend vs [trend].
List<AnalyticsInsight> buildFuelInsights(
  AnalyticsChart chart,
  List<FuelLogEntity> logs,
  List<AnalyticsPoint> series, {
  double? trend,
}) {
  if (logs.isEmpty) return const [AnalyticsInsight(InsightKind.notEnoughData)];
  final out = <AnalyticsInsight>[];
  if (isFuelSegmentChart(chart)) {
    final avg = _weightedSegmentAverage(chart, series);
    if (avg == null) {
      out.add(const AnalyticsInsight(InsightKind.fuelNeedFullFills));
    } else {
      out.add(AnalyticsInsight(InsightKind.fuelAverage,
          value: avg, value2: series.length.toDouble()));
    }
  } else if (series.every((p) => p.value <= 0)) {
    out.add(const AnalyticsInsight(InsightKind.notEnoughData));
  } else {
    final peak = series.reduce((a, b) => b.value > a.value ? b : a);
    out.add(AnalyticsInsight(InsightKind.peakMonth,
        value: peak.value, date: peak.date));
  }
  if (trend != null) {
    if (trend.abs() < flatTrendThresholdPercent) {
      out.add(const AnalyticsInsight(InsightKind.trendFlat));
    } else {
      out.add(AnalyticsInsight(
          trend > 0 ? InsightKind.trendUp : InsightKind.trendDown,
          value: trend.abs()));
    }
  }
  return out;
}

List<RideEntity> _chronological(List<RideEntity> rides) =>
    [...rides]..sort((a, b) => a.startTime.compareTo(b.startTime));
