import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:throttleiq/features/stats/presentation/providers/ride_polyline_provider.dart';

List<LatLng> _track(int n) =>
    [for (var i = 0; i < n; i++) LatLng(12.0 + i * 0.001, 77.0 + i * 0.001)];

void main() {
  group('downsamplePolyline', () {
    test('leaves a track shorter than the budget untouched', () {
      final points = _track(10);
      expect(downsamplePolyline(points, 80), same(points));
    });

    test('leaves a track exactly at the budget untouched', () {
      final points = _track(80);
      expect(downsamplePolyline(points, 80), hasLength(80));
    });

    test('thins a long track to the budget', () {
      expect(downsamplePolyline(_track(5000), 80), hasLength(80));
      expect(downsamplePolyline(_track(81), 80), hasLength(80));
    });

    test('keeps the real endpoints so the start/end markers stay honest', () {
      final points = _track(1000);
      final thinned = downsamplePolyline(points, 80);
      expect(thinned.first, points.first);
      expect(thinned.last, points.last);
    });

    test('preserves order', () {
      final thinned = downsamplePolyline(_track(1000), 40);
      for (var i = 1; i < thinned.length; i++) {
        expect(thinned[i].latitude, greaterThan(thinned[i - 1].latitude));
      }
    });

    test('handles degenerate inputs', () {
      expect(downsamplePolyline(const [], 80), isEmpty);
      expect(downsamplePolyline(_track(1), 80), hasLength(1));
      // A budget too small to keep both endpoints is refused rather than
      // returning a "route" of one point.
      expect(downsamplePolyline(_track(100), 1), hasLength(100));
    });
  });
}
