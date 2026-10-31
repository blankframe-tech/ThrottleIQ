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
      _ride('old-in', DateTime(2025, 3, 1), 200),
      _ride('old-out', DateTime(2025, 11, 1), 500),
      _ride('now', DateTime(2026, 2, 1), 300),
    ], 2026, now: DateTime(2026, 10, 31));
    expect(r.previousKm, closeTo(200, 1e-9));
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

  test('inProgress follows the now given to the calculation', () {
    expect(
        computeYearInReview(rides, 2026, now: DateTime(2026, 10, 31))
            .inProgress,
        isTrue);
    expect(
        computeYearInReview(rides, 2026, now: DateTime(2027, 1, 1)).inProgress,
        isFalse);
  });

  test('no percentage against a previous span under 50 km', () {
    final tiny = computeYearInReview([
      _ride('a', DateTime(2025, 5, 1), 5),
      _ride('b', DateTime(2026, 5, 1), 220),
    ], 2026, now: DateTime(2027));
    expect(tiny.previousKm, closeTo(5, 1e-9));
    expect(tiny.changeVsPrevious, isNull);
  });

  group('story facts', () {
    RideEntity rich(String id, DateTime start, double km,
            {double? maxMs, double? climb, double? lean, String? route}) =>
        RideEntity(
          id: id,
          userId: 'u1',
          bikeId: 'b1',
          startTime: start,
          distanceM: km * 1000,
          avgSpeedMs: 8,
          maxSpeedMs: maxMs,
          elevationGainM: climb,
          maxLeanDeg: lean,
          routeName: route,
        );

    test('days, streak, weekdays and hours', () {
      final r = computeYearInReview([
        rich('a', DateTime(2024, 3, 4, 21), 10), // Monday night
        rich('b', DateTime(2024, 3, 5, 22), 10), // Tuesday
        rich('c', DateTime(2024, 3, 5, 7), 10), // same day again
        rich('d', DateTime(2024, 3, 6, 23), 10), // Wednesday
        rich('e', DateTime(2024, 3, 9, 12), 10), // Saturday, after a gap
        rich('f', DateTime(2024, 12, 31, 12), 10), // a leap year's last day
      ], 2024, now: DateTime(2025));
      expect(r.dayKm.length, 366);
      expect(r.dayKm[365], 10);
      expect(r.activeDays, 5);
      expect(r.longestStreakDays, 3);
      expect(r.weekdayRides, [1, 3, 1, 0, 0, 1, 0]); // 31 Dec 2024 is a Tuesday
      expect(r.favouriteWeekday, DateTime.tuesday);
      expect(r.peakHour, 12);
      // 3 of 6 rides start after 20:00.
      expect(r.riderClock, (RiderClock.nightOwl, 0.5));
    });

    test('rider clock picks early, sunset, then daylight', () {
      RiderClock clockFor(List<int> hours) => computeYearInReview([
            for (final (i, h) in hours.indexed)
              rich('$i', DateTime(2026, 1, i + 1, h), 5)
          ], 2026, now: DateTime(2027))
              .riderClock!
              .$1;
      expect(clockFor([5, 12, 12, 12, 12]), RiderClock.earlyBird); // 20%
      expect(clockFor([17, 18, 12, 12, 12]), RiderClock.sunsetChaser); // 40%
      expect(clockFor([10, 12, 14, 17, 12]), RiderClock.daylight);
      expect(computeYearInReview(const [], 2026).riderClock, isNull);
    });

    test('top speed, climb, lean and the longest ride', () {
      final r = computeYearInReview([
        rich('a', DateTime(2026, 2, 1), 40, maxMs: 25, climb: 300, lean: 22),
        rich('b', DateTime(2026, 4, 9), 120,
            maxMs: 20, climb: 500, route: 'Hill run'),
        rich('c', DateTime(2026, 5, 1), 10),
      ], 2026, now: DateTime(2027));
      expect(r.topSpeedKmh, closeTo(90, 1e-9));
      expect(r.topSpeedDate, DateTime(2026, 2, 1));
      expect(r.climbM, 800);
      expect(r.maxLeanDeg, 22);
      expect(r.longestRideDate, DateTime(2026, 4, 9));
      expect(r.longestRideRoute, 'Hill run');
      expect(r.favouriteBikeRides, 3);
    });

    test('a single short ride gets only the pages it can fill', () {
      final r = computeYearInReview([_ride('a', DateTime(2026, 1, 1), 5)], 2026,
          now: DateTime(2027));
      expect(storySlides(r, hasBikeName: true), [
        StorySlide.cover,
        StorySlide.distance,
        StorySlide.days,
        StorySlide.bike,
        StorySlide.summary,
      ]);
    });

    test('a full year gets every page; a drop on last year gets no growth', () {
      final year = [
        for (var i = 0; i < 10; i++)
          rich('$i', DateTime(2026, 1 + i, 3, 8 + i), 30.0 + i,
                  maxMs: 20, climb: 40, lean: 30)
              .copyWith(durationSeconds: 3600),
      ];
      final up = computeYearInReview(
          [...year, _ride('p', DateTime(2025, 6, 1), 100)], 2026,
          now: DateTime(2027));
      expect(storySlides(up, hasBikeName: true), StorySlide.values);
      expect(storySlides(up, hasBikeName: false),
          isNot(contains(StorySlide.bike)));
      final down = computeYearInReview(
          [...year, _ride('p', DateTime(2025, 6, 1), 1000)], 2026,
          now: DateTime(2027));
      expect(storySlides(down, hasBikeName: true),
          isNot(contains(StorySlide.growth)));
    });
  });
}
