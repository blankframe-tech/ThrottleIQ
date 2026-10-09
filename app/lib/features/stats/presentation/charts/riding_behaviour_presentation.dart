import 'package:flutter/material.dart';

import '../../domain/charts/riding_behaviour_charts.dart';
import '../../domain/ride_analytics.dart';
import '../analytics_chart_l10n.dart';

/// Riding behaviour: the riding score and the harsh-event counters.
final List<ChartPresentation> ridingBehaviourPresentations = [
  ChartPresentation(
    chart: RidingBehaviourCharts.ridingScore,
    title: (l) => l.chartRidingScore,
    unit: (_) => '',
    icon: Icons.verified_outlined,
    color: (p) => p.success,
    shape: ChartShape.line,
    higherIsBetter: true,
  ),
  ChartPresentation(
    chart: RidingBehaviourCharts.hardBraking,
    title: (l) => l.chartHardBraking,
    unit: (l) => l.analyticsUnitEvents,
    icon: Icons.warning_amber_outlined,
    color: (p) => p.danger,
    shape: ChartShape.bars,
    higherIsBetter: false,
    wordInsight: _word,
  ),
  ChartPresentation(
    chart: RidingBehaviourCharts.rapidAccel,
    title: (l) => l.chartRapidAccel,
    unit: (l) => l.analyticsUnitEvents,
    icon: Icons.trending_up,
    color: (p) => p.attention,
    shape: ChartShape.bars,
    higherIsBetter: false,
    wordInsight: _word,
  ),
  ChartPresentation(
    chart: RidingBehaviourCharts.overspeed,
    title: (l) => l.chartOverspeed,
    unit: (l) => l.analyticsUnitEvents,
    icon: Icons.speed,
    color: (p) => p.danger,
    shape: ChartShape.bars,
    higherIsBetter: false,
    wordInsight: _word,
  ),
];

String? _word(InsightWording w, AnalyticsInsight i) => i.kind ==
        cleanRidesInsight
    ? w.l10n.insightCleanRides((i.value ?? 0).round(), (i.value2 ?? 0).round())
    : null;
