class SensorConstants {
  SensorConstants._();

  // Event detection thresholds
  static const double hardBrakingThreshold = -4.0; // m/s²
  static const double rapidAccelThreshold = 4.0; // m/s²
  static const double highJerkThreshold = 10.0; // m/s³

  // Hysteresis re-arm levels for the edge-triggered brake/accel counters
  // (§78.3). An event is counted once when the filtered IMU signal crosses
  // the threshold above, and can't count again until the signal has come
  // back past these — so one long brake is one event, not one per sample.
  static const double hardBrakingRearmThreshold = -2.0; // m/s²
  static const double rapidAccelRearmThreshold = 2.0; // m/s²

  // Overspeed defaults and limits (km/h and m/s)
  static const double minOverspeedKmh = 60.0;
  static const double maxOverspeedKmh = 140.0;
  static const double defaultOverspeedKmh = 100.0;
  static const double overspeedThreshold = 27.8; // 100 km/h in m/s

  // Fatigue alert after 90 minutes of active riding
  static const int fatigueAlertSeconds = 5400;

  // GPS location update distance filter (meters)
  static const double gpsDistanceFilter = 5.0;

  // GPS fix quality gate — single source of truth (was an inline magic
  // number in ride_recording_provider.dart's _onPosition)
  static const double maxGpsAccuracyM = 25.0;

  // Crash detection threshold for the legacy GPS-derived path in
  // EventDetector.detect. GPS speed deltas can never reach this on a live
  // ride (speeds above maxPlausibleSpeedMs are rejected), which is why the
  // live path no longer uses it — see ImpactDetector (§78.1). Kept for the
  // AutoRideReconciler replay, which only records "crash suspected".
  static const double crashAccelThreshold = 80.0; // m/s² (~8.2g)

  // ImpactDetector (§78.1) — raw-IMU crash detection.
  //
  // UNCALIBRATED. 4 g is a provisional starting point, not a measured value:
  // it has not been validated against real rides, drop tests, or the range
  // of budget-phone accelerometers (some saturate at 4-8 g, which is why
  // ImpactDetector also treats a run of samples pinned at the ride's max as
  // a spike). Re-tune from field data before any safety claim.
  static const double impactThreshold = 39.0; // m/s² (~4 g)

  // A run of samples pinned near the ride's max only counts as a saturated
  // spike above this floor, so a phone at rest (all samples ≈ 0 = the max)
  // doesn't look saturated. Also uncalibrated.
  static const double impactSaturationFloorMs2 = 19.6; // ~2 g

  // Master switch for live crash alerts from ImpactDetector. OFF until the
  // founder decides how crash alerts are delivered (see claude_sol §2.1:
  // escalation is still a mock) and the thresholds above are field-
  // validated. While false, the ride recorder builds no ImpactDetector
  // pipeline and live rides behave exactly as before, except that the
  // unreachable GPS crash branch is no longer called either. Tests force it
  // on via SensorFusionCoordinator(impactDetectionEnabled: true).
  static const bool impactDetectorLiveEnabled = false;

  // Sensor validation ceilings — reject obviously-broken samples (NaN,
  // sensor glitches/clipping), not legitimate high-g crash spikes
  // (ImpactDetector's spike threshold is impactThreshold)
  static const double maxPlausibleAccelMs2 = 300.0;
  static const double maxPlausibleYawRateRadS = 34.9; // ~2000°/s
  static const double maxPlausibleSpeedMs = 70.0; // ~252 km/h; reject GPS spikes & jumps
  static const double maxPhysicalAccelMs2 = 12.0; // ~1.2g; maximum physically plausible motorcycle acceleration

  // Motion classification
  static const double movingSpeedThresholdMs = 1.0; // matches existing periodType cutoff
  static const double corneringYawRateThresholdRadS = 0.26; // ~15°/s

  // Some GPS chipsets (the iOS Simulator's location playback, and a subset
  // of Android GPS chipsets) report Position.speed as near-zero even while
  // genuinely moving. When the raw field reads below this floor, the recorder
  // falls back to a haversine distance/time-derived speed for that fix
  // instead of recording the ride as stationary (DOCS/Handoff for agents and Todos/issues_open.md or issues_fixed.md §49). Reuses
  // movingSpeedThresholdMs's cutoff — the same value already used to decide
  // "is this fix idle or moving" everywhere else.
  static const double unreliableSpeedFallbackThresholdMs = movingSpeedThresholdMs;

  // Complementary filter heading blend — favor GPS course when the fix is
  // accurate, lean more on gyro dead-reckoning when it isn't
  static const double headingGoodAccuracyThresholdM = 8.0;
  static const double headingGpsWeightGoodAccuracy = 0.7;
  static const double headingGpsWeightPoorAccuracy = 0.3;

  // Crash-alert confidence gate (Epic G follow-up: don't act on a crash
  // signal derived from garbage sensor data, e.g. mid-tunnel GPS loss)
  static const int minConfidenceForCrashAlert = 40;

  // Adaptive recording (Phase 1.5): a point is only eligible to be thinned
  // (skipped from persistence) when confidence is at or above this floor —
  // deliberately conservative for a pre-launch app whose confidence
  // heuristic hasn't been tuned against real rides yet. Cornering/braking/
  // accelerating points are never eligible regardless of confidence. On an
  // eligible stretch, persisted points are throttled to at most one every
  // minPersistIntervalOnSteadyStretches — matching the original vision's
  // "1 point every 5 seconds on a straight highway" example.
  static const int minConfidenceToThinRecording = 70;
  static const Duration minPersistIntervalOnSteadyStretches = Duration(seconds: 5);

  // Maintenance thresholds (km)
  static const double oilChangeMinKm = 1000;
  static const double oilChangeMaxKm = 1500;
  static const double airFilterMinKm = 8000;
  static const double airFilterMaxKm = 10000;
  static const double chainLubeMinKm = 500;
  static const double chainLubeMaxKm = 700;
  static const double tireCheckMinKm = 5000;
  static const double tireCheckMaxKm = 8000;

  // Brakes get reminders alongside the original four because they're the
  // safety-critical ones. The rest of the expanded ServiceType list is
  // loggable but deliberately not reminded on — see _reminderTypes in
  // maintenance_provider.dart for why.
  static const double brakeFluidMinKm = 18000;
  static const double brakeFluidMaxKm = 20000;
  static const double discPadsMinKm = 12000;
  static const double discPadsMaxKm = 15000;
}
