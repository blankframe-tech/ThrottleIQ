import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/domain/year_in_review.dart';

RideEntity _ride(String id, DateTime start, double km, {String bike = 'b1'}) =>
    RideEntity(
      id: id,
      userId: 'u1',
      bikeId: bike,
      startTime: start,
      distanceM: km * 1000,
    );

void main() {
  final rides = [
    _ride('a', DateTime(2025, 12, 31, 23), 50),
    _ride('b', DateTime(2026, 1, 1), 10),
    _ride('c', DateTime(2026, 6, 1), 30, bike: 'b2'),
    _ride('d', DateTime(2026, 7, 1), 5),
  ];

  test('rideYears lists each year once, newest first', () {
    expect(rideYears(rides), [2026, 2025]);
    expect(rideYears(const []), isEmpty);
  });

  test('sums only the chosen year', () {
    final r = computeYearInReview(rides, 2026);
    expect(r.year, 2026);
    expect(r.rideCount, 3);
    expect(r.distanceKm, closeTo(45, 1e-9));
    expect(r.longestRideKm, closeTo(30, 1e-9));
    // b1 has two rides to b2's one, even though b2 rode further.
    expect(r.favouriteBikeId, 'b1');
  });

  test('a ride-count tie goes to the bike with more distance', () {
    final r = computeYearInReview([
      _ride('x', DateTime(2026, 1, 1), 5),
      _ride('y', DateTime(2026, 1, 2), 8, bike: 'b2'),
    ], 2026);
    expect(r.favouriteBikeId, 'b2');
  });

  test('a year without rides is all zero', () {
    final r = computeYearInReview(rides, 2024);
    expect(r.rideCount, 0);
    expect(r.distanceKm, 0);
    expect(r.longestRideKm, 0);
    expect(r.favouriteBikeId, isNull);
  });
}
