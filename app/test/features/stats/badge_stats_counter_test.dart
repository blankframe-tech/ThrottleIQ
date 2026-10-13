import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/stats/data/badge_stats_counter.dart';

/// The batch shapes firestore.rules accepts for stats/badges. The rules side
/// of each shape is covered by scripts/test/rules/badge_stats_rules.test.js.
void main() {
  const uid = 'rider-1';

  group('BadgeStatsBatches.badgeCount', () {
    test('new badge: create the doc with countedAt, owners.<id> +1', () {
      final writes = BadgeStatsBatches.badgeCount(uid, 'km_100', isNew: true);
      expect(writes, hasLength(2));

      final badge = writes[0];
      expect(badge.path, 'users/rider-1/earnedBadges/km_100');
      expect(badge.merge, isTrue);
      expect(badge.data, {
        'badgeId': 'km_100',
        'earnedAt': FieldValue.serverTimestamp(),
        'countedAt': FieldValue.serverTimestamp(),
      });

      final stats = writes[1];
      expect(stats.path, 'stats/badges');
      expect(stats.merge, isTrue, reason: 'only owners.km_100 may move');
      expect(stats.data, {
        'owners': {'km_100': FieldValue.increment(1)},
        'lastCountedBadge': 'km_100',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    test('backfill keeps the original earnedAt', () {
      final writes = BadgeStatsBatches.badgeCount(uid, 'night_1', isNew: false);
      expect(writes[0].data.containsKey('earnedAt'), isFalse);
      expect(writes[0].data['countedAt'], FieldValue.serverTimestamp());
      expect(writes[1].data['owners'], {'night_1': FieldValue.increment(1)});
    });

    test('the stats write never touches totalRiders', () {
      final writes = BadgeStatsBatches.badgeCount(uid, 'km_100', isNew: true);
      expect(writes[1].data.containsKey('totalRiders'), isFalse);
    });

    test('only catalog ids can be counted', () {
      expect(
        () => BadgeStatsBatches.badgeCount(uid, 'monthly_500km', isNew: true),
        throwsArgumentError,
      );
      expect(isCountedBadgeId('smooth_operator'), isTrue);
      expect(isCountedBadgeId('monthly_500km'), isFalse);
      expect(isCountedBadgeId(''), isFalse);
    });
  });

  group('BadgeStatsBatches.riderRegistration', () {
    test('flag the profile, totalRiders +1', () {
      final writes = BadgeStatsBatches.riderRegistration(uid);
      expect(writes, hasLength(2));
      expect(writes[0].path, 'users/rider-1');
      expect(writes[0].merge, isTrue);
      expect(writes[0].data, {
        'badgeStatsCountedAt': FieldValue.serverTimestamp(),
      });
      expect(writes[1].path, 'stats/badges');
      expect(writes[1].merge, isTrue);
      expect(writes[1].data, {
        'totalRiders': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    test('sign-up merges the profile fields into the same write', () {
      final writes = BadgeStatsBatches.riderRegistration(
        uid,
        profileFields: {'displayName': 'Asha', 'visibility': 'public'},
      );
      expect(writes[0].data, {
        'displayName': 'Asha',
        'visibility': 'public',
        'badgeStatsCountedAt': FieldValue.serverTimestamp(),
      });
      expect(writes[1].data.containsKey('owners'), isFalse);
    });
  });

  group('what still needs counting', () {
    test('riderNeedsCounting: an existing, unflagged profile only', () {
      expect(
        riderNeedsCounting(null),
        isFalse,
        reason: 'ensureProfile creates and counts a missing profile',
      );
      expect(riderNeedsCounting({'displayName': 'A'}), isTrue);
      expect(
        riderNeedsCounting({
          'displayName': 'A',
          'badgeStatsCountedAt': DateTime(2026),
        }),
        isFalse,
      );
    });

    test('badgesNeedingCount: held catalog badges without countedAt', () {
      final held = <String, Map<String, dynamic>>{
        'km_100': {'badgeId': 'km_100', 'countedAt': DateTime(2026)},
        'first_ride': {'badgeId': 'first_ride'},
        'night_1': {'badgeId': 'night_1', 'earnedAt': DateTime(2025)},
        'monthly_500km': {'badgeId': 'monthly_500km'},
      };
      // Catalog order; counted and non-catalog docs skipped.
      expect(badgesNeedingCount(held), ['first_ride', 'night_1']);
      expect(badgesNeedingCount(const {}), isEmpty);
    });
  });
}
