/// Riding behaviour: the riding score and the harsh-event counters.
library;

import '../../../../core/utils/riding_score.dart';
import '../../../ride/domain/entities/ride_entity.dart';
import '../ride_analytics.dart';

abstract final class RidingBehaviourCharts {
  static const ridingScore = PerRideChart(
    'ridingScore',
    value: _score,
    aggregation: Aggregation.mean,
  );
  static const hardBraking = PerRideChart(
    'hardBraking',
    value: _brakes,
    shapeInsight: _cleanRides,
  );
  static const rapidAccel = PerRideChart(
    'rapidAccel',
    value: _accel,
    shapeInsight: _cleanRides,
  );
  static const overspeed = PerRideChart(
    'overspeed',
    value: _overspeed,
    shapeInsight: _cleanRides,
  );

  static const List<AnalyticsChart> all = [
    ridingScore,
    hardBraking,
    rapidAccel,
    overspeed,
  ];
}

/// Rides with no events ([AnalyticsInsight.value]) out of
/// [AnalyticsInsight.value2].
const cleanRidesInsight = InsightKind('cleanRides');

int rideScore(RideEntity r) => computeRidingScore(
      hardBrakes: r.hardBrakeCount,
      rapidAccel: r.rapidAccelCount,
      highJerk: r.highJerkCount,
    );

double? _score(RideEntity r) => rideScore(r).toDouble();
double? _brakes(RideEntity r) => r.hardBrakeCount.toDouble();
double? _accel(RideEntity r) => r.rapidAccelCount.toDouble();

/// Null on rides recorded before it was counted (schema v25).
double? _overspeed(RideEntity r) => r.overspeedCount?.toDouble();

List<AnalyticsInsight> _cleanRides(
  List<RideEntity> rides,
  List<AnalyticsPoint> series,
) {
  final clean = series.where((p) => p.value == 0).length;
  return [
    AnalyticsInsight(
      cleanRidesInsight,
      value: clean.toDouble(),
      value2: series.length.toDouble(),
    ),
  ];
}
