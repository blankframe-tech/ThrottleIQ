import 'dart:math';

/// Signed longitudinal acceleration from a raw 3-axis accelerometer sample,
/// using whichever axis currently has the largest magnitude as a stand-in
/// for "forward".
///
/// This is the heuristic [AccelAxisCalibrator] exists to move away from. It
/// works passably when the phone happens to be mounted flush with one axis
/// pointing along the direction of travel, but two things break it: a mount
/// that's rotated or tilted (diagonal to every axis, so no single raw axis
/// is "forward"), and any single sample where cornering or a bump makes a
/// *different* axis briefly the largest one — which flips which axis this
/// picks, sample to sample, even though the phone hasn't moved.
///
/// Kept as the calibrator's fallback rather than deleted: early in a ride,
/// before enough GPS-paired samples have accumulated to fit a real axis (see
/// [AccelAxisCalibrator.isCalibrated]), this is what the app used to do
/// unconditionally, so falling back to it costs nothing new.
double dominantAxisSignedMagnitude(double ax, double ay, double az) {
  final magnitude = sqrt(ax * ax + ay * ay + az * az);
  final absValues = [ax.abs(), ay.abs(), az.abs()];
  final dominantIdx = absValues.indexOf(absValues.reduce(max));
  final signed = [ax, ay, az][dominantIdx];
  return signed < 0 ? -magnitude : magnitude;
}

/// Learns which direction "forward" actually is in the accelerometer's own
/// coordinate frame, by fitting raw accelerometer samples against the
/// GPS-derived acceleration for the same stretch of riding — instead of
/// assuming it's whichever single axis happens to read largest right now
/// (see [dominantAxisSignedMagnitude]).
///
/// **The fusion, concretely:** `MotionCalculator` already derives a signed
/// longitudinal acceleration from consecutive GPS speed samples — noisier
/// and lower-rate than the accelerometer (one value per GPS fix, not per
/// ~50ms sample), but unambiguously *correctly signed and directed*, because
/// it comes from the bike's actual track over ground rather than from a
/// sensor whose mounting angle is unknown. Treating that as ground truth,
/// this fits a 3D vector `axis` — the accelerometer reading of "one unit of
/// forward" — that minimizes `(rawAccel · axis − gpsAccel)²` across the
/// samples seen so far. Once fit, `axis` is normalized to unit length and
/// every future raw sample is projected onto it (`rawAccel · axis`), which
/// is a true directional projection rather than an undirected magnitude, so
/// it no longer overstates longitudinal acceleration when part of a sample
/// is actually lateral (cornering) or vertical (a bump).
///
/// **Fitting is a standard linear least-squares problem** solved via its
/// normal equations, `(Σ raw rawᵀ) · axis = Σ raw · gpsAccel` — a 3×3 linear
/// system accumulated incrementally (O(1) memory per sample, no stored
/// history) and solved on demand by Cramer's rule. No sign ambiguity: the
/// fit target is the *signed* GPS acceleration, not its magnitude, so the
/// solved axis already points the right way — there's no separate "which
/// way is forward" step to get wrong.
///
/// **What "enough samples" means** ([isCalibrated]): the normal-equations
/// matrix is only invertible once the accelerometer has seen a genuinely
/// 3-dimensional spread of directions (straight-line riding alone under-
/// determines the fit — braking/accelerating varies one axis, but cornering
/// or a bump is what pins down the other two). [_minDeterminant] guards
/// against solving a near-singular system, which would otherwise return an
/// arbitrary, noise-dominated axis instead of declining to answer. **Its
/// exact value is a starting point, not a tuned constant** — like the
/// hard-brake/rapid-accel thresholds it feeds, getting it right needs real
/// ride logs to check the fitted axis against, which wasn't available here
/// (see `HANDOFF_Document.md`).
///
/// One instance per ride — see [reset] and `RideRecordingNotifier`'s other
/// per-ride calculators (`_detector`, `_estimator`, `_cadencePolicy`), which
/// this follows the same lifecycle as.
class AccelAxisCalibrator {
  /// Below this many paired samples, the fit is too thin to trust even if
  /// the matrix happens to invert cleanly — an early, lucky-looking fit from
  /// a handful of samples is exactly the noise-dominated case the sample
  /// count (as opposed to only the determinant) is here to catch.
  static const int _minSamples = 20;

