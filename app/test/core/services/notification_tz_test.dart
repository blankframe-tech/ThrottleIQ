import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  // issues §101.C8: an unknown zone name used to leave tz.local at UTC, so
  // the 9 pm daily summary fired at 03:00 in Bangladesh.
  group('NotificationService.resolveLocalLocation', () {
    test('a valid name resolves to that zone', () {
      expect(
          NotificationService.resolveLocalLocation(
                  'Asia/Dhaka', const Duration(hours: 6))
              .name,
          'Asia/Dhaka');
    });

    test('an unknown name falls back to the device offset', () {
      final loc = NotificationService.resolveLocalLocation(
          'Not/AZone', const Duration(hours: 6));
      final now = tz.TZDateTime.now(loc);
      expect(now.timeZoneOffset, const Duration(hours: 6));
    });

    test('a negative whole-hour offset maps to the inverted Etc zone', () {
      final loc = NotificationService.resolveLocalLocation(
          null, const Duration(hours: -5));
      expect(tz.TZDateTime.now(loc).timeZoneOffset, const Duration(hours: -5));
    });

    test('the legacy Asia/Dacca alias resolves', () {
      final loc = NotificationService.resolveLocalLocation(
          'Asia/Dacca', const Duration(hours: 6));
      expect(tz.TZDateTime.now(loc).timeZoneOffset, const Duration(hours: 6));
    });

    test('an unknown name with a non-whole-hour offset does not throw', () {
      expect(
        () => NotificationService.resolveLocalLocation(
            'bad', const Duration(hours: 5, minutes: 45)),
        returnsNormally,
      );
    });
  });

  // issues §101.C9: "tomorrow" was now + 24 h, which lands an hour off on a
  // DST-change day.
  group('NotificationService.nextInstanceOf', () {
    late tz.Location ny;
    setUpAll(() => ny = tz.getLocation('America/New_York'));

    test('across a spring-forward night stays at 21:00 local', () {
      // US DST began 2026-03-08 at 02:00. 22:00 on the 7th is past 21:00.
      final now = tz.TZDateTime(ny, 2026, 3, 7, 22);
      final next = NotificationService.nextInstanceOf(now, 21, 0);
      expect([next.year, next.month, next.day, next.hour, next.minute],
          [2026, 3, 8, 21, 0]);
    });

    test('across a fall-back night stays at 21:00 local', () {
      final now = tz.TZDateTime(ny, 2026, 10, 31, 22);
      final next = NotificationService.nextInstanceOf(now, 21, 0);
      expect([next.month, next.day, next.hour], [11, 1, 21]);
    });

    test('a time still ahead today is today', () {
      final now = tz.TZDateTime(ny, 2026, 6, 1, 8);
      final next = NotificationService.nextInstanceOf(now, 21, 0);
      expect([next.day, next.hour], [1, 21]);
    });

    test('exactly now rolls over to tomorrow', () {
      final now = tz.TZDateTime(ny, 2026, 6, 30, 21);
      final next = NotificationService.nextInstanceOf(now, 21, 0);
      expect([next.month, next.day, next.hour], [7, 1, 21]);
    });
  });
}
