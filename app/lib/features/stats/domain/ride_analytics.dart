/// Generic machinery behind the Rides tab's analytics charts.
///
/// Everything here is a pure function of the rider's data plus an explicit
/// `now`, so it can be unit-tested without a clock, SQLite or Flutter (see
/// `test/features/stats/ride_analytics_test.dart`). The presentation layer
/// only turns these numbers into charts, labels and CSV cells.
///
/// This file knows no individual chart. Each chart family lives in its own
/// file under `charts/` as an [AnalyticsChart] (its series math, period
/// aggregate and insights), and `analytics_chart_registry.dart` lists them in
/// display order. Adding a family is one new file plus one registry line —
/// see `test/features/stats/chart_registry_structure_test.dart` for why.
///
/// Only data the app actually records is used. Metrics a ride doesn't carry
/// (e.g. moving time on rides finalized before it was tracked) are skipped
/// for that ride rather than guessed as zero.
library;

import '../../maintenance/domain/entities/fuel_log.dart';
import '../../ride/domain/entities/ride_entity.dart';

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

/// `[start, end)` of a range.
typedef AnalyticsWindow = ({DateTime start, DateTime end});

/// One value on a chart.
///
/// [key] is stable and unique within a series: a ride id, an ISO day, a
/// bucket number or a bike id. [secondary] carries the second stack of a
/// two-part bar or a companion figure; [tertiary] a third.
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

  static const empty = MetricSummary(
    min: 0,
    max: 0,
    avg: 0,
    total: 0,
    count: 0,
  );

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
      min: min,
      max: max,
      avg: total / count,
      total: total,
      count: count,
    );
  }

  double aggregate(Aggregation a) => a == Aggregation.sum ? total : avg;
}

// ─── Calendar helpers ──────────────────────────────────────────────────────

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Monday of the week containing [t], at local midnight.
DateTime weekStartOf(DateTime t) {
  final d = dayOf(t);
  return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}

/// `2026-10-09` — a stable point key for a day.
String isoDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// [rides] sorted oldest first.
List<RideEntity> chronological(List<RideEntity> rides) =>
    [...rides]..sort((a, b) => a.startTime.compareTo(b.startTime));

// ─── Ranges, windows and trends ────────────────────────────────────────────

/// How many rides / weeks the compact list cards show.
const int previewRideCount = 20;
const int previewWeekCount = 12;

/// `[start, end)` of [range] ending at [now]; null for
/// [AnalyticsRange.all].
AnalyticsWindow? rangeWindow(AnalyticsRange range, DateTime now) {
  final len = range.length;
  if (len == null) return null;
  final end = DateTime(now.year, now.month, now.day + 1);
  final start = DateTime(end.year, end.month, end.day - len.inDays);
  return (start: start, end: end);
}

/// The window immediately before [range]'s; null for [AnalyticsRange.all].
AnalyticsWindow? previousRangeWindow(AnalyticsRange range, DateTime now) {
  final w = rangeWindow(range, now);
  if (w == null) return null;
  final days = range.length!.inDays;
  return (
    start: DateTime(w.start.year, w.start.month, w.start.day - days),
    end: w.start,
  );
}

List<RideEntity> ridesInWindow(List<RideEntity> rides, AnalyticsWindow? w) {
  if (w == null) return rides;
  return rides
      .where(
        (r) => !r.startTime.isBefore(w.start) && r.startTime.isBefore(w.end),
      )
      .toList();
}

List<RideEntity> ridesInRange(
  List<RideEntity> rides,
  AnalyticsRange range,
  DateTime now,
) =>
    ridesInWindow(rides, rangeWindow(range, now));

/// Percentage change from [previous] to [current]; null when there's no
/// honest baseline (no previous data, or a zero previous value).
double? trendPercent(double? current, double? previous) {
  if (current == null || previous == null || previous == 0) return null;
  return (current - previous) / previous.abs() * 100;
}

// ─── Insights ──────────────────────────────────────────────────────────────

/// What an [AnalyticsInsight] says. The generic kinds live here; a chart
/// family declares its own (e.g. a peak-hour insight) next to its charts,
/// and words them in its presentation file.
class InsightKind {
  final String name;
  const InsightKind(this.name);

  static const notEnoughData = InsightKind('notEnoughData');
  static const trendUp = InsightKind('trendUp');
  static const trendDown = InsightKind('trendDown');
  static const trendFlat = InsightKind('trendFlat');

  /// The series' highest point ([AnalyticsInsight.value] on `date`).
  static const peakValue = InsightKind('peakValue');

  @override
  String toString() => 'InsightKind.$name';
}

