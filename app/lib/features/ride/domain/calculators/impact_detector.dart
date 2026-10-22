import 'dart:collection';
import 'dart:math' as math;

import '../../../../core/constants/sensor_constants.dart';
import 'event_detector.dart' show CrashSignal;

/// Why an impact became a possible fall (tier 1 or 2).
enum ImpactReason {
  /// Never got past tier 0.
  none,

  /// Moving before the impact, then stopped and settled (rules 1-5).
  speedDrop,

  /// Already stopped, then an impact, and the phone stays rotated (rule 6):
  /// a tip-over from a standstill, which no speed rule can see.
  tipOver,
}

/// One impact and what it turned into.
///
/// Every impact produces one of these, at whatever tier it reached: tier 0
/// near-misses are exactly the data needed to calibrate the thresholds, and
/// shadow mode saves them to `impact_events` (see SensorFusionCoordinator).
class ImpactCandidate {
  final DateTime spikeAt;

  /// 0 = an impact, logged only. 1 = a possible fall, asked about after the
  /// ride. 2 = a likely crash, the only tier that may raise the live alarm.
  final int tier;
  final ImpactReason reason;

  /// Peak of the motion-filtered, gravity-removed acceleration (m/s²).
  final double peakAccelMs2;

  /// Peak of the raw accelerometer magnitude minus 1 g (m/s²); 0 without
  /// the raw stream. iOS filters the other stream, so short impacts often
  /// show up higher here.
  final double peakRawMs2;
  final int freefallMs;

  /// Gyro rotation in the 2 s after the impact (degrees, summed |ω|·dt).
  final double rotationDeg;

  /// Largest angle between the pre-impact gravity direction and any later
  /// one, while the impact was pending (degrees).
  final double orientationChangeDeg;
  final double speedBeforeMs;

  /// Lowest GPS speed seen after the impact, or null if no fix arrived.
  final double? speedAfterMs;
  final bool wentStill;
  final bool resumed;
  final bool saturated;

  /// Seconds between the last GPS fix and the impact; null if there was none.
  final double? lastFixAgeS;

  /// RMS of the motion-filtered acceleration over the 10 s before the impact:
  /// how hard the phone was being shaken (mount vibration vs pocket).
  final double vibrationRmsMs2;

  const ImpactCandidate({
    required this.spikeAt,
    required this.tier,
    required this.reason,
    required this.peakAccelMs2,
    required this.peakRawMs2,
    required this.freefallMs,
    required this.rotationDeg,
    required this.orientationChangeDeg,
    required this.speedBeforeMs,
    required this.speedAfterMs,
    required this.wentStill,
    required this.resumed,
    required this.saturated,
    required this.lastFixAgeS,
    required this.vibrationRmsMs2,
  });

  /// Tier 2: the only tier allowed to raise the live alarm.
  bool get confirmed => tier >= 2;

  /// The phone turned at least 45° from its pre-impact angle at some point.
  bool get orientationChanged => orientationChangeDeg >= 45;

  /// The larger of the two peaks, in g.
  double get peakG => math.max(peakAccelMs2, peakRawMs2) / 9.81;

  /// Everything the detector measured, numbers only and rounded, for the
  /// `impact_events.features` column and its cloud copy.
  Map<String, Object?> toFeatures() => {
        'peakUserMs2': _round(peakAccelMs2),
        'peakRawMs2': _round(peakRawMs2),
        'freefallMs': freefallMs,
        'rotationDeg': _round(rotationDeg, 1),
        'orientationChangeDeg': _round(orientationChangeDeg, 1),
        'speedBeforeMs': _round(speedBeforeMs),
        'speedAfterMs': speedAfterMs == null ? null : _round(speedAfterMs!),
        'wentStill': wentStill,
        'resumed': resumed,
        'saturated': saturated,
        'lastFixAgeS': lastFixAgeS == null ? null : _round(lastFixAgeS!, 1),
        'vibrationRmsMs2': _round(vibrationRmsMs2),
      };

  static double _round(double v, [int digits = 2]) {
    final f = math.pow(10, digits);
    return (v * f).roundToDouble() / f;
  }
}

