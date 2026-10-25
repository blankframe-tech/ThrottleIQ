import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/social/domain/entities/shared_ride_entity.dart';
import 'package:throttleiq/features/social/domain/profile_rides.dart';
import 'package:throttleiq/features/stats/domain/ride_sort.dart';

SharedRideEntity _ride(String id,
        {int day = 1, double km = 10, int seconds = 600, int? brakes}) =>
    SharedRideEntity(
      id: id,
      userId: 'u',
      userName: 'U',
      userPhotoUrl: '',
      bikeId: 'b',
      bikeName: 'FZ-S',
      bikeType: 'commuter',
      rideDate: DateTime(2026, 9, day),
      distanceKm: km,
      durationSeconds: seconds,
      maxSpeedKmh: 0,
      polyline: const [],
      createdAt: DateTime(2026, 9, day),
      hardBrakeCount: brakes,
      rapidAccelCount: brakes == null ? null : 0,
      highJerkCount: brakes == null ? null : 0,
    );

List<String> _ids(List<SharedRideEntity> rides) =>
    [for (final r in rides) r.id];

void main() {
  group('togglePinnedRide', () {
    test('appends, removes, and refuses a sixth pin', () {
      expect(togglePinnedRide([], 'a'), ['a']);
      expect(togglePinnedRide(['a', 'b'], 'a'), ['b']);
      final full = ['1', '2', '3', '4', '5'];
      expect(togglePinnedRide(full, '6'), isNull);
      expect(togglePinnedRide(full, '3'), ['1', '2', '4', '5']);
    });
  });

  group('sortSharedRides', () {
    final rides = [
      _ride('old-long', day: 1, km: 80, seconds: 600),
      _ride('new-short', day: 3, km: 5, seconds: 3600, brakes: 0),
      _ride('mid', day: 2, km: 20, seconds: 1200, brakes: 5),
    ];

    test('recent is newest first', () {
      expect(_ids(sortSharedRides(rides, RideSort.recent)),
          ['new-short', 'mid', 'old-long']);
    });

    test('longest distance and duration rank by their value', () {
      expect(_ids(sortSharedRides(rides, RideSort.longestDistance)),
          ['old-long', 'mid', 'new-short']);
      expect(_ids(sortSharedRides(rides, RideSort.longestDuration)),
          ['new-short', 'mid', 'old-long']);
    });

    test('best score puts rides without a score last', () {
      expect(_ids(sortSharedRides(rides, RideSort.bestScore)),
          ['new-short', 'mid', 'old-long']);
    });

    test('ties fall back to newest, and the input is not mutated', () {
      final tied = [_ride('a', day: 1), _ride('b', day: 2)];
      expect(_ids(sortSharedRides(tied, RideSort.longestDistance)), ['b', 'a']);
      expect(_ids(tied), ['a', 'b']);
    });
  });

  test('withVote toggles and moves tallies', () {
    final r = _ride('r');
    final up = r.withVote(1);
    expect((up.myVote, up.upvotes, up.downvotes), (1, 1, 0));
    final flipped = up.withVote(-1);
    expect((flipped.myVote, flipped.upvotes, flipped.downvotes), (-1, 0, 1));
    final cleared = flipped.withVote(-1);
    expect((cleared.myVote, cleared.upvotes, cleared.downvotes), (null, 0, 0));
  });
}