  /// Determinant floor, relative to the accumulated matrix's own scale
  /// (`trace³`, so it stays meaningful whether accelerometer units are near
  /// 1 m/s² or 10 m/s²) rather than an absolute number. Below this, the
  /// seen accelerometer directions are too close to co-planar (or
  /// co-linear) to pin down a unique 3D axis, and solving anyway would fit
  /// noise. See the class doc for why this specific value is unvalidated.
  static const double _minRelativeDeterminant = 1e-6;

  // Row-major 3x3 accumulator for Σ raw·rawᵀ, and Σ raw·gpsAccel — the
  // normal equations' left- and right-hand sides. Never stores the samples
  // themselves.
  final List<double> _m = List.filled(9, 0.0);
  final List<double> _b = List.filled(3, 0.0);
  int _sampleCount = 0;

  /// The most recently solved axis, cached so repeated [project] calls
  /// between new [addSample]s don't re-solve the same system. Invalidated
  /// (set back to null) by every [addSample], since each new sample changes
  /// the fit.
  List<double>? _cachedAxis;

  int get sampleCount => _sampleCount;

  /// One training pair: the accelerometer's average raw reading over an
  /// interval, and the GPS-derived signed acceleration for that same
  /// interval (`MotionCalculator.acceleration`, one value per GPS fix — see
  /// `RideRecordingNotifier._onPosition`, which averages the raw samples
  /// received since the previous fix before calling this).
  void addSample({required double ax, required double ay, required double az, required double gpsAccelMs2}) {
    final raw = [ax, ay, az];
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        _m[i * 3 + j] += raw[i] * raw[j];
      }
      _b[i] += raw[i] * gpsAccelMs2;
    }
    _sampleCount++;
    _cachedAxis = null;
  }

  /// Whether [project] currently has a fitted axis to use — see the class
  /// doc for what "enough" means. Exposed so callers/tests can distinguish
  /// "still on the fallback heuristic" from "fitted, and it happened to
  /// match the fallback".
  bool get isCalibrated => _axis() != null;

  /// Signed longitudinal acceleration for one raw accelerometer sample:
  /// the fitted-axis projection once [isCalibrated], the dominant-axis
  /// [dominantAxisSignedMagnitude] fallback until then.
  double signedLongitudinalAccelMs2(double ax, double ay, double az) {
    final axis = _axis();
    if (axis == null) return dominantAxisSignedMagnitude(ax, ay, az);
    return ax * axis[0] + ay * axis[1] + az * axis[2];
  }

  void reset() {
    for (var i = 0; i < 9; i++) {
      _m[i] = 0.0;
    }
    for (var i = 0; i < 3; i++) {
      _b[i] = 0.0;
    }
    _sampleCount = 0;
    _cachedAxis = null;
  }

  List<double>? _axis() {
    if (_sampleCount < _minSamples) return null;
    if (_cachedAxis != null) return _cachedAxis;

    final m = _m;
    final det = m[0] * (m[4] * m[8] - m[5] * m[7]) -
        m[1] * (m[3] * m[8] - m[5] * m[6]) +
        m[2] * (m[3] * m[7] - m[4] * m[6]);

    final trace = m[0] + m[4] + m[8];
    final scale = trace * trace * trace;
    if (scale == 0 || det.abs() < _minRelativeDeterminant * scale.abs()) {
      return null; // near-singular — see _minRelativeDeterminant's doc comment
    }

    // Cramer's rule: solve M·v = b by replacing one column of M with b at a
    // time and comparing determinants.
    final v = [
      _determinant3(_withColumn(m, 0, _b)) / det,
      _determinant3(_withColumn(m, 1, _b)) / det,
      _determinant3(_withColumn(m, 2, _b)) / det,
    ];

    final magnitude = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (magnitude == 0 || !magnitude.isFinite) return null;

    _cachedAxis = [v[0] / magnitude, v[1] / magnitude, v[2] / magnitude];
    return _cachedAxis;
  }

  static List<double> _withColumn(List<double> m, int col, List<double> replacement) {
    final out = List<double>.from(m);
    for (var row = 0; row < 3; row++) {
      out[row * 3 + col] = replacement[row];
    }
    return out;
  }

  static double _determinant3(List<double> m) {
    return m[0] * (m[4] * m[8] - m[5] * m[7]) -
        m[1] * (m[3] * m[8] - m[5] * m[6]) +
        m[2] * (m[3] * m[7] - m[4] * m[6]);
  }
}
