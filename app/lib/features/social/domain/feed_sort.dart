import 'entities/shared_ride_entity.dart';

/// How the social feed is ordered (and, for [FeedSort.following], filtered).
///
/// Pure and Flutter-free so the ordering can be tested directly — see
/// `test/features/social/feed_sort_test.dart`. Mirrors
/// `lib/features/stats/domain/ride_sort.dart`, which does the same job for the
/// rides list on Stats.
enum FeedSort {
  /// Most upvoted first.
  hot,

  /// Newest first — the default.
  recent,

  /// Only rides by riders you follow, newest first.
  following,
}

extension FeedSortLabel on FeedSort {
  /// Short label for the feed chips.
  String get label {
    switch (this) {
      case FeedSort.hot:
        return 'Hot';
      case FeedSort.recent:
        return 'Recent';
      case FeedSort.following:
        return 'Following';
    }
  }
}

/// Orders (and for [FeedSort.following], filters) [rides] for display.
///
/// Returns a NEW list — the input is never mutated, because callers pass the
/// provider-owned feed list that must not be reordered underneath other
/// widgets (same contract as `sortRides`).
///
/// [followingUids] is the set of riders the signed-in rider follows; it is
/// only read by [FeedSort.following]. An empty set there yields an empty
/// feed — deliberately, so the UI can say "follow someone" rather than
/// silently falling back to a feed that ignores the chip the rider just
/// tapped.
///
/// Tie-breaking: [FeedSort.hot] falls back to recency, exactly like every
/// non-recency ordering in `ride_sort.dart` — score ties are the common case
/// (a brand-new feed is all zeroes), and without it two rides on the same
/// score would land in whatever order the three merged Firestore queries
/// happened to return. Recency ties then fall back to the ride id, because
/// this feed is merged from three queries whose `createdAt` values can be
/// identical to the millisecond (a re-share writes the same timestamp), and an
/// unbroken tie makes the list visibly reshuffle between rebuilds.
///
/// Missing values sort last, as on Stats: `upvotes`/`downvotes` default to 0
/// for rides shared before voting existed, so an unvoted ride ranks below
/// anything with a positive score instead of being treated as hot.
List<SharedRideEntity> sortFeed(
  List<SharedRideEntity> rides,
  FeedSort sort, {
  Set<String> followingUids = const {},
}) {
  int byRecency(SharedRideEntity a, SharedRideEntity b) {
    final c = b.createdAt.compareTo(a.createdAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  switch (sort) {
    case FeedSort.hot:
      return [...rides]..sort((a, b) {
          final c = b.netScore.compareTo(a.netScore);
          return c != 0 ? c : byRecency(a, b);
        });
    case FeedSort.recent:
      return [...rides]..sort(byRecency);
    case FeedSort.following:
      return [
        for (final ride in rides)
          if (followingUids.contains(ride.userId)) ride,
      ]..sort(byRecency);
  }
}
