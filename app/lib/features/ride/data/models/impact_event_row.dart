import 'dart:convert';
import 'dart:typed_data';

import '../../domain/calculators/impact_detector.dart';
import '../../domain/entities/impact_event_types.dart';

/// Which rule set produced an impact_events row. Bump whenever
/// ImpactDetector's rules or thresholds change, so labels collected under
/// different rules are never pooled by accident.
const int kImpactRulesVersion = 1;

/// An `impact_events` row for a resolved [ImpactCandidate]. Pure, so the
/// mapping is testable without a database.
Map<String, Object?> impactEventRowFromCandidate({
  required ImpactCandidate candidate,
  required String id,
  required String rideId,
  required String userId,
  double? lat,
  double? lng,
  PhonePlacement placement = PhonePlacement.unknown,
  bool? appForeground,
  bool? charging,
  double? sampleRateHz,
  Uint8List? imu,
  DateTime? now,
}) {
  final features = {
    ...candidate.toFeatures(),
    'rulesVersion': kImpactRulesVersion,
  };
  return {
    'id': id,
    'ride_id': rideId,
    'user_id': userId,
    'at': candidate.spikeAt.toUtc().toIso8601String(),
    'tier': candidate.tier,
    'reason': candidate.reason.name,
    'peak_user_g': _r(candidate.peakAccelMs2 / 9.81, 3),
    'peak_raw_g': _r(candidate.peakRawMs2 / 9.81, 3),
    'freefall_ms': candidate.freefallMs,
    'rotation_deg': _r(candidate.rotationDeg, 1),
    'orientation_change_deg': _r(candidate.orientationChangeDeg, 1),
    'still_after': candidate.wentStill ? 1 : 0,
    'resumed_after': candidate.resumed ? 1 : 0,
    'speed_before_ms': _r(candidate.speedBeforeMs, 2),
    'speed_after_ms':
        candidate.speedAfterMs == null ? null : _r(candidate.speedAfterMs!, 2),
    'gps_gap_s':
        candidate.lastFixAgeS == null ? null : _r(candidate.lastFixAgeS!, 1),
    'lat': lat,
    'lng': lng,
    'placement_declared': placement.wire,
    'app_foreground': appForeground == null ? null : (appForeground ? 1 : 0),
    'charging': charging == null ? null : (charging ? 1 : 0),
    'vibration_rms': _r(candidate.vibrationRmsMs2, 2),
    'sample_rate_hz': sampleRateHz == null ? null : _r(sampleRateHz, 1),
    'features': jsonEncode(features),
    'imu': imu,
    'consent_research': 0,
    'synced': 0,
    'created_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
  };
}

double _r(double v, int digits) {
  var f = 1.0;
  for (var i = 0; i < digits; i++) {
    f *= 10;
  }
  return (v * f).roundToDouble() / f;
}
