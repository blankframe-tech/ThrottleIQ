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
  /// Discard reason for a pre-v15 detection (no owner recorded) that was
  /// never claimed — see [discardStaleUnowned].
  static const unownedLegacyReason = 'unowned_legacy';

  /// How long an unowned detection is kept waiting to be claimed.
  static const unownedMaxAge = Duration(days: 7);

  /// [userId] is the rider signed in when the detection opened, as handed to
  /// the background isolate by `AutoTrackingService.setOwner`. Null only when
  /// no owner had been saved yet (the service restarted after an app update,
  /// before the app itself was opened); such rows are treated like pre-v15
  /// ones — see [claimUnowned].
  Future<void> insertDetection({
    required String id,
    required DateTime startedAt,
    required String triggerSource,
    String? userId,
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
        'user_id': userId,
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

  /// Detections waiting to become [userId]'s rides.
  ///
  /// Scoped to the owner (claude_sol §1.4.2): this used to return every
  /// pending row, and the reconciler attributed all of them to whoever was
  /// signed in — on a shared phone, rider A's commute became rider B's ride,
  /// on B's bike, counted toward B's service interval.
  Future<List<Map<String, dynamic>>> pendingDetections(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.query(
      'auto_detections',
      where: 'status = ? AND user_id = ?',
      whereArgs: [AutoDetectionStatus.pending, userId],
      orderBy: 'started_at ASC',
    );
  }

  /// Discards pending/recording detections with no owner that started before
  /// [now] minus [unownedMaxAge]. Returns how many.
  ///
  /// These are rows written before v15 (or in the post-update window described
  /// on [insertDetection]) that [claimUnowned] never claimed. After a week no
  /// one is going to recognise the journey, and holding them longer only
  /// keeps their raw fixes on disk.
  Future<int> discardStaleUnowned(DateTime now) async {
    final db = await DatabaseHelper.instance.database;
    final cutoff = now.subtract(unownedMaxAge).toIso8601String();
    return db.transaction((txn) async {
      final rows = await txn.query('auto_detections',
          columns: ['id'],
          where: 'user_id IS NULL AND status IN (?, ?) AND started_at < ?',
          whereArgs: [
            AutoDetectionStatus.pending,
            AutoDetectionStatus.recording,
            cutoff,
          ]);
      for (final row in rows) {
        await txn.update(
          'auto_detections',
          {
            'status': AutoDetectionStatus.discarded,
            'discard_reason': unownedLegacyReason,
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        await txn.delete('auto_fixes',
            where: 'detection_id = ?', whereArgs: [row['id']]);
      }
      return rows.length;
    });
  }

  /// Gives unowned pending detections to [userId], but only when this device
  /// has never held another rider's data. Returns how many were claimed.
  ///
  /// The simplest rule that is still safe. An unowned row carries no hint of
  /// whose it was, so on a phone only one rider has used — the common case,
  /// and the one where refusing would silently drop real rides — it can only
  /// be theirs. If any ride or bike on this device belongs to someone else,
  /// the row could be either rider's, so it is left unclaimed and
  /// [discardStaleUnowned] drops it after [unownedMaxAge]. Losing a
  /// pre-update detection on a shared phone is the lesser harm than putting
  /// one rider's journey on another's bike.
  Future<int> claimUnowned(String userId) async {
    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) async {
      final others = await txn.rawQuery('''
        SELECT 1 FROM rides WHERE user_id != ?
        UNION ALL
        SELECT 1 FROM bikes WHERE user_id != ?
        LIMIT 1
      ''', [userId, userId]);
      if (others.isNotEmpty) return 0;
      return txn.update(
        'auto_detections',
        {'user_id': userId},
        where: 'user_id IS NULL AND status = ?',
        whereArgs: [AutoDetectionStatus.pending],
      );
    });
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
