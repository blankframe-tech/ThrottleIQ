import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/ride_resume.dart';

/// §90.C6: rebuilding a killed ride must respect pause gaps and the live
/// path's below-threshold zeroing, or a restore reintroduces distance the
/// live recorder had refused.
void main() {
  final t0 = DateTime.utc(2026, 10, 6, 9);

  /// ~111.19 m per 0.001° of latitude.
  StoredFix fix(int secondsIn, double latOffset, double speedMs) => (
        time: t0.add(Duration(seconds: secondsIn)),
        lat: 23.8103 + latOffset,
        lng: 90.4125,
        speedMs: speedMs,
      );

  test('the gap into a segment start (a resume) adds no distance', () {
    final fixes = [
      fix(0, 0, 10),
      fix(10, 0.001, 10), // paused here
      fix(1810, 0.2, 12), // resumed 22 km away, after a van ride
      fix(1820, 0.201, 12),
    ];

    final withoutMarker = rebuildRideAggregates(fixes);
    final withMarker =
        rebuildRideAggregates(fixes, segmentStartIndices: {2});

    expect(withMarker.distanceM, closeTo(2 * 111.2, 1));
    // Even unmarked, the Doppler cap bounds the gap (12 m/s · 1800 s · 1.5
    // is still huge, so the marker is what actually fixes it).
    expect(withoutMarker.distanceM, greaterThan(20000));
  });

  test('the pause gap is not credited as moving time', () {
    final fixes = [
      fix(0, 0, 10),
      fix(10, 0.001, 10),
      fix(40, 0.0015, 10), // 30 s pause, both ends "moving"
      fix(50, 0.0025, 10),
    ];
    final marked = rebuildRideAggregates(fixes, segmentStartIndices: {2});
    final unmarked = rebuildRideAggregates(fixes);
    expect(marked.movingSeconds, 20);
    expect(unmarked.movingSeconds, 50);
  });

  test('stationary jitter between two idle fixes adds nothing', () {
    final aggregates = rebuildRideAggregates([
      fix(0, 0, 10),
      fix(10, 0.001, 10),
      fix(20, 0.00104, 0), // stopped at a light, drifting
      fix(30, 0.00098, 0),
      fix(40, 0.00106, 0),
    ]);
    // 0→1 is a real leg; 1→2 ends a ride-to-stop (counted); the two idle
    // legs after it are jitter.
    const firstTwoLegs = 111.2 + 0.04 * 111.2;
    expect(aggregates.distanceM, closeTo(firstTwoLegs, 1));
  });

  test('a multipath jump between moving fixes is capped', () {
    final aggregates = rebuildRideAggregates([
      fix(0, 0, 10),
      fix(1, 0.002, 10), // 222 m in 1 s at 10 m/s
      fix(2, 0.0021, 10),
    ]);
    // Cap per leg: 10 · 1 · 1.5 + 25 = 40 m.
    expect(aggregates.distanceM, lessThanOrEqualTo(80));
  });
}
