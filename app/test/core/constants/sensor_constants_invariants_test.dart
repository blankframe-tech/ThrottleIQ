import 'package:flutter_test/flutter_test.dart';
import 'package:throttleiq/core/constants/sensor_constants.dart';

/// The threshold invariants from the throttleiq-qa skill (Step 5), plus the
/// ones the tiered ImpactDetector relies on. Checked by hand until now.
void main() {
  test('braking is negative, acceleration positive', () {
    expect(SensorConstants.hardBrakingThreshold, lessThan(0));
    expect(SensorConstants.rapidAccelThreshold, greaterThan(0));
  });

  test('a crash is far beyond a hard brake', () {
    expect(SensorConstants.hardBrakingThreshold.abs(),
        lessThan(SensorConstants.crashAccelThreshold / 9.81));
  });

  test('overspeed and fatigue are sane', () {
    expect(SensorConstants.overspeedThreshold, greaterThan(0));
    expect(SensorConstants.fatigueAlertSeconds, greaterThanOrEqualTo(3600));
  });

  test('the crash gate is stricter than the thinning gate', () {
    expect(SensorConstants.minConfidenceForCrashAlert,
        lessThan(SensorConstants.minConfidenceToThinRecording));
  });

  test('impact tiers: clipping floor < ask bar < alarm bar < plausible', () {
    expect(SensorConstants.impactSaturationFloorMs2,
        lessThan(SensorConstants.impactAskThreshold));
    expect(SensorConstants.impactAskThreshold,
        lessThan(SensorConstants.impactThreshold));
    expect(SensorConstants.impactThreshold,
        lessThan(SensorConstants.maxPlausibleAccelMs2));
  });

  test('shadow mode is on and the live alarm is off', () {
    // Flip crashAlertsEnabled only with the plan's targets met
    // (DOCS/General/CRASH TESTING, section 10) and a delivery path decided.
    expect(SensorConstants.impactShadowEnabled, isTrue);
    expect(SensorConstants.crashAlertsEnabled, isFalse);
  });

  test('IMU sampling is at least 50 Hz', () {
    expect(SensorConstants.imuSamplingPeriod.inMilliseconds,
        lessThanOrEqualTo(20));
  });
}
