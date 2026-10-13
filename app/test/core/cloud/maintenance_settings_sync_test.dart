import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/maintenance_settings_sync.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/daos/outbox_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';

/// issues §88.2: maintenance settings (tracked checks + running costs) must
/// survive a reinstall. The Firestore write/read is a thin shell around
/// these SQLite halves, which run here against a real in-memory schema.
void main() {
  sqfliteFfiInit();

  late Database db;

  Future<void> addBike(Database d, String id, {String user = 'u1'}) =>
      d.insert('bikes', {
        'id': id,
        'user_id': user,
        'brand': 'Yamaha',
        'model': 'MT-07',
        'created_at': DateTime(2026).toIso8601String(),
      });

  Future<void> addSettings(Database d, String bikeId) async {
    await d.insert('bike_maintenance_configs', {
      'bike_id': bikeId,
      'service_type': 'oilChange',
      'interval_km': 2500.0,
      'is_enabled': 1,
      'notes': 'Motul 10W-40',
      'typical_cost': 1800.0,
    });
    await d.insert('bike_maintenance_configs', {
      'bike_id': bikeId,
      'service_type': 'chainLube',
      'interval_km': 500.0,
      'is_enabled': 0,
    });
    await d.insert('bike_running_costs', {
      'bike_id': bikeId,
      'fuel_price_per_litre': 125.0,
      'km_per_litre': 38.5,
    });
  }

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('doc lives under the owner-only private subcollection', () {
    expect(MaintenanceSettingsSync.collection, 'private');
    expect(MaintenanceSettingsSync.docId('b1'), 'maintenanceSettings_b1');
  });

  test('buildPayload is null for a bike with no settings', () async {
    await addBike(db, 'b1');
    expect(await MaintenanceSettingsSync.buildPayload('b1'), isNull);
  });

  test('buildPayload leaves out a table with no local rows', () async {
    await addBike(db, 'b1');
    await db.insert('bike_running_costs', {
      'bike_id': 'b1',
      'fuel_price_per_litre': 125.0,
      'km_per_litre': null,
    });
    final payload = await MaintenanceSettingsSync.buildPayload('b1');
    expect(payload, isNotNull);
    expect(payload!.containsKey('configs'), isFalse,
        reason: 'an absent table must not wipe the cloud copy on merge');
    expect(payload['runningCost'],
        {'fuel_price_per_litre': 125.0, 'km_per_litre': null});
  });

  test('round-trips to a fresh install', () async {
    await addBike(db, 'b1');
    await addSettings(db, 'b1');
    final payload = await MaintenanceSettingsSync.buildPayload('b1');

    // New device: bike restored by downloadBikes, settings not yet.
    await db.delete('bike_maintenance_configs');
    await db.delete('bike_running_costs');
    final other = db;
    expect(await MaintenanceSettingsSync.bikesMissingSettings('u1'), ['b1']);

    expect(await MaintenanceSettingsSync.applyDownloaded('b1', payload!),
        isTrue);

    final configs = await other.query('bike_maintenance_configs',
        orderBy: 'service_type');
    expect(configs, hasLength(2));
    expect(configs[1]['service_type'], 'oilChange');
    expect(configs[1]['interval_km'], 2500.0);
    expect(configs[1]['is_enabled'], 1);
    expect(configs[1]['notes'], 'Motul 10W-40');
    expect(configs[1]['typical_cost'], 1800.0);
    expect(configs[0]['is_enabled'], 0);
    expect(configs[0]['typical_cost'], isNull);

    final running = await other.query('bike_running_costs');
    expect(running.single['fuel_price_per_litre'], 125.0);
    expect(running.single['km_per_litre'], 38.5);
    expect(await MaintenanceSettingsSync.bikesMissingSettings('u1'), isEmpty);
  });

  test('never overwrites local rows', () async {
    await addBike(db, 'b1');
    await db.insert('bike_running_costs', {
      'bike_id': 'b1',
      'fuel_price_per_litre': 130.0,
      'km_per_litre': 40.0,
    });
    final wrote = await MaintenanceSettingsSync.applyDownloaded('b1', {
      'configs': [
        {'service_type': 'oilChange', 'interval_km': 3000, 'is_enabled': 1},
      ],
      'runningCost': {'fuel_price_per_litre': 99.0, 'km_per_litre': 10.0},
    });
    expect(wrote, isTrue, reason: 'configs were empty locally, so they fill');
    final running = await db.query('bike_running_costs');
    expect(running.single['fuel_price_per_litre'], 130.0);
    expect(running.single['km_per_litre'], 40.0);
    expect(await db.query('bike_maintenance_configs'), hasLength(1));

    // Now both tables have rows: a second download changes nothing.
    expect(
        await MaintenanceSettingsSync.applyDownloaded('b1', {
          'configs': [
            {'service_type': 'airFilter', 'interval_km': 6000, 'is_enabled': 1},
          ],
        }),
        isFalse);
    expect(await db.query('bike_maintenance_configs'), hasLength(1));
  });

  test('skips a bike that is not on this device, and malformed rows',
      () async {
    expect(
        await MaintenanceSettingsSync.applyDownloaded('ghost', {
          'runningCost': {'fuel_price_per_litre': 99.0},
        }),
        isFalse);

    await addBike(db, 'b1');
    await MaintenanceSettingsSync.applyDownloaded('b1', {
      'configs': [
        'not a map',
        {'service_type': 'oilChange'}, // no interval
        {'service_type': 'chainLube', 'interval_km': -5},
        {'service_type': 'airFilter', 'interval_km': 6000, 'is_enabled': true},
      ],
    });
    final configs = await db.query('bike_maintenance_configs');
    expect(configs.single['service_type'], 'airFilter');
    expect(configs.single['is_enabled'], 1);
  });

  test('bike queries are scoped to the signed-in rider', () async {
    await addBike(db, 'mine');
    await addBike(db, 'theirs', user: 'u2');
    await addSettings(db, 'theirs');
    expect(await MaintenanceSettingsSync.bikesMissingSettings('u1'), ['mine']);
    expect(await MaintenanceSettingsSync.bikesWithSettings('u1'), isEmpty);
    expect(await MaintenanceSettingsSync.bikesWithSettings('u2'), ['theirs']);
  });

  test('outbox drops a settings entry whose bike is gone locally', () async {
    final dao = OutboxDao();
    final service = OutboxService(dao: dao, currentUid: () => 'u1');
    await service.enqueueMaintenanceSettings(
        uid: 'u1', bikeId: 'deleted-bike', attemptNow: false);
    // Re-queuing the same bike supersedes rather than stacks.
    await service.enqueueMaintenanceSettings(
        uid: 'u1', bikeId: 'deleted-bike', attemptNow: false);
    final entries = await dao.all();
    expect(entries, hasLength(1));
    expect(entries.single.kind, OutboxKind.maintenanceSettings);

    final result = await service.deliverForTesting(entries.single);
    expect(result, OutboxDeliveryResult.delivered);
    expect(await dao.all(), isEmpty);
    service.dispose();
  });
}
