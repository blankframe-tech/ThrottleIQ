import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:throttleiq/features/maintenance/domain/entities/fuel_log.dart';
import 'package:throttleiq/features/stats/domain/ride_analytics.dart';
import 'package:throttleiq/features/stats/presentation/analytics_chart_l10n.dart';
import 'package:throttleiq/features/stats/presentation/screens/analytics_detail_screen.dart';
import 'package:throttleiq/features/stats/presentation/widgets/analytics_chart_card.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

final _now = DateTime(2026, 10, 9, 15);

FuelLogEntity _fill(String id, DateTime at, double odo, double liters,
        {bool full = true, double price = 130, String bike = 'b1'}) =>
    FuelLogEntity(
      id: id,
      bikeId: bike,
      filledAt: at,
      odometerKm: odo,
      liters: liters,
      totalCost: liters * price,
      pricePerLiter: price,
      fullTank: full,
      createdAt: at,
      updatedAt: at,
    );

/// Aug: baseline + one stretch; Sep: partial then full; Oct: one stretch.
List<FuelLogEntity> _logs() => [
      _fill('a', DateTime(2026, 8, 2), 1000, 8),
      _fill('b', DateTime(2026, 8, 20), 1200, 5), // 40 km/L
      _fill('p', DateTime(2026, 9, 5), 1300, 2, full: false),
      _fill('c', DateTime(2026, 9, 15), 1500, 6, price: 125), // 300/8 = 37.5
      _fill('d', DateTime(2026, 10, 3), 1750, 5), // 50 km/L
    ];

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

