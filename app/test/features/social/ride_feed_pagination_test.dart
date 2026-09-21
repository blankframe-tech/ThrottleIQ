import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/presentation/providers/ride_feed_provider.dart';

SharedRideEntity ride(String id, {int upvotes = 0, int? myVote, int comments = 0}) =>
    SharedRideEntity(
      id: id,
      userId: 'rider-$id',
      userName: 'Rider $id',
      userPhotoUrl: '',
      bikeId: 'bike',
      bikeName: 'FZ-S',
      bikeType: 'commuter',
      rideDate: DateTime(2026, 9, 1),
      distanceKm: 10,
      durationSeconds: 600,
      maxSpeedKmh: 60,
      polyline: const [],
      createdAt: DateTime(2026, 9, 1),
      upvotes: upvotes,
      myVote: myVote,
      comments: comments,
    );

/// The optimistic-update and paging-state behaviour of the feed notifier
/// (issues §83.20). The seeded constructor keeps this off Firestore.
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  RideFeedNotifier seeded(List<SharedRideEntity> rides) {
    late RideFeedNotifier notifier;
    container = ProviderContainer(overrides: [
      rideFeedNotifierProvider.overrideWith((ref) {
        notifier = RideFeedNotifier.seeded(ref, rides);
        return notifier;
      }),
    ]);
    container.read(rideFeedNotifierProvider);
    return notifier;
  }

  group('FeedState', () {
    test('seeded feed is loaded and exhausted', () {
      final n = seeded([ride('a'), ride('b')]);
      expect(n.state.isLoading, isFalse);
      expect(n.state.hasMore, isFalse);
      expect(n.state.rides, hasLength(2));
    });

    test('copyWith clears the error only when asked', () {
      const s = FeedState(error: 'boom');
      expect(s.copyWith(isLoading: false).error, 'boom');
      expect(s.copyWith(clearError: true).error, isNull);
    });
  });

  group('optimistic comment count', () {
    test('increments only the targeted ride', () {
      final n = seeded([ride('a', comments: 2), ride('b', comments: 5)]);
      n.incrementCommentCount('a');
      expect(n.state.rides.firstWhere((r) => r.id == 'a').comments, 3);
      expect(n.state.rides.firstWhere((r) => r.id == 'b').comments, 5);
    });

    test('an unknown id leaves the feed untouched', () {
      final n = seeded([ride('a', comments: 2)]);
      n.incrementCommentCount('nope');
      expect(n.state.rides.single.comments, 2);
    });
  });

  group('loadMore guards', () {
    test('does nothing once every source is exhausted', () async {
      // hasMore is false on a seeded feed, so this must return without
      // touching the repository — which would throw with no Firebase app.
      final n = seeded([ride('a')]);
      await n.loadMore();
      expect(n.state.rides, hasLength(1));
      expect(n.state.isLoadingMore, isFalse);
    });
  });
}
