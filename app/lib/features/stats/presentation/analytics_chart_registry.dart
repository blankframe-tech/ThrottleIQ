/// How every analytics chart looks and reads, in display order — the
/// presentation twin of `domain/analytics_chart_registry.dart`.
///
/// A new chart family is one file under `charts/` plus one line here.
/// `test/features/stats/chart_registry_structure_test.dart` checks both
/// registries list the same charts in the same order.
library;

import '../domain/ride_analytics.dart';
import 'analytics_chart_l10n.dart';
import 'charts/activity_pattern_presentation.dart';
import 'charts/bike_presentation.dart';
import 'charts/cornering_elevation_presentation.dart';
import 'charts/fuel_presentation.dart';
import 'charts/ride_basics_presentation.dart';
import 'charts/riding_behaviour_presentation.dart';
import 'charts/time_presentation.dart';

final List<ChartPresentation> analyticsChartPresentations = [
  ...rideBasicsPresentations,
  ...timePresentations,
  ...ridingBehaviourPresentations,
  ...corneringElevationPresentations,
  ...activityPatternPresentations,
  ...bikePresentations,
  ...fuelPresentations,
];

final Map<String, ChartPresentation> _byId = {
  for (final p in analyticsChartPresentations) p.chart.id: p,
};

/// The presentation registered for [chart].
ChartPresentation chartPresentationOf(AnalyticsChart chart) =>
    _byId[chart.id] ??
    (throw StateError('No ChartPresentation registered for ${chart.id}'));
