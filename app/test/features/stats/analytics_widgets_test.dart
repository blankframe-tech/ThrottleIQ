import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';
import 'package:throttleiq/features/garage/presentation/providers/garage_provider.dart';
import 'package:throttleiq/features/stats/presentation/providers/badge_sync_provider.dart';
import 'package:throttleiq/features/stats/presentation/providers/rider_stats_provider.dart';
import 'package:throttleiq/features/stats/presentation/screens/stats_screen.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/domain/ride_analytics.dart';
import 'package:throttleiq/features/stats/presentation/screens/analytics_detail_screen.dart';
import 'package:throttleiq/features/stats/presentation/widgets/analytics_chart_card.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

final _now = DateTime(2026, 10, 9, 15);

List<RideEntity> _rides() => [
      for (var i = 0; i < 40; i++)
        RideEntity(
          id: 'r$i',
          userId: 'u',
          bikeId: i.isEven ? 'b1' : 'b2',
          startTime: _now.subtract(Duration(days: i * 2, hours: i % 9)),
          distanceM: 3000.0 + i * 700,
          avgSpeedMs: 6 + (i % 5),
          maxSpeedMs: 12 + (i % 7),
          durationSeconds: 900 + i * 30,
          movingSeconds: i % 6 == 0 ? null : 700 + i * 20,
          hardBrakeCount: i % 4,
          rapidAccelCount: i % 3,
          highJerkCount: i % 5,
          overspeedCount: i % 7 == 0 ? null : i % 3,
          maxLeanDeg: i % 5 == 0 ? null : 12.0 + i % 9 * 3,
          peakLateralG: i % 5 == 0 ? null : 0.2 + i % 9 * 0.05,
          peakAccelG: i % 5 == 0 ? null : 0.15 + i % 4 * 0.05,
          peakBrakeG: i % 5 == 0 ? null : 0.3 + i % 6 * 0.07,
          elevationGainM: i % 4 == 0 ? null : (i % 6) * 25.0,
          elevationLossM: i % 4 == 0 ? null : (i % 5) * 20.0,
          status: RideStatus.completed,
        ),
    ];

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('every chart card renders without layout errors', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final rides = _rides();
    for (final chart in AnalyticsChart.values) {
      await t.pumpWidget(_app(Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnalyticsChartCard(
              chart: chart,
              points: buildPreviewSeries(chart, rides, now: _now),
              bikeName: (id) => 'Bike $id',
              insight: 'insight',
              onTap: () {},
            ),
          ),
        ),
      )));
      await t.pump();
      expect(t.takeException(), isNull, reason: chart.name);
    }
  });

  for (final locale in const [Locale('en'), Locale('bn')]) {
    testWidgets(
        'detail screen renders every chart and switches range '
        '(${locale.languageCode})', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final rides = _rides();
      for (final chart in AnalyticsChart.values) {
        await t.pumpWidget(_app(
          AnalyticsDetailScreen(
            key: ValueKey(chart),
            chart: chart,
            rides: rides,
            bikeNames: const {'b1': 'Honda CB Hornet', 'b2': 'Yamaha FZ'},
            now: _now,
          ),
          locale: locale,
        ));
        await t.pump();
        expect(t.takeException(), isNull, reason: chart.name);
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(find.text(l10n.analyticsDownloadData), findsOneWidget);
        await t.tap(find.text(l10n.analyticsRangeAll));
        await t.pump();
        expect(t.takeException(), isNull, reason: '${chart.name} all');
        await t.tap(find.text(l10n.analyticsRange7d));
        await t.pump();
        expect(t.takeException(), isNull, reason: '${chart.name} 7d');
      }
    });
  }

  testWidgets('detail screen with no rides shows the empty state', (t) async {
    t.view.physicalSize = const Size(360, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app(AnalyticsDetailScreen(
      chart: AnalyticsChart.distancePerRide,
      rides: const [],
      now: _now,
    )));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Not enough rides in this period yet.'), findsWidgets);
    expect(find.text('No earlier data'), findsOneWidget);
  });

  testWidgets(
      'Rides tab: compact header leaves the first chart above the fold '
      'and has no metric toggle', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final rides = _rides();
    await t.pumpWidget(ProviderScope(
      overrides: [
        riderStatsProvider.overrideWith(
            (ref) async => computeRiderStats(rides: rides, bikes: const [])),
        allBikesProvider.overrideWith((ref) async => const []),
        badgeSyncProvider.overrideWith((ref) async {}),
      ],
      child: _app(const StatsScreen()),
    ));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    // Room reserved for the bottom nav bar the shell draws under the tab.
    const bottomNavHeight = 80.0;
    final firstCard = find.byType(AnalyticsChartCard).first;
    expect(firstCard, findsOneWidget);
    final top = t.getTopLeft(firstCard).dy;
    expect(top, lessThan(800 - bottomNavHeight - 100),
        reason: 'first chart should start well above the fold');
    // The old Dist/Speed toggle is gone.
    expect(find.text('Dist'), findsNothing);
    expect(find.text('Speed'), findsNothing);

    // Tapping a chart opens its detail view.
    await t.tap(firstCard);
    await t.pumpAndSettle();
    expect(find.byType(AnalyticsDetailScreen), findsOneWidget);
    expect(find.text('Download data'), findsOneWidget);
  });
}
