import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/numeric_locale.dart';
import '../../../core/theme/app_theme_context.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/ride_analytics.dart';

/// Wording, units, colours and table layout for each [AnalyticsChart].
///
/// The numbers come from `ride_analytics.dart`; this file only decides how
/// they read. Dates follow the app-wide English style ("8 Oct") in every
/// language, via [kNumericLocale].

String chartTitle(AppLocalizations l10n, AnalyticsChart c) => switch (c) {
      AnalyticsChart.distancePerRide => l10n.chartDistancePerRide,
      AnalyticsChart.weeklyDistance => l10n.chartWeeklyDistance,
      AnalyticsChart.avgSpeed => l10n.chartAvgSpeed,
      AnalyticsChart.topSpeed => l10n.chartTopSpeed,
      AnalyticsChart.rideDuration => l10n.chartRideDuration,
      AnalyticsChart.movingVsStopped => l10n.chartMovingVsStopped,
      AnalyticsChart.jamTime => l10n.chartJamTime,
      AnalyticsChart.ridingScore => l10n.chartRidingScore,
      AnalyticsChart.hardBraking => l10n.chartHardBraking,
      AnalyticsChart.rapidAccel => l10n.chartRapidAccel,
      AnalyticsChart.overspeed => l10n.chartOverspeed,
      AnalyticsChart.activityCalendar => l10n.chartActivityCalendar,
      AnalyticsChart.hourOfDay => l10n.chartHourOfDay,
      AnalyticsChart.weekday => l10n.chartWeekday,
      AnalyticsChart.distanceByBike => l10n.chartDistanceByBike,
      AnalyticsChart.longestRides => l10n.chartLongestRides,
      AnalyticsChart.fuelSpend => l10n.chartFuelSpend,
      AnalyticsChart.fuelEfficiency => l10n.chartFuelEfficiency,
      AnalyticsChart.fuelCostPerKm => l10n.chartFuelCostPerKm,
      AnalyticsChart.fuelLiters => l10n.chartFuelLiters,
    };

/// The app's currency symbol. Amounts are written `৳1,200`, rates `৳2.6/km`.
const String kCurrencySymbol = '৳';

/// Unit of the plotted value; empty for a unitless score.
String chartUnit(AppLocalizations l10n, AnalyticsChart c) => switch (c) {
      AnalyticsChart.distancePerRide ||
      AnalyticsChart.weeklyDistance ||
      AnalyticsChart.activityCalendar ||
      AnalyticsChart.distanceByBike ||
      AnalyticsChart.longestRides =>
        'km',
      AnalyticsChart.avgSpeed || AnalyticsChart.topSpeed => 'km/h',
      AnalyticsChart.rideDuration ||
      AnalyticsChart.jamTime =>
        l10n.analyticsUnitMin,
      AnalyticsChart.movingVsStopped => '%',
      AnalyticsChart.ridingScore => '',
      AnalyticsChart.hardBraking ||
      AnalyticsChart.rapidAccel ||
      AnalyticsChart.overspeed =>
        l10n.analyticsUnitEvents,
      AnalyticsChart.hourOfDay ||
      AnalyticsChart.weekday =>
        l10n.analyticsUnitRides,
      AnalyticsChart.fuelSpend => kCurrencySymbol,
      AnalyticsChart.fuelEfficiency => 'km/L',
      AnalyticsChart.fuelCostPerKm => '$kCurrencySymbol/km',
      AnalyticsChart.fuelLiters => 'L',
    };

/// Whether a rise is good news (true), bad news (false) or neither (null) —
/// colours the trend figure.
bool? higherIsBetter(AnalyticsChart c) => switch (c) {
      AnalyticsChart.hardBraking ||
      AnalyticsChart.rapidAccel ||
      AnalyticsChart.overspeed ||
      AnalyticsChart.jamTime ||
      AnalyticsChart.fuelSpend ||
      AnalyticsChart.fuelCostPerKm =>
        false,
      AnalyticsChart.fuelEfficiency ||
      AnalyticsChart.ridingScore ||
      AnalyticsChart.distancePerRide ||
      AnalyticsChart.weeklyDistance ||
      AnalyticsChart.movingVsStopped ||
      AnalyticsChart.activityCalendar =>
        true,
      _ => null,
    };

