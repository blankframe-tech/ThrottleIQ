import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/utils/riding_score.dart';

void main() {
  group('computeRidingScore', () {
    test('is 100 with no events', () {
      expect(
        computeRidingScore(hardBrakes: 0, rapidAccel: 0, highJerk: 0),
        100,
      );
    });

    test('deducts 5 per hard brake, 3 per rapid accel, 1 per high jerk', () {
      expect(
        computeRidingScore(hardBrakes: 2, rapidAccel: 1, highJerk: 3),
        100 - (2 * 5) - (1 * 3) - (3 * 1),
      );
    });

    test('clamps at 0, never goes negative', () {
      expect(
        computeRidingScore(hardBrakes: 50, rapidAccel: 0, highJerk: 0),
        0,
      );
    });
  });

  group('ridingScoreTier', () {
    test('80 and above is smooth', () {
      expect(ridingScoreTier(80), RidingScoreTier.smooth);
      expect(ridingScoreTier(100), RidingScoreTier.smooth);
    });

    test('60 to 79 is steady', () {
      expect(ridingScoreTier(60), RidingScoreTier.steady);
      expect(ridingScoreTier(79), RidingScoreTier.steady);
    });

    test('below 60 is aggressive', () {
      expect(ridingScoreTier(59), RidingScoreTier.aggressive);
      expect(ridingScoreTier(0), RidingScoreTier.aggressive);
    });
  });
}
