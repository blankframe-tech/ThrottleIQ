import '../../../../core/constants/sensor_constants.dart';

/// Single source of truth for "is this raw sample trustworthy enough to use"
/// — replaces the inline `pos.accuracy > 25` magic number that used to live
/// directly in `ride_recording_provider.dart`. Pure Dart, no platform
/// dependencies, so it's unit-testable the same way as [MotionCalculator]/
/// [EventDetector].
///
/// The plausibility ceilings here are deliberately far above legitimate
/// high-g events (event_detector.dart's crash threshold is 80 m/s²) — this
/// catches sensor glitches/NaN/clipping, not real crashes.
class SensorValidator {
  bool isValidGpsFix({required double accuracyM}) =>
      accuracyM.isFinite && accuracyM <= SensorConstants.maxGpsAccuracyM;

  bool isPlausibleAccel(double accelMs2) =>
      accelMs2.isFinite && accelMs2.abs() <= SensorConstants.maxPlausibleAccelMs2;

  bool isPlausibleYawRate(double yawRateRadS) =>
      yawRateRadS.isFinite &&
      yawRateRadS.abs() <= SensorConstants.maxPlausibleYawRateRadS;

  bool isFreshTimestamp(DateTime timestamp, DateTime? previous) =>
      previous == null || timestamp.isAfter(previous);
}
