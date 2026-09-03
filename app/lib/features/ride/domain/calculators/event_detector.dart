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
  final List<_SpeedSample> _recentSpeeds = []; // Last 2s of speed samples
  static const double _crashAccelThreshold = SensorConstants.crashAccelThreshold;
  static const double _crashJerkThreshold = 10.0; // m/s³
  static const Duration _crashWindow = Duration(seconds: 2);
  static const double _speedDropThreshold = 2.0; // m/s

  CrashSignal? lastCrashSignal;

  /// Classifies one fix.
  ///
  /// [at] is the instant this sample belongs to. It defaults to
  /// `DateTime.now()`, which is correct for the live recording path where
  /// fixes arrive in real time — but **any replay caller must pass it
  /// explicitly**, using the fix's own timestamp.
  ///
  /// This matters because every window in this class is wall-clock relative:
  /// the 2-second crash window, the 2-second speed history, and the 5-second
  /// alert TTL. Replaying an hour of stored fixes takes milliseconds, so with
  /// an implicit `DateTime.now()` every sample lands inside one window — the
  /// crash detector would see the whole ride as a single instant and the
  /// jerk/speed-drop logic would produce nonsense. Passing the stored
  /// timestamp is what makes reconstructing a ride from persisted fixes
  /// (see `AutoRideReconciler`) produce the same events the live path would
  /// have produced.
  ///
  /// Optional rather than required only so the existing live call sites and
  /// the crash-detector test suite keep compiling unchanged; treat it as
  /// required in any new code.
  RideAlert detect({
    double? jerk,
    double? accel,
    double speedMs = 0,
    int elapsedSeconds = 0,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();

    // Update recent speed history (keep last 2 seconds)
    _recentSpeeds.add(_SpeedSample(speedMs: speedMs, timestamp: now));
    _recentSpeeds.removeWhere((s) => now.difference(s.timestamp) > _crashWindow);

    // Track jerk. highJerkCount is a ride-wide tally (any high-jerk moment,
    // used for the ride summary), but _peakJerkInWindow feeds the crash
    // check below and must only reflect jerk that happened WHILE an
    // accel-spike window is open — docs/Issues.md §33.8: this used to update
    // unconditionally, so a jerk spike seconds before an unrelated
    // high-accel event still counted as "in window" by the time the crash
    // check ran, inflating false-positive crash detections.
    if (jerk != null && jerk.abs() > SensorConstants.highJerkThreshold) {
      highJerkCount++;
      if (_highAccelStart != null) {
        _peakJerkInWindow = (_peakJerkInWindow == 0)
            ? jerk.abs()
            : (_peakJerkInWindow + jerk.abs()) / 2; // Moving avg
      }
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

    // Hard braking / rapid acceleration (below the crash threshold).
    // Counters feed the ride summary; the returned alert drives UI/haptics.
    if (accel != null && accel.abs() <= _crashAccelThreshold) {
      if (accel <= SensorConstants.hardBrakingThreshold) {
        hardBrakeCount++;
        _lastAlert = RideAlert.hardBraking;
        _lastAlertTime = now;
        return RideAlert.hardBraking;
      }
      if (accel >= SensorConstants.rapidAccelThreshold) {
        rapidAccelCount++;
        _lastAlert = RideAlert.rapidAccel;
        _lastAlertTime = now;
        return RideAlert.rapidAccel;
      }
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
