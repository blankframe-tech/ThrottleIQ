import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/badges.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/badge_stats_counter.dart';
import 'rider_stats_provider.dart';

/// Keeps the `stats/badges` counters; overridable in tests.
final badgeStatsCounterProvider = Provider<BadgeStatsCounter>(
  (ref) => BadgeStatsCounter(),
);

/// Fire-and-forget sync of newly-earned badges into
/// `users/{uid}/earnedBadges` — the Rider Stats UI never depends on this
/// (earned/not-earned is always recomputed live from local ride data via
/// [computeBadges]); this persists a durable record for a future
/// partner-discount lookup and counts each new badge into `stats/badges`
/// in the same batch (see BadgeStatsCounter). Failures are swallowed so a
/// Firestore hiccup never disrupts the stats screen.
final badgeSyncProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  final stats = ref.watch(riderStatsProvider).valueOrNull;
  if (uid == null || stats == null) return;

  final earnedIds = computeBadges(
    stats,
  ).where((b) => b.earned).map((b) => b.def.id).toSet();
  if (earnedIds.isEmpty) return;

  try {
    final counter = ref.read(badgeStatsCounterProvider);
    final held = await counter.fetchHeldBadges(uid);
    // Only ids with no doc at all: re-saving an existing badge must not
    // count it again (the rules reject that as well).
    for (final badgeId in earnedIds.difference(held.keys.toSet())) {
      await counter.recordEarnedBadge(uid, badgeId);
    }
    // Docs written by older app versions that were never counted.
    await counter.countHeldBadges(uid, held);
  } catch (_) {
    // Best-effort background sync — badge display never depends on this.
  }
});
