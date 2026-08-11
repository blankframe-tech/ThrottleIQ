import 'package:flutter/material.dart';

import '../../features/ride/domain/entities/ride_entity.dart';
import 'rider_stats.dart';

/// Milestone badges.
///
/// Earned/not-earned is always a pure function of the rider's local ride
/// history, so the UI never waits on a network round trip to know what's
/// earned.
///
/// Badges are expressed as *ladders*, not as a flat list of hand-written
/// predicates. A [BadgeFamily] names one measurable thing about the rider
/// (total distance, longest single ride, night rides…) and carries the
/// thresholds at which it awards Bronze → Diamond. Adding a rung is one line
/// of data; the earned test, the "how to earn it" copy and the progress
/// figure all fall out of the family definition.
///
/// Badge **ids are persisted** (`users/{uid}/earnedBadges`, see
/// badge_sync_provider.dart), so every id here is stable copy — never
/// regenerate them from the threshold.

/// Rungs of a badge ladder, lowest to highest.
enum BadgeTier { bronze, silver, gold, platinum, diamond }

extension BadgeTierLabel on BadgeTier {
  String get label {
    switch (this) {
      case BadgeTier.bronze:
        return 'Bronze';
      case BadgeTier.silver:
        return 'Silver';
      case BadgeTier.gold:
        return 'Gold';
      case BadgeTier.platinum:
        return 'Platinum';
      case BadgeTier.diamond:
        return 'Diamond';
    }
  }
}

/// One rung: the stable id, its display name, and the value that earns it.
class BadgeTierSpec {
  final String id;
  final String name;
  final BadgeTier tier;
  final num threshold;

  const BadgeTierSpec({
    required this.id,
    required this.name,
    required this.tier,
    required this.threshold,
  });
}

/// One measurable thing about a rider, plus the ladder of thresholds on it.
class BadgeFamily {
  final String id;
  final String name;
  final IconData icon;

  /// Suffix for figures on this ladder ('km', 'rides'). Kept separate from
  /// the copy so progress ("420 / 500 km") formats itself.
  final String unit;

  /// What this family measures, in one sentence — shown when the rider taps
  /// a badge they have already earned.
  final String about;

  /// How to earn a rung. `{n}` is replaced with the threshold.
  final String requirement;

  /// The rider's current standing on this ladder.
  final num Function(BadgeStats stats) valueOf;

  /// Lowest threshold first. Fewer than five rungs is fine — not every
  /// measure has a sensible Diamond.
  final List<BadgeTierSpec> tiers;

  const BadgeFamily({
    required this.id,
    required this.name,
    required this.icon,
    required this.unit,
    required this.about,
    required this.requirement,
    required this.valueOf,
    required this.tiers,
  });

  String requirementFor(num threshold) =>
      requirement.replaceAll('{n}', formatBadgeValue(threshold));
}

/// A single badge: one rung of one family. Built by flattening
/// [badgeFamilies] — there are no free-standing badges.
class BadgeDef {
  final BadgeFamily family;
  final BadgeTierSpec spec;

  const BadgeDef(this.family, this.spec);

  String get id => spec.id;
  String get name => spec.name;
  BadgeTier get tier => spec.tier;
  num get threshold => spec.threshold;
  IconData get icon => family.icon;

  /// The whole earned test, for every badge in the app.
  bool isEarned(BadgeStats stats) => family.valueOf(stats) >= threshold;
}

class EarnedBadge {
  final BadgeDef def;
  final bool earned;
  const EarnedBadge(this.def, this.earned);
}

/// One family with the rider's standing on it — what the badge grid renders.
class BadgeFamilyProgress {
  final BadgeFamily family;
  final num value;
  final List<EarnedBadge> badges;

  const BadgeFamilyProgress({
    required this.family,
    required this.value,
    required this.badges,
  });

  int get earnedCount => badges.where((b) => b.earned).length;

  /// The highest rung earned, or null if none — the family's headline tier.
  BadgeTier? get highestTier {
    BadgeTier? best;
    for (final b in badges) {
      if (b.earned) best = b.def.tier;
    }
    return best;
  }

