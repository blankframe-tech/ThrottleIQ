import '../../domain/entities/maintenance_entity.dart';

class MaintenanceConfigModel {
  static MaintenanceConfigEntity fromMap(Map<String, dynamic> m) =>
      MaintenanceConfigEntity(
        bikeId: m['bike_id'] as String,
        serviceType: ServiceTypeExt.fromString(m['service_type'] as String),
        intervalKm: (m['interval_km'] as num).toDouble(),
        isEnabled: (m['is_enabled'] as int) == 1,
      );

  static Map<String, dynamic> toMap(MaintenanceConfigEntity e) => {
        'bike_id': e.bikeId,
        'service_type': e.serviceType.name,
        'interval_km': e.intervalKm,
        'is_enabled': e.isEnabled ? 1 : 0,
      };
}
