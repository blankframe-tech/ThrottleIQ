import 'dart:math' as math;

import '../../../../core/constants/sensor_constants.dart';
import 'event_detector.dart' show CrashSignal;

/// What happened to one IMU spike, confirmed or not.
///
/// Near-misses (a spike that never confirmed) are exactly the data needed to
/// calibrate [SensorConstants.impactThreshold], so every spike produces one of
/// these whether or not it became a crash. They're kept in memory only — no
/// table exists for them yet (claude_sol §1.1.1 step 4 needs a schema change).
class ImpactCandidate {
  final DateTime spikeAt;
  final double peakAccelMs2;
  final double speedBeforeMs;

  /// Lowest GPS speed seen after the spike, or null if no fix arrived.
  final double? speedAfterMs;
  final bool wentStill;
  final bool orientationChanged;
  final bool confirmed;

  const ImpactCandidate({
    required this.spikeAt,
    required this.peakAccelMs2,
    required this.speedBeforeMs,
    required this.speedAfterMs,
    required this.wentStill,
    required this.orientationChanged,
    required this.confirmed,
  });

  Map<String, dynamic> toMap() => {
        'spikeAt': spikeAt.toIso8601String(),
        'peakAccelMs2': peakAccelMs2,
        'speedBeforeMs': speedBeforeMs,
        'speedAfterMs': speedAfterMs,
        'wentStill': wentStill,
        'orientationChanged': orientationChanged,
        'confirmed': confirmed,
      };
}

/// Crash detection from the raw (unfiltered) IMU, confirmed by GPS.
///
/// Replaces the GPS-derived crash branch in `EventDetector.detect`, which
/// could never fire on a live ride: it needed an 80 m/s² GPS speed delta,
/// and speeds above `maxPlausibleSpeedMs` are rejected before they get there
/// (claude_sol §1.1.1).
///
/// **Spike.** A sample whose magnitude `|a| = sqrt(x²+y²+z²)` reaches
/// [impactThreshold], or [_saturationRun] consecutive samples within 2% of
/// the highest magnitude seen this ride (and above [saturationFloor]). The
/// second rule catches budget phones whose accelerometer clips at 4-8 g,
/// where a real impact reads as a flat-topped run rather than a peak.
///
/// **Confirmation.** A spike alone is a pothole, a dropped phone, a slammed
/// top box. It becomes a crash only when, after it:
/// - GPS shows the bike stopped: a fix below [stoppedSpeedMs] within
///   [speedConfirmWindow], at least [minSpeedDropMs] slower than the fastest
///   fix in the few seconds before the spike (so a phone knocked off a bike
///   that was already parked doesn't qualify). Because the location stream
///   has a distance filter, a stopped bike may produce *no* fixes at all;
///   GPS silence for the whole window counts as stopped only if the phone is
///   also still, since a still phone can't be travelling at speed.
/// - **and** the phone is either still (magnitude variance below
///   [stillnessMaxVariance] for [stillnessDuration]) or its gravity vector
///   has rotated more than [orientationChangeDeg] from its pre-spike
///   baseline (bike on its side, engine possibly still running).
///
/// Every threshold here is provisional and uncalibrated — see
/// [SensorConstants.impactThreshold]. All inputs carry explicit timestamps,
/// so the detector is deterministic under test and replay.
class ImpactDetector {
  ImpactDetector({
    this.impactThreshold = SensorConstants.impactThreshold,
    this.saturationFloor = SensorConstants.impactSaturationFloorMs2,
    this.stoppedSpeedMs = 2.0,
    this.minSpeedDropMs = 2.0,
    this.speedConfirmWindow = const Duration(seconds: 5),
    this.stillnessDuration = const Duration(seconds: 3),
    this.stillnessMaxVariance = 0.25,
    this.orientationChangeDeg = 45.0,
    this.onCandidate,
  });

  final double impactThreshold;
  final double saturationFloor;
  final double stoppedSpeedMs;
  final double minSpeedDropMs;
  final Duration speedConfirmWindow;
  final Duration stillnessDuration;
  final double stillnessMaxVariance; // (m/s²)²
  final double orientationChangeDeg;

  /// Called once per spike when it resolves (confirmed or expired).
  final void Function(ImpactCandidate candidate)? onCandidate;

