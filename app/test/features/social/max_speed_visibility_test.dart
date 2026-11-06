import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/stats/domain/ride_sort.dart';
import 'package:throttleiq/features/stats/presentation/screens/all_rides_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

SharedRideEntity _ride() => SharedRideEntity(
      id: 'r',
      userId: 'owner',
      userName: 'U',
      userPhotoUrl: '',
      bikeId: 'b',
      bikeName: 'FZ-S',
      bikeType: 'commuter',
      rideDate: DateTime(2026, 9, 1),
      distanceKm: 10,
      durationSeconds: 600,
      maxSpeedKmh: 90,
      polyline: const [],
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  test('only the sharer may see max speed', () {
    final r = _ride();
    expect(r.maxSpeedVisibleTo('owner'), isTrue);
    expect(r.maxSpeedVisibleTo('someone-else'), isFalse);
    expect(r.maxSpeedVisibleTo(null), isFalse);
  });

  testWidgets('sort chips omit top speed when not offered', (tester) async {
    Future<void> pump(List<RideSort> options) => tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RideSortChips(
                sort: RideSort.recent,
                onChanged: (_) {},
                options: options,
              ),
            ),
          ),
        );
    await pump(RideSort.values);
    final all =
        find.byType(GestureDetector, skipOffstage: false).evaluate().length;
    await pump([
      for (final s in RideSort.values)
        if (s != RideSort.topSpeed) s,
    ]);
    expect(find.byType(GestureDetector, skipOffstage: false).evaluate().length,
        all - 1);
  });
}
