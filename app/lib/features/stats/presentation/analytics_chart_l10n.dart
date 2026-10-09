import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/numeric_locale.dart';
import '../../../core/theme/app_theme_context.dart';
import '../../../core/theme/app_theme_style.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/ride_analytics.dart';

/// Wording, units, colours, shape and table layout of the analytics charts.
///
/// The numbers come from `ride_analytics.dart`; this file only decides how
/// they read. It knows no individual chart: each family's
/// [ChartPresentation]s live under `charts/`, and
/// `analytics_chart_registry.dart` lists them. Dates follow the app-wide
/// English style ("8 Oct") in every language, via [kNumericLocale].

/// The app's currency symbol. Amounts are written `৳1,200`, rates `৳2.6/km`.
const String kCurrencySymbol = '৳';

String rangeLabel(AppLocalizations l10n, AnalyticsRange r) => switch (r) {
      AnalyticsRange.days7 => l10n.analyticsRange7d,
      AnalyticsRange.days30 => l10n.analyticsRange30d,
      AnalyticsRange.days90 => l10n.analyticsRange90d,
      AnalyticsRange.year => l10n.analyticsRange1y,
      AnalyticsRange.all => l10n.analyticsRangeAll,
    };

// ─── Formatting ────────────────────────────────────────────────────────────

/// Whole numbers stay whole; small values keep one decimal.
String formatAnalyticsNumber(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e9) return v.toStringAsFixed(0);
  return v.abs() >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

String formatWithUnit(double v, String unit) {
  final n = unit == 'g' ? v.toStringAsFixed(2) : formatAnalyticsNumber(v);
  if (unit.isEmpty) return n;
  if (unit == '%' || unit == '°') return '$n$unit';
  // Currency leads: ৳1200, ৳2.6/km.
  if (unit.startsWith(kCurrencySymbol)) {
    return '$kCurrencySymbol$n${unit.substring(kCurrencySymbol.length)}';
  }
  return '$n $unit';
}

String shortDate(DateTime d) => DateFormat('d MMM', kNumericLocale).format(d);
String longDate(DateTime d) => DateFormat('d MMM y', kNumericLocale).format(d);

/// "Oct" — a month bar's axis label.
String shortMonth(DateTime d) => DateFormat('MMM', kNumericLocale).format(d);

/// "Oct 2026" — a month in tooltips, tables and insights.
String longMonth(DateTime d) => DateFormat('MMM y', kNumericLocale).format(d);

/// CSV cells: ISO dates and plain numbers.
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String isoMonth(DateTime d) => DateFormat('yyyy-MM').format(d);
String isoDateTime(DateTime d) => DateFormat('yyyy-MM-dd HH:mm').format(d);
String csvNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

String hourLabel(int h) => '${h.toString().padLeft(2, '0')}:00';

/// Short English weekday name ("Mon") for an ISO weekday, matching the
/// app's English-style dates.
String weekdayLabel(int isoWeekday) => DateFormat.E(
      kNumericLocale,
    ).format(DateTime(2024, 1, isoWeekday)); // 1 Jan 2024 was a Monday.

// ─── Tables ────────────────────────────────────────────────────────────────

/// A chart's data as a table: display cells for the screen (newest first)
/// and raw cells for CSV (oldest first, ISO dates, plain numbers).
class ChartTable {
  final List<String> headers;
  final List<List<String>> displayRows;
  final List<List<Object?>> csvRows;

  const ChartTable({
    required this.headers,
    required this.displayRows,
    required this.csvRows,
  });
}

/// What a family's table builder gets to work with.
class ChartTableContext {
  final AppLocalizations l10n;

  /// The chart's unit.
  final String unit;

  /// "<chart title> (<unit>)".
  final String valueHeader;

  /// "Total (km)".
  final String kmHeader;
  final String Function(double v) formatValue;
  final String Function(String bikeId) bikeName;

  const ChartTableContext({
    required this.l10n,
    required this.unit,
    required this.valueHeader,
    required this.kmHeader,
    required this.formatValue,
    required this.bikeName,
  });

  /// "Header (unit)", or just the header for a unitless column.
  static String withUnit(String header, String unit) =>
      unit.isEmpty ? header : '$header ($unit)';
}

/// The default table: one row per point, its date and value.
ChartTable dateValueTable(ChartTableContext t, List<AnalyticsPoint> points) =>
    ChartTable(
      headers: [t.l10n.analyticsColDate, t.valueHeader],
      displayRows: [
        for (final p in points.reversed)
          [longDate(p.date!), t.formatValue(p.value)],
      ],
      csvRows: [
        for (final p in points) [isoDateTime(p.date!), csvNum(p.value)],
      ],
    );

// ─── The chart presentation spec ───────────────────────────────────────────

/// How a chart is drawn.
enum ChartShape { line, bars, stacked, heatmap, ranked }

/// What a family's insight wording gets to work with.
class InsightWording {
  final AppLocalizations l10n;

  /// The chart's unit.
  final String unit;
  final String Function(String bikeId) bikeName;

  const InsightWording({
    required this.l10n,
    required this.unit,
    required this.bikeName,
  });
}

String _dateLabel(AnalyticsPoint p) => p.date == null ? '' : shortDate(p.date!);
String _rankDate(AnalyticsPoint p, String Function(String) bikeName) =>
    p.date == null ? '' : longDate(p.date!);