  static const int _saturationRun = 3;
  static const double _saturationBand = 0.98;
  static const Duration _preSpikeSpeedWindow = Duration(seconds: 5);
  static const double _gravityAlpha = 0.1;
  static const int _maxCandidates = 50;

  /// Spike → stop within [speedConfirmWindow] → then [stillnessDuration] of
  /// stillness, so this is the longest a spike can stay pending.
  Duration get _pendingWindow => speedConfirmWindow + stillnessDuration;

  final List<({DateTime t, double speedMs})> _speeds = [];
  double _rideMaxMagnitude = 0;
  int _nearMaxRun = 0;
  double? _prevMagnitude;
  DateTime? _prevSampleAt;

  List<double>? _gravity; // low-passed accelerometer (with gravity)

  // Pending spike state
  DateTime? _spikeAt;
  double _peak = 0;
  double _peakJerk = 0;
  double _speedBefore = 0;
  double? _minSpeedAfter;
  bool _stopSeen = false;
  List<double>? _gravityBaseline;
  bool _everStill = false;
  bool _everRotated = false;
  final List<({DateTime t, double mag})> _postSpike = [];

  final List<ImpactCandidate> _candidates = [];

  /// Most recent confirmed crash, for the dismissal/false-positive report.
  CrashSignal? lastCrashSignal;

  /// Recent spike outcomes (newest last, capped at [_maxCandidates]).
  List<ImpactCandidate> get candidates => List.unmodifiable(_candidates);

  bool get hasPendingSpike => _spikeAt != null;

  /// Feeds one raw `UserAccelerometerEvent` sample (gravity removed, m/s²).
  /// Returns a [CrashSignal] on the sample that confirms a crash.
  CrashSignal? addSample(DateTime t, double x, double y, double z) {
    final mag = math.sqrt(x * x + y * y + z * z);
    if (!mag.isFinite) return null;

    var jerk = 0.0;
    if (_prevMagnitude != null && _prevSampleAt != null) {
      final dt = t.difference(_prevSampleAt!).inMicroseconds / 1e6;
      if (dt > 0) jerk = (mag - _prevMagnitude!).abs() / dt;
    }
    _prevMagnitude = mag;
    _prevSampleAt = t;

    if (mag > _rideMaxMagnitude) _rideMaxMagnitude = mag;
    if (mag >= saturationFloor && mag >= _saturationBand * _rideMaxMagnitude) {
      _nearMaxRun++;
    } else {
      _nearMaxRun = 0;
    }
    final isSpike = mag >= impactThreshold || _nearMaxRun >= _saturationRun;

    if (isSpike) {
      if (_spikeAt == null) {
        _openSpike(t, mag);
      } else {
        // Max, not average — the same rule as the jerk fix in §78.2.
        _peak = math.max(_peak, mag);
      }
    }

    if (_spikeAt == null) return null;
    _peakJerk = math.max(_peakJerk, jerk);

    _postSpike.add((t: t, mag: mag));
    _postSpike.removeWhere((s) => t.difference(s.t) > stillnessDuration);
    if (_isStill(t)) _everStill = true;

    return _evaluate(t);
  }

  /// Feeds one accelerometer sample *including* gravity. Optional: without
  /// it, confirmation relies on stillness alone.
  void addGravitySample(DateTime t, double x, double y, double z) {
    final g = _gravity;
    if (g == null) {
      _gravity = [x, y, z];
    } else {
      g[0] = _gravityAlpha * x + (1 - _gravityAlpha) * g[0];
      g[1] = _gravityAlpha * y + (1 - _gravityAlpha) * g[1];
      g[2] = _gravityAlpha * z + (1 - _gravityAlpha) * g[2];
    }
    if (_spikeAt != null && _gravityBaseline != null && _gravity != null) {
      if (_angleDeg(_gravityBaseline!, _gravity!) > orientationChangeDeg) {
        _everRotated = true;
      }
    }
  }

  /// Feeds one accepted GPS fix's speed. Returns a [CrashSignal] if this fix
  /// is the one that confirms a pending spike.
  CrashSignal? addSpeed(DateTime t, double speedMs) {
    if (!speedMs.isFinite) return null;
    _speeds.add((t: t, speedMs: speedMs));
    _speeds.removeWhere((s) => t.difference(s.t) > _preSpikeSpeedWindow * 2);

    if (_spikeAt == null) return null;
    if (!t.isBefore(_spikeAt!)) {
      _minSpeedAfter =
          _minSpeedAfter == null ? speedMs : math.min(_minSpeedAfter!, speedMs);
      if (t.difference(_spikeAt!) <= speedConfirmWindow &&
          speedMs < stoppedSpeedMs &&
          _speedBefore - speedMs >= minSpeedDropMs) {
        _stopSeen = true;
      }
    }
    return _evaluate(t);
  }

