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
  });
}
