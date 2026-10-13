import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/realtime/firebase_realtime_store.dart';
import 'package:throttleiq/core/realtime/realtime_config.dart';
import 'package:throttleiq/core/realtime/realtime_location.dart';
import 'package:throttleiq/core/realtime/realtime_store.dart';

void main() {
  group('RealtimeLocation wire shape', () {
    // Mirrors database.rules.json's location `.validate` — the rules refuse
    // any other key, so a field added here without a rules change would get
    // every write rejected.
    const allowed = {'lat', 'lng', 'ts', 'seq', 'speedMs', 'headingDeg', 'accuracyM'};

    test('writes only keys the rules accept, with the server-ts sentinel', () {
      final map = const RealtimeLocation(
        lat: 23.8,
        lng: 90.4,
        seq: 3,
        speedMs: 7.5,
        headingDeg: 90,
        accuracyM: 4,
      ).toWrite();
      expect(allowed.containsAll(map.keys), isTrue);
      expect(map.keys, containsAll(['lat', 'lng', 'ts', 'seq']));
      expect(map['ts'], kRealtimeServerTimestamp);
    });

    test('drops a negative speed/accuracy rather than send a refused write', () {
      final map = const RealtimeLocation(
        lat: 1,
        lng: 1,
        seq: 0,
        speedMs: -1,
        accuracyM: -1,
      ).toWrite();
      expect(map.containsKey('speedMs'), isFalse);
      expect(map.containsKey('accuracyM'), isFalse);
    });

    test('round-trips through what the server returns', () {
      final parsed = RealtimeLocation.tryParse({
        'lat': 23.8,
        'lng': 90.4,
        'seq': 12,
        'ts': 1791000000000,
        'speedMs': 3,
      })!;
      expect(parsed.seq, 12);
      expect(parsed.speedMs, 3.0);
      expect(parsed.serverTime!.millisecondsSinceEpoch, 1791000000000);
    });

    test('rejects malformed values instead of throwing', () {
      expect(RealtimeLocation.tryParse(null), isNull);
      expect(RealtimeLocation.tryParse('x'), isNull);
      expect(RealtimeLocation.tryParse({'lat': 1, 'lng': 2}), isNull);
      expect(RealtimeLocation.tryParse({'lat': '1', 'lng': 2, 'seq': 0}), isNull);
    });

    test('age uses the server clock offset and never goes negative', () {
      final ts = DateTime.utc(2026, 10, 7, 9);
      final loc = RealtimeLocation(lat: 0, lng: 0, seq: 0, serverTime: ts);
      final local = ts.add(const Duration(seconds: 3));
      expect(loc.ageAt(local), const Duration(seconds: 3));
      // Phone clock 2 s behind the server.
      expect(loc.ageAt(local, serverTimeOffsetMs: 2000),
          const Duration(seconds: 5));
      expect(loc.ageAt(ts.subtract(const Duration(seconds: 9))), Duration.zero);
    });
  });

  group('normalizeRealtimeValue', () {
    test('turns plugin maps into string-keyed maps, recursively', () {
      final out = normalizeRealtimeValue(<Object?, Object?>{
        'a': <Object?, Object?>{'b': 1},
      });
      expect(out, {
        'a': {'b': 1},
      });
      expect(out, isA<Map<String, Object?>>());
    });

    test('integer-keyed lists come back as maps without holes', () {
      expect(normalizeRealtimeValue([null, 'x', 'y']), {'1': 'x', '2': 'y'});
    });
  });

  group('RealtimeConfig', () {
    test('disabled without a URL — the shipped default', () {
      expect(const RealtimeConfig(databaseUrl: '').isEnabled, isFalse);
      expect(RealtimeConfig.fromEnvironment.isEnabled, isFalse,
          reason: 'tests run without --dart-define=RTDB_URL');
    });

    test('parses the emulator host, ignoring garbage', () {
      expect(
        const RealtimeConfig(databaseUrl: 'x', emulatorHost: '10.0.2.2:9000')
            .emulator,
        (host: '10.0.2.2', port: 9000),
      );
      expect(
          const RealtimeConfig(databaseUrl: 'x', emulatorHost: 'nope').emulator,
          isNull);
      expect(
          const RealtimeConfig(databaseUrl: 'x', emulatorHost: 'h:abc').emulator,
          isNull);
    });
  });
}
