import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/badge_earned_dates.dart';
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
