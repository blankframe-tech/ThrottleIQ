import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

/// Cloud backup of a bike's maintenance settings (issues §88.2): the checks
/// it tracks (`bike_maintenance_configs`: interval, enabled, notes, typical
/// cost) and its fuel price & mileage (`bike_running_costs`). Before this,
/// both lived only in SQLite and were lost on reinstall or a new device.
///
/// **Where:** one document per bike at
/// `users/{uid}/private/maintenanceSettings_{bikeId}`. Deliberately NOT on
/// `users/{uid}/bikes/{bikeId}` — that doc is readable by followers
/// (`bikesVisibleTo` in firestore.rules), and what a rider pays for fuel and
/// servicing is theirs alone. `private/{docId}` is already owner-only
/// read/write, so this needed no rules change. Not under `maintenance/`
/// either: every doc there is treated as a log by
/// `CloudRepository.downloadMaintenance`.
///
/// **Upload** goes through the outbox (`OutboxKind.maintenanceSettings`),
/// queued on every local save; the delivery reads SQLite at delivery time, so
/// a queue of edits collapses into one write of the latest state.
///
/// **Download** only fills what is missing locally, per table, and never
/// overwrites a local row — same rule as bikes and maintenance logs.
class MaintenanceSettingsSync {
  MaintenanceSettingsSync._();

  static const String collection = 'private';
  static const String _docPrefix = 'maintenanceSettings_';

  static String docId(String bikeId) => '$_docPrefix$bikeId';

  static DocumentReference<Map<String, dynamic>> docRef(
    FirebaseFirestore firestore,
    String uid,
    String bikeId,
  ) =>
      firestore
          .collection('users')
          .doc(uid)
          .collection(collection)
          .doc(docId(bikeId));

  /// Columns copied per config row. `bike_id` is implied by the doc.
  static const _configColumns = [
    'service_type',
    'interval_km',
    'is_enabled',
    'notes',
    'typical_cost',
  ];

  /// The Firestore fields for [bikeId]'s current local settings, or null if
  /// the bike has none (nothing worth writing).
  ///
  /// A table with no local rows is left OUT of the result rather than sent
  /// as empty. The doc is written with `merge: true`, so on a fresh device
  /// where the rider edits one setting before the restore has run, the
  /// other table's cloud copy isn't wiped by an absence that only means
  /// "not downloaded yet".
  static Future<Map<String, dynamic>?> buildPayload(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    final configs = await db.query(
      'bike_maintenance_configs',
      where: 'bike_id = ?',
      whereArgs: [bikeId],
      orderBy: 'service_type',
    );
    final running = await db.query(
      'bike_running_costs',
      where: 'bike_id = ?',
      whereArgs: [bikeId],
      limit: 1,
    );
    if (configs.isEmpty && running.isEmpty) return null;

    return {
      'bikeId': bikeId,
      if (configs.isNotEmpty)
        'configs': [
          for (final row in configs)
            {for (final c in _configColumns) c: row[c]},
        ],
      if (running.isNotEmpty)
        'runningCost': {
          'fuel_price_per_litre': running.first['fuel_price_per_litre'],
          'km_per_litre': running.first['km_per_litre'],
        },
    };
  }

  /// Owned bikes that have no config rows or no running-cost row locally,
  /// i.e. the ones a cloud copy could fill in. Pure SQLite, so the sync
  /// cycle can skip the network entirely when there is nothing to restore.
  static Future<List<String>> bikesMissingSettings(String uid) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT b.id FROM bikes b
      WHERE b.user_id = ?
        AND (NOT EXISTS (SELECT 1 FROM bike_maintenance_configs c
                         WHERE c.bike_id = b.id)
             OR NOT EXISTS (SELECT 1 FROM bike_running_costs r
                            WHERE r.bike_id = b.id))
    ''', [uid]);
    return rows.map((r) => r['id'] as String).toList();
  }

  /// Owned bikes with any local settings — the one-time backfill for
  /// settings saved before this sync existed.
  static Future<List<String>> bikesWithSettings(String uid) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT b.id FROM bikes b
      WHERE b.user_id = ?
        AND (EXISTS (SELECT 1 FROM bike_maintenance_configs c
                     WHERE c.bike_id = b.id)
             OR EXISTS (SELECT 1 FROM bike_running_costs r
                        WHERE r.bike_id = b.id))
    ''', [uid]);
    return rows.map((r) => r['id'] as String).toList();
  }

  /// Writes a downloaded doc into SQLite for [bikeId], filling only the
  /// tables that have no local rows. Returns true if anything was written.
  ///
  /// Malformed entries are skipped individually; one bad config row must
  /// not cost the rider the rest of them.
  static Future<bool> applyDownloaded(
    String bikeId,
    Map<String, dynamic> data,
  ) async {
    final db = await DatabaseHelper.instance.database;
    var wrote = false;

    await db.transaction((txn) async {
      final bikeExists = (await txn.query('bikes',
              columns: ['id'],
              where: 'id = ?',
              whereArgs: [bikeId],
              limit: 1))
          .isNotEmpty;
      if (!bikeExists) return;

      final rawConfigs = data['configs'];
      if (rawConfigs is List && rawConfigs.isNotEmpty) {
        final hasLocal = (await txn.query('bike_maintenance_configs',
                columns: ['bike_id'],
                where: 'bike_id = ?',
                whereArgs: [bikeId],
                limit: 1))
            .isNotEmpty;
        if (!hasLocal) {
          for (final raw in rawConfigs) {
            final row = _configRow(bikeId, raw);
            if (row == null) continue;
            await txn.insert('bike_maintenance_configs', row,
                conflictAlgorithm: ConflictAlgorithm.replace);
            wrote = true;
          }
        }
      }

      final running = data['runningCost'];
      if (running is Map) {
        final hasLocal = (await txn.query('bike_running_costs',
                columns: ['bike_id'],
                where: 'bike_id = ?',
                whereArgs: [bikeId],
                limit: 1))
            .isNotEmpty;
        if (!hasLocal) {
          await txn.insert(
            'bike_running_costs',
            {
              'bike_id': bikeId,
              'fuel_price_per_litre': _positiveOrNull(
                  running['fuel_price_per_litre']),
              'km_per_litre': _positiveOrNull(running['km_per_litre']),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          wrote = true;
        }
      }
    });
    return wrote;
  }

  static Map<String, dynamic>? _configRow(String bikeId, Object? raw) {
    if (raw is! Map) return null;
    final serviceType = raw['service_type'];
    final interval = raw['interval_km'];
    if (serviceType is! String || serviceType.isEmpty) return null;
    if (interval is! num || interval <= 0) return null;
    final enabled = raw['is_enabled'];
    final notes = raw['notes'];
    return {
      'bike_id': bikeId,
      'service_type': serviceType,
      'interval_km': interval.toDouble(),
      'is_enabled': (enabled == 1 || enabled == true) ? 1 : 0,
      'notes': notes is String && notes.trim().isNotEmpty ? notes : null,
      'typical_cost': _positiveOrNull(raw['typical_cost']),
    };
  }

  static double? _positiveOrNull(Object? v) =>
      (v is num && v > 0) ? v.toDouble() : null;
}
