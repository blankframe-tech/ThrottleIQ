import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/export_service.dart';

void main() {
  late ExportService service;

  setUp(() {
    service = ExportService();
  });

  group('ExportService.generateGPX - Timezone & UTC formatting (§109.3)', () {
    test(
        'converts local startTime without offset into UTC ISO-8601 with Z in <time>',
        () {
      // Local ISO string without timezone (e.g. 10:30 local in Dhaka UTC+6 is 04:30 UTC)
      final localDate = DateTime(2026, 10, 22, 10, 30, 0);
      final ride = {
        'id': 'ride-123',
        'startTime': localDate
            .toIso8601String(), // Local time representation without 'Z'
        'distanceM': 15000,
      };

      final gpx = service.generateGPX(ride, []);

      final expectedUtcTime = localDate.toUtc().toIso8601String();
      expect(gpx, contains('<time>$expectedUtcTime</time>'));
      expect(expectedUtcTime.endsWith('Z'), isTrue);
    });

    test('preserves already UTC startTime with trailing Z', () {
      const utcTime = '2026-10-22T04:30:00.000Z';
      final ride = {
        'id': 'ride-123',
        'startTime': utcTime,
        'distanceM': 5000,
      };

      final gpx = service.generateGPX(ride, []);

      expect(gpx, contains('<time>$utcTime</time>'));
    });

    test('converts track point timestamps to UTC ISO-8601 with Z', () {
      final pointTime = DateTime(2026, 10, 22, 10, 31, 0);
      final ride = {
        'id': 'ride-123',
        'startTime': '2026-10-22T04:30:00.000Z',
        'distanceM': 1000,
      };
      final points = [
        {
          'lat': 23.8103,
          'lng': 90.4125,
          'timestamp': pointTime.toIso8601String(),
          'altitude_m': 12.5,
        },
      ];

      final gpx = service.generateGPX(ride, points);

      final expectedPointUtc = pointTime.toUtc().toIso8601String();
      expect(gpx, contains('<trkpt lat="23.8103" lon="90.4125">'));
      expect(gpx, contains('<ele>12.50</ele>'));
      expect(gpx, contains('<time>$expectedPointUtc</time></trkpt>'));
      expect(expectedPointUtc.endsWith('Z'), isTrue);
    });

    test('computes bounds and distance properly in GPX', () {
      final ride = {
        'id': 'ride-456',
        'startTime': '2026-10-22T04:00:00.000Z',
        'distanceM': 2500,
      };
      final points = [
        {
          'lat': 23.8100,
          'lng': 90.4100,
          'timestamp': '2026-10-22T04:00:00.000Z',
          'altitude_m': 10.0,
        },
        {
          'lat': 23.8200,
          'lng': 90.4200,
          'timestamp': '2026-10-22T04:05:00.000Z',
          'altitude_m': 0.0, // 0 elevation should not produce <ele>
        },
      ];

      final gpx = service.generateGPX(ride, points);

      expect(gpx, contains('<desc>Distance: 2.50 km</desc>'));
      expect(
          gpx,
          contains(
              '<bounds minlat="23.81" minlon="90.41" maxlat="23.82" maxlon="90.42" />'));
      expect(gpx, contains('<ele>10.00</ele>'));
      // Second point has elevation 0.0, so no <ele> tag for it
      expect(
          gpx,
          contains(
              '<trkpt lat="23.82" lon="90.42"><time>2026-10-22T04:05:00.000Z</time></trkpt>'));
    });
  });
}
