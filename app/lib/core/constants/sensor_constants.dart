class SensorConstants {
  SensorConstants._();

  // Event detection thresholds
  static const double hardBrakingThreshold = -4.0; // m/s²
  static const double rapidAccelThreshold = 4.0; // m/s²
  static const double highJerkThreshold = 10.0; // m/s³

  // Overspeed: 100 km/h in m/s
  static const double overspeedThreshold = 27.8;

  // Fatigue alert after 90 minutes of active riding
  static const int fatigueAlertSeconds = 5400;

  // GPS location update distance filter (meters)
  static const double gpsDistanceFilter = 5.0;

  // GPS fix quality gate — single source of truth (was an inline magic
  // number in ride_recording_provider.dart's _onPosition)
  static const double maxGpsAccuracyM = 25.0;

  // Sensor validation ceilings — reject obviously-broken samples (NaN,
  // sensor glitches/clipping), not legitimate high-g crash spikes
  // (event_detector.dart's crash threshold is 80.0 m/s²)
  static const double maxPlausibleAccelMs2 = 300.0;
  static const double maxPlausibleYawRateRadS = 34.9; // ~2000°/s

  // Motion classification
  static const double movingSpeedThresholdMs = 1.0; // matches existing periodType cutoff
  static const double corneringYawRateThresholdRadS = 0.26; // ~15°/s

  // Complementary filter heading blend — favor GPS course when the fix is
  // accurate, lean more on gyro dead-reckoning when it isn't
  static const double headingGoodAccuracyThresholdM = 8.0;
  static const double headingGpsWeightGoodAccuracy = 0.7;
  static const double headingGpsWeightPoorAccuracy = 0.3;

  // Crash-alert confidence gate (Epic G follow-up: don't act on a crash
  // signal derived from garbage sensor data, e.g. mid-tunnel GPS loss)
  static const int minConfidenceForCrashAlert = 40;

  // Maintenance thresholds (km)
  static const double oilChangeMinKm = 1000;
  static const double oilChangeMaxKm = 1500;
  static const double airFilterMinKm = 8000;
  static const double airFilterMaxKm = 10000;
  static const double chainLubeMinKm = 500;
  static const double chainLubeMaxKm = 700;
  static const double tireCheckMinKm = 5000;
  static const double tireCheckMaxKm = 8000;
}
