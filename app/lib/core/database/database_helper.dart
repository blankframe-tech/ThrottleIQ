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
  Future<void> createSchemaForTesting(Database db) => _onCreate(db, 11);

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
  /// from the same call. docs/Issues.md §33.9: the previous catch treated ANY
  /// exception here as the one documented corruption case it was written
  /// for, and deleted the whole database — turning a transient error into
  /// permanent data loss of every local ride/bike/maintenance record.
  static const _corruptionMarkers = [
    'file is not a database',
    'file is encrypted or is not a database',
    'database disk image is malformed',
    'database corrupt',
  ];

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
      // db file left corrupt by the maintenance_logs index-before-table bug
      // (fixed below) - nuke and rebuild rather than crash forever.
      await deleteDatabase(path);
      return _openDb(path);
    }
  }

  Future<Database> _openDb(String path) {
    return openDatabase(
      path,
      version: 11,
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
      await db.execute('ALTER TABLE ride_points ADD COLUMN period_type TEXT DEFAULT "moving"');
      await db.execute('ALTER TABLE ride_points ADD COLUMN accuracy_m REAL');
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
      await db.execute('ALTER TABLE bikes ADD COLUMN odometer_km REAL');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE ride_points ADD COLUMN heading_deg REAL');
      await db.execute('ALTER TABLE ride_points ADD COLUMN confidence INTEGER');
      await db.execute('ALTER TABLE ride_points ADD COLUMN imu_quality INTEGER');
      await db.execute('ALTER TABLE ride_points ADD COLUMN is_cornering INTEGER');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE maintenance_logs ADD COLUMN custom_label TEXT');
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
      await db.execute('ALTER TABLE rides ADD COLUMN moving_s INTEGER');
    }
    if (oldVersion < 10) {
      await db.execute(_createOutboxSql);
      await db.execute(_createOutboxIndexSql);
    }
    if (oldVersion < 11) {
      // Auto-tracking. Existing rides were all started by the rider, so the
      // defaults below are the truthful reading of a pre-v11 row rather than
      // a placeholder: is_auto = 0, bike_confidence = 'high'.
      await _addColumnIfMissing(db, 'rides', 'is_auto',
          'is_auto INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'rides', 'bike_confidence',
          "bike_confidence TEXT NOT NULL DEFAULT 'high'");
      await db.execute(_createAutoDetectionsSql);
      await db.execute(_createAutoFixesSql);
      await db.execute(_createAutoFixesIndexSql);
      await db.execute(_createAutoDetectionsIndexSql);
    }
  }

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
      created_at TEXT NOT NULL
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
  /// sat there. See docs/Issues.md §25.
  ///
  /// Rows are the rider's *intent*, recorded the instant they tap, and are
  /// replayed by [SyncManager] when connectivity returns. `payload` is JSON
  /// whose shape is owned by the handler for that `kind` — deliberately
  /// schemaless here so a new queued operation needs no migration.
  ///
  /// `next_attempt_at` carries the exponential backoff, so one permanently
  /// failing row can't spin the drain loop.
  static const String _createOutboxSql = '''
    CREATE TABLE IF NOT EXISTS outbox (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      next_attempt_at TEXT,
      last_error TEXT
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
        synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
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
        status TEXT NOT NULL DEFAULT 'active',
        map_snapshot_path TEXT,
        is_auto INTEGER NOT NULL DEFAULT 0,
        bike_confidence TEXT NOT NULL DEFAULT 'high',
        synced INTEGER NOT NULL DEFAULT 0,
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
        created_at TEXT NOT NULL
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

    await db.execute(_createDeletedBikesSql);
    await db.execute(_createOutboxSql);
    await db.execute(_createOutboxIndexSql);
    await db.execute(_createAutoDetectionsSql);
    await db.execute(_createAutoFixesSql);
    await db.execute(_createAutoFixesIndexSql);
    await db.execute(_createAutoDetectionsIndexSql);
  }
}
