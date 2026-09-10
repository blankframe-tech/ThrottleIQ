import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/core/utils/ride_speed_invariant.dart';

void main() {
  group('RideSpeedInvariant.reconcile', () {
    test('leaves a normal ride (max above avg, under ceiling) unchanged', () {
      final result = RideSpeedInvariant.reconcile(
        avgSpeedKmh: 40,
        rawMaxSpeedKmh: 90,
      );
      expect(result, 90);
    });

    test('floors a max speed below the average up to the average', () {
      final result = RideSpeedInvariant.reconcile(
        avgSpeedKmh: 60,
        rawMaxSpeedKmh: 10,
      );
      expect(result, 60);
    });

    test('floors a missing (zero) max speed up to the average', () {
      final result = RideSpeedInvariant.reconcile(
        avgSpeedKmh: 55,
        rawMaxSpeedKmh: 0,
      );
      expect(result, 55);
    });

    test('clamps a wildly implausible max speed to the ceiling', () {
      final result = RideSpeedInvariant.reconcile(
        avgSpeedKmh: 40,
        rawMaxSpeedKmh: 9999,
      );
      expect(result, RideSpeedInvariant.ceilingKmh);
      expect(result, closeTo(SensorConstants.maxPlausibleSpeedMs * 3.6, 0.0001));
    });

    test('zero-duration/zero-distance edge case (avg 0) does not floor a real max speed', () {
      final result = RideSpeedInvariant.reconcile(
        avgSpeedKmh: 0,
        rawMaxSpeedKmh: 80,
      );
      expect(result, 80);
    });
  });

  group('RideSpeedInvariant.reconcileFromDistance', () {
    test('computes average from distance/duration and floors max to it', () {
      final result = RideSpeedInvariant.reconcileFromDistance(
        distanceKm: 60,
        durationSeconds: 3600, // avg = 60 km/h
        rawMaxSpeedKmh: 20,
      );
      expect(result, 60);
    });

    test('clamps a fabricated 9999 km/h top speed to the ceiling', () {
      final result = RideSpeedInvariant.reconcileFromDistance(
        distanceKm: 50,
        durationSeconds: 3600,
        rawMaxSpeedKmh: 9999,
      );
      expect(result, RideSpeedInvariant.ceilingKmh);
    });

    test('zero duration falls back to average of 0, leaving a plausible max alone', () {
      final result = RideSpeedInvariant.reconcileFromDistance(
        distanceKm: 10,
        durationSeconds: 0,
        rawMaxSpeedKmh: 30,
      );
      expect(result, 30);
    });
  });
}