/// Crash detection from the IMU, confirmed by GPS and by what the phone does
/// afterwards. Every threshold is provisional and uncalibrated: see
/// [SensorConstants.impactThreshold] and the plan in
/// `DOCS/General/CRASH TESTING/crash_analysis_and_detection_plan.html`.
///
/// **Impact (tier 0).** Any of: the motion-filtered magnitude reaches
/// [askThreshold]; the raw magnitude reaches 1 g + [askThreshold]; a run of
/// [_saturationRun] samples pinned within 2% of the ride's max (budget
/// phones clip at 4-8 g); or a free fall of at least 100 ms ending (a phone
/// thrown from a pocket).
///
/// **Possible fall (tier 1)**, by either rule:
/// - *Speed drop.* The fastest fix in the [preSpikeSpeedWindow] before the
///   impact was at least [minSpeedDropMs]. After it, the bike stopped: a fix
///   under [stoppedSpeedMs] within [stopConfirmWindow], or no fix at all for
///   [silenceAsStop] (the distance filter sends nothing from a phone that
///   isn't moving). And it settled: the phone went still, or turned
///   [settleRotationDeg], or the bike didn't ride on for [noResumeAfter].
///   A fix at [resumeSpeedMs] or more after [resumeGrace] means it rode on,
///   and cancels the rule.
/// - *Tip-over.* The bike was already stopped: the last fix was under
///   [stoppedSpeedMs], or nothing arrived for [tipOverQuietBefore]. Then the
///   phone stays turned [tipOverRotationDeg] from its pre-impact angle for
///   [tipOverHold].
///
/// **Likely crash (tier 2)**, the live-alarm tier: the speed-drop rule, with
/// [alertMinSpeedMs] before the impact, a peak of [impactThreshold] or a
/// clipped run, and the phone either still for [alertStillFor] or held
/// rotated (the tip-over hold).
///
/// All inputs carry explicit timestamps, so the detector is deterministic
/// under test and replay.
class ImpactDetector {
  ImpactDetector({
    this.askThreshold = SensorConstants.impactAskThreshold,
    this.impactThreshold = SensorConstants.impactThreshold,
    this.saturationFloor = SensorConstants.impactSaturationFloorMs2,
    this.stoppedSpeedMs = 1.0,
    this.minSpeedDropMs = 1.0,
    this.resumeSpeedMs = 2.0,
    this.preSpikeSpeedWindow = const Duration(seconds: 10),
    this.stopConfirmWindow = const Duration(seconds: 10),
    this.silenceAsStop = const Duration(seconds: 5),
    this.resumeGrace = const Duration(milliseconds: 1500),
    this.noResumeAfter = const Duration(seconds: 20),
    this.stillnessDuration = const Duration(seconds: 3),
    this.stillnessMaxVariance = 0.25,
    this.settleRotationDeg = 45.0,
    this.tipOverRotationDeg = 60.0,
    this.tipOverHold = const Duration(seconds: 5),
    this.tipOverQuietBefore = const Duration(seconds: 3),
    this.alertMinSpeedMs = 4.2,
    this.alertStillFor = const Duration(seconds: 10),
    this.pendingWindow = const Duration(seconds: 25),
    this.onCandidate,
  });

  final double askThreshold;
  final double impactThreshold;
  final double saturationFloor;
  final double stoppedSpeedMs;
  final double minSpeedDropMs;
  final double resumeSpeedMs;
  final Duration preSpikeSpeedWindow;
  final Duration stopConfirmWindow;
  final Duration silenceAsStop;
  final Duration resumeGrace;
  final Duration noResumeAfter;
  final Duration stillnessDuration;
  final double stillnessMaxVariance; // (m/s²)²
  final double settleRotationDeg;
  final double tipOverRotationDeg;
  final Duration tipOverHold;
  final Duration tipOverQuietBefore;
  final double alertMinSpeedMs;
  final Duration alertStillFor;

  /// How long an impact stays open. Long enough for [noResumeAfter] and
  /// [alertStillFor] to play out.
  final Duration pendingWindow;

  /// Called once per impact when it resolves (at tier 2, or when
  /// [pendingWindow] runs out). Settable so a coordinator can attach to an
  /// injected detector.
  void Function(ImpactCandidate candidate)? onCandidate;

  static const int _saturationRun = 3;
  static const double _saturationBand = 0.98;
  static const double _g = 9.81;
  static const double _freefallMs2 = 0.3 * _g;
  static const Duration _freefallMin = Duration(milliseconds: 100);
  static const Duration _freefallLinksSpike = Duration(seconds: 1);
  static const Duration _vibrationWindow = Duration(seconds: 10);
  static const Duration _rotationWindow = Duration(seconds: 2);
  static const Duration _stoppedBeforeMaxAge = Duration(minutes: 5);

  /// Gravity low-pass weight per 50 ms; scaled to the real sample gap so the
  /// time constant doesn't change with the sampling rate.
  static const double _gravityAlpha = 0.1;
  static const int _maxCandidates = 50;

