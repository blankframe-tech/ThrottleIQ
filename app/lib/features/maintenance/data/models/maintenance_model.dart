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
        customLabel: m['custom_label'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        visitId: m['visit_id'] as String?,
        checkKey: m['check_key'] as String?,
        shopName: m['shop_name'] as String?,
        shopKind: ShopKindExt.fromString(m['shop_kind'] as String?),
        receiptPath: m['receipt_path'] as String?,
        visitTotal: (m['visit_total'] as num?)?.toDouble(),
        visitLabel: m['visit_label'] as String?,
        partBrand: m['part_brand'] as String?,
        partGrade: m['part_grade'] as String?,
      );

  /// Visit columns are written only when set, so a row stays insertable into
  /// a pre-v20 table (an older build pulling this log from the cloud skips
  /// unknown columns' rows otherwise — see CloudRepository.downloadMaintenance).
  static Map<String, dynamic> toMap(MaintenanceEntity e) => {
        'id': e.id,
        'bike_id': e.bikeId,
        'service_type': e.serviceType.name,
        'date': e.date.toIso8601String(),
        'odometer_km': e.odometerKm,
        'cost': e.cost,
        'notes': e.notes,
        'custom_label': e.customLabel,
        'synced': 0,
        'created_at': e.createdAt.toIso8601String(),
        if (e.visitId != null) 'visit_id': e.visitId,
        if (e.checkKey != null) 'check_key': e.checkKey,
        if (e.shopName != null) 'shop_name': e.shopName,
        if (e.shopKind != null) 'shop_kind': e.shopKind!.name,
        if (e.receiptPath != null) 'receipt_path': e.receiptPath,
        if (e.visitTotal != null) 'visit_total': e.visitTotal,
        if (e.visitLabel != null) 'visit_label': e.visitLabel,
        if (e.partBrand != null) 'part_brand': e.partBrand,
        if (e.partGrade != null) 'part_grade': e.partGrade,
      };
}
