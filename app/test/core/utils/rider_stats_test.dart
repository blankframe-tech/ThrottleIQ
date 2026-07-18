import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/rider_stats.dart';
import 'package:throttleiq/features/garage/domain/entities/bike_entity.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';

BikeEntity _bike(String id, {int rideCount = 0}) => BikeEntity(
      id: id,
      userId: 'u1',
      brand: 'Yamaha',
      model: 'MT-15',
      rideCount: rideCount,
      createdAt: DateTime(2026, 1, 1),
    );

RideEntity _ride(
  String id, {
  required DateTime startTime,
  double avgSpeedMs = 10,
  double maxSpeedMs = 20,
  double distanceM = 1000,
  int hardBrakeCount = 0,
  int rapidAccelCount = 0,
  int highJerkCount = 0,
}) =>
    RideEntity(
      id: id,
      userId: 'u1',
      bikeId: 'b1',
      startTime: startTime,
      avgSpeedMs: avgSpeedMs,
      maxSpeedMs: maxSpeedMs,
      distanceM: distanceM,
      hardBrakeCount: hardBrakeCount,
      rapidAccelCount: rapidAccelCount,
      highJerkCount: highJerkCount,
    );

void main() {
  group('computeRiderStats', () {
    test('returns all zeros and no most-used bike when there are no rides', () {
      final stats = computeRiderStats(rides: [], bikes: [_bike('b1')]);
      expect(stats.totalRides, 0);
      expect(stats.totalDistanceKm, 0);
      expect(stats.allTimeAvgSpeedKmh, 0);
      expect(stats.allTimeTopSpeedKmh, 0);
      expect(stats.avgRidingScore, 0);
      expect(stats.mostUsedBike, isNull);
      expect(stats.recentRides, isEmpty);
    });

    test('most-used bike is null when no bike has any rides yet, even if bikes exist', () {
      final stats = computeRiderStats(
        rides: [_ride('r1', startTime: DateTime(2026, 1, 1))],
        bikes: [_bike('b1', rideCount: 0), _bike('b2', rideCount: 0)],
      );
      expect(stats.mostUsedBike, isNull);
    });

    test('picks the bike with the highest rideCount as most-used', () {
      final stats = computeRiderStats(
        rides: [_ride('r1', startTime: DateTime(2026, 1, 1))],
        bikes: [_bike('b1', rideCount: 3), _bike('b2', rideCount: 7)],
      );
      expect(stats.mostUsedBike!.id, 'b2');
    });

    test('averages speed/score across rides and takes the max top speed', () {
      final stats = computeRiderStats(
        bikes: const [],
        rides: [
          _ride('r1',
              startTime: DateTime(2026, 1, 1),
              avgSpeedMs: 10, // 36 km/h
              maxSpeedMs: 20, // 72 km/h
              distanceM: 1000,
              hardBrakeCount: 0),
          _ride('r2',
              startTime: DateTime(2026, 1, 2),
              avgSpeedMs: 20, // 72 km/h
              maxSpeedMs: 30, // 108 km/h
              distanceM: 2000,
              hardBrakeCount: 4), // score = 100 - 20 = 80
        ],
      );
      expect(stats.totalRides, 2);
      expect(stats.totalDistanceKm, 3); // 1000m + 2000m
      expect(stats.allTimeAvgSpeedKmh, (36 + 72) / 2);
      expect(stats.allTimeTopSpeedKmh, 108);
      expect(stats.avgRidingScore, (100 + 80) / 2);
    });

    test('recentRides is sorted most-recent-first regardless of input order, capped to the limit', () {
      final stats = computeRiderStats(
        bikes: const [],
        recentLimit: 2,
        rides: [
          _ride('oldest', startTime: DateTime(2026, 1, 1)),
          _ride('newest', startTime: DateTime(2026, 1, 3)),
          _ride('middle', startTime: DateTime(2026, 1, 2)),
        ],
      );
      expect(stats.recentRides.map((r) => r.id).toList(), ['newest', 'middle']);
    });
  });
}
