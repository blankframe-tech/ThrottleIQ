import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/motion_calculator.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_point_entity.dart';

void main() {
  group('MotionCalculator', () {
    late MotionCalculator calculator;

    setUp(() {
      calculator = MotionCalculator();
    });

    group('Speed Calculation', () {
      test('calculates correct speed from motion data', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 15.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.speedMs, equals(15.0));
      });

      test('handles zero speed (stationary)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 5.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 0.0,
          currentLat: 23.8103,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.speedMs, equals(0.0));
      });

      test('handles high speed (highway)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 30.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 50.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.speedMs, equals(50.0));
      });
    });

    group('Acceleration Calculation', () {
      test('calculates positive acceleration (speeding up)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 15.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        // deltaT = 1s, accel = (15 - 10) / 1 = 5 m/s²
        expect(result.acceleration, equals(5.0));
      });

      test('calculates negative acceleration (braking)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 20.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 10.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        // accel = (10 - 20) / 1 = -10 m/s²
        expect(result.acceleration, equals(-10.0));
      });

      test('calculates zero acceleration (constant speed)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 20.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 20.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.acceleration, equals(0.0));
      });

      test('calculates hard deceleration (emergency braking)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 30.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 0.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 2),
        );

        // accel = (0 - 30) / 2 = -15 m/s²
        expect(result.acceleration, equals(-15.0));
      });

      test('handles very short time delta (high precision)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 10.5,
          currentLat: 23.8103,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 0, 100), // 100ms later
        );

        // deltaT = 0.1s, accel = (10.5 - 10) / 0.1 = 5 m/s²
        expect(result.acceleration, closeTo(5.0, 0.01));
      });
    });

    group('Jerk Calculation', () {
      test('calculates positive jerk (increasing acceleration)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
          acceleration: 2.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 15.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        // accel = (15 - 10) / 1 = 5 m/s²
        // jerk = (5 - 2) / 1 = 3 m/s³
        expect(result.jerk, equals(3.0));
      });

      test('calculates negative jerk (decreasing acceleration)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 15.0,
          acceleration: 5.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 18.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        // accel = (18 - 15) / 1 = 3 m/s²
        // jerk = (3 - 5) / 1 = -2 m/s³
        expect(result.jerk, equals(-2.0));
      });

      test('returns null jerk when no previous acceleration', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
          acceleration: null,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 15.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.jerk, isNull);
      });

      test('handles zero jerk (constant acceleration)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
          acceleration: 5.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 15.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        // accel = (15 - 10) / 1 = 5 m/s²
        // jerk = (5 - 5) / 1 = 0
        expect(result.jerk, equals(0.0));
      });
    });

    group('Distance Calculation (Haversine)', () {
      test('calculates zero distance (same location)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 10.0,
          currentLat: 23.8103,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.distanceDeltaM, lessThan(1.0));
      });

      test('calculates short distance (10m north)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 0.0,
          lng: 0.0,
          speedMs: 10.0,
        );

        // ~0.00009 degrees at equator ≈ 10m
        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 10.0,
          currentLat: 0.00009,
          currentLng: 0.0,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.distanceDeltaM, greaterThan(8.0));
        expect(result.distanceDeltaM, lessThan(12.0));
      });

      test('calculates longer distance (100m)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 20.0,
        );

        // Rough estimate: ~0.0009 degrees ≈ 100m at latitude 23.8
        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 20.0,
          currentLat: 23.8112,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.distanceDeltaM, greaterThan(90.0));
        expect(result.distanceDeltaM, lessThan(110.0));
      });

      test('calculates distance for diagonal movement', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 0.0,
          lng: 0.0,
          speedMs: 10.0,
        );

        // Move 10m north and 10m east
        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 10.0,
          currentLat: 0.00009,
          currentLng: 0.00009,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        // Should be sqrt(10² + 10²) ≈ 14.14m
        expect(result.distanceDeltaM, greaterThan(10.0));
      });

      test('handles antipodal points (opposite sides of earth)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 0.0,
          lng: 0.0,
          speedMs: 10.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 10.0,
          currentLat: 0.0,
          currentLng: 180.0,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        // Distance should be ~half earth's circumference (~20,000km)
        expect(result.distanceDeltaM, greaterThan(19000000.0));
      });

      test('calculates distance for well-known locations (Dhaka to Chattogram)', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103, // Dhaka
          lng: 90.4125,
          speedMs: 25.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 25.0,
          currentLat: 22.3475, // Chattogram
          currentLng: 91.8479,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        // Great-circle distance Dhaka-Chattogram ≈ 219 km (the oft-quoted
        // ~250 km figure is the ROAD distance, not straight-line).
        expect(result.distanceDeltaM, greaterThan(210000.0));
        expect(result.distanceDeltaM, lessThan(230000.0));
      });
    });

    group('Zero Delta Time Handling', () {
      test('returns zero distance and no accel/jerk when time delta is zero', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 15.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 0), // Same time
        );

        expect(result.speedMs, equals(15.0));
        expect(result.acceleration, isNull);
        expect(result.jerk, isNull);
        expect(result.distanceDeltaM, equals(0.0));
      });

      test('returns zero distance and no accel when time goes backwards', () {
        final prev = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 1),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 10.0,
        );

        final result = calculator.calculate(
          prev: prev,
          currentSpeedMs: 15.0,
          currentLat: 23.8105,
          currentLng: 90.4130,
          currentTime: DateTime(2026, 7, 12, 10, 0, 0), // Time went backwards
        );

        expect(result.speedMs, equals(15.0));
        expect(result.distanceDeltaM, equals(0.0));
      });
    });

    group('Integration Tests', () {
      test('calculates motion for realistic ride sequence', () {
        // Simulate a 3-second acceleration sequence
        var current = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 0.0,
        );

        // t=0: start moving at 5 m/s
        var result = calculator.calculate(
          prev: current,
          currentSpeedMs: 5.0,
          currentLat: 23.8103,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.speedMs, equals(5.0));
        expect(result.acceleration, equals(5.0));
        expect(result.jerk, isNull);

        // t=1: accelerate to 10 m/s
        current = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 1),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 5.0,
          acceleration: 5.0,
        );

        result = calculator.calculate(
          prev: current,
          currentSpeedMs: 10.0,
          currentLat: 23.8105,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 2),
        );

        expect(result.speedMs, equals(10.0));
        expect(result.acceleration, equals(5.0));
        expect(result.jerk, equals(0.0)); // Constant acceleration

        // t=2: continue to 15 m/s
        current = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 2),
          lat: 23.8105,
          lng: 90.4125,
          speedMs: 10.0,
          acceleration: 5.0,
        );

        result = calculator.calculate(
          prev: current,
          currentSpeedMs: 15.0,
          currentLat: 23.8107,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 3),
        );

        expect(result.speedMs, equals(15.0));
        expect(result.acceleration, equals(5.0));
        expect(result.jerk, equals(0.0));
      });

      test('handles realistic braking sequence', () {
        // Start at 20 m/s with accel 0
        var current = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 0),
          lat: 23.8103,
          lng: 90.4125,
          speedMs: 20.0,
          acceleration: 0.0,
        );

        // Gentle brake: -2 m/s²
        var result = calculator.calculate(
          prev: current,
          currentSpeedMs: 18.0,
          currentLat: 23.8105,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 1),
        );

        expect(result.acceleration, equals(-2.0));
        expect(result.jerk, equals(-2.0)); // jerk = (-2 - 0) / 1

        // Hard brake: -5 m/s²
        current = RidePointEntity(
          rideId: 'test-ride',
          timestamp: DateTime(2026, 7, 12, 10, 0, 1),
          lat: 23.8105,
          lng: 90.4125,
          speedMs: 18.0,
          acceleration: -2.0,
        );

        result = calculator.calculate(
          prev: current,
          currentSpeedMs: 13.0,
          currentLat: 23.8107,
          currentLng: 90.4125,
          currentTime: DateTime(2026, 7, 12, 10, 0, 2),
        );

        expect(result.acceleration, equals(-5.0));
        expect(result.jerk, equals(-3.0)); // jerk = (-5 - (-2)) / 1
      });
    });
  });
}
