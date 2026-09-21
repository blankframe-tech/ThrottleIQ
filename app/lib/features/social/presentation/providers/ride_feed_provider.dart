import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/ride_share_repository.dart';
import '../../domain/entities/shared_ride_entity.dart';
import '../../domain/feed_sort.dart';

/// How many rides each backing query fetches per page.
const int kFeedPageSize = 20;

/// Which ordering the feed chips have selected.
///
/// Deliberately NOT persisted, mirroring `rideSortProvider` on Stats: a sort
/// is a momentary "show me what's hot", not a preference. Defaults to
/// [FeedSort.recent] — opening the tab should show what riders just posted.
final feedSortProvider = StateProvider<FeedSort>((ref) => FeedSort.recent);

/// Uids the signed-in rider follows.
///
/// The follow graph is small (one doc per edge) and already fetched whole by
/// `FollowRepository.getFollowing`.
final followingUidsProvider = FutureProvider<Set<String>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const {};
  return (await FollowRepository().getFollowing(uid)).toSet();
});

/// Fetches a single shared ride by ID.
final sharedRideProvider = FutureProvider.autoDispose
    .family<SharedRideEntity?, String>(
        (ref, rideId) async => RideShareRepository().getSharedRide(rideId));

/// The signed-in rider's own shared rides — reached from the garage header's
/// user menu (My Shared Rides), not the feed.
final myRidesProvider = FutureProvider<List<SharedRideEntity>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return [];
  return RideShareRepository().getMyRides(uid);
});