/// A plain-language observation about a series, as numbers; the
/// presentation layer words it.
class AnalyticsInsight {
  final InsightKind kind;
  final double? value;
  final double? value2;
  final DateTime? date;
  final String? key;

  const AnalyticsInsight(
    this.kind, {
    this.value,
    this.value2,
    this.date,
    this.key,
  });

  @override
  String toString() => 'AnalyticsInsight($kind, $value, $value2, $date, $key)';
}

/// Changes smaller than this (in percent) read as "about the same".
const double flatTrendThresholdPercent = 3;

/// The trend insight for [trend], or null when there's no trend.
AnalyticsInsight? trendInsight(double? trend) {
  if (trend == null) return null;
  if (trend.abs() < flatTrendThresholdPercent) {
    return const AnalyticsInsight(InsightKind.trendFlat);
  }
  return AnalyticsInsight(
    trend > 0 ? InsightKind.trendUp : InsightKind.trendDown,
    value: trend.abs(),
  );
}

/// The highest point of a non-empty [series], as a [InsightKind.peakValue].
AnalyticsInsight peakValueInsight(List<AnalyticsPoint> series) {
  final peak = series.reduce((a, b) => b.value > a.value ? b : a);
  return AnalyticsInsight(
    InsightKind.peakValue,
    value: peak.value,
    date: peak.date,
  );
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

// ─── The chart spec ────────────────────────────────────────────────────────

/// Everything a chart may read: the rider's rides and logged fill-ups.
class ChartInput {
  final List<RideEntity> rides;
  final List<FuelLogEntity> fuelLogs;

  const ChartInput({this.rides = const [], this.fuelLogs = const []});
}

/// What a compact list card shows.
class ChartPreview {
  final List<AnalyticsPoint> points;
  final List<AnalyticsInsight> insights;

  const ChartPreview({required this.points, required this.insights});
}

/// What the detail view shows for one range.
class ChartDetail {
  final List<AnalyticsPoint> series;

  /// Percent change vs the previous period; null with no baseline.
  final double? trend;
  final List<AnalyticsInsight> insights;

  /// Rides (or fill-ups) in the range — the summary's count cell.
  final int count;

  const ChartDetail({
    required this.series,
    required this.trend,
    required this.insights,
    required this.count,
  });
}

/// One chart on the analytics list: its stable [id] and its math.
///
/// A family file under `charts/` declares its charts as const instances of
/// a subclass, and the registry lists them. Wording, colour and shape are
/// the presentation layer's `ChartPresentation`, keyed by the same chart.
abstract class AnalyticsChart {
  /// Stable and unique across the registry; also names the CSV export.
  final String id;

  const AnalyticsChart(this.id);

  String get name => id;

  /// How points combine across a period. A mean metric's summary shows the
  /// item count in place of a (meaningless) total.
  Aggregation get aggregation => Aggregation.sum;

  /// The compact card's series and insights.
  ChartPreview preview(ChartInput input, {required DateTime now});

  /// The detail view's series, trend, insights and count for [range].
  ChartDetail detail(
    ChartInput input,
    AnalyticsRange range, {
    required DateTime now,
  });

  /// Whether [range] has enough to draw.
  bool hasDataIn(
    ChartInput input,
    AnalyticsRange range, {
    required DateTime now,
  });

  /// The shortest range that has something to show.
  AnalyticsRange defaultRange(ChartInput input, {required DateTime now}) => [
        AnalyticsRange.days30,
        AnalyticsRange.days90,
        AnalyticsRange.year,
      ].firstWhere(
        (r) => hasDataIn(input, r, now: now),
        orElse: () => AnalyticsRange.all,
      );

  @override
  String toString() => 'AnalyticsChart($id)';
}

/// A chart over the rider's rides.
abstract class RideChart extends AnalyticsChart {
  const RideChart(super.id);

  /// Rides a range needs before the detail view opens on it.
  int get minRides => 1;

  /// The series for [rides] (already filtered to a range).
  ///
  /// [window] bounds calendar charts so empty weeks/days at either end of
  /// the range still show; when null they span first ride → [now].
  List<AnalyticsPoint> series(
    List<RideEntity> rides, {
    required DateTime now,
    AnalyticsWindow? window,
  });

  /// The compact card's series; the whole-history series by default.
  List<AnalyticsPoint> previewSeries(
    List<RideEntity> rides, {
    required DateTime now,
  }) =>
      series(rides, now: now);

  /// The number two periods are compared on, for a non-empty [rides].
  /// Total distance by default.
  double? aggregateRides(List<RideEntity> rides) =>
      rides.fold<double>(0, (s, r) => s + r.distanceKm);

  /// [aggregateRides], or null with no rides.
  double? periodAggregate(List<RideEntity> rides) =>
      rides.isEmpty ? null : aggregateRides(rides);

  /// The insight about the shape of a non-empty [series]: its peak by
  /// default.
  List<AnalyticsInsight> shapeInsights(
    List<RideEntity> rides,
    List<AnalyticsPoint> series, {
    required DateTime now,
  }) =>
      [peakValueInsight(series)];

  /// Up to two insights over [rides] (current range): one about the shape
  /// of the data, one about the trend vs [trend] when there is one.
  List<AnalyticsInsight> insights(
    List<RideEntity> rides,
    List<AnalyticsPoint> series, {
    required DateTime now,
    double? trend,
  }) {
    if (rides.isEmpty || series.isEmpty) {
      return const [AnalyticsInsight(InsightKind.notEnoughData)];
    }
    final out = [
      ...shapeInsights(rides, series, now: now),
      if (trendInsight(trend) case final t?) t,
    ];
    if (out.isEmpty) out.add(const AnalyticsInsight(InsightKind.notEnoughData));
    return out;
  }

  @override
  ChartPreview preview(ChartInput input, {required DateTime now}) {
    final points = previewSeries(input.rides, now: now);
    return ChartPreview(
      points: points,
      insights: insights(input.rides, points, now: now),
    );
  }

  @override
  ChartDetail detail(
    ChartInput input,
    AnalyticsRange range, {
    required DateTime now,
  }) {
    final window = rangeWindow(range, now);
    final current = ridesInWindow(input.rides, window);
    final previous = ridesInWindow(
      input.rides,
      previousRangeWindow(range, now),
    );
    final s = series(current, now: now, window: window);
    final trend = trendPercent(
      periodAggregate(current),
      periodAggregate(previous),
    );
    return ChartDetail(
      series: s,
      trend: trend,
      insights: insights(current, s, now: now, trend: trend),
      count: current.length,
    );
  }

  @override
  bool hasDataIn(
    ChartInput input,
    AnalyticsRange range, {
    required DateTime now,
  }) =>
      ridesInRange(input.rides, range, now).length >= minRides;
}

/// A chart with one point per ride, oldest first. Rides that don't carry
/// the metric ([value] returns null) are skipped.
class PerRideChart extends RideChart {
  /// The plotted per-ride value, or null when this ride doesn't carry it.
  final double? Function(RideEntity r) value;

  /// A companion figure carried in [AnalyticsPoint.secondary].
  final double? Function(RideEntity r)? secondary;

  /// A third figure carried in [AnalyticsPoint.tertiary].
  final double? Function(RideEntity r)? tertiary;

  @override
  final Aggregation aggregation;

  /// Replaces the default peak-value insight.
  final List<AnalyticsInsight> Function(
    List<RideEntity> rides,
    List<AnalyticsPoint> series,
  )? shapeInsight;

  const PerRideChart(
    super.id, {
    required this.value,
    this.secondary,
    this.tertiary,
    this.aggregation = Aggregation.sum,
    this.shapeInsight,
  });

  /// A trend line needs two rides.
  @override
  int get minRides => 2;

  /// Per-ride series, oldest first. Rides missing the metric are skipped.
  List<AnalyticsPoint> perRideSeries(List<RideEntity> rides) {
    final out = <AnalyticsPoint>[];
    for (final r in chronological(rides)) {
      final v = value(r);
      if (v == null) continue;
      out.add(
        AnalyticsPoint(
          key: r.id,
          date: r.startTime,
          value: v,
          secondary: secondary?.call(r),
          tertiary: tertiary?.call(r),
        ),
      );
    }
    return out;
  }

  @override
  List<AnalyticsPoint> series(
    List<RideEntity> rides, {
    required DateTime now,
    AnalyticsWindow? window,
  }) =>
      perRideSeries(rides);

  /// The last [previewRideCount] rides.
  @override
  List<AnalyticsPoint> previewSeries(
    List<RideEntity> rides, {
    required DateTime now,
  }) {
    final s = perRideSeries(rides);
    return s.length > previewRideCount
        ? s.sublist(s.length - previewRideCount)
        : s;
  }

  @override
  double? aggregateRides(List<RideEntity> rides) {
    final s = MetricSummary.of(perRideSeries(rides).map((p) => p.value));
    if (s.isEmpty) return null;
    return s.aggregate(aggregation);
  }

  @override
  List<AnalyticsInsight> shapeInsights(
    List<RideEntity> rides,
    List<AnalyticsPoint> series, {
    required DateTime now,
  }) =>
      shapeInsight?.call(rides, series) ??
      super.shapeInsights(rides, series, now: now);
}
