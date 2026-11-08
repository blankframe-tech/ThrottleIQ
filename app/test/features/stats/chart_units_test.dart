import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:throttleiq/features/maintenance/domain/entities/fuel_log.dart';
import 'package:throttleiq/features/stats/domain/charts/bike_charts.dart';
import 'package:throttleiq/features/stats/domain/charts/fuel_charts.dart';
import 'package:throttleiq/features/stats/domain/charts/ride_basics_charts.dart';
import 'package:throttleiq/features/stats/domain/ride_analytics.dart';
import 'package:throttleiq/features/stats/presentation/analytics_chart_l10n.dart';
import 'package:throttleiq/features/stats/presentation/analytics_chart_registry.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

const _mi = 1 / 1.609344;

FuelLogEntity _fill(String id, DateTime at, double odo, double liters) =>
    FuelLogEntity(
      id: id,
      bikeId: 'b1',
      filledAt: at,
      odometerKm: odo,
      liters: liters,
      totalCost: liters * 100,
      pricePerLiter: 100,
      fullTank: true,
      createdAt: at,
      updatedAt: at,
    );

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('chartDisplayValue converts only when imperial', () {
    for (final k in ChartUnitKind.values) {
      expect(chartDisplayValue(k, 42, imperial: false), 42);
    }
    expect(chartDisplayValue(ChartUnitKind.none, 42, imperial: true), 42);
    expect(
      chartDisplayValue(ChartUnitKind.distance, 100, imperial: true),
      closeTo(62.1371, 1e-3),
    );
    expect(
      chartDisplayValue(ChartUnitKind.speed, 100, imperial: true),
      closeTo(62.1371, 1e-3),
    );
    // 40 km/L = 94.1 mpg (US).
    expect(
      chartDisplayValue(ChartUnitKind.efficiency, 40, imperial: true),
      closeTo(94.09, 0.01),
    );
    expect(
      chartDisplayValue(ChartUnitKind.costPerDistance, 2, imperial: true),
      closeTo(3.2187, 1e-3),
    );
  });

  test('each unit-bearing chart flips unit and values with imperial', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final cases = <AnalyticsChart, (String, String, double)>{
      RideBasicsCharts.distancePerRide: ('km', 'mi', _mi),
      RideBasicsCharts.weeklyDistance: ('km', 'mi', _mi),
      RideBasicsCharts.avgSpeed: ('km/h', 'mph', _mi),
      RideBasicsCharts.topSpeed: ('km/h', 'mph', _mi),
      BikeCharts.distanceByBike: ('km', 'mi', _mi),
      BikeCharts.longestRides: ('km', 'mi', _mi),
      FuelCharts.fuelEfficiency: ('km/L', 'mpg', 3.785411784 / 1.609344),
      FuelCharts.fuelCostPerKm: ('৳/km', '৳/mi', 1.609344),
    };
    const pts = [AnalyticsPoint(key: 'a', value: 10, secondary: 5)];
    cases.forEach((chart, c) {
      final spec = chartPresentationOf(chart);
      expect(spec.unitOf(l10n), c.$1, reason: chart.id);
      expect(spec.unitOf(l10n, imperial: true), c.$2, reason: chart.id);
      expect(spec.displayPoints(pts, imperial: false), same(pts));
      expect(
        spec.displayPoints(pts, imperial: true).single.value,
        closeTo(10 * c.$3, 1e-9),
        reason: chart.id,
      );
    });
  });

  test('litres and spend stay put when imperial', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    for (final c in [FuelCharts.fuelSpend, FuelCharts.fuelLiters]) {
      final spec = chartPresentationOf(c);
      expect(spec.unitOf(l10n, imperial: true), spec.unit(l10n));
      const pts = [AnalyticsPoint(key: 'a', value: 10)];
      expect(spec.displayPoints(pts, imperial: true), same(pts));
    }
  });

  test('fuel efficiency table and insight read in mpg and miles', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final logs = [
      _fill('a', DateTime(2026, 9, 1), 1000, 8),
      _fill('b', DateTime(2026, 9, 10), 1200, 5), // 200 km / 5 L = 40 km/L
    ];
    final now = DateTime(2026, 10, 1);
    final spec = chartPresentationOf(FuelCharts.fuelEfficiency);
    final series = FuelCharts.fuelEfficiency.series(logs, now: now);
    final shown = spec.displayPoints(series, imperial: true);
    final t = spec.buildTable(
      l10n,
      shown,
      bikeName: (id) => id,
      imperial: true,
    );
    expect(t.headers, ['Date', 'Fuel efficiency (mpg)', 'Distance (mi)']);
    expect(t.displayRows.single[1], '94.1');
    expect(t.displayRows.single[2], '124');
    final insight = FuelCharts.fuelEfficiency.insights(logs, series).single;
    expect(
      spec.insightText(l10n, insight, bikeName: (id) => id, imperial: true),
      'Average 94 mpg over 1 full-tank stretch.',
    );
  });

  test('distance table headers follow imperial', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final spec = chartPresentationOf(BikeCharts.distanceByBike);
    final km = spec.buildTable(l10n, const [], bikeName: (id) => id);
    expect(km.headers.last, 'Total (km)');
    final mi = spec.buildTable(
      l10n,
      const [],
      bikeName: (id) => id,
      imperial: true,
    );
    expect(mi.headers.last, 'Total (mi)');
  });
}
