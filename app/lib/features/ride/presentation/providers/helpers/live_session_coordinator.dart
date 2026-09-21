import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/services/battery_service.dart';
import 'package:throttleiq/features/ride/domain/entities/live_session_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

/// Coordinates live-sharing sessions: token creation, periodic position updates,
/// permanent user pointers, and durable offline teardown via [OutboxService].
class LiveSessionCoordinator {
  LiveSessionCoordinator({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  String? _currentLiveSessionToken;
  Timer? _liveSessionTimer;
  bool _liveShareEnabled = false;

  static const Duration _liveSessionUpdateInterval = Duration(seconds: 10);

  bool get isLiveShareEnabled => _liveShareEnabled;
  String? get currentLiveSessionToken => _currentLiveSessionToken;

  void reset() {
    _liveSessionTimer?.cancel();
    _liveSessionTimer = null;
    _currentLiveSessionToken = null;
    _liveShareEnabled = false;
  }

  /// Create a cryptographically secure live share session token.
  ///
  /// Uses `Random.secure()` so the ~190 bits of entropy cannot be guessed from
  /// the system clock (issues §24.2).
  String createLiveSessionToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(32, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// Marks sharing as opted-in and publishes the first snapshot.
  ///
  /// Deliberately does NOT start the periodic timer itself: that requires a
  /// callback the caller re-invokes for every tick so each publish reads the
  /// rider's *current* position/status (see [startPeriodicPublishing]'s doc
  /// comment for why a closure over these plain values instead would freeze
  /// the shared position at whatever it was the instant sharing was turned
  /// on). Callers should follow this with [startPeriodicPublishing].
  Future<String?> enableLiveSharing({
    required String? uid,
    required String? rideId,
    required double? lastLat,
    required double? lastLng,
    required double currentSpeedMs,
    required bool crashDetected,
    required RecordingStatus status,
  }) async {
    if (_liveShareEnabled) return _currentLiveSessionToken;
    if (status != RecordingStatus.active && status != RecordingStatus.paused) {
      return null;
    }
    _liveShareEnabled = true;
    return publishLiveSession(
      uid: uid,
      rideId: rideId,
      lastLat: lastLat,
      lastLng: lastLng,
      currentSpeedMs: currentSpeedMs,
      crashDetected: crashDetected,
      status: status,
    );
  }

  /// Starts (or restarts) the periodic publish tick.
  ///
  /// [onTick] must read fresh state on every call rather than closing over
  /// values captured once — this used to be the caller's job done wrong: the
  /// old `enableLiveSharing` built this closure from its own parameters, so
  /// every 10s tick republished the exact position/speed/status the rider had
  /// at the moment they tapped "share", forever. A live viewer's map simply
  /// never moved. Both call sites (`RideRecordingNotifier.enableLiveSharing`
  /// and its `resumeRide` cold-start path) now pass a closure that re-reads
  /// `state`/`_lastPoint` at call time instead.
  void startPeriodicPublishing({required VoidCallback onTick}) {
    _liveSessionTimer?.cancel();
    _liveSessionTimer = Timer.periodic(_liveSessionUpdateInterval, (_) {
      onTick();
    });
  }

  /// Suspends periodic publishing without clearing the session/token —
  /// used while a ride is paused so a stale position isn't republished every
  /// 10s. [startPeriodicPublishing] resumes it.
  void pausePeriodicPublishing() {
    _liveSessionTimer?.cancel();
    _liveSessionTimer = null;
  }

  /// Publishes the current live session snapshot to Firestore.
  Future<String?> publishLiveSession({
    required String? uid,
    required String? rideId,
    required double? lastLat,
    required double? lastLng,
    required double currentSpeedMs,
    required bool crashDetected,
    required RecordingStatus status,
  }) async {
    if (uid == null || rideId == null) return null;

    try {
      final existingToken = _currentLiveSessionToken;
      final token = existingToken ?? createLiveSessionToken();
      _currentLiveSessionToken = token;

      final batteryLevel = await BatteryService.getBatteryLevel();

      // "Stop sharing now" can land while this tick was awaiting the battery
      // read above. Publishing anyway would re-create the doc the rider just
      // deleted — with `shareable: true` — under the very link they revoked.
      if (!_liveShareEnabled || _currentLiveSessionToken != token) return null;

      final session = LiveSessionEntity(
        token: token,
        uid: uid,
        rideId: rideId,
        active: true,
        lastLat: lastLat,
        lastLng: lastLng,
        speedMs: currentSpeedMs,
        batteryPct: batteryLevel,
        status: crashDetected
            ? LiveSessionStatus.crash
            : (status == RecordingStatus.paused
                ? LiveSessionStatus.paused
                : LiveSessionStatus.riding),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      // Independent docs — run concurrently rather than sequentially so the
      // first share tap (the only time both fire together) isn't stuck
      // waiting on two back-to-back 8s timeouts on a bad connection.
      await Future.wait([
        _bestEffortWrite(
          'live session publish',
          () => _firestore
              .collection('liveSessions')
              .doc(token)
              // Server time, not the phone's clock — §78.7. The entity
              // writes a client Timestamp; a rider whose clock is off would
              // otherwise look stale (or impossibly fresh) to the viewer.
              .set({
                ...session.toFirestore(),
                'updatedAt': FieldValue.serverTimestamp(),
              }),
        ),
        if (existingToken == null) _publishLivePointer(uid, token),
      ]);

      return token;
    } catch (e) {
      debugPrint('[LiveSession] Failed to publish live session: $e');
      return null;
    }
  }

  /// Publishes/refreshes `livePointers/{uid}` for permanent link indirection.
  Future<void> _publishLivePointer(String uid, String token) {
    return _bestEffortWrite(
      'live pointer publish',
      () => _firestore.collection('livePointers').doc(uid).set({
        'uid': uid,
        'token': token,
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// Updates live session status ('riding', 'paused', 'crash', 'completed').
  ///
  /// `completed` also revokes the link (`shareable: false`) — §78.7, same as
  /// the outbox teardown: the rules' `get` keys on `shareable`, not `active`.
  Future<void> updateLiveSessionStatus(LiveSessionStatus status) async {
    final token = _currentLiveSessionToken;
    if (token == null) return;
    final completed = status == LiveSessionStatus.completed;

    await _bestEffortWrite(
      'live session status',
      () => _firestore.collection('liveSessions').doc(token).update({
        'status': status.toString().split('.').last,
        'active': !completed,
        if (completed) 'shareable': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// "Stop sharing now": revokes the live link mid-ride — §78.7.
  ///
  /// Deletes `liveSessions/{token}` outright (the rider asked for it gone,
  /// not just hidden) and clears the `/r/{username}` pointer. Recording
  /// carries on; the rider can share again, which mints a fresh token, so
  /// the revoked link stays dead.
  ///
  /// Both writes go straight to Firestore rather than through the outbox:
  /// the SDK's own offline queue persists them and keeps them in order
  /// relative to a later re-share's pointer write, which a separately
  /// drained outbox entry could not guarantee (a late teardown would clear
  /// the NEW pointer). If the delete is rejected — e.g. the rules granting
  /// it aren't deployed yet — it falls back to `shareable: false`, which the
  /// existing owner-update rule allows and which closes the link just the
  /// same.
  Future<void> stopSharingNow({required String? uid}) async {
    final token = _currentLiveSessionToken;
    _currentLiveSessionToken = null;
    _liveShareEnabled = false;
    _liveSessionTimer?.cancel();
    _liveSessionTimer = null;

    await Future.wait([
      if (token != null) _revokeSession(token),
      if (uid != null)
        _bestEffortWrite(
          'live pointer clear',
          () => _firestore.collection('livePointers').doc(uid).set({
            'uid': uid,
            'token': null,
            'active': false,
            'updatedAt': FieldValue.serverTimestamp(),
          }),
        ),
    ]);
  }

  Future<void> _revokeSession(String token) async {
    final doc = _firestore.collection('liveSessions').doc(token);
    try {
      await doc.delete().timeout(kOutboxAttemptTimeout);
    } on TimeoutException {
      debugPrint('[LiveSession] session delete not confirmed within '
          '${kOutboxAttemptTimeout.inSeconds}s — queued by Firestore, moving on');
    } on FirebaseException catch (e) {
      debugPrint('[LiveSession] session delete rejected ($e) — '
          'falling back to shareable:false');
      await _bestEffortWrite(
        'live session revoke',
        () => doc.update({
          'status': 'completed',
          'active': false,
          'shareable': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    } catch (e) {
      debugPrint('[LiveSession] session delete failed: $e');
    }
  }

  /// Ends the live session and clears the permanent pointer durably via [OutboxService].
  ///
  /// Only awaits the local, near-instant durable enqueue (`attemptNow:
  /// false`) — never the Firestore round-trip. This used to await
  /// [OutboxService.enqueueLiveSessionTeardown]'s default `attemptNow: true`,
  /// which blocks on an up-to-8s network write; since every caller of this
  /// method (`stopRide`, `cancelRide`, `restoreInterruptedRide`) sits
  /// directly on a rider-facing tap or the app-launch path, that made
  /// ending a ride on a slow/flaky connection feel frozen. The teardown is
  /// still guaranteed queued by the time this returns, so nothing is lost if
  /// the app is killed a moment later — [SyncManager]'s periodic drain (or
  /// the next natural outbox attempt) delivers it in the background.
  Future<void> tearDownLiveShare({
    required String? uid,
    required OutboxService outbox,
  }) async {
    final token = _currentLiveSessionToken;
    _currentLiveSessionToken = null;
    _liveShareEnabled = false;
    _liveSessionTimer?.cancel();
    _liveSessionTimer = null;

    if (uid == null) return;

    await outbox.enqueueLiveSessionTeardown(
      uid: uid,
      token: token,
      attemptNow: false,
    );
  }

  Future<void> _bestEffortWrite(String label, Future<void> Function() write) async {
    try {
      await write().timeout(kOutboxAttemptTimeout);
    } on TimeoutException {
      debugPrint('[LiveSession] $label not confirmed within '
          '${kOutboxAttemptTimeout.inSeconds}s — queued by Firestore, moving on');
    } catch (e) {
      debugPrint('[LiveSession] $label failed: $e');
    }
  }

  void dispose() {
    _liveSessionTimer?.cancel();
    _liveSessionTimer = null;
  }
}
