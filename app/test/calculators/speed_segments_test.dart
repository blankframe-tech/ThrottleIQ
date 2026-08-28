import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/speed_segments.dart';

void main() {
  group('speedBandForKmh', () {
    test('buckets at the documented cutoffs', () {
      expect(speedBandForKmh(0), SpeedBand.idle);
      expect(speedBandForKmh(4.9), SpeedBand.idle);
      expect(speedBandForKmh(5), SpeedBand.normal);
      expect(speedBandForKmh(49.9), SpeedBand.normal);
      expect(speedBandForKmh(50), SpeedBand.brisk);
      expect(speedBandForKmh(89.9), SpeedBand.brisk);
      expect(speedBandForKmh(90), SpeedBand.hard);
      expect(speedBandForKmh(200), SpeedBand.hard);
    });
  });

  group('buildSpeedSegments', () {
    test('needs at least two points', () {
      expect(buildSpeedSegments<int>([], []), isEmpty);
      expect(buildSpeedSegments<int>([1], [10]), isEmpty);
    });

    test('mismatched list lengths return no segments rather than crash', () {
      expect(buildSpeedSegments<int>([1, 2, 3], [10, 10]), isEmpty);
    });

    test('a uniform-speed ride is a single segment', () {
      final points = [0, 1, 2, 3, 4];
      final speedsMs = List.filled(5, 10.0); // 36 km/h -> normal
      final segments = buildSpeedSegments(points, speedsMs);
      expect(segments, hasLength(1));
      expect(segments.single.band, SpeedBand.normal);
      expect(segments.single.points, points);
    });

    test('splits into a new segment at every band change, sharing the boundary point', () {
      final points = [0, 1, 2, 3];
      // idle (0 km/h), idle, hard (100 km/h), hard
      final speedsMs = [0.0, 0.0, 27.8, 27.8];
      final segments = buildSpeedSegments(points, speedsMs);

      expect(segments, hasLength(2));
      expect(segments[0].band, SpeedBand.idle);
      expect(segments[0].points, [0, 1, 2]);
      expect(segments[1].band, SpeedBand.hard);
      // Boundary point (2) is repeated so the drawn line has no gap.
      expect(segments[1].points, [2, 3]);
    });

    test('a road that goes idle -> normal -> brisk -> hard -> back to normal produces four segments', () {
      final points = [0, 1, 2, 3, 4];
      final speedsMs = [0.0, 10.0, 20.0, 30.0, 10.0];
      // km/h: 0, 36, 72, 108, 36 -> idle, normal, brisk, hard, normal.
      // The trailing single-point "normal" run at the end can't form a line
      // on its own, so it's dropped rather than emitted as a 1-point segment.
      final segments = buildSpeedSegments(points, speedsMs);
      expect(segments.map((s) => s.band).toList(),
          [SpeedBand.idle, SpeedBand.normal, SpeedBand.brisk, SpeedBand.hard]);
    });
  });
}
