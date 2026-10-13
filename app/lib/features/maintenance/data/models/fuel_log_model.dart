import '../../domain/entities/fuel_log.dart';

/// SQLite row and Firestore document shapes for [FuelLogEntity].
///
/// The cloud document is the row minus the local-only `synced` flag, with
/// `full_tank` as a real boolean (SQLite has none). `firestore.rules`
/// validates exactly this key set — change both together.
class FuelLogModel {
  const FuelLogModel._();

  /// Firestore subcollection under `users/{uid}`.
  static const collection = 'fuelLogs';

  /// Keys a cloud document may carry, besides the server-set `syncedAt`.
  static const cloudKeys = [
    'id',
    'bike_id',
    'filled_at',
    'odometer_km',
    'liters',
    'total_cost',
    'price_per_liter',
    'full_tank',
    'station',
    'note',
    'created_at',
    'updated_at',
  ];

  static FuelLogEntity fromMap(Map<String, dynamic> m) => FuelLogEntity(
        id: m['id'] as String,
        bikeId: m['bike_id'] as String,
        filledAt: DateTime.parse(m['filled_at'] as String),
        odometerKm: (m['odometer_km'] as num).toDouble(),
        liters: (m['liters'] as num).toDouble(),
        totalCost: (m['total_cost'] as num).toDouble(),
        pricePerLiter: (m['price_per_liter'] as num).toDouble(),
        fullTank: _bool(m['full_tank'], fallback: true),
        station: _blankToNull(m['station'] as String?),
        note: _blankToNull(m['note'] as String?),
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt:
            DateTime.parse((m['updated_at'] ?? m['created_at']) as String),
      );

  /// A local row. `synced` starts at 0: every write is a pending upload.
  static Map<String, dynamic> toMap(FuelLogEntity e) => {
        'id': e.id,
        'bike_id': e.bikeId,
        'filled_at': e.filledAt.toIso8601String(),
        'odometer_km': e.odometerKm,
        'liters': e.liters,
        'total_cost': e.totalCost,
        'price_per_liter': e.pricePerLiter,
        'full_tank': e.fullTank ? 1 : 0,
        'station': _blankToNull(e.station),
        'note': _blankToNull(e.note),
        'created_at': e.createdAt.toIso8601String(),
        'updated_at': e.updatedAt.toIso8601String(),
        'synced': 0,
      };

  /// The Firestore document for a local row (without `syncedAt`, which the
  /// writer adds as a server timestamp). Unknown local columns are dropped,
  /// so a newer schema's extra column can't get a write rejected by rules.
  static Map<String, dynamic> toCloudPayload(Map<String, dynamic> row) => {
        for (final k in cloudKeys)
          if (k == 'full_tank')
            k: _bool(row[k], fallback: true)
          else if (row[k] != null)
            k: row[k],
      };

  /// A downloaded document as a local row, marked synced. Null when it is
  /// missing something a row can't do without.
  static Map<String, dynamic>? fromCloud(Map<String, dynamic> doc) {
    for (final k in const [
      'id',
      'bike_id',
      'filled_at',
      'odometer_km',
      'liters',
      'total_cost',
      'price_per_liter',
      'created_at',
    ]) {
      if (doc[k] == null) return null;
    }
    return {
      for (final k in cloudKeys)
        if (k == 'full_tank')
          k: _bool(doc[k], fallback: true) ? 1 : 0
        else if (k == 'updated_at')
          k: doc[k] ?? doc['created_at']
        else
          k: doc[k],
      'synced': 1,
    };
  }

  static bool _bool(Object? v, {required bool fallback}) => switch (v) {
        bool b => b,
        num n => n != 0,
        _ => fallback,
      };

  static String? _blankToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}
