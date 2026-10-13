@Timeout(Duration(seconds: 20))
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/maintenance/domain/entities/maintenance_entity.dart';
import 'package:throttleiq/features/maintenance/domain/entities/service_visit.dart';
import 'package:throttleiq/features/maintenance/presentation/providers/maintenance_provider.dart';

class _MockUser extends Mock implements User {
  @override
  String get uid => 'u1';
}

class _ThrowingOutbox extends OutboxService {
  int attempts = 0;

  @override
  Future<String> enqueueMaintenanceLog({
    required String uid,
    required Map<String, dynamic> logData,
    bool attemptNow = true,
  }) async {
    attempts++;
    throw StateError('sqlite busy');
  }
}

/// issues §101.R8: a failed backup enqueue must not become an uncaught
/// async error (which main.dart records as a fatal crash).
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
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('saveVisit persists and raises no uncaught error when enqueue throws',
      () async {
    final outbox = _ThrowingOutbox();
    final uncaught = <Object>[];
    await runZonedGuarded(() async {
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_MockUser()),
        outboxServiceProvider.overrideWithValue(outbox),
      ]);
      addTearDown(c.dispose);
      await c.read(maintenanceProvider('b1').notifier).saveVisit(VisitDraft(
            date: DateTime(2026, 10, 1),
            odometerKm: 100,
            items: const [VisitItemDraft(type: ServiceType.chain)],
          ));
      // Let the failed enqueue's error handler run.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }, (e, st) => uncaught.add(e));

    expect(outbox.attempts, 1);
    expect(uncaught, isEmpty);
    expect(await db.query('maintenance_logs'), hasLength(1));
  });
}
