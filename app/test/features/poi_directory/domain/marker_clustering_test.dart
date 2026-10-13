import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/features/poi_directory/domain/marker_clustering.dart';

typedef _Pt = ({String id, double lat, double lng});

List<MapCluster<_Pt>> _cluster(List<_Pt> pts, double zoom) => clusterByGrid<_Pt>(
      pts,
      latitudeOf: (p) => p.lat,
      longitudeOf: (p) => p.lng,
      zoom: zoom,
    );

void main() {
  // Two pumps ~100 m apart in Mirpur, one ~30 km away in Savar.
  const List<_Pt> pts = [
    (id: 'a', lat: 23.8060, lng: 90.3680),
    (id: 'b', lat: 23.8065, lng: 90.3690),
    (id: 'c', lat: 23.8450, lng: 90.2570),
  ];

  test('close points merge at city zoom, far ones stay apart', () {
    final clusters = _cluster(pts, 11);
    expect(clusters.length, 2);
    final merged = clusters.firstWhere((c) => !c.isSingle);
    expect({for (final p in merged.items) p.id}, {'a', 'b'});
    expect(merged.latitude, closeTo(23.80625, 1e-9));
    expect(merged.longitude, closeTo(90.3685, 1e-9));
  });

  test('everything is its own pin at street zoom', () {
    final clusters = _cluster(pts, 16);
    expect(clusters.length, 3);
    expect(clusters.every((c) => c.isSingle), isTrue);
  });

  test('fractional zoom clusters like its floor, so pinching does not reshuffle', () {
    expect(_cluster(pts, 11.9).length, _cluster(pts, 11).length);
  });

  test('every item lands in exactly one cluster', () {
    for (final z in [3.0, 8.0, 12.0, 15.0]) {
      final total = _cluster(pts, z).fold<int>(0, (n, c) => n + c.items.length);
      expect(total, pts.length, reason: 'zoom $z');
    }
  });

  test('worldPixel doubles per zoom step', () {
    final (x1, y1) = worldPixel(23.8, 90.4, 10);
    final (x2, y2) = worldPixel(23.8, 90.4, 11);
    expect(x2, closeTo(x1 * 2, 1e-6));
    expect(y2, closeTo(y1 * 2, 1e-6));
  });
}
