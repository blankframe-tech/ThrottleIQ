import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Blob;

import '../../features/ride/domain/entities/impact_event_types.dart';
import '../utils/geohash_util.dart';
import '../utils/num_cast.dart';

/// Cloud shapes for `impact_events` rows. Pure, so they're testable without
/// Firestore; the field lists here and the `hasOnly` lists in
/// `firestore.rules` (impactEventValid / crashEventValid) must match.

/// The rider's private copy: `users/{uid}/impactEvents/{id}`. Everything the
/// row holds except the owner (it's in the path) and local bookkeeping.
Map<String, Object?> impactEventCloudPayload(Map<String, Object?> row) {
  final imu = row['imu'];
  final out = <String, Object?>{
    'schema': 1,
    'rideId': row['ride_id'],
    'at': row['at'],
    'tier': row['tier'],
    'reason': row['reason'],
    'peakUserG': row['peak_user_g'],
    'peakRawG': row['peak_raw_g'],
    'freefallMs': row['freefall_ms'],
    'rotationDeg': row['rotation_deg'],
    'orientationChangeDeg': row['orientation_change_deg'],
    'stillAfter': _bool(row['still_after']),
    'resumedAfter': _bool(row['resumed_after']),
    'speedBeforeMs': row['speed_before_ms'],
    'speedAfterMs': row['speed_after_ms'],
    'gpsGapS': row['gps_gap_s'],
    'lat': row['lat'],
    'lng': row['lng'],
    'placement': row['placement_declared'],
    'appForeground': _bool(row['app_foreground']),
    'charging': _bool(row['charging']),
    'vibrationRms': row['vibration_rms'],
    'sampleRateHz': row['sample_rate_hz'],
    'features': _json(row['features']),
    'imu': imu is Uint8List ? Blob(imu) : null,
    'label': row['label'],
    'labelDetail': _json(row['label_detail']),
    'labelSource': row['label_source'],
    'labeledAt': row['labeled_at'],
    'consent': _bool(row['consent_research']) ?? false,
    'createdAt': row['created_at'],
  };
  out.removeWhere((_, v) => v == null);
  return out;
}

/// The de-identified central record: `crashEvents/{id}`, one per answered
/// impact (or reported miss) — the dataset behind honest demo statistics.
///
/// Null unless the rider answered and opted in (`consent_research = 1`).
/// No uid in the content beyond [ownerUid] (needed so the rider can delete
/// it, and never readable by clients), no exact position (a ~1.2 × 0.6 km
/// geohash cell), no free text.
Map<String, Object?>? crashEventCloudPayload(
  Map<String, Object?> row, {
  required String ownerUid,
  required String platform,
  required int consentVersion,
}) {
  final label = row['label'] as String?;
  if (label == null || _bool(row['consent_research']) != true) return null;
  final detail = _json(row['label_detail']) ?? const <String, Object?>{};
  final features = _json(row['features']) ?? const <String, Object?>{};
  final tier = (row['tier'] as num?)?.toInt() ?? -1;
  final at = DateTime.tryParse(row['at'] as String? ?? '')?.toLocal();
  final lat = asDoubleOrNull(row['lat']);
  final lng = asDoubleOrNull(row['lng']);
  final speedBefore = asDoubleOrNull(row['speed_before_ms']);
  final peakUser = asDoubleOrNull(row['peak_user_g']) ?? 0;
  final peakRaw = asDoubleOrNull(row['peak_raw_g']) ?? 0;

  final out = <String, Object?>{
    'ownerUid': ownerUid,
    'createdAt': row['created_at'],
    'platform': platform,
    'label': label,
    'detectedTier': tier >= 0 ? tier : null,
    'reason': row['reason'],
    'peakG': tier >= 0 ? (peakUser > peakRaw ? peakUser : peakRaw) : null,
    'freefallMs': row['freefall_ms'],
    'rotationDeg': row['rotation_deg'],
    'orientationChangeDeg': row['orientation_change_deg'],
    'speedBeforeKmh':
        speedBefore == null ? null : (speedBefore * 36).round() / 10,
    'placement': row['placement_declared'],
    'bikeCc': (row['bike_cc'] as num?)?.toInt(),
    'bikeClass': bikeClassFor(
      cc: (row['bike_cc'] as num?)?.toInt(),
      brand: row['bike_brand'] as String?,
      model: row['bike_model'] as String?,
      isEbike: _bool(row['bike_is_ebike']) ?? false,
    ),
    'surface': _oneOf(detail['surface'], RoadSurface.values.map((s) => s.wire)),
    'severity':
        _oneOf(detail['severity'], ImpactSeverity.values.map((s) => s.wire)),
    'geohash6': lat == null || lng == null
        ? null
        : GeohashUtil.encode(lat, lng, precision: 6),
    'hourLocal': at?.hour,
    'weekday': at?.weekday,
    'rulesVersion': (features['rulesVersion'] as num?)?.toInt(),
    'consentVersion': consentVersion,
  };
  out.removeWhere((_, v) => v == null);
  return out;
}

/// A coarse bike class from the garage entry, for breakdowns ("sport bikes
/// vs commuters"). A heuristic over the Bangladesh catalogue
/// (bike_catalog.dart); anything unrecognised is a commuter.
String bikeClassFor(
    {int? cc, String? brand, String? model, bool isEbike = false}) {
  if (isEbike) return 'ebike';
  final name = '${brand ?? ''} ${model ?? ''}'.toLowerCase();
  bool any(List<String> keys) => keys.any(name.contains);
  if (any(const [
    'scooter',
    'ray',
    'activa',
    'dio',
    'pleasure',
    'jupiter',
    'ntorq',
    'burgman',
    'vespa',
    'nmax',
    'aerox',
    'pcx'
  ])) {
    return 'scooter';
  }
  if (any(const ['himalayan', 'xpulse', 'adventure', 'dual', 'adv '])) {
    return 'adventure';
  }
  if (any(const [
    'r15',
    'r3',
    'yzf',
    'cbr',
    'gsx-r',
    'gixxer sf',
    'rc 390',
    'rc390',
    'rc 200',
    'ninja',
    'sr 250',
    'sr 300',
    'kpr'
  ])) {
    return 'sport';
  }
  if ((cc ?? 0) >= 400) return 'sport';
  return 'commuter';
}

bool? _bool(Object? v) => v == null ? null : (v is bool ? v : (v as num) != 0);

Map<String, Object?>? _json(Object? v) {
  if (v is! String || v.isEmpty) return null;
  try {
    final decoded = jsonDecode(v);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

String? _oneOf(Object? v, Iterable<String> allowed) =>
    v is String && allowed.contains(v) ? v : null;
