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
  Future<void> createSchemaForTesting(Database db) => _onCreate(db, 10);

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

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'throttleiq.db');
    try {
      return await _openDb(path);
    } catch (_) {
      // db file left corrupt by the maintenance_logs index-before-table bug
      // (fixed below) - nuke and rebuild rather than crash forever.
      await deleteDatabase(path);
      return _openDb(path);
    }
  }

  Future<Database> _openDb(String path) {
    return openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
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
  }

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
  }
}
