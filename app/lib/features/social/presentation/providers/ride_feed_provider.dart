import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/shared_ride_entity.dart';

/// Public ride feed — all non-private shared rides, newest first.
final publicRideFeedProvider = FutureProvider<List<SharedRideEntity>>((ref) {
  return RideShareRepository().getPublicRides();
});

/// Holds the feed list locally so likes can be toggled optimistically without
/// waiting on a Firestore round-trip. Seeded from [publicRideFeedProvider]
/// once it resolves.
final rideFeedNotifierProvider =
    StateNotifierProvider<RideLikeNotifier, List<SharedRideEntity>>((ref) {
  final rides = ref.watch(publicRideFeedProvider).valueOrNull ?? [];
  return RideLikeNotifier(ref, rides);
});

class RideLikeNotifier extends StateNotifier<List<SharedRideEntity>> {
  RideLikeNotifier(this._ref, List<SharedRideEntity> initial) : super(initial);

  final Ref _ref;
  final _repo = RideShareRepository();

  Future<void> toggleLike(String rideId) async {
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final ride = state.where((r) => r.id == rideId).firstOrNull;
    if (ride == null) return;
    final liking = !ride.isLikedByCurrentUser;

    // Optimistic update first.
    state = [
      for (final r in state)
        if (r.id == rideId)
          r.copyWith(
            isLikedByCurrentUser: liking,
            likes: r.likes + (liking ? 1 : -1),
          )
        else
          r,
    ];

    try {
      await _repo.toggleLike(rideId, uid, liking);
    } catch (_) {
      // Revert on failure.
      state = [
        for (final r in state)
          if (r.id == rideId) ride else r,
      ];
    }
  }

  /// Patches the cached comment count for [rideId] after a successful post,
  /// mirroring the optimistic list-patch pattern used by [toggleLike].
  void incrementCommentCount(String rideId) {
    state = [
      for (final r in state)
        if (r.id == rideId) r.copyWith(comments: r.comments + 1) else r,
    ];
  }
}
