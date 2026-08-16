import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/daos/auto_detection_dao.dart';
import '../../../../core/database/daos/bike_dao.dart';
import '../../../../core/database/daos/ride_dao.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../garage/presentation/providers/garage_provider.dart';
import '../../domain/calculators/auto_ride_reconciler.dart';
import '../../domain/entities/ride_entity.dart';
import '../models/ride_model.dart';

final autoRideReconcilerServiceProvider =
    Provider<AutoRideReconcilerService>((ref) => AutoRideReconcilerService(ref));

/// Turns detections captured by the background isolate into real rides.
///
/// Runs on the **UI isolate**, at launch and whenever the app returns to the
/// foreground. This split is the answer to the isolate problem: the background
/// isolate can't reach `RideRecordingNotifier` or Riverpod, so it only ever
/// writes raw fixes; everything that needs app state — which user, which bike,
/// updating garage totals, notifying — happens here, where that state exists.
///
/// Nothing here runs unless auto-tracking is on and a detection is pending, so
/// the cost on a normal launch is one indexed query returning no rows.
class AutoRideReconcilerService {
  AutoRideReconcilerService(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  final _detectionDao = AutoDetectionDao();
  final _rideDao = RideDao();
  final _pointDao = RidePointDao();
  final _bikeDao = BikeDao();
  final _reconciler = AutoRideReconciler();

  var _running = false;

  /// Processes every pending detection.
  ///
  /// Reentrancy-guarded: this is called from both app launch and the
  /// foreground lifecycle hook, which on a cold start fire close together.
  /// Two concurrent runs would each see the same pending rows and promote
  /// them twice — the duplicate-ride bug that also motivates the transaction
  /// in [AutoDetectionDao.markReconciled].
  Future<List<String>> reconcilePending() async {
    if (_running) return const [];
    _running = true;
    try {
      // A detection left `recording` means the process died mid-journey. It
      // still holds real fixes, so close it (dated to its last fix, not now)
      // and reconcile it like any other rather than abandoning the ride.
      await _detectionDao.closeStaleRecordingDetections();

      final pending = await _detectionDao.pendingDetections();
      if (pending.isEmpty) return const [];

      final uid = _ref.read(currentUserProvider)?.uid;
      if (uid == null) {
        // Signed out. Leave the rows pending rather than discarding them —
        // the rides happened, and attributing them needs a user.
        return const [];
      }

      final createdRideIds = <String>[];
      for (final detection in pending) {
        final rideId = await _reconcileOne(detection, uid);
        if (rideId != null) createdRideIds.add(rideId);
      }

      if (createdRideIds.isNotEmpty) {
        _ref.invalidate(garageProvider);
        unawaited(HomeWidgetService.instance.refreshFromLocalData());
      }
      return createdRideIds;
    } finally {
      _running = false;
    }
  }

  Future<String?> _reconcileOne(
    Map<String, dynamic> detection,
    String uid,
  ) async {
    final detectionId = detection['id'] as String;
    final rows = await _detectionDao.fixesFor(detectionId);

    final staged = <StagedFix>[
      for (final r in rows)
        (
          timestamp: DateTime.parse(r['timestamp'] as String),
          lat: (r['lat'] as num).toDouble(),
          lng: (r['lng'] as num).toDouble(),
          speedMs: (r['speed_ms'] as num?)?.toDouble() ?? 0,
          accuracyM: (r['accuracy_m'] as num?)?.toDouble(),
          altitudeM: (r['altitude_m'] as num?)?.toDouble(),
          headingDeg: (r['heading_deg'] as num?)?.toDouble(),
        ),
    ];

    final outcome = _reconciler.reconcile(staged);
    if (!outcome.isAccepted) {
      await _detectionDao.markDiscarded(detectionId, outcome.rejectionReason!);
      return null;
    }

    // Attribution. There is no signal in a background detection saying which
    // bike was ridden, so this falls back to whichever bike is active and
    // records that it guessed — see BikeAttributionConfidence. The one case
    // that is *not* a guess is a single-bike garage, where "the active bike"
    // and "the only bike" are the same statement.
    final bikes = _ref.read(garageProvider).valueOrNull ?? const [];
    final activeBike = _ref.read(activeBikeProvider);
    if (activeBike == null) {
      // No bike to attribute to at all. Keep the detection pending rather
      // than discarding a real ride — once the rider adds a bike, the next
      // launch picks it up.
      debugPrint('[auto-tracking] $detectionId held: no bike in garage');
      return null;
    }
    final confidence = bikes.length <= 1
        ? BikeAttributionConfidence.high
        : BikeAttributionConfidence.low;

    final ride = outcome.ride!;
    final startTime = staged.first.timestamp;
    final rideId = _uuid.v4();

    final entity = RideEntity(
      id: rideId,
      userId: uid,
      bikeId: activeBike.id,
      startTime: startTime,
      endTime: staged.last.timestamp,
      distanceM: ride.distanceM,
      avgSpeedMs: ride.avgSpeedMs,
      maxSpeedMs: ride.maxSpeedMs,
      durationSeconds: ride.durationSeconds,
      movingSeconds: ride.movingSeconds,
      hardBrakeCount: ride.hardBrakeCount,
      rapidAccelCount: ride.rapidAccelCount,
      highJerkCount: ride.highJerkCount,
      status: RideStatus.completed,
      isAuto: true,
      bikeConfidence: confidence,
    );

    // Inserted already-complete rather than inserted-then-finalized. The live
    // path writes an `active` row at ride start because the ride is genuinely
    // in progress and must survive a crash mid-recording; here the journey is
    // over before the row exists, so a two-step write would only create a
    // window where a half-formed ride is visible in history.
    await _rideDao.insert(RideModel.toMap(entity));

    await _pointDao.insertBatch([
      for (final p in ride.points) {...p, 'ride_id': rideId},
    ]);

    await _bikeDao.incrementStats(activeBike.id, ride.distanceM);
    await _detectionDao.markReconciled(detectionId, rideId);

    // A crash signal found during replay is recorded and shown to the rider,
    // and deliberately does NOT reach the emergency-contact flow. That flow
    // summons help within a minute of an impact; firing it here would mean
    // calling someone's family about a crash that — if it happened at all —
    // is hours old and which the rider evidently survived, since the app is
    // open. See ReconciledRide.crashSuspected.
    if (ride.crashSuspected) {
      debugPrint('[auto-tracking] ride $rideId replayed a crash signal');
    }

    if (confidence.needsConfirmation) {
      unawaited(NotificationService.instance.showRideConfirmation(
        rideId: rideId,
        bikeLabel: '${activeBike.brand} ${activeBike.model}',
        distanceKm: ride.distanceM / 1000,
      ));
    }

    return rideId;
  }
}