/// One page-load's worth of feed state.
///
/// Replaces the old `FutureProvider` + separate optimistic-state notifier
/// pair. That shape could not paginate — the future resolved once with three
/// 20-document queries merged client-side, and rebuilding the notifier from it
/// discarded any in-flight optimistic vote (issues §83.20).
class FeedState {
  const FeedState({
    this.rides = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<SharedRideEntity> rides;
  final bool isLoading;
  final bool isLoadingMore;

  /// False once a page came back short, meaning every source is exhausted.
  final bool hasMore;
  final Object? error;

  FeedState copyWith({
    List<SharedRideEntity>? rides,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) =>
      FeedState(
        rides: rides ?? this.rides,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

final rideFeedNotifierProvider =
    StateNotifierProvider<RideFeedNotifier, FeedState>(
        (ref) => RideFeedNotifier(ref)..refresh());

/// What the feed list actually renders: the held feed run through the
/// selected [FeedSort], with blocked riders removed.
final visibleFeedProvider = Provider<List<SharedRideEntity>>((ref) {
  final rides = ref.watch(rideFeedNotifierProvider).rides;
  final sort = ref.watch(feedSortProvider);
  final following =
      ref.watch(followingUidsProvider).valueOrNull ?? const <String>{};
  final blockedUids =
      ref.watch(blockedUsersProvider).valueOrNull ?? const <String>{};

  final unblocked =
      rides.where((ride) => !blockedUids.contains(ride.userId)).toList();
  return sortFeed(unblocked, sort, followingUids: following);
});

class RideFeedNotifier extends StateNotifier<FeedState> {
  RideFeedNotifier(this._ref) : super(const FeedState());

  /// A notifier holding fixed content that never reaches Firestore, for widget
  /// tests that want to render the feed without a Firebase app.
  @visibleForTesting
  RideFeedNotifier.seeded(this._ref, List<SharedRideEntity> rides)
      : super(FeedState(rides: rides, isLoading: false, hasMore: false));

  final Ref _ref;

  /// Lazy: constructing [RideShareRepository] touches
  /// `FirebaseFirestore.instance`, which throws with no Firebase app. Keeping
  /// it late means [RideFeedNotifier.seeded] never triggers that.
  late final _repo = RideShareRepository();

  /// The oldest `createdAt` currently held — the cursor every backing query
  /// pages from. Ties on this value can re-fetch a ride; the id-keyed merge in
  /// [_merge] makes that harmless.
  DateTime? _cursor;

  /// Reloads the feed from the top, dropping the cursor.
  Future<void> refresh() async {
    _cursor = null;
    state = state.copyWith(isLoading: true, clearError: true, hasMore: true);
    try {
      final page = await _fetchPage();
      state = FeedState(
        rides: page,
        isLoading: false,
        hasMore: page.length >= kFeedPageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Appends the next page. No-op while one is already in flight, or once a
  /// short page has proved there is nothing left.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _fetchPage();
      final merged = _merge(state.rides, page);
      state = state.copyWith(
        rides: merged,
        isLoadingMore: false,
        // Judged on what the queries returned, not on what survived the merge:
        // a page that was entirely duplicates still means the sources had more.
        hasMore: page.length >= kFeedPageSize,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  /// One page from every source the rider can see, merged newest-first.
  ///
  /// Firestore rules can't filter a single list query across audiences (see
  /// firestore.rules `rideVisibleTo`), so this fans out to the queries that
  /// each line up with one visibility clause.
  Future<List<SharedRideEntity>> _fetchPage() async {
    final uid = _ref.read(currentUserProvider)?.uid;
    // The "Following" chip needs rides BY the people the rider follows, which
    // the public-discovery query can't be relied on to contain — that was the
    // empty-Following bug. Fetched as its own source so the chip filters a
    // superset rather than a 20-ride sample.
    final following =
        _ref.read(followingUidsProvider).valueOrNull ?? const <String>{};

    // hydrateVotes: false on every source — these four result sets overlap
    // heavily, and hydrating inside each query would fetch the same ride's
    // vote up to four times. Hydrate once, after the merge (issues §83.20).
    final results = await Future.wait([
      _repo.getPublicRides(
          limit: kFeedPageSize, before: _cursor, hydrateVotes: false),
      if (uid != null)
        _repo.getSharedToMe(uid,
            limit: kFeedPageSize, before: _cursor, hydrateVotes: false)
      else
        Future.value(<SharedRideEntity>[]),
      if (uid != null)
        _repo.getMyRides(uid,
            limit: kFeedPageSize, before: _cursor, hydrateVotes: false)
      else
        Future.value(<SharedRideEntity>[]),
      if (following.isNotEmpty)
        _repo.getRidesByAuthors(following,
            limit: kFeedPageSize, before: _cursor, hydrateVotes: false)
      else
        Future.value(<SharedRideEntity>[]),
    ]);

    final byId = <String, SharedRideEntity>{};
    for (final list in results) {
      for (final ride in list) {
        byId[ride.id] = ride;
      }
    }
    final page = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (page.isNotEmpty) _cursor = page.last.createdAt;
    return _repo.hydrateVotesFor(page);
  }

  /// Existing rides win over refetched copies, so an optimistic vote already
  /// applied locally isn't stomped by a server value that hasn't caught up.
  List<SharedRideEntity> _merge(
    List<SharedRideEntity> existing,
    List<SharedRideEntity> incoming,
  ) {
    final seen = {for (final r in existing) r.id};
    return [
      ...existing,
      ...incoming.where((r) => !seen.contains(r.id)),
    ];
  }

  /// Casts/changes/clears a vote (1 upvote, -1 downvote). Tapping the same
  /// arrow again clears it, mirroring RideShareRepository.vote's toggle rule.
  Future<void> vote(String rideId, int value) async {
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final ride = state.rides.where((r) => r.id == rideId).firstOrNull;
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

    state = state.copyWith(rides: [
      for (final r in state.rides)
        if (r.id == rideId)
          r.copyWith(
              myVote: newVote, upvotes: newUpvotes, downvotes: newDownvotes)
        else
          r,
    ]);

    try {
      await _repo.vote(rideId, uid, value);
    } catch (_) {
      // Revert on failure.
      state = state.copyWith(rides: [
        for (final r in state.rides)
          if (r.id == rideId) ride else r,
      ]);
    }
  }

  /// Patches the cached comment count for [rideId] after a successful post,
  /// mirroring the optimistic list-patch pattern used by [vote].
  void incrementCommentCount(String rideId) {
    state = state.copyWith(rides: [
      for (final r in state.rides)
        if (r.id == rideId) r.copyWith(comments: r.comments + 1) else r,
    ]);
  }
}
