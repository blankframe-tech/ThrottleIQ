import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/speed_baseline.dart';

void main() {
  group('computeBaseline', () {
    test('an empty pool has no baseline', () {
      expect(computeBaseline(const []), isNull);
    });

    test('mean and stddev of a simple pool', () {
      final baseline = computeBaseline([30, 40, 50]);
      expect(baseline, isNotNull);
      expect(baseline!.sampleCount, 3);
      expect(baseline.meanKmh, closeTo(40, 0.01));
      expect(baseline.stddevKmh, closeTo(8.16, 0.01));
    });

    test('a single-sample pool has zero stddev, not a crash', () {
      final baseline = computeBaseline([42]);
      expect(baseline!.meanKmh, 42);
      expect(baseline.stddevKmh, 0);
    });

    test('an identical-value pool has zero stddev', () {
      final baseline = computeBaseline([35, 35, 35, 35]);
      expect(baseline!.stddevKmh, 0);
    });
  });

  group('isSpeedOutlier', () {
    test('never flags below the minimum sample count, no matter the speed', () {
      final baseline = (sampleCount: 4, meanKmh: 35.0, stddevKmh: 5.0);
      expect(isSpeedOutlier(120, baseline, minSamples: 5), isFalse);
    });

    test('the exact "everyone does 30-50, someone does 80" scenario is flagged', () {
      // Simulated pool centered around 35-45 km/h.
      final baseline = computeBaseline([32, 35, 38, 41, 44, 36, 39, 42])!;
      expect(isSpeedOutlier(80, baseline), isTrue);
    });

    test('a speed within the normal range is not flagged', () {
      final baseline = computeBaseline([32, 35, 38, 41, 44, 36, 39, 42])!;
      expect(isSpeedOutlier(40, baseline), isFalse);
    });

    test('a flat (zero-stddev) baseline still requires the absolute delta', () {
      final baseline = (sampleCount: 10, meanKmh: 0.0, stddevKmh: 0.0);
      expect(isSpeedOutlier(5, baseline), isFalse); // under minDeltaKmh
      expect(isSpeedOutlier(25, baseline), isTrue);
    });

    test('a small absolute gap is never flagged even with a huge z-score', () {
      // stddev is tiny, so a few km/h over produces a large z — but the
      // absolute-delta floor should still block it.
      final baseline = (sampleCount: 10, meanKmh: 30.0, stddevKmh: 0.5);
      expect(isSpeedOutlier(35, baseline), isFalse); // only +5, under minDeltaKmh
    });

    test('respects custom thresholds', () {
      final baseline = (sampleCount: 10, meanKmh: 30.0, stddevKmh: 5.0);
      expect(
        isSpeedOutlier(40, baseline, zThreshold: 1.5, minDeltaKmh: 5),
        isTrue,
      );
      expect(
        isSpeedOutlier(40, baseline, zThreshold: 5, minDeltaKmh: 5),
        isFalse,
      );
    });
  });
}
