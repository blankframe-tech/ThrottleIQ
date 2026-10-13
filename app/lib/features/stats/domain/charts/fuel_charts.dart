/// Fuel (schema v27): spend, efficiency, cost per km and litres.
///
/// These read the rider's logged fill-ups ([FuelLogEntity]) instead of
/// rides. Spend and litres are one bar per calendar month; km/L and ৳/km
/// are one point per full-to-full stretch (see [fuelSegments]).
library;

import '../../../maintenance/domain/calculators/fuel_economy.dart';
import '../../../maintenance/domain/entities/fuel_log.dart';
import '../ride_analytics.dart';

abstract final class FuelCharts {
  static const fuelSpend = FuelMonthlyChart('fuelSpend', spend: true);
  static const fuelEfficiency = FuelSegmentChart(
    'fuelEfficiency',
    kmPerLiter: true,
  );
  static const fuelCostPerKm = FuelSegmentChart(
    'fuelCostPerKm',
    kmPerLiter: false,
  );
  static const fuelLiters = FuelMonthlyChart('fuelLiters', spend: false);

  static const List<AnalyticsChart> all = [
    fuelSpend,
    fuelEfficiency,
    fuelCostPerKm,
    fuelLiters,
  ];
}

/// Fuel: the highest month ([AnalyticsInsight.value], month in `date`).
const peakMonthInsight = InsightKind('peakMonth');

/// Fuel: distance-weighted average over [AnalyticsInsight.value2]
/// full-tank stretches.
const fuelAverageInsight = InsightKind('fuelAverage');

/// Fuel: fill-ups exist, but not two full-tank ones to measure between.
const fuelNeedFullFillsInsight = InsightKind('fuelNeedFullFills');

/// How many months the compact fuel cards show.
const int previewMonthCount = 6;

DateTime monthStartOf(DateTime t) => DateTime(t.year, t.month);

String _isoMonth(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

List<FuelLogEntity> fuelLogsInWindow(
  List<FuelLogEntity> logs,
  AnalyticsWindow? w,
) {
  if (w == null) return logs;
  return logs
      .where((l) => !l.filledAt.isBefore(w.start) && l.filledAt.isBefore(w.end))
      .toList();
}

bool _endsInWindow(FuelSegment s, AnalyticsWindow? w) =>
    w == null || (!s.end.isBefore(w.start) && s.end.isBefore(w.end));

/// A chart over the rider's fill-ups.
abstract class FuelChart extends AnalyticsChart {
  const FuelChart(super.id);

  /// Points with a value a range needs before the detail view opens on it.
  int get minPoints;

  /// The series over every fill-up in [logs], limited to [window] (the
  /// whole history when null, ending at [now]).
  List<AnalyticsPoint> series(
    List<FuelLogEntity> logs, {
    required DateTime now,
    AnalyticsWindow? window,
  });

  /// The compact card's series. Empty with no fill-ups at all, so the card
  /// shows its "log fuel" hint.
  List<AnalyticsPoint> previewSeries(
    List<FuelLogEntity> logs, {
    required DateTime now,
  });

  /// The number two periods are compared on; null when [window] holds
  /// nothing to compare.
  double? periodAggregate(List<FuelLogEntity> logs, AnalyticsWindow? window);

  /// The insight about the shape of [series] when there are fill-ups.
  AnalyticsInsight shapeInsight(List<AnalyticsPoint> series);

  /// Up to two insights: the series' shape and the trend vs [trend].
  List<AnalyticsInsight> insights(
    List<FuelLogEntity> logs,
    List<AnalyticsPoint> series, {
    double? trend,
  }) {
    if (logs.isEmpty) {
      return const [AnalyticsInsight(InsightKind.notEnoughData)];
    }
    return [shapeInsight(series), if (trendInsight(trend) case final t?) t];
  }

  @override
  ChartPreview preview(ChartInput input, {required DateTime now}) {
    final points = previewSeries(input.fuelLogs, now: now);
    return ChartPreview(
      points: points,
      insights: insights(input.fuelLogs, points),
    );
  }

  @override
  ChartDetail detail(
    ChartInput input,
    AnalyticsRange range, {
    required DateTime now,
  }) {
    final logs = input.fuelLogs;
    final window = rangeWindow(range, now);
    final previousWindow = previousRangeWindow(range, now);
    final s = series(logs, now: now, window: window);
    final trend = previousWindow == null
        ? null
        : trendPercent(
            periodAggregate(logs, window),
            periodAggregate(logs, previousWindow),
          );
    return ChartDetail(
      series: s,
      trend: trend,
      insights: insights(logs, s, trend: trend),
      count: fuelLogsInWindow(logs, window).length,
    );
  }

  @override
  bool hasDataIn(
    ChartInput input,
    AnalyticsRange range, {
    required DateTime now,
  }) =>
      series(
        input.fuelLogs,
        now: now,
        window: rangeWindow(range, now),
      ).where((p) => p.value > 0).length >=
      minPoints;
}

/// Total spend ([spend]) or litres per calendar month.
class FuelMonthlyChart extends FuelChart {
  final bool spend;

  const FuelMonthlyChart(super.id, {required this.spend});

  @override
  int get minPoints => 1;

  double _amount(FuelLogEntity l) => spend ? l.totalCost : l.liters;

  /// Per calendar month from [from]'s month to [to]'s, empty months
  /// included, oldest first. [AnalyticsPoint.secondary] is the month's
  /// fill-up count.
  List<AnalyticsPoint> monthly(
    List<FuelLogEntity> logs, {
    required DateTime from,
    required DateTime to,
  }) {
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final l in logs) {
      final k = _isoMonth(l.filledAt);
      totals[k] = (totals[k] ?? 0) + _amount(l);
      counts[k] = (counts[k] ?? 0) + 1;
    }
    final last = monthStartOf(to);
    final out = <AnalyticsPoint>[];
    for (var m = monthStartOf(from);
        !m.isAfter(last);
        m = DateTime(m.year, m.month + 1)) {
      final k = _isoMonth(m);
      out.add(
        AnalyticsPoint(
          key: k,
          date: m,
          value: totals[k] ?? 0,
          secondary: (counts[k] ?? 0).toDouble(),
        ),
      );
    }
    return out;
  }

  @override
  List<AnalyticsPoint> series(
    List<FuelLogEntity> logs, {
    required DateTime now,
    AnalyticsWindow? window,
  }) {
    if (logs.isEmpty) return const [];
    if (window != null) {
      return monthly(
        fuelLogsInWindow(logs, window),
        from: window.start,
        to: now,
      );
    }
    final earliest =
        logs.map((l) => l.filledAt).reduce((a, b) => a.isBefore(b) ? a : b);
    return monthly(logs, from: earliest, to: now);
  }

  /// The last [previewMonthCount] months.
  @override
  List<AnalyticsPoint> previewSeries(
    List<FuelLogEntity> logs, {
    required DateTime now,
  }) {
    if (logs.isEmpty) return const [];
    final m = monthStartOf(now);
    return monthly(
      logs,
      from: DateTime(m.year, m.month - (previewMonthCount - 1)),
      to: now,
    );
  }

  @override
  double? periodAggregate(List<FuelLogEntity> logs, AnalyticsWindow? window) {
    final inWindow = fuelLogsInWindow(logs, window);
    if (inWindow.isEmpty) return null;
    return inWindow.fold<double>(0, (s, l) => s + _amount(l));
  }

  @override
  AnalyticsInsight shapeInsight(List<AnalyticsPoint> series) {
    if (series.every((p) => p.value <= 0)) {
      return const AnalyticsInsight(InsightKind.notEnoughData);
    }
    final peak = series.reduce((a, b) => b.value > a.value ? b : a);
    return AnalyticsInsight(
      peakMonthInsight,
      value: peak.value,
      date: peak.date,
    );
  }
}

