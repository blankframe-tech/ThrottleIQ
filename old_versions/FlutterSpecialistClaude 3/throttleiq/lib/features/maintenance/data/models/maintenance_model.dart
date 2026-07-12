import '../../domain/entities/maintenance_entity.dart';

class MaintenanceModel {
  static MaintenanceEntity fromMap(Map<String, dynamic> m) => MaintenanceEntity(
        id: m['id'] as String,
        bikeId: m['bike_id'] as String,
        serviceType: ServiceTypeExt.fromString(m['service_type'] as String),
        date: DateTime.parse(m['date'] as String),
        odometerKm: (m['odometer_km'] as num).toDouble(),
        cost: m['cost'] != null ? (m['cost'] as num).toDouble() : null,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  static Map<String, dynamic> toMap(MaintenanceEntity e) => {
        'id': e.id,
        'bike_id': e.bikeId,
        'service_type': e.serviceType.name,
        'date': e.date.toIso8601String(),
        'odometer_km': e.odometerKm,
        'cost': e.cost,
        'notes': e.notes,
        'synced': 0,
        'created_at': e.createdAt.toIso8601String(),
      };
}
