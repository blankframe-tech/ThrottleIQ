import '../../../../core/constants/sensor_constants.dart';

enum RideAlert { none, hardBraking, rapidAccel, overspeed, fatigue }

class EventDetector {
  int hardBrakeCount = 0;
  int rapidAccelCount = 0;
  int highJerkCount = 0;

  RideAlert detect({
    double? acceleration,
    double? jerk,
    double speedMs = 0,
    int elapsedSeconds = 0,
  }) {
    if (acceleration != null) {
      if (acceleration < SensorConstants.hardBrakingThreshold) {
        hardBrakeCount++;
        return RideAlert.hardBraking;
      }
      if (acceleration > SensorConstants.rapidAccelThreshold) {
        rapidAccelCount++;
        return RideAlert.rapidAccel;
      }
    }
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