  // ── Always-on state ─────────────────────────────────────────────────────
  final List<({DateTime t, double speedMs})> _speeds = [];
  DateTime? _lastFixAt;
  double _lastFixSpeed = 0;
  double _rideMaxMagnitude = 0;
  int _nearMaxRun = 0;
  double? _prevMagnitude;
  DateTime? _prevSampleAt;
  List<double>? _gravity; // low-passed accelerometer (with gravity)
  DateTime? _prevGravityAt;
  DateTime? _freefallStart;
  int _recentFreefallMs = 0;
  DateTime? _recentFreefallEnd;
  final ListQueue<({DateTime t, double sq})> _vibration = ListQueue();
  double _vibrationSumSq = 0;
  DateTime? _prevGyroAt;

  // ── Pending impact ──────────────────────────────────────────────────────
  DateTime? _spikeAt;
  double _peak = 0;
  double _peakRaw = 0;
  double _peakJerk = 0;
  bool _saturated = false;
  int _freefallMs = 0;
  double _rotationDeg = 0;
  double _speedBefore = 0;
  double? _lastFixAgeS;
  bool _stoppedBefore = false;
  double? _minSpeedAfter;
  bool _resumed = false;
  bool _stopSeen = false;
  bool _silentSeen = false;
  List<double>? _gravityBaseline;
  double _maxOrientationDeg = 0;
  DateTime? _rotatedSince;
  bool _rotationHeld = false;
  bool _everStill = false;
  DateTime? _stillSince;
  Duration _maxStillFor = Duration.zero;
  double _vibrationRms = 0;
  int _tier = 0;
  ImpactReason _reason = ImpactReason.none;
  final List<({DateTime t, double mag})> _postSpike = [];

  final List<ImpactCandidate> _candidates = [];

  /// Most recent tier-2 crash, for the dismissal/false-positive report.
  CrashSignal? lastCrashSignal;

  /// Recent impact outcomes (newest last, capped at [_maxCandidates]).
  List<ImpactCandidate> get candidates => List.unmodifiable(_candidates);

  bool get hasPendingSpike => _spikeAt != null;

  /// Feeds one motion-filtered, gravity-removed sample
  /// (`UserAccelerometerEvent`, m/s²). Returns a [CrashSignal] on the sample
  /// that reaches tier 2.
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
    final nearMax =
        mag >= saturationFloor && mag >= _saturationBand * _rideMaxMagnitude;
    _nearMaxRun = nearMax ? _nearMaxRun + 1 : 0;
    final clipped = _nearMaxRun >= _saturationRun;

    if (mag >= askThreshold || clipped) {
      if (_spikeAt == null) _openSpike(t);
      // Max, not average — the same rule as the jerk fix in §78.2.
      _peak = math.max(_peak, mag);
      if (clipped) _saturated = true;
    }

    // After the spike check, so the impact itself never counts as the
    // vibration the phone was under before it.
    _vibration.add((t: t, sq: mag * mag));
    _vibrationSumSq += mag * mag;
    while (_vibration.isNotEmpty &&
        t.difference(_vibration.first.t) > _vibrationWindow) {
      _vibrationSumSq -= _vibration.removeFirst().sq;
    }

    if (_spikeAt == null) return null;
    _peakJerk = math.max(_peakJerk, jerk);

    _postSpike.add((t: t, mag: mag));
    _postSpike.removeWhere((s) => t.difference(s.t) > stillnessDuration);
    _trackStillness(t);

