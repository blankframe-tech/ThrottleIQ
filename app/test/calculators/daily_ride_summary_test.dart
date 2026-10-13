import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/features/ride/domain/calculators/daily_ride_summary.dart';

void main() {
  final day = DateTime(2026, 10, 6);
  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  /// A detected fragment: [minutes] long, [km] covered, moving the whole
  /// time unless [movingMinutes] says otherwise.
  DaySegment detected(DateTime start, int minutes, double km,
          {int? movingMinutes, double maxSpeedMs = 10}) =>
      DaySegment(
        source: DaySegmentSource.detected,
        start: start,
        end: start.add(Duration(minutes: minutes)),
        distanceM: km * 1000,
        movingSeconds: (movingMinutes ?? minutes) * 60,
        durationSeconds: minutes * 60,
        maxSpeedMs: maxSpeedMs,
      );

  DaySegment recorded(DateTime start, int minutes, double km) => DaySegment(
        source: DaySegmentSource.recorded,
        start: start,
        end: start.add(Duration(minutes: minutes)),
        distanceM: km * 1000,
        movingSeconds: minutes * 60,
        durationSeconds: minutes * 60,
        maxSpeedMs: 12,
      );

  test('the merge gap is 20 minutes', () {
    expect(SensorConstants.autoRideMergeGap, const Duration(minutes: 20));
  });

  group('Dhaka jam merging', () {
    test('one commute split by four 10-minute jams is ONE ride', () {
      // 5 fragments, each 6 min / 1.5 km, separated by 10 min stationary.
      final segments = [
        for (var i = 0; i < 5; i++) detected(at(8, i * 16), 6, 1.5),
      ];
      final s = summarizeDay(day: day, segments: segments);
      expect(s.rideCount, 1);
      expect(s.detectedRideCount, 1);
      expect(s.recordedRideCount, 0);
      expect(s.detectedSegmentCount, 5);
      expect(s.distanceM, closeTo(7500, 1e-6));
      // 5 × 6 min riding + 4 × 10 min jam = 70 min of ride time.
      expect(s.rideSeconds, 70 * 60);
      expect(s.movingSeconds, 30 * 60);
      expect(s.jamSeconds, 40 * 60);
    });

    test('a gap exactly at the threshold still merges', () {
      final s = summarizeDay(day: day, segments: [
        detected(at(8, 0), 10, 3),
        detected(at(8, 30), 10, 3), // 20 min after the first ends
      ]);
      expect(s.rideCount, 1);
    });

    test('a gap longer than the threshold is two rides', () {
      final s = summarizeDay(day: day, segments: [
        detected(at(8, 0), 10, 3),
        detected(at(8, 31), 10, 3), // 21 min gap: a real stop
      ]);
      expect(s.rideCount, 2);
      expect(s.detectedRideCount, 2);
      expect(s.rideSeconds, 20 * 60);
    });

    test('morning and evening commutes stay separate', () {
      final s = summarizeDay(day: day, segments: [
        detected(at(8, 0), 30, 9),
        detected(at(8, 45), 15, 4), // jam-split tail of the morning ride
        detected(at(18, 0), 40, 9),
      ]);
      expect(s.rideCount, 2);
    });

    test('input order does not matter', () {
      final a = [
        detected(at(8, 0), 6, 1.5),
        detected(at(8, 16), 6, 1.5),
        detected(at(12, 0), 6, 1.5),
      ];
      final b = a.reversed.toList();
      expect(summarizeDay(day: day, segments: b).rideCount,
          summarizeDay(day: day, segments: a).rideCount);
    });

    test('straight-line crawl across a jam gap is credited', () {
      final first = DaySegment(
        source: DaySegmentSource.detected,
        start: at(8, 0),
        end: at(8, 10),
        distanceM: 2000,
        movingSeconds: 600,
        durationSeconds: 600,
        maxSpeedMs: 10,
        startPoint: (lat: 23.75, lng: 90.39),
        endPoint: (lat: 23.76, lng: 90.39),
      );
      final second = DaySegment(
        source: DaySegmentSource.detected,
        start: at(8, 22),
        end: at(8, 32),
        distanceM: 2000,
        movingSeconds: 600,
        durationSeconds: 600,
        maxSpeedMs: 10,
        // ~0.01° of latitude further north: ~1.1 km crawled in the jam.
        startPoint: (lat: 23.77, lng: 90.39),
        endPoint: (lat: 23.78, lng: 90.39),
      );
      final s = summarizeDay(day: day, segments: [first, second]);
      expect(s.rideCount, 1);
      expect(s.distanceM, closeTo(4000 + 1112, 10));
    });
  });

  group('manual rides', () {
    test('count alongside rides that were not recorded', () {
      final s = summarizeDay(day: day, segments: [
        recorded(at(8, 0), 40, 12),
        detected(at(13, 0), 15, 4),
        recorded(at(18, 0), 45, 12),
      ]);
      expect(s.rideCount, 3);
      expect(s.recordedRideCount, 2);
      expect(s.detectedRideCount, 1);
      expect(s.distanceM, closeTo(28000, 1e-6));
    });

    test('the minute before tapping Start is folded into the manual ride', () {
      // Auto noticed the bike moving at 8:00; the rider tapped Start at 8:03.
      final s = summarizeDay(day: day, segments: [
        detected(at(8, 0), 2, 0.4),
        recorded(at(8, 3), 40, 12),
      ]);
      expect(s.rideCount, 1);
      expect(s.recordedRideCount, 1);
      expect(s.detectedRideCount, 0);
      expect(s.distanceM, closeTo(12400, 1e-6));
    });

    test('a forgotten jam-split tail after Stop is folded in too', () {
      final s = summarizeDay(day: day, segments: [
        recorded(at(8, 0), 30, 9),
        detected(at(8, 40), 5, 1),
        detected(at(8, 55), 5, 1),
      ]);
      expect(s.rideCount, 1);
      expect(s.detectedSegmentCount, 2);
    });

    test('two recorded rides close together stay two rides', () {
      final s = summarizeDay(day: day, segments: [
        recorded(at(8, 0), 20, 6),
        recorded(at(8, 25), 20, 6),
      ]);
      expect(s.rideCount, 2);
    });

    test('a fragment between two recorded rides does not merge them', () {
      final s = summarizeDay(day: day, segments: [
        recorded(at(8, 0), 20, 6),
        detected(at(8, 25), 3, 0.5),
        recorded(at(8, 35), 20, 6),
      ]);
      expect(s.rideCount, 2);
      expect(s.detectedRideCount, 0);
    });
  });

  group('ride gate on detected-only rides', () {
    test('a lone tiny fragment (pushing the bike out) is not a ride', () {
      final s = summarizeDay(day: day, segments: [
        detected(at(8, 0), 1, 0.1),
      ]);
      expect(s.isEmpty, isTrue);
      expect(s.distanceM, 0);
    });

    test('tiny fragments that merge into a real journey do count', () {
      // Each 200 m crawl fails the gate alone; together they are 1 km.
      final s = summarizeDay(day: day, segments: [
        for (var i = 0; i < 5; i++) detected(at(8, i * 10), 2, 0.2),
      ]);
      expect(s.rideCount, 1);
    });

    test('walking pace is never a ride however far', () {
      final s = summarizeDay(day: day, segments: [
        detected(at(8, 0), 30, 2, maxSpeedMs: 1.5),
      ]);
      expect(s.isEmpty, isTrue);
    });
  });

  test('only segments starting on the day are counted', () {
    final s = summarizeDay(day: day, segments: [
      detected(at(8, 0), 10, 3),
      detected(at(8, 0).subtract(const Duration(days: 1)), 10, 3),
      detected(at(8, 0).add(const Duration(days: 1)), 10, 3),
    ]);
    expect(s.rideCount, 1);
    expect(s.day, DateTime(2026, 10, 6));
  });

  test('an empty day', () {
    final s = summarizeDay(day: day, segments: const []);
    expect(s.isEmpty, isTrue);
    expect(s.rideSeconds, 0);
    expect(s.jamSeconds, 0);
  });
}