/// First and last point (plus the middle in the detail view).
Set<int> _endsLabelled(int n, bool detailed) {
  if (n <= 1) return {0};
  return detailed ? {0, (n - 1) ~/ 2, n - 1} : {0, n - 1};
}

String _notEnoughRidesYet(AppLocalizations l10n) => l10n.notEnoughRidesYet;
String _insightNotEnoughData(AppLocalizations l10n) =>
    l10n.insightNotEnoughData;
String _ridesCount(AppLocalizations l10n) => l10n.analyticsColRides;

/// Everything about one chart that isn't math: wording, unit, icon, colour,
/// shape, axis labels, table layout and insight wording.
///
/// A family file under `charts/` builds one per chart of its domain family.
/// Defaults suit a dated, ride-based series.
class ChartPresentation {
  final AnalyticsChart chart;
  final String Function(AppLocalizations l10n) title;

  /// Unit of the plotted value; empty for a unitless score.
  final String Function(AppLocalizations l10n) unit;
  final IconData icon;
  final Color Function(AppColorPalette p) color;
  final ChartShape shape;

  /// Whether a rise is good news (true), bad news (false) or neither
  /// (null) — colours the trend figure.
  final bool? higherIsBetter;

  /// Axis and default-table numbers.
  final String Function(double v) formatValue;

  /// Least headroom above and below a line, in value units.
  final double lineMinPad;

  /// Bars that are all zero draw the empty state instead.
  final bool needsNonZero;

  /// The x-axis label under a point.
  final String Function(AnalyticsPoint p) axisLabel;

  /// The heading of a point's tooltip.
  final String Function(AnalyticsPoint p) pointLabel;

  /// Which of `count` points get an x label.
  final Set<int> Function(int count, bool detailed) labelledIndices;

  /// A ranked row's label.
  final String Function(AnalyticsPoint p, String Function(String) bikeName)
      rankLabel;

  /// The two halves of a stacked bar, for the detail view's legend.
  final (String, String) Function(AppLocalizations l10n)? stackLabels;

  final ChartTable Function(ChartTableContext t, List<AnalyticsPoint> points)
      table;

  /// Words the family's own insight kinds; null for kinds it doesn't own.
  final String? Function(InsightWording w, AnalyticsInsight i)? wordInsight;

  /// Shown in place of a chart without data.
  final String Function(AppLocalizations l10n) emptyChartText;

  /// The not-enough-data insight and empty-table text.
  final String Function(AppLocalizations l10n) emptyDataText;

  /// The summary's count cell when it replaces the total.
  final String Function(AppLocalizations l10n) countLabel;

  const ChartPresentation({
    required this.chart,
    required this.title,
    required this.unit,
    required this.icon,
    required this.color,
    required this.shape,
    this.higherIsBetter,
    this.formatValue = formatAnalyticsNumber,
    this.lineMinPad = 1.0,
    this.needsNonZero = false,
    this.axisLabel = _dateLabel,
    this.pointLabel = _dateLabel,
    this.labelledIndices = _endsLabelled,
    this.rankLabel = _rankDate,
    this.stackLabels,
    this.table = dateValueTable,
    this.wordInsight,
    this.emptyChartText = _notEnoughRidesYet,
    this.emptyDataText = _insightNotEnoughData,
    this.countLabel = _ridesCount,
  });

  Color colorOf(BuildContext context) => color(context.palette);

  /// Whether [points] are enough to draw.
  bool hasData(List<AnalyticsPoint> points) => switch (shape) {
        ChartShape.line => points.length >= 2,
        ChartShape.heatmap => points.any((p) => p.value > 0),
        _ when needsNonZero => points.any((p) => p.value > 0),
        _ => points.isNotEmpty,
      };

  String insightText(
    AppLocalizations l10n,
    AnalyticsInsight i, {
    required String Function(String bikeId) bikeName,
  }) {
    final u = unit(l10n);
    final own = wordInsight?.call(
      InsightWording(l10n: l10n, unit: u, bikeName: bikeName),
      i,
    );
    if (own != null) return own;
    String pct(double? v) => (v ?? 0).toStringAsFixed(0);
    if (i.kind == InsightKind.notEnoughData) return emptyDataText(l10n);
    if (i.kind == InsightKind.trendUp) return l10n.insightTrendUp(pct(i.value));
    if (i.kind == InsightKind.trendDown) {
      return l10n.insightTrendDown(pct(i.value));
    }
    if (i.kind == InsightKind.trendFlat) return l10n.insightTrendFlat;
    if (i.kind == InsightKind.peakValue) {
      return l10n.insightPeakValue(
        formatWithUnit(i.value ?? 0, u),
        shortDate(i.date!),
      );
    }
    throw StateError('${chart.id} has no wording for ${i.kind}');
  }

  ChartTable buildTable(
    AppLocalizations l10n,
    List<AnalyticsPoint> points, {
    required String Function(String bikeId) bikeName,
  }) {
    final u = unit(l10n);
    return table(
      ChartTableContext(
        l10n: l10n,
        unit: u,
        valueHeader: ChartTableContext.withUnit(title(l10n), u),
        kmHeader: ChartTableContext.withUnit(l10n.analyticsTotal, 'km'),
        formatValue: formatValue,
        bikeName: bikeName,
      ),
      points,
    );
  }
}
