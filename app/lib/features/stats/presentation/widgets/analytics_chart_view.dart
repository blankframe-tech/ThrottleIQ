import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';

/// How a chart is drawn.
enum _Shape { line, bars, stacked, heatmap, ranked }

_Shape _shapeOf(AnalyticsChart c) => switch (c) {
      AnalyticsChart.distancePerRide ||
      AnalyticsChart.avgSpeed ||
      AnalyticsChart.topSpeed ||
      AnalyticsChart.ridingScore ||
      AnalyticsChart.maxLean ||
      AnalyticsChart.peakG =>
        _Shape.line,
      AnalyticsChart.movingVsStopped => _Shape.stacked,
      AnalyticsChart.activityCalendar => _Shape.heatmap,
      AnalyticsChart.distanceByBike ||
      AnalyticsChart.longestRides =>
        _Shape.ranked,
      _ => _Shape.bars,
    };

/// Draws one [AnalyticsChart] from its series.
///
/// [detailed] is the large version in the detail view: taller, with a value
/// axis, more x labels and touch tooltips. The compact version on the list
/// card stays a sparkline-weight glance.
class AnalyticsChartView extends StatelessWidget {
  final AnalyticsChart chart;
  final List<AnalyticsPoint> points;
  final bool detailed;
  final String Function(String bikeId) bikeName;

  const AnalyticsChartView({
    super.key,
    required this.chart,
    required this.points,
    required this.bikeName,
    this.detailed = false,
  });

  double get _height => detailed ? 240 : 92;

  @override
  Widget build(BuildContext context) {
    final shape = _shapeOf(chart);
    final hasData = switch (shape) {
      _Shape.line => points.length >= 2,
      _Shape.heatmap => points.any((p) => p.value > 0),
      _Shape.bars
          when chart == AnalyticsChart.hourOfDay ||
              chart == AnalyticsChart.weekday =>
        points.any((p) => p.value > 0),
      _ => points.isNotEmpty,
    };
    if (!hasData) {
      return SizedBox(
        height: _height,
        child: Center(
          child: Text(
            context.l10n.notEnoughRidesYet,
            style: TextStyle(color: context.palette.textTertiary, fontSize: 12),
          ),
        ),
      );
    }
    return switch (shape) {
      _Shape.line => _line(context),
      _Shape.bars => _bars(context, stacked: false),
      _Shape.stacked => _bars(context, stacked: true),
      _Shape.heatmap => _heatmap(context),
      _Shape.ranked => _ranked(context),
    };
  }

  TextStyle _axisStyle(BuildContext context) => TextStyle(
      fontSize: detailed ? 10 : 9, color: context.palette.textTertiary);

  String _xLabel(int i) {
    final p = points[i];
    if (p.bucket != null) {
      return chart == AnalyticsChart.hourOfDay
          ? p.bucket!.toString()
          : weekdayLabel(p.bucket!).substring(0, 1);
    }
    return p.date == null ? '' : shortDate(p.date!);
  }

  /// Indices that get an x label.
  Set<int> _labelledIndices() {
    final n = points.length;
    if (chart == AnalyticsChart.hourOfDay) {
      return detailed ? {0, 3, 6, 9, 12, 15, 18, 21} : {0, 6, 12, 18};
    }
    if (chart == AnalyticsChart.weekday) return {for (var i = 0; i < n; i++) i};
    if (n <= 1) return {0};
    return detailed ? {0, (n - 1) ~/ 2, n - 1} : {0, n - 1};
  }

