import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badges.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';

RiderStatsSummary _stats({
  int totalRides = 0,
  double totalDistanceKm = 0,
  double topSpeedKmh = 0,
  double avgRidingScore = 0,
}) =>
    RiderStatsSummary(
      allTimeAvgSpeedKmh: 0,
      allTimeTopSpeedKmh: topSpeedKmh,
      avgRidingScore: avgRidingScore,
      mostUsedBike: null,
      totalRides: totalRides,
      totalDistanceKm: totalDistanceKm,
      recentRides: const [],
    );

void main() {
  group('computeBadges', () {
    test('nothing earned with zero rides', () {
      final badges = computeBadges(_stats());
      expect(badges.every((b) => !b.earned), isTrue);
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
      expect(earned('speed_demon'), isFalse);
    });

    test('smooth operator needs both a ride-count floor and a high average score', () {
      bool earned(RiderStatsSummary s) =>
          computeBadges(s).firstWhere((b) => b.def.id == 'smooth_operator').earned;

      expect(earned(_stats(totalRides: 1, avgRidingScore: 95)), isFalse);
      expect(earned(_stats(totalRides: 5, avgRidingScore: 80)), isFalse);
      expect(earned(_stats(totalRides: 5, avgRidingScore: 95)), isTrue);
    });

    test('every badge id is unique', () {
      final ids = badgeDefs.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
