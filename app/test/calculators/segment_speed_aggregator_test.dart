import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/segment_speed_aggregator.dart';

typedef _P = ({double lat, double lng, double speedMs});

_P _p(double lat, double lng, double speedMs) => (lat: lat, lng: lng, speedMs: speedMs);

void main() {
  group('averageSpeedPerSegment', () {
    test('a single point produces one segment', () {
      final segments = averageSpeedPerSegment([_p(23.8103, 90.4125, 10.0)]);
      expect(segments, hasLength(1));
      expect(segments.single.avgSpeedKmh, closeTo(36.0, 0.01));
      expect(segments.single.pointCount, 1);
    });

    test('points within the same geohash cell average together', () {
      // Sub-meter apart at these coordinates — same precision-7 cell.
      final segments = averageSpeedPerSegment([
        _p(23.81030, 90.41250, 10.0),
        _p(23.81031, 90.41251, 20.0),
      ]);
      expect(segments, hasLength(1));
      expect(segments.single.avgSpeedKmh, closeTo(3.6 * 15.0, 0.01)); // mean of 10,20 m/s
      expect(segments.single.pointCount, 2);
    });

    test('points far apart land in different segments', () {
      final segments = averageSpeedPerSegment([
        _p(23.8103, 90.4125, 10.0), // Dhaka
        _p(24.8949, 91.8687, 20.0), // Sylhet — hundreds of km away
      ]);
      expect(segments, hasLength(2));
    });

    test('an empty point list produces no segments', () {
      expect(averageSpeedPerSegment(const []), isEmpty);
    });

    test('a finer precision splits what a coarser precision merges', () {
      final points = [
        _p(23.81030, 90.41250, 10.0),
        _p(23.81035, 90.41255, 10.0),
      ];
      final coarse = averageSpeedPerSegment(points, precision: 4);
      final fine = averageSpeedPerSegment(points, precision: 9);
      expect(coarse.length, lessThanOrEqualTo(fine.length));
    });
  });
}
