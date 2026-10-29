import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/daos/ride_dao.dart';
import '../../../core/database/database_helper.dart';
import '../domain/calculators/auto_ride_reconciler.dart';
import '../domain/calculators/elevation_profile.dart';
import '../domain/entities/ride_entity.dart';
import 'models/ride_model.dart';

/// Largest GPX file accepted. A 3-hour 1 Hz ride from another app is ~1-3 MB.
const kMaxGpxBytes = 10 * 1024 * 1024;

/// Most track points accepted: a full day at 1 Hz, with room to spare.
const kMaxGpxPoints = 100000;

enum GpxImportError { tooLarge, notGpx, noTrack, overlapsRide }

class GpxImportException implements Exception {
  const GpxImportException(this.reason);
  final GpxImportError reason;

  @override
  String toString() => 'GpxImportException(${reason.name})';
}

// `<trkpt ...>body</trkpt>` or `<trkpt .../>`. The body stops at the next
// `<trkpt` so an unclosed tag can't make every match scan to the end of file.
final _trkpt =
    RegExp(r'<trkpt\b([^>]*?)(?:/>|>((?:(?!<trkpt\b)[\s\S])*?)</trkpt>)');

double? _attr(String attrs, String name) {
  final m = RegExp('\\b$name\\s*=\\s*["\']([^"\']*)["\']').firstMatch(attrs);
  return m == null ? null : double.tryParse(m.group(1)!.trim());
}

String? _tag(String body, String name) =>
    RegExp('<$name>([^<]*)</$name>').firstMatch(body)?.group(1)?.trim();

/// The timed track points of a GPX file, oldest first.
///
/// Untrusted input (any file the rider picks): size and point count are
/// capped, and points without a valid time or coordinates are skipped.
/// Throws [GpxImportException] when nothing importable is left.
List<StagedFix> parseGpx(String text) {
  if (text.length > kMaxGpxBytes) {
    throw const GpxImportException(GpxImportError.tooLarge);
  }
  if (!text.contains('<gpx')) {
    throw const GpxImportException(GpxImportError.notGpx);
  }
  final fixes = <StagedFix>[];
  for (final m in _trkpt.allMatches(text)) {
    if (fixes.length >= kMaxGpxPoints) {
      throw const GpxImportException(GpxImportError.tooLarge);
    }
    final attrs = m.group(1)!;
    final body = m.group(2) ?? '';
    final lat = _attr(attrs, 'lat');
    final lng = _attr(attrs, 'lon');
    final time = DateTime.tryParse(_tag(body, 'time') ?? '');
    if (lat == null || lng == null || time == null) continue;
    if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
      continue;
    }
    final ele = double.tryParse(_tag(body, 'ele') ?? '');
    fixes.add((
      // Local, like the timestamps the live recorder stores.
      timestamp: time.toLocal(),
      lat: lat,
      lng: lng,
      // GPX has no speed; the replay derives it from position and time.
      speedMs: 0,
      accuracyM: null,
      altitudeM: ele != null && ele.isFinite ? ele : null,
      headingDeg: null,
    ));
  }
  if (fixes.length < 2) {
    throw const GpxImportException(GpxImportError.noTrack);
  }
  return fixes..sort((a, b) => a.timestamp.compareTo(b.timestamp));
}

/// Saves a GPX track (e.g. history from another app) as a completed ride.
///
/// Stats come from the same replay the auto-detection path uses
/// ([AutoRideReconciler.measure]), so an imported ride reads like a recorded
/// one. Like every completed ride it is credited to the bike's distance and
/// ride count (the UI says so), because deleting a ride or moving it to
/// another bike takes exactly that credit back off (§103.2,
/// `BikeDao.moveRideStats`); an uncredited import would drive the bike
/// short when it is deleted.
class GpxRideImporter {
  GpxRideImporter({RideDao? rideDao}) : _rideDao = rideDao ?? RideDao();

  final RideDao _rideDao;

  /// Returns the saved ride. Throws [GpxImportException] for a file that
  /// can't be imported, including one overlapping a ride already on record
  /// (importing the same file twice, or a ride also recorded here).
  Future<RideEntity> importGpx({
    required String userId,
    required String bikeId,
    required String gpx,
  }) async {
    final fixes = parseGpx(gpx);
    final measured = AutoRideReconciler().measure(fixes);
    if (measured == null || measured.points.isEmpty) {
      throw const GpxImportException(GpxImportError.noTrack);
    }
    final start = fixes.first.timestamp;
    final end = fixes.last.timestamp;

    final now = DateTime.now();
    for (final w in await _rideDao.rideWindows(userId)) {
      if (w.start.isBefore(end) && (w.end ?? now).isAfter(start)) {
        throw const GpxImportException(GpxImportError.overlapsRide);
      }
    }

    final id = const Uuid().v4();
    final elevation = rideElevationGainLoss([
      for (final p in measured.points) (p['altitude_m'] as num?)?.toDouble(),
    ]);
    final ride = RideEntity(
      id: id,
      userId: userId,
      bikeId: bikeId,
      startTime: start,
      endTime: end,
      distanceM: measured.distanceM,
      avgSpeedMs: measured.avgSpeedMs,
      maxSpeedMs: measured.maxSpeedMs,
      durationSeconds: measured.durationSeconds,
      movingSeconds: measured.movingSeconds,
      hardBrakeCount: measured.hardBrakeCount,
      rapidAccelCount: measured.rapidAccelCount,
      highJerkCount: measured.highJerkCount,
      elevationGainM: elevation?.gainM,
      elevationLossM: elevation?.lossM,
      status: RideStatus.completed,
    );

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.insert('rides', RideModel.toMap(ride));
      // What BikeDao.incrementStats does for a recorded ride, minus
      // last_ride_at: an imported ride is usually old history.
      await txn.rawUpdate('''
        UPDATE bikes SET
          total_distance_m = total_distance_m + ?,
          ride_count = ride_count + 1,
          synced = 0
        WHERE id = ?
      ''', [ride.distanceM, bikeId]);
      final batch = txn.batch();
      for (final p in measured.points) {
        batch.insert('ride_points', {...p, 'ride_id': id},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
    return ride;
  }
}
