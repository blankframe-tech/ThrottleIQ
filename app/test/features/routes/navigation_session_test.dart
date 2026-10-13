import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/routes/presentation/providers/navigation_session_provider.dart';
import 'package:throttleiq/features/social/domain/entities/route_entity.dart';

LatLng _offset(LatLng from, double bearingDeg, double metres) {
  const metresPerDegLat = 111320.0;
  final rad = bearingDeg * math.pi / 180.0;
  final dLat = (metres * math.cos(rad)) / metresPerDegLat;
  final dLng = (metres * math.sin(rad)) /
      (metresPerDegLat * math.cos(from.latitude * math.pi / 180.0));
  return LatLng(from.latitude + dLat, from.longitude + dLng);
}

const _dhaka = LatLng(23.8103, 90.4125);

List<LatLng> _straightKm() {
  final points = <LatLng>[_dhaka];
  for (var walked = 50.0; walked <= 1000.0; walked += 50) {
    points.add(_offset(_dhaka, 90, walked));
  }
  return points;
}

RouteEntity _route({List<LatLng>? polyline}) => RouteEntity(
      id: 'route-1',
      userId: 'alice',
      name: 'Mirpur loop',
      distanceKm: 1.0,
      polyline: polyline ?? _straightKm(),
      createdAt: DateTime(2026, 1, 1),
    );

RideRecordingState _recording({
  RecordingStatus status = RecordingStatus.active,
  LatLng? at,
  double speedMs = 10,
}) =>
    RideRecordingState(
      status: status,
      currentPosition: at,
      currentSpeedMs: speedMs,
    );

void main() {
  group('NavigationSessionNotifier', () {
    late NavigationSessionNotifier notifier;

    setUp(() => notifier = NavigationSessionNotifier());
    tearDown(() => notifier.dispose());

    test('starts inactive and renders nothing', () {
      expect(notifier.state.isActive, isFalse);
      expect(notifier.state.currentTurn, isNull);
      expect(notifier.state.polyline, isEmpty);
    });

    test('start() derives the manoeuvre list once', () {
      notifier.start(_route());
      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.turns, isNotEmpty);
      expect(notifier.state.currentTurn, isNotNull);
      expect(notifier.state.progress.metresRemaining, closeTo(1000, 5));
    });

    test('ignores recording updates while nothing is being navigated', () {
      notifier.onRecordingState(_recording(at: _dhaka));
      expect(notifier.state.isActive, isFalse);
    });

    test('a fix advances progress', () {
      notifier.start(_route());
      notifier.onRecordingState(_recording(at: _offset(_dhaka, 90, 400)));
      expect(notifier.state.progress.metresRemaining, closeTo(600, 30));
      expect(notifier.state.progress.etaSeconds, closeTo(60, 5));
    });

    test('a paused ride freezes guidance instead of stepping on a stale fix',
        () {
      notifier.start(_route());
      notifier.onRecordingState(_recording(at: _offset(_dhaka, 90, 400)));
      final frozen = notifier.state.progress;

      notifier.onRecordingState(_recording(
        status: RecordingStatus.paused,
        at: _offset(_dhaka, 90, 900),
      ));
      expect(notifier.state.progress, frozen);
    });

    test('ending the ride ends guidance', () {
      notifier.start(_route());
      notifier.onRecordingState(_recording(at: _dhaka));
      expect(notifier.state.isActive, isTrue);

      notifier.onRecordingState(_recording(status: RecordingStatus.completed));
      expect(notifier.state.isActive, isFalse);
    });

    test('a discarded ride ends guidance too', () {
      notifier.start(_route());
      notifier.onRecordingState(_recording(status: RecordingStatus.idle));
      expect(notifier.state.isActive, isFalse);
    });

    test('stop() drops guidance without claiming anything about the ride', () {
      notifier.start(_route());
      notifier.stop();
      expect(notifier.state.isActive, isFalse);
      // Idempotent: closing the banner twice is a plausible double-tap.
      notifier.stop();
      expect(notifier.state.isActive, isFalse);
    });

    test('a fix with no position yet is not an update', () {
      notifier.start(_route());
      final before = notifier.state.progress;
      notifier.onRecordingState(_recording(at: null));
      expect(notifier.state.progress, before);
    });

    test('a route with no usable shape stays active but silent', () {
      notifier.start(_route(polyline: const [_dhaka]));
      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.turns, isEmpty);
      expect(notifier.state.currentTurn, isNull);
      // And a fix against it must not throw.
      notifier.onRecordingState(_recording(at: _dhaka));
      expect(notifier.state.currentTurn, isNull);
    });
  });
}
