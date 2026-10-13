import '../../../../core/database/daos/maintenance_config_dao.dart';
import '../../../../core/database/daos/maintenance_dao.dart';
import '../../../../core/database/daos/maintenance_profile_dao.dart';
import '../../../../core/database/database_helper.dart';
import '../../../garage/domain/entities/bike_entity.dart';
import '../../domain/calculators/maintenance_forecast.dart';
import '../../domain/calculators/riding_conditions.dart';
import '../../domain/catalog/schedule_templates.dart';
import '../../domain/entities/maintenance_entity.dart';
import '../../domain/entities/maintenance_profile.dart';
import '../models/maintenance_config_model.dart';
import '../models/maintenance_model.dart';
import 'maintenance_usage_repository.dart';

/// Everything the forecast needs about one bike, loaded together.
class BikeMaintenanceData {
  final BikeEntity bike;
  final List<MaintenanceConfigEntity> configs;
  final List<MaintenanceEntity> logs;
  final MaintenanceProfileEntity? profile;
  final UsageStats usage;
  final double creditedKm;

  const BikeMaintenanceData({
    required this.bike,
    required this.configs,
    required this.logs,
    required this.profile,
    required this.usage,
    required this.creditedKm,
  });
}

/// The forecast input for [bike], the same for the page, the widget and
/// notifications.
ForecastInput buildForecastInput({
  required BikeEntity bike,
  required MaintenanceProfileEntity? profile,
  required UsageStats usage,
  required double creditedKm,
  required DateTime now,
}) {
  return ForecastInput(
    currentOdometerKm: bike.currentOdometerKm,
    now: now,
    avgDailyKm: usage.avgDailyKm,
    conditions: deriveConditions(
      usage: usage,
      profile: profile?.ridingProfile ?? RidingProfile.normal,
    ),
    adapt: profile?.adaptIntervals ?? true,
    fallbackBaseline: newBikeBaseline(
      baselineOdometerKm: bike.odometerKm,
      creditedKm: creditedKm,
      addedAt: bike.createdAt,
    ),
  );
}

/// The checks a bike tracks before the rider has customised anything: its
/// setup template's, or the one suggested for its model.
List<MaintenanceConfigEntity> defaultConfigsFor(
  BikeEntity bike,
  MaintenanceProfileEntity? profile,
) {
  final template = profile != null
      ? profile.template
      : suggestTemplate(brand: bike.brand, model: bike.model, cc: bike.cc);
  return configsFromTemplate(
    bikeId: bike.id,
    template: template,
    oilGrade: profile?.oilGrade,
  );
}

/// Riverpod-free loader for code outside the widget tree (home-screen
/// widget, notifications).
class MaintenanceForecastRepository {
  final _configDao = MaintenanceConfigDao();
  final _logDao = MaintenanceDao();
  final _profileDao = MaintenanceProfileDao();
  final _usage = MaintenanceUsageRepository();

  Future<BikeMaintenanceData> load(BikeEntity bike, {DateTime? now}) async {
    final configRows = await _configDao.getConfigsForBike(bike.id);
    final profileRow = await _profileDao.getProfile(bike.id);
    final profile = profileRow == null
        ? null
        : MaintenanceProfileEntity.fromMap(profileRow);
    final configs = configRows.isEmpty
        ? defaultConfigsFor(bike, profile)
        : configRows.map(MaintenanceConfigModel.fromMap).toList();
    final logs = (await _logDao.getForBike(bike.id))
        .map(MaintenanceModel.fromMap)
        .toList();
    return BikeMaintenanceData(
      bike: bike,
      configs: configs,
      logs: logs,
      profile: profile,
      usage: await _usage.usageFor(bike.id, now: now),
      creditedKm: await creditedKmFor(bike.id),
    );
  }

  Future<List<CheckForecast>> forecastFor(BikeEntity bike,
      {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final d = await load(bike, now: at);
    return forecastChecks(
      configs: d.configs,
      logs: d.logs,
      input: buildForecastInput(
        bike: bike,
        profile: d.profile,
        usage: d.usage,
        creditedKm: d.creditedKm,
        now: at,
      ),
    );
  }

  /// Total km credited to [bikeId] from detected trips.
  static Future<double> creditedKmFor(String bikeId) async {
    final db = await DatabaseHelper.instance.database;
    final row = (await db.rawQuery(
      'SELECT COALESCE(SUM(distance_m), 0) AS d '
      'FROM detection_odometer_credits WHERE bike_id = ?',
      [bikeId],
    ))
        .first;
    return ((row['d'] as num?) ?? 0) / 1000;
  }
}
