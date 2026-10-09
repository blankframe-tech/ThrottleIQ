import 'dart:math' as math;

/// Standard gravity, m/s².
const double kStandardGravity = 9.80665;

/// One live cornering/g estimate, from the most recent GPS fixes.
class CorneringReading {
  /// Lean angle in degrees: positive leaning right, negative leaning left.
  final double leanDeg;

  /// Lateral acceleration in g: positive towards the right of travel.
  final double lateralG;

  /// Longitudinal acceleration in g: positive speeding up, negative braking.
  /// Null when this fix produced no sustained longitudinal reading.
  final double? longitudinalG;

  const CorneringReading({
    required this.leanDeg,
    required this.lateralG,
    this.longitudinalG,
  });

  @override
  String toString() =>
      'CorneringReading(lean $leanDeg°, lat ${lateralG}g, lon ${longitudinalG}g)';
}

/// A ride's per-ride maxima. A field is null when the estimator never had a
/// usable stretch for it (the ride never got above [CorneringEstimator.minSpeedMs]
/// for long enough) — "unknown", not "zero".
class CorneringPeaks {
  final double? maxLeanDeg;
  final double? maxLeanLeftDeg;
  final double? maxLeanRightDeg;
  final double? peakLateralG;
  final double? peakAccelG;
  final double? peakBrakeG;

  const CorneringPeaks({
    this.maxLeanDeg,
    this.maxLeanLeftDeg,
    this.maxLeanRightDeg,
    this.peakLateralG,
    this.peakAccelG,
    this.peakBrakeG,
  });
}

/// Lean angle and g-force estimated from GPS kinematics alone.
///
/// Mount-independent by design: the phone can sit in a pocket, a tank bag
/// or a handlebar clamp at any angle, so nothing here reads the IMU.
///
/// * Lateral: a motorcycle in a steady turn has centripetal acceleration
///   `a_lat = v·ω`, where ω is the heading (course-over-ground) rate. For a
///   balanced turn the bike leans so gravity and that acceleration resolve
///   through the contact patch: `lean = atan(a_lat / g)`.
/// * Longitudinal: the derivative of GPS (Doppler) speed.
///
/// Both use a central difference across two fix intervals (fix i-2 → i,
/// speed taken at fix i-1), which halves the per-fix heading/speed noise
/// compared with a one-step difference.
///
/// Outlier rejection, in order:
/// 1. Gaps longer than [maxGapSeconds] (a pause, a tunnel) restart the
///    history rather than differencing across them.
/// 2. Lateral needs every fix in the span at or above [minSpeedMs] — GPS
///    course is meaningless at walking pace, and a U-turn in a car park
///    isn't cornering. Longitudinal needs the faster end of the span above
///    it, so a hard stop from speed still counts.
/// 3. Raw values beyond [glitchG] are discarded as GPS glitches (a course
///    flip, a speed spike) instead of being clamped into a fake peak.
/// 4. A value only counts once it is *sustained*: the last
///    [lateralSustainSamples] (or [longitudinalSustainSamples]) raw values
///    must agree in sign, and the reading is the smallest of them. One bad
///    fix can't make a peak.
/// 5. The result is clamped to physical limits: |g| ≤ [maxG], lean ≤
///    [maxLeanDeg].
///
/// Pure and clock-free: feed it fixes, read [peaks].
class CorneringEstimator {
  /// Below ~15 km/h, course-over-ground is too noisy to difference.
  static const double minSpeedMs = 15 / 3.6;

  /// A longer gap between fixes restarts the history.
  static const double maxGapSeconds = 3.0;

  static const int lateralSustainSamples = 3;
  static const int longitudinalSustainSamples = 2;

  /// Physical clamps. Road tyres on a road bike top out well below both.
  static const double maxLeanDeg = 60.0;
  static const double maxG = 1.5;

  /// Raw values beyond this are glitches, not riding.
  static const double glitchG = 2.0;

  final List<_Fix> _fixes = [];
  final List<double> _lateral = [];
  final List<double> _longitudinal = [];

  double? _maxLeanLeft;
  double? _maxLeanRight;
  double? _peakLateralG;
  double? _peakAccelG;
  double? _peakBrakeG;

  /// The per-ride maxima so far.
  CorneringPeaks get peaks {
    final left = _maxLeanLeft;
    final right = _maxLeanRight;
    final double? maxLean = left == null && right == null
        ? null
        : math.max(left ?? 0.0, right ?? 0.0);
    return CorneringPeaks(
      maxLeanDeg: maxLean,
      maxLeanLeftDeg: left,
      maxLeanRightDeg: right,
      peakLateralG: _peakLateralG,
      peakAccelG: _peakAccelG,
      peakBrakeG: _peakBrakeG,
    );
  }

  /// Forgets everything, peaks included — a new ride.
  void reset() {
    restartHistory();
    _maxLeanLeft = null;
    _maxLeanRight = null;
    _peakLateralG = null;
    _peakAccelG = null;
    _peakBrakeG = null;
  }

