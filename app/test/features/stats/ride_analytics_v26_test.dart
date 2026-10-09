import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/domain/charts/cornering_elevation_charts.dart';
import 'package:throttleiq/features/stats/domain/ride_analytics.dart';
import 'package:throttleiq/features/stats/presentation/analytics_chart_l10n.dart';
import 'package:throttleiq/features/stats/presentation/analytics_chart_registry.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

/// The schema v26 charts: max lean, peak g and elevation gain per ride.
RideEntity _ride(
  String id,
  DateTime start, {
  double? lean,
  double? latG,
  double? accelG,
  double? brakeG,
  double? gain,
  double? loss,
}) =>
    RideEntity(
      id: id,
      userId: 'u',
      bikeId: 'b',
      startTime: start,
      distanceM: 10000,
      maxLeanDeg: lean,
      peakLateralG: latG,
      peakAccelG: accelG,
      peakBrakeG: brakeG,
      elevationGainM: gain,
      elevationLossM: loss,
      status: RideStatus.completed,
    );

void main() {
  final now = DateTime(2026, 10, 9, 15);
  final rides = [
    // Out of order on purpose; one legacy ride with nothing.
    _ride(
      'c',
      DateTime(2026, 10, 3),
      lean: 31,
      latG: 0.6,
      accelG: 0.3,
      brakeG: 0.7,
      gain: 0,
      loss: 0,
    ),
    _ride('legacy', DateTime(2026, 10, 1)),
    _ride(
      'a',
      DateTime(2026, 10, 2),
      lean: 22,
      latG: 0.4,
      accelG: null,
      brakeG: 0.5,
      gain: 120,
      loss: 80,
    ),
    // Elevation backfilled, but no lean (recorded before v26).
    _ride('b', DateTime(2026, 10, 2, 18), gain: 40, loss: 45),
  ];

  test('all three are per-ride charts', () {
    for (final c in [
      CorneringElevationCharts.maxLean,
      CorneringElevationCharts.peakG,
      CorneringElevationCharts.elevationGain,
    ]) {
      expect(c, isA<PerRideChart>(), reason: c.name);
    }
    expect(CorneringElevationCharts.maxLean.aggregation, Aggregation.mean);
    expect(CorneringElevationCharts.peakG.aggregation, Aggregation.mean);
    expect(CorneringElevationCharts.elevationGain.aggregation, Aggregation.sum);
  });

  test('max lean: chronological, NULL legacy rides skipped', () {
    final s = CorneringElevationCharts.maxLean.perRideSeries(rides);
    expect(s.map((p) => p.key), ['a', 'c']);
    expect(s.map((p) => p.value), [22, 31]);
    expect(CorneringElevationCharts.maxLean.periodAggregate(rides), 26.5);
    final i = CorneringElevationCharts.maxLean.insights(rides, s, now: now);
    expect(i.single.kind, peakLeanInsight);
    expect(i.single.value, 31);
    expect(i.single.date, DateTime(2026, 10, 3));
  });

  test('peak g: lateral value, accel/brake alongside', () {
    final s = CorneringElevationCharts.peakG.perRideSeries(rides);
    expect(s.map((p) => p.key), ['a', 'c']);
    expect(s.map((p) => p.value), [0.4, 0.6]);
    expect(s.map((p) => p.secondary), [null, 0.3]);
    expect(s.map((p) => p.tertiary), [0.5, 0.7]);
    final i = CorneringElevationCharts.peakG.insights(rides, s, now: now);
    expect(i.single.kind, InsightKind.peakValue);
    expect(i.single.value, 0.6);
  });

  test('elevation: gain value, loss alongside; a flat 0 is kept', () {
    final s = CorneringElevationCharts.elevationGain.perRideSeries(rides);
    expect(s.map((p) => p.key), ['a', 'b', 'c']);
    expect(s.map((p) => p.value), [120, 40, 0]);
    expect(s.map((p) => p.secondary), [80, 45, 0]);
    expect(CorneringElevationCharts.elevationGain.periodAggregate(rides), 160);
    final i = CorneringElevationCharts.elevationGain.insights(
      rides,
      s,
      now: now,
    );
    expect(i.single.kind, totalClimbInsight);
    expect(i.single.value, 160);
    expect(i.single.value2, 3);
  });

  test('an all-legacy history has no data for any of them', () {
    final legacy = [_ride('x', DateTime(2026, 10, 1))];
    for (final c in [
      CorneringElevationCharts.maxLean,
      CorneringElevationCharts.peakG,
      CorneringElevationCharts.elevationGain,
    ]) {
      expect(c.perRideSeries(legacy), isEmpty, reason: c.name);
      expect(c.periodAggregate(legacy), isNull, reason: c.name);
    }
  });

  group('table / CSV / wording', () {
    setUpAll(() => initializeDateFormatting('en'));
    final l10n = AppLocalizationsEn();
    String bike(String id) => id;

    test('peak g has lateral, accel and brake columns', () {
      final t = chartPresentationOf(CorneringElevationCharts.peakG).buildTable(
        l10n,
        CorneringElevationCharts.peakG.perRideSeries(rides),
        bikeName: bike,
      );
      expect(t.headers, [
        'Date',
        'Cornering (g)',
        'Acceleration (g)',
        'Braking (g)',
      ]);
      expect(t.csvRows.first, ['2026-10-02 00:00', '0.400', '', '0.500']);
      expect(t.displayRows.first, ['3 Oct 2026', '0.60', '0.30', '0.70']);
    });

    test('elevation has climb and descent columns', () {
      final t = chartPresentationOf(CorneringElevationCharts.elevationGain)
          .buildTable(
        l10n,
        CorneringElevationCharts.elevationGain.perRideSeries(rides),
        bikeName: bike,
      );
      expect(t.headers, ['Date', 'Climb (m)', 'Descent (m)']);
      expect(t.csvRows.first, ['2026-10-02 00:00', '120', '80']);
    });

    test('max lean is one degree column', () {
      final t =
          chartPresentationOf(CorneringElevationCharts.maxLean).buildTable(
        l10n,
        CorneringElevationCharts.maxLean.perRideSeries(rides),
        bikeName: bike,
      );
      expect(t.headers, ['Date', 'Max lean angle per ride (°)']);
      expect(t.csvRows.last, ['2026-10-03 00:00', '31']);
    });

    test('insights read naturally', () {
      expect(
        chartPresentationOf(CorneringElevationCharts.maxLean).insightText(
          l10n,
          AnalyticsInsight(
            peakLeanInsight,
            value: 31,
            date: DateTime(2026, 10, 3),
          ),
          bikeName: bike,
        ),
        startsWith('Your deepest lean was about 31° on 3 Oct.'),
      );
      expect(
        chartPresentationOf(CorneringElevationCharts.elevationGain).insightText(
          l10n,
          const AnalyticsInsight(totalClimbInsight, value: 160, value2: 3),
          bikeName: bike,
        ),
        'You climbed 160 m in total across 3 rides.',
      );
      expect(formatWithUnit(0.456, 'g'), '0.46 g');
    });
  });
}
