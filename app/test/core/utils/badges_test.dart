import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badges.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

RiderStatsSummary _stats({
  int totalRides = 0,
  double totalDistanceKm = 0,
  double topSpeedKmh = 0,
  double avgRidingScore = 0,
  List<RideEntity> rides = const [],
}) =>
    RiderStatsSummary(
      allTimeAvgSpeedKmh: 0,
      allTimeTopSpeedKmh: topSpeedKmh,
      avgRidingScore: avgRidingScore,
      mostUsedBike: null,
      totalRides: totalRides,
      totalDistanceKm: totalDistanceKm,
      recentRides: rides,
      allRides: rides,
    );

RideEntity _ride({
  String id = 'r1',
  required DateTime startTime,
  double distanceM = 1000,
  int? durationSeconds = 600,
}) =>
    RideEntity(
      id: id,
      userId: 'u1',
      bikeId: 'b1',
      startTime: startTime,
      distanceM: distanceM,
      durationSeconds: durationSeconds,
    );

/// Family ids whose metric is a whole number, so "just under" is one less
/// rather than a fraction less.
const _integerMetrics = {'first', 'rides', 'night', 'early', 'streak'};

/// Builds a [BadgeStats] whose *only* non-zero figure is the one [familyId]
/// measures, set to [value].
///
/// Deliberately exhaustive with a failing default: adding a badge family
/// without teaching this helper how to drive it fails the boundary sweep
/// below rather than silently skipping the new ladder.
BadgeStats _statsWith(String familyId, num value) {
  switch (familyId) {
    case 'first':
    case 'rides':
      return BadgeStats(totalRides: value.round());
    case 'distance':
      return BadgeStats(totalDistanceKm: value.toDouble());
    case 'long_ride':
      return BadgeStats(longestRideKm: value.toDouble());
    case 'saddle_time':
      return BadgeStats(longestRideHours: value.toDouble());
    case 'speed':
      return BadgeStats(topSpeedKmh: value.toDouble());
    case 'night':
      return BadgeStats(nightRides: value.round());
    case 'early':
      return BadgeStats(earlyRides: value.round());
    case 'streak':
      return BadgeStats(longestDayStreak: value.round());
    case 'smooth':
      return BadgeStats(smoothnessScore: value.toDouble());
  }
  fail('No metric setter for badge family "$familyId" — '
      'add one when adding a family.');
}

