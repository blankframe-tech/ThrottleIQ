import '../vendor/core/utils/geohash_util.dart';
import '../vendor/core/utils/riding_score.dart';
import '../vendor/features/ride/domain/calculators/segment_speed_aggregator.dart';

/// Same box the server checks (functions/src/partner-api/scoring.ts): a
/// road cell outside Bangladesh is not Dhaka data, and one would make the
/// server refuse the whole upload, so it is dropped here first.
bool inBangladesh(String geohash) {
  final b = GeohashUtil.decodeBounds(geohash);
  final lat = (b['latMin']! + b['latMax']!) / 2;
  final lng = (b['lngMin']! + b['lngMax']!) / 2;
  return lat >= 20.3 && lat <= 26.8 && lng >= 87.9 && lng <= 92.8;
}

/// One impact the detector resolved during the ride (tier 1 "worth asking",
/// tier 2 "crash"). After the ride, ask the rider "Did you fall?" and set
/// [riderSaysFell] with [RideReport.withFellAnswers]; those answers are what
/// teaches the detector Dhaka's potholes from real falls.
class ImpactSummary {
  final int tier;
  final String reason;
  final double peakAccelMs2;
  final double speedBeforeKmh;
  final DateTime at;
  final bool? riderSaysFell;

  const ImpactSummary({
    required this.tier,
    required this.reason,
    required this.peakAccelMs2,
    required this.speedBeforeKmh,
    required this.at,
    this.riderSaysFell,
  });

  ImpactSummary withAnswer(bool? fell) => ImpactSummary(
        tier: tier,
        reason: reason,
        peakAccelMs2: peakAccelMs2,
        speedBeforeKmh: speedBeforeKmh,
        at: at,
        riderSaysFell: fell,
      );

  Map<String, Object?> toJson() => {
        'tier': tier,
        'reason': reason,
        'peakAccelMs2': peakAccelMs2,
        'speedBeforeKmh': speedBeforeKmh,
        'at': at.toUtc().toIso8601String(),
        'riderSaysFell': riderSaysFell,
      };

  factory ImpactSummary.fromJson(Map<String, Object?> j) => ImpactSummary(
        tier: j['tier'] as int,
        reason: j['reason'] as String,
        peakAccelMs2: (j['peakAccelMs2'] as num).toDouble(),
        speedBeforeKmh: (j['speedBeforeKmh'] as num).toDouble(),
        at: DateTime.parse(j['at'] as String),
        riderSaysFell: j['riderSaysFell'] as bool?,
      );
}

/// A finished trip, ready for `ThrottleIqClient.uploadRide`. No raw GPS
/// track leaves the phone: only the speed per ~150 m road cell, the
/// counts, and the three leg distances.
///
/// [toJson]/[fromJson] round-trip, so the app can queue a report while
/// offline and upload it later; the upload is idempotent per [rideId].
class RideReport {
  final String rideId;
  final String riderRef;
  final DateTime startedAt;
  final DateTime endedAt;
  final double pickupKm;
  final double tripKm;
  final double homeKm;
  final int movingSeconds;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final int hardBrakes;
  final int rapidAccels;
  final int highJerks;
  final int overspeeds;
  final int? weatherCode;
  final List<SegmentSpeedSample> segments;
  final List<ImpactSummary> impacts;

  const RideReport({
    required this.rideId,
    required this.riderRef,
    required this.startedAt,
    required this.endedAt,
    required this.pickupKm,
    required this.tripKm,
    required this.homeKm,
    required this.movingSeconds,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.hardBrakes,
    required this.rapidAccels,
    required this.highJerks,
    required this.overspeeds,
    required this.weatherCode,
    required this.segments,
    required this.impacts,
  });

  double get distanceKm => pickupKm + tripKm + homeKm;

  /// The on-phone score (ThrottleIQ's event score), shown before upload.
  int get eventScore => computeRidingScore(
      hardBrakes: hardBrakes, rapidAccel: rapidAccels, highJerk: highJerks);

  /// [answers] in [impacts] order: true "I fell", false "No", null "not asked".
  RideReport withFellAnswers(List<bool?> answers) {
    if (answers.length != impacts.length) {
      throw ArgumentError(
          'expected ${impacts.length} answers, got ${answers.length}');
    }
    return RideReport(
      rideId: rideId,
      riderRef: riderRef,
      startedAt: startedAt,
      endedAt: endedAt,
      pickupKm: pickupKm,
      tripKm: tripKm,
      homeKm: homeKm,
      movingSeconds: movingSeconds,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      hardBrakes: hardBrakes,
      rapidAccels: rapidAccels,
      highJerks: highJerks,
      overspeeds: overspeeds,
      weatherCode: weatherCode,
      segments: segments,
      impacts: [
        for (var i = 0; i < impacts.length; i++)
          impacts[i].withAnswer(answers[i])
      ],
    );
  }

  /// The body of `POST /v1/rides` (see mayabi/API.md).
  Map<String, Object?> toJson() => {
        'rideId': rideId,
        'riderRef': riderRef,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'distanceKm': distanceKm,
        'pickupKm': pickupKm,
        'tripKm': tripKm,
        'returnKm': homeKm,
        'movingSeconds': movingSeconds,
        'avgSpeedKmh': avgSpeedKmh,
        'maxSpeedKmh': maxSpeedKmh,
        'hardBrakes': hardBrakes,
        'rapidAccels': rapidAccels,
        'highJerks': highJerks,
        'overspeeds': overspeeds,
        'weatherCode': weatherCode,
        'segments': [
          for (final s in segments)
            {
              'segmentId': s.segmentId,
              'avgSpeedKmh': s.avgSpeedKmh,
              'pointCount': s.pointCount
            },
        ],
        'impacts': [for (final i in impacts) i.toJson()],
      };

  factory RideReport.fromJson(Map<String, Object?> j) => RideReport(
        rideId: j['rideId'] as String,
        riderRef: j['riderRef'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        pickupKm: (j['pickupKm'] as num).toDouble(),
        tripKm: (j['tripKm'] as num).toDouble(),
        homeKm: (j['returnKm'] as num).toDouble(),
        movingSeconds: j['movingSeconds'] as int,
        avgSpeedKmh: (j['avgSpeedKmh'] as num).toDouble(),
        maxSpeedKmh: (j['maxSpeedKmh'] as num).toDouble(),
        hardBrakes: j['hardBrakes'] as int,
        rapidAccels: j['rapidAccels'] as int,
        highJerks: j['highJerks'] as int,
        overspeeds: j['overspeeds'] as int,
        weatherCode: j['weatherCode'] as int?,
        segments: [
          for (final s in (j['segments'] as List).cast<Map<String, Object?>>())
            (
              segmentId: s['segmentId'] as String,
              avgSpeedKmh: (s['avgSpeedKmh'] as num).toDouble(),
              pointCount: s['pointCount'] as int,
            ),
        ],
        impacts: [
          for (final i in (j['impacts'] as List).cast<Map<String, Object?>>())
            ImpactSummary.fromJson(i),
        ],
      );
}