  void _openSpike(DateTime t, double mag) {
    _spikeAt = t;
    _peak = mag;
    _peakJerk = 0;
    _minSpeedAfter = null;
    _stopSeen = false;
    _everStill = false;
    _everRotated = false;
    _postSpike.clear();
    _gravityBaseline = _gravity == null ? null : List.of(_gravity!);
    _speedBefore = 0;
    for (final s in _speeds) {
      if (!s.t.isAfter(t) && t.difference(s.t) <= _preSpikeSpeedWindow) {
        _speedBefore = math.max(_speedBefore, s.speedMs);
      }
    }
  }

  bool _isStill(DateTime now) {
    if (_postSpike.length < 2) return false;
    // The buffer must cover the whole stillness duration, and only with
    // post-spike samples (the spike sample itself is loud, so it falls out
    // of any quiet window by construction).
    final span = now.difference(_postSpike.first.t);
    // One sample period of slack: the buffer trims at exactly the duration.
    if (span < stillnessDuration - const Duration(milliseconds: 100)) {
      return false;
    }
    var sum = 0.0;
    for (final s in _postSpike) {
      sum += s.mag;
    }
    final mean = sum / _postSpike.length;
    var sq = 0.0;
    for (final s in _postSpike) {
      sq += (s.mag - mean) * (s.mag - mean);
    }
    return sq / _postSpike.length < stillnessMaxVariance;
  }

  CrashSignal? _evaluate(DateTime now) {
    final spikeAt = _spikeAt!;
    final sinceSpike = now.difference(spikeAt);

    final gpsSilent = _minSpeedAfter == null &&
        sinceSpike >= speedConfirmWindow &&
        _speedBefore >= minSpeedDropMs;
    final stopped = _stopSeen || (gpsSilent && _everStill);
    final settled = _everStill || _everRotated;

    if (stopped && settled) {
      final signal = CrashSignal(
        peakAccelerationMs2: _peak,
        peakJerkMs3: _peakJerk,
        detectedAt: now,
        hadHighAccelSpike: true,
        hadJerkSpike: _peakJerk > SensorConstants.highJerkThreshold,
        hadSpeedDrop: true,
      );
      lastCrashSignal = signal;
      _closeSpike(confirmed: true);
      return signal;
    }

    if (sinceSpike > _pendingWindow) _closeSpike(confirmed: false);
    return null;
  }

  void _closeSpike({required bool confirmed}) {
    final candidate = ImpactCandidate(
      spikeAt: _spikeAt!,
      peakAccelMs2: _peak,
      speedBeforeMs: _speedBefore,
      speedAfterMs: _minSpeedAfter,
      wentStill: _everStill,
      orientationChanged: _everRotated,
      confirmed: confirmed,
    );
    _candidates.add(candidate);
    if (_candidates.length > _maxCandidates) _candidates.removeAt(0);
    _spikeAt = null;
    _postSpike.clear();
    _gravityBaseline = null;
    onCandidate?.call(candidate);
  }

  static double _angleDeg(List<double> a, List<double> b) {
    final na = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    final nb = math.sqrt(b[0] * b[0] + b[1] * b[1] + b[2] * b[2]);
    if (na == 0 || nb == 0) return 0;
    final cos = ((a[0] * b[0] + a[1] * b[1] + a[2] * b[2]) / (na * nb))
        .clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }

  void reset() {
    _speeds.clear();
    _rideMaxMagnitude = 0;
    _nearMaxRun = 0;
    _prevMagnitude = null;
    _prevSampleAt = null;
    _gravity = null;
    _spikeAt = null;
    _peak = 0;
    _peakJerk = 0;
    _speedBefore = 0;
    _minSpeedAfter = null;
    _stopSeen = false;
    _gravityBaseline = null;
    _everStill = false;
    _everRotated = false;
    _postSpike.clear();
    _candidates.clear();
    lastCrashSignal = null;
  }
}
