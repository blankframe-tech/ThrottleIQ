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

    // These names are persisted in SQLite, so renaming one silently orphans
    // every already-logged row. Pin the original four explicitly.
    test('the pre-existing type names are unchanged', () {
      expect(ServiceType.oilChange.name, 'oilChange');
      expect(ServiceType.airFilter.name, 'airFilter');
      expect(ServiceType.chain.name, 'chain');
      expect(ServiceType.tire.name, 'tire');
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
    });
  });
}
