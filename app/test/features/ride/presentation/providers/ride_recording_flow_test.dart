import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:throttleiq/core/cloud/sync_manager.dart';
import 'package:throttleiq/core/database/database_helper.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';
import 'package:throttleiq/features/auth/presentation/providers/auth_provider.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'u1';
}

class _Sync extends Mock implements SyncManager {
  @override
  Future<void> sync() async {}
}

/// Location on, permission granted, fixes from a stream the test owns.
class _Geo extends GeolocatorPlatform {
  final fixes = StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      fixes.stream;
}

/// #50 / §90.B9: the recorder's own start → pause → resume → stop flow,
/// against the real notifier with fakes for GPS, plugins and the cloud.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(Firebase.initializeApp);
  sqfliteFfiInit();

  late Database db;
  late GeolocatorPlatform originalGeo;
  late _Geo geo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.createSchemaForTesting(db);
    DatabaseHelper.overrideDatabaseForTesting(db);
    await db.insert('bikes', {
      'id': 'b1',
      'user_id': 'u1',
      'brand': 'Bajaj',
      'model': 'Pulsar',
      'is_active': 1,
      'created_at': DateTime(2026, 10, 29).toIso8601String(),
    });
    originalGeo = GeolocatorPlatform.instance;
    geo = _Geo();
    GeolocatorPlatform.instance = geo;
    // Haptics, wakelock and the IMU have no host side under test.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('vibration'), (_) async => false);
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage(<Object?>[]));
    for (final name in [
      'dev.fluttercommunity.plus/sensors/user_accel',
      'dev.fluttercommunity.plus/sensors/gyroscope',
      'dev.fluttercommunity.plus/sensors/accelerometer',
      'dev.fluttercommunity.plus/sensors/method',
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (_) async => null);
    }
  });

  tearDown(() async {
    GeolocatorPlatform.instance = originalGeo;
    await geo.fixes.close();
    DatabaseHelper.overrideDatabaseForTesting(null);
    await db.close();
  });

  /// Runs [body] with stray async errors from fire-and-forget side effects
  /// (analytics, stats, home widget: no backend here) ignored, while the
  /// body's own failures, expectations included, still fail the test.
  Future<void> quietly(Future<void> Function() body) {
    final done = Completer<void>();
    runZonedGuarded(() async {
      try {
        await body();
        done.complete();
      } catch (e, st) {
        done.completeError(e, st);
      }
    }, (_, __) {});
    return done.future;
  }

  Future<String?> rideStatus(String id) async =>
      (await db.query('rides', where: 'id = ?', whereArgs: [id]))
          .single['status'] as String?;

  test('start, pause, resume and stop move the ride through every state',
      () async {
    final c = ProviderContainer(overrides: [
      syncManagerProvider.overrideWithValue(_Sync()),
      currentUserProvider.overrideWithValue(_User()),
      realtimeServicesProvider
          .overrideWith((ref) => RealtimeServices.disabled()),
    ]);
    addTearDown(c.dispose);
    final n = c.read(rideRecordingProvider.notifier);
    RideRecordingState s() => c.read(rideRecordingProvider);

    await quietly(() async {
      await n.startRide(bikeId: 'b1');
      expect(s().status, RecordingStatus.active);
      expect(s().error, isNull);
      final id = s().ride!.id;
      expect(s().ride!.bikeId, 'b1');
      expect(await rideStatus(id), 'active');
      expect(geo.fixes.hasListener, isTrue, reason: 'GPS opened on start');

      await n.pauseRide();
      expect(s().status, RecordingStatus.paused);
      expect(s().transitionPending, isFalse);
      // Cancelled, not paused (§90.C1): nothing buffers fixes while paused.
      expect(geo.fixes.hasListener, isFalse);
      final frozen = s().elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(s().elapsed, frozen, reason: 'the clock stops while paused');

      // A second pause, or a stray resume while active, is a no-op.
      await n.pauseRide();
      expect(s().status, RecordingStatus.paused);

      await n.resumeRide();
      expect(s().status, RecordingStatus.active);
      expect(s().ride!.id, id, reason: 'same ride after resume');
      expect(geo.fixes.hasListener, isTrue);
      await n.resumeRide();
      expect(s().status, RecordingStatus.active);

      final stopped = await n.stopRide();
      expect(stopped, id);
      expect(s().status, RecordingStatus.idle);
      expect(s().ride, isNull);
      expect(geo.fixes.hasListener, isFalse, reason: 'GPS closed on stop');
      expect(await rideStatus(id), 'completed');
    });
  });

  test('start without a bike stays idle with a reason', () async {
    await db.delete('bikes');
    final c = ProviderContainer(overrides: [
      syncManagerProvider.overrideWithValue(_Sync()),
      currentUserProvider.overrideWithValue(_User()),
      realtimeServicesProvider
          .overrideWith((ref) => RealtimeServices.disabled()),
    ]);
    addTearDown(c.dispose);
    await c.read(rideRecordingProvider.notifier).startRide();
    final s = c.read(rideRecordingProvider);
    expect(s.status, RecordingStatus.idle);
    expect(s.error, kNoBikeRecordingError);
    expect(geo.fixes.hasListener, isFalse);
  });

  test('pause, resume and stop do nothing while idle', () async {
    final c = ProviderContainer(overrides: [
      syncManagerProvider.overrideWithValue(_Sync()),
      currentUserProvider.overrideWithValue(_User()),
      realtimeServicesProvider
          .overrideWith((ref) => RealtimeServices.disabled()),
    ]);
    addTearDown(c.dispose);
    final n = c.read(rideRecordingProvider.notifier);
    await n.pauseRide();
    await n.resumeRide();
    expect(await n.stopRide(), isNull);
    expect(c.read(rideRecordingProvider).status, RecordingStatus.idle);
  });
}