  /// The next rung to chase, or null once the ladder is topped out.
  EarnedBadge? get nextUp {
    for (final b in badges) {
      if (!b.earned) return b;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Measurable stats
// ---------------------------------------------------------------------------

/// Everything the badge ladders measure, derived once per evaluation.
///
/// A flat bag of numbers rather than the ride list itself, so every
/// [BadgeFamily.valueOf] is a trivial field read and the per-ride passes
/// (night rides, streaks…) happen once instead of once per badge.
class BadgeStats {
  final int totalRides;
  final double totalDistanceKm;
  final double topSpeedKmh;

  /// Average smoothness score, but **0 until the rider has 5 rides** — a
  /// perfect score off a single two-minute ride is not evidence of anything,
  /// and folding the floor into the metric keeps the ladder a plain `>=`.
  final double smoothnessScore;

  final double longestRideKm;
  final double longestRideHours;
  final int nightRides;
  final int earlyRides;
  final int longestDayStreak;

  const BadgeStats({
    this.totalRides = 0,
    this.totalDistanceKm = 0,
    this.topSpeedKmh = 0,
    this.smoothnessScore = 0,
    this.longestRideKm = 0,
    this.longestRideHours = 0,
    this.nightRides = 0,
    this.earlyRides = 0,
    this.longestDayStreak = 0,
  });

  /// Minimum rides before [smoothnessScore] reports anything.
  static const int smoothnessRideFloor = 5;

  /// A ride counts as a night ride when it *starts* at or after 21:00, or
  /// before 04:00. Start time, not end time: what makes it a night ride is
  /// setting off in the dark.
  static bool isNightRide(DateTime start) => start.hour >= 21 || start.hour < 4;

  /// 04:00–06:59. Deliberately disjoint from [isNightRide] so a 4 am start is
  /// counted once, as the early start it is.
  static bool isEarlyRide(DateTime start) => start.hour >= 4 && start.hour < 7;

  factory BadgeStats.from(RiderStatsSummary stats) {
    // Mirror the Rides tab's own fallback: an older cached summary has no
    // allRides, and per-ride badges should degrade to "not earned yet"
    // rather than read a truncated list as if it were the full history.
    final rides =
        stats.allRides.isNotEmpty ? stats.allRides : stats.recentRides;

    var longestKm = 0.0;
    var longestSeconds = 0;
    var night = 0;
    var early = 0;
    for (final r in rides) {
      if (r.distanceKm > longestKm) longestKm = r.distanceKm;
      final seconds = r.durationSeconds ?? 0;
      if (seconds > longestSeconds) longestSeconds = seconds;
      if (isNightRide(r.startTime)) night++;
      if (isEarlyRide(r.startTime)) early++;
    }

    return BadgeStats(
      totalRides: stats.totalRides,
      totalDistanceKm: stats.totalDistanceKm,
      topSpeedKmh: stats.allTimeTopSpeedKmh,
      smoothnessScore:
          stats.totalRides >= smoothnessRideFloor ? stats.avgRidingScore : 0,
      longestRideKm: longestKm,
      longestRideHours: longestSeconds / 3600,
      nightRides: night,
      earlyRides: early,
      longestDayStreak: computeLongestDayStreak(rides),
    );
  }
}

/// Longest run of consecutive calendar days on which at least one ride was
/// recorded. Two rides on the same day are one day of the streak, and input
/// order is irrelevant — days are de-duplicated and sorted first.
int computeLongestDayStreak(List<RideEntity> rides) {
  if (rides.isEmpty) return 0;

  final days = rides
      .map((r) =>
          DateTime(r.startTime.year, r.startTime.month, r.startTime.day))
      .toSet()
      .toList()
    ..sort();

  var best = 1;
  var run = 1;
  for (var i = 1; i < days.length; i++) {
    // Compare in hours with a tolerance rather than adding a day to the date:
    // across a DST boundary consecutive local midnights are 23 or 25 hours
    // apart, which `difference().inDays` truncates to 0 and would silently
    // break a streak that the rider actually rode.
    final gap = days[i].difference(days[i - 1]).inHours;
    if (gap >= 20 && gap <= 28) {
      run++;
      if (run > best) best = run;
    } else {
      run = 1;
    }
  }
  return best;
}

/// The streak the rider is *on* right now: consecutive calendar days ending
/// today or yesterday on which at least one ride was recorded.
///
/// Distinct from [computeLongestDayStreak], which is a personal best and only
/// ever grows. A dashboard number labelled "streak" has to be the live one —
/// showing a best of 14 to someone who last rode in March reads as a claim
/// that they're on a 14-day run.
///
/// Yesterday counts as still-alive so the number doesn't collapse to zero
/// every morning before the day's ride; a gap of two days or more ends it.
/// [now] is injectable so the "today" boundary is testable.
int computeCurrentDayStreak(List<RideEntity> rides, {DateTime? now}) {
  if (rides.isEmpty) return 0;

  final today = () {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }();

  final days = rides
      .map((r) =>
          DateTime(r.startTime.year, r.startTime.month, r.startTime.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a)); // newest first

  // Same hour-window comparison as computeLongestDayStreak, and for the same
  // DST reason: consecutive local midnights are 23-25 hours apart.
  bool isDayBefore(DateTime later, DateTime earlier) {
    final gap = later.difference(earlier).inHours;
    return gap >= 20 && gap <= 28;
  }

  final mostRecent = days.first;
  if (mostRecent != today && !isDayBefore(today, mostRecent)) return 0;

  var streak = 1;
  for (var i = 1; i < days.length; i++) {
    if (!isDayBefore(days[i - 1], days[i])) break;
    streak++;
  }
  return streak;
}

// ---------------------------------------------------------------------------
// The ladders
// ---------------------------------------------------------------------------

const List<BadgeFamily> badgeFamilies = [
  BadgeFamily(
    id: 'first',
    name: 'First ride',
    icon: Icons.flag_outlined,
    unit: 'rides',
    about: 'Where every rider starts — your first recorded ride.',
    requirement: 'Record your first ride.',
    valueOf: _totalRides,
    tiers: [
      BadgeTierSpec(
          id: 'first_ride',
          name: 'First ride',
          tier: BadgeTier.bronze,
          threshold: 1),
    ],
  ),
  BadgeFamily(
    id: 'rides',
    name: 'Rides',
    icon: Icons.two_wheeler_outlined,
    unit: 'rides',
    about: 'How many rides you have recorded, all time.',
    requirement: 'Record {n} rides.',
    valueOf: _totalRides,
    tiers: [
      BadgeTierSpec(
          id: 'rides_10',
          name: '10 rides',
          tier: BadgeTier.bronze,
          threshold: 10),
      BadgeTierSpec(
          id: 'rides_25',
          name: '25 rides',
          tier: BadgeTier.silver,
          threshold: 25),
      BadgeTierSpec(
          id: 'rides_50',
          name: '50 rides',
          tier: BadgeTier.gold,
          threshold: 50),
      BadgeTierSpec(
          id: 'rides_100',
          name: '100 rides',
          tier: BadgeTier.platinum,
          threshold: 100),
      BadgeTierSpec(
          id: 'rides_250',
          name: '250 rides',
          tier: BadgeTier.diamond,
          threshold: 250),
    ],
  ),
  BadgeFamily(
    id: 'distance',
    name: 'Distance',
    icon: Icons.route_outlined,
    unit: 'km',
    about: 'Total distance covered across every ride you have recorded.',
    requirement: 'Ride {n} km in total.',
    valueOf: _totalDistanceKm,
    tiers: [
      BadgeTierSpec(
          id: 'km_100', name: '100 km', tier: BadgeTier.bronze, threshold: 100),
      BadgeTierSpec(
          id: 'km_500', name: '500 km', tier: BadgeTier.silver, threshold: 500),
      BadgeTierSpec(
          id: 'km_1000',
          name: '1,000 km',
          tier: BadgeTier.gold,
          threshold: 1000),
      BadgeTierSpec(
          id: 'km_2500',
          name: '2,500 km',
          tier: BadgeTier.platinum,
          threshold: 2500),
      BadgeTierSpec(
          id: 'km_5000',
          name: '5,000 km',
          tier: BadgeTier.diamond,
          threshold: 5000),
    ],
  ),
  BadgeFamily(
    id: 'long_ride',
    name: 'Longest ride',
    icon: Icons.timeline_outlined,
    unit: 'km',
    about: 'The distance of your single longest recorded ride.',
    requirement: 'Cover {n} km in one ride.',
    valueOf: _longestRideKm,
    tiers: [
      BadgeTierSpec(
          id: 'long_ride_50',
          name: 'Day tripper',
          tier: BadgeTier.bronze,
          threshold: 50),
      BadgeTierSpec(
          id: 'long_ride_100',
          name: 'Century',
          tier: BadgeTier.silver,
          threshold: 100),
      BadgeTierSpec(
          id: 'long_ride_200',
          name: 'Long hauler',
          tier: BadgeTier.gold,
          threshold: 200),
      BadgeTierSpec(
          id: 'long_ride_400',
          name: 'Tourer',
          tier: BadgeTier.platinum,
          threshold: 400),
      BadgeTierSpec(
          id: 'long_ride_800',
          name: 'Iron rider',
          tier: BadgeTier.diamond,
          threshold: 800),
    ],
  ),
  BadgeFamily(
    id: 'saddle_time',
    name: 'Saddle time',
    icon: Icons.timer_outlined,
    unit: 'h',
    about: 'The duration of your single longest recorded ride.',
    requirement: 'Ride for {n} hours without ending the recording.',
    valueOf: _longestRideHours,
    tiers: [
      BadgeTierSpec(
          id: 'saddle_1h',
          name: 'One hour',
          tier: BadgeTier.bronze,
          threshold: 1),
      BadgeTierSpec(
          id: 'saddle_2h',
          name: 'Two hours',
          tier: BadgeTier.silver,
          threshold: 2),
      BadgeTierSpec(
          id: 'saddle_4h',
          name: 'Four hours',
          tier: BadgeTier.gold,
          threshold: 4),
      BadgeTierSpec(
          id: 'saddle_8h',
          name: 'Eight hours',
          tier: BadgeTier.platinum,
          threshold: 8),
    ],
  ),
  BadgeFamily(
    id: 'speed',
    name: 'Top speed',
    icon: Icons.speed_outlined,
    unit: 'km/h',
    about: 'The highest speed recorded on any of your rides.',
    requirement: 'Record a top speed of {n} km/h.',
    valueOf: _topSpeedKmh,
    tiers: [
      BadgeTierSpec(
          id: 'ton_up', name: 'Ton-up', tier: BadgeTier.bronze, threshold: 100),
      BadgeTierSpec(
          id: 'speed_140',
          name: 'Quick',
          tier: BadgeTier.silver,
          threshold: 140),
      BadgeTierSpec(
          id: 'speed_demon',
          name: 'Speed demon',
          tier: BadgeTier.gold,
          threshold: 160),
    ],
  ),
  BadgeFamily(
    id: 'night',
    name: 'Night rider',
    icon: Icons.nightlight_outlined,
    unit: 'rides',
    about: 'Rides that set off after 9 pm or before 4 am.',
    requirement: 'Start {n} rides between 9 pm and 4 am.',
    valueOf: _nightRides,
    tiers: [
      BadgeTierSpec(
          id: 'night_1',
          name: 'After dark',
          tier: BadgeTier.bronze,
          threshold: 1),
      BadgeTierSpec(
          id: 'night_5',
          name: 'Night owl',
          tier: BadgeTier.silver,
          threshold: 5),
      BadgeTierSpec(
          id: 'night_25',
          name: 'Moonlighter',
          tier: BadgeTier.gold,
          threshold: 25),
      BadgeTierSpec(
          id: 'night_50',
          name: 'Nocturnal',
          tier: BadgeTier.platinum,
          threshold: 50),
    ],
  ),
  BadgeFamily(
    id: 'early',
    name: 'Early bird',
    icon: Icons.wb_twilight_outlined,
    unit: 'rides',
    about: 'Rides that set off between 4 am and 7 am.',
    requirement: 'Start {n} rides between 4 am and 7 am.',
    valueOf: _earlyRides,
    tiers: [
      BadgeTierSpec(
          id: 'early_1',
          name: 'Sunrise run',
          tier: BadgeTier.bronze,
          threshold: 1),
      BadgeTierSpec(
          id: 'early_5',
          name: 'Early bird',
          tier: BadgeTier.silver,
          threshold: 5),
      BadgeTierSpec(
          id: 'early_25',
          name: 'Dawn patrol',
          tier: BadgeTier.gold,
          threshold: 25),
    ],
  ),
  BadgeFamily(
    id: 'streak',
    name: 'Streak',
    icon: Icons.local_fire_department_outlined,
    unit: 'days',
    about: 'Your longest run of consecutive days with a recorded ride.',
    requirement: 'Ride on {n} days in a row.',
    valueOf: _longestDayStreak,
    tiers: [
      BadgeTierSpec(
          id: 'streak_3',
          name: '3-day streak',
          tier: BadgeTier.bronze,
          threshold: 3),
      BadgeTierSpec(
          id: 'streak_7',
          name: '7-day streak',
          tier: BadgeTier.silver,
          threshold: 7),
      BadgeTierSpec(
          id: 'streak_14',
          name: '14-day streak',
          tier: BadgeTier.gold,
          threshold: 14),
      BadgeTierSpec(
          id: 'streak_30',
          name: '30-day streak',
          tier: BadgeTier.platinum,
          threshold: 30),
    ],
  ),
  BadgeFamily(
    id: 'smooth',
    name: 'Smoothness',
    icon: Icons.auto_awesome_outlined,
    unit: 'pts',
    about: 'Your average riding score — fewer hard brakes, rapid '
        'accelerations and jerky inputs score higher.',
    requirement: 'Average {n} points across at least 5 rides.',
    valueOf: _smoothnessScore,
    tiers: [
      BadgeTierSpec(
          id: 'smooth_80',
          name: 'Steady hands',
          tier: BadgeTier.bronze,
          threshold: 80),
      BadgeTierSpec(
          id: 'smooth_operator',
          name: 'Smooth operator',
          tier: BadgeTier.silver,
          threshold: 90),
      BadgeTierSpec(
          id: 'smooth_95', name: 'Silk', tier: BadgeTier.gold, threshold: 95),
      BadgeTierSpec(
          id: 'smooth_98',
          name: 'Effortless',
          tier: BadgeTier.platinum,
          threshold: 98),
    ],
  ),
];

// Metric accessors. Top-level functions rather than closures, so the family
// table above can stay `const`.
num _totalRides(BadgeStats s) => s.totalRides;
num _totalDistanceKm(BadgeStats s) => s.totalDistanceKm;
num _topSpeedKmh(BadgeStats s) => s.topSpeedKmh;
num _longestRideKm(BadgeStats s) => s.longestRideKm;
num _longestRideHours(BadgeStats s) => s.longestRideHours;
num _nightRides(BadgeStats s) => s.nightRides;
num _earlyRides(BadgeStats s) => s.earlyRides;
num _longestDayStreak(BadgeStats s) => s.longestDayStreak;
num _smoothnessScore(BadgeStats s) => s.smoothnessScore;

/// Every badge in the app, flattened from [badgeFamilies] in ladder order.
final List<BadgeDef> badgeDefs = [
  for (final family in badgeFamilies)
    for (final spec in family.tiers) BadgeDef(family, spec),
];

/// Every badge with its earned state. Pure.
List<EarnedBadge> computeBadges(RiderStatsSummary stats) =>
    computeBadgesFrom(BadgeStats.from(stats));

/// [computeBadges] against already-derived stats — the form the unit tests
/// drive, and what the grouped view reuses.
List<EarnedBadge> computeBadgesFrom(BadgeStats stats) =>
    [for (final def in badgeDefs) EarnedBadge(def, def.isEarned(stats))];

/// Badges grouped into their ladders, with the rider's standing on each —
/// what the badge grid draws. Pure.
List<BadgeFamilyProgress> computeBadgeProgress(RiderStatsSummary stats) =>
    computeBadgeProgressFrom(BadgeStats.from(stats));

List<BadgeFamilyProgress> computeBadgeProgressFrom(BadgeStats stats) => [
      for (final family in badgeFamilies)
        BadgeFamilyProgress(
          family: family,
          value: family.valueOf(stats),
          badges: [
            for (final spec in family.tiers)
              EarnedBadge(BadgeDef(family, spec),
                  family.valueOf(stats) >= spec.threshold),
          ],
        ),
    ];

/// Trims the pointless `.0` off whole numbers so thresholds read as
/// "5,000 km" rather than "5000.0 km", while 2.5 h keeps its half.
///
/// A decimal only survives below 100: at 420.7 km the tenth is noise the
/// rider can't act on, but at 2.5 h it's half the badge.
String formatBadgeValue(num value) {
  if (value is int) return _grouped(value);
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05 || value.abs() >= 100) {
    return _grouped(rounded.toInt());
  }
  return value.toStringAsFixed(1);
}

String _grouped(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
