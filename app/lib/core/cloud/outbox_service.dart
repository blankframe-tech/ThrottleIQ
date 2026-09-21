import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../database/daos/outbox_dao.dart';
import '../database/database_helper.dart';
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

  /// Syncing a maintenance log entry to the rider's Firestore subcollection.
  static const String maintenanceLog = 'maintenance_log';
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

/// After this many rejections that retrying can't fix, an entry is retired
/// to [OutboxStatus.dead] — §69.O4. Not 1: a `permission-denied` can be a
/// token that hasn't refreshed yet, or rules that are mid-deploy.
const int kOutboxMaxPermanentFailures = 3;

/// After this many failed attempts of any kind, an entry is retired too.
/// With [outboxBackoff] capped at 30 minutes that is several hours of
/// genuinely trying — past that, something is wrong that the rider should
/// see rather than the queue silently retrying every half hour forever.
const int kOutboxMaxAttempts = 20;

/// Firestore error codes a retry will not change: the server looked at the
/// write and said no. Everything else (`unavailable`, `deadline-exceeded`,
/// `aborted`, a socket error, a Cloudinary hiccup…) is transient.
const Set<String> kOutboxPermanentErrorCodes = {
  'permission-denied',
  'invalid-argument',
  'not-found',
  'failed-precondition',
};

/// Whether [error] is a rejection that retrying won't fix. See
/// [kOutboxPermanentErrorCodes].
bool isPermanentOutboxError(Object error) =>
    error is FirebaseException &&
    kOutboxPermanentErrorCodes.contains(error.code);