/// km/L ([kmPerLiter]) or ৳/km per full-to-full stretch.
class FuelSegmentChart extends FuelChart {
  final bool kmPerLiter;

  const FuelSegmentChart(super.id, {required this.kmPerLiter});

  @override
  Aggregation get aggregation => Aggregation.mean;

  /// A trend line needs two stretches.
  @override
  int get minPoints => 2;

  /// One point per stretch that ends inside [window], oldest first.
  /// Stretches are measured over every fill-up, so one that started before
  /// the window still counts. [AnalyticsPoint.secondary] is the stretch's
  /// distance in km.
  @override
  List<AnalyticsPoint> series(
    List<FuelLogEntity> logs, {
    required DateTime now,
    AnalyticsWindow? window,
  }) =>
      [
        for (final s in fuelSegments(logs))
          if (_endsInWindow(s, window))
            AnalyticsPoint(
              key: s.endLogId,
              date: s.end,
              value: kmPerLiter ? s.kmPerLiter : s.costPerKm,
              secondary: s.distanceKm,
            ),
      ];

  /// The last [previewRideCount] stretches.
  @override
  List<AnalyticsPoint> previewSeries(
    List<FuelLogEntity> logs, {
    required DateTime now,
  }) {
    if (logs.isEmpty) return const [];
    final s = series(logs, now: now);
    return s.length > previewRideCount
        ? s.sublist(s.length - previewRideCount)
        : s;
  }

  /// Distance-weighted: total km over total litres, or total ৳ over total
  /// km — not the mean of the stretches.
  @override
  double? periodAggregate(List<FuelLogEntity> logs, AnalyticsWindow? window) {
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
    return kmPerLiter ? km / liters : cost / km;
  }

  /// Distance-weighted mean of a stretch series (whose secondary is the
  /// stretch distance).
  double? _weightedAverage(List<AnalyticsPoint> series) {
    var km = 0.0;
    var other = 0.0;
    for (final p in series) {
      final d = p.secondary ?? 0;
      if (d <= 0 || p.value <= 0) continue;
      km += d;
      other += kmPerLiter ? d / p.value : p.value * d;
    }
    if (km <= 0 || other <= 0) return null;
    return kmPerLiter ? km / other : other / km;
  }

  @override
  AnalyticsInsight shapeInsight(List<AnalyticsPoint> series) {
    final avg = _weightedAverage(series);
    if (avg == null) return const AnalyticsInsight(fuelNeedFullFillsInsight);
    return AnalyticsInsight(
      fuelAverageInsight,
      value: avg,
      value2: series.length.toDouble(),
    );
  }
}
