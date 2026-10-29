import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/data/repositories/ride_share_repository.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/presentation/providers/ride_feed_provider.dart';
import 'package:throttleiq/features/social/presentation/screens/my_shared_rides_screen.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

class _FailingRepo extends Fake implements RideShareRepository {
  @override
  Future<void> deleteSharedRide(String rideId) async =>
      throw Exception('offline');
}

/// #28: a failed delete on My Shared Rides tells the rider instead of
/// silently looking like it worked.
void main() {
  testWidgets('a failed delete shows a SnackBar and keeps the ride',
      (tester) async {
    final ride = SharedRideEntity(
      id: 'r1',
      userId: 'me',
      userName: 'Me',
      userPhotoUrl: '',
      bikeId: 'b1',
      bikeName: 'FZ-S',
      bikeType: '150cc',
      rideDate: DateTime(2026, 9, 1),
      distanceKm: 10,
      durationSeconds: 600,
      maxSpeedKmh: 60,
      polyline: const [],
      createdAt: DateTime(2026, 9, 1),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        myRidesProvider.overrideWith((ref) async => [ride]),
        rideShareRepositoryProvider.overrideWithValue(_FailingRepo()),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MySharedRidesScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(
        find.text(
            "Couldn't delete the shared ride. Check your connection and try again."),
        findsOneWidget);
    expect(find.text('FZ-S'), findsOneWidget);
  });
}
