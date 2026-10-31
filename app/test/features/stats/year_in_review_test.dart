import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/domain/year_in_review.dart';

RideEntity _ride(String id, DateTime start, double km,
        {String bike = 'b1', int? seconds}) =>
    RideEntity(
      id: id,
      userId: 'u1',
      bikeId: bike,
      startTime: start,
      distanceM: km * 1000,
      durationSeconds: seconds,
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

  test('ride time, month totals and the busiest month', () {
    final r = computeYearInReview([
      _ride('a', DateTime(2026, 3, 2), 10, seconds: 600),
      _ride('b', DateTime(2026, 3, 9), 15, seconds: 900),
      _ride('c', DateTime(2026, 8, 1), 20), // no duration: counts as zero
    ], 2026, now: DateTime(2027));
    expect(r.rideSeconds, 1500);
    expect(r.monthKm, hasLength(12));
    expect(r.monthKm[2], closeTo(25, 1e-9));
    expect(r.monthKm[7], closeTo(20, 1e-9));
    expect(r.busiestMonth, 3);
  });

  test('a past year compares against the whole year before', () {
    final r = computeYearInReview(rides, 2026, now: DateTime(2027, 2));
    expect(r.previousKm, closeTo(50, 1e-9));
    expect(r.changeVsPrevious, closeTo(-0.1, 1e-9)); // 45 vs 50
  });

  test('a year in progress compares against the same date a year earlier', () {
    final r = computeYearInReview([
      _ride('old-in', DateTime(2025, 3, 1), 20),
      _ride('old-out', DateTime(2025, 11, 1), 500),
      _ride('now', DateTime(2026, 2, 1), 30),
    ], 2026, now: DateTime(2026, 10, 31));
    expect(r.previousKm, closeTo(20, 1e-9));
    expect(r.changeVsPrevious, closeTo(0.5, 1e-9));
  });

  test('no rides the year before means nothing to compare', () {
    final r = computeYearInReview(rides, 2025, now: DateTime(2027));
    expect(r.previousKm, isNull);
    expect(r.changeVsPrevious, isNull);
    expect(computeYearInReview(rides, 2024).busiestMonth, isNull);
  });

  test('the review banner season is December and January', () {
    expect(reviewSeasonYear(DateTime(2026, 12, 1)), 2026);
    expect(reviewSeasonYear(DateTime(2027, 1, 31)), 2026);
    expect(reviewSeasonYear(DateTime(2026, 11, 30)), isNull);
    expect(reviewSeasonYear(DateTime(2027, 2, 1)), isNull);
  });
}
