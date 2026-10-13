import 'entities/shared_ride_entity.dart';

/// One merged page of the Social feed, built from several independently
/// paged Firestore queries (public, shared-to-me, mine, followed authors).
class MergedFeedPage {
  const MergedFeedPage({
    required this.rides,
    required this.cursor,
    required this.hasMore,
  });

  /// De-duplicated, newest first.
  final List<SharedRideEntity> rides;

  /// The `createdAt` every source should page from next (`startAfter`), or
  /// null when nothing came back.
  final DateTime? cursor;

  /// True while at least one source returned a full page.
  final bool hasMore;
}

/// Merges one page from each feed source without leaving holes.
///
/// Each source is fetched with the same `limit` from the same cursor, but the
/// sources don't cover the same stretch of time: a dense one (every public
/// ride) might only reach back an hour in 20 documents, while a sparse one
/// (the four riders you follow) reaches back a month. The old merge set the
/// next cursor to the oldest ride across *all* sources — so the next page of
/// the dense source started a month back and silently skipped everything it
/// had between "an hour ago" and "a month ago". That is how posts from
/// followed riders went missing from the feed while they were actively
/// sharing: a followed rider's `followers`-only post (or a public one past
/// the first page) lived in exactly that skipped window.
///
/// The fix is the classic k-way-merge horizon: a source that returned a full
/// page may have more rides just older than its last one, so nothing older
/// than the *newest* such horizon can be shown yet. Everything at or after it
/// is complete across every source; everything older is dropped from this
/// page and re-fetched (and de-duplicated by id) on the next.
///
/// [pageSizes], when given, is the `limit` each source (same index) was
/// queried with — sources don't all share one: the per-author restricted
/// queries use a much smaller limit than the public ones (issues §90.A1), and
/// a source is "full" relative to its OWN limit. Defaults to [pageSize] for
/// every source.
MergedFeedPage mergeFeedSources(
  List<List<SharedRideEntity>> sources, {
  required int pageSize,
  List<int>? pageSizes,
}) {
  assert(pageSizes == null || pageSizes.length == sources.length);
  final byId = <String, SharedRideEntity>{};
  DateTime? horizon;
  for (var i = 0; i < sources.length; i++) {
    final source = sources[i];
    final limit = pageSizes?[i] ?? pageSize;
    for (final ride in source) {
      byId[ride.id] = ride;
    }
    if (source.length >= limit && source.isNotEmpty) {
      final oldest = source
          .map((r) => r.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      if (horizon == null || oldest.isAfter(horizon)) horizon = oldest;
    }
  }

  final all = byId.values.toList()
    ..sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });

  if (horizon == null) {
    // Every source is exhausted: everything fetched is the complete tail.
    return MergedFeedPage(
      rides: all,
      cursor: all.isEmpty ? null : all.last.createdAt,
      hasMore: false,
    );
  }

  final cut = horizon;
  return MergedFeedPage(
    rides: [
      for (final r in all)
        if (!r.createdAt.isBefore(cut)) r,
    ],
    cursor: cut,
    hasMore: true,
  );
}