/// The uid a queued entry belongs to, or null if its payload doesn't say.
/// Every real payload carries one of these two keys (see [OutboxKind]).
String? outboxEntryOwner(OutboxEntry entry) {
  final owner = entry.payload['userId'] ?? entry.payload['uid'];
  return owner is String ? owner : null;
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
/// Riverpod provider for [OutboxService]. Participates in the dependency graph
/// and can be cleanly overridden in unit/integration tests.
final outboxServiceProvider = Provider<OutboxService>((ref) {
  final service = OutboxService();
  ref.onDispose(() => service.dispose());
  return service;
});

class OutboxService {
  OutboxService({
    OutboxDao? dao,
    RideShareRepository? shareRepository,
    FirebaseFirestore? firestore,
    String? Function()? currentUid,
    Future<OutboxDeliveryResult> Function(OutboxEntry entry)? deliverOverride,
  })  : _dao = dao ?? OutboxDao(),
        _explicitShareRepository = shareRepository,
        _explicitFirestore = firestore,
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _deliverOverride = deliverOverride;

  final OutboxDao _dao;

  /// Who is signed in right now. Injected so tests can switch accounts
  /// without a live FirebaseAuth.
  final String? Function() _currentUid;

  /// Test-only: replaces the per-kind handlers, so the retry/dead-letter
  /// policy in [_deliver] can be exercised without Firestore.
  final Future<OutboxDeliveryResult> Function(OutboxEntry entry)?
      _deliverOverride;
  RideShareRepository? _explicitShareRepository;
  FirebaseFirestore? _explicitFirestore;

  RideShareRepository get _shareRepository =>
      _explicitShareRepository ??= RideShareRepository();
  FirebaseFirestore get _firestore =>
      _explicitFirestore ??= FirebaseFirestore.instance;

  /// Serializes every delivery attempt — [drain] and [_attemptOne] alike —
  /// so two never run concurrently. issues §62.7: [_attemptOne] (run
  /// synchronously from `enqueueShareRide` et al.) used to be unguarded
  /// while a boolean `_draining` flag protected only [drain] from itself. A
  /// rider tapping "share ride" the instant a timer-triggered `drain()` was
  /// already running could get both calling `_deliverShareRide` on the same
  /// entry at once — double-uploading a photo to Cloudinary and racing on
  /// `_dao.updatePayload` (last write wins, so one photo URL could vanish).
  /// Chaining every call onto this future serializes them regardless of
  /// which method they came in through; each link swallows its own error so
  /// one failed attempt doesn't wedge the chain for the next caller, while
  /// the original error still propagates to whoever awaited that attempt.
  Future<void> _queue = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Fires whenever the queue's depth may have changed, so a UI badge can
  /// refresh without polling.
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  Future<int> pendingCount() => _dao.pendingCount();
  Future<int> pendingShareCount() =>
      _dao.pendingCountOfKind(OutboxKind.shareRide);

  /// Entries the queue gave up on — Settings → Sync issues.
  Future<List<OutboxEntry>> deadEntries() => _dao.dead();
  Future<int> deadCount() => _dao.deadCount();

  /// The rider's "Retry" on a dead entry: back in line with fresh counters,
  /// and one attempt straight away. Returns true if that attempt delivered.
  Future<bool> retryDead(String id) async {
    await _dao.revive(id);
    _changes.add(null);
    return await _attemptOne(id) == OutboxDeliveryResult.delivered;
  }

  /// The rider's "Discard" on a dead entry. The intent is gone for good.
  Future<void> discard(String id) async {
    await _serialized(() => _dao.delete(id));
    _changes.add(null);
  }

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
    int? hardBrakeCount,
    int? rapidAccelCount,
    int? highJerkCount,
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
        'maxSpeedKmh': maxSpeedKmh,
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
        'hardBrakeCount': hardBrakeCount,
        'rapidAccelCount': rapidAccelCount,
        'highJerkCount': highJerkCount,
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

  Future<String> enqueueMaintenanceLog({
    required String uid,
    required Map<String, dynamic> logData,
    bool attemptNow = true,
  }) async {
    final entryId = 'maintenance:${logData['id']}';
    await _dao.enqueue(
      id: entryId,
      kind: OutboxKind.maintenanceLog,
      payload: {
        'uid': uid,
        'log': logData,
      },
    );
    _changes.add(null);
    if (attemptNow) {
      unawaited(_attemptOne(entryId));
    }
    return entryId;
  }

  Future<OutboxDeliveryResult> _attemptOne(String id) {
    return _serialized(() async {
      final entries = await _dao.all();
      final entry = entries.where((e) => e.id == id).firstOrNull;
      if (entry == null) return OutboxDeliveryResult.delivered;
      return _deliver(entry);
    });
  }

  /// Replays every entry whose backoff has elapsed.
  ///
  /// Reentrancy-guarded via [_serialized]: [SyncManager] calls this from a
  /// periodic timer, from its connectivity listener and on login, and those
  /// can easily overlap — and it must also never run concurrently with a
  /// caller-triggered [_attemptOne] (see [_serialized]'s doc comment).
  ///
  /// Only the signed-in rider's own entries are replayed — §69.O4. On a
  /// shared phone, account A's queued share used to be attempted under B's
  /// credentials: rules reject it (it names A), so it failed forever, or —
  /// for a write the rules didn't pin to the author — landed as B. Another
  /// account's rows are left exactly as they are (no attempt counted) until
  /// that account signs back in. An entry with no owner in its payload is
  /// still attempted: its handler rejects it as malformed.
  Future<void> drain() {
    return _serialized(() async {
      try {
        final due = await _dao.due();
        final uid = _currentUid();
        for (final entry in due) {
          final owner = outboxEntryOwner(entry);
          if (owner != null && owner != uid) continue;
          await _deliver(entry);
        }
      } finally {
        _changes.add(null);
      }
    });
  }

  Future<OutboxDeliveryResult> _deliver(OutboxEntry entry) async {
    try {
      final override = _deliverOverride;
      final handled = override != null
          ? await override(entry)
          : switch (entry.kind) {
              OutboxKind.shareRide => await _deliverShareRide(entry),
              OutboxKind.liveSessionTeardown =>
                await _deliverLiveTeardown(entry),
              OutboxKind.maintenanceLog => await _deliverMaintenanceLog(entry),
              // An unrecognised kind is not going to start working later.
              _ => OutboxDeliveryResult.discarded,
            };

      if (handled == OutboxDeliveryResult.deferred) {
        await _recordFailure(
          entry,
          error: 'not delivered (offline or timed out)',
          permanent: false,
        );
      } else {
        await _dao.delete(entry.id);
      }
      _changes.add(null);
      return handled;
    } catch (e) {
      // A thrown error is different from a timeout: the request reached
      // something that rejected it. Still retried — a permissions error can
      // resolve once rules are deployed or a token refreshes — but only up
      // to [kOutboxMaxPermanentFailures] times for a rejection retrying
      // can't fix, after which the entry is parked for the rider (§69.O4)
      // instead of retried every 30 minutes for the life of the install.
      debugPrint('[Outbox] ${entry.kind} ${entry.id} failed: $e');
      await _recordFailure(
        entry,
        error: e.toString(),
        permanent: isPermanentOutboxError(e),
      );
      _changes.add(null);
      return OutboxDeliveryResult.deferred;
    }
  }

  /// Records one failed attempt, retiring the entry to [OutboxStatus.dead]
  /// once it has hit either give-up threshold.
  Future<void> _recordFailure(
    OutboxEntry entry, {
    required String error,
    required bool permanent,
  }) async {
    final attempts = entry.attempts + 1;
    final permanentFailures = entry.permanentFailures + (permanent ? 1 : 0);
    final dead = permanentFailures >= kOutboxMaxPermanentFailures ||
        attempts >= kOutboxMaxAttempts;
    if (dead) {
      debugPrint('[Outbox] ${entry.kind} ${entry.id} gave up after '
          '$attempts attempts ($permanentFailures permanent)');
    }
    await _dao.recordFailure(
      id: entry.id,
      error: error,
      nextAttemptAt: DateTime.now().add(outboxBackoff(entry.attempts)),
      permanent: permanent,
      dead: dead,
    );
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
    final dist = (p['distanceKm'] as num?)?.toDouble() ?? 0;
    final dur = (p['durationSeconds'] as num?)?.toInt() ?? 0;
    var maxSpd = (p['maxSpeedKmh'] as num?)?.toDouble() ?? 0;
    final avgSpd = dur > 0 ? (dist / dur) * 3600 : 0.0;
    if (dist > 0 && (maxSpd <= 0 || maxSpd < avgSpd)) {
      maxSpd = avgSpd;
    }

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
            distanceKm: dist,
            durationSeconds: dur,
            maxSpeedKmh: maxSpd,
            polyline: polyline,
            mapSnapshotUrl: null,
            audience: p['audience'] as String? ?? 'public',
            photoUrls: uploaded,
            routeId: p['routeId'] as String?,
            caption: p['caption'] as String?,
            hardBrakeCount: (p['hardBrakeCount'] as num?)?.toInt(),
            rapidAccelCount: (p['rapidAccelCount'] as num?)?.toInt(),
            highJerkCount: (p['highJerkCount'] as num?)?.toInt(),
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
        try {
          // `shareable: false` is what actually revokes the link — §78.7.
          // The `get` rule keys on it (plus `expiresAt`), not on `active`,
          // so without it an ended ride's last position stayed publicly
          // readable by anyone holding the link for the rest of the 24h TTL.
          await _firestore.collection('liveSessions').doc(token).update({
            'status': 'completed',
            'active': false,
            'shareable': false,
            'updatedAt': FieldValue.serverTimestamp(),
          }).timeout(kOutboxAttemptTimeout);
        } on FirebaseException catch (e) {
          // The session doc is already gone (the rider tapped "Stop sharing
          // now", or it was never written) — nothing left to revoke, but
          // the pointer below still needs clearing, so carry on rather than
          // returning early as this used to.
          if (e.code != 'not-found') rethrow;
        }
      }
      await _firestore.collection('livePointers').doc(uid).set({
        'uid': uid,
        'token': null,
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(kOutboxAttemptTimeout);
      return OutboxDeliveryResult.delivered;
    } on TimeoutException {
      return OutboxDeliveryResult.deferred;
    }
  }

  Future<OutboxDeliveryResult> _deliverMaintenanceLog(OutboxEntry entry) async {
    final uid = entry.payload['uid'] as String?;
    final log = entry.payload['log'] as Map<String, dynamic>?;
    if (uid == null || log == null || log['id'] == null) {
      return OutboxDeliveryResult.discarded;
    }

    final logId = log['id'].toString();
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('maintenance')
          .doc(logId)
          .set(log)
          .timeout(kOutboxAttemptTimeout);

      try {
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'maintenance_logs',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [logId],
        );
      } catch (e) {
        debugPrint('[Outbox] local maintenance sync status update skipped: $e');
      }

      return OutboxDeliveryResult.delivered;
    } on TimeoutException {
      return OutboxDeliveryResult.deferred;
    } on SocketException {
      return OutboxDeliveryResult.deferred;
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
