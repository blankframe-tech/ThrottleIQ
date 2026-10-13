import 'package:dio/dio.dart';

import '../../domain/entities/place_entity.dart';

/// An unsaved place candidate parsed from an Overpass API response — not yet
/// written to Firestore.
class OverpassCandidate {
  final String osmId;
  final String name;
  final PlaceCategory category;
  final double latitude;
  final double longitude;
  final String address;
  final String? phone;

  const OverpassCandidate({
    required this.osmId,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.phone,
  });
}

/// Pulls nearby fuel/parts/garage/recreation points of interest from OpenStreetMap's
/// Overpass API (https://overpass-api.de) — a free, rate-limited public
/// service, so this is only ever called from an explicit rider action
/// ("Import nearby" in `places_list_screen.dart`), never automatically.
class OverpassService {
  final Dio _dio;
  OverpassService({Dio? dio})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: connectTimeout));

  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  /// Overpass's usage policy asks clients to identify themselves; same UA
  /// as [NominatimService].
  static const userAgent = 'ThrottleIQ/1.0 (com.bft.throttleiq)';

  /// Client-side limits (issues §101.P5). Dio's default of zero waits
  /// forever; the query's `[timeout:25]` only bounds the server side, so
  /// the receive window is that plus headroom.
  static const connectTimeout = Duration(seconds: 10);
  static const sendTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 35);

  /// Fetches candidates within [radiusMeters] of the given point. Only
  /// motorcycle-relevant tags are queried: `amenity=fuel` (fuel),
  /// `craft=motorcycle_repair` (garage/service), `shop=motorcycle`
  /// (parts/dealer), and — for the recreation category — `amenity=cafe`,
  /// `amenity=restaurant` and `tourism=viewpoint` (the biker-cafe / ride-out
  /// stop-off shape of place).
  ///
  /// Queries nodes, ways and relations (`nwr`) with `out center`, because
  /// fuel stations and garages are often mapped as building outlines, not
  /// points (issues §101.P5); a way/relation carries its centroid in
  /// `center`.
  Future<List<OverpassCandidate>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    // issues §33.16: latitude/longitude/radiusMeters are spliced
    // directly into the query text below, so a non-finite value (NaN/
    // Infinity — e.g. from a corrupted last-known-location) would render as
    // the literal strings "NaN"/"Infinity" and produce a malformed query.
    // Reject before building it rather than let Overpass reject it.
    if (!latitude.isFinite || !longitude.isFinite || !radiusMeters.isFinite) {
      return const [];
    }

    final radius = radiusMeters.round();
    final query = '''
[out:json][timeout:25];
(
  nwr["amenity"="fuel"](around:$radius,$latitude,$longitude);
  nwr["craft"="motorcycle_repair"](around:$radius,$latitude,$longitude);
  nwr["shop"="motorcycle"](around:$radius,$latitude,$longitude);
  nwr["amenity"="cafe"](around:$radius,$latitude,$longitude);
  nwr["amenity"="restaurant"](around:$radius,$latitude,$longitude);
  nwr["tourism"="viewpoint"](around:$radius,$latitude,$longitude);
);
out center;
''';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        data: {'data': query},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'User-Agent': userAgent},
          sendTimeout: sendTimeout,
          receiveTimeout: receiveTimeout,
        ),
      );

      final elements = (response.data?['elements'] as List<dynamic>?) ?? [];
      return elements
          .map((e) => parseElement(e as Map<String, dynamic>))
          .whereType<OverpassCandidate>()
          .toList();
    } on DioException {
      // Matches NominatimService's defensive pattern: a free, rate-limited
      // public API failing (timeout, 429, transient outage) should not crash
      // an explicit "Import nearby" tap — it should just come back empty.
      return const [];
    }
  }

  /// Parses one raw Overpass JSON element into a candidate, or null when it
  /// doesn't match a motorcycle-relevant tag or is missing coordinates.
  /// Pure/no I/O — exposed (not private) so this mapping is unit-testable
  /// without a live Overpass call.
  OverpassCandidate? parseElement(Map<String, dynamic> element) {
    final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
    final category = _categoryFor(tags);
    if (category == null) return null;

    // Nodes carry lat/lon directly; ways/relations (from `out center`)
    // carry them under `center`.
    final center = element['center'] as Map<String, dynamic>?;
    final lat = ((element['lat'] ?? center?['lat']) as num?)?.toDouble();
    final lon = ((element['lon'] ?? center?['lon']) as num?)?.toDouble();
    final id = element['id'];
    if (lat == null || lon == null || id == null) return null;

    final name = (tags['name'] as String?)?.trim();

    return OverpassCandidate(
      // Node ids stay 'node/<id>', so dedupe of earlier imports
      // (PlaceRepository.osmDocId) is unchanged.
      osmId: '${element['type'] ?? 'node'}/$id',
      name: (name == null || name.isEmpty) ? category.displayName : name,
      category: category,
      latitude: lat,
      longitude: lon,
      address: _addressFrom(tags),
      phone: (tags['phone'] as String?) ?? (tags['contact:phone'] as String?),
    );
  }

  PlaceCategory? _categoryFor(Map<String, dynamic> tags) {
    if (tags['amenity'] == 'fuel') return PlaceCategory.fuel;
    if (tags['craft'] == 'motorcycle_repair') return PlaceCategory.garage;
    if (tags['shop'] == 'motorcycle') return PlaceCategory.parts;
    // Recreation: cafes/restaurants riders meet at, plus scenic viewpoints
    // worth stopping for. Checked last so a node that somehow carries both a
    // motorcycle tag and a food tag still classifies as the more specific
    // motorcycle one.
    if (tags['amenity'] == 'cafe' || tags['amenity'] == 'restaurant') {
      return PlaceCategory.recreation;
    }
    if (tags['tourism'] == 'viewpoint') return PlaceCategory.recreation;
    return null;
  }

  String _addressFrom(Map<String, dynamic> tags) {
    final parts = [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:city'],
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.join(', ');
  }
}