  FlTitlesData _titles(BuildContext context, double maxY) {
    final labelled = _labelledIndices();
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: detailed,
          reservedSize: 38,
          interval: maxY > 0 ? maxY / 2 : null,
          getTitlesWidget: (v, meta) {
            if (v > meta.max + 1e-9) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(formatChartNumber(chart, v),
                  textAlign: TextAlign.right, style: _axisStyle(context)),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 18,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.round();
            if ((v - i).abs() > 1e-6 ||
                i < 0 ||
                i >= points.length ||
                !labelled.contains(i)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
              child: Text(_xLabel(i), style: _axisStyle(context)),
            );
          },
        ),
      ),
    );
  }

  String _tooltip(BuildContext context, int i) {
    final p = points[i];
    final unit = chartUnit(context.l10n, chart);
    final head = p.bucket != null
        ? (chart == AnalyticsChart.hourOfDay
            ? hourLabel(p.bucket!)
            : weekdayLabel(p.bucket!))
        : (p.date == null ? '' : shortDate(p.date!));
    return '$head\n${formatWithUnit(p.value, unit)}';
  }

  Widget _line(BuildContext context) {
    final color = chartColor(context, chart);
    final values = points.map((p) => p.value).toList();
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    var pad = (maxV - minV) * 0.15;
    // g-forces span 0–1.5: a whole-unit floor would flatten the line.
    final minPad = chart == AnalyticsChart.peakG ? 0.05 : 1.0;
    if (pad < minPad) pad = minPad;
    final minY = math.max(0.0, minV - pad);
    final maxY = maxV + pad;
    var peak = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[peak]) peak = i;
    }
    return SizedBox(
      height: _height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          gridData: FlGridData(
            show: detailed,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : null,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: context.palette.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: _titles(context, maxY),
          lineTouchData: LineTouchData(
            enabled: detailed,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => context.palette.surfaceVariant,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    _tooltip(context, s.x.round()),
                    TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              barWidth: detailed ? 2.5 : 2,
              color: color,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) =>
                    detailed && values.length <= 40 || spot.x.round() == peak,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: spot.x.round() == peak ? 3.5 : 2,
                  color: color,
                  strokeWidth: 1.5,
                  strokeColor: context.palette.surface,
                ),
              ),
              belowBarData:
                  BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bars(BuildContext context, {required bool stacked}) {
    final color = chartColor(context, chart);
    final rest = context.palette.warning;
    final maxV = stacked ? 100.0 : points.map((p) => p.value).reduce(math.max);
    final maxY = maxV <= 0 ? 1.0 : maxV * (stacked ? 1 : 1.1);
    return SizedBox(
      height: _height,
      child: LayoutBuilder(builder: (context, c) {
        final usable = c.maxWidth - (detailed ? 38 : 0);
        final width =
            (usable / points.length * 0.62).clamp(2.0, detailed ? 22.0 : 14.0);
        return BarChart(
          BarChartData(
            maxY: maxY,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              show: detailed,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: context.palette.border, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: _titles(context, maxY),
            barTouchData: BarTouchData(
              enabled: detailed,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => context.palette.surfaceVariant,
                getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                  _tooltip(context, gi),
                  TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textPrimary),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: stacked ? 100 : points[i].value,
                    width: width,
                    color: stacked ? null : color,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(width / 3)),
                    rodStackItems: stacked
                        ? [
                            BarChartRodStackItem(0, points[i].value, color),
                            BarChartRodStackItem(points[i].value, 100,
                                rest.withValues(alpha: 0.55)),
                          ]
                        : const [],
                  ),
                ]),
            ],
          ),
        );
      }),
    );
  }

  Widget _heatmap(BuildContext context) {
    // Pad to whole Monday-first weeks; cap the detail view at 26 weeks so cells stay tappable-sized.
    var days = points;
    final maxDays = detailed ? 26 * 7 : 12 * 7;
    if (days.length > maxDays) days = days.sublist(days.length - maxDays);
    final lead = (days.first.date!.weekday - DateTime.monday);
    final cells = <AnalyticsPoint?>[
      for (var i = 0; i < lead; i++) null,
      ...days,
    ];
    final weeks = (cells.length / 7).ceil();
    final maxV = days.map((p) => p.value).fold<double>(0, math.max);
    final color = chartColor(context, chart);
    final gap = detailed ? 3.0 : 2.0;
    return LayoutBuilder(builder: (context, c) {
      final labelW = detailed ? 16.0 : 0.0;
      final size = math.min(
        (c.maxWidth - labelW - gap * (weeks - 1)) / weeks,
        detailed ? 18.0 : (_height - gap * 6) / 7,
      );
      Widget cell(AnalyticsPoint? p) {
        Color fill;
        if (p == null) {
          fill = Colors.transparent;
        } else if (p.value <= 0) {
          fill = context.palette.border;
        } else {
          final t = maxV <= 0 ? 1.0 : (p.value / maxV);
          fill = color.withValues(alpha: 0.3 + 0.7 * t);
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: fill, borderRadius: BorderRadius.circular(size / 4)),
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detailed)
            SizedBox(
              width: labelW,
              child: Column(children: [
                for (var d = 1; d <= 7; d++)
                  SizedBox(
                    height: size + (d < 7 ? gap : 0),
                    child: d.isOdd
                        ? Text(weekdayLabel(d).substring(0, 1),
                            style: _axisStyle(context))
                        : null,
                  ),
              ]),
            ),
          for (var w = 0; w < weeks; w++)
            Padding(
              padding: EdgeInsets.only(right: w < weeks - 1 ? gap : 0),
              child: Column(children: [
                for (var d = 0; d < 7; d++)
                  Padding(
                    padding: EdgeInsets.only(bottom: d < 6 ? gap : 0),
                    child: cell(
                        w * 7 + d < cells.length ? cells[w * 7 + d] : null),
                  ),
              ]),
            ),
        ],
      );
    });
  }

  Widget _ranked(BuildContext context) {
    final color = chartColor(context, chart);
    final rows = detailed ? points : points.take(3).toList();
    final maxV = rows.map((p) => p.value).fold<double>(0, math.max);
    String label(AnalyticsPoint p) => chart == AnalyticsChart.distanceByBike
        ? bikeName(p.key)
        : (p.date == null ? '' : longDate(p.date!));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final p in rows)
          Padding(
            padding: EdgeInsets.symmetric(vertical: detailed ? 5 : 3),
            child: Row(
              children: [
                SizedBox(
                  width: detailed ? 120 : 96,
                  child: Text(label(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: detailed ? 12 : 11,
                          color: context.palette.textSecondary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxV <= 0 ? 0 : p.value / maxV,
                      minHeight: detailed ? 12 : 8,
                      backgroundColor: context.palette.border,
                      color: color,
                    ),
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(formatWithUnit(p.value, 'km'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: detailed ? 12 : 11,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
