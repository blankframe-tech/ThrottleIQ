/// Every chart on the Rides tab's analytics list, in display order.
///
/// A new chart family is one file under `charts/` plus one line here (and
/// its twin in `presentation/analytics_chart_registry.dart`). Nothing else
/// in the shared analytics code names a chart.
library;

import 'charts/activity_pattern_charts.dart';
import 'charts/bike_charts.dart';
import 'charts/cornering_elevation_charts.dart';
import 'charts/fuel_charts.dart';
import 'charts/ride_basics_charts.dart';
import 'charts/riding_behaviour_charts.dart';
import 'charts/time_charts.dart';
import 'ride_analytics.dart';

const List<AnalyticsChart> analyticsCharts = [
  ...RideBasicsCharts.all,
  ...TimeCharts.all,
  ...RidingBehaviourCharts.all,
  ...CorneringElevationCharts.all,
  ...ActivityPatternCharts.all,
  ...BikeCharts.all,
  ...FuelCharts.all,
];
