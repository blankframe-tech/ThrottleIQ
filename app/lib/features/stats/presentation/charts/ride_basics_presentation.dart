import 'package:flutter/material.dart';

import '../../domain/charts/ride_basics_charts.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';

/// Ride basics: distance, speed and duration.
final List<ChartPresentation> rideBasicsPresentations = [
  ChartPresentation(
    chart: RideBasicsCharts.distancePerRide,
    title: (l) => l.chartDistancePerRide,
    unit: (_) => 'km',
    icon: Icons.route_outlined,
    color: (p) => p.primary,
    shape: ChartShape.line,
    higherIsBetter: true,
  ),
  ChartPresentation(
    chart: RideBasicsCharts.weeklyDistance,
    title: (l) => l.chartWeeklyDistance,
    unit: (_) => 'km',
    icon: Icons.date_range_outlined,
    color: (p) => p.primary,
    shape: ChartShape.bars,
    higherIsBetter: true,
    table: _weeklyTable,
  ),
  ChartPresentation(
    chart: RideBasicsCharts.avgSpeed,
    title: (l) => l.chartAvgSpeed,
    unit: (_) => 'km/h',
    icon: Icons.speed_outlined,
    color: (p) => p.secondary,
    shape: ChartShape.line,
  ),
  ChartPresentation(
    chart: RideBasicsCharts.topSpeed,
    title: (l) => l.chartTopSpeed,
    unit: (_) => 'km/h',
    icon: Icons.bolt_outlined,
    color: (p) => p.attention,
    shape: ChartShape.line,
  ),
  ChartPresentation(
    chart: RideBasicsCharts.rideDuration,
    title: (l) => l.chartRideDuration,
    unit: (l) => l.analyticsUnitMin,
    icon: Icons.timer_outlined,
    color: (p) => p.secondary,
    shape: ChartShape.bars,
  ),
];

ChartTable _weeklyTable(ChartTableContext t, List<AnalyticsPoint> points) =>
    ChartTable(
      headers: [t.l10n.analyticsColWeekOf, t.valueHeader],
      displayRows: [
        for (final p in points.reversed)
          [longDate(p.date!), formatAnalyticsNumber(p.value)],
      ],
      csvRows: [
        for (final p in points) [isoDate(p.date!), csvNum(p.value)],
      ],
    );
