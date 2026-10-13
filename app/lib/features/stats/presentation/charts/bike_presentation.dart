import 'package:flutter/material.dart';

import '../../domain/charts/bike_charts.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';

/// Bikes and records: distance per bike, and the longest rides.
final List<ChartPresentation> bikePresentations = [
  ChartPresentation(
    chart: BikeCharts.distanceByBike,
    title: (l) => l.chartDistanceByBike,
    unit: (_) => 'km',
    icon: Icons.two_wheeler_outlined,
    color: (p) => p.primary,
    shape: ChartShape.ranked,
    rankLabel: (p, bikeName) => bikeName(p.key),
    table: _bikeTable,
    wordInsight: _word,
  ),
  ChartPresentation(
    chart: BikeCharts.longestRides,
    title: (l) => l.chartLongestRides,
    unit: (_) => 'km',
    icon: Icons.emoji_events_outlined,
    color: (p) => p.primary,
    shape: ChartShape.ranked,
    table: _longestTable,
    wordInsight: _word,
  ),
];

String? _word(InsightWording w, AnalyticsInsight i) {
  if (i.kind == topBikeInsight) {
    return w.l10n.insightTopBike(
      w.bikeName(i.key ?? ''),
      (i.value ?? 0).toStringAsFixed(0),
    );
  }
  if (i.kind == longestRideInsight) {
    return w.l10n.insightLongestRide(
      formatWithUnit(i.value ?? 0, 'km'),
      shortDate(i.date!),
    );
  }
  return null;
}

ChartTable _bikeTable(ChartTableContext t, List<AnalyticsPoint> points) =>
    ChartTable(
      headers: [t.l10n.analyticsColBike, t.l10n.analyticsColRides, t.kmHeader],
      displayRows: [
        for (final p in points)
          [
            t.bikeName(p.key),
            (p.secondary ?? 0).toStringAsFixed(0),
            formatAnalyticsNumber(p.value),
          ],
      ],
      csvRows: [
        for (final p in points)
          [
            t.bikeName(p.key),
            (p.secondary ?? 0).toStringAsFixed(0),
            csvNum(p.value),
          ],
      ],
    );

/// Ranked longest first, so not reversed.
ChartTable _longestTable(ChartTableContext t, List<AnalyticsPoint> points) =>
    ChartTable(
      headers: [t.l10n.analyticsColDate, t.valueHeader],
      displayRows: [
        for (final p in points)
          [longDate(p.date!), formatAnalyticsNumber(p.value)],
      ],
      csvRows: [
        for (final p in points) [isoDateTime(p.date!), csvNum(p.value)],
      ],
    );
