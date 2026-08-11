import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/accel_axis_calibrator.dart';

double _dot(List<double> a, List<double> b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

double _norm(List<double> v) => sqrt(_dot(v, v));

List<double> _unit(List<double> v) {
  final n = _norm(v);
  return [v[0] / n, v[1] / n, v[2] / n];
}

void main() {
  group('dominantAxisSignedMagnitude', () {
    test('picks the largest-magnitude axis and signs by its own sign', () {
      expect(dominantAxisSignedMagnitude(5, 1, 1), closeTo(sqrt(27), 1e-9));
      expect(dominantAxisSignedMagnitude(-5, 1, 1), closeTo(-sqrt(27), 1e-9));
      expect(dominantAxisSignedMagnitude(1, -5, 1), closeTo(-sqrt(27), 1e-9));
      expect(dominantAxisSignedMagnitude(1, 1, 5), closeTo(sqrt(27), 1e-9));
    });

    test('a stationary phone (all-zero sample) reports zero', () {
      expect(dominantAxisSignedMagnitude(0, 0, 0), 0);
    });
  });

  group('AccelAxisCalibrator', () {
    test('falls back to the dominant-axis heuristic before enough samples', () {
      final calibrator = AccelAxisCalibrator();
      expect(calibrator.isCalibrated, isFalse);
      expect(calibrator.signedLongitudinalAccelMs2(3, 0.5, 0.2),
          dominantAxisSignedMagnitude(3, 0.5, 0.2));

      // A handful of samples isn't "enough" even if they'd invert cleanly —
      // see _minSamples' doc comment.
      for (var i = 0; i < 5; i++) {
        calibrator.addSample(ax: 1, ay: 2, az: 3, gpsAccelMs2: i.toDouble());
      }
      expect(calibrator.isCalibrated, isFalse);
    });

    test('stays on the fallback when the seen directions are co-linear', () {
      // Every sample points the same way in device space (only its
      // magnitude, along one fixed direction, tracks gpsAccel) — that
      // under-determines a unique 3D axis no matter how many samples
      // arrive, so the fit must keep declining rather than solve a
      // near-singular system.
      final calibrator = AccelAxisCalibrator();
      final rnd = Random(1);
      for (var i = 0; i < 200; i++) {
        final g = rnd.nextDouble() * 10 - 5;
        calibrator.addSample(ax: g * 0.8, ay: g * 0.6, az: 0, gpsAccelMs2: g);
      }
      expect(calibrator.isCalibrated, isFalse);
    });

    test('recovers a tilted mounting axis from GPS-paired samples', () {
      // A phone mounted at some arbitrary angle — not flush with any single
      // device axis, which is exactly the case dominantAxisSignedMagnitude
      // gets wrong.
      final trueAxis = _unit([0.6, -0.3, 0.74]);
      final calibrator = AccelAxisCalibrator();
      final rnd = Random(42);

      for (var i = 0; i < 400; i++) {
        final gpsAccel = rnd.nextDouble() * 12 - 6; // -6..6 m/s²
        // Independent per-sample noise in all 3 dimensions — cornering and
        // road bumps, uncorrelated with the longitudinal signal — which is
        // what gives the fit a genuinely 3D spread of directions to solve.
        final noise = [
          (rnd.nextDouble() - 0.5) * 2,
          (rnd.nextDouble() - 0.5) * 2,
          (rnd.nextDouble() - 0.5) * 2,
        ];
        calibrator.addSample(
          ax: trueAxis[0] * gpsAccel + noise[0],
          ay: trueAxis[1] * gpsAccel + noise[1],
          az: trueAxis[2] * gpsAccel + noise[2],
          gpsAccelMs2: gpsAccel,
        );
      }

      expect(calibrator.isCalibrated, isTrue);

      // A clean reading along the true axis should project back to
      // approximately its own known acceleration...
      const knownAccel = 5.0;
      final cleanSample = [
        trueAxis[0] * knownAccel,
        trueAxis[1] * knownAccel,
        trueAxis[2] * knownAccel,
      ];
      final projected = calibrator.signedLongitudinalAccelMs2(
          cleanSample[0], cleanSample[1], cleanSample[2]);
      expect(projected, closeTo(knownAccel, 0.5));

      // ...and braking should still read negative, accelerating positive —
      // the sign the whole hard-brake/rapid-accel threshold check depends
      // on (see SensorConstants).
      final brakingSample = trueAxis.map((c) => c * -4.0).toList();
      expect(
          calibrator.signedLongitudinalAccelMs2(
              brakingSample[0], brakingSample[1], brakingSample[2]),
          lessThan(0));
    });

    test('reset forgets the fit and falls back to the heuristic again', () {
      final calibrator = AccelAxisCalibrator();
      final trueAxis = _unit([1, 0.2, 0.1]);
      final rnd = Random(3);
      for (var i = 0; i < 200; i++) {
        final g = rnd.nextDouble() * 10 - 5;
        calibrator.addSample(
          ax: trueAxis[0] * g + (rnd.nextDouble() - 0.5),
          ay: trueAxis[1] * g + (rnd.nextDouble() - 0.5),
          az: trueAxis[2] * g + (rnd.nextDouble() - 0.5),
          gpsAccelMs2: g,
        );
      }
      expect(calibrator.isCalibrated, isTrue);

      calibrator.reset();

      expect(calibrator.isCalibrated, isFalse);
      expect(calibrator.sampleCount, 0);
      expect(calibrator.signedLongitudinalAccelMs2(2, 0, 0),
          dominantAxisSignedMagnitude(2, 0, 0));
    });
  });
}
