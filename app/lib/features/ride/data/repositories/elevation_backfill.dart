import 'package:flutter/foundation.dart';

import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/calculators/elevation_profile.dart';

/// Fills `elevation_gain_m` / `elevation_loss_m` (schema v26) on rides
/// finalized before those columns existed, from their stored points.
///
/// Lazy and cheap by construction:
/// * at most one pass per app start ([runOncePerStart]);
/// * only finished rides with NULL elevation that still have at least one
///   stored altitude sample are selected, so rides without points (pulled
///   down from the cloud, purged, or recorded on a device without altitude)
///   are never even read and simply stay NULL;
/// * rides are processed in batches of [batchSize], with a [pause] between
///   batches, so the pass never holds the database or the event loop for
///   long — it runs off the UI path via `unawaited` at startup.
///
/// A ride whose altitude data is too sparse to trust also stays NULL (see
/// [rideElevationGainLoss]) and is looked at again on the next start; that's
/// one indexed query per such ride, which is the price of never writing a
/// made-up number.
class ElevationBackfill {
  ElevationBackfill({
    RidePointDao? pointDao,
    this.batchSize = 10,
    this.pause = const Duration(milliseconds: 200),
  }) : _pointDao = pointDao ?? RidePointDao();

  final RidePointDao _pointDao;
  final int batchSize;
  final Duration pause;

  static bool _ranThisStart = false;

  /// Runs [run] the first time it's called in this process; later calls
  /// return 0 without touching the database.
  static Future<int> runOncePerStart({ElevationBackfill? backfill}) async {
    if (_ranThisStart) return 0;
    _ranThisStart = true;
    try {
      return await (backfill ?? ElevationBackfill()).run();
    } catch (e, s) {
      debugPrint('[ElevationBackfill] failed: $e\n$s');
      return 0;
    }
  }

  @visibleForTesting
  static void resetForTesting() => _ranThisStart = false;

  /// One full pass. Returns how many rides gained an elevation figure.
  Future<int> run() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT r.id FROM rides r
      WHERE r.elevation_gain_m IS NULL
        AND r.status IN ('completed', 'crash')
        AND EXISTS (SELECT 1 FROM ride_points p
                    WHERE p.ride_id = r.id AND p.altitude_m IS NOT NULL)
      ORDER BY r.start_time DESC
    ''');
    final ids = [for (final r in rows) r['id'] as String];

    var filled = 0;
    for (var i = 0; i < ids.length; i += batchSize) {
      if (i > 0 && pause > Duration.zero) await Future<void>.delayed(pause);
      final batch = ids.skip(i).take(batchSize);
      for (final id in batch) {
        final elevation =
            rideElevationGainLoss(await _pointDao.getAltitudesForRide(id));
        if (elevation == null) continue;
        // `synced = 0` so the figure reaches the cloud copy too. Guarded on
        // NULL so a ride finalized meanwhile keeps its own value.
        filled += await db.update(
          'rides',
          {
            'elevation_gain_m': elevation.gainM,
            'elevation_loss_m': elevation.lossM,
            'synced': 0,
          },
          where: 'id = ? AND elevation_gain_m IS NULL',
          whereArgs: [id],
        );
      }
    }
    return filled;
  }
}
