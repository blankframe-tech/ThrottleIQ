/// Cornering and elevation (schema v26): max lean, peak g and climb.
///
/// All three are null on rides recorded before v26 (elevation: unless
/// backfilled), and those rides are skipped.
library;

import '../../../ride/domain/entities/ride_entity.dart';
import '../ride_analytics.dart';

abstract final class CorneringElevationCharts {
  static const maxLean = PerRideChart(
    'maxLean',
    value: _lean,
    aggregation: Aggregation.mean,
    shapeInsight: _peakLean,
  );

  /// value = lateral; the longitudinal peaks ride along for the table.
  static const peakG = PerRideChart(
    'peakG',
    value: _lateralG,
    secondary: _accelG,
    tertiary: _brakeG,
    aggregation: Aggregation.mean,
  );
  static const elevationGain = PerRideChart(
    'elevationGain',
    value: _gain,
    secondary: _loss,
    shapeInsight: _totalClimb,
  );

  static const List<AnalyticsChart> all = [maxLean, peakG, elevationGain];
}

/// The deepest lean ([AnalyticsInsight.value]) and its ride's date.
/// Worded as an estimate — see CorneringEstimator.
const peakLeanInsight = InsightKind('peakLean');

/// Total climb ([AnalyticsInsight.value]) over [AnalyticsInsight.value2]
/// rides.
const totalClimbInsight = InsightKind('totalClimb');

double? _lean(RideEntity r) => r.maxLeanDeg;
double? _lateralG(RideEntity r) => r.peakLateralG;
double? _accelG(RideEntity r) => r.peakAccelG;
double? _brakeG(RideEntity r) => r.peakBrakeG;
double? _gain(RideEntity r) => r.elevationGainM;
double? _loss(RideEntity r) => r.elevationLossM;

List<AnalyticsInsight> _peakLean(
  List<RideEntity> rides,
  List<AnalyticsPoint> series,
) {
  final peak = series.reduce((a, b) => b.value > a.value ? b : a);
  return [
    AnalyticsInsight(peakLeanInsight, value: peak.value, date: peak.date),
  ];
}

List<AnalyticsInsight> _totalClimb(
  List<RideEntity> rides,
  List<AnalyticsPoint> series,
) {
  final total = series.fold<double>(0, (s, p) => s + p.value);
  return [
    AnalyticsInsight(
      totalClimbInsight,
      value: total,
      value2: series.length.toDouble(),
    ),
  ];
}
