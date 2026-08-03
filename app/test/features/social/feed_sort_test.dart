import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/domain/feed_sort.dart';

SharedRideEntity _ride({
  required String id,
  required int day,
  String userId = 'u1',
  int upvotes = 0,
  int downvotes = 0,
  int hour = 12,
}) {
  return SharedRideEntity(
    id: id,
    userId: userId,
    userName: 'Rider',
    userPhotoUrl: '',
    bikeId: 'b1',
    bikeName: 'RX100',
    bikeType: '100cc',
    rideDate: DateTime(2026, 8, day),
    distanceKm: 10,
    durationSeconds: 600,
    maxSpeedKmh: 60,
    polyline: const [],
    createdAt: DateTime(2026, 8, day, hour),
    upvotes: upvotes,
    downvotes: downvotes,
  );
}

List<String> _ids(List<SharedRideEntity> rides) => rides.map((r) => r.id).toList();

void main() {
  group('sortFeed', () {
    test('recent orders newest first', () {
      final rides = [
        _ride(id: 'old', day: 1),
        _ride(id: 'new', day: 10),
        _ride(id: 'mid', day: 5),
      ];
      expect(_ids(sortFeed(rides, FeedSort.recent)), ['new', 'mid', 'old']);
    });

    test('hot orders by net score, highest first', () {
      final rides = [
        _ride(id: 'meh', day: 1, upvotes: 2, downvotes: 1),
        _ride(id: 'loved', day: 2, upvotes: 40, downvotes: 2),
        _ride(id: 'panned', day: 3, upvotes: 1, downvotes: 9),
      ];
      expect(_ids(sortFeed(rides, FeedSort.hot)), ['loved', 'meh', 'panned']);
    });

    test('hot ranks an unvoted ride below a positively scored one', () {
      final rides = [
        _ride(id: 'unvoted', day: 9),
        _ride(id: 'upvoted', day: 1, upvotes: 1),
      ];
      expect(_ids(sortFeed(rides, FeedSort.hot)), ['upvoted', 'unvoted']);
    });

    test('hot breaks score ties by recency', () {
      final rides = [
        _ride(id: 'older', day: 1, upvotes: 5),
        _ride(id: 'newer', day: 7, upvotes: 5),
      ];
      expect(_ids(sortFeed(rides, FeedSort.hot)), ['newer', 'older']);
    });

    test('identical timestamps break by id so the order is stable', () {
      final rides = [
        _ride(id: 'b', day: 3),
        _ride(id: 'a', day: 3),
        _ride(id: 'c', day: 3),
      ];
      expect(_ids(sortFeed(rides, FeedSort.recent)), ['a', 'b', 'c']);
      expect(_ids(sortFeed(rides, FeedSort.hot)), ['a', 'b', 'c']);
    });

    test('following keeps only rides by followed riders, newest first', () {
      final rides = [
        _ride(id: 'mine', day: 9, userId: 'me'),
        _ride(id: 'friend-old', day: 1, userId: 'friend'),
        _ride(id: 'stranger', day: 8, userId: 'stranger'),
        _ride(id: 'friend-new', day: 5, userId: 'friend'),
      ];
      expect(
        _ids(sortFeed(rides, FeedSort.following, followingUids: {'friend'})),
        ['friend-new', 'friend-old'],
      );
    });

    test('following with nobody followed yields an empty feed', () {
      final rides = [_ride(id: 'a', day: 1), _ride(id: 'b', day: 2)];
      expect(sortFeed(rides, FeedSort.following), isEmpty);
    });

    test('following ignores followingUids for the other sorts', () {
      final rides = [
        _ride(id: 'stranger', day: 2, userId: 'stranger'),
        _ride(id: 'friend', day: 1, userId: 'friend'),
      ];
      expect(_ids(sortFeed(rides, FeedSort.recent, followingUids: {'friend'})),
          ['stranger', 'friend']);
    });

    test('never mutates or aliases the input list', () {
      final rides = [
        _ride(id: 'old', day: 1),
        _ride(id: 'new', day: 10),
      ];
      final sorted = sortFeed(rides, FeedSort.recent);

      expect(_ids(rides), ['old', 'new']);
      expect(identical(sorted, rides), isFalse);
    });

    test('handles an empty feed for every sort', () {
      for (final sort in FeedSort.values) {
        expect(sortFeed(const [], sort), isEmpty);
      }
    });

    test('every sort has a chip label', () {
      expect(FeedSort.hot.label, 'Hot');
      expect(FeedSort.recent.label, 'Recent');
      expect(FeedSort.following.label, 'Following');
    });
  });
}
