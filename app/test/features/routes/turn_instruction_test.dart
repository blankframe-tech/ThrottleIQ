import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/routes/domain/turn_instruction.dart';

/// Builds a polyline by walking [legs] of (bearing, metres) from [start],
/// emitting a point every ~30 m so the simplifier keeps real corners but the
/// legs still read as straight stretches.
List<LatLng> _path(LatLng start, List<(double bearing, double metres)> legs) {
  final points = <LatLng>[start];
  var current = start;
  for (final (bearing, metres) in legs) {
    const step = 30.0;
    var walked = 0.0;
    while (walked < metres) {
      final d = (metres - walked) < step ? (metres - walked) : step;
      current = _offset(current, bearing, d);
      points.add(current);
      walked += d;
    }
  }
  return points;
}

/// Moves [from] by [metres] along [bearingDeg]. Flat-earth approximation —
/// fine at the scale these tests use (hundreds of metres).
LatLng _offset(LatLng from, double bearingDeg, double metres) {
  const metresPerDegLat = 111320.0;
  final rad = bearingDeg * math.pi / 180.0;
  final dLat = (metres * math.cos(rad)) / metresPerDegLat;
  final dLng = (metres * math.sin(rad)) /
      (metresPerDegLat * math.cos(from.latitude * math.pi / 180.0));
  return LatLng(from.latitude + dLat, from.longitude + dLng);
}

const _dhaka = LatLng(23.8103, 90.4125);

