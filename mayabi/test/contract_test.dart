import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:throttleiq_mayabi/throttleiq_mayabi.dart';

/// The upload this package produces, kept as a fixture that the server's
/// validator is tested against (functions/test/partner-scoring.test.js), so
/// the Dart and TypeScript sides can't drift apart silently.
/// Regenerate after a deliberate format change: UPDATE_FIXTURES=1 dart test.
void main() {
  test('recorder output matches test/fixtures/ride_upload.json', () {
    final r = RideRecorder(rideId: 'fixture_ride', riderRef: 'mayabi-fixture');
    final t0 = DateTime.utc(2026, 10, 17, 3);
    var lng = 90.40;
    for (var s = 0; s < 240; s++) {
      if (s == 60) r.phase = RidePhase.onTrip;
      if (s == 180) r.phase = RidePhase.toHome;
      lng += 8 / (111320 * 0.915);
      r.addLocation(
          lat: 23.79,
          lng: lng,
          speedMs: 8,
          accuracyM: 5,
          at: t0.add(Duration(seconds: s)));
    }
    final json = const JsonEncoder.withIndent('  ')
        .convert(r.finish(weatherCode: 3).toJson());
    final file = File('test/fixtures/ride_upload.json');
    if (Platform.environment['UPDATE_FIXTURES'] == '1') {
      file.writeAsStringSync('$json\n');
    }
    expect(json, file.readAsStringSync().trimRight());
  });
}