void main() {
  group('badge ladder shape', () {
    test('every badge id is unique', () {
      final ids = badgeDefs.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ids that have already been written to Firestore still exist', () {
      // earnedBadges docs are keyed by these; renaming one orphans a rider's
      // record and re-awards the badge.
      const persisted = [
        'first_ride',
        'km_100', 'km_500', 'km_1000', 'km_2500', 'km_5000',
        'rides_10', 'rides_25', 'rides_50', 'rides_100',
        'ton_up', 'speed_demon', 'smooth_operator',
      ];
      final ids = badgeDefs.map((b) => b.id).toSet();
      for (final id in persisted) {
        expect(ids, contains(id), reason: '$id is a persisted badge id');
      }
    });

    test('thresholds and tiers both ascend within every family', () {
      for (final family in badgeFamilies) {
        for (var i = 1; i < family.tiers.length; i++) {
          expect(family.tiers[i].threshold,
              greaterThan(family.tiers[i - 1].threshold),
              reason: '${family.id} thresholds must ascend');
          expect(family.tiers[i].tier.index,
              greaterThan(family.tiers[i - 1].tier.index),
              reason: '${family.id} tiers must ascend');
        }
      }
    });

    test('every family has at least one tier and non-empty copy', () {
      for (final family in badgeFamilies) {
        expect(family.tiers, isNotEmpty);
        expect(family.about, isNotEmpty);
        expect(family.requirement, isNotEmpty);
        for (final spec in family.tiers) {
          expect(spec.name, isNotEmpty);
          expect(spec.id, isNotEmpty);
        }
      }
    });

    test('requirement copy substitutes the threshold', () {
      final distance = badgeFamilies.firstWhere((f) => f.id == 'distance');
      expect(distance.requirementFor(5000), contains('5,000'));
      expect(distance.requirementFor(5000), isNot(contains('{n}')));
    });
  });

  group('computeBadges boundaries', () {
    test('nothing is earned with zero rides', () {
      final badges = computeBadges(_stats());
      expect(badges.every((b) => !b.earned), isTrue);
      expect(badges, hasLength(badgeDefs.length));
    });

    test('nothing is earned from an empty ride list', () {
      final badges = computeBadgesFrom(BadgeStats.from(_stats(rides: const [])));
      expect(badges.every((b) => !b.earned), isTrue);
    });

    test('every badge is earned at exactly its threshold, and not below', () {
      for (final def in badgeDefs) {
        final delta = _integerMetrics.contains(def.family.id) ? 1 : 0.01;

        expect(def.isEarned(_statsWith(def.family.id, def.threshold)), isTrue,
            reason: '${def.id} must be earned at exactly ${def.threshold}');
        expect(
            def.isEarned(_statsWith(def.family.id, def.threshold - delta)),
            isFalse,
            reason: '${def.id} must NOT be earned just under its threshold');
        expect(
            def.isEarned(_statsWith(def.family.id, def.threshold + delta)),
            isTrue,
            reason: '${def.id} must stay earned just over its threshold');
      }
    });

    test('earning a rung implies every lower rung on the same ladder', () {
      for (final family in badgeFamilies) {
        for (final spec in family.tiers) {
          final progress = computeBadgeProgressFrom(
                  _statsWith(family.id, spec.threshold))
              .firstWhere((p) => p.family.id == family.id);

          var seenUnearned = false;
          for (final badge in progress.badges) {
            if (!badge.earned) seenUnearned = true;
            // Once a rung is unearned no higher rung may be earned.
            if (badge.earned) {
              expect(seenUnearned, isFalse,
                  reason: '${family.id} ladder has a gap at ${badge.def.id}');
            }
          }
        }
      }
    });

    test('distance milestones earn independently at their thresholds', () {
      final badges = computeBadges(_stats(totalRides: 1, totalDistanceKm: 600));
      bool earned(String id) => badges.firstWhere((b) => b.def.id == id).earned;

      expect(earned('first_ride'), isTrue);
      expect(earned('km_100'), isTrue);
      expect(earned('km_500'), isTrue);
      expect(earned('km_1000'), isFalse);
    });

    test('ton-up needs 100 km/h top speed, speed demon needs 160', () {
      final badges = computeBadges(_stats(topSpeedKmh: 120));
      bool earned(String id) => badges.firstWhere((b) => b.def.id == id).earned;

      expect(earned('ton_up'), isTrue);
      expect(earned('speed_140'), isFalse);
      expect(earned('speed_demon'), isFalse);
    });

    test('smooth operator needs both a ride-count floor and a high average',
        () {
      bool earned(RiderStatsSummary s) => computeBadges(s)
          .firstWhere((b) => b.def.id == 'smooth_operator')
          .earned;

      expect(earned(_stats(totalRides: 1, avgRidingScore: 95)), isFalse);
      expect(earned(_stats(totalRides: 5, avgRidingScore: 80)), isFalse);
      expect(earned(_stats(totalRides: 5, avgRidingScore: 95)), isTrue);
      // Exactly on the floor, exactly on the threshold.
      expect(earned(_stats(totalRides: 5, avgRidingScore: 90)), isTrue);
      expect(earned(_stats(totalRides: 4, avgRidingScore: 100)), isFalse);
    });
  });

  group('BadgeStats.from', () {
    test('reads per-ride metrics off the full history', () {
      final stats = BadgeStats.from(_stats(
        totalRides: 3,
        rides: [
          _ride(id: 'a', startTime: DateTime(2026, 6, 1, 22), distanceM: 120000),
          _ride(
              id: 'b',
              startTime: DateTime(2026, 6, 2, 5),
              distanceM: 30000,
              durationSeconds: 9000),
          _ride(id: 'c', startTime: DateTime(2026, 6, 10, 13)),
        ],
      ));

      expect(stats.longestRideKm, 120);
      expect(stats.longestRideHours, 2.5);
      expect(stats.nightRides, 1);
      expect(stats.earlyRides, 1);
      expect(stats.longestDayStreak, 2);
    });

    test('an empty history derives zeros, not nulls or crashes', () {
      final stats = BadgeStats.from(RiderStatsSummary.empty);
      expect(stats.longestRideKm, 0);
      expect(stats.longestRideHours, 0);
      expect(stats.nightRides, 0);
      expect(stats.earlyRides, 0);
      expect(stats.longestDayStreak, 0);
      expect(stats.smoothnessScore, 0);
    });

    test('night and early windows are disjoint at their shared boundary', () {
      expect(BadgeStats.isNightRide(DateTime(2026, 6, 1, 3, 59)), isTrue);
      expect(BadgeStats.isNightRide(DateTime(2026, 6, 1, 4)), isFalse);
      expect(BadgeStats.isEarlyRide(DateTime(2026, 6, 1, 4)), isTrue);
      expect(BadgeStats.isEarlyRide(DateTime(2026, 6, 1, 6, 59)), isTrue);
      expect(BadgeStats.isEarlyRide(DateTime(2026, 6, 1, 7)), isFalse);
      expect(BadgeStats.isNightRide(DateTime(2026, 6, 1, 20, 59)), isFalse);
      expect(BadgeStats.isNightRide(DateTime(2026, 6, 1, 21)), isTrue);
    });

    test('falls back to recentRides when allRides is absent', () {
      // An older cached summary has no allRides; per-ride badges should read
      // what is there rather than reporting a rider with no history at all.
      final summary = RiderStatsSummary(
        allTimeAvgSpeedKmh: 0,
        allTimeTopSpeedKmh: 0,
        avgRidingScore: 0,
        mostUsedBike: null,
        totalRides: 1,
        totalDistanceKm: 60,
        recentRides: [
          _ride(startTime: DateTime(2026, 6, 1, 23), distanceM: 60000),
        ],
      );
      final stats = BadgeStats.from(summary);
      expect(stats.longestRideKm, 60);
      expect(stats.nightRides, 1);
    });
  });

  group('computeLongestDayStreak', () {
    test('empty history has no streak', () {
      expect(computeLongestDayStreak(const []), 0);
    });

    test('a single ride is a one-day streak', () {
      expect(
          computeLongestDayStreak([_ride(startTime: DateTime(2026, 6, 1))]), 1);
    });

    test('several rides on one day are still one day', () {
      expect(
        computeLongestDayStreak([
          _ride(id: 'a', startTime: DateTime(2026, 6, 1, 8)),
          _ride(id: 'b', startTime: DateTime(2026, 6, 1, 18)),
        ]),
        1,
      );
    });

    test('counts consecutive days regardless of input order', () {
      expect(
        computeLongestDayStreak([
          _ride(id: 'c', startTime: DateTime(2026, 6, 3)),
          _ride(id: 'a', startTime: DateTime(2026, 6, 1)),
          _ride(id: 'b', startTime: DateTime(2026, 6, 2)),
        ]),
        3,
      );
    });

    test('a gap breaks the streak and the longest run wins', () {
      expect(
        computeLongestDayStreak([
          _ride(id: 'a', startTime: DateTime(2026, 6, 1)),
          _ride(id: 'b', startTime: DateTime(2026, 6, 2)),
          // gap
          _ride(id: 'c', startTime: DateTime(2026, 6, 10)),
          _ride(id: 'd', startTime: DateTime(2026, 6, 11)),
          _ride(id: 'e', startTime: DateTime(2026, 6, 12)),
        ]),
        3,
      );
    });

    test('spans month and year boundaries', () {
      expect(
        computeLongestDayStreak([
          _ride(id: 'a', startTime: DateTime(2025, 12, 31, 22)),
          _ride(id: 'b', startTime: DateTime(2026, 1, 1, 9)),
          _ride(id: 'c', startTime: DateTime(2026, 1, 2, 7)),
        ]),
        3,
      );
    });
  });

  /// The live streak shown on the Record screen, as distinct from the
  /// personal best above it. `now` is injected throughout so these don't
  /// depend on the day the suite runs.
  group('computeCurrentDayStreak', () {
    final today = DateTime(2026, 6, 10);

    test('empty history has no streak', () {
      expect(computeCurrentDayStreak(const [], now: today), 0);
    });

    test('counts back from a ride today', () {
      expect(
        computeCurrentDayStreak([
          _ride(id: 'a', startTime: DateTime(2026, 6, 8, 7)),
          _ride(id: 'b', startTime: DateTime(2026, 6, 9, 18)),
          _ride(id: 'c', startTime: DateTime(2026, 6, 10, 9)),
        ], now: today),
        3,
      );
    });

    test('a ride yesterday keeps the streak alive', () {
      // Otherwise the number a rider sees collapses to zero every morning
      // until they've been out again.
      expect(
        computeCurrentDayStreak([
          _ride(id: 'a', startTime: DateTime(2026, 6, 8)),
          _ride(id: 'b', startTime: DateTime(2026, 6, 9)),
        ], now: today),
        2,
      );
    });

    test('two days off ends it, however long the run was', () {
      expect(
        computeCurrentDayStreak([
          for (var d = 1; d <= 7; d++)
            _ride(id: 'r$d', startTime: DateTime(2026, 6, d)),
        ], now: today),
        0,
      );
    });

    test('ignores an older, longer run behind a gap', () {
      // The personal best here is 4; what the rider is *on* is 2.
      expect(
        computeCurrentDayStreak([
          for (var d = 1; d <= 4; d++)
            _ride(id: 'old$d', startTime: DateTime(2026, 6, d)),
          _ride(id: 'new1', startTime: DateTime(2026, 6, 9)),
          _ride(id: 'new2', startTime: DateTime(2026, 6, 10)),
        ], now: today),
        2,
      );
    });

    test('several rides in one day count once', () {
      expect(
        computeCurrentDayStreak([
          _ride(id: 'a', startTime: DateTime(2026, 6, 10, 7)),
          _ride(id: 'b', startTime: DateTime(2026, 6, 10, 19)),
        ], now: today),
        1,
      );
    });

    test('spans a month boundary', () {
      expect(
        computeCurrentDayStreak([
          _ride(id: 'a', startTime: DateTime(2026, 5, 31, 20)),
          _ride(id: 'b', startTime: DateTime(2026, 6, 1, 8)),
        ], now: DateTime(2026, 6, 1)),
        2,
      );
    });
  });

  group('computeBadgeProgress', () {
    test('groups every badge into exactly one family', () {
      final progress = computeBadgeProgress(_stats());
      final grouped =
          progress.fold<int>(0, (sum, p) => sum + p.badges.length);
      expect(grouped, badgeDefs.length);
      expect(progress, hasLength(badgeFamilies.length));
    });

    test('reports the highest earned tier and the next rung to chase', () {
      final distance = computeBadgeProgress(_stats(totalDistanceKm: 1200))
          .firstWhere((p) => p.family.id == 'distance');

      expect(distance.value, 1200);
      expect(distance.earnedCount, 3);
      expect(distance.highestTier, BadgeTier.gold);
      expect(distance.nextUp?.def.id, 'km_2500');
    });

    test('a topped-out ladder has no next rung', () {
      final speed = computeBadgeProgress(_stats(topSpeedKmh: 200))
          .firstWhere((p) => p.family.id == 'speed');
      expect(speed.nextUp, isNull);
      expect(speed.highestTier, BadgeTier.gold);
    });

    test('an untouched ladder has no tier and points at its first rung', () {
      final streak = computeBadgeProgress(_stats())
          .firstWhere((p) => p.family.id == 'streak');
      expect(streak.highestTier, isNull);
      expect(streak.earnedCount, 0);
      expect(streak.nextUp?.def.tier, BadgeTier.bronze);
    });
  });

  group('formatBadgeValue', () {
    test('groups thousands and drops meaningless decimals', () {
      expect(formatBadgeValue(5000), '5,000');
      expect(formatBadgeValue(1000.0), '1,000');
      expect(formatBadgeValue(420.7), '421');
      expect(formatBadgeValue(100), '100');
      expect(formatBadgeValue(0), '0');
    });

    test('keeps a decimal where it carries meaning', () {
      expect(formatBadgeValue(2.5), '2.5');
      expect(formatBadgeValue(1.4), '1.4');
    });
  });
}