void main() {
  group('bearingDegrees', () {
    test('cardinal directions', () {
      expect(bearingDegrees(_dhaka, _offset(_dhaka, 0, 200)), closeTo(0, 1));
      expect(bearingDegrees(_dhaka, _offset(_dhaka, 90, 200)), closeTo(90, 1));
      expect(bearingDegrees(_dhaka, _offset(_dhaka, 180, 200)), closeTo(180, 1));
      expect(bearingDegrees(_dhaka, _offset(_dhaka, 270, 200)), closeTo(270, 1));
    });

    test('always returns 0-360, never negative', () {
      for (var b = 0; b < 360; b += 15) {
        final result = bearingDegrees(_dhaka, _offset(_dhaka, b.toDouble(), 200));
        expect(result, greaterThanOrEqualTo(0));
        expect(result, lessThan(360));
      }
    });
  });

  group('normalizeBearingDelta', () {
    test('leaves small deltas alone', () {
      expect(normalizeBearingDelta(0), closeTo(0, 1e-9));
      expect(normalizeBearingDelta(45), closeTo(45, 1e-9));
      expect(normalizeBearingDelta(-45), closeTo(-45, 1e-9));
    });

    // The wraparound case: heading 350 -> 10 is a 20 degree RIGHT turn, not a
    // 340 degree left one. Getting this wrong inverts turns near due north.
    test('wraps across the 0/360 boundary the short way', () {
      expect(normalizeBearingDelta(340), closeTo(-20, 1e-9));
      expect(normalizeBearingDelta(-340), closeTo(20, 1e-9));
      expect(normalizeBearingDelta(359), closeTo(-1, 1e-9));
    });

    test('maps to (-180, 180]', () {
      for (var d = -720; d <= 720; d += 7) {
        final n = normalizeBearingDelta(d.toDouble());
        expect(n, greaterThan(-180.0000001));
        expect(n, lessThanOrEqualTo(180.0000001));
      }
    });
  });

  group('classifyBearingDelta', () {
    test('small changes are straight', () {
      expect(classifyBearingDelta(0), TurnKind.straight);
      expect(classifyBearingDelta(10), TurnKind.straight);
      expect(classifyBearingDelta(-19), TurnKind.straight);
    });

    test('right-hand deltas are right turns, scaled by severity', () {
      expect(classifyBearingDelta(30), TurnKind.slightRight);
      expect(classifyBearingDelta(90), TurnKind.right);
      expect(classifyBearingDelta(140), TurnKind.sharpRight);
    });

    test('left-hand deltas mirror them', () {
      expect(classifyBearingDelta(-30), TurnKind.slightLeft);
      expect(classifyBearingDelta(-90), TurnKind.left);
      expect(classifyBearingDelta(-140), TurnKind.sharpLeft);
    });

    test('doubling back is a U-turn either way', () {
      expect(classifyBearingDelta(175), TurnKind.uTurn);
      expect(classifyBearingDelta(-175), TurnKind.uTurn);
      expect(classifyBearingDelta(180), TurnKind.uTurn);
    });
  });

  group('buildTurnInstructions', () {
    test('returns nothing for a degenerate polyline', () {
      expect(buildTurnInstructions(const []), isEmpty);
      expect(buildTurnInstructions([_dhaka]), isEmpty);
    });

    test('a straight line yields only start and arrive', () {
      final line = _path(_dhaka, [(90, 1000)]);
      final turns = buildTurnInstructions(line);

      expect(turns.first.kind, TurnKind.start);
      expect(turns.last.kind, TurnKind.arrive);
      expect(
        turns.where((t) =>
            t.kind != TurnKind.start && t.kind != TurnKind.arrive),
        isEmpty,
        reason: 'a straight road should produce no manoeuvres',
      );
    });

    test('a right-angle right turn is detected', () {
      // East 500 m, then south 500 m — a 90 degree right.
      final line = _path(_dhaka, [(90, 500), (180, 500)]);
      final turns = buildTurnInstructions(line);
      final manoeuvres = turns
          .where((t) => t.kind != TurnKind.start && t.kind != TurnKind.arrive)
          .toList();

      expect(manoeuvres, hasLength(1));
      expect(manoeuvres.single.kind, TurnKind.right);
      expect(manoeuvres.single.text, 'Turn right');
    });

    test('a right-angle left turn is detected', () {
      // East 500 m, then north 500 m — a 90 degree left.
      final line = _path(_dhaka, [(90, 500), (0, 500)]);
      final manoeuvres = buildTurnInstructions(line)
          .where((t) => t.kind != TurnKind.start && t.kind != TurnKind.arrive)
          .toList();

      expect(manoeuvres, hasLength(1));
      expect(manoeuvres.single.kind, TurnKind.left);
    });

    test('doubling back yields a U-turn', () {
      final line = _path(_dhaka, [(90, 500), (270, 500)]);
      final kinds = buildTurnInstructions(line).map((t) => t.kind).toList();

      expect(kinds, contains(TurnKind.uTurn));
    });

    test('always starts with start and ends with arrive', () {
      final line = _path(_dhaka, [(90, 400), (180, 400), (270, 400)]);
      final turns = buildTurnInstructions(line);

      expect(turns.first.kind, TurnKind.start);
      expect(turns.last.kind, TurnKind.arrive);
      expect(turns.last.text, 'You have arrived');
    });

    test('distanceFromStart increases monotonically', () {
      final line = _path(_dhaka, [(90, 400), (180, 400), (270, 400)]);
      final turns = buildTurnInstructions(line);

      for (var i = 1; i < turns.length; i++) {
        expect(
          turns[i].distanceFromStartM,
          greaterThanOrEqualTo(turns[i - 1].distanceFromStartM),
        );
      }
      expect(turns.first.distanceFromStartM, 0);
    });

    // pointIndex must address the ORIGINAL polyline, since the navigation
    // screen looks the coordinate back up in the line it is drawing.
    test('pointIndex stays in range of the original polyline', () {
      final line = _path(_dhaka, [(90, 400), (180, 400)]);
      final turns = buildTurnInstructions(line);

      for (final t in turns) {
        expect(t.pointIndex, greaterThanOrEqualTo(0));
        expect(t.pointIndex, lessThan(line.length));
      }
      expect(turns.last.pointIndex, line.length - 1);
    });
  });

  group('nearestPointOnPolyline', () {
    test('returns null for an empty polyline', () {
      expect(nearestPointOnPolyline(const [], _dhaka), isNull);
    });

    test('finds the closest point and its distance', () {
      final line = _path(_dhaka, [(90, 300)]);
      final result = nearestPointOnPolyline(line, line[3]);

      expect(result, isNotNull);
      expect(result!.index, 3);
      expect(result.distanceM, closeTo(0, 1));
    });

    test('reports the off-route distance for a point beside the line', () {
      final line = _path(_dhaka, [(90, 300)]);
      final aside = _offset(line[2], 0, 150); // 150 m north of the route
      final result = nearestPointOnPolyline(line, aside)!;

      expect(result.distanceM, closeTo(150, 25));
    });
  });

  group('remainingDistanceM', () {
    test('is zero at or past the final point', () {
      final line = _path(_dhaka, [(90, 300)]);
      expect(remainingDistanceM(line, line.length - 1), 0);
      expect(remainingDistanceM(line, line.length + 5), 0);
    });

    test('is the full length from the start', () {
      final line = _path(_dhaka, [(90, 300)]);
      expect(remainingDistanceM(line, 0), closeTo(300, 15));
    });

    test('shrinks as the rider advances', () {
      final line = _path(_dhaka, [(90, 600)]);
      final atStart = remainingDistanceM(line, 0);
      final halfway = remainingDistanceM(line, line.length ~/ 2);

      expect(halfway, lessThan(atStart));
    });

    test('handles a degenerate polyline', () {
      expect(remainingDistanceM(const [], 0), 0);
      expect(remainingDistanceM([_dhaka], 0), 0);
    });
  });
}
