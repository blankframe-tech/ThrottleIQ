import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/entities/live_session_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/helpers/live_session_coordinator.dart';

/// The Firestore live-share write gate: a stopped or crawling rider writes
/// at the heartbeat, a moving one every tick, and a status change at once.
void main() {
  final t0 = DateTime(2026, 10, 15, 8);

  // 0.001° of latitude is about 111 m, 0.0005° about 56 m.
  LiveSessionEntity at(int seconds,
          {double? lat = 23.81,
          double? lng = 90.41,
          String token = 'tok',
          LiveSessionStatus status = LiveSessionStatus.riding}) =>
      LiveSessionEntity(
        token: token,
        uid: 'alice',
        rideId: 'ride-1',
        active: true,
        lastLat: lat,
        lastLng: lng,
        status: status,
        updatedAt: t0.add(Duration(seconds: seconds)),
        expiresAt: t0.add(const Duration(hours: 24)),
      );

  test('the first write for a share always goes out', () {
    expect(shouldWriteLiveSession(null, at(0)), isTrue);
  });

  test('a rider who moved under 100 m in one tick is skipped', () {
    expect(shouldWriteLiveSession(at(0), at(10)), isFalse);
    expect(shouldWriteLiveSession(at(0), at(10, lat: 23.8105)), isFalse);
  });

  test('a rider who moved 100 m or more is written every tick', () {
    expect(shouldWriteLiveSession(at(0), at(10, lat: 23.811)), isTrue);
  });

  test('a stopped rider is still written once the heartbeat has passed', () {
    expect(shouldWriteLiveSession(at(0), at(15)), isTrue);
  });

  test('a status change (paused, crash) is written at once', () {
    expect(
        shouldWriteLiveSession(at(0), at(1, status: LiveSessionStatus.paused)),
        isTrue);
    expect(
        shouldWriteLiveSession(at(0), at(1, status: LiveSessionStatus.crash)),
        isTrue);
  });

  test('a new token (re-share) is written at once', () {
    expect(shouldWriteLiveSession(at(0), at(1, token: 'new')), isTrue);
  });

  test('a first GPS fix after a share without one is written at once', () {
    expect(shouldWriteLiveSession(at(0, lat: null, lng: null), at(5)), isTrue);
    expect(
        shouldWriteLiveSession(
            at(0, lat: null, lng: null), at(5, lat: null, lng: null)),
        isFalse);
  });
}
