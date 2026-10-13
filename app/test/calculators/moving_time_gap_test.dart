import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/average_speed.dart';

/// §78.11: a GPS gap is credited as moving time by distance, not by the
/// speed of the fix that ends it.
void main() {
  test('50 s gap, 0 → 5 m/s over 10 m adds about 4 s, not 50 s', () {
    final ms = movingMsForGap(
      gapMs: 50000,
      prevSpeedMs: 0,
      speedMs: 5,
      distanceM: 10,
    );
    expect(ms, closeTo(4000, 1));
  });

  test('a long gap moving at both ends counts whole', () {
    expect(
      movingMsForGap(
          gapMs: 20000, prevSpeedMs: 12, speedMs: 11, distanceM: 230),
      20000,
    );
  });

  test('a normal fix interval follows the ending fix', () {
    expect(
        movingMsForGap(
            gapMs: 1000, prevSpeedMs: 0, speedMs: 3, distanceM: 1.5),
        1000);
    expect(
        movingMsForGap(
            gapMs: 1000, prevSpeedMs: 3, speedMs: 0.2, distanceM: 1.5),
        0);
  });

  test('distance-based credit never exceeds the gap', () {
    expect(
      movingMsForGap(
          gapMs: 10000, prevSpeedMs: 0, speedMs: 2, distanceM: 500),
      10000,
    );
  });

  test('beyond the max gap, only real travel is credited', () {
    expect(
      movingMsForGap(
          gapMs: 120000, prevSpeedMs: 10, speedMs: 10, distanceM: 20),
      0,
    );
    expect(
      movingMsForGap(
          gapMs: 120000, prevSpeedMs: 10, speedMs: 10, distanceM: 1200),
      120000,
    );
  });

  test('non-positive gaps add nothing', () {
    expect(
        movingMsForGap(gapMs: 0, prevSpeedMs: 5, speedMs: 5, distanceM: 5),
        0);
  });
}
