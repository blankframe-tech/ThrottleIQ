import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/sensor_validator.dart';

void main() {
  group('SensorValidator', () {
    late SensorValidator validator;

    setUp(() {
      validator = SensorValidator();
    });

    group('isValidGpsFix', () {
      test('accepts a fix at the accuracy ceiling', () {
        expect(validator.isValidGpsFix(accuracyM: 25.0), isTrue);
      });

      test('rejects a fix just past the accuracy ceiling', () {
        expect(validator.isValidGpsFix(accuracyM: 25.01), isFalse);
      });

      test('accepts a very accurate fix', () {
        expect(validator.isValidGpsFix(accuracyM: 3.0), isTrue);
      });

      test('rejects NaN/infinite accuracy', () {
        expect(validator.isValidGpsFix(accuracyM: double.nan), isFalse);
        expect(validator.isValidGpsFix(accuracyM: double.infinity), isFalse);
      });
    });

    group('isPlausibleAccel', () {
      test('accepts a legitimate crash-magnitude spike', () {
        expect(validator.isPlausibleAccel(85.0), isTrue);
      });

      test('accepts the ceiling value', () {
        expect(validator.isPlausibleAccel(300.0), isTrue);
        expect(validator.isPlausibleAccel(-300.0), isTrue);
      });

      test('rejects a sensor-glitch magnitude past the ceiling', () {
        expect(validator.isPlausibleAccel(300.01), isFalse);
        expect(validator.isPlausibleAccel(-300.01), isFalse);
      });

      test('rejects NaN/infinite', () {
        expect(validator.isPlausibleAccel(double.nan), isFalse);
        expect(validator.isPlausibleAccel(double.infinity), isFalse);
      });
    });

    group('isPlausibleYawRate', () {
      test('accepts a real hard-cornering yaw rate', () {
        expect(validator.isPlausibleYawRate(2.0), isTrue); // ~115°/s
      });

      test('rejects past the ~2000°/s ceiling', () {
        expect(validator.isPlausibleYawRate(35.0), isFalse);
      });

      test('rejects NaN/infinite', () {
        expect(validator.isPlausibleYawRate(double.nan), isFalse);
        expect(validator.isPlausibleYawRate(double.infinity), isFalse);
      });
    });

    group('isFreshTimestamp', () {
      test('accepts when there is no previous timestamp yet', () {
        expect(validator.isFreshTimestamp(DateTime(2026, 1, 1), null), isTrue);
      });

      test('accepts a timestamp after the previous one', () {
        final prev = DateTime(2026, 1, 1, 12, 0, 0);
        final next = DateTime(2026, 1, 1, 12, 0, 1);
        expect(validator.isFreshTimestamp(next, prev), isTrue);
      });

      test('rejects a timestamp equal to the previous one', () {
        final t = DateTime(2026, 1, 1, 12, 0, 0);
        expect(validator.isFreshTimestamp(t, t), isFalse);
      });

      test('rejects an out-of-order (earlier) timestamp', () {
        final prev = DateTime(2026, 1, 1, 12, 0, 1);
        final next = DateTime(2026, 1, 1, 12, 0, 0);
        expect(validator.isFreshTimestamp(next, prev), isFalse);
      });
    });
  });
}
