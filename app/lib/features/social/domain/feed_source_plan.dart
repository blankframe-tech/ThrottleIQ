import 'entities/shared_ride_entity.dart';

/// Firestore's cap on the number of values in a `whereIn` filter.
const int kFirestoreWhereInLimit = 30;

/// Per-author limit for the `followers`/`mutual` ride queries (issues §90.A1).
///
/// Those queries exist only because firestore.rules can prove a restricted
/// ride readable for ONE pinned author at a time (`rideVisibleTo`'s live
/// follow-graph clauses, §88.1) — they can't be folded into a `whereIn`. They
/// used to run with the full page limit (20) per followed author, so following
/// 30 riders cost up to 600 reads per page. Restricted posts are the minority
/// of a rider's shares, so a handful per author per page is plenty; the merge
/// horizon (see `mergeFeedSources`) pages further back when an author really
/// has more.
const int kRestrictedPerAuthorLimit = 5;

/// Splits [items] into consecutive chunks of at most [size] (order kept).
List<List<T>> chunkList<T>(List<T> items, [int size = kFirestoreWhereInLimit]) {
  assert(size > 0);
  return [
    for (var i = 0; i < items.length; i += size)
      items.sublist(i, i + size > items.length ? items.length : i + size),
  ];
}

/// The restricted audiences the viewer may query for one followed author:
/// `followers` always (they follow the author), plus `mutual` only when the
/// author follows back — firestore.rules denies a query naming `mutual`
/// otherwise.
List<String> restrictedAudiencesFor(String author, Set<String> mutualUids) =>
    mutualUids.contains(author)
        ? const ['followers', 'mutual']
        : const ['followers'];

/// Whether a feed source can be skipped on every later (older) page.
///
/// A source that came back short has nothing older than what it returned —
/// but only if none of what it returned was cut off by the merge horizon
/// ([cut], the next page's cursor): those cut rides are only seen again by
/// re-querying the source. Skipping exhausted sources is what keeps
/// `loadMore` from re-paying one read per followed author (Firestore bills an
/// empty query as one read) for authors with no restricted posts at all.
bool isFeedSourceExhausted(
  List<SharedRideEntity> rides, {
  required int limit,
  required DateTime? cut,
}) {
  if (rides.length >= limit) return false;
  if (cut == null) return true;
  return rides.every((r) => !r.createdAt.isBefore(cut));
}
