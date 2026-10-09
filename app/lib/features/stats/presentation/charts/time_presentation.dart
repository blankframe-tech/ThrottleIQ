import 'package:flutter/material.dart';

import '../../domain/charts/time_charts.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';

/// Time on the road: moving vs stopped, and time stuck in jams.
final List<ChartPresentation> timePresentations = [
  ChartPresentation(
    chart: TimeCharts.movingVsStopped,
    title: (l) => l.chartMovingVsStopped,
    unit: (_) => '%',
    icon: Icons.pause_circle_outline,
    color: (p) => p.success,
    shape: ChartShape.stacked,
    higherIsBetter: true,
    stackLabels: (l) => (l.analyticsColMoving, l.analyticsColStopped),
    table: _movingStoppedTable,
    wordInsight: _word,
  ),
  ChartPresentation(
    chart: TimeCharts.jamTime,
    title: (l) => l.chartJamTime,
    unit: (l) => l.analyticsUnitMin,
    icon: Icons.traffic_outlined,
    color: (p) => p.warning,
    shape: ChartShape.bars,
    higherIsBetter: false,
    wordInsight: _word,
  ),
];

String? _word(InsightWording w, AnalyticsInsight i) =>
    i.kind == stoppedShareInsight
        ? w.l10n.insightStoppedShare((i.value ?? 0).toStringAsFixed(0))
        : null;

ChartTable _movingStoppedTable(
  ChartTableContext t,
  List<AnalyticsPoint> points,
) =>
    ChartTable(
      headers: [
        t.l10n.analyticsColDate,
        ChartTableContext.withUnit(t.l10n.analyticsColMoving, '%'),
        ChartTableContext.withUnit(
          t.l10n.analyticsColStopped,
          t.l10n.analyticsUnitMin,
        ),
      ],
      displayRows: [
        for (final p in points.reversed)
          [
            longDate(p.date!),
            formatWithUnit(p.value, '%'),
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
