import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/ride/presentation/widgets/rider_stat_strip.dart';
import 'package:throttleiq/features/stats/presentation/providers/rider_stats_provider.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// The Record screen's stat strip.
///
/// Tested on its own rather than through `RecordScreen`, which reads
/// `FirebaseAuth.instance` in `initState` and can't be pumped without a live
/// Firebase app — same reason the bike picker and the skin picker are their
/// own widgets (`Issues.md` §15).
RideEntity ride(DateTime startTime, {String id = 'r1'}) => RideEntity(
      id: id,
      userId: 'u1',
      bikeId: 'b1',
      startTime: startTime,
      distanceM: 1000,
      durationSeconds: 600,
    );

RiderStatsSummary stats({
  int totalRides = 0,
  double totalDistanceKm = 0,
  List<RideEntity> rides = const [],
}) =>
    RiderStatsSummary(
      allTimeAvgSpeedKmh: 0,
      allTimeTopSpeedKmh: 0,
      avgRidingScore: 0,
      mostUsedBike: null,
      totalRides: totalRides,
      totalDistanceKm: totalDistanceKm,
      recentRides: rides,
      allRides: rides,
    );

void main() {
  Widget harness(AsyncValue<RiderStatsSummary> value) => ProviderScope(
        overrides: [
          riderStatsProvider.overrideWith((ref) async => value.requireValue),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RiderStatStrip()),
        ),
      );

  testWidgets('shows rides, kilometres and the live streak', (tester) async {
    final today = DateTime.now();
    await tester.pumpWidget(harness(AsyncValue.data(stats(
      totalRides: 128,
      totalDistanceKm: 1204.4,
      rides: [
        ride(today, id: 'a'),
        ride(today.subtract(const Duration(days: 1)), id: 'b'),
      ],
    ))));
    await tester.pumpAndSettle();

    expect(find.text('128'), findsOneWidget);
    expect(find.text('RIDES'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // the two-day streak
    expect(find.text('DAY STREAK'), findsOneWidget);
  });

  testWidgets('groups thousands so the distance stays readable',
      (tester) async {
    // Four unbroken digits in a 22pt display face is the number a rider has
    // to stop and parse.
    await tester.pumpWidget(
        harness(AsyncValue.data(stats(totalDistanceKm: 1204.4))));
    await tester.pumpAndSettle();

    expect(find.text('1,204'), findsOneWidget);
    expect(find.text('KILOMETRES'), findsOneWidget);
  });

  testWidgets('renders zeros rather than a spinner while stats resolve',
      (tester) async {
    // The layout is fixed-height either way; a progress indicator sliding
    // into a row of numbers is more disruptive than a number that ticks up.
    await tester.pumpWidget(harness(AsyncValue.data(stats())));
    // Deliberately not settled — this is the first frame, before the
    // FutureProvider has resolved.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('0'), findsNWidgets(3));
  });

  testWidgets('an empty history has no streak', (tester) async {
    await tester.pumpWidget(harness(AsyncValue.data(stats(totalRides: 0))));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNWidgets(3));
  });
}
