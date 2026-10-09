import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme_style.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/charts/fuel_charts.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';

/// Fuel (schema v27): spend, efficiency, cost per km and litres.
final List<ChartPresentation> fuelPresentations = [
  _monthly(
    FuelCharts.fuelSpend,
    title: (l) => l.chartFuelSpend,
    unit: kCurrencySymbol,
    icon: Icons.payments_outlined,
    color: (p) => p.attention,
    higherIsBetter: false,
  ),
  _stretch(
    FuelCharts.fuelEfficiency,
    title: (l) => l.chartFuelEfficiency,
    unit: 'km/L',
    icon: Icons.local_gas_station_outlined,
    color: (p) => p.success,
    higherIsBetter: true,
    displayDecimals: 1,
  ),
  _stretch(
    FuelCharts.fuelCostPerKm,
    title: (l) => l.chartFuelCostPerKm,
    unit: '$kCurrencySymbol/km',
    icon: Icons.price_change_outlined,
    color: (p) => p.attention,
    higherIsBetter: false,
    displayDecimals: 2,
  ),
  _monthly(
    FuelCharts.fuelLiters,
    title: (l) => l.chartFuelLiters,
    unit: 'L',
    icon: Icons.water_drop_outlined,
    color: (p) => p.secondary,
    higherIsBetter: null,
  ),
];

String _fuelHint(AppLocalizations l) => l.fuelChartEmptyHint;
String _fillUps(AppLocalizations l) => l.analyticsColFillUps;

/// One bar per calendar month.
ChartPresentation _monthly(
  FuelMonthlyChart chart, {
  required String Function(AppLocalizations l) title,
  required String unit,
  required IconData icon,
  required Color Function(AppColorPalette p) color,
  required bool? higherIsBetter,
}) =>
    ChartPresentation(
      chart: chart,
      title: title,
      unit: (_) => unit,
      icon: icon,
      color: color,
      shape: ChartShape.bars,
      higherIsBetter: higherIsBetter,
      needsNonZero: true,
      axisLabel: (p) => p.date == null ? '' : shortMonth(p.date!),
      pointLabel: (p) => p.date == null ? '' : longMonth(p.date!),
      table: _monthlyTable,
      wordInsight: _word,
      emptyChartText: _fuelHint,
      emptyDataText: _fuelHint,
      countLabel: _fillUps,
    );

/// One point per full-to-full stretch.
ChartPresentation _stretch(
  FuelSegmentChart chart, {
  required String Function(AppLocalizations l) title,
  required String unit,
  required IconData icon,
  required Color Function(AppColorPalette p) color,
  required bool? higherIsBetter,
  required int displayDecimals,
}) =>
    ChartPresentation(
      chart: chart,
      title: title,
      unit: (_) => unit,
      icon: icon,
      color: color,
      shape: ChartShape.line,
      higherIsBetter: higherIsBetter,
      table: (t, points) => _stretchTable(t, points, displayDecimals),
      wordInsight: _word,
      emptyChartText: _fuelHint,
      emptyDataText: _fuelHint,
      countLabel: _fillUps,
    );

String? _word(InsightWording w, AnalyticsInsight i) {
  if (i.kind == peakMonthInsight) {
    return w.l10n.insightPeakMonth(
      formatWithUnit(i.value ?? 0, w.unit),
      longMonth(i.date!),
    );
  }
  if (i.kind == fuelAverageInsight) {
    return w.l10n.insightFuelAverage(
      formatWithUnit(i.value ?? 0, w.unit),
      (i.value2 ?? 0).round(),
    );
  }
  if (i.kind == fuelNeedFullFillsInsight) {
    return w.l10n.insightFuelNeedFullFills;
  }
  return null;
}

/// Months with a fill-up only; the empty ones are just gaps in the bars.
ChartTable _monthlyTable(ChartTableContext t, List<AnalyticsPoint> points) {
  final filled = points.where((p) => (p.secondary ?? 0) > 0).toList();
  return ChartTable(
    headers: [
      t.l10n.analyticsColMonth,
      t.valueHeader,
      t.l10n.analyticsColFillUps,
    ],
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
          isoMonth(p.date!),
          csvNum(p.value),
          (p.secondary ?? 0).toStringAsFixed(0),
        ],
    ],
  );
}

/// One row per closing full-tank fill-up.
ChartTable _stretchTable(
  ChartTableContext t,
  List<AnalyticsPoint> points,
  int decimals,
) =>
    ChartTable(
      headers: [
        t.l10n.analyticsColDate,
        t.valueHeader,
        ChartTableContext.withUnit(t.l10n.analyticsColDistance, 'km'),
      ],
      displayRows: [
        for (final p in points.reversed)
          [
            longDate(p.date!),
            p.value.toStringAsFixed(decimals),
            formatAnalyticsNumber(p.secondary ?? 0),
          ],
      ],
      csvRows: [
        for (final p in points)
          [
            isoDateTime(p.date!),
            p.value.toStringAsFixed(3),
            csvNum(p.secondary ?? 0),
          ],
      ],
    );
