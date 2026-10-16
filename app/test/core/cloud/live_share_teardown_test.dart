import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/realtime/realtime_connection_manager.dart';
import 'package:throttleiq/core/realtime/realtime_health.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';

import '../realtime/in_memory_realtime_store.dart';

RealtimeServices _services(InMemoryRealtimeStore store) => RealtimeServices(
      store: store,
      connections: RealtimeConnectionManager(store, linger: Duration.zero),
      health: RealtimeHealthMonitor(store),
    );

/// A device with no network: goOnline() is called but the socket never comes up.
class _NoNetworkStore extends InMemoryRealtimeStore {
  _NoNetworkStore() : super(online: false);
  @override
  Future<void> goOnline() async => goOnlineCalls++;
}

void main() {
  test(
      'the queued teardown removes /live_shares/{token} and lets the socket go again',
      () async {
    final store = InMemoryRealtimeStore(online: false);
    final realtime = _services(store);
    final written = store.set('live_shares/tok',
        {'uid': 'u1', 'expiresAt': 1}); // left by a share the app was killed in
    store.setOnline(true);
    await written;
    store.setOnline(
        false); // a fresh launch: socket down until a lease asks for it
    expect(store.valueAt('live_shares/tok'), isNotNull);
    await removeLiveShareNode(realtime, 'tok');

    expect(store.valueAt('live_shares/tok'), isNull);
    expect(store.goOnlineCalls, greaterThan(0),
        reason: 'a lease brings the socket up for the write');
    expect(realtime.connections.holders, isEmpty,
        reason: 'and is released afterwards');
    realtime.dispose();
  });

  test(
      'with no network it times out (so the outbox retries) and still releases its lease',
      () async {
    final store = _NoNetworkStore();
    final realtime = _services(store);
    await expectLater(
      removeLiveShareNode(realtime, 'tok',
          timeout: const Duration(milliseconds: 50)),
      throwsA(isA<TimeoutException>()),
    );
    expect(realtime.connections.holders, isEmpty);
    realtime.dispose();
  });

  test(
      'a rules rejection is logged, not thrown, so the teardown still delivers',
      () async {
    final store = InMemoryRealtimeStore()..denyPaths.add('live_shares');
    final realtime = _services(store);
    await removeLiveShareNode(realtime, 'tok');
    expect(store.log, isEmpty);
    expect(realtime.connections.holders, isEmpty);
    realtime.dispose();
  });

  test('does nothing when RTDB is not configured', () async {
    final store = InMemoryRealtimeStore(enabled: false);
    await removeLiveShareNode(_services(store), 'tok');
    expect(store.log, isEmpty);
    expect(store.goOnlineCalls, 0);
  });
}
