import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/maintenance/data/models/maintenance_config_model.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';

void main() {
  group('MaintenanceConfigModel', () {
    test('serializes and deserializes cleanly', () {
      const entity = MaintenanceConfigEntity(
        bikeId: 'bike-abc',
        serviceType: ServiceType.sparkPlug,
        intervalKm: 12000,
        isEnabled: true,
      );

      final map = MaintenanceConfigModel.toMap(entity);
      expect(map['bike_id'], 'bike-abc');
      expect(map['service_type'], 'sparkPlug');
      expect(map['interval_km'], 12000.0);
      expect(map['is_enabled'], 1);

      final reconstructed = MaintenanceConfigModel.fromMap(map);
      expect(reconstructed, equals(entity));
    });

    test('handles is_enabled = 0 correctly', () {
      const entity = MaintenanceConfigEntity(
        bikeId: 'bike-abc',
        serviceType: ServiceType.valveClearance,
        intervalKm: 25000,
        isEnabled: false,
      );

      final map = MaintenanceConfigModel.toMap(entity);
      expect(map['is_enabled'], 0);

      final reconstructed = MaintenanceConfigModel.fromMap(map);
      expect(reconstructed.isEnabled, isFalse);
    });

    test('serializes and deserializes notes correctly', () {
      const entity = MaintenanceConfigEntity(
        bikeId: 'bike-abc',
        serviceType: ServiceType.fuel,
        intervalKm: 300,
        isEnabled: true,
        notes: 'Octane 95, 12L Tank Capacity',
      );

      final map = MaintenanceConfigModel.toMap(entity);
      expect(map['notes'], 'Octane 95, 12L Tank Capacity');

      final reconstructed = MaintenanceConfigModel.fromMap(map);
      expect(reconstructed.notes, 'Octane 95, 12L Tank Capacity');
      expect(reconstructed, equals(entity));
    });

    test('trims whitespace and treats empty notes as null', () {
      const withSpaces = MaintenanceConfigEntity(
        bikeId: 'bike-abc',
        serviceType: ServiceType.oilChange,
        intervalKm: 2500,
        isEnabled: true,
        notes: '   Motul 7100 10W-40   ',
      );
      expect(MaintenanceConfigModel.toMap(withSpaces)['notes'], 'Motul 7100 10W-40');

      const blank = MaintenanceConfigEntity(
        bikeId: 'bike-abc',
        serviceType: ServiceType.chain,
        intervalKm: 500,
        isEnabled: true,
        notes: '     ',
      );
      expect(MaintenanceConfigModel.toMap(blank)['notes'], isNull);
    });
  });
}
