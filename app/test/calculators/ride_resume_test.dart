import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/ride_resume.dart';

/// Rebuilding a killed ride's running totals from the fixes that reached
/// disk. This is what makes "quit the app mid-ride" resumable rather than
/// merely salvageable — get it wrong and a resumed ride silently restarts its
/// distance, top speed and average from zero.
void main() {
  final t0 = DateTime.utc(2026, 5, 1, 9);

  /// ~111.19m apart per 0.001° of latitude at the equator.
  StoredFix fix(int secondsIn, double latOffset, double speedMs) => (
        time: t0.add(Duration(seconds: secondsIn)),
        lat: 23.8103 + latOffset,
        lng: 90.4125,
        speedMs: speedMs,
      );

  group('rebuildRideAggregates', () {
    test('an empty fix list yields the empty aggregates', () {
      expect(rebuildRideAggregates([]), same(RideResumeAggregates.empty));
    });

    test('sums distance along the track, not start-to-end', () {
      // A there-and-back: the endpoints coincide, so a naive
      // first-to-last measurement would report ~0.
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 10),
        fix(10, 0.001, 10),
        fix(20, 0, 10),
      ]);

      expect(aggregates.distanceM, closeTo(222.4, 1));
    });

    test('keeps the highest speed seen, not the last', () {
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 5),
        fix(10, 0.001, 27.5),
        fix(20, 0.002, 8),
      ]);

      expect(aggregates.maxSpeedMs, 27.5);
      expect(aggregates.speedCount, 3);
      expect(aggregates.speedSum, closeTo(40.5, 0.001));
    });

    test('excludes stopped time from moving seconds', () {
      // Ten seconds rolling, then ten sitting at a light. Only the first gap
      // is riding time.
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 10),
        fix(10, 0.001, 10),
        fix(20, 0.001, 0),
      ]);

      expect(aggregates.movingSeconds, 10);
    });

    test('reports the span the stored fixes cover', () {
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 10),
        fix(600, 0.001, 10),
      ]);

      expect(aggregates.firstFixTime, t0);
      expect(aggregates.span, const Duration(minutes: 10));
    });

    test('a suspended-app gap is not counted as riding', () {
      // The app was killed for an hour between two fixes. Counting that gap
      // would both inflate moving time and crush the average speed.
      final aggregates = rebuildRideAggregates([
        fix(0, 0, 10),
        fix(3600, 0.001, 10),
      ]);

      expect(aggregates.movingSeconds, 0);
      expect(aggregates.span, const Duration(hours: 1));
    });
  });

  group('haversineMeters', () {
    test('is zero for a point against itself', () {
      expect(
        haversineMeters(lat1: 23.81, lng1: 90.41, lat2: 23.81, lng2: 90.41),
        0,
      );
    });

    test('measures a known short hop', () {
      // 0.001° of latitude is ~111.2m anywhere on the globe.
      expect(
        haversineMeters(lat1: 23.810, lng1: 90.41, lat2: 23.811, lng2: 90.41),
        closeTo(111.2, 0.5),
      );
    });

    test('is symmetric', () {
      final there =
          haversineMeters(lat1: 23.81, lng1: 90.41, lat2: 23.92, lng2: 90.52);
      final back =
          haversineMeters(lat1: 23.92, lng1: 90.52, lat2: 23.81, lng2: 90.41);
      expect(there, closeTo(back, 0.0001));
    });
  });
}
