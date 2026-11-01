import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:throttleiq/features/stats/domain/charts/fuel_charts.dart';
import 'package:throttleiq/features/stats/domain/ride_analytics.dart';
import 'package:throttleiq/features/stats/presentation/analytics_chart_registry.dart';
import 'package:throttleiq/features/stats/presentation/fuel_chart_units.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('converts fuel efficiency and distance to imperial', () {
    const points = [
      AnalyticsPoint(key: 'a', value: 20, secondary: 100),
    ];

    final converted = convertFuelChartPoints(
      FuelCharts.fuelEfficiency,
      points,
      true,
    );

    expect(converted.single.value, closeTo(47.04, 0.02));
    expect(converted.single.secondary, closeTo(62.14, 0.02));

    // The original metric data must remain unchanged.
    expect(points.single.value, 20);
    expect(points.single.secondary, 100);
  });

  test('metric mode preserves the original data', () {
    const points = [
      AnalyticsPoint(key: 'a', value: 20, secondary: 100),
    ];

    final result = convertFuelChartPoints(
      FuelCharts.fuelEfficiency,
      points,
      false,
    );

    expect(result, same(points));
  });

  test('imperial fuel cost has matching title, units and CSV', () {
    final l10n = AppLocalizationsEn();
    const chart = FuelCharts.fuelCostPerKm;

    final converted = convertFuelChartPoints(
      chart,
      [
        AnalyticsPoint(
          key: 'a',
          date: DateTime(2026, 11, 1),
          value: 3,
          secondary: 100,
        ),
      ],
      true,
    );

    final title = fuelChartTitleOverride(chart, l10n, true)!;
    final unit = fuelChartUnitOverride(chart, l10n, true)!;

    expect(title, 'Fuel cost per mile');
    expect(unit, '৳/mi');
    expect(converted.single.value, closeTo(4.828032, 0.000001));

    final table = chartPresentationOf(chart).buildTable(
      l10n,
      converted,
      bikeName: (_) => 'Bike',
      titleOverride: title,
      unitOverride: unit,
      distanceUnitOverride: l10n.unitDistanceMi,
    );

    expect(table.headers[1], contains('Fuel cost per mile'));
    expect(table.headers[2], contains('(mi)'));
    expect(
      double.parse(table.csvRows.single[1].toString()),
      closeTo(4.83, 0.01),
    );
  });

  test('unrelated fuel metrics are not converted', () {
    const points = [
      AnalyticsPoint(key: 'a', value: 10, secondary: 2),
    ];

    expect(
      convertFuelChartPoints(FuelCharts.fuelLiters, points, true),
      same(points),
    );
    expect(
      convertFuelChartPoints(FuelCharts.fuelSpend, points, true),
      same(points),
    );
  });
}