  /// Drops the fix history but keeps the peaks — a pause/resume, where the
  /// next fix must not be differenced against the one before the pause.
  void restartHistory() {
    _fixes.clear();
    _lateral.clear();
    _longitudinal.clear();
  }

  /// Adds one GPS fix. [headingDeg] is the receiver's course over ground
  /// (0–360, clockwise from north); pass null when the fix has none.
  ///
  /// Returns the current sustained reading, or null while there isn't one
  /// (too few fixes, too slow, unsettled).
  CorneringReading? addFix({
    required DateTime time,
    required double speedMs,
    double? headingDeg,
  }) {
    if (!speedMs.isFinite || speedMs < 0) return null;
    if (_fixes.isNotEmpty) {
      final dt = _seconds(_fixes.last.time, time);
      if (dt <= 0) return null; // duplicate or out-of-order fix
      if (dt > maxGapSeconds) restartHistory();
    }
    final heading = (headingDeg != null &&
            headingDeg.isFinite &&
            headingDeg >= 0 &&
            headingDeg <= 360)
        ? headingDeg
        : null;
    _fixes.add(_Fix(time, speedMs, heading));
    if (_fixes.length > 3) _fixes.removeAt(0);
    if (_fixes.length < 3) return null;

    final f0 = _fixes[0];
    final f1 = _fixes[1];
    final f2 = _fixes[2];
    final span = _seconds(f0.time, f2.time);

    // ── Longitudinal ──
    double? longitudinalG;
    if (math.max(f0.speedMs, f2.speedMs) >= minSpeedMs) {
      final aLon = (f2.speedMs - f0.speedMs) / span;
      if (aLon.abs() > glitchG * kStandardGravity) {
        _longitudinal.clear();
      } else {
        _push(_longitudinal, aLon, longitudinalSustainSamples);
        final sustained = _sustained(_longitudinal, longitudinalSustainSamples);
        if (sustained != null) {
          longitudinalG = (sustained / kStandardGravity).clamp(-maxG, maxG);
          if (longitudinalG > 0) {
            _peakAccelG = math.max(_peakAccelG ?? 0, longitudinalG);
          } else {
            _peakBrakeG = math.max(_peakBrakeG ?? 0, -longitudinalG);
          }
        }
      }
    } else {
      _longitudinal.clear();
    }

    // ── Lateral ──
    final h0 = f0.headingDeg;
    final h2 = f2.headingDeg;
    final fastEnough = f0.speedMs >= minSpeedMs &&
        f1.speedMs >= minSpeedMs &&
        f2.speedMs >= minSpeedMs;
    if (h0 == null || h2 == null || !fastEnough) {
      _lateral.clear();
      return null;
    }
    final omegaRadS = _wrapDeg(h2 - h0) * math.pi / 180 / span;
    final aLat = f1.speedMs * omegaRadS;
    if (aLat.abs() > glitchG * kStandardGravity) {
      _lateral.clear();
      return null;
    }
    _push(_lateral, aLat, lateralSustainSamples);
    final sustained = _sustained(_lateral, lateralSustainSamples);
    if (sustained == null) return null;

    final lateralG = (sustained / kStandardGravity).clamp(-maxG, maxG);
    final leanMag = math
        .min(math.atan(lateralG.abs()) * 180 / math.pi, maxLeanDeg)
        .toDouble();
    if (lateralG >= 0) {
      _maxLeanRight = math.max(_maxLeanRight ?? 0, leanMag);
    } else {
      _maxLeanLeft = math.max(_maxLeanLeft ?? 0, leanMag);
    }
    // A sustained straight still records "0°" on both sides, so a ride that
    // rode at speed reads as measured-and-upright rather than unknown.
    _maxLeanLeft ??= 0;
    _maxLeanRight ??= 0;
    _peakLateralG = math.max(_peakLateralG ?? 0, lateralG.abs());

    return CorneringReading(
      leanDeg: lateralG >= 0 ? leanMag : -leanMag,
      lateralG: lateralG,
      longitudinalG: longitudinalG,
    );
  }

  static double _seconds(DateTime a, DateTime b) =>
      b.difference(a).inMicroseconds / 1e6;

  /// [d] wrapped into (-180, 180].
  static double _wrapDeg(double d) {
    var x = d % 360;
    if (x > 180) x -= 360;
    if (x <= -180) x += 360;
    return x;
  }

  static void _push(List<double> window, double v, int size) {
    window.add(v);
    if (window.length > size) window.removeAt(0);
  }

  /// The smallest-magnitude value of a full window whose values all share a
  /// sign, else 0 when the full window disagrees, else null (not yet full).
  static double? _sustained(List<double> window, int size) {
    if (window.length < size) return null;
    final allPositive = window.every((v) => v > 0);
    final allNegative = window.every((v) => v < 0);
    if (!allPositive && !allNegative) return 0;
    final minAbs = window.map((v) => v.abs()).reduce(math.min);
    return allPositive ? minAbs : -minAbs;
  }
}

class _Fix {
  final DateTime time;
  final double speedMs;
  final double? headingDeg;

  const _Fix(this.time, this.speedMs, this.headingDeg);
}
