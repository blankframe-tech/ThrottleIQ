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
      version: 5,
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
  }

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
  }
}
