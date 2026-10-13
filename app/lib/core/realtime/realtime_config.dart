/// Where the Realtime Database lives, from build-time `--dart-define`s.
///
/// Empty by default on purpose: the project has no RTDB instance until
/// someone creates one in the console (see
/// DOCS/For Devs and Contributors/architecture/realtime-database.md, "Setup"),
/// and an app pointed at a database that doesn't exist would sit retrying a
/// socket forever. With no URL, `RealtimeStore.isEnabled` is false and every
/// feature stays on Firestore exactly as before.
///
/// ```sh
/// flutter run --dart-define=RTDB_URL=https://throttleiqfb-default-rtdb.asia-southeast1.firebasedatabase.app
/// # local emulator (`firebase emulators:start --only database`):
/// flutter run --dart-define=RTDB_URL=http://127.0.0.1:9000?ns=throttleiqfb \
///             --dart-define=RTDB_EMULATOR_HOST=10.0.2.2:9000
/// ```
class RealtimeConfig {
  const RealtimeConfig({required this.databaseUrl, this.emulatorHost = ''});

  static const RealtimeConfig fromEnvironment = RealtimeConfig(
    databaseUrl: String.fromEnvironment('RTDB_URL'),
    emulatorHost: String.fromEnvironment('RTDB_EMULATOR_HOST'),
  );

  final String databaseUrl;

  /// `host:port` of a database emulator, or empty for the real service.
  final String emulatorHost;

  bool get isEnabled => databaseUrl.isNotEmpty;

  /// [emulatorHost] split for `useDatabaseEmulator`, or null when unset or
  /// malformed (a typo here must not crash startup).
  ({String host, int port})? get emulator {
    final i = emulatorHost.lastIndexOf(':');
    if (i <= 0) return null;
    final port = int.tryParse(emulatorHost.substring(i + 1));
    if (port == null) return null;
    return (host: emulatorHost.substring(0, i), port: port);
  }
}
