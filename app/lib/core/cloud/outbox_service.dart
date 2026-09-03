import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:latlong2/latlong.dart';

import '../database/daos/outbox_dao.dart';
import '../../features/social/data/repositories/ride_share_repository.dart';

/// The operations that can be queued for later delivery.
///
/// Stored as plain strings in the `outbox.kind` column (see [OutboxDao]) so a
/// row written by a newer build and read by an older one is skipped rather
/// than crashing it.
class OutboxKind {
  OutboxKind._();

  /// Posting a ride to the social feed, including its photo uploads.
  static const String shareRide = 'share_ride';

  /// Marking a live-share session finished and clearing the rider's
  /// `/r/{username}` pointer. Queued because it runs on the end-of-ride path,
  /// which must never block on the network.
  static const String liveSessionTeardown = 'live_session_teardown';
}

/// How long an attempt is given before we stop waiting on it.
///
/// This is the crux of the whole offline story. A Firestore write issued while
/// offline does **not** throw — the SDK accepts it into its own local mutation
/// queue and the returned Future stays unresolved until a server acknowledges
/// it, which may be hours. Awaiting one on a user-facing path is what made
/// "end ride" and "share ride" hang with no connection. Every network call the
/// outbox makes is therefore bounded by this, and a timeout is treated as
/// "not delivered yet", not as failure.
const Duration kOutboxAttemptTimeout = Duration(seconds: 8);

/// Backoff before retrying a failed queue entry: 30s, 1m, 2m, 4m … capped at
/// 30 minutes.
///
/// Pure so it can be unit-tested without a database or a network. The cap
/// matters more than the curve: [SyncManager] also drains on every
/// connectivity change, so a rider who regains signal gets their queue flushed
/// immediately regardless of where the backoff had crept to.
Duration outboxBackoff(int attempts) {
  const base = Duration(seconds: 30);
  const cap = Duration(minutes: 30);
  if (attempts <= 0) return base;
  // Shift rather than pow, and clamp the exponent before shifting — 1 << 40
  // silently overflows to nonsense on a 64-bit int.
  final exponent = attempts > 10 ? 10 : attempts;
  final scaled = base * (1 << exponent).toDouble();
  return scaled > cap ? cap : scaled;
}

/// Outcome of trying to deliver one queued operation.
enum OutboxDeliveryResult {
  /// Landed in the cloud. The row is gone.
  delivered,

  /// Couldn't be delivered right now (offline, timeout, transient error).
  /// The row stays queued and will be retried.
  deferred,

  /// Can never succeed (malformed payload, unknown kind). The row is dropped
  /// rather than retried forever.
  discarded,
}

