import '../../../../core/constants/sensor_constants.dart';

enum RideAlert { none, hardBraking, rapidAccel, overspeed, fatigue }

class EventDetector {
  int hardBrakeCount = 0;
  int rapidAccelCount = 0;
  int highJerkCount = 0;

  RideAlert? _lastAlert;
  DateTime? _lastAlertTime;
  static const Duration _alertTTL = Duration(seconds: 5);

  RideAlert detect({
    double? jerk,
    double speedMs = 0,
    int elapsedSeconds = 0,
  }) {
    final now = DateTime.now();

    if (jerk != null && jerk.abs() > SensorConstants.highJerkThreshold) {
      highJerkCount++;
    }

    if (speedMs > SensorConstants.overspeedThreshold) {
      _lastAlert = RideAlert.overspeed;
      _lastAlertTime = now;
      return RideAlert.overspeed;
    }

    if (elapsedSeconds >= SensorConstants.fatigueAlertSeconds &&
        (_lastAlert != RideAlert.fatigue ||
            _lastAlertTime == null ||
            now.difference(_lastAlertTime!).inSeconds >= 10)) {
      _lastAlert = RideAlert.fatigue;
      _lastAlertTime = now;
      return RideAlert.fatigue;
    }

    if (_lastAlert != null &&
        _lastAlertTime != null &&
        now.difference(_lastAlertTime!) > _alertTTL) {
      _lastAlert = null;
      _lastAlertTime = null;
    }

    return RideAlert.none;
  }

  void reset() {
    hardBrakeCount = 0;
    rapidAccelCount = 0;
    highJerkCount = 0;
    _lastAlert = null;
    _lastAlertTime = null;
  }
}
