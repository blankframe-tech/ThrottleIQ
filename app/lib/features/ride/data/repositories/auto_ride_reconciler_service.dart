import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/daos/auto_detection_dao.dart';
import '../../../../core/services/auto_tracking_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/calculators/auto_detection_policy.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../presentation/providers/daily_ride_summary_provider.dart';
import 'detected_odometer_credit.dart';

final autoRideReconcilerServiceProvider =
    Provider<AutoRideReconcilerService>((ref) => AutoRideReconcilerService(ref));

/// Hands detections captured by the background isolate to the rider's daily
/// summary (it used to turn each into a ride row — see [_summarizeOne]).
///
/// Runs on the **UI isolate**, at launch and whenever the app returns to the
/// foreground. This split is the answer to the isolate problem: the background
/// isolate can't reach `RideRecordingNotifier` or Riverpod, so it only ever
/// writes raw fixes; everything that needs app state — which user, notifying —
/// happens here, where that state exists.
///
/// Nothing here runs unless auto-tracking is on and a detection is pending, so
/// the cost on a normal launch is one indexed query returning no rows.
class AutoRideReconcilerService {
  AutoRideReconcilerService(this._ref);

  final Ref _ref;

  final _detectionDao = AutoDetectionDao();
  final _odometerCredit = DetectedOdometerCredit();

  var _running = false;

  /// Moves every pending detection into the daily summary. Returns the ids
  /// of the detections moved.
  ///
  /// Reentrancy-guarded: this is called from both app launch and the
  /// foreground lifecycle hook, which on a cold start fire close together.
  /// Two concurrent runs would each see the same pending rows; harmless now
  /// (summarising is idempotent) but still pointless work.
  Future<List<String>> reconcilePending() async {
    if (_running) return const [];
    _running = true;
    try {
      // A detection left `recording` means the process died mid-journey. It
      // still holds real fixes, so close it (dated to its last fix, not now)
      // and reconcile it like any other rather than abandoning the ride.
      //
      // §90.C2: but only when it really is abandoned. This runs on every
      // foreground, and closing a detection the service is still appending
      // to truncated the ride being ridden right now.
      await _closeAbandonedRecordings();

      final uid = _ref.read(currentUserProvider)?.uid;
      if (uid == null) {
        // Signed out. Leave the rows pending rather than discarding them —
        // the rides happened, and attributing them needs a user.
        return const [];
      }

      // Detections with no recorded owner (pre-v15 rows): drop the stale
      // ones, and claim the rest only if this device has never held another
      // rider's data. See AutoDetectionDao.claimUnowned.
      await _detectionDao.discardStaleUnowned(DateTime.now());
      await _detectionDao.claimUnowned(uid);

      // Only this rider's detections. Another rider's stay pending for when
      // they sign back in on this device (grill §1.4.2).
      final pending = await _detectionDao.pendingDetections(uid);

      // The UI-isolate path to the end-of-day notification (the task handler
      // has its own, see AutoTrackingService). Covers a rider who opens the
      // app after 9pm, and iOS, where the handler may not be alive then.
      unawaited(_ref
          .read(dailyRideSummaryRepositoryProvider)
          .showEndOfDayIfDue(uid));

      if (pending.isEmpty) return const [];

      final summarized = <String>[];
      var creditedKm = 0.0;
      for (final detection in pending) {
        creditedKm += await _summarizeOne(detection, uid);
        summarized.add(detection['id'] as String);
      }
      if (summarized.isNotEmpty) _ref.invalidate(dailyRideSummaryProvider);
      // The bike's odometer moved, so every maintenance due date did too.
      if (creditedKm > 0) _ref.invalidate(garageProvider);
      return summarized;
    } finally {
      _running = false;
    }
  }

  /// How long a `recording` detection may go without a fix, while the
  /// auto-tracking service is running, before it counts as abandoned. Twice
  /// the service's own stillness timeout: a live detection that quiet would
  /// already have been closed by the service itself.
  static final _staleRecordingAfter = AutoTrackingService.stillnessTimeout * 2;

  Future<void> _closeAbandonedRecordings() async {
    final recordings =
        await _detectionDao.recordingDetectionsWithLastActivity();
    if (recordings.isEmpty) return;
    final serviceRunning = await AutoTrackingService.isServiceRunning();
    final now = DateTime.now();
    for (final r in recordings) {
      if (shouldCloseRecordingDetection(
        serviceRunning: serviceRunning,
        lastActivity: r.lastActivity,
        now: now,
        staleAfter: _staleRecordingAfter,
      )) {
        await _detectionDao.closeRecordingDetection(r.id);
      }
    }
  }

  /// Moves one closed detection into the daily summary.
  ///
  /// Before 2026-10 this replayed the fixes and promoted every accepted
  /// detection to a ride row of its own. In Dhaka traffic that surfaced one
  /// commute as 2–5 "rides" — the background detector closes after 5 minutes
  /// still, and jams last longer — and it also put fragments of journeys the
  /// rider was recording by hand into history. Detections are now counted in
  /// the end-of-day summary instead (`daily_ride_summary.dart`), merged across
  /// jam gaps and trimmed against recorded rides at read time. Nothing is
  /// replayed or discarded here, and the fixes stay on disk.
  ///
  /// A detection no longer becomes a ride row or needs a bike confirmation,
  /// but its distance (clear of any recorded ride) still counts toward the
  /// active bike's odometer so maintenance stays due on time — §93.1, see
  /// [DetectedOdometerCredit]. Returns the km credited.
  Future<double> _summarizeOne(
      Map<String, dynamic> detection, String uid) async {
    final id = detection['id'] as String;
    final km =
        await _odometerCredit.creditDetection(userId: uid, detectionId: id);
    await _detectionDao.markSummarized(id);
    return km;
  }
}
