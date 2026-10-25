import '../../stats/domain/ride_sort.dart';
import 'entities/shared_ride_entity.dart';

/// Most rides a rider can pin to the top of their profile. firestore.rules
/// (`profileFieldsValid`) enforces the same cap on `pinnedRideIds`.
const int kMaxPinnedRides = 5;

/// [pins] with [rideId] toggled: removed when pinned, otherwise appended (pin
/// order is display order). Null when [rideId] isn't pinned and the cap is
/// already reached. Pure — see `test/features/social/profile_rides_test.dart`.
List<String>? togglePinnedRide(List<String> pins, String rideId) {
  if (pins.contains(rideId)) return [...pins.where((id) => id != rideId)];
  if (pins.length >= kMaxPinnedRides) return null;
  return [...pins, rideId];
}

/// The rides on a profile, ordered by [sort] — the Stats tab's orderings
/// applied to shared rides. Returns a new list. Ties (and rides without a
/// riding score, under [RideSort.bestScore]) fall back to newest first, then
/// id, so the list doesn't reshuffle between rebuilds.
List<SharedRideEntity> sortSharedRides(
    List<SharedRideEntity> rides, RideSort sort) {
  num? key(SharedRideEntity r) => switch (sort) {
        RideSort.recent => null,
        RideSort.topSpeed => r.maxSpeedKmh,
        RideSort.longestDistance => r.distanceKm,
        RideSort.longestDuration => r.durationSeconds,
        RideSort.bestScore => r.ridingScore,
      };
  int newest(SharedRideEntity a, SharedRideEntity b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  return [...rides]..sort((a, b) {
      final ka = key(a), kb = key(b);
      if (ka == kb) return newest(a, b);
      if (ka == null) return 1;
      if (kb == null) return -1;
      return kb.compareTo(ka);
    });
}
