import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/badges.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/data/repositories/challenge_repository.dart';
import 'rider_stats_provider.dart';

/// Fire-and-forget sync of newly-earned badges into
/// `users/{uid}/earnedBadges` — the Rider Stats UI never depends on this
/// (earned/not-earned is always recomputed live from local ride data via
/// [computeBadges]); this only persists a durable record for a future
/// partner-discount lookup. Failures are swallowed so a Firestore hiccup
/// never disrupts the stats screen.
final badgeSyncProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  final stats = ref.watch(riderStatsProvider).valueOrNull;
  if (uid == null || stats == null) return;

  final earnedIds =
      computeBadges(stats).where((b) => b.earned).map((b) => b.def.id).toSet();
  if (earnedIds.isEmpty) return;

  try {
    final repo = ChallengeRepository();
    final synced = (await repo.getEarnedBadges(uid))
        .map((m) => m['badgeId'] as String?)
        .whereType<String>()
        .toSet();
    for (final badgeId in earnedIds.difference(synced)) {
      await repo.earnMilestoneBadge(userId: uid, badgeId: badgeId);
    }
  } catch (_) {
    // Best-effort background sync — badge display never depends on this.
  }
});
