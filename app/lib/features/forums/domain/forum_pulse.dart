import 'entities/forum_post_entity.dart';

/// The Pulse feed: recent posts across the rider's garage forums and the
/// forums they follow, merged newest-first. Pure pieces live here so the
/// source selection and the filter chips are testable without Firestore.

/// Most source forums one Pulse page reads from. Every source costs up to
/// [kPulsePerSourceLimit] post reads per page (plus a vote read per post
/// shown), so this is the read-cost ceiling: 8 × 10 = 80 posts per page.
const int kPulseMaxSources = 8;

/// Posts read per source forum per Pulse page. Smaller than a thread's
/// `kForumPostsPageSize` (25) because Pulse fans out over several forums at
/// once; `mergeForumPostPages` keeps the merge hole-free at any page size.
const int kPulsePerSourceLimit = 10;

/// The chip row above the Pulse feed.
enum PulseFilter { all, myBikes, help, diy, mostVoted, saved }

/// Which forums feed Pulse: garage forums first (they're why the rider is
/// here), then followed forums, de-duplicated, capped at [max].
List<String> pulseSourceForumIds({
  required List<String> garageForumIds,
  required List<String> followedForumIds,
  int max = kPulseMaxSources,
}) {
  final seen = <String>{};
  final ids = <String>[];
  for (final id in [...garageForumIds, ...followedForumIds]) {
    if (id.isEmpty || !seen.add(id)) continue;
    ids.add(id);
    if (ids.length >= max) break;
  }
  return ids;
}

/// Applies a chip to the posts already loaded — client-side, zero reads.
/// [PulseFilter.saved] is not a post filter (saved posts come from the local
/// bookmark store) and returns an empty list here.
List<ForumPostEntity> filterPulsePosts(
  List<ForumPostEntity> posts,
  PulseFilter filter, {
  Set<String> garageForumIds = const {},
}) {
  switch (filter) {
    case PulseFilter.all:
      return posts;
    case PulseFilter.myBikes:
      return [for (final p in posts) if (garageForumIds.contains(p.forumId)) p];
    case PulseFilter.help:
      return [for (final p in posts) if (p.postType == ForumPostType.troubleshoot) p];
    case PulseFilter.diy:
      return [for (final p in posts) if (p.postType == ForumPostType.diyGuide) p];
    case PulseFilter.mostVoted:
      final voted = [for (final p in posts) if (p.netScore > 0) p];
      voted.sort((a, b) {
        final byScore = b.netScore.compareTo(a.netScore);
        if (byScore != 0) return byScore;
        return b.createdAt.compareTo(a.createdAt);
      });
      return voted;
    case PulseFilter.saved:
      return const [];
  }
}
