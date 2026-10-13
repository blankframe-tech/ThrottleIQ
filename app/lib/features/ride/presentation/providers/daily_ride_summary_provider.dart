import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/daily_ride_summary_repository.dart';
import '../../domain/calculators/daily_ride_summary.dart';

final dailyRideSummaryRepositoryProvider =
    Provider<DailyRideSummaryRepository>((ref) => DailyRideSummaryRepository());

/// Today's auto-tracking summary: manual rides plus rides the background
/// tracker caught that weren't recorded, jam-split fragments merged. Null
/// when signed out.
///
/// Invalidated by `AutoRideReconcilerService` whenever it moves detections
/// into the summary; otherwise recomputed on next watch.
final dailyRideSummaryProvider =
    FutureProvider.autoDispose<DailyRideSummary?>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return null;
  return ref.read(dailyRideSummaryRepositoryProvider).summaryFor(
        uid,
        DateTime.now(),
      );
});

/// The last two weeks of daily summaries, newest first, days with no riding
/// left out. Backs the auto-tracking history sheet.
final recentDailyRideSummariesProvider =
    FutureProvider.autoDispose<List<DailyRideSummary>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const [];
  ref.watch(dailyRideSummaryProvider);
  final days =
      await ref.read(dailyRideSummaryRepositoryProvider).recentDays(uid);
  return days.where((d) => !d.isEmpty).toList();
});
