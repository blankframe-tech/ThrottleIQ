import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'realtime_config.dart';
import 'realtime_store.dart';

/// [RealtimeStore] over the `firebase_database` plugin — the only file that
/// imports it.
///
/// The [FirebaseDatabase] instance is created on first use, not in the
/// constructor: building the provider must not open a socket (or throw, if
/// `Firebase.initializeApp` failed) for a rider who never shares or joins a
/// group ride.
class FirebaseRealtimeStore implements RealtimeStore {
  FirebaseRealtimeStore(this._config);

  final RealtimeConfig _config;
  FirebaseDatabase? _db;

  /// The app whose database this is — overridden by the emulator
  /// integration test to stand up a second, independent socket.
  @protected
  FirebaseApp get firebaseApp => Firebase.app();

  FirebaseDatabase get _database {
    final existing = _db;
    if (existing != null) return existing;
    final db = FirebaseDatabase.instanceFor(
      app: firebaseApp,
      databaseURL: _config.databaseUrl,
    );
    final emulator = _config.emulator;
    if (emulator != null) db.useDatabaseEmulator(emulator.host, emulator.port);
    // Positions are worthless once stale; never replay a backlog of them
    // from disk after a cold start.
    db.setPersistenceEnabled(false);
    return _db = db;
  }

  @override
  bool get isEnabled => _config.isEnabled;

  @override
  Future<void> set(String path, Object value) =>
      _database.ref(path).set(value);

  @override
  Future<void> remove(String path) => _database.ref(path).remove();

  @override
  Stream<Object?> watch(String path) => _database
      .ref(path)
      .onValue
      .map((event) => normalizeRealtimeValue(event.snapshot.value));

  @override
  Stream<bool> watchConnected() => _database
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  @override
  Stream<int> watchServerTimeOffset() => _database
      .ref('.info/serverTimeOffset')
      .onValue
      .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);

  @override
  Future<void> removeOnDisconnect(String path) =>
      _database.ref(path).onDisconnect().remove();

  @override
  Future<void> cancelOnDisconnect(String path) =>
      _database.ref(path).onDisconnect().cancel();

  @override
  Future<void> goOnline() => _database.goOnline();

  @override
  Future<void> goOffline() => _database.goOffline();
}

/// The plugin hands back `Map<Object?, Object?>` (and, for integer-keyed
/// children, sometimes a `List`). Everything downstream wants
/// `Map<String, Object?>`, recursively.
Object? normalizeRealtimeValue(Object? raw) {
  if (raw is Map) {
    return {
      for (final entry in raw.entries)
        entry.key.toString(): normalizeRealtimeValue(entry.value),
    };
  }
  if (raw is List) {
    return {
      for (var i = 0; i < raw.length; i++)
        if (raw[i] != null) '$i': normalizeRealtimeValue(raw[i]),
    };
  }
  return raw;
}
