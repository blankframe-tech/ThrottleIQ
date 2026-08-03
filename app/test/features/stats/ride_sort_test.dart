import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/stats/domain/ride_sort.dart';

RideEntity _ride({
  required String id,
  required int day,
  double distanceM = 1000,
  double? maxSpeedMs,
  int? durationSeconds = 600,
  int hardBrakes = 0,
  int rapidAccel = 0,
  int highJerk = 0,
}) {
  return RideEntity(
    id: id,
    userId: 'u1',
    bikeId: 'b1',
    startTime: DateTime(2026, 8, day),
    distanceM: distanceM,
    maxSpeedMs: maxSpeedMs,
    durationSeconds: durationSeconds,
    hardBrakeCount: hardBrakes,
    rapidAccelCount: rapidAccel,
    highJerkCount: highJerk,
    status: RideStatus.completed,
  );
}

List<String> _ids(List<RideEntity> rides) => rides.map((r) => r.id).toList();

void main() {
  group('sortRides', () {
    test('recent orders newest first', () {
      final rides = [
        _ride(id: 'old', day: 1),
        _ride(id: 'new', day: 10),
        _ride(id: 'mid', day: 5),
      ];
      expect(_ids(sortRides(rides, RideSort.recent)), ['new', 'mid', 'old']);
    });

    test('top speed orders fastest first', () {
      final rides = [
        _ride(id: 'slow', day: 1, maxSpeedMs: 10),
        _ride(id: 'fast', day: 2, maxSpeedMs: 40),
        _ride(id: 'mid', day: 3, maxSpeedMs: 25),
      ];
      expect(_ids(sortRides(rides, RideSort.topSpeed)), ['fast', 'mid', 'slow']);
    });

    test('distance orders longest first', () {
      final rides = [
        _ride(id: 'short', day: 1, distanceM: 500),
        _ride(id: 'long', day: 2, distanceM: 90000),
        _ride(id: 'mid', day: 3, distanceM: 12000),
      ];
      expect(_ids(sortRides(rides, RideSort.longestDistance)),
          ['long', 'mid', 'short']);
    });

    test('duration orders longest first', () {
      final rides = [
        _ride(id: 'quick', day: 1, durationSeconds: 300),
        _ride(id: 'epic', day: 2, durationSeconds: 14400),
        _ride(id: 'mid', day: 3, durationSeconds: 3600),
      ];
      expect(_ids(sortRides(rides, RideSort.longestDuration)),
          ['epic', 'mid', 'quick']);
    });

    test('best score orders smoothest first', () {
      final rides = [
        _ride(id: 'rough', day: 1, hardBrakes: 20, rapidAccel: 20, highJerk: 20),
        _ride(id: 'smooth', day: 2),
        _ride(id: 'okay', day: 3, hardBrakes: 3),
      ];
      final sorted = _ids(sortRides(rides, RideSort.bestScore));
      expect(sorted.first, 'smooth');
      expect(sorted.last, 'rough');
    });

    // Ties are common — a repeated commute, or several 0.0 km test rides. If
    // ties fell through to database order the list would reshuffle between
    // rebuilds for no visible reason.
    test('ties break by recency, newest first', () {
      final rides = [
        _ride(id: 'a', day: 1, distanceM: 5000),
        _ride(id: 'c', day: 9, distanceM: 5000),
        _ride(id: 'b', day: 5, distanceM: 5000),
      ];
      expect(_ids(sortRides(rides, RideSort.longestDistance)), ['c', 'b', 'a']);
    });

    test('tie-breaking is stable across repeated sorts', () {
      final rides = [
        _ride(id: 'a', day: 1, maxSpeedMs: 20),
        _ride(id: 'b', day: 2, maxSpeedMs: 20),
        _ride(id: 'c', day: 3, maxSpeedMs: 20),
      ];
      final first = _ids(sortRides(rides, RideSort.topSpeed));
      final second = _ids(sortRides(sortRides(rides, RideSort.topSpeed), RideSort.topSpeed));
      expect(second, first);
    });

    // A ride with no recorded top speed or duration is a data gap. Surfacing
    // it at the top of "fastest" or "longest" would be actively wrong.
    test('missing values sort last, not first', () {
      final rides = [
        _ride(id: 'unknown', day: 9, maxSpeedMs: null),
        _ride(id: 'known', day: 1, maxSpeedMs: 15),
      ];
      expect(_ids(sortRides(rides, RideSort.topSpeed)), ['known', 'unknown']);

      final byDuration = [
        _ride(id: 'nodur', day: 9, durationSeconds: null),
        _ride(id: 'hasdur', day: 1, durationSeconds: 100),
      ];
      expect(_ids(sortRides(byDuration, RideSort.longestDuration)),
          ['hasdur', 'nodur']);
    });

    test('never mutates the input list', () {
      final rides = [
        _ride(id: 'a', day: 1, distanceM: 100),
        _ride(id: 'b', day: 2, distanceM: 900),
      ];
      final before = _ids(rides);
      sortRides(rides, RideSort.longestDistance);
      expect(_ids(rides), before);
    });

    test('handles empty and single-element lists', () {
      for (final sort in RideSort.values) {
        expect(sortRides(const [], sort), isEmpty);
        final one = [_ride(id: 'only', day: 1)];
        expect(_ids(sortRides(one, sort)), ['only']);
      }
    });

    test('every sort returns the same rides, just reordered', () {
      final rides = [
        _ride(id: 'a', day: 1, distanceM: 100, maxSpeedMs: 5),
        _ride(id: 'b', day: 2, distanceM: 900, maxSpeedMs: 30),
        _ride(id: 'c', day: 3, distanceM: 400, maxSpeedMs: 12),
      ];
      for (final sort in RideSort.values) {
        expect(_ids(sortRides(rides, sort))..sort(), ['a', 'b', 'c']);
      }
    });
  });

  group('RideSortLabel', () {
    test('every sort has a non-empty label', () {
      for (final sort in RideSort.values) {
        expect(sort.label, isNotEmpty);
      }
    });

    test('recent shows no trailing value; the date is its sort key', () {
      expect(RideSort.recent.trailingValue(_ride(id: 'a', day: 1)), isNull);
    });

    test('other sorts render the figure they rank by', () {
      final r = _ride(
        id: 'a',
        day: 1,
        distanceM: 12300,
        maxSpeedMs: 25,
        durationSeconds: 3900,
      );
      expect(RideSort.topSpeed.trailingValue(r), '90 km/h');
      expect(RideSort.longestDistance.trailingValue(r), '12.3 km');
      expect(RideSort.longestDuration.trailingValue(r), '1h 5m');
      expect(RideSort.bestScore.trailingValue(r), isNotNull);
    });

    test('duration label handles seconds, minutes and hours', () {
      String? d(int? s) => RideSort.longestDuration
          .trailingValue(_ride(id: 'x', day: 1, durationSeconds: s));
      expect(d(45), '45s');
      expect(d(600), '10m');
      expect(d(7260), '2h 1m');
      expect(d(null), '0s');
    });
  });
}
