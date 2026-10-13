import 'package:flutter/material.dart';

import '../../domain/charts/cornering_elevation_charts.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';

/// Cornering and elevation (schema v26): max lean, peak g and climb.
final List<ChartPresentation> corneringElevationPresentations = [
  ChartPresentation(
    chart: CorneringElevationCharts.maxLean,
    title: (l) => l.chartMaxLean,
    unit: (_) => '°',
    icon: Icons.turn_slight_right,
    color: (p) => p.secondary,
    shape: ChartShape.line,
    wordInsight: _word,
  ),
  ChartPresentation(
    chart: CorneringElevationCharts.peakG,
    title: (l) => l.chartPeakG,
    unit: (_) => 'g',
    icon: Icons.adjust,
    color: (p) => p.attention,
    shape: ChartShape.line,
    // g-forces live between 0 and 1.5: one decimal hides the difference,
    // and a whole-unit line padding would flatten the line.
    formatValue: _twoDecimals,
    lineMinPad: 0.05,
    table: _peakGTable,
  ),
  ChartPresentation(
    chart: CorneringElevationCharts.elevationGain,
    title: (l) => l.chartElevationGain,
    unit: (_) => 'm',
    icon: Icons.terrain_outlined,
    color: (p) => p.success,
    shape: ChartShape.bars,
    table: _elevationTable,
    wordInsight: _word,
  ),
];

String _twoDecimals(double v) => v.toStringAsFixed(2);

String? _word(InsightWording w, AnalyticsInsight i) {
  if (i.kind == peakLeanInsight) {
    return w.l10n.insightPeakLean(
      formatWithUnit(i.value ?? 0, '°'),
      shortDate(i.date!),
    );
  }
  if (i.kind == totalClimbInsight) {
    return w.l10n.insightTotalClimb(
      formatWithUnit(i.value ?? 0, 'm'),
      (i.value2 ?? 0).round(),
    );
  }
  return null;
}

ChartTable _peakGTable(ChartTableContext t, List<AnalyticsPoint> points) {
  String g(double? v) => v == null ? '—' : v.toStringAsFixed(2);
  String csvG(double? v) => v == null ? '' : v.toStringAsFixed(3);
  return ChartTable(
    headers: [
      t.l10n.analyticsColDate,
      ChartTableContext.withUnit(t.l10n.analyticsColLateral, 'g'),
      ChartTableContext.withUnit(t.l10n.analyticsColAccel, 'g'),
      ChartTableContext.withUnit(t.l10n.analyticsColBrake, 'g'),
    ],
    displayRows: [
      for (final p in points.reversed)
        [longDate(p.date!), g(p.value), g(p.secondary), g(p.tertiary)],
    ],
    csvRows: [
      for (final p in points)
        [
          isoDateTime(p.date!),
          csvG(p.value),
          csvG(p.secondary),
          csvG(p.tertiary),
        ],
    ],
  );
}

ChartTable _elevationTable(ChartTableContext t, List<AnalyticsPoint> points) =>
    ChartTable(
      headers: [
        t.l10n.analyticsColDate,
        ChartTableContext.withUnit(t.l10n.analyticsColClimb, 'm'),
        ChartTableContext.withUnit(t.l10n.analyticsColDescent, 'm'),
      ],
      displayRows: [
        for (final p in points.reversed)
          [
            longDate(p.date!),
            formatAnalyticsNumber(p.value),
            p.secondary == null ? '—' : formatAnalyticsNumber(p.secondary!),
          ],
      ],
      csvRows: [
        for (final p in points)
          [
            isoDateTime(p.date!),
            csvNum(p.value),
            p.secondary == null ? '' : csvNum(p.secondary!),
          ],
      ],
    );
