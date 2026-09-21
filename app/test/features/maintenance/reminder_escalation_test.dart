import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';

/// issues §32: the status pill is an early-warning indicator, so a part close
/// to its interval must not read the same green "OK" as one that was just
/// serviced. Pins the thresholds in [computeMaintenanceReminders].
void main() {
  ReminderStatus statusAt(double intervalKm, double kmSinceService) {
    final reminders = computeMaintenanceReminders(
      kmSinceService, // odometer; nothing logged, so km since service == odometer
      const [],
      [
        MaintenanceConfigEntity(
          bikeId: 'b',
          serviceType: ServiceType.oilChange,
          intervalKm: intervalKm,
        ),
      ],
    );
    return reminders.single.status;
  }

  group('long intervals (> 1000 km): due soon at 80% used', () {
    test('freshly serviced and half-way are OK', () {
      expect(statusAt(3000, 0), ReminderStatus.ok);
      expect(statusAt(3000, 1500), ReminderStatus.ok);
    });

    test('13% remaining is due soon, not OK', () {
      // The exact case from the UI critique: 87% of the interval used.
      expect(statusAt(3000, 2610), ReminderStatus.dueSoon);
    });

    test('the boundary: 79% used is OK, 80% is due soon', () {
      expect(statusAt(3000, 2369), ReminderStatus.ok);
      expect(statusAt(3000, 2400), ReminderStatus.dueSoon);
    });

    test('at or past the interval is overdue', () {
      expect(statusAt(3000, 2999), ReminderStatus.dueSoon);
      expect(statusAt(3000, 3000), ReminderStatus.overdue);
      expect(statusAt(3000, 4500), ReminderStatus.overdue);
    });
  });

  group('short intervals (<= 1000 km): due soon in the last 150 km', () {
    test('chain-lube-sized interval escalates 150 km out', () {
      expect(statusAt(500, 349), ReminderStatus.ok);
      expect(statusAt(500, 350), ReminderStatus.dueSoon);
      expect(statusAt(500, 500), ReminderStatus.overdue);
    });
  });
}
