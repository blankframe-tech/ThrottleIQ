/// Drives the real `firebase_database` plugin — the app's actual WebSocket
/// client — against the local emulators. The JS suites in scripts/test/rtdb
/// prove the rules and the emulator's socket; this proves the Flutter plugin
/// path through `FirebaseRealtimeStore` on a real device.
///
/// ```sh
/// # repo root
/// firebase emulators:start --only auth,database --project=throttleiq-rtdb-test
/// # app/ — Android emulator reaches the host at 10.0.2.2
/// flutter test integration_test/realtime_emulator_test.dart \
///   --dart-define=RTDB_URL=http://10.0.2.2:9000?ns=throttleiq-rtdb-test \
///   --dart-define=RTDB_EMULATOR_HOST=10.0.2.2:9000 \
///   --dart-define=AUTH_EMULATOR_HOST=10.0.2.2:9099
/// ```
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:throttleiq/core/realtime/firebase_realtime_store.dart';
import 'package:throttleiq/core/realtime/realtime_config.dart';
import 'package:throttleiq/core/realtime/realtime_health.dart';
import 'package:throttleiq/core/realtime/realtime_location.dart';
import 'package:throttleiq/core/realtime/realtime_location_publisher.dart';
import 'package:throttleiq/firebase_options.dart';

const _authEmulator = String.fromEnvironment('AUTH_EMULATOR_HOST');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const config = RealtimeConfig.fromEnvironment;

  late FirebaseApp writerApp;
  late FirebaseApp readerApp;
  late FirebaseRealtimeStore writer;
  late FirebaseRealtimeStore reader;
  late String uid;

  setUpAll(() async {
    if (!config.isEnabled || config.emulator == null) {
      fail('Run with --dart-define=RTDB_URL=… and RTDB_EMULATOR_HOST=… '
          '(see the header of this file). Refusing to touch production.');
    }
    writerApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // A second app instance = a second, independent socket: the live viewer.
    readerApp = await Firebase.initializeApp(
      name: 'rtdb-reader',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instanceFor(app: writerApp);
    final i = _authEmulator.lastIndexOf(':');
    await auth.useAuthEmulator(
        _authEmulator.substring(0, i), int.parse(_authEmulator.substring(i + 1)));
    uid = (await auth.signInAnonymously()).user!.uid;

    writer = FirebaseRealtimeStore(config);
    reader = _StoreForApp(config, readerApp);
  });

  testWidgets('writer and reader sockets both come up', (tester) async {
    expect(await writer.watchConnected().firstWhere((c) => c), isTrue);
    expect(await reader.watchConnected().firstWhere((c) => c), isTrue);
  });

  testWidgets('a 1 Hz live-share stream reaches an unauthenticated reader in order',
      (tester) async {
    final token = 'it${DateTime.now().microsecondsSinceEpoch}'.padRight(40, 'x');
    await writer.set('live_shares/$token', {
      'uid': uid,
      'expiresAt':
          DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    });

    final stats = RealtimeDeliveryStats();
    final latencies = <Duration>[];
    var offsetMs = 0;
    final offsetSub =
        reader.watchServerTimeOffset().listen((o) => offsetMs = o);
    final received = Completer<void>();
    const count = 10;
    final sub = reader.watch('live_shares/$token/location').listen((raw) {
      final loc = RealtimeLocation.tryParse(raw);
      if (loc == null || !stats.observe('w', loc.seq)) return;
      final age = loc.ageAt(DateTime.now(), serverTimeOffsetMs: offsetMs);
      if (age != null) latencies.add(age);
      if (loc.seq == count - 1 && !received.isCompleted) received.complete();
    });

    final publisher = RealtimeLocationPublisher(
      store: writer,
      path: 'live_shares/$token/location',
      minInterval: Duration.zero,
    );
    for (var i = 0; i < count; i++) {
      publisher.offer(LocationSample(lat: 23.8 + i * 0.0001, lng: 90.4));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await received.future.timeout(const Duration(seconds: 10));
    await sub.cancel();
    await offsetSub.cancel();
    await publisher.stop(removePath: 'live_shares/$token');

    expect(stats.outOfOrder, 0);
    latencies.sort();
    final p95 = latencies[(latencies.length * 0.95).ceil() - 1];
    // ignore: avoid_print
    print('[rtdb-it] $stats p95=${p95.inMilliseconds}ms');
    expect(p95, lessThan(const Duration(seconds: 2)));
  });

  testWidgets('.info/connected follows goOffline / goOnline', (tester) async {
    final states = <bool>[];
    final sub = writer.watchConnected().listen(states.add);
    await writer.watchConnected().firstWhere((c) => c);
    await writer.goOffline();
    await writer.watchConnected().firstWhere((c) => !c);
    await writer.goOnline();
    await writer.watchConnected().firstWhere((c) => c);
    await sub.cancel();
    expect(states, containsAllInOrder([true, false, true]));
  });

  testWidgets('onDisconnect().remove() clears typing when the writer drops',
      (tester) async {
    final chatId = '${uid}_zzzz-peer';
    final path = 'chat_presence/$chatId/$uid';
    await writer.removeOnDisconnect(path);
    await writer.set(path, {'typing': true, 'ts': const {'.sv': 'timestamp'}});
    await writer.goOffline();
    // The writer can still read its own local cache; the server copy is gone
    // once it's back.
    await writer.goOnline();
    final value = await writer
        .watch(path)
        .firstWhere((v) => v == null)
        .timeout(const Duration(seconds: 10));
    expect(value, isNull);
  });
}

/// [FirebaseRealtimeStore] bound to a non-default app, for the reader.
class _StoreForApp extends FirebaseRealtimeStore {
  _StoreForApp(super.config, this.app);
  final FirebaseApp app;

  @override
  FirebaseApp get firebaseApp => app;
}
