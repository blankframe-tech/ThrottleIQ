import '../../../../core/constants/sensor_constants.dart';

enum RideAlert { none, hardBraking, rapidAccel, overspeed, fatigue, crash }

class CrashSignal {
  final double peakAccelerationMs2;
  final double peakJerkMs3;
  final DateTime detectedAt;
  final bool hadHighAccelSpike; // >8g
  final bool hadJerkSpike; // >10 m/s³
  final bool hadSpeedDrop; // speed -> 0 within 2s

  CrashSignal({
    required this.peakAccelerationMs2,
    required this.peakJerkMs3,
    required this.detectedAt,
    required this.hadHighAccelSpike,
    required this.hadJerkSpike,
    required this.hadSpeedDrop,
  });

  Map<String, dynamic> toMap() {
    return {
      'peakAccelerationMs2': peakAccelerationMs2,
      'peakJerkMs3': peakJerkMs3,
      'detectedAt': detectedAt.toIso8601String(),
      'hadHighAccelSpike': hadHighAccelSpike,
      'hadJerkSpike': hadJerkSpike,
      'hadSpeedDrop': hadSpeedDrop,
    };
  }
}

class EventDetector {
  int hardBrakeCount = 0;
  int rapidAccelCount = 0;
  int highJerkCount = 0;

  RideAlert? _lastAlert;
  DateTime? _lastAlertTime;
  static const Duration _alertTTL = Duration(seconds: 5);

  // Crash detection state
  DateTime? _highAccelStart; // When spike >8g started
  double _peakAccelSinceSpike = 0;
  double _peakJerkInWindow = 0;
  List<_SpeedSample> _recentSpeeds = []; // Last 2s of speed samples
  static const double _crashAccelThreshold = 8.0; // g (>80 m/s²)
  static const double _crashJerkThreshold = 10.0; // m/s³
  static const Duration _crashWindow = Duration(seconds: 2);
  static const double _speedDropThreshold = 2.0; // m/s

  CrashSignal? lastCrashSignal;

  RideAlert detect({
    double? jerk,
    double? accel,
    double speedMs = 0,
    int elapsedSeconds = 0,
  }) {
    final now = DateTime.now();

    // Update recent speed history (keep last 2 seconds)
    _recentSpeeds.add(_SpeedSample(speedMs: speedMs, timestamp: now));
    _recentSpeeds.removeWhere((s) => now.difference(s.timestamp) > _crashWindow);

    // Track jerk
    if (jerk != null && jerk.abs() > SensorConstants.highJerkThreshold) {
      highJerkCount++;
      _peakJerkInWindow = (_peakJerkInWindow == 0)
          ? jerk.abs()
          : (_peakJerkInWindow + jerk.abs()) / 2; // Moving avg
    }

    // Detect high-acceleration spike (>8g threshold)
    if (accel != null && accel.abs() > _crashAccelThreshold) {
      if (_highAccelStart == null) {
        _highAccelStart = now;
        _peakAccelSinceSpike = accel.abs();
      } else {
        _peakAccelSinceSpike = (_peakAccelSinceSpike > accel.abs())
            ? _peakAccelSinceSpike
            : accel.abs();
      }
    }

    // Check if accel spike + jerk spike + speed drop = CRASH
    if (_highAccelStart != null &&
        now.difference(_highAccelStart!) <= _crashWindow) {
      final hadSpikeDrop = _checkSpeedDrop();
      final hadJerkSpike = _peakJerkInWindow > _crashJerkThreshold;

      if (hadSpikeDrop && hadJerkSpike) {
        lastCrashSignal = CrashSignal(
          peakAccelerationMs2: _peakAccelSinceSpike,
          peakJerkMs3: _peakJerkInWindow,
          detectedAt: now,
          hadHighAccelSpike: true,
          hadJerkSpike: true,
          hadSpeedDrop: true,
        );
        _resetCrashState();
        return RideAlert.crash;
      }
    }

    // Reset accel tracking if window expired
    if (_highAccelStart != null &&
        now.difference(_highAccelStart!) > _crashWindow) {
      _resetCrashState();
    }

    // Other alerts
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

  bool _checkSpeedDrop() {
    if (_recentSpeeds.length < 2) return false;
    final oldest = _recentSpeeds.first;
    final newest = _recentSpeeds.last;
    final speedDelta = oldest.speedMs - newest.speedMs;
    return speedDelta >= _speedDropThreshold && newest.speedMs < 1.0;
  }

  void _resetCrashState() {
    _highAccelStart = null;
    _peakAccelSinceSpike = 0;
    _peakJerkInWindow = 0;
    _recentSpeeds.clear();
  }

  void reset() {
    hardBrakeCount = 0;
    rapidAccelCount = 0;
    highJerkCount = 0;
    _lastAlert = null;
    _lastAlertTime = null;
    _resetCrashState();
    lastCrashSignal = null;
  }
}

class _SpeedSample {
  final double speedMs;
  final DateTime timestamp;
  _SpeedSample({required this.speedMs, required this.timestamp});
}
