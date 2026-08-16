import '../../../../core/constants/sensor_constants.dart';
import '../entities/ride_point_entity.dart';
import 'average_speed.dart';
import 'event_detector.dart';
import 'motion_calculator.dart';
import 'recording_cadence_policy.dart';
import 'vehicle_state_estimator.dart';

/// One staged GPS fix as the background isolate wrote it — the `auto_fixes`
/// row shape, in the order `_onPosition` would have seen it live.
typedef StagedFix = ({
  DateTime timestamp,
  double lat,
  double lng,
  double speedMs,
  double? accuracyM,
  double? altitudeM,
  double? headingDeg,
});

/// Why a detection didn't become a ride. Stored on the discarded row so the
/// thresholds below can be tuned against real rejections rather than guessed
/// at a second time.
class ReconcileRejection {
  static const tooFewFixes = 'too_few_fixes';
  static const tooShortDistance = 'too_short_distance';
  static const tooShortDuration = 'too_short_duration';
  static const tooSlow = 'too_slow';
  static const noMovement = 'no_movement';
}

/// A detection rebuilt into everything a `rides` row and its `ride_points`
/// need.
class ReconciledRide {
  final double distanceM;
  final double maxSpeedMs;
  final double avgSpeedMs;
  final int movingSeconds;
  final int durationSeconds;
  final int hardBrakeCount;
  final int rapidAccelCount;
  final int highJerkCount;

  /// `ride_points` rows, minus `ride_id` — the caller stamps that on insert.
  final List<Map<String, Object?>> points;

  /// True when the replay's [EventDetector] produced a crash signal.
  ///
  /// **This must never trigger the emergency-contact path.** That flow exists
  /// to summon help within a minute of an impact; reaching it here would mean
  /// contacting someone's family about a crash that, if real, happened hours
  /// ago and which the rider demonstrably walked away from — they were well
  /// enough to open the app. The only honest use of this flag is to mark the
  /// ride for the rider's own review. See `AutoRideReconciler.reconcile`.
  final bool crashSuspected;

  const ReconciledRide({
    required this.distanceM,
    required this.maxSpeedMs,
    required this.avgSpeedMs,
    required this.movingSeconds,
    required this.durationSeconds,
    required this.hardBrakeCount,
    required this.rapidAccelCount,
    required this.highJerkCount,
    required this.points,
    required this.crashSuspected,
  });
}

/// Either a rebuilt ride or the reason there isn't one.
class ReconcileOutcome {
  final ReconciledRide? ride;
  final String? rejectionReason;

  const ReconcileOutcome.accepted(ReconciledRide this.ride)
      : rejectionReason = null;
  const ReconcileOutcome.rejected(String this.rejectionReason) : ride = null;

  bool get isAccepted => ride != null;
}

/// Rebuilds a real ride from the fixes a background detection captured.
///
/// ## Why this replays instead of computing directly
///
/// The obvious implementation — sum the haversines, take the max speed, done —
/// would be a second, independent way of producing ride statistics. It would
/// drift from the live path the first time either side was tuned, and the
/// symptom would be that the same journey reads differently depending on
/// whether the rider happened to tap start. So this drives the *same*
/// calculators the live recorder uses, in the same order, with the same
/// thresholds: [MotionCalculator] for the derivative chain,
/// [VehicleStateEstimator] for fusion and confidence, [EventDetector] for
/// events, [RecordingCadencePolicy] for which fixes get persisted.
///
/// It mirrors `RideRecordingNotifier._onPosition`. If that method changes,
/// this must change with it — the two are a pair, and the ride-summary parity
/// test exists to catch them drifting.
///
/// ## What is deliberately *not* reproduced
///
/// - **IMU-derived state.** The background isolate captures no accelerometer
///   or gyroscope samples (running them all day is exactly the battery cost
///   auto-tracking exists to avoid), so [VehicleStateEstimator] here sees GPS
///   only. Its `imuQuality` is therefore low and `isCornering` is always
///   false. That is honest — the data genuinely wasn't collected — and it
///   only affects the *thinning* decision and the stored per-point metadata,
///   not distance, speed or duration.
/// - **Live alerts.** Haptics and the crash countdown are real-time
///   behaviours. Replaying them hours later would be noise at best and a false
///   emergency at worst.
class AutoRideReconciler {
  /// A detection needs at least this many usable fixes to be a ride at all.
  static const int minFixes = 10;

  /// Shorter than this and it's a car park manoeuvre, not a journey.
  static const double minDistanceM = 300;

  /// Below this and it's a rider pushing the bike, or a false trigger.
  static const int minDurationSeconds = 60;

  /// Peak speed below this (~15 km/h) reads as walking or wheeling the bike.
  /// Deliberately a *peak* rather than an average, because a genuine ride
  /// stuck in Dhaka traffic can average very little.
  static const double minPeakSpeedMs = 4.2;

  /// Fixes with worse accuracy than this are dropped before anything else,
  /// exactly as `_onPosition` drops them live.
  static const double _accuracyGateM = SensorConstants.maxGpsAccuracyM;

