import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/services/notification_service.dart';
import 'package:throttleiq/features/maintenance/data/services/maintenance_alerts.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/maintenance_forecast.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final now = DateTime(2026, 10, 6);

  CheckForecast f({
    ReminderStatus status = ReminderStatus.dueSoon,
    double? kmLeft,
    int? daysLeft,
    int? daysLimit,
    int? warnDays,
    double? lastKm = 12000,
  }) =>
      CheckForecast(
        key: 'oilChange',
        serviceType: ServiceType.oilChange,
        status: status,
        kmLimit: 1500,
        baseKmLimit: 1500,
        kmLeft: kmLeft,
        daysLeft: daysLeft,
        daysLimit: daysLimit,
        warnDays: warnDays,
        lastServiceKm: lastKm,
      );

  test('one alert per item, status and service', () {
    final soon = MaintenanceAlerts.alertKey('b1', f());
    final over =
        MaintenanceAlerts.alertKey('b1', f(status: ReminderStatus.overdue));
    final nextService = MaintenanceAlerts.alertKey('b1', f(lastKm: 13500));
    expect({soon, over, nextService}, hasLength(3));
    expect(MaintenanceAlerts.alertKey('b1', f()), soon);
  });

  test('notification ids stay inside the maintenance range and are stable', () {
    for (final k in ['b1|oilChange', 'b2|chain', 'x|paper:taxToken']) {
      final id = MaintenanceAlerts.notificationIdFor(k);
      expect(id, greaterThanOrEqualTo(NotificationService.maintenanceIdBase));
      expect(
          id,
          lessThan(NotificationService.maintenanceIdBase +
              NotificationService.maintenanceIdSpan));
      expect(MaintenanceAlerts.notificationIdFor(k), id);
    }
  });

  test('date-driven checks are scheduled for the start of their window', () {
    final at = MaintenanceAlerts.warningStart(
        f(status: ReminderStatus.ok, daysLeft: 100, daysLimit: 730, warnDays: 30),
        now);
    expect(at, DateTime(2026, 12, 15, 10)); // due 14 Jan, 30-day window
    expect(MaintenanceAlerts.warningStart(f(kmLeft: 500), now), isNull);
  });

  test('body text says how much is left, or how far over', () {
    expect(remainingText(f(kmLeft: 410, daysLeft: 17), l10n, now),
        '410 km or 17 days left, whichever comes first');
    expect(
        remainingText(
            f(status: ReminderStatus.overdue, kmLeft: -120), l10n, now),
        'Over by 120 km');
    expect(
        remainingText(
            f(status: ReminderStatus.overdue, daysLeft: -3), l10n, now),
        'Was due 3 days ago');
    expect(remainingText(f(daysLeft: 1), l10n, now), '1 day left');
  });

  test('body text honours the imperial unit choice (issues §101.R10)', () {
    expect(
        remainingText(f(kmLeft: 410, daysLeft: 17), l10n, now, imperial: true),
        '255 mi or 17 days left, whichever comes first');
    expect(
        remainingText(
            f(status: ReminderStatus.overdue, kmLeft: -120), l10n, now,
            imperial: true),
        'Over by 75 mi');
  });

  test('every item gets its own id, and keeps it', () {
    final keys = [
      for (var b = 0; b < 5; b++)
        for (var i = 0; i < 25; i++) 'bike$b|item$i',
    ];
    final ids = IdAllocatorForTesting.allocate(const {}, keys);
    expect(ids.values.toSet().length, keys.length);
    final again = IdAllocatorForTesting.allocate(ids, keys);
    expect(again, ids);
  });

  test('the due day itself is "due today", not overdue', () {
    expect(remainingText(f(daysLeft: 0), l10n, now), 'Due today');
  });
}

