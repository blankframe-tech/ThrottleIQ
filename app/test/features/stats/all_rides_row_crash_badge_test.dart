import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/theme/app_shape_profile.dart';
import 'package:throttleiq/core/theme/app_theme_style.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/domain/ride_sort.dart';
import 'package:throttleiq/features/stats/presentation/providers/ride_polyline_provider.dart';
import 'package:throttleiq/features/stats/presentation/screens/all_rides_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// issues §78.30: a suspected-crash ride must not look like a commute in
/// history — it is the only surface where crash data is visible at all while
/// the live detector is switched off.
void main() {
  RideEntity ride(RideStatus status) => RideEntity(
        id: 'r1',
        userId: 'u',
        bikeId: 'b',
        startTime: DateTime(2026, 9, 1, 8),
        endTime: DateTime(2026, 9, 1, 9),
        distanceM: 12000,
        avgSpeedMs: 8,
        maxSpeedMs: 20,
        durationSeconds: 3600,
        status: status,
      );

  Future<void> pump(WidgetTester tester, RideEntity r) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            ridePolylineProvider.overrideWith((ref, id) async => const <LatLng>[]),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [
              AppColorPalette.calmingLight,
              AppShapeProfile.curvy,
            ]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: AllRidesRow(ride: r, sort: RideSort.recent),
              ),
            ),
          ),
        ),
      );

  testWidgets('a crash ride carries a Suspected crash badge', (tester) async {
    await pump(tester, ride(RideStatus.crash));
    await tester.pump();
    expect(find.text('SUSPECTED CRASH'), findsOneWidget);
  });

  testWidgets('an ordinary completed ride does not', (tester) async {
    await pump(tester, ride(RideStatus.completed));
    await tester.pump();
    expect(find.text('SUSPECTED CRASH'), findsNothing);
  });
}
