@Timeout(Duration(seconds: 20))
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/maintenance_settings_sync.dart';
import 'package:throttleiq/core/database/daos/maintenance_dao.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/maintenance/domain/calculators/riding_conditions.dart';
import 'package:throttleiq/features/maintenance/domain/catalog/schedule_templates.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_profile.dart';
import 'package:throttleiq/features/maintenance/domain/entities/service_visit.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';

/// Visits, tombstoned deletes (§94.2), setup and the v20 settings backup,
/// against a real in-memory schema.
void main() {
  sqfliteFfiInit();
  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Bajaj',
      'model': 'Pulsar 150',
      'cc': 150,
      'odometer_km': 24000.0,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
        overrides: [currentUserProvider.overrideWithValue(null)]);
    addTearDown(c.dispose);
    return c;
  }

  test('a visit is one entry with many items; editing updates in place', () async {
    final c = container();
    final n = c.read(maintenanceProvider('b1').notifier);
    final visitId = await n.saveVisit(VisitDraft(
      date: DateTime(2026, 10, 1),
      odometerKm: 24500,
      totalCost: 1400,
      shopName: 'Rahim Motors',
      items: const [
        VisitItemDraft(type: ServiceType.oilChange, partGrade: 'mineral'),
        VisitItemDraft(type: ServiceType.chain),
        VisitItemDraft(type: ServiceType.airFilter),
      ],
    ));

    var logs = await c.read(maintenanceProvider('b1').future);
    expect(logs, hasLength(3));
    expect(groupVisits(logs).single.totalCost, 1400);
    final oilId = logs.firstWhere((l) => l.serviceType == ServiceType.oilChange).id;

    await n.updateVisit(
        visitId,
        VisitDraft(
          date: DateTime(2026, 10, 1),
          odometerKm: 24550,
          totalCost: 1500,
          items: const [
            VisitItemDraft(type: ServiceType.oilChange),
            VisitItemDraft(type: ServiceType.tire),
          ],
        ));
    logs = await c.read(maintenanceProvider('b1').future);
    expect(logs.map((l) => l.serviceType).toSet(),
        {ServiceType.oilChange, ServiceType.tire});
    expect(logs.firstWhere((l) => l.serviceType == ServiceType.oilChange).id,
        oilId);
    // The two unticked items left tombstones so the cloud copies go too.
    expect(await MaintenanceDao().deletedIds(), hasLength(2));
  });

  test('deleting a visit tombstones every item and drops queued uploads', () async {
    final c = container();
    final n = c.read(maintenanceProvider('b1').notifier);
    final visitId = await n.saveVisit(VisitDraft(
      date: DateTime(2026, 10, 1),
      odometerKm: 24500,
      items: const [
        VisitItemDraft(type: ServiceType.oilChange),
        VisitItemDraft(type: ServiceType.chain),
      ],
    ));
    final ids = (await c.read(maintenanceProvider('b1').future))
        .map((l) => l.id)
        .toList();
    // Simulate an upload still queued for one of them.
    await db.insert('outbox', {
      'id': 'maintenance:${ids.first}',
      'kind': 'maintenance_log',
      'payload': '{}',
      'created_at': DateTime.now().toIso8601String(),
      'next_attempt_at': DateTime.now().toIso8601String(),
    });

    await n.deleteVisit(visitId);

    expect(await c.read(maintenanceProvider('b1').future), isEmpty);
    final dao = MaintenanceDao();
    expect(await dao.deletedIds(), ids.toSet());
    expect(await dao.pendingRemoteDeletions('u1'), unorderedEquals(ids));
    expect(await dao.isDeleted(ids.first), isTrue);
    expect(await db.query('outbox'), isEmpty);
    await dao.markDeletionSynced(ids.first);
    expect(await dao.pendingRemoteDeletions('u1'), [ids.last]);
  });

  test('setup writes the template, profile and oil baseline', () async {
    final c = container();
    await c.read(maintenanceProfileProvider('b1').future);
    await c.read(maintenanceProfileProvider('b1').notifier).completeSetup(
          MaintenanceSetupDraft(
            template: templateById('bajaj_pulsar_150'),
            ridingProfile: RidingProfile.severe,
            oilGrade: OilGrade.semiSynthetic,
            lastOilKm: 23500,
            lastOilDate: DateTime(2026, 9, 1),
          ),
        );

    final profile = await c.read(maintenanceProfileProvider('b1').future);
    expect(profile!.templateId, 'bajaj_pulsar_150');
    expect(profile.ridingProfile, RidingProfile.severe);
    expect(profile.onboardedAt, isNotNull);

    final configs = await c.read(maintenanceConfigProvider('b1').future);
    final oil = configs.firstWhere((x) => x.serviceType == ServiceType.oilChange);
    expect(oil.intervalKm, 2500); // semi-synthetic
    expect(oil.baselineKm, 23500);
    // "Everything else at the same time" was not ticked.
    final air = configs.firstWhere((x) => x.serviceType == ServiceType.airFilter);
    expect(air.hasBaseline, isFalse);
  });

  test('profile and paperwork survive a reinstall via the settings backup', () async {
    final c = container();
    await c.read(maintenanceProfileProvider('b1').notifier).completeSetup(
          MaintenanceSetupDraft(template: templateById('generic_mid')),
        );
    await c.read(paperworkProvider('b1').notifier).upsert(PaperworkEntity(
          bikeId: 'b1',
          kind: PaperworkKind.taxToken,
          expiresOn: DateTime(2027, 3, 31),
        ));

    final payload = await MaintenanceSettingsSync.buildPayload('b1');
    expect(payload!['profile']['template_id'], 'generic_mid');
    expect((payload['paperwork'] as List).single['kind'], 'taxToken');
    expect((payload['configs'] as List).first, contains('interval_days'));

    // Fresh device: same bike, nothing else.
    await db.delete('bike_paperwork');
    await db.delete('bike_maintenance_profiles');
    await db.delete('bike_maintenance_configs');
    expect(await MaintenanceSettingsSync.bikesMissingSettings('u1'), ['b1']);

    expect(await MaintenanceSettingsSync.applyDownloaded('b1', payload), isTrue);
    expect((await db.query('bike_maintenance_profiles')).single['template_id'],
        'generic_mid');
    expect((await db.query('bike_paperwork')).single['kind'], 'taxToken');
    final oil = (await db.query('bike_maintenance_configs',
            where: "service_type = 'oilChange'"))
        .single;
    expect(oil['interval_days'], 180);
  });

  test('quick-check failures become open issues until fixed', () async {
    final c = container();
    await c.read(precheckIssuesProvider('b1').notifier)
        .record([PrecheckItem.chain, PrecheckItem.lights]);
    var issues = await c.read(precheckIssuesProvider('b1').future);
    expect(issues.map((i) => i.item).toSet(),
        {PrecheckItem.chain, PrecheckItem.lights});
    // The same failure again doesn't duplicate an open issue.
    await c.read(precheckIssuesProvider('b1').notifier)
        .record([PrecheckItem.chain]);
    issues = await c.read(precheckIssuesProvider('b1').future);
    expect(issues, hasLength(2));

    await c.read(precheckIssuesProvider('b1').notifier)
        .resolve(issues.first.id);
    expect(await c.read(precheckIssuesProvider('b1').future), hasLength(1));
    final profile = await c.read(maintenanceProfileProvider('b1').future);
    expect(profile!.lastPrecheckAt, isNotNull);
  });

  test('a custom check can be added, tracked and removed', () async {
    final c = container();
    final n = c.read(maintenanceConfigProvider('b1').notifier);
    await c.read(maintenanceConfigProvider('b1').future);
    await n.addCustomCheck(label: 'Steering bearings', intervalKm: 10000);
    var configs = await c.read(maintenanceConfigProvider('b1').future);
    final custom = configs.singleWhere((x) => x.isCustom);
    expect(custom.customLabel, 'Steering bearings');
    expect(custom.isEnabled, isTrue);

    await n.removeCustomCheck(custom.key);
    configs = await c.read(maintenanceConfigProvider('b1').future);
    expect(configs.where((x) => x.isCustom), isEmpty);
  });

  test('restore merges paperwork by kind and replaces a placeholder profile',
      () async {
    final cloud = {
      'profile': {
        'template_id': 'bajaj_pulsar_150',
        'riding_profile': 'severe',
        'onboarded_at': DateTime(2026, 9, 1).toIso8601String(),
      },
      'paperwork': [
        {'kind': 'taxToken', 'expires_on': DateTime(2027, 1, 1).toIso8601String()},
        {'kind': 'insurance', 'expires_on': DateTime(2027, 2, 1).toIso8601String()},
      ],
    };
    // Before the restore ran, the rider added insurance (creating a
    // placeholder profile).
    final c = container();
    await c.read(paperworkProvider('b1').notifier).upsert(PaperworkEntity(
          bikeId: 'b1',
          kind: PaperworkKind.insurance,
          expiresOn: DateTime(2027, 6, 1),
        ));
    final payload = await MaintenanceSettingsSync.buildPayload('b1');
    expect(payload!.containsKey('profile'), isFalse,
        reason: 'a placeholder profile must not overwrite the cloud one');

    expect(await MaintenanceSettingsSync.applyDownloaded('b1', cloud), isTrue);
    final profile = (await db.query('bike_maintenance_profiles')).single;
    expect(profile['template_id'], 'bajaj_pulsar_150');
    final papers = {
      for (final r in await db.query('bike_paperwork'))
        r['kind']: r['expires_on'],
    };
    expect(papers.keys.toSet(), {'taxToken', 'insurance'});
    // The local insurance row wins over the cloud's.
    expect(papers['insurance'], DateTime(2027, 6, 1).toIso8601String());
  });
}

