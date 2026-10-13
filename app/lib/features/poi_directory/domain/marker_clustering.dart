import 'dart:math' as math;

/// A group of map items close enough on screen at the current zoom to draw
/// as one bubble. [latitude]/[longitude] is the group's centroid.
class MapCluster<T> {
  final List<T> items;
  final double latitude;
  final double longitude;

  const MapCluster(this.items, this.latitude, this.longitude);

  bool get isSingle => items.length == 1;
}

/// Web Mercator world-pixel coordinates of a point at [zoom] (256px tiles) —
/// the same projection the tiles are drawn in, so "same grid cell" means
/// "close together on the rider's screen".
(double, double) worldPixel(double latitude, double longitude, double zoom) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final lat = latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
  final x = (longitude + 180) / 360 * scale;
  final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * scale;
  return (x, y);
}

/// Grid clustering: items whose projected position falls in the same
/// [cellSizePx] square at [zoom] become one cluster.
///
/// Chosen over a cluster package because the Places batch is a few hundred
/// points at most (one radius query), which a single O(n) pass handles every
/// frame without help, and it keeps the dependency list as it is. Zoom is
/// floored so clusters only regroup on whole zoom steps rather than shimmering
/// during a pinch. At or past [disableAtZoom] every item is its own cluster —
/// by street level, pins that still overlap are genuinely side by side.
List<MapCluster<T>> clusterByGrid<T>(
  Iterable<T> items, {
  required double Function(T) latitudeOf,
  required double Function(T) longitudeOf,
  required double zoom,
  double cellSizePx = 64,
  double disableAtZoom = 16,
}) {
  if (zoom >= disableAtZoom) {
    return [
      for (final item in items)
        MapCluster<T>([item], latitudeOf(item), longitudeOf(item)),
    ];
  }
  final z = zoom.floorToDouble();
  final cells = <(int, int), List<T>>{};
  for (final item in items) {
    final (x, y) = worldPixel(latitudeOf(item), longitudeOf(item), z);
    final key = ((x / cellSizePx).floor(), (y / cellSizePx).floor());
    (cells[key] ??= <T>[]).add(item);
  }
  return [
    for (final group in cells.values)
      MapCluster<T>(
        group,
        group.map(latitudeOf).reduce((a, b) => a + b) / group.length,
        group.map(longitudeOf).reduce((a, b) => a + b) / group.length,
      ),
  ];
}