  ReconcileOutcome reconcile(List<StagedFix> staged) {
    // Same gate, same constant, same position in the pipeline as the live
    // path: a bad fix must not reach the derivative chain.
    final fixes = staged
        .where((f) => (f.accuracyM ?? 0) <= _accuracyGateM)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (fixes.length < minFixes) {
      return const ReconcileOutcome.rejected(ReconcileRejection.tooFewFixes);
    }

    final calculator = MotionCalculator();
    final estimator = VehicleStateEstimator();
    final detector = EventDetector();
    final cadence = RecordingCadencePolicy();

    var distanceM = 0.0;
    var maxSpeedMs = 0.0;
    var crashSuspected = false;
    RidePointEntity? lastPoint;
    final points = <Map<String, Object?>>[];

    for (final fix in fixes) {
      final speedMs = fix.speedMs < 0 ? 0.0 : fix.speedMs;
      if (speedMs > maxSpeedMs) maxSpeedMs = speedMs;

      double? accel;
      double? jerk;
      var distDelta = 0.0;

      if (lastPoint != null) {
        final result = calculator.calculate(
          prev: lastPoint,
          currentSpeedMs: speedMs,
          currentLat: fix.lat,
          currentLng: fix.lng,
          currentTime: fix.timestamp,
        );
        accel = result.acceleration;
        jerk = result.jerk;
        distDelta = result.distanceDeltaM;
      }

      distanceM += distDelta;

      estimator.addGpsSample(
        timestamp: fix.timestamp,
        lat: fix.lat,
        lng: fix.lng,
        speedMs: speedMs,
        accuracyM: fix.accuracyM ?? _accuracyGateM,
        headingDeg: fix.headingDeg,
        altitudeM: fix.altitudeM,
        accelerationMs2: accel,
      );
      final vehicleState = estimator.currentState;

      final point = RidePointEntity(
        // Stamped by the caller once the ride id exists.
        rideId: '',
        timestamp: fix.timestamp,
        lat: fix.lat,
        lng: fix.lng,
        speedMs: speedMs,
        acceleration: accel,
        jerk: jerk,
        altitudeM: fix.altitudeM,
        headingDeg: vehicleState?.headingDeg,
        confidence: vehicleState?.confidence,
        imuQuality: vehicleState?.imuQuality,
        isCornering: vehicleState?.isCornering,
      );

      // Advances on every fix, thinned or not — the derivative chain needs
      // every consecutive fix. Same invariant as the live path.
      lastPoint = point;

      if (cadence.shouldPersist(
        timestamp: fix.timestamp,
        vehicleState: vehicleState,
      )) {
        points.add({
          'timestamp': point.timestamp.toIso8601String(),
          'lat': point.lat,
          'lng': point.lng,
          'speed_ms': point.speedMs,
          'acceleration': point.acceleration,
          'jerk': point.jerk,
          'altitude_m': point.altitudeM,
          'period_type':
              speedMs < SensorConstants.movingSpeedThresholdMs ? 'idle' : 'moving',
          'accuracy_m': fix.accuracyM,
          'heading_deg': point.headingDeg,
          'confidence': point.confidence,
          'imu_quality': point.imuQuality,
          'is_cornering': point.isCornering == null
              ? null
              : (point.isCornering! ? 1 : 0),
        });
      }

      // `at:` is what makes this replay honest — see EventDetector.detect.
      // Without it every sample here would share one wall-clock instant and
      // the 2-second crash window would swallow the entire journey.
      final alert = detector.detect(
        jerk: jerk,
        accel: accel,
        speedMs: speedMs,
        elapsedSeconds:
            fix.timestamp.difference(fixes.first.timestamp).inSeconds,
        at: fix.timestamp,
      );

      // Recorded, never acted on. See ReconciledRide.crashSuspected.
      if (alert == RideAlert.crash) crashSuspected = true;
    }

    final samples = <SpeedSample>[
      for (final f in fixes)
        (time: f.timestamp, speedMs: f.speedMs < 0 ? 0.0 : f.speedMs),
    ];
    final moving = movingSeconds(samples);
    final duration =
        fixes.last.timestamp.difference(fixes.first.timestamp).inSeconds;

    final rejection = _reject(
      distanceM: distanceM,
      durationSeconds: duration,
      maxSpeedMs: maxSpeedMs,
      movingSeconds: moving,
    );
    if (rejection != null) return ReconcileOutcome.rejected(rejection);

    return ReconcileOutcome.accepted(ReconciledRide(
      distanceM: distanceM,
      maxSpeedMs: maxSpeedMs,
      avgSpeedMs: averageSpeedMs(distanceM: distanceM, movingSeconds: moving),
      movingSeconds: moving,
      durationSeconds: duration,
      hardBrakeCount: detector.hardBrakeCount,
      rapidAccelCount: detector.rapidAccelCount,
      highJerkCount: detector.highJerkCount,
      points: points,
      crashSuspected: crashSuspected,
    ));
  }

  /// The "was this actually a ride" gate.
  ///
  /// Every threshold here is a false-positive filter, and each rejects a
  /// specific real-world thing the platform's activity recognition gets wrong:
  /// wheeling the bike out of a garage, a phone jostling on a desk, a short
  /// walk to a shop, a lift in a friend's car that never got above walking
  /// pace in traffic.
  ///
  /// Order matters only for which reason gets reported, and the order is
  /// chosen so the reported reason is the most specific true one.
  String? _reject({
    required double distanceM,
    required int durationSeconds,
    required double maxSpeedMs,
    required int movingSeconds,
  }) {
    if (movingSeconds <= 0) return ReconcileRejection.noMovement;
    if (maxSpeedMs < minPeakSpeedMs) return ReconcileRejection.tooSlow;
    if (distanceM < minDistanceM) return ReconcileRejection.tooShortDistance;
    if (durationSeconds < minDurationSeconds) {
      return ReconcileRejection.tooShortDuration;
    }
    return null;
  }
}
