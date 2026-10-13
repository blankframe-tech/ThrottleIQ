import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/elevation_profile.dart';

void main() {
  group('elevationGainLoss', () {
    test('returns null for an empty series', () {
      expect(elevationGainLoss([]), isNull);
    });

    test('returns null when altitude is mostly missing', () {
      final altitudes = <double?>[
        for (var i = 0; i < 30; i++) i % 3 == 0 ? 100.0 + i : null,
      ];
      expect(elevationGainLoss(altitudes), isNull);
    });

    test('returns null when there are too few samples for the smoothing window', () {
      expect(elevationGainLoss([100.0, 101.0, 102.0]), isNull);
    });

    test('returns null for a flat trace within the noise floor', () {
      final altitudes = List<double?>.generate(
        30,
        (i) => 100.0 + (i.isEven ? 0.4 : -0.4),
      );
      expect(elevationGainLoss(altitudes), isNull);
    });

    test('reports gain and loss for a clean up-then-down profile', () {
      final altitudes = <double?>[
        for (var i = 0; i < 20; i++) 100.0 + i * 2.0, // climbs 38m
        for (var i = 0; i < 20; i++) 138.0 - i * 2.0, // descends 38m
      ];
      final result = elevationGainLoss(altitudes, smoothingWindow: 3);
      expect(result, isNotNull);
      expect(result!.gainM, closeTo(38, 4));
      expect(result.lossM, closeTo(38, 4));
    });

    test('smoothing keeps a noisy climb close to its real trend', () {
      // A steady 40m climb over 40 samples with +/-1m jitter superimposed.
      // Summing raw deltas would inflate gain well past 40m by also counting
      // every jitter step upward; smoothing should keep it close to 40.
      final altitudes = <double?>[
        for (var i = 0; i < 40; i++) 100.0 + i + (i.isEven ? 1.0 : -1.0),
      ];
      final result = elevationGainLoss(altitudes);
      expect(result, isNotNull);
      expect(result!.gainM, lessThan(60));
      expect(result.gainM, greaterThan(30));
    });
  });
}
