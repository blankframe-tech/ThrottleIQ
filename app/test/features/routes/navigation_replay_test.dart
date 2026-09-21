import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';
import 'package:throttleiq/features/routes/domain/navigation_progress.dart';
import 'package:throttleiq/features/routes/domain/turn_instruction.dart';
import 'package:throttleiq/features/routes/presentation/providers/navigation_session_provider.dart';
import 'package:throttleiq/features/social/domain/entities/route_entity.dart';

import 'gpx_replay.dart';

/// Riding a saved route, one GPS fix at a time (issues §78.21).
///
/// Every other test in this directory checks one function against one
/// position. This one replays a whole trail through the session the cockpit
/// actually uses, which is where the interesting failures live: guidance that
/// jams on a corner, an off-route warning that never clears, a banner that
/// finishes the route still pointing at turn 2.
void main() {
  // `flutter test` runs with the package root as the working directory.
  const fixture = 'test/features/routes/fixtures/dhaka_zigzag.gpx';

  late List<GpxFix> track;
  late RouteEntity route;

  setUpAll(() {
    track = readGpx(fixture);
    route = RouteEntity(
      id: 'route-zigzag',
      userId: 'alice',
      name: 'Dhaka zigzag',
      distanceKm: 1.7,
      polyline: [for (final f in track) f.position],
      createdAt: DateTime(2026, 9, 21),
    );
  });

  /// Replays [fixes] and returns the progress after each one.
  List<NavigationProgress> replay(
    NavigationSessionNotifier notifier,
    List<GpxFix> fixes, {
    RecordingStatus status = RecordingStatus.active,
  }) {
    final seen = <NavigationProgress>[];
    for (final fix in fixes) {
      notifier.onRecordingState(RideRecordingState(
        status: status,
        currentPosition: fix.position,
        currentSpeedMs: fix.speedMs,
      ));
      seen.add(notifier.state.progress);
    }
    return seen;
  }

  late NavigationSessionNotifier notifier;
  setUp(() {
    notifier = NavigationSessionNotifier()..start(route);
  });
  tearDown(() => notifier.dispose());

  test('the fixture is the shape the rest of these tests assume', () {
    expect(track.length, greaterThan(100));
    final turns = buildTurnInstructions(route.polyline);
    final manoeuvres = turns
        .where((t) => t.kind != TurnKind.start && t.kind != TurnKind.arrive)
        .length;
    expect(manoeuvres, greaterThanOrEqualTo(2),
        reason: 'a route with no corners would prove nothing about guidance');
  });

  group('riding the route as recorded', () {
    test('guidance reaches the end and never goes backwards', () {
      final seen = replay(notifier, track);

      for (var i = 1; i < seen.length; i++) {
        expect(seen[i].turnIndex, greaterThanOrEqualTo(seen[i - 1].turnIndex),
            reason: 'the manoeuvre pointer stepped back at fix $i');
      }
      expect(seen.last.turnIndex, notifier.state.turns.length - 1,
          reason: 'finished the route still pointing at an earlier turn');
      expect(seen.last.arrived, isTrue);
    });

    test('every manoeuvre is shown at some point, none skipped over', () {
      final reached = replay(notifier, track).map((p) => p.turnIndex).toSet();
      // From 1, not 0: index 0 is `start` ("Head north-east"), and the first
      // fix of a ride is already at the start point, so the banner is past it
      // before it could ever be read. That instruction is the rider's to see
      // on the pre-flight screen, which is where RouteNavigationScreen shows
      // it — not something the cockpit drops.
      expect(
          reached,
          containsAll(List.generate(
              notifier.state.turns.length - 1, (i) => i + 1)),
          reason: 'a turn the banner never displayed is a turn the rider '
              'never got told about');
    });

    test('no off-route warning while riding the line it was recorded from', () {
      final seen = replay(notifier, track);
      final offRoute = seen.where((p) => p.isOffRoute).length;
      expect(offRoute, 0,
          reason: 'GPS jitter alone must not trip the warning — a banner that '
              'cries wolf is one riders learn to ignore');
    });

    test('distance remaining falls monotonically, within jitter', () {
      final seen = replay(notifier, track);
      for (var i = 1; i < seen.length; i++) {
        // Jitter can nudge the nearest-point match one vertex backwards; a
        // whole fix's worth of travel cannot.
        expect(seen[i].metresRemaining,
            lessThanOrEqualTo(seen[i - 1].metresRemaining + 20),
            reason: 'remaining distance grew at fix $i');
      }
      expect(seen.first.metresRemaining, greaterThan(1000));
      expect(seen.last.metresRemaining, lessThan(kArrivedM));
    });

    test('an ETA is offered throughout, and withdrawn on arrival', () {
      final seen = replay(notifier, track);
      // Moving at ~30 km/h the whole way, so an ETA is always computable
      // until the rider is inside the arrival radius — at which point a
      // countdown to somewhere you already are is noise, not information.
      expect(seen.where((p) => !p.arrived).every((p) => p.etaSeconds != null),
          isTrue);
      expect(seen.where((p) => p.arrived), isNotEmpty);
      expect(seen.where((p) => p.arrived).every((p) => p.etaSeconds == null),
          isTrue);
      expect(seen.last.etaSeconds, isNull);
    });
  });

  group('when the ride does not go to plan', () {
    test('a detour raises the warning and rejoining clears it', () {
      // South off the first leg, which is the bottom edge of the zigzag —
      // so the detour can't wander back within range of a later leg. (An
      // earlier version of this test pushed north off the second leg and
      // silently re-crossed the first, which is its own useful reminder that
      // "off route" is a distance to the whole line, not to one segment.)
      final detoured = withDetour(track,
          fromIndex: 20, toIndex: 45, bearingDeg: 180, metres: 250);
      final seen = replay(notifier, detoured);

      expect(seen.sublist(22, 43).every((p) => p.isOffRoute), isTrue,
          reason: 'a rider 250 m off the line should be told so');
      expect(seen.last.isOffRoute, isFalse,
          reason: 'and should stop being told once they are back on it');
      expect(seen.last.arrived, isTrue,
          reason: 'a detour must not abandon the route');
    });

    test('a detour does not rewind the manoeuvre pointer', () {
      final detoured = withDetour(track,
          fromIndex: 20, toIndex: 45, bearingDeg: 180, metres: 250);
      final seen = replay(notifier, detoured);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i].turnIndex, greaterThanOrEqualTo(seen[i - 1].turnIndex));
      }
    });

    test('corners taken wide still advance the banner', () {
      // 45 m off the recorded line for the whole ride — inside the off-route
      // threshold, outside the 30 m "reached" ball that the pointer used to
      // depend on. This is the regression that jammed guidance on a corner.
      final wide = [
        for (final f in track)
          (position: offsetMetres(f.position, 45, 45), speedMs: f.speedMs)
      ];
      final seen = replay(notifier, wide);
      expect(seen.last.turnIndex, notifier.state.turns.length - 1);
    });

    test('a gap in fixes catches guidance up rather than stranding it', () {
      // One fix in every twenty: a phone asleep in a pocket, or a tunnel.
      final sparse = decimated(track, 20);
      final seen = replay(notifier, sparse);
      expect(seen.last.turnIndex, notifier.state.turns.length - 1);
      expect(seen.last.arrived, isTrue);
    });

    test('pausing mid-route freezes guidance until the ride resumes', () {
      final firstHalf = track.take(60).toList();
      replay(notifier, firstHalf);
      final atPause = notifier.state.progress;

      // Fixes that arrive while paused are stale by definition — pauseRide()
      // suspends the location subscription.
      replay(notifier, track.skip(60).take(40).toList(),
          status: RecordingStatus.paused);
      expect(notifier.state.progress, atPause);

      // Resuming picks straight back up.
      replay(notifier, track.skip(60).toList());
      expect(notifier.state.progress.arrived, isTrue);
    });

    test('ending the ride mid-route ends guidance, and it stays ended', () {
      replay(notifier, track.take(60).toList());
      expect(notifier.state.isActive, isTrue);

      notifier.onRecordingState(
          const RideRecordingState(status: RecordingStatus.completed));
      expect(notifier.state.isActive, isFalse);

      // Late fixes from a torn-down stream must not revive a finished session.
      replay(notifier, track.skip(60).take(10).toList());
      expect(notifier.state.isActive, isFalse);
    });
  });

  group('the GPX reader itself', () {
    test('reads position and speed off every trackpoint', () {
      expect(track.first.position.latitude, closeTo(23.81, 0.01));
      expect(track.first.position.longitude, closeTo(90.41, 0.01));
      expect(track.first.speedMs, closeTo(8.3, 0.01));
    });

    test('falls back to a plausible speed when a file omits it', () {
      // Points with no <speed> would otherwise read as "stopped", which
      // suppresses the ETA and would hollow out every test above.
      const noSpeed = '''
<gpx><trk><trkseg>
  <trkpt lat="23.81" lon="90.41"></trkpt>
</trkseg></trk></gpx>''';
      final file = File('${Directory.systemTemp.path}/tiq_no_speed.gpx')
        ..writeAsStringSync(noSpeed);
      addTearDown(() => file.deleteSync());
      expect(readGpx(file.path, defaultSpeedMs: 9.0).single.speedMs, 9.0);
    });

    test('says so loudly when handed something that is not a track', () {
      final file = File('${Directory.systemTemp.path}/tiq_empty.gpx')
        ..writeAsStringSync('<gpx></gpx>');
      addTearDown(() => file.deleteSync());
      expect(() => readGpx(file.path), throwsStateError);
    });
  });
}