Color chartColor(BuildContext context, AnalyticsChart c) {
  final p = context.palette;
  return switch (c) {
    AnalyticsChart.avgSpeed ||
    AnalyticsChart.rideDuration ||
    AnalyticsChart.hourOfDay ||
    AnalyticsChart.weekday =>
      p.secondary,
    AnalyticsChart.topSpeed || AnalyticsChart.rapidAccel => p.attention,
    AnalyticsChart.jamTime => p.warning,
    AnalyticsChart.hardBraking || AnalyticsChart.overspeed => p.danger,
    AnalyticsChart.ridingScore ||
    AnalyticsChart.movingVsStopped ||
    AnalyticsChart.fuelEfficiency =>
      p.success,
    AnalyticsChart.fuelSpend || AnalyticsChart.fuelCostPerKm => p.attention,
    AnalyticsChart.fuelLiters => p.secondary,
    _ => p.primary,
  };
}

IconData chartIcon(AnalyticsChart c) => switch (c) {
      AnalyticsChart.distancePerRide => Icons.route_outlined,
      AnalyticsChart.weeklyDistance => Icons.date_range_outlined,
      AnalyticsChart.avgSpeed => Icons.speed_outlined,
      AnalyticsChart.topSpeed => Icons.bolt_outlined,
      AnalyticsChart.rideDuration => Icons.timer_outlined,
      AnalyticsChart.movingVsStopped => Icons.pause_circle_outline,
      AnalyticsChart.jamTime => Icons.traffic_outlined,
      AnalyticsChart.ridingScore => Icons.verified_outlined,
      AnalyticsChart.hardBraking => Icons.warning_amber_outlined,
      AnalyticsChart.rapidAccel => Icons.trending_up,
      AnalyticsChart.overspeed => Icons.speed,
      AnalyticsChart.activityCalendar => Icons.calendar_month_outlined,
      AnalyticsChart.hourOfDay => Icons.schedule_outlined,
      AnalyticsChart.weekday => Icons.view_week_outlined,
      AnalyticsChart.distanceByBike => Icons.two_wheeler_outlined,
      AnalyticsChart.longestRides => Icons.emoji_events_outlined,
      AnalyticsChart.fuelSpend => Icons.payments_outlined,
      AnalyticsChart.fuelEfficiency => Icons.local_gas_station_outlined,
      AnalyticsChart.fuelCostPerKm => Icons.price_change_outlined,
      AnalyticsChart.fuelLiters => Icons.water_drop_outlined,
    };

String rangeLabel(AppLocalizations l10n, AnalyticsRange r) => switch (r) {
      AnalyticsRange.days7 => l10n.analyticsRange7d,
      AnalyticsRange.days30 => l10n.analyticsRange30d,
      AnalyticsRange.days90 => l10n.analyticsRange90d,
      AnalyticsRange.year => l10n.analyticsRange1y,
      AnalyticsRange.all => l10n.analyticsRangeAll,
    };

/// Whole numbers stay whole; small values keep one decimal.
String formatAnalyticsNumber(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e9) return v.toStringAsFixed(0);
  return v.abs() >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

