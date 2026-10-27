import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/sync_manager.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/ride/domain/entities/ride_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

class _Sync extends Mock implements SyncManager {
  int calls = 0;
  @override
  Future<void> sync() async => calls++;
}

/// Critique oct27 #6: stopping a ride backs it up at once instead of waiting
/// for the 5-minute timer, which MIUI may never let fire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(Firebase.initializeApp);
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    final now = DateTime(2026, 10, 27, 8).toIso8601String();
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Bajaj',
      'model': 'Pulsar',
      'is_active': 1,
      'created_at': now,
    });
    await db.insert('rides', {
      'id': 'r1',
      'user_id': 'u1',
      'bike_id': 'b1',
      'start_time': now,
      'status': 'active',
      'created_at': now,
    });
    // The haptic and wakelock plugins have no host side under test.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('vibration'), (_) async => false);
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage(<Object?>[]));
  });

  tearDown(() async {
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  test('stopRide triggers a sync', () async {
    final sync = _Sync();
    final c = ProviderContainer(overrides: [
      syncManagerProvider.overrideWithValue(sync),
      currentUserProvider.overrideWithValue(null),
      realtimeServicesProvider
          .overrideWith((ref) => RealtimeServices.disabled()),
    ]);
    addTearDown(c.dispose);
    final n = c.read(rideRecordingProvider.notifier);
    // ignore: invalid_use_of_protected_member
    n.state = RideRecordingState(
      status: RecordingStatus.active,
      ride: RideEntity(
          id: 'r1',
          userId: 'u1',
          bikeId: 'b1',
          startTime: DateTime(2026, 10, 27, 8)),
    );

    // Fire-and-forget side effects (stats, widgets, analytics) have no
    // backend here; only the sync call is under test.
    String? stopped;
    await runZonedGuarded(() async => stopped = await n.stopRide(), (_, __) {});

    expect(stopped, 'r1');
    expect(sync.calls, 1);
  });
}
