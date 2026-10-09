import '../../features/ride/domain/entities/ride_entity.dart';
import 'badges.dart';
import 'riding_score.dart';

/// Badge rarity: how many riders own a badge, and the tier that implies.
///
/// The counts come from the `stats/badges` doc, which the clients keep
/// themselves (features/stats/data/badge_stats_counter.dart, guarded by
/// firestore.rules). Everything here is pure so the mapping and
/// the percentage are unit-tested without Firestore; the provider that reads
/// the doc lives in features/stats/presentation/providers/.
///
/// Rule throughout: an unknown number is `null`, never a guess. The UI hides
/// the figure (or shows "—") rather than invent one.

/// Rarity tiers, most common first.
enum BadgeRarity { common, uncommon, rare, epic, legendary }

/// Upper bounds (exclusive, in percent of riders) for each rarer tier.
/// Anything at or above [uncommonBelow] is Common.
const double legendaryBelow = 1;
const double epicBelow = 5;
const double rareBelow = 15;
const double uncommonBelow = 40;

/// The tier for a share of riders, in percent (0–100).
BadgeRarity rarityForPercent(double percent) {
  if (percent < legendaryBelow) return BadgeRarity.legendary;
  if (percent < epicBelow) return BadgeRarity.epic;
  if (percent < rareBelow) return BadgeRarity.rare;
  if (percent < uncommonBelow) return BadgeRarity.uncommon;
  return BadgeRarity.common;
}

/// Percent of riders owning a badge, or null when it can't be said honestly.
///
/// Null when the total is unknown or zero, or the owner count is unknown.
/// Owners are clamped into `0..totalRiders`: the counts are bumped
/// separately (a rider's badges can be counted before the rider is), and
/// "104% of riders" is never a true statement.
///
/// [ownedByViewer]: the viewer has this badge locally, so the true count is
/// at least 1. A server count of 0 then just means their award hasn't synced
/// or been counted yet — that figure is known to be stale, so it is withheld
/// rather than shown as "0% of riders" to someone holding the badge.
double? ownershipPercent({
  required int? owners,
  required int? totalRiders,
  bool ownedByViewer = false,
}) {
  if (owners == null || totalRiders == null || totalRiders <= 0) return null;
  if (ownedByViewer && owners < 1) return null;
  final clamped = owners.clamp(0, totalRiders);
  return clamped / totalRiders * 100;
}

/// "37%", with the ends kept truthful: a non-zero share under 1% reads
/// "<1%" rather than rounding to "0%", and a share short of everyone reads
/// ">99%" rather than rounding up to "100%".
String formatOwnershipPercent(double percent) {
  if (percent <= 0) return '0%';
  if (percent < 1) return '<1%';
  if (percent >= 100) return '100%';
  if (percent > 99) return '>99%';
  return '${percent.round()}%';
}

/// Fewest counted riders before any ownership share is shown. Below this a
/// single rider moves a share by 5+ points, and with three riders every
/// badge nobody else has reads "Legendary"; the sheet shows "—" instead.
const int minRidersForRarity = 20;

/// The parsed `stats/badges` doc.
class BadgeOwnershipStats {
  final int totalRiders;
  final Map<String, int> owners;

  const BadgeOwnershipStats({required this.totalRiders, required this.owners});

  /// Null when the doc is missing or malformed — callers treat that exactly
  /// like being offline with nothing cached.
  static BadgeOwnershipStats? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final total = data['totalRiders'];
    if (total is! num || total <= 0) return null;
    final raw = data['owners'];
    final owners = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is String && value is num) owners[key] = value.toInt();
      });
    }
    return BadgeOwnershipStats(totalRiders: total.toInt(), owners: owners);
  }

  /// Whether enough riders are counted for a share to mean anything.
  bool get hasEnoughRiders => totalRiders >= minRidersForRarity;

  /// Percent of riders owning [badgeId]; see [ownershipPercent]. Null
  /// below [minRidersForRarity] riders.
  ///
  /// A badge id missing from `owners` counts as zero: the client-side
  /// counters only create a key when the first rider's badge is counted
  /// (BadgeStatsCounter). A viewer holding the badge still gets null there
  /// (see [ownershipPercent]'s `ownedByViewer`), since their own award
  /// evidently hasn't been counted yet.
  double? percentFor(String badgeId, {bool ownedByViewer = false}) =>
      !hasEnoughRiders
          ? null
          : ownershipPercent(
              owners: owners[badgeId] ?? 0,
              totalRiders: totalRiders,
              ownedByViewer: ownedByViewer,
            );
}

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
  var topSpeed = 0.0;
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
    if (r.maxSpeedKmh > topSpeed) topSpeed = r.maxSpeedKmh;
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
      topSpeedKmh: topSpeed,
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
