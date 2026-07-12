import '../../../../core/constants/sensor_constants.dart';

enum RideAlert { none, hardBraking, rapidAccel, overspeed, fatigue }

class EventDetector {
  int hardBrakeCount = 0;
  int rapidAccelCount = 0;
  int highJerkCount = 0;

  // GPS-based: only checks overspeed and fatigue
  // (braking/accel detected faster by sensor stream in provider)
  RideAlert detect({
    double? jerk,
    double speedMs = 0,
    int elapsedSeconds = 0,
  }) {
    if (jerk != null && jerk.abs() > SensorConstants.highJerkThreshold) {
      highJerkCount++;
    }
    if (speedMs > SensorConstants.overspeedThreshold) {
      return RideAlert.overspeed;
    }
    if (elapsedSeconds >= SensorConstants.fatigueAlertSeconds) {
      return RideAlert.fatigue;
    }
    return RideAlert.none;
  }

  void reset() {
    hardBrakeCount = 0;
    rapidAccelCount = 0;
    highJerkCount = 0;
  }
}
