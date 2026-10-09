import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/i18n/l10n_context.dart';
import '../../../../core/theme/app_theme_context.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../maintenance/domain/entities/fuel_log.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';
import '../widgets/analytics_chart_view.dart';
import '../../../../core/utils/error_reporter.dart';

/// Full-screen view of one analytics chart: a larger chart, a time range
/// selector, summary stats with the trend vs the previous period, a
/// plain-language insight, the per-ride/per-day table and a CSV export.
class AnalyticsDetailScreen extends StatefulWidget {
  final AnalyticsChart chart;
  final List<RideEntity> rides;
  final Map<String, String> bikeNames;

  /// Every fill-up on the rider's bikes; only the fuel charts read it.
  final List<FuelLogEntity> fuelLogs;

  /// Injectable clock for tests.
  final DateTime? now;

  const AnalyticsDetailScreen({
    super.key,
    required this.chart,
    required this.rides,
    this.bikeNames = const {},
    this.fuelLogs = const [],
    this.now,
  });

  @override
  State<AnalyticsDetailScreen> createState() => _AnalyticsDetailScreenState();
}

class _AnalyticsDetailScreenState extends State<AnalyticsDetailScreen> {
  late AnalyticsRange _range;
  final _downloadKey = GlobalKey();
  bool _exporting = false;

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    // The shortest range that has something to show; per-ride trend charts
    // need two rides to draw a line.
    final chart = widget.chart;
    final need = isPerRideChart(chart) || isFuelSegmentChart(chart) ? 2 : 1;
    bool hasData(AnalyticsRange r) {
      if (!isFuelChart(chart)) {
        return ridesInRange(widget.rides, r, _now).length >= need;
      }
      final series = buildFuelSeries(chart, widget.fuelLogs,
          now: _now, window: rangeWindow(r, _now));
      return series.where((p) => p.value > 0).length >= need;
    }

