import '../../features/ride/domain/entities/ride_entity.dart';
import 'badges.dart';
import 'riding_score.dart';

/// When each badge was first earned, replayed from the rider's own rides.
///
/// Walks the rides oldest-first, keeping the same running figures as
/// [BadgeStats.from], and stamps each badge with the ride that first carried
/// it over its threshold (that ride's end time, falling back to its start).
/// Local and offline, and the real date — unlike the `earnedAt` on the
/// synced Firestore record, which is when the app happened to sync it.
///
/// A badge earned and since lost (Smoothness is an average, so it can dip)
/// keeps its first date; the UI only shows dates for currently-earned badges.
Map<String, DateTime> computeBadgeEarnedDates(List<RideEntity> rides) {
  final ordered = [...rides]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final dates = <String, DateTime>{};

  var totalRides = 0;
  var totalKm = 0.0;
  var scoreSum = 0;
  var longestKm = 0.0;
  var longestSeconds = 0;
  var night = 0;
  var early = 0;
  DateTime? lastDay;
  var run = 0;
  var bestStreak = 0;

  for (final r in ordered) {
    totalRides++;
    totalKm += r.distanceKm;
    scoreSum += computeRidingScore(
      hardBrakes: r.hardBrakeCount,
      rapidAccel: r.rapidAccelCount,
      highJerk: r.highJerkCount,
    );
    if (r.distanceKm > longestKm) longestKm = r.distanceKm;
    final seconds = r.durationSeconds ?? 0;
    if (seconds > longestSeconds) longestSeconds = seconds;
    if (BadgeStats.isNightRide(r.startTime)) night++;
    if (BadgeStats.isEarlyRide(r.startTime)) early++;

    final day = DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
    if (lastDay == null) {
      run = 1;
    } else if (day != lastDay) {
      // Same DST-tolerant window as computeLongestDayStreak.
      final gap = day.difference(lastDay).inHours;
      run = (gap >= 20 && gap <= 28) ? run + 1 : 1;
    }
    lastDay = day;
    if (run > bestStreak) bestStreak = run;

    final stats = BadgeStats(
      totalRides: totalRides,
      totalDistanceKm: totalKm,
      smoothnessScore: totalRides >= BadgeStats.smoothnessRideFloor
          ? scoreSum / totalRides
          : 0,
      longestRideKm: longestKm,
      longestRideHours: longestSeconds / 3600,
      nightRides: night,
      earlyRides: early,
      longestDayStreak: bestStreak,
    );
    final when = r.endTime ?? r.startTime;
    for (final def in badgeDefs) {
      if (!dates.containsKey(def.id) && def.isEarned(stats)) {
        dates[def.id] = when;
      }
    }
  }
  return dates;
}
