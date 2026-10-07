import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