    return _evaluate(t);
  }

  /// Feeds one accelerometer sample *including* gravity. Drives the
  /// orientation checks, the raw peak and free-fall detection; optional (the
  /// speed rule can still settle on stillness without it).
  CrashSignal? addGravitySample(DateTime t, double x, double y, double z) {
    final mag = math.sqrt(x * x + y * y + z * z);
    if (!mag.isFinite) return null;

    final g = _gravity;
    if (g == null) {
      _gravity = [x, y, z];
    } else {
      final prev = _prevGravityAt;
      final dt = prev == null
          ? 0.05
          : math.max(0, t.difference(prev).inMicroseconds) / 1e6;
      final a = 1 - math.pow(1 - _gravityAlpha, dt / 0.05).toDouble();
      g[0] = a * x + (1 - a) * g[0];
      g[1] = a * y + (1 - a) * g[1];
      g[2] = a * z + (1 - a) * g[2];
    }
    _prevGravityAt = t;

    if (mag < _freefallMs2) {
      _freefallStart ??= t;
    } else if (_freefallStart != null) {
      final fell = t.difference(_freefallStart!);
      _freefallStart = null;
      if (fell >= _freefallMin) {
        _recentFreefallMs = fell.inMilliseconds;
        _recentFreefallEnd = t;
        if (_spikeAt == null) {
          _openSpike(t); // the free fall ending is the landing
        } else {
          _freefallMs = math.max(_freefallMs, fell.inMilliseconds);
        }
      }
    }

    final rawExcess = mag - _g;
    if (rawExcess >= askThreshold && _spikeAt == null) _openSpike(t);

    if (_spikeAt == null) return null;
    _peakRaw = math.max(_peakRaw, rawExcess);
    final baseline = _gravityBaseline;
    if (baseline != null) {
      final angle = _angleDeg(baseline, _gravity!);
      if (angle > _maxOrientationDeg) _maxOrientationDeg = angle;
      if (angle >= tipOverRotationDeg) {
        _rotatedSince ??= t;
        if (t.difference(_rotatedSince!) >= tipOverHold) _rotationHeld = true;
      } else {
        _rotatedSince = null;
      }
    }
    return _evaluate(t);
  }

  /// Feeds one gyroscope sample (rad/s). Only measures how far the phone
  /// spun in the 2 s after an impact; never decides a tier by itself.
  void addGyroSample(DateTime t, double x, double y, double z) {
    final w = math.sqrt(x * x + y * y + z * z);
    if (!w.isFinite) return;
    final prev = _prevGyroAt;
    _prevGyroAt = t;
    final spikeAt = _spikeAt;
    if (spikeAt == null || prev == null) return;
    final since = t.difference(spikeAt);
    if (since.isNegative || since > _rotationWindow) return;
    final dt = t.difference(prev).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.5) return;
    _rotationDeg += w * dt * 180 / math.pi;
  }

  /// Feeds one accepted GPS fix's speed. Returns a [CrashSignal] if this fix
  /// is the one that brings a pending impact to tier 2.
  CrashSignal? addSpeed(DateTime t, double speedMs) {
    if (!speedMs.isFinite) return null;
    _speeds.add((t: t, speedMs: speedMs));
    _speeds.removeWhere((s) => t.difference(s.t) > preSpikeSpeedWindow * 2);
    _lastFixAt = t;
    _lastFixSpeed = speedMs;

    final spikeAt = _spikeAt;
    if (spikeAt == null) return null;
    if (!t.isBefore(spikeAt)) {
      _minSpeedAfter =
          _minSpeedAfter == null ? speedMs : math.min(_minSpeedAfter!, speedMs);
      final since = t.difference(spikeAt);
      // A fix right after the impact can still carry pre-impact speed (GPS
      // speed is smoothed over about a second), so it can't mean "rode on".
      if (speedMs >= resumeSpeedMs && since >= resumeGrace) _resumed = true;
      if (since <= stopConfirmWindow &&
          speedMs < stoppedSpeedMs &&
          _speedBefore - speedMs >= minSpeedDropMs) {
        _stopSeen = true;
      }
    }
    return _evaluate(t);
  }

  void _openSpike(DateTime t) {
    _spikeAt = t;
    _peak = 0;
    _peakRaw = 0;
    _peakJerk = 0;
    _saturated = false;
    final ff = _recentFreefallEnd;
    _freefallMs = ff != null &&
            !t.difference(ff).isNegative &&
            t.difference(ff) <= _freefallLinksSpike
        ? _recentFreefallMs
        : 0;
    _rotationDeg = 0;
    _minSpeedAfter = null;
    _resumed = false;
    _stopSeen = false;
    _silentSeen = false;
    _everStill = false;
    _stillSince = null;
    _maxStillFor = Duration.zero;
    _maxOrientationDeg = 0;
    _rotatedSince = null;
    _rotationHeld = false;
    _tier = 0;
    _reason = ImpactReason.none;
    _postSpike.clear();
    _gravityBaseline = _gravity == null ? null : List.of(_gravity!);
    _vibrationRms = _vibration.isEmpty
        ? 0
        : math.sqrt(math.max(0, _vibrationSumSq) / _vibration.length);

    _speedBefore = 0;
    for (final s in _speeds) {
      if (!s.t.isAfter(t) && t.difference(s.t) <= preSpikeSpeedWindow) {
        _speedBefore = math.max(_speedBefore, s.speedMs);
      }
    }
    final lastFixAt = _lastFixAt;
    if (lastFixAt == null || lastFixAt.isAfter(t)) {
      _lastFixAgeS = null;
      _stoppedBefore = false;
    } else {
      final age = t.difference(lastFixAt);
      _lastFixAgeS = age.inMilliseconds / 1000;
      // A slow last fix, or none for a while: with the 3 m distance filter a
      // phone that sends nothing for 3 s has moved less than 3 m.
      _stoppedBefore = age <= _stoppedBeforeMaxAge &&
          (_lastFixSpeed < stoppedSpeedMs || age >= tipOverQuietBefore);
    }
  }

  void _trackStillness(DateTime now) {
    if (_isStill(now)) {
      _everStill = true;
      _stillSince ??= now.subtract(stillnessDuration);
      final stillFor = now.difference(_stillSince!);
      if (stillFor > _maxStillFor) _maxStillFor = stillFor;
    } else {
      _stillSince = null;
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

    // Latched: a stop seen once stays seen, even after a late fix arrives.
    if (_minSpeedAfter == null &&
        sinceSpike >= silenceAsStop &&
        _speedBefore >= minSpeedDropMs) {
      _silentSeen = true;
    }
    final stopped = !_resumed && (_stopSeen || _silentSeen);
    final noResume = !_resumed && sinceSpike >= noResumeAfter;
    final settled =
        _everStill || _maxOrientationDeg >= settleRotationDeg || noResume;
    final speedRule = _speedBefore >= minSpeedDropMs && stopped && settled;

    if (_tier < 1 && speedRule) {
      _tier = 1;
      _reason = ImpactReason.speedDrop;
    }
    if (_tier < 1 && _stoppedBefore && _rotationHeld && !_resumed) {
      _tier = 1;
      _reason = ImpactReason.tipOver;
    }

    final hardEnough =
        _peak >= impactThreshold || _peakRaw >= impactThreshold || _saturated;
    if (speedRule &&
        _speedBefore >= alertMinSpeedMs &&
        hardEnough &&
        (_maxStillFor >= alertStillFor || _rotationHeld)) {
      _tier = 2;
      _reason = ImpactReason.speedDrop;
      final signal = CrashSignal(
        peakAccelerationMs2: math.max(_peak, _peakRaw),
        peakJerkMs3: _peakJerk,
        detectedAt: now,
        hadHighAccelSpike: true,
        hadJerkSpike: _peakJerk > SensorConstants.highJerkThreshold,
        hadSpeedDrop: true,
      );
      lastCrashSignal = signal;
      _closeSpike();
      return signal;
    }

    if (sinceSpike > pendingWindow) _closeSpike();
    return null;
  }

  /// Resolves a pending impact now, at the tier it has reached. For a ride
  /// that ends inside [pendingWindow] — likely right after a real fall —
  /// which would otherwise lose the impact. Never raises the alarm.
  void flush() {
    if (_spikeAt != null) _closeSpike();
  }

  void _closeSpike() {
    final candidate = ImpactCandidate(
      spikeAt: _spikeAt!,
      tier: _tier,
      reason: _reason,
      peakAccelMs2: _peak,
      peakRawMs2: math.max(0, _peakRaw),
      freefallMs: _freefallMs,
      rotationDeg: _rotationDeg,
      orientationChangeDeg: _maxOrientationDeg,
      speedBeforeMs: _speedBefore,
      speedAfterMs: _minSpeedAfter,
      wentStill: _everStill,
      resumed: _resumed,
      saturated: _saturated,
      lastFixAgeS: _lastFixAgeS,
      vibrationRmsMs2: _vibrationRms,
    );
    _candidates.add(candidate);
    if (_candidates.length > _maxCandidates) _candidates.removeAt(0);
    _spikeAt = null;
    _postSpike.clear();
    _gravityBaseline = null;
    _rotatedSince = null;
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
    _lastFixAt = null;
    _lastFixSpeed = 0;
    _rideMaxMagnitude = 0;
    _nearMaxRun = 0;
    _prevMagnitude = null;
    _prevSampleAt = null;
    _gravity = null;
    _prevGravityAt = null;
    _freefallStart = null;
    _recentFreefallMs = 0;
    _recentFreefallEnd = null;
    _vibration.clear();
    _vibrationSumSq = 0;
    _prevGyroAt = null;
    _spikeAt = null;
    _peak = 0;
    _peakRaw = 0;
    _peakJerk = 0;
    _saturated = false;
    _freefallMs = 0;
    _rotationDeg = 0;
    _speedBefore = 0;
    _lastFixAgeS = null;
    _stoppedBefore = false;
    _minSpeedAfter = null;
    _resumed = false;
    _stopSeen = false;
    _silentSeen = false;
    _gravityBaseline = null;
    _maxOrientationDeg = 0;
    _rotatedSince = null;
    _rotationHeld = false;
    _everStill = false;
    _stillSince = null;
    _maxStillFor = Duration.zero;
    _vibrationRms = 0;
    _tier = 0;
    _reason = ImpactReason.none;
    _postSpike.clear();
    _candidates.clear();
    lastCrashSignal = null;
  }
}
