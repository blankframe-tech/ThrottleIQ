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

/// Pulls nearby fuel/parts/garage points of interest from OpenStreetMap's
/// Overpass API (https://overpass-api.de) — a free, rate-limited public
/// service, so this is only ever called from an explicit rider action
/// ("Import nearby" in `places_list_screen.dart`), never automatically.
class OverpassService {
  final Dio _dio;
  OverpassService({Dio? dio}) : _dio = dio ?? Dio();

  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  /// Fetches candidates within [radiusMeters] of the given point. Only
  /// motorcycle-relevant tags are queried: `amenity=fuel` (fuel),
  /// `craft=motorcycle_repair` (garage/service), and `shop=motorcycle`
  /// (parts/dealer).
  Future<List<OverpassCandidate>> fetchNearby({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final radius = radiusMeters.round();
    final query = '''
[out:json][timeout:25];
(
  node["amenity"="fuel"](around:$radius,$latitude,$longitude);
  node["craft"="motorcycle_repair"](around:$radius,$latitude,$longitude);
  node["shop"="motorcycle"](around:$radius,$latitude,$longitude);
);
out body;
''';

    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      data: {'data': query},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final elements = (response.data?['elements'] as List<dynamic>?) ?? [];
    return elements
        .map((e) => parseElement(e as Map<String, dynamic>))
        .whereType<OverpassCandidate>()
        .toList();
  }

  /// Parses one raw Overpass JSON element into a candidate, or null when it
  /// doesn't match a motorcycle-relevant tag or is missing coordinates.
  /// Pure/no I/O — exposed (not private) so this mapping is unit-testable
  /// without a live Overpass call.
  OverpassCandidate? parseElement(Map<String, dynamic> element) {
    final tags = (element['tags'] as Map<String, dynamic>?) ?? const {};
    final category = _categoryFor(tags);
    if (category == null) return null;

    final lat = (element['lat'] as num?)?.toDouble();
    final lon = (element['lon'] as num?)?.toDouble();
    final id = element['id'];
    if (lat == null || lon == null || id == null) return null;

    final name = (tags['name'] as String?)?.trim();

    return OverpassCandidate(
      osmId: 'node/$id',
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
