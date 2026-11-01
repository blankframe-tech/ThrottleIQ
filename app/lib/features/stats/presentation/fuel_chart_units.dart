import 'package:throttleiq/features/maintenance/domain/calculators/fuel_units.dart';
import 'package:throttleiq/features/stats/domain/charts/fuel_charts.dart';
import 'package:throttleiq/features/stats/domain/ride_analytics.dart';
import '../../../l10n/app_localizations.dart';
import 'analytics_chart_l10n.dart';

double convertFuelChartValue(
  AnalyticsChart chart,
  double value,
  bool imperial
) {

  if(!imperial) return value;

  if(chart.id == FuelCharts.fuelEfficiency.id){
    return FuelUnits.kmPerLitreToMpg(value);
  }

  if(chart.id == FuelCharts.fuelCostPerKm.id){
    return FuelUnits.costPerKmToPerMile(value);
  }

  return value;
}


List<AnalyticsPoint> convertFuelChartPoints(
      AnalyticsChart chart,
      List<AnalyticsPoint> points,
      bool imperial
) {
  if(!imperial ||
      (chart.id != FuelCharts.fuelEfficiency.id &&
      chart.id  != FuelCharts.fuelCostPerKm.id)){
    return points;
  }

  return [
    for(final point in points)
      AnalyticsPoint(
        key: point.key,
        date: point.date,
        value: convertFuelChartValue(chart, point.value, imperial),
        secondary: point.secondary == null
            ? null
            : point.secondary!/FuelUnits.kmPerMile,
        tertiary: point.tertiary,
        bucket: point.bucket
      ),
  ];

}

String? fuelChartUnitOverride (
  AnalyticsChart chart,
  AppLocalizations l10n,
  bool imperial
) {
  if(chart.id == FuelCharts.fuelEfficiency.id){
    return imperial ? l10n.unitMpg : l10n.unitKmPerLitre;
  }

  if(chart.id == FuelCharts.fuelCostPerKm.id){
    final distanceUnit = imperial ? l10n.unitDistanceMi : l10n.unitDistanceKm;

    return '$kCurrencySymbol/$distanceUnit';
  }

  return null;
}