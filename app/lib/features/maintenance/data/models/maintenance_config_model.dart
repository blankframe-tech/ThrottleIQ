import '../../domain/entities/maintenance_entity.dart';

class MaintenanceConfigModel {
  /// `service_type` holds the check's key: a [ServiceType] name, or
  /// `custom:<id>` for a rider-defined tracked check (the table's primary key
  /// is (bike_id, service_type), so each custom check needs its own value).
  static MaintenanceConfigEntity fromMap(Map<String, dynamic> m) {
    final key = m['service_type'] as String;
    final isCustom = key.startsWith(kCustomCheckPrefix);
    return MaintenanceConfigEntity(
      bikeId: m['bike_id'] as String,
      serviceType:
          isCustom ? ServiceType.custom : ServiceTypeExt.fromString(key),
      intervalKm: (m['interval_km'] as num).toDouble(),
      intervalDays: (m['interval_days'] as num?)?.toInt(),
      isEnabled: (m['is_enabled'] as int) == 1,
      notes: m['notes'] as String?,
      typicalCost: (m['typical_cost'] as num?)?.toDouble(),
      warnKm: (m['warn_km'] as num?)?.toDouble(),
      warnDays: (m['warn_days'] as num?)?.toInt(),
      baselineKm: (m['baseline_km'] as num?)?.toDouble(),
      baselineDate: DateTime.tryParse(m['baseline_date'] as String? ?? ''),
      source: m['source'] == 'user' ? IntervalSource.user : IntervalSource.template,
      customId: isCustom ? key.substring(kCustomCheckPrefix.length) : null,
      customLabel: m['custom_label'] as String?,
    );
  }

  static Map<String, dynamic> toMap(MaintenanceConfigEntity e) => {
        'bike_id': e.bikeId,
        'service_type': e.key,
        'interval_km': e.intervalKm,
        'is_enabled': e.isEnabled ? 1 : 0,
        'notes': (e.notes != null && e.notes!.trim().isNotEmpty)
            ? e.notes!.trim()
            : null,
        // Omitted rather than written as NULL when unset: rows are always
        // replaced wholesale (see MaintenanceConfigDao.saveConfigsForBike),
        // so absent == NULL, and an older table without the column stays
        // writable.
        if (e.typicalCost != null && e.typicalCost! > 0)
          'typical_cost': e.typicalCost,
        if (e.intervalDays != null && e.intervalDays! > 0)
          'interval_days': e.intervalDays,
        if (e.warnKm != null) 'warn_km': e.warnKm,
        if (e.warnDays != null) 'warn_days': e.warnDays,
        if (e.baselineKm != null) 'baseline_km': e.baselineKm,
        if (e.baselineDate != null)
          'baseline_date': e.baselineDate!.toIso8601String(),
        if (e.source == IntervalSource.user) 'source': 'user',
        if (e.customLabel != null && e.customLabel!.trim().isNotEmpty)
          'custom_label': e.customLabel!.trim(),
      };
}