String formatWithUnit(double v, String unit) {
  final n = formatAnalyticsNumber(v);
  if (unit.isEmpty) return n;
  if (unit == '%') return '$n%';
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
String _isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String _isoMonth(DateTime d) => DateFormat('yyyy-MM').format(d);
String _isoDateTime(DateTime d) => DateFormat('yyyy-MM-dd HH:mm').format(d);

String hourLabel(int h) => '${h.toString().padLeft(2, '0')}:00';

/// Short English weekday name ("Mon") for an ISO weekday, matching the
/// app's English-style dates.
String weekdayLabel(int isoWeekday) => DateFormat.E(kNumericLocale)
    .format(DateTime(2024, 1, isoWeekday)); // 1 Jan 2024 was a Monday.

String insightText(
  AppLocalizations l10n,
  AnalyticsChart chart,
  AnalyticsInsight i, {
  required String Function(String bikeId) bikeName,
}) {
  final unit = chartUnit(l10n, chart);
  String pct(double? v) => (v ?? 0).toStringAsFixed(0);
  switch (i.kind) {
    case InsightKind.notEnoughData:
      return isFuelChart(chart)
          ? l10n.fuelChartEmptyHint
          : l10n.insightNotEnoughData;
    case InsightKind.peakMonth:
      return l10n.insightPeakMonth(
          formatWithUnit(i.value ?? 0, unit), longMonth(i.date!));
    case InsightKind.fuelAverage:
      return l10n.insightFuelAverage(
          formatWithUnit(i.value ?? 0, unit), (i.value2 ?? 0).round());
    case InsightKind.fuelNeedFullFills:
      return l10n.insightFuelNeedFullFills;
    case InsightKind.trendUp:
      return l10n.insightTrendUp(pct(i.value));
    case InsightKind.trendDown:
      return l10n.insightTrendDown(pct(i.value));
    case InsightKind.trendFlat:
      return l10n.insightTrendFlat;
    case InsightKind.peakValue:
      return l10n.insightPeakValue(
          formatWithUnit(i.value ?? 0, unit), shortDate(i.date!));
    case InsightKind.peakHour:
      return l10n.insightPeakHour(hourLabel((i.value ?? 0).round()));
    case InsightKind.peakWeekday:
      return l10n.insightPeakWeekday(weekdayLabel((i.value ?? 1).round()));
    case InsightKind.topBike:
      return l10n.insightTopBike(bikeName(i.key ?? ''), pct(i.value));
    case InsightKind.streak:
      final current = (i.value ?? 0).round();
      final longest = (i.value2 ?? 0).round();
      return current > 0
          ? l10n.insightStreak(current, longest)
          : l10n.insightStreakRecordOnly(longest);
    case InsightKind.longestRide:
      return l10n.insightLongestRide(
          formatWithUnit(i.value ?? 0, 'km'), shortDate(i.date!));
    case InsightKind.cleanRides:
      return l10n.insightCleanRides(
          (i.value ?? 0).round(), (i.value2 ?? 0).round());
    case InsightKind.stoppedShare:
      return l10n.insightStoppedShare(pct(i.value));
  }
}

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

String _csvNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

ChartTable buildChartTable(
  AppLocalizations l10n,
  AnalyticsChart chart,
  List<AnalyticsPoint> points, {
  required String Function(String bikeId) bikeName,
}) {
  final unit = chartUnit(l10n, chart);
  String withUnit(String h, String u) => u.isEmpty ? h : '$h ($u)';
  final valueHeader = withUnit(chartTitle(l10n, chart), unit);
  final kmHeader = withUnit(l10n.analyticsTotal, 'km');

  if (isFuelMonthlyChart(chart)) {
    // Months with a fill-up only; the empty ones are just gaps in the bars.
    final filled = points.where((p) => (p.secondary ?? 0) > 0).toList();
    return ChartTable(
      headers: [l10n.analyticsColMonth, valueHeader, l10n.analyticsColFillUps],
      displayRows: [
        for (final p in filled.reversed)
          [
            longMonth(p.date!),
            formatAnalyticsNumber(p.value),
            (p.secondary ?? 0).toStringAsFixed(0),
          ],
      ],
      csvRows: [
        for (final p in filled)
          [
            _isoMonth(p.date!),
            _csvNum(p.value),
            (p.secondary ?? 0).toStringAsFixed(0),
          ],
      ],
    );
  }
  if (isFuelSegmentChart(chart)) {
    // One row per closing full-tank fill-up.
    return ChartTable(
      headers: [
        l10n.analyticsColDate,
        valueHeader,
        withUnit(l10n.analyticsColDistance, 'km'),
      ],
      displayRows: [
        for (final p in points.reversed)
          [
            longDate(p.date!),
            p.value.toStringAsFixed(
                chart == AnalyticsChart.fuelEfficiency ? 1 : 2),
            formatAnalyticsNumber(p.secondary ?? 0),
          ],
      ],
      csvRows: [
        for (final p in points)
          [
            _isoDateTime(p.date!),
            p.value.toStringAsFixed(3),
            _csvNum(p.secondary ?? 0),
          ],
      ],
    );
  }

  if (isPerRideChart(chart)) {
    if (chart == AnalyticsChart.movingVsStopped) {
      final rows = [
        for (final p in points) [p.date!, p.value, p.secondary],
      ];
      return ChartTable(
        headers: [
          l10n.analyticsColDate,
          withUnit(l10n.analyticsColMoving, '%'),
          withUnit(l10n.analyticsColStopped, l10n.analyticsUnitMin),
        ],
        displayRows: [
          for (final r in rows.reversed)
            [
              longDate(r[0] as DateTime),
              formatWithUnit(r[1] as double, '%'),
              r[2] == null ? '—' : formatAnalyticsNumber(r[2] as double),
            ],
        ],
        csvRows: [
          for (final r in rows)
            [
              _isoDateTime(r[0] as DateTime),
              _csvNum(r[1] as double),
              r[2] == null ? '' : _csvNum(r[2] as double),
            ],
        ],
      );
    }
    return ChartTable(
      headers: [l10n.analyticsColDate, valueHeader],
      displayRows: [
        for (final p in points.reversed)
          [longDate(p.date!), formatAnalyticsNumber(p.value)],
      ],
      csvRows: [
        for (final p in points) [_isoDateTime(p.date!), _csvNum(p.value)],
      ],
    );
  }

  switch (chart) {
    case AnalyticsChart.weeklyDistance:
      return ChartTable(
        headers: [l10n.analyticsColWeekOf, valueHeader],
        displayRows: [
          for (final p in points.reversed)
            [longDate(p.date!), formatAnalyticsNumber(p.value)],
        ],
        csvRows: [
          for (final p in points) [_isoDate(p.date!), _csvNum(p.value)],
        ],
      );
    case AnalyticsChart.activityCalendar:
      final ridden = points.where((p) => (p.secondary ?? 0) > 0).toList();
      return ChartTable(
        headers: [l10n.analyticsColDate, l10n.analyticsColRides, kmHeader],
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
              _isoDate(p.date!),
              (p.secondary ?? 0).toStringAsFixed(0),
              _csvNum(p.value),
            ],
        ],
      );
    case AnalyticsChart.hourOfDay:
    case AnalyticsChart.weekday:
      final isHour = chart == AnalyticsChart.hourOfDay;
      String label(AnalyticsPoint p) =>
          isHour ? hourLabel(p.bucket!) : weekdayLabel(p.bucket!);
      return ChartTable(
        headers: [
          isHour ? l10n.analyticsColHour : l10n.analyticsColDay,
          l10n.analyticsColRides,
          kmHeader,
        ],
        displayRows: [
          for (final p in points)
            [
              label(p),
              p.value.toStringAsFixed(0),
              formatAnalyticsNumber(p.secondary ?? 0),
            ],
        ],
        csvRows: [
          for (final p in points)
            [label(p), p.value.toStringAsFixed(0), _csvNum(p.secondary ?? 0)],
        ],
      );
    case AnalyticsChart.distanceByBike:
      return ChartTable(
        headers: [l10n.analyticsColBike, l10n.analyticsColRides, kmHeader],
        displayRows: [
          for (final p in points)
            [
              bikeName(p.key),
              (p.secondary ?? 0).toStringAsFixed(0),
              formatAnalyticsNumber(p.value),
            ],
        ],
        csvRows: [
          for (final p in points)
            [
              bikeName(p.key),
              (p.secondary ?? 0).toStringAsFixed(0),
              _csvNum(p.value),
            ],
        ],
      );
    case AnalyticsChart.longestRides:
    default:
      return ChartTable(
        headers: [l10n.analyticsColDate, valueHeader],
        displayRows: [
          for (final p in points)
            [longDate(p.date!), formatAnalyticsNumber(p.value)],
        ],
        csvRows: [
          for (final p in points) [_isoDateTime(p.date!), _csvNum(p.value)],
        ],
      );
  }
}
