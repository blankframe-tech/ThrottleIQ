import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/shared_ride_entity.dart';

/// The rider's feed: public rides + rides shared to them (followers/mutual)
/// + their own shared rides, deduped and ranked by vote score.
///
/// Firestore rules can't filter a single list query across audiences (see
/// firestore.rules `rideVisibleTo`), so this fans out to the three queries
/// that each line up with one visibility clause and merges client-side.
final rideFeedProvider = FutureProvider<List<SharedRideEntity>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  final repo = RideShareRepository();

  final results = await Future.wait([
    repo.getPublicRides(),
    if (uid != null) repo.getSharedToMe(uid) else Future.value(<SharedRideEntity>[]),
    if (uid != null) repo.getMyRides(uid) else Future.value(<SharedRideEntity>[]),
  ]);

  final byId = <String, SharedRideEntity>{};
  for (final list in results) {
    for (final ride in list) {
      byId[ride.id] = ride;
    }
  }

  final rides = byId.values.toList()
    ..sort((a, b) {
      final scoreCompare = b.netScore.compareTo(a.netScore);
      if (scoreCompare != 0) return scoreCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
  return rides;
});

/// Holds the feed list locally so likes/votes can be toggled optimistically
/// without waiting on a Firestore round-trip. Seeded from [rideFeedProvider]
/// once it resolves.
final rideFeedNotifierProvider =
    StateNotifierProvider<RideFeedNotifier, List<SharedRideEntity>>((ref) {
  final rides = ref.watch(rideFeedProvider).valueOrNull ?? [];
  return RideFeedNotifier(ref, rides);
});

class RideFeedNotifier extends StateNotifier<List<SharedRideEntity>> {
  RideFeedNotifier(this._ref, List<SharedRideEntity> initial) : super(initial);

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

  /// Casts/changes/clears a vote (1 upvote, -1 downvote). Tapping the same
  /// arrow again clears it, mirroring RideShareRepository.vote's toggle rule.
  Future<void> vote(String rideId, int value) async {
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final ride = state.where((r) => r.id == rideId).firstOrNull;
    if (ride == null) return;

    final clearing = ride.myVote == value;
    final newVote = clearing ? null : value;
    var newUpvotes = ride.upvotes;
    var newDownvotes = ride.downvotes;
    // Undo the previous vote's tally, if any.
    if (ride.myVote == 1) newUpvotes--;
    if (ride.myVote == -1) newDownvotes--;
    // Apply the new vote's tally, if any.
    if (newVote == 1) newUpvotes++;
    if (newVote == -1) newDownvotes++;

    state = [
      for (final r in state)
        if (r.id == rideId)
          r.copyWith(myVote: newVote, upvotes: newUpvotes, downvotes: newDownvotes)
        else
          r,
    ];

    try {
      await _repo.vote(rideId, uid, value);
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
