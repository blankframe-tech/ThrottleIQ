import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/routes/domain/navigation_progress.dart';
import 'package:throttleiq/features/routes/domain/turn_instruction.dart';

/// Moves [from] by [metres] along [bearingDeg]. Flat-earth approximation —
/// fine at the scale these tests use, and the same helper shape as
/// turn_instruction_test.dart.
LatLng _offset(LatLng from, double bearingDeg, double metres) {
  const metresPerDegLat = 111320.0;
  final rad = bearingDeg * math.pi / 180.0;
  final dLat = (metres * math.cos(rad)) / metresPerDegLat;
  final dLng = (metres * math.sin(rad)) /
      (metresPerDegLat * math.cos(from.latitude * math.pi / 180.0));
  return LatLng(from.latitude + dLat, from.longitude + dLng);
}

const _dhaka = LatLng(23.8103, 90.4125);

/// A straight 1 km line due east, a point every 50 m.
List<LatLng> _straightKm() {
  final points = <LatLng>[_dhaka];
  for (var walked = 50.0; walked <= 1000.0; walked += 50) {
    points.add(_offset(_dhaka, 90, walked));
  }
  return points;
}

/// An L: 500 m east, then 500 m north. Points every 25 m so the simplifier
/// keeps the corner.
List<LatLng> _corner() {
  final points = <LatLng>[_dhaka];
  var current = _dhaka;
  for (var i = 0; i < 20; i++) {
    current = _offset(current, 90, 25);
    points.add(current);
  }
  for (var i = 0; i < 20; i++) {
    current = _offset(current, 0, 25);
    points.add(current);
  }
  return points;
}