const _fuelCharts = [
  AnalyticsChart.fuelSpend,
  AnalyticsChart.fuelEfficiency,
  AnalyticsChart.fuelCostPerKm,
  AnalyticsChart.fuelLiters,
];

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('fuel charts are classified and aggregate correctly', () {
    expect(AnalyticsChart.values.where(isFuelChart), _fuelCharts);
    expect(isFuelMonthlyChart(AnalyticsChart.fuelSpend), isTrue);
    expect(isFuelSegmentChart(AnalyticsChart.fuelCostPerKm), isTrue);
    expect(aggregationFor(AnalyticsChart.fuelEfficiency), Aggregation.mean);
    expect(aggregationFor(AnalyticsChart.fuelSpend), Aggregation.sum);
    expect(isPerRideChart(AnalyticsChart.fuelSpend), isFalse);
  });

  group('monthly series', () {
    test('spend per month, empty months included, fill counts as secondary',
        () {
      final s = buildFuelSeries(AnalyticsChart.fuelSpend, _logs(), now: _now);
      expect(s.map((p) => p.key), ['2026-08', '2026-09', '2026-10']);
      expect(s.map((p) => p.value), [13 * 130.0, 2 * 130 + 6 * 125.0, 650.0]);
      expect(s.map((p) => p.secondary), [2, 2, 1]);
    });

    test('litres per month over a 90-day window starts at the window', () {
      final w = rangeWindow(AnalyticsRange.days90, _now);
      final s = buildFuelSeries(AnalyticsChart.fuelLiters, _logs(),
          now: _now, window: w);
      expect(s.first.key, '2026-07');
      expect(s.last.key, '2026-10');
      expect(s.map((p) => p.value), [0, 13, 8, 5]);
    });

    test('preview is the last six months', () {
      final s =
          buildFuelPreviewSeries(AnalyticsChart.fuelLiters, _logs(), now: _now);
      expect(s, hasLength(previewMonthCount));
      expect(s.first.key, '2026-05');
      expect(s.last.value, 5);
    });
  });

  group('stretch series', () {
    test('km/L per full-to-full stretch, partials folded in', () {
      final s =
          buildFuelSeries(AnalyticsChart.fuelEfficiency, _logs(), now: _now);
      expect(s.map((p) => p.key), ['b', 'c', 'd']);
      expect(s.map((p) => p.value), [40, 37.5, 50]);
      expect(s.map((p) => p.secondary), [200, 300, 250]);
    });

    test('cost per km', () {
      final s =
          buildFuelSeries(AnalyticsChart.fuelCostPerKm, _logs(), now: _now);
      expect(s[0].value, closeTo(650 / 200, 1e-9));
      expect(s[1].value, closeTo((260 + 750) / 300, 1e-9));
    });

    test('a window keeps stretches that end in it, measured from before it',
        () {
      final w = rangeWindow(AnalyticsRange.days30, _now); // Sep 9 – Oct 9
      final s = buildFuelSeries(AnalyticsChart.fuelEfficiency, _logs(),
          now: _now, window: w);
      // 'c' closes a stretch that opened at 'b' in August.
      expect(s.map((p) => p.key), ['c', 'd']);
      expect(s.first.secondary, 300);
    });
  });

  test('period aggregate and trend', () {
    final w = rangeWindow(AnalyticsRange.days30, _now);
    final prev = previousRangeWindow(AnalyticsRange.days30, _now);
    // Last 30 days: fills c (6 L at 125) and d (5 L at 130).
    expect(fuelPeriodAggregate(AnalyticsChart.fuelSpend, _logs(), w), 1400);
    // Stretches c and d: 550 km over 13 L (c's 8 L includes the partial).
    expect(fuelPeriodAggregate(AnalyticsChart.fuelEfficiency, _logs(), w),
        closeTo(550 / 13, 1e-9));
    // The 30 days before hold stretch b: 200 km / 5 L.
    expect(
        fuelPeriodAggregate(AnalyticsChart.fuelEfficiency, _logs(), prev), 40);
    // Whole history: 750 km over 18 L, not the mean of the three.
    expect(fuelPeriodAggregate(AnalyticsChart.fuelEfficiency, _logs(), null),
        closeTo(750 / 18, 1e-9));
    expect(fuelPeriodAggregate(AnalyticsChart.fuelSpend, const [], w), isNull);
    // Ride aggregates never answer for a fuel chart.
    expect(periodAggregate(AnalyticsChart.fuelSpend, const []), isNull);
  });

  group('insights', () {
    test('no fill-ups: the log-fuel hint', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      for (final c in _fuelCharts) {
        final i = buildFuelInsights(c, const [], const []);
        expect(i.single.kind, InsightKind.notEnoughData);
        expect(insightText(l10n, c, i.single, bikeName: (id) => id),
            'Log fuel fill-ups to see this');
      }
    });

    test('monthly: peak month, then trend', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final s = buildFuelSeries(AnalyticsChart.fuelSpend, _logs(), now: _now);
      final i =
          buildFuelInsights(AnalyticsChart.fuelSpend, _logs(), s, trend: -20);
      expect(
          i.map((x) => x.kind), [InsightKind.peakMonth, InsightKind.trendDown]);
      expect(
          insightText(l10n, AnalyticsChart.fuelSpend, i.first,
              bikeName: (id) => id),
          'Your highest was ৳1690 in Aug 2026.');
    });

    test('stretches: distance-weighted average, or ask for full fills',
        () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final s =
          buildFuelSeries(AnalyticsChart.fuelEfficiency, _logs(), now: _now);
      final i = buildFuelInsights(AnalyticsChart.fuelEfficiency, _logs(), s);
      expect(i.single.kind, InsightKind.fuelAverage);
      expect(i.single.value, closeTo(750 / 18, 1e-9));
      expect(
          insightText(l10n, AnalyticsChart.fuelEfficiency, i.single,
              bikeName: (id) => id),
          'Average 42 km/L over 3 full-tank stretches.');

      final onlyOne = [_logs().first];
      final none = buildFuelInsights(AnalyticsChart.fuelEfficiency, onlyOne,
          buildFuelSeries(AnalyticsChart.fuelEfficiency, onlyOne, now: _now));
      expect(none.single.kind, InsightKind.fuelNeedFullFills);
    });
  });

  test('tables and CSV', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final monthly = buildChartTable(l10n, AnalyticsChart.fuelSpend,
        buildFuelSeries(AnalyticsChart.fuelSpend, _logs(), now: _now),
        bikeName: (id) => id);
    expect(monthly.headers, ['Month', 'Fuel spend per month (৳)', 'Fill-ups']);
    expect(monthly.displayRows.first, ['Oct 2026', '650', '1']);
    expect(monthly.csvRows.first, ['2026-08', '1690', '2']);

    final eff = buildChartTable(l10n, AnalyticsChart.fuelEfficiency,
        buildFuelSeries(AnalyticsChart.fuelEfficiency, _logs(), now: _now),
        bikeName: (id) => id);
    expect(eff.headers.last, 'Distance (km)');
    expect(eff.displayRows.first, ['3 Oct 2026', '50.0', '250']);
    expect(eff.csvRows.first, ['2026-08-20 00:00', '40.000', '200']);
    expect(toCsv(eff.headers, eff.csvRows), startsWith('Date,'));
  });

  test('currency formats ahead of the number', () {
    expect(formatWithUnit(1200, '৳'), '৳1200');
    expect(formatWithUnit(2.6, '৳/km'), '৳2.6/km');
    expect(formatWithUnit(42, 'km/L'), '42 km/L');
  });

  testWidgets('fuel cards render with data and show the hint without',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final logs in [_logs(), <FuelLogEntity>[]]) {
      for (final chart in _fuelCharts) {
        await t.pumpWidget(_app(Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AnalyticsChartCard(
              chart: chart,
              points: buildFuelPreviewSeries(chart, logs, now: _now),
              bikeName: (id) => id,
              onTap: () {},
            ),
          ),
        )));
        await t.pump();
        expect(t.takeException(), isNull, reason: chart.name);
        expect(find.text('Log fuel fill-ups to see this'),
            logs.isEmpty ? findsOneWidget : findsNothing,
            reason: chart.name);
      }
    }
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets(
        'fuel detail screens render and switch range '
        '(${locale.languageCode})', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final chart in _fuelCharts) {
        await t.pumpWidget(_app(
          AnalyticsDetailScreen(
            key: ValueKey(chart),
            chart: chart,
            rides: const [],
            fuelLogs: _logs(),
            now: _now,
          ),
          locale: locale,
        ));
        await t.pump();
        expect(t.takeException(), isNull, reason: chart.name);
        expect(find.text(l10n.analyticsDownloadData), findsOneWidget);
        for (final r in [l10n.analyticsRangeAll, l10n.analyticsRange7d]) {
          await t.tap(find.text(r));
          await t.pump();
          expect(t.takeException(), isNull, reason: '${chart.name} $r');
        }
      }
    });
  }

  testWidgets('fuel detail with no fill-ups shows the hint', (t) async {
    t.view.physicalSize = const Size(360, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(AnalyticsDetailScreen(
      chart: AnalyticsChart.fuelEfficiency,
      rides: const [],
      now: _now,
    )));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Log fuel fill-ups to see this'), findsWidgets);
  });
}
