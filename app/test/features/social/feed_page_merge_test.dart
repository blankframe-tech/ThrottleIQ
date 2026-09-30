import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/domain/feed_page_merge.dart';

SharedRideEntity ride(String id, DateTime createdAt, {String? userId}) =>
    SharedRideEntity(
      id: id,
      userId: userId ?? 'rider-$id',
      userName: 'Rider $id',
      userPhotoUrl: '',
      bikeId: 'bike',
      bikeName: 'FZ-S',
      bikeType: 'commuter',
      rideDate: createdAt,
      distanceKm: 10,
      durationSeconds: 600,
      maxSpeedKmh: 60,
      polyline: const [],
      createdAt: createdAt,
    );

final t0 = DateTime(2026, 9, 30, 12);
DateTime minutesAgo(int m) => t0.subtract(Duration(minutes: m));

void main() {
  group('mergeFeedSources', () {
    test('all sources short: everything shown, no more pages', () {
      final page = mergeFeedSources([
        [ride('a', minutesAgo(1)), ride('b', minutesAgo(5))],
        [ride('c', minutesAgo(3))],
      ], pageSize: 3);
      expect(page.rides.map((r) => r.id), ['a', 'c', 'b']);
      expect(page.hasMore, isFalse);
      expect(page.cursor, minutesAgo(5));
    });

    test('de-duplicates a ride returned by several sources', () {
      final shared = ride('x', minutesAgo(2));
      final page = mergeFeedSources([
        [shared],
        [shared, ride('y', minutesAgo(4))],
      ], pageSize: 5);
      expect(page.rides.map((r) => r.id), ['x', 'y']);
    });

    test(
        'a dense full source bounds the page: older rides from a sparse '
        'source wait for the next page instead of opening a gap', () {
      // Dense public source: 3 rides within the last 3 minutes (full page).
      final dense = [
        ride('p1', minutesAgo(1)),
        ride('p2', minutesAgo(2)),
        ride('p3', minutesAgo(3)),
      ];
      // Sparse followed-author source reaching back days.
      final sparse = [
        ride('f1', minutesAgo(2), userId: 'friend'),
        ride('f2', minutesAgo(60 * 24), userId: 'friend'),
      ];
      final page = mergeFeedSources([dense, sparse], pageSize: 3);

      // f2 is older than the dense source's horizon — the dense source may
      // still have rides between 3 minutes and a day ago, so f2 can't be
      // placed yet.
      expect(page.rides.map((r) => r.id), ['p1', 'f1', 'p2', 'p3']);
      // The next page must start at the dense source's horizon, NOT at f2's
      // createdAt (which is what used to skip a day of public rides).
      expect(page.cursor, minutesAgo(3));
      expect(page.hasMore, isTrue);
    });

    test('the newest horizon among several full sources wins', () {
      final page = mergeFeedSources([
        [ride('a1', minutesAgo(1)), ride('a2', minutesAgo(10))],
        [ride('b1', minutesAgo(2)), ride('b2', minutesAgo(4))],
      ], pageSize: 2);
      expect(page.cursor, minutesAgo(4));
      expect(page.rides.map((r) => r.id), ['a1', 'b1', 'b2']);
    });

    test('empty input', () {
      final page = mergeFeedSources([[], []], pageSize: 20);
      expect(page.rides, isEmpty);
      expect(page.cursor, isNull);
      expect(page.hasMore, isFalse);
    });
  });
}
