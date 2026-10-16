import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/core/services/auto_tracking_service.dart';

/// Critique B5: the foreground-task service hosts a manual ride and records
/// it itself once the UI's heartbeat stops.
void main() {
  final t0 = DateTime(2026, 10, 15, 8);
  const timeout = AutoTrackingService.uiBeatTimeout;

  group('uiGone', () {
    test('a recent heartbeat means the UI is alive', () {
      expect(
          AutoTrackingService.uiGone(
              now: t0.add(timeout * 3),
              hostedSince: t0,
              lastUiBeat: t0.add(timeout * 3 - const Duration(seconds: 1))),
          isFalse);
    });

    test('silence for the timeout means it is gone', () {
      expect(
          AutoTrackingService.uiGone(
              now: t0.add(timeout * 2), hostedSince: t0, lastUiBeat: t0),
          isTrue);
    });

    test('no beat yet: counted from when hosting began', () {
      expect(
          AutoTrackingService.uiGone(
              now: t0.add(timeout - const Duration(seconds: 1)),
              hostedSince: t0),
          isFalse);
      expect(AutoTrackingService.uiGone(now: t0.add(timeout), hostedSince: t0),
          isTrue);
    });

    test('a beat from before hosting began does not count', () {
      expect(
          AutoTrackingService.uiGone(
              now: t0.add(const Duration(seconds: 5)),
              hostedSince: t0,
              lastUiBeat: t0.subtract(const Duration(hours: 1))),
          isFalse);
    });
  });

  group('canRecordWithoutUi', () {
    test('a service started from the app keeps while-in-use access', () {
      expect(
          AutoTrackingService.canRecordWithoutUi(
              startedBySystem: false,
              permission: LocationPermission.whileInUse),
          isTrue);
    });

    test('a system restart needs "Allow all the time"', () {
      expect(
          AutoTrackingService.canRecordWithoutUi(
              startedBySystem: true, permission: LocationPermission.whileInUse),
          isFalse);
      expect(
          AutoTrackingService.canRecordWithoutUi(
              startedBySystem: true, permission: LocationPermission.always),
          isTrue);
    });

    test('no permission, no recording', () {
      expect(
          AutoTrackingService.canRecordWithoutUi(
              startedBySystem: false, permission: LocationPermission.denied),
          isFalse);
    });
  });

  group('takeoverPointRow', () {
    Position fix(
            {double accuracy = 8, double speed = 12, double heading = 90}) =>
        Position(
          latitude: 23.81,
          longitude: 90.41,
          timestamp: DateTime.utc(2026, 10, 15, 2, 30),
          accuracy: accuracy,
          altitude: 9,
          altitudeAccuracy: 0,
          heading: heading,
          headingAccuracy: 0,
          speed: speed,
          speedAccuracy: 0,
        );

    test('maps a fix to the recorder\'s ride_points columns', () {
      final row = AutoTrackingService.takeoverPointRow('r1', fix())!;
      expect(row['ride_id'], 'r1');
      expect(row['timestamp'], '2026-10-15T02:30:00.000Z');
      expect(row['lat'], 23.81);
      expect(row['lng'], 90.41);
      expect(row['speed_ms'], 12);
      expect(row['accuracy_m'], 8);
      expect(row['altitude_m'], 9);
      expect(row['heading_deg'], 90);
      expect(row['period_type'], 'moving');
    });

    test('drops a fix the recorder\'s accuracy gate would drop', () {
      expect(
          AutoTrackingService.takeoverPointRow(
              'r1', fix(accuracy: SensorConstants.maxGpsAccuracyM + 1)),
          isNull);
      expect(
          AutoTrackingService.takeoverPointRow('r1', fix(accuracy: double.nan)),
          isNull);
    });

    test('bad speed and heading are cleaned, standing still is idle', () {
      final row = AutoTrackingService.takeoverPointRow(
          'r1', fix(speed: double.nan, heading: -1))!;
      expect(row['speed_ms'], 0.0);
      expect(row['heading_deg'], isNull);
      expect(row['period_type'], 'idle');
    });
  });
}