/// Records and replays cloud writes the rider has already committed to.
///
/// The contract every caller relies on: **once [enqueue] returns, the rider's
/// intent is on disk and will happen.** Callers may then ask for an immediate
/// delivery attempt, but they never have to wait for one, and a failed attempt
/// costs nothing — the row is still queued.
class OutboxService {
  OutboxService({
    OutboxDao? dao,
    RideShareRepository? shareRepository,
    FirebaseFirestore? firestore,
  })  : _dao = dao ?? OutboxDao(),
        _shareRepository = shareRepository ?? RideShareRepository(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  static final OutboxService instance = OutboxService();

  final OutboxDao _dao;
  final RideShareRepository _shareRepository;
  final FirebaseFirestore _firestore;

  bool _draining = false;

  /// Fires whenever the queue's depth may have changed, so a UI badge can
  /// refresh without polling.
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  Future<int> pendingCount() => _dao.pendingCount();
  Future<int> pendingShareCount() =>
      _dao.pendingCountOfKind(OutboxKind.shareRide);

  /// Queues a ride share and, unless [attemptNow] is false, tries to deliver
  /// it straight away.
  ///
  /// Returns true if it actually reached Firestore; false means it is safely
  /// queued and the caller should tell the rider it will post later — never
  /// that it failed. The queue id is the ride id, so re-sharing the same ride
  /// while a share is still pending supersedes it rather than double-posting.
  Future<bool> enqueueShareRide({
    required String rideId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
    required String bikeId,
    required String bikeName,
    required String bikeType,
    required DateTime rideDate,
    required double distanceKm,
    required int durationSeconds,
    required double maxSpeedKmh,
    required List<LatLng> polyline,
    required String audience,
    List<String> localPhotoPaths = const [],
    List<String> uploadedPhotoUrls = const [],
    String? routeId,
    String? caption,
    bool attemptNow = true,
  }) async {
    await _dao.enqueue(
      id: 'share:$rideId',
      kind: OutboxKind.shareRide,
      payload: {
        'rideId': rideId,
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'bikeId': bikeId,
        'bikeName': bikeName,
        'bikeType': bikeType,
        'rideDate': rideDate.toIso8601String(),
        'distanceKm': distanceKm,
        'durationSeconds': durationSeconds,
        // Flat array of coordinates [lat, lng, lat, lng, ...] reduces outbox
        // JSON row size significantly and eliminates nested list allocations.
        'polyline': [
          for (final p in polyline) ...[p.latitude, p.longitude],
        ],
        'audience': audience,
        'localPhotoPaths': localPhotoPaths,
        'uploadedPhotoUrls': uploadedPhotoUrls,
        'routeId': routeId,
        'caption': caption,
      },
    );
    _changes.add(null);
    if (!attemptNow) return false;
    return await _attemptOne('share:$rideId') == OutboxDeliveryResult.delivered;
  }

  /// Queues the end-of-ride live-share teardown.
  ///
  /// [token] may be null when the ride was never shared live; in that case only
  /// the pointer clear is queued. Both writes are idempotent, which is what
  /// makes it safe for this to race with Firestore's own offline replay of the
  /// same writes.
  Future<bool> enqueueLiveSessionTeardown({
    required String uid,
    required String? token,
    bool attemptNow = true,
  }) async {
    await _dao.enqueue(
      id: 'live-teardown:$uid',
      kind: OutboxKind.liveSessionTeardown,
      payload: {'uid': uid, 'token': token},
    );
    _changes.add(null);
    if (!attemptNow) return false;
    return await _attemptOne('live-teardown:$uid') ==
        OutboxDeliveryResult.delivered;
  }

  Future<OutboxDeliveryResult> _attemptOne(String id) async {
    final entries = await _dao.all();
    final entry = entries.where((e) => e.id == id).firstOrNull;
    if (entry == null) return OutboxDeliveryResult.delivered;
    return _deliver(entry);
  }

  /// Replays every entry whose backoff has elapsed.
  ///
  /// Reentrancy-guarded: [SyncManager] calls this from a periodic timer, from
  /// its connectivity listener and on login, and those can easily overlap.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final due = await _dao.due();
      for (final entry in due) {
        await _deliver(entry);
      }
    } finally {
      _draining = false;
      _changes.add(null);
    }
  }

  Future<OutboxDeliveryResult> _deliver(OutboxEntry entry) async {
    try {
      final handled = switch (entry.kind) {
        OutboxKind.shareRide => await _deliverShareRide(entry),
        OutboxKind.liveSessionTeardown => await _deliverLiveTeardown(entry),
        // An unrecognised kind is not going to start working later.
        _ => OutboxDeliveryResult.discarded,
      };

      if (handled == OutboxDeliveryResult.deferred) {
        await _dao.recordFailure(
          id: entry.id,
          error: 'not delivered (offline or timed out)',
          nextAttemptAt: DateTime.now().add(outboxBackoff(entry.attempts)),
        );
      } else {
        await _dao.delete(entry.id);
      }
      _changes.add(null);
      return handled;
    } catch (e) {
      // A thrown error is different from a timeout: the request reached
      // something that rejected it. Still retried — a permissions error can
      // resolve once rules are deployed or a token refreshes — but recorded so
      // it is visible rather than silent.
      debugPrint('[Outbox] ${entry.kind} ${entry.id} failed: $e');
      await _dao.recordFailure(
        id: entry.id,
        error: e.toString(),
        nextAttemptAt: DateTime.now().add(outboxBackoff(entry.attempts)),
      );
      _changes.add(null);
      return OutboxDeliveryResult.deferred;
    }
  }

  Future<OutboxDeliveryResult> _deliverShareRide(OutboxEntry entry) async {
    final p = entry.payload;
    final rideId = p['rideId'] as String?;
    final userId = p['userId'] as String?;
    if (rideId == null || userId == null) return OutboxDeliveryResult.discarded;

    // Photos first, and folded back into the payload as they land: Cloudinary
    // mints a new asset per call, so a retry that re-uploaded would leave the
    // earlier copies orphaned and burn the rider's quota.
    final localPaths = (p['localPhotoPaths'] as List?)?.cast<String>() ?? const [];
    final uploaded = <String>[
      ...?(p['uploadedPhotoUrls'] as List?)?.cast<String>(),
    ];

    if (uploaded.length < localPaths.length) {
      for (var i = uploaded.length; i < localPaths.length; i++) {
        final file = File(localPaths[i]);
        // A photo the rider has since deleted off the device must not wedge
        // the whole share — post it without that image.
        if (!file.existsSync()) continue;
        try {
          final url = await _shareRepository
              .uploadRidePhoto(userId, rideId, file)
              .timeout(kOutboxAttemptTimeout);
          uploaded.add(url);
          await _dao.updatePayload(
            id: entry.id,
            payload: {...p, 'uploadedPhotoUrls': uploaded},
          );
        } on TimeoutException {
          return OutboxDeliveryResult.deferred;
        } on SocketException {
          return OutboxDeliveryResult.deferred;
        }
      }
    }

    final polyline = decodePolylinePayload(p['polyline']);

    try {
      await _shareRepository
          .shareRide(
            rideId: rideId,
            userId: userId,
            userName: p['userName'] as String? ?? 'Rider',
            userPhotoUrl: p['userPhotoUrl'] as String? ?? '',
            bikeId: p['bikeId'] as String? ?? '',
            bikeName: p['bikeName'] as String? ?? 'Unknown Bike',
            bikeType: p['bikeType'] as String? ?? 'Motorcycle',
            rideDate: DateTime.tryParse(p['rideDate'] as String? ?? '') ??
                entry.createdAt,
            distanceKm: (p['distanceKm'] as num?)?.toDouble() ?? 0,
            durationSeconds: (p['durationSeconds'] as num?)?.toInt() ?? 0,
            maxSpeedKmh: (p['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
            polyline: polyline,
            mapSnapshotUrl: null,
            audience: p['audience'] as String? ?? 'public',
            photoUrls: uploaded,
            routeId: p['routeId'] as String?,
            caption: p['caption'] as String?,
          )
          .timeout(kOutboxAttemptTimeout);
      return OutboxDeliveryResult.delivered;
    } on TimeoutException {
      return OutboxDeliveryResult.deferred;
    }
  }

  Future<OutboxDeliveryResult> _deliverLiveTeardown(OutboxEntry entry) async {
    final uid = entry.payload['uid'] as String?;
    if (uid == null) return OutboxDeliveryResult.discarded;
    final token = entry.payload['token'] as String?;

    try {
      if (token != null) {
        await _firestore.collection('liveSessions').doc(token).update({
          'status': 'completed',
          'active': false,
          'updatedAt': DateTime.now().toIso8601String(),
        }).timeout(kOutboxAttemptTimeout);
      }
      await _firestore.collection('livePointers').doc(uid).set({
        'uid': uid,
        'token': null,
        'active': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }).timeout(kOutboxAttemptTimeout);
      return OutboxDeliveryResult.delivered;
    } on TimeoutException {
      return OutboxDeliveryResult.deferred;
    } on FirebaseException catch (e) {
      // The session doc is already gone (or was never written) — there is
      // nothing left to tear down, so this is success, not a retry.
      if (e.code == 'not-found') return OutboxDeliveryResult.delivered;
      rethrow;
    }
  }

  /// Decodes polyline payload, supporting both modern flat format
  /// `[lat0, lng0, lat1, lng1, ...]` and legacy nested format
  /// `[[lat0, lng0], [lat1, lng1], ...]`.
  @visibleForTesting
  static List<LatLng> decodePolylinePayload(Object? raw) {
    final polyline = <LatLng>[];
    if (raw is List) {
      if (raw.isNotEmpty && raw.first is num) {
        for (var i = 0; i + 1 < raw.length; i += 2) {
          final lat = (raw[i] as num).toDouble();
          final lng = (raw[i + 1] as num).toDouble();
          polyline.add(LatLng(lat, lng));
        }
      } else {
        for (final pair in raw) {
          if (pair is List && pair.length >= 2) {
            final lat = (pair[0] as num).toDouble();
            final lng = (pair[1] as num).toDouble();
            polyline.add(LatLng(lat, lng));
          }
        }
      }
    }
    return polyline;
  }

  @visibleForTesting
  Future<OutboxDeliveryResult> deliverForTesting(OutboxEntry entry) =>
      _deliver(entry);

  void dispose() => _changes.close();
}
