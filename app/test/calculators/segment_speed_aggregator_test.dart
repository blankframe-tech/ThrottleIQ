import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/ride/domain/calculators/segment_speed_aggregator.dart';

typedef _P = ({double lat, double lng, double speedMs});

_P _p(double lat, double lng, double speedMs) =>
    (lat: lat, lng: lng, speedMs: speedMs);

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
      expect(segments.single.avgSpeedKmh,
          closeTo(3.6 * 15.0, 0.01)); // mean of 10,20 m/s
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

  group('roadSpeedSampleDocs', () {
    // A ride heading east along one road: consecutive precision-7 cells.
    List<SegmentSpeedSample> ride(double lat, double speedMs) =>
        averageSpeedPerSegment([
          for (var i = 0; i < 12; i++) _p(lat, 90.40 + i * 0.002, speedMs),
        ]);

    final start = DateTime(2026, 11, 8, 17, 20);
    final now = DateTime.utc(2026, 11, 8, 12, 5);

    test('carries only the coarse fields: no exact timestamp, no ids', () {
      final docs = roadSpeedSampleDocs(ride(23.81, 10),
          startTime: start, now: now, weatherCode: 3, random: Random(1));
      for (final d in docs) {
        expect(d.data.keys.toSet(),
            {'speedKmh', 'weekday', 'hour', 'weatherCode', 'day'});
        expect(d.data['day'],
            now.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay);
        expect(d.data['weekday'], start.weekday);
        expect(d.data['hour'], start.hour);
      }
    });

    test('two rides in the same hour cannot be split into ordered paths', () {
      final a = ride(23.81, 10);
      final b = ride(23.83, 12);
      final docsA = roadSpeedSampleDocs(a,
          startTime: start, now: now, weatherCode: 3, random: Random(7));
      final docsB = roadSpeedSampleDocs(b,
          startTime: start, now: now, weatherCode: 3, random: Random(8));

      // Write order is not route order, so arrival order leaks no path.
      expect(docsA.map((d) => d.segmentId),
          isNot(orderedEquals(a.map((s) => s.segmentId))));
      expect(docsB.map((d) => d.segmentId),
          isNot(orderedEquals(b.map((s) => s.segmentId))));

      // Apart from the speed, every sample of both rides is identical, so
      // nothing in a stored doc says which ride it came from or its place
      // in that ride.
      final meta = {
        for (final d in [...docsA, ...docsB])
          (Map.of(d.data)..remove('speedKmh')).toString(),
      };
      expect(meta, hasLength(1));
    });
  });
}
