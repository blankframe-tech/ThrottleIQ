import 'dart:async';

/// The write-side sentinel the Realtime Database replaces with its own clock.
///
/// Identical to `ServerValue.timestamp` from `firebase_database`, kept as a
/// plain map so nothing outside `firebase_realtime_store.dart` depends on the
/// plugin — `InMemoryRealtimeStore` in the tests resolves it the same way.
/// `database.rules.json` refuses any location whose `ts` isn't exactly this,
/// so readers can trust `ts` as server time.
const Map<String, String> kRealtimeServerTimestamp = {'.sv': 'timestamp'};

/// The seam between ThrottleIQ and Firebase Realtime Database.
///
/// Only the handful of operations the movement channels need. Paths are
/// slash-separated and relative to the database root
/// (`live_shares/<token>/location`). Every method is safe to call when
/// [isEnabled] is false — it just does nothing — so callers never branch on
/// whether RTDB is configured beyond deciding which transport to trust.
abstract class RealtimeStore {
  /// False when no database URL is configured (see `RealtimeConfig`). The
  /// Firestore paths carry everything in that case.
  bool get isEnabled;

  /// Writes [value] (a map, or a scalar such as `true`) at [path].
  Future<void> set(String path, Object value);

  Future<void> remove(String path);

  /// Live value at [path]: a decoded map/list/scalar, or null when absent.
  /// Errors (e.g. permission denied) are delivered on the stream, never
  /// swallowed — a silent stream is indistinguishable from "nobody moved".
  Stream<Object?> watch(String path);

  /// `.info/connected`: whether this client's WebSocket is up.
  Stream<bool> watchConnected();

  /// `.info/serverTimeOffset` in milliseconds — add to the local clock to
  /// estimate the server's, for staleness against server-stamped `ts`.
  Stream<int> watchServerTimeOffset();

  /// Removes [path] server-side when this client disconnects (killed app,
  /// lost signal, `goOffline`).
  Future<void> removeOnDisconnect(String path);

  Future<void> cancelOnDisconnect(String path);

  Future<void> goOnline();

  Future<void> goOffline();
}

/// What the app uses when RTDB isn't configured: every write is a no-op and
/// the connection never comes up, so the health monitor keeps every feature
/// on its Firestore path.
class DisabledRealtimeStore implements RealtimeStore {
  const DisabledRealtimeStore();

  @override
  bool get isEnabled => false;

  @override
  Future<void> set(String path, Object value) async {}

  @override
  Future<void> remove(String path) async {}

  @override
  Stream<Object?> watch(String path) => const Stream.empty();

  @override
  Stream<bool> watchConnected() => Stream.value(false);

  @override
  Stream<int> watchServerTimeOffset() => Stream.value(0);

  @override
  Future<void> removeOnDisconnect(String path) async {}

  @override
  Future<void> cancelOnDisconnect(String path) async {}

  @override
  Future<void> goOnline() async {}

  @override
  Future<void> goOffline() async {}
}
