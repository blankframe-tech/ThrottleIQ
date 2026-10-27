import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:throttleiq/features/profile/presentation/providers/profile_providers.dart';
import 'package:throttleiq/features/social/data/repositories/ride_share_repository.dart';
import 'package:throttleiq/features/social/domain/entities/ride_comment_entity.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/presentation/providers/ride_feed_provider.dart';
import 'package:throttleiq/features/social/presentation/screens/shared_ride_detail_screen.dart';
import 'package:throttleiq/features/social/presentation/widgets/shared_ride_feed_card.dart';
import 'package:throttleiq/l10n/app_localizations.dart';

/// Comments on a shared ride from a rider the viewer blocked are hidden, on
/// the detail screen and in the feed card's inline thread.
class _Repo extends Mock implements RideShareRepository {
  @override
  Future<List<RideCommentEntity>> getComments(String rideId,
          {int limit = kRideCommentsPageSize, DateTime? before}) async =>
      [
        for (final (uid, text) in [
          ('friend', 'Friendly comment'),
          ('harasser', 'Blocked comment'),
        ])
          RideCommentEntity(
              id: uid,
              rideId: rideId,
              userId: uid,
              userName: uid,
              userPhotoUrl: '',
              text: text,
              createdAt: DateTime(2026, 10, 27)),
      ];
}

void main() {
  final ride = SharedRideEntity(
    id: 'r1',
    userId: 'author',
    userName: 'Author',
    userPhotoUrl: '',
    bikeId: 'b1',
    bikeName: 'Pulsar',
    bikeType: 'Sport',
    rideDate: DateTime(2026, 10, 27),
    distanceKm: 10,
    durationSeconds: 600,
    maxSpeedKmh: 60,
    polyline: const [],
    comments: 2,
    createdAt: DateTime(2026, 10, 27),
  );

  setUp(() => RideShareRepository.instanceForTest = _Repo());

  Widget app(Widget home) => ProviderScope(
        overrides: [
          blockedUsersProvider.overrideWith((ref) async => {'harasser'}),
          sharedRideProvider(ride.id).overrideWith((ref) async => ride),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  testWidgets('detail screen hides comments from blocked riders',
      (tester) async {
    await tester.pumpWidget(
        app(SharedRideDetailScreen(rideId: ride.id, initialRide: ride)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Friendly comment'), 300,
        scrollable: find.byType(Scrollable).first);

    expect(find.text('Friendly comment'), findsOneWidget);
    expect(find.text('Blocked comment'), findsNothing);
  });

  testWidgets('feed card hides comments from blocked riders', (tester) async {
    await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
            child: SharedRideFeedCard(ride: ride, onVote: (_) {})))));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    expect(find.textContaining('Friendly comment', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Blocked comment', findRichText: true),
        findsNothing);
  });
}
