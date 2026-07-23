import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/recording_cadence_policy.dart';
import 'package:throttleiq/features/ride/domain/entities/vehicle_state.dart';

VehicleState _state({
  int confidence = 100,
  bool isCornering = false,
  bool isBraking = false,
  bool isAccelerating = false,
}) =>
    VehicleState(
      timestamp: DateTime(2026, 1, 1),
      latitude: 1.0,
      longitude: 1.0,
      speedMs: 10,
      accelerationMs2: 0,
      confidence: confidence,
      imuQuality: 100,
      isMoving: true,
      isStopped: false,
      isCornering: isCornering,
      isBraking: isBraking,
      isAccelerating: isAccelerating,
      gpsAccuracyM: 3.0,
    );

void main() {
  group('RecordingCadencePolicy', () {
    late RecordingCadencePolicy policy;
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    setUp(() {
      policy = RecordingCadencePolicy();
    });

    test('always persists when there is no fused state yet', () {
      expect(policy.shouldPersist(timestamp: t0, vehicleState: null), isTrue);
    });

    test('always persists the first eligible-for-thinning fix (nothing to throttle against yet)', () {
      expect(policy.shouldPersist(timestamp: t0, vehicleState: _state()), isTrue);
    });

    test('throttles subsequent high-confidence steady fixes within the interval', () {
      policy.shouldPersist(timestamp: t0, vehicleState: _state());
      final result = policy.shouldPersist(
        timestamp: t0.add(const Duration(seconds: 2)),
        vehicleState: _state(),
      );
      expect(result, isFalse);
    });

    test('persists again once the throttle interval elapses', () {
      policy.shouldPersist(timestamp: t0, vehicleState: _state());
      final result = policy.shouldPersist(
        timestamp: t0.add(const Duration(seconds: 5)),
        vehicleState: _state(),
      );
      expect(result, isTrue);
    });

    test('never thins below the confidence floor, regardless of interval', () {
      policy.shouldPersist(timestamp: t0, vehicleState: _state(confidence: 69));
      final result = policy.shouldPersist(
        timestamp: t0.add(const Duration(milliseconds: 500)),
        vehicleState: _state(confidence: 69),
      );
      expect(result, isTrue);
    });

    test('never thins while cornering, regardless of interval or confidence', () {
      policy.shouldPersist(timestamp: t0, vehicleState: _state(isCornering: true));
      final result = policy.shouldPersist(
        timestamp: t0.add(const Duration(milliseconds: 500)),
        vehicleState: _state(isCornering: true),
      );
      expect(result, isTrue);
    });

    test('never thins while braking', () {
      policy.shouldPersist(timestamp: t0, vehicleState: _state(isBraking: true));
      final result = policy.shouldPersist(
        timestamp: t0.add(const Duration(milliseconds: 500)),
        vehicleState: _state(isBraking: true),
      );
      expect(result, isTrue);
    });

    test('never thins while accelerating', () {
      policy.shouldPersist(timestamp: t0, vehicleState: _state(isAccelerating: true));
      final result = policy.shouldPersist(
        timestamp: t0.add(const Duration(milliseconds: 500)),
        vehicleState: _state(isAccelerating: true),
      );
      expect(result, isTrue);
    });

    test('an event persist also resets the throttle clock for the steady fix right after it', () {
      // The throttle is a simple "at most one persisted point per interval,
      // full stop" rate limiter — it doesn't distinguish *why* the previous
      // persist happened. A corner (always persisted) immediately followed
      // by a steady fix still throttles against that corner's timestamp,
      // same as it would against a prior steady fix.
      policy.shouldPersist(timestamp: t0, vehicleState: _state());
      policy.shouldPersist(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        vehicleState: _state(isCornering: true),
      );
      final result = policy.shouldPersist(
        timestamp: t0.add(const Duration(milliseconds: 200)),
        vehicleState: _state(),
      );
      expect(result, isFalse);
    });

    test('reset() clears the throttle so the next fix persists immediately', () {
      policy.shouldPersist(timestamp: t0, vehicleState: _state());
      policy.reset();
      final result = policy.shouldPersist(
        timestamp: t0.add(const Duration(milliseconds: 100)),
        vehicleState: _state(),
      );
      expect(result, isTrue);
    });
  });
}
