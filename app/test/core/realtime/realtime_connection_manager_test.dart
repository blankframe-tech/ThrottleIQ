import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/realtime/realtime_connection_manager.dart';

import 'fake_clock.dart';
import 'in_memory_realtime_store.dart';

/// The socket is only up while something holds a lease — the Spark plan's
/// 100-connection cap depends on idle apps actually disconnecting.
void main() {
  late FakeClock clock;
  late InMemoryRealtimeStore store;
  late RealtimeConnectionManager manager;

  setUp(() {
    clock = FakeClock();
    store = InMemoryRealtimeStore(online: false);
    manager = RealtimeConnectionManager(
      store,
      linger: const Duration(seconds: 30),
      timerFactory: clock.timer,
    );
  });

  test('first lease brings the socket up; later leases do not re-connect', () {
    manager.acquire('a');
    manager.acquire('b');
    expect(store.goOnlineCalls, 1);
    expect(store.online, isTrue);
    expect(manager.holders, ['a', 'b']);
  });

  test('goes offline only after the last release, plus the linger', () {
    final a = manager.acquire('a');
    final b = manager.acquire('b');
    a.release();
    clock.elapse(const Duration(minutes: 5));
    expect(store.goOfflineCalls, 0, reason: 'b still holds it');

    b.release();
    clock.elapse(const Duration(seconds: 29));
    expect(store.online, isTrue, reason: 'still lingering');
    clock.elapse(const Duration(seconds: 1));
    expect(store.goOfflineCalls, 1);
    expect(store.online, isFalse);
    expect(manager.isOnline, isFalse);
  });

  test('re-acquiring during the linger cancels the disconnect', () {
    manager.acquire('map').release();
    clock.elapse(const Duration(seconds: 10));
    manager.acquire('cockpit');
    clock.elapse(const Duration(minutes: 2));
    expect(store.goOfflineCalls, 0);
    expect(store.goOnlineCalls, 1, reason: 'never went down, never reconnected');
  });

  test('reconnects after a full linger cycle', () {
    manager.acquire('a').release();
    clock.elapse(const Duration(seconds: 30));
    manager.acquire('a');
    expect(store.goOnlineCalls, 2);
    expect(store.online, isTrue);
  });

  test('release is idempotent — a double release cannot drop someone else', () {
    final a = manager.acquire('a');
    manager.acquire('b');
    a.release();
    a.release();
    clock.elapse(const Duration(minutes: 1));
    expect(store.online, isTrue);
    expect(manager.holders, ['b']);
  });

  test('a disabled store is never asked to connect', () {
    final disabled = InMemoryRealtimeStore(enabled: false, online: false);
    RealtimeConnectionManager(disabled, timerFactory: clock.timer)
        .acquire('x')
        .release();
    clock.elapse(const Duration(minutes: 1));
    expect(disabled.goOnlineCalls, 0);
    expect(disabled.goOfflineCalls, 0);
  });
}
