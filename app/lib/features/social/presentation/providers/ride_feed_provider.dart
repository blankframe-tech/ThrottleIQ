import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../domain/feed_sort.dart';

/// Which ordering the feed chips have selected.
///
/// Deliberately NOT persisted, mirroring `rideSortProvider` on Stats: a sort
/// is a momentary "show me what's hot", not a preference. Defaults to
/// [FeedSort.recent] — opening the tab should show what riders just posted.
final feedSortProvider = StateProvider<FeedSort>((ref) => FeedSort.recent);

/// Uids the signed-in rider follows, for [FeedSort.following].
///
/// The follow graph is small (one doc per edge) and already fetched whole by
/// `FollowRepository.getFollowing`, so filtering the merged feed against this
/// set client-side needs no extra Firestore query — and therefore no new
/// composite index or rules clause.
final followingUidsProvider = FutureProvider<Set<String>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const {};
  return (await FollowRepository().getFollowing(uid)).toSet();
});

/// The rider's feed: public rides + rides shared to them (followers/mutual)
/// + their own shared rides, deduped and ordered newest-first.
///
/// Firestore rules can't filter a single list query across audiences (see
/// firestore.rules `rideVisibleTo`), so this fans out to the three queries
/// that each line up with one visibility clause and merges client-side. Each
/// query already asks Firestore for `createdAt` descending; the merge is
/// re-sorted here because interleaving three sorted lists doesn't preserve
/// the order.
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

  return sortFeed(byId.values.toList(), FeedSort.recent);
});

/// The signed-in rider's own shared rides — reached from the garage header's
/// user menu (My Shared Rides), not the feed. Unlike [rideFeedProvider] this
/// isn't deduped/ranked against other visibility tiers; it's just "everything
/// I've shared", regardless of audience.
final myRidesProvider = FutureProvider<List<SharedRideEntity>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return [];
  return RideShareRepository().getMyRides(uid);
});

/// Holds the feed list locally so likes/votes can be toggled optimistically
/// without waiting on a Firestore round-trip. Seeded from [rideFeedProvider]
/// once it resolves.
final rideFeedNotifierProvider =
    StateNotifierProvider<RideFeedNotifier, List<SharedRideEntity>>((ref) {
  final rides = ref.watch(rideFeedProvider).valueOrNull ?? [];
  return RideFeedNotifier(ref, rides);
});

/// What the feed list actually renders: the locally-held feed
/// ([rideFeedNotifierProvider], so optimistic like/vote edits show through)
/// run through the selected [FeedSort].
///
/// Ordering lives in the pure `sortFeed` rather than in the Firestore queries
/// because the feed is a client-side merge of three queries — no single query
/// could order it, and re-fetching on every chip tap would be a round-trip for
/// data already in memory.
final visibleFeedProvider = Provider<List<SharedRideEntity>>((ref) {
  final rides = ref.watch(rideFeedNotifierProvider);
  final sort = ref.watch(feedSortProvider);
  final following = ref.watch(followingUidsProvider).valueOrNull ?? const <String>{};
  final blockedUids = ref.watch(blockedUsersProvider).valueOrNull ?? const <String>{};
  
  // Filter out any rides from blocked users
  final unblockedRides = rides.where((ride) => !blockedUids.contains(ride.userId)).toList();
  
  return sortFeed(unblockedRides, sort, followingUids: following);
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
