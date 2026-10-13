/// Reads a GPX track and replays it through the navigation session, which is
/// the closest this project gets to riding a route without a bike.
///
/// `issues_open.md` §78.21 names "a phone on a bike, or a GPX-replaying
/// simulator" as the two ways to check route guidance. This is the second one.
/// It drives the same code the cockpit drives — `NavigationSessionNotifier`
/// folding `RideRecordingState` updates — so everything from the fix to the
/// banner's contents is exercised. What it deliberately does **not** cover is
/// the layer below that: `Geolocator`, permissions, the foreground service and
/// persistence are all constructed inline by `RideRecordingNotifier` and can't
/// be substituted (issues §83.13). A real ride is still the only check on
/// those.
///
/// The parser is a regex over `<trkpt>` rather than an XML library on purpose:
/// `xml` is only a transitive dependency here, and a test helper that pulls in
/// a direct one to read four attributes is a bad trade.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// One replayed fix.
typedef GpxFix = ({LatLng position, double speedMs});

final _trkpt = RegExp(
  r'<trkpt[^>]*\blat="([-\d.]+)"[^>]*\blon="([-\d.]+)"[^>]*>(.*?)</trkpt>',
  dotAll: true,
);
final _speed = RegExp(r'<speed>([-\d.]+)</speed>');

/// Every `<trkpt>` in [path], in file order.
///
/// A point with no `<speed>` falls back to [defaultSpeedMs] rather than 0:
/// plenty of GPX writers omit it, and a zero would read as "stopped", which
/// suppresses the ETA and would quietly hollow out any test using the file.
List<GpxFix> readGpx(String path, {double defaultSpeedMs = 8.3}) {
  final source = File(path).readAsStringSync();
  final fixes = <GpxFix>[];
  for (final m in _trkpt.allMatches(source)) {
    final lat = double.parse(m.group(1)!);
    final lng = double.parse(m.group(2)!);
    final speedMatch = _speed.firstMatch(m.group(3) ?? '');
    fixes.add((
      position: LatLng(lat, lng),
      speedMs:
          speedMatch == null ? defaultSpeedMs : double.parse(speedMatch.group(1)!),
    ));
  }
  if (fixes.isEmpty) {
    throw StateError('No <trkpt> elements in $path — wrong file, or not GPX.');
  }
  return fixes;
}

/// Moves [from] by [metres] along [bearingDeg]. Flat-earth, which is exact
/// enough over the hundreds of metres these fixtures cover.
LatLng offsetMetres(LatLng from, double bearingDeg, double metres) {
  const metresPerDegLat = 111320.0;
  final rad = bearingDeg * math.pi / 180.0;
  return LatLng(
    from.latitude + (metres * math.cos(rad)) / metresPerDegLat,
    from.longitude +
        (metres * math.sin(rad)) /
            (metresPerDegLat * math.cos(from.latitude * math.pi / 180.0)),
  );
}

/// Pushes every fix in [fixes] sideways by [metres] along [bearingDeg],
/// between [fromIndex] and [toIndex] — a rider who left the route for a few
/// blocks and rejoined it.
List<GpxFix> withDetour(
  List<GpxFix> fixes, {
  required int fromIndex,
  required int toIndex,
  required double bearingDeg,
  required double metres,
}) =>
    [
      for (var i = 0; i < fixes.length; i++)
        if (i >= fromIndex && i < toIndex)
          (
            position: offsetMetres(fixes[i].position, bearingDeg, metres),
            speedMs: fixes[i].speedMs
          )
        else
          fixes[i],
    ];

/// Keeps every [stride]-th fix — a phone that dropped to a coarse duty cycle,
/// or a tunnel. Always keeps the last fix so the replay still ends where the
/// ride ended.
List<GpxFix> decimated(List<GpxFix> fixes, int stride) {
  final out = <GpxFix>[
    for (var i = 0; i < fixes.length; i += stride) fixes[i],
  ];
  if (out.last != fixes.last) out.add(fixes.last);
  return out;
}
