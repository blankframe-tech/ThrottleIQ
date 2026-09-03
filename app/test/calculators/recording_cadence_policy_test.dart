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

    test('an event does not reset the steady clock, maintaining straight-line cadence', () {
      // t0: initial steady fix persisted on steady clock
      policy.shouldPersist(timestamp: t0, vehicleState: _state());

      // t0 + 2s: cornering event persisted on event clock
      policy.shouldPersist(
        timestamp: t0.add(const Duration(seconds: 2)),
        vehicleState: _state(isCornering: true),
      );

      // t0 + 3s: steady fix within 5s of t0 is throttled
      final result1 = policy.shouldPersist(
        timestamp: t0.add(const Duration(seconds: 3)),
        vehicleState: _state(),
      );
      expect(result1, isFalse);

      // t0 + 5s: steady fix after 5s from t0 is persisted (not pushed back to t0+7s)
      final result2 = policy.shouldPersist(
        timestamp: t0.add(const Duration(seconds: 5)),
        vehicleState: _state(),
      );
      expect(result2, isTrue);
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
