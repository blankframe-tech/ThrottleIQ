import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_realtime_store.dart';
import 'realtime_config.dart';
import 'realtime_connection_manager.dart';
import 'realtime_health.dart';
import 'realtime_store.dart';

/// Everything a feature needs to use the RTDB movement channel, as one
/// object: the store, the socket lease, and the health monitor that decides
/// whether to trust it.
class RealtimeServices {
  RealtimeServices({
    required this.store,
    required this.connections,
    required this.health,
  });

  /// Wiring for when RTDB isn't configured — and the default in tests.
  factory RealtimeServices.disabled() {
    const store = DisabledRealtimeStore();
    return RealtimeServices(
      store: store,
      connections: RealtimeConnectionManager(store),
      health: RealtimeHealthMonitor(store),
    );
  }

  final RealtimeStore store;
  final RealtimeConnectionManager connections;
  final RealtimeHealthMonitor health;

  bool get isEnabled => store.isEnabled;

  /// Brings the socket up for [tag] and starts health monitoring (which
  /// waits for the first lease so that merely building the provider never
  /// opens a connection).
  RealtimeLease acquire(String tag) {
    final lease = connections.acquire(tag);
    health.start();
    return lease;
  }

  RealtimeTransport transportNow() => health.transportNow();

  void dispose() {
    connections.dispose();
    health.dispose();
  }
}

final realtimeServicesProvider = Provider<RealtimeServices>((ref) {
  const config = RealtimeConfig.fromEnvironment;
  final services = config.isEnabled
      ? () {
          final store = FirebaseRealtimeStore(config);
          return RealtimeServices(
            store: store,
            connections: RealtimeConnectionManager(store),
            health: RealtimeHealthMonitor(store),
          );
        }()
      : RealtimeServices.disabled();
  ref.onDispose(services.dispose);
  return services;
});

/// Live [RealtimeHealth], for "Live" / "Delayed" badges.
final realtimeHealthProvider = StreamProvider.autoDispose<RealtimeHealth>((ref) {
  final health = ref.watch(realtimeServicesProvider).health;
  return health.changes.startWithValue(health.current);
});

extension<T> on Stream<T> {
  Stream<T> startWithValue(T value) async* {
    yield value;
    yield* this;
  }
}
