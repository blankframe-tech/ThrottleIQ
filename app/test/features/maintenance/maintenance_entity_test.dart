import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

MaintenanceEntity _log({
  required ServiceType type,
  String? customLabel,
}) {
  return MaintenanceEntity(
    id: 'log-1',
    bikeId: 'bike-1',
    serviceType: type,
    date: DateTime(2026, 7, 1),
    odometerKm: 12000,
    customLabel: customLabel,
    createdAt: DateTime(2026, 7, 1),
  );
}

void main() {
  group('ServiceTypeExt.fromString', () {
    test('round-trips every enum value', () {
      for (final type in ServiceType.values) {
        expect(
          ServiceTypeExt.fromString(type.name),
          type,
          reason: '${type.name} should round-trip',
        );
      }
    });

    test('falls back to custom for an unknown string', () {
      expect(ServiceTypeExt.fromString('gearbox_rebuild'), ServiceType.custom);
      expect(ServiceTypeExt.fromString(''), ServiceType.custom);
    });

    test('the pre-existing type names are unchanged and fuel is pinned', () {
      expect(ServiceType.oilChange.name, 'oilChange');
      expect(ServiceType.airFilter.name, 'airFilter');
      expect(ServiceType.chain.name, 'chain');
      expect(ServiceType.tire.name, 'tire');
      expect(ServiceType.fuel.name, 'fuel');
    });

    test('fuel service type is properly configured', () {
      expect(ServiceType.fuel.label, 'Fuel');
      expect(ServiceType.fuel.category, MaintenanceCategory.engine);
      expect(ServiceType.fuel.defaultIntervalKm, 300.0);
      expect(ServiceType.fuel.isRecommendedDefault, isTrue);
      expect(_log(type: ServiceType.fuel).displayLabel, 'Fuel');
    });

    test('every type has a non-empty label', () {
      for (final type in ServiceType.values) {
        expect(type.label, isNotEmpty, reason: '${type.name} needs a label');
      }
    });
  });

  group('MaintenanceEntity.displayLabel', () {
    test('uses the custom label for a custom service', () {
      final log = _log(type: ServiceType.custom, customLabel: 'Radiator flush');
      expect(log.displayLabel, 'Radiator flush');
    });

    test('trims the custom label', () {
      final log = _log(type: ServiceType.custom, customLabel: '  Fork seals  ');
      expect(log.displayLabel, 'Fork seals');
    });

    test('falls back to the enum label when the custom label is null', () {
      final log = _log(type: ServiceType.custom);
      expect(log.displayLabel, 'Custom');
    });

    test('falls back to the enum label when the custom label is blank', () {
      final log = _log(type: ServiceType.custom, customLabel: '   ');
      expect(log.displayLabel, 'Custom');
    });

    test('ignores a stray custom label on a non-custom service', () {
      final log = _log(type: ServiceType.oilChange, customLabel: 'ignore me');
      expect(log.displayLabel, 'Oil Change');
    });

    test('uses the enum label for the new built-in types', () {
      expect(_log(type: ServiceType.frontDiscPads).displayLabel, 'Front Disc Pads');
      expect(_log(type: ServiceType.rearDrumPads).displayLabel, 'Rear Drum Pads');
      expect(_log(type: ServiceType.radiatorCoolant).displayLabel, 'Radiator / Coolant');
      expect(_log(type: ServiceType.oilFilter).displayLabel, 'Oil Filter');
      expect(_log(type: ServiceType.chainTension).displayLabel, 'Chain Slack & Tension');
      expect(_log(type: ServiceType.brakeRotors).displayLabel, 'Brake Rotors / Discs');
      expect(_log(type: ServiceType.forkSeals).displayLabel, 'Fork Oil & Seals');
      expect(_log(type: ServiceType.wheelBearings).displayLabel, 'Wheel Bearings');
      expect(_log(type: ServiceType.driveBelt).displayLabel, 'Drive Belt');
      expect(_log(type: ServiceType.throttleCables).displayLabel, 'Throttle & Cables');
    });

    test('every type has non-empty description and positive default interval', () {
      for (final type in ServiceType.values) {
        expect(type.description, isNotEmpty);
        expect(type.defaultIntervalKm, greaterThan(0));
      }
    });

    test('category grouping maps appropriately', () {
      expect(ServiceType.oilChange.category, MaintenanceCategory.engine);
      expect(ServiceType.oilFilter.category, MaintenanceCategory.engine);
      expect(ServiceType.chain.category, MaintenanceCategory.drivetrain);
      expect(ServiceType.frontDiscPads.category, MaintenanceCategory.braking);
      expect(ServiceType.tire.category, MaintenanceCategory.chassisElectrical);
    });
  });

  group('MaintenanceConfigEntity', () {
    test('supports equality and copyWith', () {
      const config = MaintenanceConfigEntity(
        bikeId: 'bike-1',
        serviceType: ServiceType.oilChange,
        intervalKm: 1500,
        isEnabled: true,
        notes: 'Castrol Power1 10W-40',
      );

      final modified = config.copyWith(
        intervalKm: 2000,
        isEnabled: false,
        notes: 'Motul 7100 10W-40',
      );
      expect(modified.intervalKm, 2000);
      expect(modified.isEnabled, false);
      expect(modified.bikeId, 'bike-1');
      expect(modified.serviceType, ServiceType.oilChange);
      expect(modified.notes, 'Motul 7100 10W-40');

      const clone = MaintenanceConfigEntity(
        bikeId: 'bike-1',
        serviceType: ServiceType.oilChange,
        intervalKm: 1500,
        isEnabled: true,
        notes: 'Castrol Power1 10W-40',
      );
      expect(config, equals(clone));
    });
  });

  group('MaintenanceReminder', () {
    test('carries notes from config', () {
      const reminder = MaintenanceReminder(
        serviceType: ServiceType.tire,
        status: ReminderStatus.ok,
        kmSinceService: 5000,
        kmLimit: 15000,
        notes: 'Front: 120/70-17, Rear: 160/60-17 (DOT 1524)',
      );

      expect(reminder.notes, 'Front: 120/70-17, Rear: 160/60-17 (DOT 1524)');
      expect(reminder.serviceType, ServiceType.tire);
      expect(reminder.kmSinceService, 5000);
      expect(reminder.kmLimit, 15000);
    });
  });
}
