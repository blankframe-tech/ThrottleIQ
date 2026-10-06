import '../../../../core/database/database_helper.dart';
import '../../domain/calculators/riding_conditions.dart';

/// Reads how a bike has been ridden lately, for the forecast's riding pace
/// and condition adjustments. Riverpod-free so the home-screen widget and
/// notifications (which run outside the widget tree) get the same numbers
/// as the page.
class MaintenanceUsageRepository {
  /// Days of riding the projected pace is averaged over.
  static const paceWindowDays = 30;

  /// Days of ride telemetry the condition factors are taken from.
  static const telemetryWindowDays = 60;

  /// Below this much riding in the pace window there's nothing to project
  /// from, and dates come only from time intervals.
  static const minPaceKm = 5.0;

  Future<UsageStats> usageFor(String bikeId, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final db = await DatabaseHelper.instance.database;

    final paceFrom = at.subtract(const Duration(days: paceWindowDays));
    final teleFrom = at.subtract(const Duration(days: telemetryWindowDays));

    final tele = (await db.rawQuery('''
      SELECT COALESCE(SUM(distance_m), 0) AS d,
             COALESCE(SUM(moving_s), 0) AS m,
             COALESCE(SUM(duration_s), 0) AS t,
             COALESCE(SUM(hard_brake_count), 0) AS b
      FROM rides
      WHERE bike_id = ? AND status = 'completed' AND start_time >= ?
    ''', [bikeId, teleFrom.toIso8601String()])).first;

    final paceKm = await distanceKmSince(bikeId, paceFrom);

    final bike = (await db.query('bikes',
            columns: ['created_at'],
            where: 'id = ?',
            whereArgs: [bikeId],
            limit: 1))
        .firstOrNull;
    final created = DateTime.tryParse(bike?['created_at'] as String? ?? '');
    // A bike added last week has a week of riding, not a month: dividing by
    // 30 would make a daily commuter look like a weekend rider.
    var days = paceWindowDays.toDouble();
    if (created != null && created.isAfter(paceFrom)) {
      days = at.difference(created).inHours / 24;
      if (days < 7) days = 7;
    }

    return UsageStats(
      avgDailyKm: paceKm >= minPaceKm ? paceKm / days : null,
      rideDistanceKm: ((tele['d'] as num?) ?? 0) / 1000,
      movingSeconds: ((tele['m'] as num?) ?? 0).toInt(),
      durationSeconds: ((tele['t'] as num?) ?? 0).toInt(),
      hardBrakes: ((tele['b'] as num?) ?? 0).toInt(),
    );
  }

  /// Km on [bikeId] since [from]: completed rides plus credited detected
  /// trips (§93.1).
  Future<double> distanceKmSince(String bikeId, DateTime from) async {
    final db = await DatabaseHelper.instance.database;
    final rides = (await db.rawQuery('''
      SELECT COALESCE(SUM(distance_m), 0) AS d FROM rides
      WHERE bike_id = ? AND status = 'completed' AND start_time >= ?
    ''', [bikeId, from.toIso8601String()])).first['d'] as num? ?? 0;
    final credits = (await db.rawQuery('''
      SELECT COALESCE(SUM(distance_m), 0) AS d FROM detection_odometer_credits
      WHERE bike_id = ? AND credited_at >= ?
    ''', [bikeId, from.toIso8601String()])).first['d'] as num? ?? 0;
    return (rides + credits) / 1000;
  }
}
