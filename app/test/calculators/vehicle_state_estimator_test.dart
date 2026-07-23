import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/vehicle_state_estimator.dart';

void main() {
  group('VehicleStateEstimator', () {
    late VehicleStateEstimator estimator;
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    setUp(() {
      estimator = VehicleStateEstimator();
    });

    test('currentState is null before any GPS fix', () {
      expect(estimator.currentState, isNull);
    });

    test('ignores a GPS fix with accuracy past the reject threshold', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 25.01,
        headingDeg: 90,
      );
      expect(estimator.currentState, isNull);
    });

    test('first GPS fix seeds heading directly from the reported course', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 90.0,
      );
      expect(estimator.currentState!.headingDeg, 90.0);
    });

    test('heading blends toward a new GPS course, weighted by accuracy', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0, // good accuracy -> gpsWeight 0.7
        headingDeg: 90.0,
      );
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(seconds: 1)),
        lat: 1.0001,
        lng: 1.0001,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 100.0,
      );
      // 90 + 0.7 * (100 - 90) = 97.0
      expect(estimator.currentState!.headingDeg, closeTo(97.0, 0.01));
    });

    test('poor GPS accuracy leans the heading blend away from the new course', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 90.0,
      );
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(seconds: 1)),
        lat: 1.0001,
        lng: 1.0001,
        speedMs: 10,
        accuracyM: 20.0, // poor accuracy -> gpsWeight 0.3
        headingDeg: 190.0,
      );
      // 90 + 0.3 * (190 - 90) = 120.0
      expect(estimator.currentState!.headingDeg, closeTo(120.0, 0.01));
    });

    test('heading blend wraps around the 0/360 boundary via the shortest path', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 350.0,
      );
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(seconds: 1)),
        lat: 1.0001,
        lng: 1.0001,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 10.0,
      );
      // shortest path from 350 to 10 is +20 (through 0), not -340:
      // 350 + 0.7 * 20 = 364 -> normalized to 4.0
      expect(estimator.currentState!.headingDeg, closeTo(4.0, 0.01));
    });

    test('gyro dead-reckons heading forward between GPS fixes', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 90.0,
      );

      // First gyro sample only seeds the integration clock; no delta yet.
      estimator.addGyroSample(
        timestamp: t0.add(const Duration(milliseconds: 500)),
        gx: 0,
        gy: 0,
        gz: 0.2,
      );
      // Second sample integrates over the 0.5s gap.
      estimator.addGyroSample(
        timestamp: t0.add(const Duration(milliseconds: 1000)),
        gx: 0,
        gy: 0,
        gz: 0.2,
      );

      // A GPS fix with no heading doesn't touch the blend, just re-emits
      // state carrying the dead-reckoned heading forward.
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(milliseconds: 1500)),
        lat: 1.0002,
        lng: 1.0002,
        speedMs: 10,
        accuracyM: 3.0,
      );

      // 90 + (0.2 rad/s * 0.5s * 180/pi) = 90 + 5.729... = 95.729...
      expect(estimator.currentState!.headingDeg, closeTo(95.73, 0.01));
      expect(estimator.currentState!.angularVelocityRadS, 0.2);
    });

    test('isCornering is true only while moving with sustained high yaw rate', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10, // moving
        accuracyM: 3.0,
        headingDeg: 90.0,
      );
      estimator.addGyroSample(timestamp: t0.add(const Duration(milliseconds: 100)), gx: 0, gy: 0, gz: 0.5);
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(milliseconds: 200)),
        lat: 1.0001,
        lng: 1.0001,
        speedMs: 10,
        accuracyM: 3.0,
      );

      expect(estimator.currentState!.isCornering, isTrue);
    });

    test('isCornering is false below the yaw-rate threshold even while moving', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 90.0,
      );
      estimator.addGyroSample(timestamp: t0.add(const Duration(milliseconds: 100)), gx: 0, gy: 0, gz: 0.1);
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(milliseconds: 200)),
        lat: 1.0001,
        lng: 1.0001,
        speedMs: 10,
        accuracyM: 3.0,
      );

      expect(estimator.currentState!.isCornering, isFalse);
    });

    test('isCornering is false when stopped, even with high yaw rate', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 0, // stopped
        accuracyM: 3.0,
        headingDeg: 90.0,
      );
      estimator.addGyroSample(timestamp: t0.add(const Duration(milliseconds: 100)), gx: 0, gy: 0, gz: 0.9);
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(milliseconds: 200)),
        lat: 1.0001,
        lng: 1.0001,
        speedMs: 0,
        accuracyM: 3.0,
      );

      expect(estimator.currentState!.isCornering, isFalse);
      expect(estimator.currentState!.isMoving, isFalse);
      expect(estimator.currentState!.isStopped, isTrue);
    });

    test('isBraking/isAccelerating reuse the existing hard-brake/rapid-accel thresholds', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
        accelerationMs2: -5.0, // <= -4.0 hard-braking threshold
      );
      expect(estimator.currentState!.isBraking, isTrue);
      expect(estimator.currentState!.isAccelerating, isFalse);

      estimator.addGpsSample(
        timestamp: t0.add(const Duration(seconds: 1)),
        lat: 1.0001,
        lng: 1.0001,
        speedMs: 15,
        accuracyM: 3.0,
        accelerationMs2: 5.0, // >= 4.0 rapid-accel threshold
      );
      expect(estimator.currentState!.isBraking, isFalse);
      expect(estimator.currentState!.isAccelerating, isTrue);
    });

    test('confidence is 100 with an accurate fix and healthy, recent IMU data', () {
      for (var i = 0; i < 6; i++) {
        estimator.addAccelSample(
          timestamp: t0.add(Duration(milliseconds: i * 50)),
          ax: 1.0 + (i.isEven ? 0.1 : -0.1),
          ay: 0,
          az: 0,
        );
      }
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(milliseconds: 300)),
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0, // "great" accuracy floor
      );
      expect(estimator.currentState!.confidence, 100);
    });

    test('confidence drops with a poor-accuracy fix even with healthy IMU data', () {
      for (var i = 0; i < 6; i++) {
        estimator.addAccelSample(
          timestamp: t0.add(Duration(milliseconds: i * 50)),
          ax: 1.0 + (i.isEven ? 0.1 : -0.1),
          ay: 0,
          az: 0,
        );
      }
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(milliseconds: 300)),
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 25.0, // at the reject ceiling -> 0 accuracy points
      );
      // accuracyScore 0 + recencyScore 20 + imuScore 30 = 50
      expect(estimator.currentState!.confidence, 50);
    });

    test('confidence drops sharply with no IMU data at all', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
      );
      // accuracyScore 50 + recencyScore 20 + imuScore (60% quality * 30 = 18) = 88
      expect(estimator.currentState!.confidence, 88);
    });

    test('tick() recomputes confidence against a later time without a new fix', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
      );
      final freshConfidence = estimator.currentState!.confidence;

      estimator.tick(t0.add(const Duration(seconds: 30)));
      final staleConfidence = estimator.currentState!.confidence;

      expect(staleConfidence, lessThan(freshConfidence));
    });

    test('tick() is a no-op before any GPS fix has ever arrived', () {
      estimator.tick(t0);
      expect(estimator.currentState, isNull);
    });

    test('reset() clears all state back to nothing', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 90.0,
      );
      expect(estimator.currentState, isNotNull);

      estimator.reset();
      expect(estimator.currentState, isNull);

      // And a fresh fix afterward seeds heading directly again, proving the
      // old fused heading was actually cleared, not just hidden.
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
        headingDeg: 200.0,
      );
      expect(estimator.currentState!.headingDeg, 200.0);
    });

    test('rejects a physically-implausible accel spike as a validator glitch, not a real event', () {
      estimator.addGpsSample(
        timestamp: t0,
        lat: 1.0,
        lng: 1.0,
        speedMs: 10,
        accuracyM: 3.0,
      );
      estimator.addAccelSample(timestamp: t0, ax: 1000, ay: 0, az: 0); // way past the plausibility ceiling
      estimator.addGpsSample(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        lat: 1.0001,
        lng: 1.0001,
        speedMs: 10,
        accuracyM: 3.0,
      );
      // The implausible sample should count as a rejection (lowering
      // imuQuality/confidence), not silently pass through as good data.
      expect(estimator.currentState!.imuQuality, lessThan(100));
    });
  });
}
