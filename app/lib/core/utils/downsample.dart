/// Evenly thins [items] to at most [budget] entries, always keeping the
/// first and last so a chart's endpoints still land on the ride's real
/// start/finish. Same index-stepping strategy as
/// `ride_polyline_provider.dart`'s `downsamplePolyline`, generalized to any
/// list so telemetry series (speed, altitude) can share it without pulling
/// in that provider's `LatLng`-specific type.
List<T> downsample<T>(List<T> items, int budget) {
  if (budget < 2 || items.length <= budget) return items;
  final step = (items.length - 1) / (budget - 1);
  return [
    for (var i = 0; i < budget - 1; i++) items[(i * step).floor()],
    items.last,
  ];
}
