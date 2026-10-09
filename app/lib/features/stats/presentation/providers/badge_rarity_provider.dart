import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/badge_rarity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'rider_stats_provider.dart';

/// `stats/badges`, the aggregate the clients keep (BadgeStatsCounter).
///
/// Read once per signed-in session and held (a plain, non-autoDispose
/// provider), not listened to: every award by any rider rewrites this doc,
/// and a live listener would stream those to every open app for a figure
/// that only needs to be roughly current. Firestore's offline cache backs the
/// read, so a rider who has loaded it once still sees it offline.
///
/// Resolves to null — never throws — when signed out, offline with nothing
/// cached, the doc doesn't exist yet, or it is malformed. The detail sheet
/// then hides the figure and the rarity tier.
final badgeOwnershipStatsProvider = FutureProvider<BadgeOwnershipStats?>((
  ref,
) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return null;

  final doc = FirebaseFirestore.instance.collection('stats').doc('badges');
  try {
    // Default source: server, falling back to the local cache when offline.
    final snap = await doc.get();
    return BadgeOwnershipStats.fromMap(snap.data());
  } catch (_) {
    try {
      final cached = await doc.get(const GetOptions(source: Source.cache));
      return BadgeOwnershipStats.fromMap(cached.data());
    } catch (_) {
      return null;
    }
  }
});

/// When each currently-known badge was first earned, replayed from local
/// rides (see [computeBadgeEarnedDates]). Empty until ride stats load.
final badgeEarnedDatesProvider = Provider<Map<String, DateTime>>((ref) {
  final stats = ref.watch(riderStatsProvider).valueOrNull;
  // allRides only: replaying the truncated recentRides would date a
  // cumulative badge by the wrong ride. No full history means no dates.
  if (stats == null || stats.allRides.isEmpty) return const {};
  return computeBadgeEarnedDates(stats.allRides);
});
