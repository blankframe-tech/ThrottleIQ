import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  /// Points the singleton at a caller-supplied database, for tests.
  ///
  /// Exists so the DAOs can be exercised against a real in-memory SQLite
  /// (via `sqflite_common_ffi`) instead of being mocked. That matters:
  /// BikeDao.delete once deadlocked by calling another DAO from inside its
  /// own transaction, and no amount of mocking would have caught it — only
  /// running the real statements against a real connection does.
  @visibleForTesting
  static void overrideDatabaseForTesting(Database? db) {
    _db = db;
  }

  /// Builds the full schema on an already-open database. Used by
  /// [overrideDatabaseForTesting] callers so a test DB matches production.
  @visibleForTesting
  Future<void> createSchemaForTesting(Database db) =>
      _onCreate(db, schemaVersion);

  /// Runs the real migration ladder against an already-open database.
  ///
  /// Exists so an upgrade can be tested on the path an existing install
  /// actually takes. [createSchemaForTesting] goes through `_onCreate`, which
  /// builds the current schema directly and therefore proves nothing about
  /// whether a rider on the previous version can still open their database —
  /// the failure mode that matters, because it bricks the app for exactly the
  /// people who already have rides stored.
  @visibleForTesting
  Future<void> upgradeSchemaForTesting(Database db, int from, int to) =>
      _onUpgrade(db, from, to);

  /// Substrings SQLite actually uses for a file that is unopenable/unreadable
  /// as a database, as opposed to a transient failure (disk full, file
  /// locked by another process, a momentary I/O error) that happens to throw
  /// from the same call. issues §33.9: the previous catch treated ANY
  /// exception here as the one documented corruption case it was written
  /// for, and deleted the whole database — turning a transient error into
  /// permanent data loss of every local ride/bike/maintenance record.
  static const _corruptionMarkers = [
    'file is not a database',
    'file is encrypted or is not a database',
    'database disk image is malformed',
    'database corrupt',
  ];

  /// Current schema version. One constant so the production open and the
  /// test schema builder can't drift apart when the next migration lands —
  /// bump this together with a new `if (oldVersion < N)` step in [_onUpgrade].
  static const int schemaVersion = 25;

  bool _looksCorrupt(Object error) {
    final message = error.toString().toLowerCase();
    return _corruptionMarkers.any((marker) => message.contains(marker));
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'throttleiq.db');
    try {
      return await _openDb(path);
    } catch (e) {
      if (!_looksCorrupt(e)) rethrow;
      // Rename rather than delete — docs §69.O11: a straight
      // `deleteDatabase` silently threw away every unsynced ride the rider
      // had on disk. Renaming aside lets the app rebuild a fresh (empty) db
      // and keep running, while leaving the corrupt file recoverable by hand
      // instead of gone the moment corruption is detected.
      final corruptFile = File(path);
      if (await corruptFile.exists()) {
        await corruptFile.rename(
          '$path.corrupt-${DateTime.now().millisecondsSinceEpoch}',
        );
      } else {
        await deleteDatabase(path);
      }
      return _openDb(path);
    }
  }

  Future<Database> _openDb(String path) {
    return openDatabase(
      path,
      version: schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// `ALTER TABLE ADD COLUMN` has no `IF NOT EXISTS`, unlike this ladder's
  /// `CREATE TABLE` steps — so a column addition needs its own guard to keep
  /// the "a re-run is survivable" invariant the rest of `_onUpgrade` relies on.
  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String columnDef) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'ride_points', 'period_type',
          'period_type TEXT DEFAULT "moving"');
      await _addColumnIfMissing(
          db, 'ride_points', 'accuracy_m', 'accuracy_m REAL');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bikes_user_id ON bikes(user_id)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_rides_user_id_status ON rides(user_id, status)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_rides_bike_id_status ON rides(bike_id, status)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_ride_points_ride_timestamp ON ride_points(ride_id, timestamp)
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS maintenance_logs (
          id TEXT PRIMARY KEY,
          bike_id TEXT NOT NULL,
          service_type TEXT NOT NULL,
          date TEXT NOT NULL,
          odometer_km REAL NOT NULL,
          cost REAL,
          notes TEXT,
          synced INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_maintenance_bike_id ON maintenance_logs(bike_id)
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profiles (
          uid TEXT PRIMARY KEY,
          display_name TEXT NOT NULL,
          photo_url TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'bikes', 'odometer_km', 'odometer_km REAL');
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(
          db, 'ride_points', 'heading_deg', 'heading_deg REAL');
      await _addColumnIfMissing(
          db, 'ride_points', 'confidence', 'confidence INTEGER');
      await _addColumnIfMissing(
          db, 'ride_points', 'imu_quality', 'imu_quality INTEGER');
      await _addColumnIfMissing(
          db, 'ride_points', 'is_cornering', 'is_cornering INTEGER');
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(
          db, 'maintenance_logs', 'custom_label', 'custom_label TEXT');
    }
    if (oldVersion < 8) {
      await db.execute(_createDeletedBikesSql);
    }
    if (oldVersion < 9) {
      // Seconds spent above the moving threshold, mirroring the in-memory
      // total `stopRide()` already tracks for the average-speed calculation
      // (see average_speed.dart). Persisting it is what lets jam time
      // (ride clock minus this) survive past the recording session — see
      // jam_time.dart. Existing rides finalized before this column existed
      // simply have no jam figure to show, rather than a guessed-at one.
      await _addColumnIfMissing(db, 'rides', 'moving_s', 'moving_s INTEGER');
    }
    if (oldVersion < 10) {
      await db.execute(_createOutboxSql);
      await db.execute(_createOutboxIndexSql);
    }
    if (oldVersion < 11) {
      // Auto-tracking. Existing rides were all started by the rider, so the
      // defaults below are the truthful reading of a pre-v11 row rather than
      // a placeholder: is_auto = 0, bike_confidence = 'high'.
      await _addColumnIfMissing(
          db, 'rides', 'is_auto', 'is_auto INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'rides', 'bike_confidence',
          "bike_confidence TEXT NOT NULL DEFAULT 'high'");
      await db.execute(_createAutoDetectionsSql);
      await db.execute(_createAutoFixesSql);
      await db.execute(_createAutoFixesIndexSql);
      await db.execute(_createAutoDetectionsIndexSql);
    }
    if (oldVersion < 12) {
      // The bike's own paint color, so screens can tint themselves to it
      // (see RecordScreen) instead of everything reading the app's neutral
      // accent regardless of which bike is active.
      await _addColumnIfMissing(
          db, 'bikes', 'color_value', 'color_value INTEGER');
    }
    if (oldVersion < 13) {
      // Per-bike maintenance tracking configurations and customizable intervals.
      await db.execute(_createBikeMaintenanceConfigsSql);
      await db.execute(_createBikeMaintenanceConfigsIndexSql);
    }
    if (oldVersion < 14) {
      // Extra info / notes on bike maintenance configs (e.g. oil brand, tyre dates/sizes).
      await _addColumnIfMissing(
          db, 'bike_maintenance_configs', 'notes', 'notes TEXT');
    }
    // Also gated on newVersion so upgradeSchemaForTesting(db, from, to)
    // stops at `to`: the v13/v14 migration tests build only the tables those
    // steps touch and would otherwise hit this step's `rides` ALTER. In
    // production newVersion is always schemaVersion, so this changes nothing.
    if (oldVersion < 15 && newVersion >= 15) {
      // Whether a ride's GPS trail (not just its metadata row) has reached
      // Firestore. `synced` alone flipped to 1 before the trail upload was
      // attempted, so a failed trail upload was never retried — the ride
      // looked backed up while its points existed only on this phone.
      //
      // Every existing row starts at 0, synced or not: a ride already marked
      // synced may be one whose trail upload failed, and there is no record
      // of which. Re-uploading once is safe because track chunks are keyed
      // by index and written with `set` (see CloudRepository.uploadRideTrack).
      await _addColumnIfMissing(db, 'rides', 'track_synced',
          'track_synced INTEGER NOT NULL DEFAULT 0');
      // Archiving hides a bike from the garage and pickers while keeping its
      // rides — the alternative used to be deleting the bike, which deleted
      // its whole ride history with it.
      await _addColumnIfMissing(
          db, 'bikes', 'archived', 'archived INTEGER NOT NULL DEFAULT 0');
      // The rider an auto-detection belongs to, stamped by the background
      // isolate. Without it the reconciler handed every pending detection to
      // whoever happened to be signed in. Existing rows stay NULL — nothing
      // on disk says whose they were; see AutoDetectionDao.pendingDetections
      // for how those are handled.
      await _addColumnIfMissing(
          db, 'auto_detections', 'user_id', 'user_id TEXT');
    }
    if (oldVersion < 16 && newVersion >= 16) {
      // Outbox dead-letter state (§69.O4). Every step from v10 on runs
      // against an install that already has `outbox`, but the create is
      // IF NOT EXISTS and cheap, and keeps a partial test schema (or a
      // re-run) from failing the ALTERs below on a missing table.
      await db.execute(_createOutboxSql);
      await _addColumnIfMissing(
          db, 'outbox', 'status', "status TEXT NOT NULL DEFAULT 'pending'");
      await _addColumnIfMissing(db, 'outbox', 'permanent_failures',
          'permanent_failures INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 17 && newVersion >= 17) {
      // The saved route a ride was recorded against (issues §78.21). Both
      // stay NULL on existing rows, which is correct rather than a
      // placeholder: before this, following a route recorded no ride at all.
      //
      // The name is denormalized next to the id on purpose — see
      // RideEntity.routeId for why history can't just look it up.
      await _addColumnIfMissing(db, 'rides', 'route_id', 'route_id TEXT');
      await _addColumnIfMissing(db, 'rides', 'route_name', 'route_name TEXT');
    }
    if (oldVersion < 18 && newVersion >= 18) {
      // Per-ride running cost (maintenance settings → Running costs). A
      // rider-set typical price per service on each tracked check, plus the
      // bike's fuel price & mileage. All NULL on existing rows: "not set",
      // which the ride-cost calculator treats as "leave this item out".
      await db.execute(_createBikeMaintenanceConfigsSql);
      await _addColumnIfMissing(
          db, 'bike_maintenance_configs', 'typical_cost', 'typical_cost REAL');
      await db.execute(_createBikeRunningCostsSql);
    }
    if (oldVersion < 19 && newVersion >= 19) {
      // §90.C6: marks the first fix persisted after a resume, so rebuilding
      // a killed ride's distance skips the pause gap (a paused bike put in a
      // van must not have the van journey counted on restore). 0 on every
      // existing row — no marker was ever recorded, which is the old
      // behaviour.
      await db.execute(_createRidePointsIfMissingSql);
      await _addColumnIfMissing(db, 'ride_points', 'segment_start',
          'segment_start INTEGER NOT NULL DEFAULT 0');
      // §90.C10: ride tombstones, same idea as `deleted_bikes`.
      await db.execute(_createDeletedRidesSql);
    }
    if (oldVersion < 20 && newVersion >= 20) {
      await _migrateMaintenanceV20(db);
    }
    if (oldVersion < 21 && newVersion >= 21) {
      // Places hub bookmarks (Saved tab). A brand-new table, so nothing to
      // backfill: every install simply starts with no saved places.
      await db.execute(_createSavedPlacesSql);
    }
    if (oldVersion < 22 && newVersion >= 22) {
      // Free up disk space from raw fixes of older summarized detections.
      // 0 means fixes are present. 1 means fixes were purged.
      await _addColumnIfMissing(db, 'auto_detections', 'fixes_purged',
          'fixes_purged INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 23 && newVersion >= 23) {
      // E-bike toggle and connection feature.
      await _addColumnIfMissing(
          db, 'bikes', 'is_ebike', 'is_ebike INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 24 && newVersion >= 24) {
      // When a bike was archived. Archived bikes are permanently deleted three
      // months after this (BikeArchiveService.purgeExpired). Bikes archived
      // before this column existed start their clock at the upgrade.
      await _addColumnIfMissing(db, 'bikes', 'archived_at', 'archived_at TEXT');
      await db.update(
          'bikes', {'archived_at': DateTime.now().toIso8601String()},
          where: 'archived = 1 AND archived_at IS NULL');
    }
    if (oldVersion < 25 && newVersion >= 25) {
      // Per-ride overspeed episodes. Nullable with no default on purpose:
      // existing rides were never counted, and NULL ("unknown") keeps them
      // out of the overspeed chart instead of reading as a clean 0.
      await _addColumnIfMissing(
          db, 'rides', 'overspeed_count', 'overspeed_count INTEGER');
    }
  }

  /// Places a rider bookmarked from the Places hub (schema v21).
  ///
  /// A snapshot of the place, not just its id, so the Saved tab still lists
  /// names, coordinates and phone numbers with no signal — the moment a
  /// rider most needs "that garage I saved" is out on a highway with one bar.
  /// Keyed per rider so a shared phone keeps each account's list apart, and
  /// [deleteUserData] can scope its wipe. `tags` is comma-separated
  /// [PlaceTag] names.
  static const String _createSavedPlacesSql = '''
    CREATE TABLE IF NOT EXISTS saved_places (
      user_id TEXT NOT NULL,
      place_id TEXT NOT NULL,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      address TEXT NOT NULL DEFAULT '',
      phone TEXT,
      hours TEXT,
      tags TEXT,
      verified INTEGER NOT NULL DEFAULT 0,
      saved_at TEXT NOT NULL,
      PRIMARY KEY (user_id, place_id)
    )
  ''';

  /// v20 — the maintenance redesign (issues §95): service visits, km-or-time
  /// intervals, baselines, setup profiles, paperwork, quick-check issues,
  /// log tombstones and detected-trip odometer credits.
  Future<void> _migrateMaintenanceV20(Database db) async {
    // A partial test schema (or a re-run) may lack these; real installs
    // reaching v20 have both.
    await db.execute(_createMaintenanceLogsIfMissingSql);
    await db.execute(_createBikeMaintenanceConfigsSql);

    // One visit = every item logged together. NULL on existing rows: each
    // older log is a visit of one (see ServiceVisit).
    for (final col in const [
      ['visit_id', 'visit_id TEXT'],
      ['check_key', 'check_key TEXT'],
      ['shop_name', 'shop_name TEXT'],
      ['shop_kind', 'shop_kind TEXT'],
      ['receipt_path', 'receipt_path TEXT'],
      ['visit_total', 'visit_total REAL'],
      ['visit_label', 'visit_label TEXT'],
      ['part_brand', 'part_brand TEXT'],
      ['part_grade', 'part_grade TEXT'],
    ]) {
      await _addColumnIfMissing(db, 'maintenance_logs', col[0], col[1]);
    }

    for (final col in const [
      ['interval_days', 'interval_days INTEGER'],
      ['warn_km', 'warn_km REAL'],
      ['warn_days', 'warn_days INTEGER'],
      ['baseline_km', 'baseline_km REAL'],
      ['baseline_date', 'baseline_date TEXT'],
      ['source', "source TEXT NOT NULL DEFAULT 'template'"],
      ['custom_label', 'custom_label TEXT'],
    ]) {
      await _addColumnIfMissing(db, 'bike_maintenance_configs', col[0], col[1]);
    }
    // Existing checks were configured before templates existed, possibly by
    // hand, so they're marked the rider's own: picking a template or oil
    // grade later never silently overwrites them. They do gain the time
    // limit their type defaults to — km-only was the gap being fixed.
    await db.execute("UPDATE bike_maintenance_configs SET source = 'user' "
        "WHERE interval_days IS NULL");
    await db.execute('''
      UPDATE bike_maintenance_configs SET interval_days = CASE service_type
        $_defaultIntervalDaysSqlCases
        ELSE NULL END
      WHERE interval_days IS NULL
    ''');

    await db.execute(_createDeletedMaintenanceLogsSql);
    await db.execute(_createMaintenanceProfilesSql);
    await db.execute(_createBikePaperworkSql);
    await db.execute(_createPrecheckIssuesSql);
    await db.execute(_createDetectionOdometerCreditsSql);
  }

  /// `WHEN 'oilChange' THEN 180 …` for every type with a default time limit
  /// (mirrors `ServiceTypeExt.defaultIntervalDays`).
  static const String _defaultIntervalDaysSqlCases = '''
        WHEN 'oilChange' THEN 180
        WHEN 'oilFilter' THEN 365
        WHEN 'chain' THEN 30
        WHEN 'chainTension' THEN 60
        WHEN 'tire' THEN 30
        WHEN 'clutchCable' THEN 180
        WHEN 'throttleCables' THEN 365
        WHEN 'battery' THEN 365
        WHEN 'airFilter' THEN 365
        WHEN 'sparkPlug' THEN 730
        WHEN 'forkSeals' THEN 730
        WHEN 'radiatorCoolant' THEN 730
        WHEN 'brakeFluid' THEN 730''';

  static const String _createMaintenanceLogsIfMissingSql = '''
    CREATE TABLE IF NOT EXISTS maintenance_logs (
      id TEXT PRIMARY KEY,
      bike_id TEXT NOT NULL,
      service_type TEXT NOT NULL,
      date TEXT NOT NULL,
      odometer_km REAL NOT NULL,
      cost REAL,
      notes TEXT,
      custom_label TEXT,
      synced INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
  ''';

  /// Maintenance logs deleted on this device (§94.2). Same lifecycle as
  /// `deleted_rides`: `synced = 0` until the Firestore copy is gone, kept
  /// afterwards so another device's copy can't bring it back.
  static const String _createDeletedMaintenanceLogsSql = '''
    CREATE TABLE IF NOT EXISTS deleted_maintenance_logs (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      deleted_at TEXT NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''';

  /// Per-bike maintenance setup — see MaintenanceProfileEntity.
  static const String _createMaintenanceProfilesSql = '''
    CREATE TABLE IF NOT EXISTS bike_maintenance_profiles (
      bike_id TEXT PRIMARY KEY,
      template_id TEXT NOT NULL,
      riding_profile TEXT NOT NULL DEFAULT 'normal',
      oil_grade TEXT,
      adapt_intervals INTEGER NOT NULL DEFAULT 1,
      onboarded_at TEXT,
      last_precheck_at TEXT,
      FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
    )
  ''';

  static const String _createBikePaperworkSql = '''
    CREATE TABLE IF NOT EXISTS bike_paperwork (
      bike_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      expires_on TEXT NOT NULL,
      notes TEXT,
      PRIMARY KEY (bike_id, kind),
      FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
    )
  ''';

  /// Failed T-CLOCS quick-check tiles. Local only: they're short-lived
  /// "fix this before riding" notes, not records.
  static const String _createPrecheckIssuesSql = '''
    CREATE TABLE IF NOT EXISTS precheck_issues (
      id TEXT PRIMARY KEY,
      bike_id TEXT NOT NULL,
      item TEXT NOT NULL,
      created_at TEXT NOT NULL,
      resolved_at TEXT,
      FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
    )
  ''';

  /// Distance from background-detected trips credited to a bike's odometer
  /// (issues §93.1). One row per detection, so a credit can never be applied
  /// twice; the bike's `odometer_km` holds the running total.
  static const String _createDetectionOdometerCreditsSql = '''
    CREATE TABLE IF NOT EXISTS detection_odometer_credits (
      detection_id TEXT PRIMARY KEY,
      bike_id TEXT NOT NULL,
      distance_m REAL NOT NULL,
      credited_at TEXT NOT NULL,
      trip_end TEXT,
      FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
    )
  ''';

  /// Only for the v19 step's benefit on a partial test schema (or a re-run):
  /// every real install reaching v19 already has `ride_points`.
  static const String _createRidePointsIfMissingSql = '''
    CREATE TABLE IF NOT EXISTS ride_points (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ride_id TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      speed_ms REAL NOT NULL,
      acceleration REAL,
      jerk REAL,
      altitude_m REAL,
      period_type TEXT NOT NULL DEFAULT 'moving',
      accuracy_m REAL,
      heading_deg REAL,
      confidence INTEGER,
      imu_quality INTEGER,
      is_cornering INTEGER,
      FOREIGN KEY(ride_id) REFERENCES rides(id)
    )
  ''';

  /// Tombstones for rides deleted on this device (§90.C10).
  ///
  /// A ride can reach Firestore before the rider throws it away — a crash
  /// ride is uploaded the moment crash detection fires, and is then
  /// discarded with "Discard ride" if it was a false alarm. Deleting only
  /// locally let [CloudRepository.downloadRides] pull it straight back. Same
  /// shape and lifecycle as `deleted_bikes`: `synced = 0` until the remote
  /// copy is gone, row kept afterwards. Unlike `deleted_bikes` it records
  /// its owner, so account deletion can scope it.
  static const String _createDeletedRidesSql = '''
    CREATE TABLE IF NOT EXISTS deleted_rides (
      id TEXT PRIMARY KEY,
      user_id TEXT,
      deleted_at TEXT NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const String _createBikeMaintenanceConfigsSql = '''
    CREATE TABLE IF NOT EXISTS bike_maintenance_configs (
      bike_id TEXT NOT NULL,
      service_type TEXT NOT NULL,
      interval_km REAL NOT NULL,
      is_enabled INTEGER NOT NULL DEFAULT 1,
      notes TEXT,
      typical_cost REAL,
      interval_days INTEGER,
      warn_km REAL,
      warn_days INTEGER,
      baseline_km REAL,
      baseline_date TEXT,
      source TEXT NOT NULL DEFAULT 'template',
      custom_label TEXT,
      PRIMARY KEY (bike_id, service_type),
      FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
    )
  ''';

  /// One row per bike: what its fuel costs and how far it goes on a litre.
  /// Canonical metric regardless of the unit the rider entered it in.
  static const String _createBikeRunningCostsSql = '''
    CREATE TABLE IF NOT EXISTS bike_running_costs (
      bike_id TEXT PRIMARY KEY,
      fuel_price_per_litre REAL,
      km_per_litre REAL,
      FOREIGN KEY(bike_id) REFERENCES bikes(id) ON DELETE CASCADE
    )
  ''';

  static const String _createBikeMaintenanceConfigsIndexSql = '''
    CREATE INDEX IF NOT EXISTS idx_bike_maintenance_configs_bike_id
      ON bike_maintenance_configs(bike_id)
  ''';

  /// One detected journey, from the moment the platform said "this device
  /// started moving in a vehicle" to the moment it said it stopped.
  ///
  /// Written by the **background isolate**, which has no access to the app's
  /// Riverpod container and therefore cannot go through `RideRecordingNotifier`
  /// — see `AutoTrackingService`. It deliberately records nothing derived:
  /// no distance, no average speed, no events. All of that is computed later
  /// by `AutoRideReconciler` on the UI isolate, by replaying [auto_fixes]
  /// through the same calculators the live path uses. Two code paths producing
  /// ride statistics by different routes is exactly the bug this avoids.
  ///
  /// `status` is the reconciliation state machine:
  ///   recording   — the isolate is still appending fixes
  ///   pending     — movement ended; waiting for the app to open and rebuild it
  ///   reconciled  — became `ride_id`; fixes can be pruned
  ///   discarded   — too short/slow to be a ride, or the rider said it wasn't
  ///
  /// `user_id` (v15) is the rider signed in when the background isolate
  /// opened the row; NULL on rows written before v15 — see
  /// `AutoDetectionDao.pendingDetections`.
  ///
  /// `trigger_source` records what woke us (activity recognition vs
  /// significant location change vs a paired device). Kept because the whole
  /// point of the first release is measuring which triggers produce real rides
  /// and which produce bus journeys.
  static const String _createAutoDetectionsSql = '''
    CREATE TABLE IF NOT EXISTS auto_detections (
      id TEXT PRIMARY KEY,
      started_at TEXT NOT NULL,
      ended_at TEXT,
      trigger_source TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'recording',
      ride_id TEXT,
      discard_reason TEXT,
      created_at TEXT NOT NULL,
      user_id TEXT,
      fixes_purged INTEGER NOT NULL DEFAULT 0
    )
  ''';

  /// Raw fixes captured by the background isolate for an [auto_detections] row.
  ///
  /// Intentionally a separate table from `ride_points` rather than writing
  /// straight into it: a detection is not yet a ride. Until the rider confirms
  /// (or the reconciler's own thresholds accept it) these must not appear in
  /// history, count toward a bike's odometer, or sync to Firestore. Promotion
  /// happens in one place, transactionally.
  ///
  /// Columns mirror what `_onPosition` reads off a `Position`, so the replay
  /// can reconstruct the identical calculator inputs.
  static const String _createAutoFixesSql = '''
    CREATE TABLE IF NOT EXISTS auto_fixes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      detection_id TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      lat REAL NOT NULL,
      lng REAL NOT NULL,
      speed_ms REAL NOT NULL,
      accuracy_m REAL,
      altitude_m REAL,
      heading_deg REAL,
      FOREIGN KEY(detection_id) REFERENCES auto_detections(id) ON DELETE CASCADE
    )
  ''';

  /// The replay's only query shape: every fix for one detection, in order.
  static const String _createAutoFixesIndexSql = '''
    CREATE INDEX IF NOT EXISTS idx_auto_fixes_detection
      ON auto_fixes(detection_id, timestamp)
  ''';

  /// The reconciler's only query shape: what still needs processing.
  static const String _createAutoDetectionsIndexSql = '''
    CREATE INDEX IF NOT EXISTS idx_auto_detections_status
      ON auto_detections(status, started_at)
  ''';

  /// Durable queue of cloud writes the rider has already committed to, but
  /// which couldn't reach Firestore yet.
  ///
  /// This exists because awaiting a Firestore write while offline does NOT
  /// fail — it simply never completes, since the returned Future resolves on
  /// server acknowledgement. A `try`/`catch` around it catches nothing and the
  /// caller hangs forever. That is what made "end ride" and "share ride"
  /// unusable without a connection: the rider tapped the button and the app
  /// sat there. See issues §25.
  ///
  /// Rows are the rider's *intent*, recorded the instant they tap, and are
  /// replayed by [SyncManager] when connectivity returns. `payload` is JSON
  /// whose shape is owned by the handler for that `kind` — deliberately
  /// schemaless here so a new queued operation needs no migration.
  ///
  /// `next_attempt_at` carries the exponential backoff, so one permanently
  /// failing row can't spin the drain loop.
  ///
  /// `status` is `pending` or `dead` (v16, §69.O4). A row that keeps being
  /// rejected — `permanent_failures` counts rejections Firestore will never
  /// change its mind about, e.g. `permission-denied` — stops being retried
  /// and waits in Settings → Sync issues for the rider to retry or discard
  /// it, rather than burning battery on a doomed write forever.
  static const String _createOutboxSql = '''
    CREATE TABLE IF NOT EXISTS outbox (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      next_attempt_at TEXT,
      last_error TEXT,
      status TEXT NOT NULL DEFAULT 'pending',
      permanent_failures INTEGER NOT NULL DEFAULT 0
    )
  ''';

  /// The drain loop's only query shape: oldest-first, among rows whose backoff
  /// has elapsed.
  static const String _createOutboxIndexSql = '''
    CREATE INDEX IF NOT EXISTS idx_outbox_next_attempt
      ON outbox(next_attempt_at, created_at)
  ''';

  /// Tombstones for locally-deleted bikes.
  ///
  /// Without this, deleting a bike was purely local — `CloudRepository`
  /// re-downloads "anything missing locally", so the bike came straight back
  /// on the next sync and the rider saw it reappear after a restart, still
  /// selectable on the record screen and still in their forums. A tombstone
  /// makes the deletion durable even when the cloud delete can't happen yet
  /// (offline), because the download path consults this table.
  ///
  /// `synced = 0` means the remote copy still needs deleting; SyncManager
  /// retries those and flips the row to 1. Rows are kept, not removed, so a
  /// second device that still has the bike can't reintroduce it.
  static const String _createDeletedBikesSql = '''
    CREATE TABLE IF NOT EXISTS deleted_bikes (
      id TEXT PRIMARY KEY,
      deleted_at TEXT NOT NULL,
      synced INTEGER NOT NULL DEFAULT 0
    )
  ''';

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bikes (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        year INTEGER,
        cc INTEGER,
        image_path TEXT,
        is_active INTEGER NOT NULL DEFAULT 0,
        total_distance_m REAL NOT NULL DEFAULT 0,
        ride_count INTEGER NOT NULL DEFAULT 0,
        last_ride_at TEXT,
        odometer_km REAL,
        color_value INTEGER,
        archived INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        is_ebike INTEGER NOT NULL DEFAULT 0,
        archived_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE rides (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        bike_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        distance_m REAL NOT NULL DEFAULT 0,
        avg_speed_ms REAL,
        max_speed_ms REAL,
        duration_s INTEGER,
        moving_s INTEGER,
        hard_brake_count INTEGER NOT NULL DEFAULT 0,
        rapid_accel_count INTEGER NOT NULL DEFAULT 0,
        high_jerk_count INTEGER NOT NULL DEFAULT 0,
        overspeed_count INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        map_snapshot_path TEXT,
        is_auto INTEGER NOT NULL DEFAULT 0,
        bike_confidence TEXT NOT NULL DEFAULT 'high',
        route_id TEXT,
        route_name TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        track_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ride_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        speed_ms REAL NOT NULL,
        acceleration REAL,
        jerk REAL,
        altitude_m REAL,
        period_type TEXT NOT NULL DEFAULT 'moving',
        accuracy_m REAL,
        heading_deg REAL,
        confidence INTEGER,
        imu_quality INTEGER,
        is_cornering INTEGER,
        segment_start INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(ride_id) REFERENCES rides(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_ride_points_ride_id ON ride_points(ride_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_bikes_user_id ON bikes(user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_rides_user_id_status ON rides(user_id, status)
    ''');

    await db.execute('''
      CREATE INDEX idx_rides_bike_id_status ON rides(bike_id, status)
    ''');

    await db.execute('''
      CREATE INDEX idx_ride_points_ride_timestamp ON ride_points(ride_id, timestamp)
    ''');

    await db.execute('''
      CREATE TABLE maintenance_logs (
        id TEXT PRIMARY KEY,
        bike_id TEXT NOT NULL,
        service_type TEXT NOT NULL,
        date TEXT NOT NULL,
        odometer_km REAL NOT NULL,
        cost REAL,
        notes TEXT,
        custom_label TEXT,
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        visit_id TEXT,
        check_key TEXT,
        shop_name TEXT,
        shop_kind TEXT,
        receipt_path TEXT,
        visit_total REAL,
        visit_label TEXT,
        part_brand TEXT,
        part_grade TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_maintenance_bike_id ON maintenance_logs(bike_id)
    ''');

    await db.execute('''
      CREATE TABLE user_profiles (
        uid TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        photo_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(_createBikeMaintenanceConfigsSql);
    await db.execute(_createBikeMaintenanceConfigsIndexSql);
    await db.execute(_createBikeRunningCostsSql);
    await db.execute(_createDeletedBikesSql);
    await db.execute(_createDeletedRidesSql);
    await db.execute(_createDeletedMaintenanceLogsSql);
    await db.execute(_createMaintenanceProfilesSql);
    await db.execute(_createBikePaperworkSql);
    await db.execute(_createPrecheckIssuesSql);
    await db.execute(_createDetectionOdometerCreditsSql);
    await db.execute(_createOutboxSql);
    await db.execute(_createOutboxIndexSql);
    await db.execute(_createAutoDetectionsSql);
    await db.execute(_createAutoFixesSql);
    await db.execute(_createAutoFixesIndexSql);
    await db.execute(_createAutoDetectionsIndexSql);
    await db.execute(_createSavedPlacesSql);
  }

  /// Completely deletes all local database rows associated with [userId].
  ///
  /// Required for the Account Deletion flow (Apple App Store Guideline 5.1.1(v)).
  /// Uses raw SQL statements inside a single transaction and does NOT invoke other DAOs.
  ///
  /// issues §62.9: this used to also unconditionally wipe
  /// `deleted_bikes`, `outbox`, `auto_fixes`, and `auto_detections` in full —
  /// unlike `rides`/`bikes`/`user_profiles` above, none of those four tables
  /// carry a `user_id` column, so on a shared device, deleting account A's
  /// data wiped account B's pending outbox writes (in-flight ride shares/
  /// maintenance syncs), bike-deletion tombstones, and any in-progress
  /// auto-tracking detection for account B too — the same bug class as
  /// §33.1, fixed there via a `WHERE user_id = ?` these tables don't have a
  /// column for.
  ///
  /// `outbox` is fixed properly here: every entry's JSON payload already
  /// carries the owning uid (`userId` for a share, `uid` for a live-session
  /// teardown or maintenance log — see OutboxKind in outbox_service.dart), so
  /// rows can be attributed and scoped without a schema change.
  ///
  /// `deleted_bikes`/`auto_fixes`/`auto_detections` have no owner
  /// information anywhere in their schema or their writers, so there is no
  /// safe way to tell "this row belongs to the account being deleted" from
  /// "this row belongs to whoever else is using this device" without a
  /// migration (a new `user_id` column, backfilled at every write site,
  /// including the background auto-detection path) that this pass can't
  /// verify end-to-end without a device. Rather than guess, this pass simply
  /// stops wiping them here: the worst outcome is that the deleted account's
  /// own leftover rows in these three tables linger locally (a minor
  /// cleanliness gap, not a confidentiality/data-loss one — they're never
  /// exposed to anyone but whoever is signed into this device, and only ever
  /// checked against by uuid, not identity), which is a strictly safer
  /// failure mode than the previous behavior of silently deleting another
  /// signed-in rider's live queue. Tracked as a follow-up in the issues log
  /// §62 once these tables can be properly attributed.
  ///
  /// Since v15 `auto_detections` does carry a `user_id`, so rows stamped with
  /// this account are deleted below. Pre-v15 rows (NULL owner) are still left
  /// alone, as is `deleted_bikes`.
  Future<void> deleteUserData(String userId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rides = await txn.query('rides',
          where: 'user_id = ?', whereArgs: [userId], columns: ['id']);
      for (final ride in rides) {
        await txn.delete('ride_points',
            where: 'ride_id = ?', whereArgs: [ride['id']]);
      }
      await txn.delete('rides', where: 'user_id = ?', whereArgs: [userId]);
      await txn
          .delete('deleted_rides', where: 'user_id = ?', whereArgs: [userId]);

      final bikes = await txn.query('bikes',
          where: 'user_id = ?', whereArgs: [userId], columns: ['id']);
      for (final bike in bikes) {
        await txn.delete('bike_maintenance_configs',
            where: 'bike_id = ?', whereArgs: [bike['id']]);
        await txn.delete('bike_running_costs',
            where: 'bike_id = ?', whereArgs: [bike['id']]);
        await txn.delete('maintenance_logs',
            where: 'bike_id = ?', whereArgs: [bike['id']]);
        for (final table in const [
          'bike_maintenance_profiles',
          'bike_paperwork',
          'precheck_issues',
          'detection_odometer_credits',
        ]) {
          await txn
              .delete(table, where: 'bike_id = ?', whereArgs: [bike['id']]);
        }
      }
      await txn.delete('deleted_maintenance_logs',
          where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('bikes', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('user_profiles', where: 'uid = ?', whereArgs: [userId]);
      await txn
          .delete('saved_places', where: 'user_id = ?', whereArgs: [userId]);

      // v15 gave auto_detections an owner. Only rows stamped with this uid
      // go; unowned legacy rows are left alone for the reason given above.
      // Their auto_fixes follow via ON DELETE CASCADE.
      await txn
          .delete('auto_detections', where: 'user_id = ?', whereArgs: [userId]);

      final outboxRows = await txn.query('outbox', columns: ['id', 'payload']);
      for (final row in outboxRows) {
        if (_outboxPayloadOwner(row['payload'] as String?) == userId) {
          await txn.delete('outbox', where: 'id = ?', whereArgs: [row['id']]);
        }
      }
    });
  }

  /// The uid an outbox row's JSON payload claims to belong to, or null if it
  /// can't be determined — see [deleteUserData]. Every real payload shape
  /// (share/live-teardown/maintenance-log — see OutboxKind in
  /// outbox_service.dart) carries one of these two keys.
  static String? _outboxPayloadOwner(String? rawPayload) {
    if (rawPayload == null) return null;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) return null;
      return (decoded['userId'] ?? decoded['uid']) as String?;
    } catch (_) {
      return null;
    }
  }
}