void main() {
  group('etaSeconds', () {
    test('is null while stopped or crawling', () {
      expect(etaSeconds(1000, null), isNull);
      expect(etaSeconds(1000, 0), isNull);
      expect(etaSeconds(1000, 0.9), isNull);
    });

    test('divides distance by speed once moving', () {
      expect(etaSeconds(1000, 10), 100);
      expect(etaSeconds(450, 9), 50);
    });

    test('is zero, not negative, at or past the end', () {
      expect(etaSeconds(0, 10), 0);
      expect(etaSeconds(-5, 10), 0);
    });
  });

  group('advanceTurnIndex', () {
    final polyline = _straightKm();
    final turns = buildTurnInstructions(polyline);

    test('a route with no instructions yields -1 rather than throwing', () {
      expect(
        advanceTurnIndex(
            polyline: polyline, turns: const [], position: _dhaka, from: 0),
        -1,
      );
    });

    test('holds on a manoeuvre the rider has not reached yet', () {
      final cornerPoly = _corner();
      final cornerTurns = buildTurnInstructions(cornerPoly);
      // 200 m short of the corner, riding toward it.
      final here = _offset(_dhaka, 90, 300);
      final index = advanceTurnIndex(
          polyline: cornerPoly, turns: cornerTurns, position: here, from: 0);
      expect(index, 1, reason: 'past start, still heading to the corner');
      expect(cornerTurns[index].kind, isNot(TurnKind.arrive));
    });

    test('a turn taken wide still counts as done', () {
      final cornerPoly = _corner();
      final cornerTurns = buildTurnInstructions(cornerPoly);
      final corner = cornerPoly[20];
      // 60 m past the corner and 60 m off the line — outside the 30 m ball
      // the proximity-only rule needed, which is what used to jam the banner
      // on that corner for the rest of the ride.
      final wide = _offset(_offset(corner, 0, 60), 90, 60);
      final index = advanceTurnIndex(
          polyline: cornerPoly, turns: cornerTurns, position: wide, from: 1);
      expect(index, greaterThan(1));
    });

    test('never advances past the final instruction', () {
      final atEnd = polyline.last;
      final index = advanceTurnIndex(
          polyline: polyline, turns: turns, position: atEnd, from: 0);
      expect(index, turns.length - 1);
      // Re-running from the terminus must stay put rather than run off the end.
      expect(
        advanceTurnIndex(
            polyline: polyline, turns: turns, position: atEnd, from: index),
        turns.length - 1,
      );
    });

    test('skips several manoeuvres at once after a gap in fixes', () {
      final cornerPoly = _corner();
      final cornerTurns = buildTurnInstructions(cornerPoly);
      expect(cornerTurns.length, greaterThanOrEqualTo(3),
          reason: 'start + a corner + arrive');

      // A phone that was asleep in a pocket wakes up at the very end. The
      // banner must not still be pointing at the corner the rider is past.
      final index = advanceTurnIndex(
        polyline: cornerPoly,
        turns: cornerTurns,
        position: cornerPoly.last,
        from: 0,
      );
      expect(index, cornerTurns.length - 1);
    });

    test('a from-index past the end is clamped, not trusted', () {
      expect(
        advanceTurnIndex(
            polyline: polyline, turns: turns, position: _dhaka, from: 99),
        turns.length - 1,
      );
    });
  });

  group('computeNavigationProgress', () {
    final polyline = _straightKm();
    final turns = buildTurnInstructions(polyline);

    test('before the first fix the whole route is still ahead', () {
      final p = computeNavigationProgress(
          polyline: polyline, turns: turns, previousTurnIndex: 0);
      expect(p.metresRemaining, closeTo(1000, 5));
      expect(p.metresToTurn, isNull);
      expect(p.offRouteM, isNull);
      expect(p.etaSeconds, isNull);
      expect(p.arrived, isFalse);
      // Unknown is not off-route. Showing the warning before any fix would
      // make every ride start with a red banner.
      expect(p.isOffRoute, isFalse);
    });

    test('remaining distance falls as the rider moves along the line', () {
      final p = computeNavigationProgress(
        polyline: polyline,
        turns: turns,
        previousTurnIndex: 0,
        position: _offset(_dhaka, 90, 400),
        speedMs: 10,
      );
      expect(p.metresRemaining, closeTo(600, 30));
      expect(p.etaSeconds, closeTo(60, 5));
    });

    test('a rider beside the road is on route; one a block away is not', () {
      final onRoute = computeNavigationProgress(
        polyline: polyline,
        turns: turns,
        previousTurnIndex: 0,
        position: _offset(_offset(_dhaka, 90, 400), 0, 20),
      );
      expect(onRoute.isOffRoute, isFalse);
      expect(onRoute.offRouteM, closeTo(20, 5));

      final wandered = computeNavigationProgress(
        polyline: polyline,
        turns: turns,
        previousTurnIndex: 0,
        position: _offset(_offset(_dhaka, 90, 400), 0, 250),
      );
      expect(wandered.isOffRoute, isTrue);
      expect(wandered.offRouteM, closeTo(250, 10));
    });

    test('arriving stops the ETA rather than counting down from zero', () {
      final p = computeNavigationProgress(
        polyline: polyline,
        turns: turns,
        previousTurnIndex: 0,
        position: polyline.last,
        speedMs: 10,
      );
      expect(p.arrived, isTrue);
      expect(p.etaSeconds, isNull);
    });

    test('the manoeuvre pointer only moves forward', () {
      final cornerPoly = _corner();
      final cornerTurns = buildTurnInstructions(cornerPoly);
      final atEnd = computeNavigationProgress(
        polyline: cornerPoly,
        turns: cornerTurns,
        previousTurnIndex: 0,
        position: cornerPoly.last,
      );
      // A rider who doubles back doesn't get the corner re-announced: the
      // pointer is carried in, not recomputed from scratch.
      final doubledBack = computeNavigationProgress(
        polyline: cornerPoly,
        turns: cornerTurns,
        previousTurnIndex: atEnd.turnIndex,
        position: cornerPoly.first,
      );
      expect(doubledBack.turnIndex, atEnd.turnIndex);
    });

    test('an empty polyline is survivable, not a crash', () {
      final p = computeNavigationProgress(
        polyline: const [],
        turns: const [],
        previousTurnIndex: 0,
        position: _dhaka,
      );
      expect(p.turnIndex, -1);
      expect(p.metresRemaining, 0);
      expect(p.isOffRoute, isFalse);
    });
  });
}
