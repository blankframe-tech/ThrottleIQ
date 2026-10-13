import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

/// Cloud backup of a bike's maintenance settings (issues §88.2): the checks
/// it tracks (`bike_maintenance_configs`: intervals, enabled, notes, typical
/// cost, baselines, custom checks), its fuel price & mileage
/// (`bike_running_costs`), and since v20 its setup profile
/// (`bike_maintenance_profiles`) and paperwork expiries (`bike_paperwork`).
/// Before this, all of it lived only in SQLite and was lost on reinstall or
/// a new device.
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
    'interval_days',
    'warn_km',
    'warn_days',
    'baseline_km',
    'baseline_date',
    'source',
    'custom_label',
  ];

  static const _profileColumns = [
    'template_id',
    'riding_profile',
    'oil_grade',
    'adapt_intervals',
    'onboarded_at',
    'last_precheck_at',
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
    final profile = await db.query(
      'bike_maintenance_profiles',
      where: 'bike_id = ?',
      whereArgs: [bikeId],
      limit: 1,
    );
    final paperwork = await db.query(
      'bike_paperwork',
      where: 'bike_id = ?',
      whereArgs: [bikeId],
      orderBy: 'kind',
    );
    if (configs.isEmpty &&
        running.isEmpty &&
        profile.isEmpty &&
        paperwork.isEmpty) {
      return null;
    }

    return {
      'bikeId': bikeId,
      // A placeholder profile (created by adding paperwork or a quick check
      // before setup) is not sent: on a fresh device it could otherwise
      // replace the real, set-up profile in the cloud before it's restored.
      if (profile.isNotEmpty && profile.first['onboarded_at'] != null)
        'profile': {for (final c in _profileColumns) c: profile.first[c]},
      // Unlike the tables above, paperwork is sent even when it shrinks to
      // empty once it exists: a removed document must stay removed. (Sent
      // only when the bike has a profile or other settings, so a device that
      // hasn't restored yet can't wipe the cloud copy.)
      if (paperwork.isNotEmpty || profile.isNotEmpty)
        'paperwork': [
          for (final row in paperwork)
            {
              'kind': row['kind'],
              'expires_on': row['expires_on'],
              'notes': row['notes'],
            },
        ],
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
  /// i.e. the ones a cloud copy could fill in. A missing setup profile alone
  /// doesn't count: a reinstall empties every table at once, and the profile
  /// (with its paperwork) is restored in the same [applyDownloaded] pass —
  /// counting it would cost a cloud read per never-set-up bike per session. Pure SQLite, so the sync
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
                        WHERE r.bike_id = b.id)
             OR EXISTS (SELECT 1 FROM bike_maintenance_profiles p
                        WHERE p.bike_id = b.id))
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

      final profile = data['profile'];
      if (profile is Map && profile['template_id'] is String) {
        final local = (await txn.query('bike_maintenance_profiles',
                columns: ['onboarded_at'],
                where: 'bike_id = ?',
                whereArgs: [bikeId],
                limit: 1))
            .firstOrNull;
        // Fill a missing profile, or replace a local placeholder (never set
        // up) with a cloud profile that was.
        final replace = local == null ||
            (local['onboarded_at'] == null && profile['onboarded_at'] != null);
        if (replace) {
          await txn.insert(
            'bike_maintenance_profiles',
            {
              'bike_id': bikeId,
              for (final c in _profileColumns)
                if (profile[c] != null) c: profile[c],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          wrote = true;
        }
      }

      // Paperwork merges by kind: anything the cloud has that this device
      // lacks is added; a local row is never overwritten.
      final papers = data['paperwork'];
      if (papers is List) {
        for (final raw in papers) {
          if (raw is! Map) continue;
          final kind = raw['kind'];
          final expires = raw['expires_on'];
          if (kind is! String || expires is! String) continue;
          final id = await txn.insert(
            'bike_paperwork',
            {
              'bike_id': bikeId,
              'kind': kind,
              'expires_on': expires,
              'notes': raw['notes'] is String ? raw['notes'] : null,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          if (id > 0) wrote = true;
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
    // 0 is a time-only check (e.g. a battery tracked by date alone).
    if (interval is! num || interval < 0) return null;
    final enabled = raw['is_enabled'];
    final notes = raw['notes'];
    num? optNum(String k) => raw[k] is num ? raw[k] as num : null;
    String? optStr(String k) =>
        raw[k] is String && (raw[k] as String).isNotEmpty ? raw[k] as String : null;
    return {
      'bike_id': bikeId,
      'service_type': serviceType,
      'interval_km': interval.toDouble(),
      'is_enabled': (enabled == 1 || enabled == true) ? 1 : 0,
      'notes': notes is String && notes.trim().isNotEmpty ? notes : null,
      'typical_cost': _positiveOrNull(raw['typical_cost']),
      'interval_days': optNum('interval_days')?.toInt(),
      'warn_km': optNum('warn_km')?.toDouble(),
      'warn_days': optNum('warn_days')?.toInt(),
      'baseline_km': optNum('baseline_km')?.toDouble(),
      'baseline_date': optStr('baseline_date'),
      // Docs backed up before v20 carry no source: those intervals were set
      // by the rider, same as the v20 migration assumes.
      'source': optStr('source') ?? 'user',
      'custom_label': optStr('custom_label'),
    };
  }

  static double? _positiveOrNull(Object? v) =>
      (v is num && v > 0) ? v.toDouble() : null;
}
