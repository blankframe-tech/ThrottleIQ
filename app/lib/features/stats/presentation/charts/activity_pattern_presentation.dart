import 'package:flutter/material.dart';

import '../../domain/charts/activity_pattern_charts.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';

/// Activity patterns: the riding-days calendar, hour of day and weekday.
final List<ChartPresentation> activityPatternPresentations = [
  ChartPresentation(
    chart: ActivityPatternCharts.activityCalendar,
    title: (l) => l.chartActivityCalendar,
    unit: (_) => 'km',
    icon: Icons.calendar_month_outlined,
    color: (p) => p.primary,
    shape: ChartShape.heatmap,
    higherIsBetter: true,
    table: _calendarTable,
    wordInsight: _word,
  ),
  ChartPresentation(
    chart: ActivityPatternCharts.hourOfDay,
    title: (l) => l.chartHourOfDay,
    unit: (l) => l.analyticsUnitRides,
    icon: Icons.schedule_outlined,
    color: (p) => p.secondary,
    shape: ChartShape.bars,
    needsNonZero: true,
    axisLabel: (p) => p.bucket!.toString(),
    pointLabel: (p) => hourLabel(p.bucket!),
    labelledIndices: (n, detailed) =>
        detailed ? {0, 3, 6, 9, 12, 15, 18, 21} : {0, 6, 12, 18},
    table: (t, points) =>
        _bucketTable(t, points, t.l10n.analyticsColHour, hourLabel),
    wordInsight: _word,
  ),
  ChartPresentation(
    chart: ActivityPatternCharts.weekday,
    title: (l) => l.chartWeekday,
    unit: (l) => l.analyticsUnitRides,
    icon: Icons.view_week_outlined,
    color: (p) => p.secondary,
    shape: ChartShape.bars,
    needsNonZero: true,
    axisLabel: (p) => weekdayLabel(p.bucket!).substring(0, 1),
    pointLabel: (p) => weekdayLabel(p.bucket!),
    labelledIndices: (n, _) => {for (var i = 0; i < n; i++) i},
    table: (t, points) =>
        _bucketTable(t, points, t.l10n.analyticsColDay, weekdayLabel),
    wordInsight: _word,
  ),
];

String? _word(InsightWording w, AnalyticsInsight i) {
  final l10n = w.l10n;
  if (i.kind == streakInsight) {
    final current = (i.value ?? 0).round();
    final longest = (i.value2 ?? 0).round();
    return current > 0
        ? l10n.insightStreak(current, longest)
        : l10n.insightStreakRecordOnly(longest);
  }
  if (i.kind == peakHourInsight) {
    return l10n.insightPeakHour(hourLabel((i.value ?? 0).round()));
  }
  if (i.kind == peakWeekdayInsight) {
    return l10n.insightPeakWeekday(weekdayLabel((i.value ?? 1).round()));
  }
  return null;
}

/// Ridden days only.
ChartTable _calendarTable(ChartTableContext t, List<AnalyticsPoint> points) {
  final ridden = points.where((p) => (p.secondary ?? 0) > 0).toList();
  return ChartTable(
    headers: [t.l10n.analyticsColDate, t.l10n.analyticsColRides, t.kmHeader],
    displayRows: [
      for (final p in ridden.reversed)
        [
          longDate(p.date!),
          (p.secondary ?? 0).toStringAsFixed(0),
          formatAnalyticsNumber(p.value),
        ],
    ],
    csvRows: [
      for (final p in ridden)
        [
          isoDate(p.date!),
          (p.secondary ?? 0).toStringAsFixed(0),
          csvNum(p.value),
        ],
    ],
  );
}

ChartTable _bucketTable(
  ChartTableContext t,
  List<AnalyticsPoint> points,
  String bucketHeader,
  String Function(int bucket) label,
) =>
    ChartTable(
      headers: [bucketHeader, t.l10n.analyticsColRides, t.kmHeader],
      displayRows: [
        for (final p in points)
          [
            label(p.bucket!),
            p.value.toStringAsFixed(0),
            formatAnalyticsNumber(p.secondary ?? 0),
          ],
      ],
      csvRows: [
        for (final p in points)
          [
            label(p.bucket!),
            p.value.toStringAsFixed(0),
            csvNum(p.secondary ?? 0)
          ],
      ],
    );
