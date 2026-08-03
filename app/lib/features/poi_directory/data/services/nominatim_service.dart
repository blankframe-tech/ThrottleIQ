import 'package:dio/dio.dart';

/// Reverse-geocodes a map pin into a short, human-readable locality string
/// using OpenStreetMap's Nominatim service.
///
/// Only ever called from an explicit rider action ("Use the pin's location"
/// under the address field in `add_place_screen.dart`) — never on every map
/// pan. Nominatim's usage policy caps automated use at one request per second
/// and requires an identifying User-Agent, both of which a pan-triggered
/// lookup would violate immediately.
///
/// Deliberately best-effort: every failure path returns null and the caller
/// just leaves the (now optional) address field alone. A geocoder being down
/// must never block adding a place.
class NominatimService {
  final Dio _dio;
  NominatimService({Dio? dio}) : _dio = dio ?? Dio();

  static const _endpoint = 'https://nominatim.openstreetmap.org/reverse';

  /// The identifying UA Nominatim's policy requires. Anonymous clients get
  /// blocked.
  static const _userAgent = 'ThrottleIQ/1.0 (com.bft.throttleiq)';

  /// Returns a short locality description for [latitude]/[longitude], or null
  /// if nothing useful came back.
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _endpoint,
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'format': 'jsonv2',
          // 16 ≈ "major street" — finer than that returns house numbers that
          // are meaningless in most of Bangladesh; coarser loses the para/area
          // name, which is the one part riders actually navigate by.
          'zoom': 16,
          'addressdetails': 1,
        },
        options: Options(
          headers: {'User-Agent': _userAgent},
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final data = response.data;
      if (data == null) return null;
      return parseReverse(data);
    } catch (_) {
      // Offline, rate-limited, timed out, malformed — all the same to the
      // caller: no suggestion available.
      return null;
    }
  }

  /// Builds the display string from a raw Nominatim `reverse` payload.
  ///
  /// Pure/no I/O — exposed (not private) so the mapping is unit-testable
  /// without a live Nominatim call, mirroring `OverpassService.parseElement`.
  ///
  /// Picks the parts a rider would actually say out loud, nearest-first, and
  /// caps at three so the prefill stays a starting point they can edit rather
  /// than a wall of administrative boundaries. Falls back to Nominatim's own
  /// `display_name` (trimmed to its first three commas) when the structured
  /// address is missing or yields nothing.
  String? parseReverse(Map<String, dynamic> data) {
    final address = data['address'];
    if (address is Map) {
      const keys = [
        'neighbourhood',
        'suburb',
        'road',
        'village',
        'town',
        'city_district',
        'city',
        'county',
      ];
      final seen = <String>{};
      final parts = <String>[];
      for (final key in keys) {
        final value = address[key];
        if (value is! String) continue;
        final trimmed = value.trim();
        if (trimmed.isEmpty || !seen.add(trimmed)) continue;
        parts.add(trimmed);
        if (parts.length == 3) break;
      }
      if (parts.isNotEmpty) return parts.join(', ');
    }

    final display = data['display_name'];
    if (display is String && display.trim().isNotEmpty) {
      return display.split(',').take(3).map((s) => s.trim()).join(', ');
    }
    return null;
  }
}
