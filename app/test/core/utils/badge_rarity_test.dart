import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badge_rarity.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

RideEntity _ride(
  String id,
  DateTime start, {
  double km = 1,
  int seconds = 600,
}) =>
    RideEntity(
      id: id,
      userId: 'u1',
      bikeId: 'b1',
      startTime: start,
      endTime: start.add(Duration(seconds: seconds)),
      distanceM: km * 1000,
      durationSeconds: seconds,
    );

void main() {
  group('rarityForPercent', () {
    test('maps each band to its tier', () {
      expect(rarityForPercent(0), BadgeRarity.legendary);
      expect(rarityForPercent(0.5), BadgeRarity.legendary);
      expect(rarityForPercent(3), BadgeRarity.epic);
      expect(rarityForPercent(10), BadgeRarity.rare);
      expect(rarityForPercent(25), BadgeRarity.uncommon);
      expect(rarityForPercent(60), BadgeRarity.common);
      expect(rarityForPercent(100), BadgeRarity.common);
    });

    test('boundaries belong to the more common tier', () {
      expect(rarityForPercent(legendaryBelow), BadgeRarity.epic);
      expect(rarityForPercent(epicBelow), BadgeRarity.rare);
      expect(rarityForPercent(rareBelow), BadgeRarity.uncommon);
      expect(rarityForPercent(uncommonBelow), BadgeRarity.common);
      expect(rarityForPercent(legendaryBelow - 0.001), BadgeRarity.legendary);
      expect(rarityForPercent(uncommonBelow - 0.001), BadgeRarity.uncommon);
    });

    test('rarer share never maps to a more common tier', () {
      var last = BadgeRarity.legendary;
      for (var pct = 0.0; pct <= 100; pct += 0.25) {
        final r = rarityForPercent(pct);
        expect(r.index, lessThanOrEqualTo(last.index), reason: '$pct');
        last = r;
      }
    });
  });

  group('ownershipPercent', () {
    test('is owners over riders, in percent', () {
      expect(ownershipPercent(owners: 25, totalRiders: 200), 12.5);
      expect(ownershipPercent(owners: 0, totalRiders: 50), 0);
      expect(ownershipPercent(owners: 50, totalRiders: 50), 100);
    });

    test('is unknown, not zero, without a usable total or count', () {
      expect(ownershipPercent(owners: 3, totalRiders: null), isNull);
      expect(ownershipPercent(owners: 3, totalRiders: 0), isNull);
      expect(ownershipPercent(owners: 3, totalRiders: -4), isNull);
      expect(ownershipPercent(owners: null, totalRiders: 10), isNull);
    });

    test('clamps drifted counts into 0..100%', () {
      expect(ownershipPercent(owners: 12, totalRiders: 10), 100);
      expect(ownershipPercent(owners: -2, totalRiders: 10), 0);
    });

    test('withholds a zero count from a rider who owns the badge', () {
      expect(ownershipPercent(owners: 0, totalRiders: 10, ownedByViewer: true),
          isNull);
      expect(ownershipPercent(owners: 1, totalRiders: 10, ownedByViewer: true),
          10);
    });
  });

  group('formatOwnershipPercent', () {
    test('rounds the middle and keeps the ends truthful', () {
      expect(formatOwnershipPercent(0), '0%');
      expect(formatOwnershipPercent(0.2), '<1%');
      expect(formatOwnershipPercent(1), '1%');
      expect(formatOwnershipPercent(12.5), '13%');
      expect(formatOwnershipPercent(99.4), '>99%');
      expect(formatOwnershipPercent(100), '100%');
    });
  });

  group('BadgeOwnershipStats.fromMap', () {
    test('parses the stats/badges doc', () {
      final s = BadgeOwnershipStats.fromMap({
        'totalRiders': 400,
        'recomputedAt': DateTime(2026),
        'owners': {'first_ride': 300, 'km_5000': 2, 'bad': 'x'},
      })!;
      expect(s.totalRiders, 400);
      expect(s.percentFor('first_ride'), 75);
      expect(rarityForPercent(s.percentFor('first_ride')!), BadgeRarity.common);
      expect(s.percentFor('km_5000'), 0.5);
      expect(rarityForPercent(s.percentFor('km_5000')!), BadgeRarity.legendary);
      expect(s.owners.containsKey('bad'), isFalse);
    });

    test('a badge missing from owners is unknown, not 0%', () {
      final s = BadgeOwnershipStats.fromMap(
          {'totalRiders': 10, 'owners': {}, 'recomputedAt': DateTime(2026)})!;
      expect(s.percentFor('rides_250'), isNull);
    });

    test('missing or malformed doc yields null', () {
      expect(BadgeOwnershipStats.fromMap(null), isNull);
      expect(BadgeOwnershipStats.fromMap({}), isNull);
      expect(BadgeOwnershipStats.fromMap({'totalRiders': 0}), isNull);
      expect(BadgeOwnershipStats.fromMap({'totalRiders': '12'}), isNull);
    });

    test('ignored until the first full recount has run', () {
      expect(
          BadgeOwnershipStats.fromMap({
            'totalRiders': 3,
            'owners': {'first_ride': 40},
          }),
          isNull);
    });
  });

  group('computeBadgeEarnedDates', () {
    test('dates each badge by the ride that crossed its threshold', () {
      final d1 = DateTime(2026, 3, 1, 10);
      final d2 = DateTime(2026, 3, 2, 10);
      final d3 = DateTime(2026, 3, 3, 22); // night ride
      final rides = [
        // Deliberately out of order.
        _ride('c', d3, km: 60),
        _ride('a', d1, km: 30),
        _ride('b', d2, km: 20),
      ];
      final dates = computeBadgeEarnedDates(rides);
      DateTime end(DateTime d) => d.add(const Duration(seconds: 600));
      expect(dates['first_ride'], end(d1));
      expect(dates['km_100'], end(d3)); // 30 + 20 + 60 crosses on ride c
      expect(dates['long_ride_50'], end(d3));
      expect(dates['night_1'], end(d3));
      expect(dates['streak_3'], end(d3));
      expect(dates.containsKey('km_500'), isFalse);
    });

    test('no rides, no dates', () {
      expect(computeBadgeEarnedDates(const []), isEmpty);
    });
  });
}
