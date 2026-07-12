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
