import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:throttleiq/features/poi_directory/presentation/providers/places_provider.dart';

/// Permission granted, GPS on, but no fresh fix arrives in time.
class _SlowFixGeolocator extends GeolocatorPlatform {
  _SlowFixGeolocator(this.lastKnown);

  final Position? lastKnown;
  LocationSettings? requestedSettings;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requestedSettings = locationSettings;
    throw TimeoutException('no fix', locationSettings?.timeLimit);
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async =>
      lastKnown;
}

Position _pos(double lat, double lon) => Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime(2026),
      accuracy: 30,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  // issues §101.P6: getCurrentPosition had no timeLimit, so a poor fix
  // hung the Places tab spinner.
  test('passes a time limit and falls back to the last known fix', () async {
    final fake = _SlowFixGeolocator(_pos(23.8, 90.4));
    GeolocatorPlatform.instance = fake;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final position = await container.read(currentPositionProvider.future);

    expect(fake.requestedSettings?.timeLimit, currentPositionTimeLimit);
    expect(position.latitude, 23.8);
    expect(position.longitude, 90.4);
  });

  test('still fails when there is no last known fix either', () async {
    GeolocatorPlatform.instance = _SlowFixGeolocator(null);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(currentPositionProvider.future),
      throwsA(isA<TimeoutException>()),
    );
  });
}
