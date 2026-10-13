import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/domain/feed_page_merge.dart';
import 'package:throttleiq/features/social/domain/feed_source_plan.dart';

final t0 = DateTime(2026, 10, 1, 12);
DateTime minutesAgo(int m) => t0.subtract(Duration(minutes: m));

SharedRideEntity ride(String id, int minsAgo, {String userId = 'u'}) =>
    SharedRideEntity(
      id: id,
      userId: userId,
      userName: 'Rider',
      userPhotoUrl: '',
      bikeId: 'bike',
      bikeName: 'FZ-S',
      bikeType: 'commuter',
      rideDate: minutesAgo(minsAgo),
      distanceKm: 10,
      durationSeconds: 600,
      maxSpeedKmh: 60,
      polyline: const [],
      createdAt: minutesAgo(minsAgo),
    );

/// The feed's read-bounded source plan (issues §90.A1).
void main() {
  group('chunkList', () {
    test('splits into whereIn-sized chunks, order kept', () {
      final ids = [for (var i = 0; i < 65; i++) 'u$i'];
      final chunks = chunkList(ids);
      expect(chunks.map((c) => c.length), [30, 30, 5]);
      expect(chunks.expand((c) => c), ids);
    });

    test('exactly one chunk at the limit, none for empty input', () {
      expect(chunkList(List.filled(30, 'x')), hasLength(1));
      expect(chunkList(<String>[]), isEmpty);
    });

    test('custom size', () {
      expect(chunkList([1, 2, 3, 4, 5], 2), [
        [1, 2],
        [3, 4],
        [5],
      ]);
    });
  });

  group('restrictedAudiencesFor', () {
    test('mutual only for authors who follow back', () {
      expect(restrictedAudiencesFor('a', {'a'}), ['followers', 'mutual']);
      expect(restrictedAudiencesFor('b', {'a'}), ['followers']);
    });

    test('never asks for public — that comes from the chunked query', () {
      expect(restrictedAudiencesFor('a', {'a'}), isNot(contains('public')));
    });
  });

  group('isFeedSourceExhausted', () {
    test('a full page is never exhausted', () {
      expect(
          isFeedSourceExhausted([ride('a', 1), ride('b', 2)],
              limit: 2, cut: null),
          isFalse);
    });

    test('a short page with nothing cut is exhausted', () {
      expect(
          isFeedSourceExhausted([ride('a', 1)], limit: 5, cut: minutesAgo(3)),
          isTrue);
      expect(isFeedSourceExhausted([], limit: 5, cut: minutesAgo(3)), isTrue);
    });

    test('a short page whose rides were cut by the horizon must be re-queried',
        () {
      // ride b (10 min ago) is older than the cut and was dropped from this
      // page — skipping the source next time would lose it.
      expect(
          isFeedSourceExhausted([ride('a', 1), ride('b', 10)],
              limit: 5, cut: minutesAgo(3)),
          isFalse);
    });
  });

  group('mergeFeedSources with per-source limits', () {
    test('a restricted source is "full" at its own small limit', () {
      final public = [ride('p1', 1), ride('p2', 50)]; // short vs 20
      // Restricted source asked for 2 and got 2 → may have more past r2.
      final restricted = [
        ride('r1', 2, userId: 'friend'),
        ride('r2', 5, userId: 'friend'),
      ];
      final page = mergeFeedSources([public, restricted],
          pageSize: 20, pageSizes: [20, 2]);
      // Horizon is r2's createdAt: p2 (older) waits for the next page.
      expect(page.rides.map((r) => r.id), ['p1', 'r1', 'r2']);
      expect(page.cursor, minutesAgo(5));
      expect(page.hasMore, isTrue);
    });

    test('without pageSizes every source uses pageSize (old behaviour)', () {
      final page = mergeFeedSources([
        [ride('a', 1)],
        [ride('b', 2), ride('c', 3)],
      ], pageSize: 20);
      expect(page.hasMore, isFalse);
      expect(page.rides, hasLength(3));
    });
  });
}
