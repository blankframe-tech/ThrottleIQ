import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/badge_earned_dates.dart';
import 'rider_stats_provider.dart';

/// When each currently-known badge was first earned, replayed from local
/// rides (see [computeBadgeEarnedDates]). Empty until ride stats load.
final badgeEarnedDatesProvider = Provider<Map<String, DateTime>>((ref) {
  final stats = ref.watch(riderStatsProvider).valueOrNull;
  // allRides only: replaying the truncated recentRides would date a
  // cumulative badge by the wrong ride. No full history means no dates.
  if (stats == null || stats.allRides.isEmpty) return const {};
  return computeBadgeEarnedDates(stats.allRides);
});
