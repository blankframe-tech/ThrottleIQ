import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/core/utils/geo_math.dart';
import 'package:throttleiq/features/ride/domain/calculators/fix_kinematics.dart';

import '../features/routes/gpx_replay.dart';

/// §90.C12: the per-fix speed/distance rules shared by the live recorder and
/// the auto-detection replay — in particular the Doppler distance cap.
void main() {
  group('dopplerDistanceCapM', () {
    test('is max(v, vPrev) * dt * 1.5 + accuracy', () {
      expect(
        dopplerDistanceCapM(
            rawSpeedMs: 10, prevSpeedMs: 12, deltaTSeconds: 2, accuracyM: 8),
        12 * 2 * 1.5 + 8,
      );
    });

    test('a negative dt or bad accuracy never produces a negative cap', () {
      expect(
        dopplerDistanceCapM(
            rawSpeedMs: 10,
            prevSpeedMs: 0,
            deltaTSeconds: -1,
            accuracyM: double.nan),
        0,
      );
    });
  });

  group('evaluateFix', () {
    test('a multipath jump with a plausible Doppler speed is capped', () {
      // 10 m/s for 1 s, but the position jumped 24 m (inside the 25 m
      // accuracy gate). Before §90.C12 all 24 m were credited.
      final k = evaluateFix(
        rawSpeedMs: 10,
        prev: (speedMs: 10),
        rawDistanceM: 24 + 15.0,
        deltaTSeconds: 1,
        accuracyM: 5,
      );
      expect(k.speedMs, 10);
      expect(k.distanceDeltaM, 10 * 1 * 1.5 + 5);
    });

    test('honest movement is never clipped', () {
      final k = evaluateFix(
        rawSpeedMs: 10,
        prev: (speedMs: 9),
        rawDistanceM: 9.6,
        deltaTSeconds: 1,
        accuracyM: 4,
      );
      expect(k.distanceDeltaM, 9.6);
    });

    test('the first fix of a segment adds speed but no distance', () {
      final k = evaluateFix(
        rawSpeedMs: 12,
        prev: null,
        rawDistanceM: 20000, // the van journey across a pause
        deltaTSeconds: 1800,
        accuracyM: 5,
      );
      expect(k.speedMs, 12);
      expect(k.distanceDeltaM, 0);
    });

    test('a rejected fix contributes nothing', () {
      final k = evaluateFix(
        rawSpeedMs: 0,
        prev: (speedMs: 0),
        rawDistanceM: 3,
        deltaTSeconds: 2,
        accuracyM: 10,
        acceleration: 1,
        jerk: 1,
      );
      expect(k.speedMs, 0);
      expect(k.distanceDeltaM, 0);
      expect(k.acceleration, 0);
      expect(k.jerk, 0);
    });

    test('the derived-speed fallback is not capped by the Doppler rule', () {
      // No Doppler speed; 50 m in 5 s → 10 m/s derived.
      final k = evaluateFix(
        rawSpeedMs: 0,
        prev: (speedMs: 9),
        rawDistanceM: 50,
        deltaTSeconds: 5,
        accuracyM: 5,
      );
      expect(k.speedMs, closeTo(10, 1e-9));
      expect(k.distanceDeltaM, 50);
    });

    test('GPX replay: an injected multipath jump costs at most the cap', () {
      // The fixture is 1 Hz at 8.3 m/s; dt is therefore 1 s per leg.
      final fixes = readGpx('test/features/routes/fixtures/dhaka_zigzag.gpx');
      double replay(List<LatLng> track) {
        var total = 0.0;
        for (var i = 1; i < track.length; i++) {
          total += evaluateFix(
            rawSpeedMs: fixes[i].speedMs,
            prev: (speedMs: fixes[i - 1].speedMs),
            rawDistanceM: haversineMeters(track[i - 1].latitude,
                track[i - 1].longitude, track[i].latitude, track[i].longitude),
            deltaTSeconds: 1,
            accuracyM: 5,
          ).distanceDeltaM;
        }
        return total;
      }

      final clean = [for (final f in fixes) f.position];
      final mid = clean.length ~/ 2;
      final jumped = [...clean]..[mid] = offsetMetres(clean[mid], 90, 24);

      final cleanTotal = replay(clean);
      final jumpedTotal = replay(jumped);
      // A 24 m sideways jump (inside the 25 m accuracy gate) and back: each
      // leg is ~25.4 m against a true ~8.3 m, so uncapped it adds ~34 m.
      // Capped at 8.3·1.5 + 5 ≈ 17.5 m per leg, it adds ~18 m.
      final added = jumpedTotal - cleanTotal;
      expect(added, lessThan(20));
      expect(added, greaterThan(0));
      // The clean track is untouched by the cap.
      final raw = [
        for (var i = 1; i < clean.length; i++)
          haversineMeters(clean[i - 1].latitude, clean[i - 1].longitude,
              clean[i].latitude, clean[i].longitude),
      ].fold<double>(0, (a, b) => a + b);
      expect(cleanTotal, closeTo(raw, 0.01));
    });
  });
}
