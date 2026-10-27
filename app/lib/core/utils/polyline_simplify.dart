import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'downsample.dart';

/// Most points a polyline written to a shared Firestore doc may carry.
const int kSharedPolylineMaxPoints = 1000;

/// Thins [points] for a shared/public copy: Ramer–Douglas–Peucker at
/// [toleranceM] metres, doubling the tolerance while the result is still over
/// [maxPoints], then an even decimation as the last resort. The result is
/// always a subset of [points] in order, first and last kept, so it can never
/// contain a point the caller had already removed (e.g. a privacy zone).
List<LatLng> simplifyPolyline(
  List<LatLng> points, {
  double toleranceM = 5,
  int maxPoints = kSharedPolylineMaxPoints,
}) {
  if (points.length <= 2) return points;
  // Local equirectangular projection to metres: accurate to well under the
  // tolerance over a ride's extent, and far cheaper than haversine per test.
  final cosLat = math.cos(points.first.latitude * math.pi / 180);
  const mPerDeg = 111320.0;
  final xs = [for (final p in points) p.longitude * cosLat * mPerDeg];
  final ys = [for (final p in points) p.latitude * mPerDeg];

  var tol = toleranceM;
  var out = _rdp(points, xs, ys, tol);
  // 8 doublings: 5 m → 1.28 km, past which a line this long is decimated.
  for (var i = 0; i < 8 && out.length > maxPoints; i++) {
    tol *= 2;
    out = _rdp(points, xs, ys, tol);
  }
  return downsample(out, maxPoints);
}

List<LatLng> _rdp(
    List<LatLng> pts, List<double> xs, List<double> ys, double tol) {
  final keep = List<bool>.filled(pts.length, false)
    ..[0] = true
    ..[pts.length - 1] = true;
  // Explicit stack: a 20k-point track would blow recursion depth.
  final stack = <int>[0, pts.length - 1];
  while (stack.isNotEmpty) {
    final b = stack.removeLast();
    final a = stack.removeLast();
    final dx = xs[b] - xs[a];
    final dy = ys[b] - ys[a];
    final len2 = dx * dx + dy * dy;
    var maxD = -1.0;
    var idx = -1;
    for (var i = a + 1; i < b; i++) {
      // Distance to segment a–b (clamped, so a closed loop a == b still works).
      var t = len2 == 0
          ? 0.0
          : ((xs[i] - xs[a]) * dx + (ys[i] - ys[a]) * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final ex = xs[i] - (xs[a] + t * dx);
      final ey = ys[i] - (ys[a] + t * dy);
      final d = ex * ex + ey * ey;
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (idx != -1 && maxD > tol * tol) {
      keep[idx] = true;
      stack
        ..add(a)
        ..add(idx)
        ..add(idx)
        ..add(b);
    }
  }
  return [
    for (var i = 0; i < pts.length; i++)
      if (keep[i]) pts[i],
  ];
}
