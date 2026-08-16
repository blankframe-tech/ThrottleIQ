import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Lifecycle states of an `auto_detections` row. See the table's doc comment
/// in `database_helper.dart` for what each one means.
class AutoDetectionStatus {
  static const recording = 'recording';
  static const pending = 'pending';
  static const reconciled = 'reconciled';
  static const discarded = 'discarded';
}

/// What woke the app. Recorded so trigger quality can be measured per source
/// rather than in aggregate — the first release's main open question is which
/// of these actually correlates with a motorcycle ride.
class AutoTriggerSource {
  static const activityRecognition = 'activity_recognition';
  static const significantLocationChange = 'significant_location_change';
  static const pairedDevice = 'paired_device';
  static const manualTest = 'manual_test';
}

/// Reads and writes the auto-tracking staging tables.
///
/// **This DAO is called from two isolates.** The background isolate appends
/// detections and fixes; the UI isolate reconciles them. Both go through
/// `DatabaseHelper`, whose `_db` static is per-isolate, so each ends up with
/// its own connection to the same file — which SQLite handles, but which is
/// why every method here is a single self-contained statement or transaction
/// and why nothing caches row state across calls. Do not add a method that
/// reads, computes in Dart, then writes based on what it read without wrapping
/// the pair in a transaction.
class AutoDetectionDao {
  Future<void> insertDetection({
    required String id,
    required DateTime startedAt,
    required String triggerSource,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'auto_detections',
      {
        'id': id,
        'started_at': startedAt.toIso8601String(),
        'trigger_source': triggerSource,
        'status': AutoDetectionStatus.recording,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Appends one fix to the detection currently recording.
  ///
  /// Deliberately unbatched: the background isolate can be killed between any
  /// two callbacks with no teardown hook, so a fix that isn't on disk when the
  /// callback returns is a fix that never existed. This is the same reasoning
  /// as `_earlyRideFlushUntil` on the live path, applied to the whole journey
  /// rather than just its opening seconds.
  Future<void> appendFix({
    required String detectionId,
    required DateTime timestamp,
    required double lat,
    required double lng,
    required double speedMs,
    double? accuracyM,
    double? altitudeM,
    double? headingDeg,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('auto_fixes', {
      'detection_id': detectionId,
      'timestamp': timestamp.toIso8601String(),
      'lat': lat,
      'lng': lng,
      'speed_ms': speedMs,
      'accuracy_m': accuracyM,
      'altitude_m': altitudeM,
      'heading_deg': headingDeg,
    });
  }

  /// Marks movement as finished, so the next app launch will reconcile it.
  Future<void> closeDetection(String id, DateTime endedAt) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'auto_detections',
      {
        'ended_at': endedAt.toIso8601String(),
        'status': AutoDetectionStatus.pending,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// The detection the background isolate is currently appending to, if any.
  ///
  /// There should be at most one. If a previous process died mid-journey the
  /// row is left in `recording` forever, which is why
  /// [closeStaleRecordingDetections] runs at launch.
  Future<Map<String, dynamic>?> currentRecording() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'auto_detections',
      where: 'status = ?',
      whereArgs: [AutoDetectionStatus.recording],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Closes detections left `recording` by a process that died mid-journey.
  ///
  /// Their `ended_at` is set to the last fix actually captured rather than to
  /// now: the gap between the process dying and the app next opening is not
  /// riding time, and dating the detection to "now" would stretch a 20-minute
  /// commute across an overnight.
  Future<int> closeStaleRecordingDetections() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawUpdate(
      '''
      UPDATE auto_detections
         SET status = ?,
             ended_at = COALESCE(
               (SELECT MAX(timestamp) FROM auto_fixes
                 WHERE auto_fixes.detection_id = auto_detections.id),
               started_at
             )
       WHERE status = ?
      ''',
      [AutoDetectionStatus.pending, AutoDetectionStatus.recording],
    );
  }

  Future<List<Map<String, dynamic>>> pendingDetections() async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'auto_detections',
      where: 'status = ?',
      whereArgs: [AutoDetectionStatus.pending],
      orderBy: 'started_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> fixesFor(String detectionId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'auto_fixes',
      where: 'detection_id = ?',
      whereArgs: [detectionId],
      orderBy: 'timestamp ASC',
    );
  }

  /// Promotes a detection to a real ride and drops its staged fixes.
  ///
  /// One transaction on purpose. The failure this guards against is a crash
  /// between "ride row written" and "detection marked reconciled", which on
  /// the next launch would reconcile the same detection again and give the
  /// rider two copies of one journey — with the distance counted twice against
  /// their bike's service interval.
  Future<void> markReconciled(String detectionId, String rideId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'auto_detections',
        {'status': AutoDetectionStatus.reconciled, 'ride_id': rideId},
        where: 'id = ?',
        whereArgs: [detectionId],
      );
      await txn.delete('auto_fixes',
          where: 'detection_id = ?', whereArgs: [detectionId]);
    });
  }

  /// Rejects a detection — too short, too slow, or the rider said it wasn't a
  /// ride. The row is kept (with its reason) rather than deleted: knowing what
  /// was rejected and why is the only way to tune the thresholds, and it is a
  /// handful of bytes per journey.
  Future<void> markDiscarded(String detectionId, String reason) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'auto_detections',
        {'status': AutoDetectionStatus.discarded, 'discard_reason': reason},
        where: 'id = ?',
        whereArgs: [detectionId],
      );
      await txn.delete('auto_fixes',
          where: 'detection_id = ?', whereArgs: [detectionId]);
    });
  }

  /// Detection outcomes for the trigger-quality report, newest first.
  Future<List<Map<String, dynamic>>> recentOutcomes({int limit = 200}) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'auto_detections',
      where: 'status IN (?, ?)',
      whereArgs: [
        AutoDetectionStatus.reconciled,
        AutoDetectionStatus.discarded,
      ],
      orderBy: 'started_at DESC',
      limit: limit,
    );
  }
}
