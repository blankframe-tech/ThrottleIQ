import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/firestore_quota.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/cloud/sync_manager.dart';

class _ThrowingConnectivity extends Fake implements Connectivity {
  int checks = 0;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checks++;
    throw PlatformException(code: 'boom', message: 'connectivity failed');
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _OfflineConnectivity extends Fake implements Connectivity {
  int checks = 0;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checks++;
    return [ConnectivityResult.none];
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _OnlineConnectivity extends Fake implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

/// Counts drains, then ends the pass by throwing [error], so a test never
/// reaches the database half of the sync.
class _CountingOutbox extends Fake implements OutboxService {
  _CountingOutbox([Object? error]) : error = error ?? StateError('end pass');

  final Object error;
  int drains = 0;

  @override
  Future<void> drain() async {
    drains++;
    throw error;
  }
}

FirebaseException _firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'rider-1';
}

class _FakeAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _FakeUser();

  @override
  Stream<User?> authStateChanges() => const Stream.empty();
}

/// issues §101.C2: a throw from the connectivity check must not leave the
/// sync guard (`_isSyncing`) stuck at true for the rest of the session.
void main() {
  test('a throwing connectivity check releases the sync guard', () async {
    final connectivity = _ThrowingConnectivity();
    final manager = SyncManager(
      outbox: OutboxService(currentUid: () => 'rider-1'),
      connectivity: connectivity,
      auth: _FakeAuth(),
    );

    await manager.sync();
    expect(manager.isSyncing, isFalse);
    expect(manager.status, SyncStatus.failure);

    // A second pass reaches the connectivity check again, proving the guard
    // was released rather than short-circuiting at `if (_isSyncing) return`.
    await manager.sync();
    expect(connectivity.checks, 2);
    expect(manager.isSyncing, isFalse);

    manager.dispose();
  });

  test('no network: failure, guard released, listeners notified', () async {
    final connectivity = _OfflineConnectivity();
    final manager = SyncManager(
      outbox: OutboxService(currentUid: () => 'rider-1'),
      connectivity: connectivity,
      auth: _FakeAuth(),
    );
    var notified = 0;
    manager.addListener(() => notified++);

    await manager.sync();
    expect(manager.isSyncing, isFalse);
    expect(manager.status, SyncStatus.failure);
    expect(notified, greaterThan(0));

    await manager.sync();
    expect(connectivity.checks, 2);

    manager.dispose();
  });

  test('syncOnResume runs a pass, then is throttled (critique oct27 #6)',
      () async {
    final connectivity = _OfflineConnectivity();
    final manager = SyncManager(
      outbox: OutboxService(currentUid: () => 'rider-1'),
      connectivity: connectivity,
      auth: _FakeAuth(),
    );
    addTearDown(manager.dispose);

    await manager.syncOnResume();
    expect(connectivity.checks, 1);

    // A second resume inside the 30 s window doesn't start another pass.
    await manager.syncOnResume();
    expect(connectivity.checks, 1);
  });

  /// §104: Firestore over its daily quota pauses sync before the outbox is
  /// touched, so a day-long outage costs queued entries no retries.
  group('quota pause', () {
    late FirestoreQuota quota;
    late _CountingOutbox outbox;
    late int probes;

    SyncManager online({Object? probeError, Object? drainError}) {
      outbox = _CountingOutbox(drainError);
      final manager = SyncManager(
        outbox: outbox,
        connectivity: _OnlineConnectivity(),
        auth: _FakeAuth(),
        quota: quota,
        quotaProbe: () async {
          probes++;
          if (probeError != null) throw probeError;
        },
      );
      addTearDown(manager.dispose);
      return manager;
    }

    setUp(() {
      quota = FirestoreQuota();
      probes = 0;
    });

    test('a probe refused for quota pauses before draining', () async {
      final manager = online(probeError: _firestoreError('resource-exhausted'));

      await manager.sync();

      expect(quota.isPaused, isTrue);
      expect(outbox.drains, 0);
      expect(manager.status, SyncStatus.failure);
      expect(manager.isSyncing, isFalse);
    });

    test('while paused, the next pass neither probes nor drains', () async {
      final manager = online(probeError: _firestoreError('resource-exhausted'));

      await manager.sync();
      await manager.sync();

      expect(probes, 1);
      expect(outbox.drains, 0);
    });

    test('a successful probe resumes a paused sync', () async {
      quota.report(_firestoreError('resource-exhausted'));
      final manager = online();

      await manager.sync();

      expect(quota.isPaused, isFalse);
      expect(outbox.drains, 1);
    });

    test('a probe failing for another reason does not pause', () async {
      final manager = online(probeError: _firestoreError('unavailable'));

      await manager.sync();

      expect(quota.isPaused, isFalse);
      expect(outbox.drains, 1);
    });

    test('a pass refused for quota midway pauses too', () async {
      final manager = online(drainError: _firestoreError('resource-exhausted'));

      await manager.sync();

      expect(quota.isPaused, isTrue);
      expect(manager.status, SyncStatus.failure);
    });
  });
}
