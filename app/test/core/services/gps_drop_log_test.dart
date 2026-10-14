import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';
import 'package:throttleiq/core/services/gps_drop_log.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('records each ride with its counts and the threshold used', () async {
    await GpsDropLog.record('r1', kept: 900, dropped: 100);
    await GpsDropLog.record('r2', kept: 50, dropped: 0);

    final entries = await GpsDropLog.recent();
    expect(entries.map((e) => e['rideId']), ['r1', 'r2']);
    expect(entries.first['kept'], 900);
    expect(entries.first['dropped'], 100);
    expect(entries.first['thresholdM'], SensorConstants.maxGpsAccuracyM);
  });

  test('keeps only the newest rides', () async {
    for (var i = 0; i < GpsDropLog.keep + 3; i++) {
      await GpsDropLog.record('r$i', kept: i, dropped: 0);
    }
    final entries = await GpsDropLog.recent();
    expect(entries, hasLength(GpsDropLog.keep));
    expect(entries.first['rideId'], 'r3');
    expect(entries.last['rideId'], 'r${GpsDropLog.keep + 2}');
  });

  test('an unreadable stored value reads as empty', () async {
    SharedPreferences.setMockInitialValues({GpsDropLog.prefsKey: 'not json'});
    expect(await GpsDropLog.recent(), isEmpty);
    await GpsDropLog.record('r1', kept: 1, dropped: 1);
    expect(await GpsDropLog.recent(), hasLength(1));
  });
}