    _range = [
      AnalyticsRange.days30,
      AnalyticsRange.days90,
      AnalyticsRange.year,
    ].firstWhere(hasData, orElse: () => AnalyticsRange.all);
  }

  String _bikeName(String id) =>
      widget.bikeNames[id] ?? context.l10n.analyticsUnknownBike;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chart = widget.chart;
    final now = _now;
    final window = rangeWindow(_range, now);
    final fuel = isFuelChart(chart);
    final current = ridesInWindow(widget.rides, window);
    final previous =
        ridesInWindow(widget.rides, previousRangeWindow(_range, now));
    final List<AnalyticsPoint> series;
    final double? trend;
    final List<AnalyticsInsight> insights;
    final int count;
    if (fuel) {
      final logs = widget.fuelLogs;
      final previousWindow = previousRangeWindow(_range, now);
      series = buildFuelSeries(chart, logs, now: now, window: window);
      trend = previousWindow == null
          ? null
          : trendPercent(fuelPeriodAggregate(chart, logs, window),
              fuelPeriodAggregate(chart, logs, previousWindow));
      insights = buildFuelInsights(chart, logs, series, trend: trend);
      count = fuelLogsInWindow(logs, window).length;
    } else {
      series = buildSeries(chart, current, now: now, window: window);
      trend = trendPercent(
          periodAggregate(chart, current), periodAggregate(chart, previous));
      insights = buildInsights(chart, current, series, now: now, trend: trend);
      count = current.length;
    }
    final summary = MetricSummary.of(series.map((p) => p.value));
    final table = buildChartTable(l10n, chart, series, bikeName: _bikeName);
    final unit = chartUnit(l10n, chart);
    final title = chartTitle(l10n, chart);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        foregroundColor: context.palette.textPrimary,
        elevation: 0,
        title: Text(title, style: display(context, 18)),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            AppDimensions.paddingMd, 8, AppDimensions.paddingMd, 12),
        child: FilledButton.icon(
          key: _downloadKey,
          // Colours come from the active theme's FilledButton/ColorScheme.
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
          ),
          onPressed: _exporting || table.csvRows.isEmpty
              ? null
              : () => _export(title, table),
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined, size: 18),
          label: Text(l10n.analyticsDownloadData),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingMd, 4, AppDimensions.paddingMd, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _RangeSelector(
                  value: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
                const SizedBox(height: 12),
                EditorialCard(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 10),
                  child: AnalyticsChartView(
                    chart: chart,
                    points: series,
                    bikeName: _bikeName,
                    detailed: true,
                  ),
                ),
                if (chart == AnalyticsChart.movingVsStopped) ...[
                  const SizedBox(height: 8),
                  _Legend(items: [
                    (chartColor(context, chart), l10n.analyticsColMoving),
                    (
                      context.palette.warning.withValues(alpha: 0.55),
                      l10n.analyticsColStopped
                    ),
                  ]),
                ],
                const SizedBox(height: 12),
                _SummaryGrid(
                  chart: chart,
                  summary: summary,
                  unit: unit,
                  rideCount: count,
                  countLabel:
                      fuel ? l10n.analyticsColFillUps : l10n.analyticsColRides,
                  trend: trend,
                ),
                const SizedBox(height: 12),
                EditorialLabel(l10n.analyticsInsight),
                const SizedBox(height: 6),
                EditorialCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 18, color: context.palette.attention),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insights
                              .map((i) => insightText(l10n, chart, i,
                                  bikeName: _bikeName))
                              .join(' '),
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: context.palette.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                EditorialLabel(l10n.analyticsData),
                const SizedBox(height: 6),
                if (table.displayRows.isNotEmpty)
                  _TableRow(cells: table.headers, header: true),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingMd, 0, AppDimensions.paddingMd, 16),
            sliver: table.displayRows.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          fuel
                              ? l10n.fuelChartEmptyHint
                              : l10n.insightNotEnoughData,
                          style: TextStyle(
                              fontSize: 12,
                              color: context.palette.textTertiary)),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _TableRow(cells: table.displayRows[i]),
                      childCount: table.displayRows.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(String title, ChartTable table) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    Rect? origin;
    final box = _downloadKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    setState(() => _exporting = true);
    try {
      final csv = toCsv(table.headers, table.csvRows);
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now();
      final name = 'throttleiq_${widget.chart.name}_${_range.name}_'
          '${stamp.year}${stamp.month.toString().padLeft(2, '0')}'
          '${stamp.day.toString().padLeft(2, '0')}.csv';
      final file = File('${dir.path}/$name');
      // UTF-8 BOM so spreadsheet apps read Bangla bike names correctly.
      await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: l10n.analyticsShareSubject(title),
        sharePositionOrigin: origin,
      );
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'analytics CSV export');
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.analyticsExportFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _RangeSelector extends StatelessWidget {
  final AnalyticsRange value;
  final ValueChanged<AnalyticsRange> onChanged;
  const _RangeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final r in AnalyticsRange.values)
            Expanded(
              child: Semantics(
                selected: r == value,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: r == value ? p.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: r == value ? Border.all(color: p.border) : null,
                    ),
                    child: Text(
                      rangeLabel(context.l10n, r),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            r == value ? FontWeight.w700 : FontWeight.w500,
                        color: r == value ? p.textPrimary : p.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final AnalyticsChart chart;
  final MetricSummary summary;
  final String unit;
  final int rideCount;
  final String countLabel;
  final double? trend;

  const _SummaryGrid({
    required this.chart,
    required this.summary,
    required this.unit,
    required this.rideCount,
    required this.countLabel,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String v(double x) => summary.isEmpty ? '—' : formatWithUnit(x, unit);
    // A total of averages (speeds, scores, shares, km/L) means nothing, so
    // those show the ride (or fill-up) count in its place.
    final meanMetric = aggregationFor(chart) == Aggregation.mean &&
        (isPerRideChart(chart) || isFuelSegmentChart(chart));
    final better = higherIsBetter(chart);
    Color trendColor = context.palette.textPrimary;
    if (trend != null && better != null && trend!.abs() >= 3) {
      final good = (trend! > 0) == better;
      trendColor = good ? context.palette.success : context.palette.danger;
    }
    final cells = <(String, String, Color?)>[
      (l10n.analyticsMin, v(summary.min), null),
      (l10n.analyticsMax, v(summary.max), null),
      (l10n.analyticsAvg, v(summary.avg), null),
      meanMetric
          ? (countLabel, '$rideCount', null)
          : (l10n.analyticsTotal, v(summary.total), null),
      (
        l10n.analyticsTrend,
        trend == null
            ? l10n.analyticsNoTrend
            : '${trend! >= 0 ? '+' : '−'}${trend!.abs().toStringAsFixed(0)}%',
        trendColor,
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final w = (c.maxWidth - gap * 2) / 3;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final cell in cells)
            SizedBox(
              width: cell.$1 == l10n.analyticsTrend ? w * 2 + gap : w,
              child: EditorialCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cell.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: display(context, 15,
                            color: cell.$3 ?? context.palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(cell.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: context.palette.textSecondary)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _Legend extends StatelessWidget {
  final List<(Color, String)> items;
  const _Legend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      children: [
        for (final (color, label) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: context.palette.textSecondary)),
          ]),
      ],
    );
  }
}

class _TableRow extends StatelessWidget {
  final List<String> cells;
  final bool header;
  const _TableRow({required this.cells, this.header = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? 3 : 2,
              child: Text(
                cells[i],
                maxLines: header ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                style: TextStyle(
                  fontSize: header ? 11 : 12,
                  fontWeight: header ? FontWeight.w600 : FontWeight.w400,
                  color: header ? p.textSecondary : p.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
