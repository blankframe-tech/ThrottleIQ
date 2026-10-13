import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/realtime/realtime_connection_manager.dart';
import 'package:throttleiq/core/realtime/realtime_health.dart';
import 'package:throttleiq/core/realtime/realtime_location_publisher.dart';
import 'package:throttleiq/core/realtime/realtime_providers.dart';
import 'package:throttleiq/core/services/battery_service.dart';
import 'package:throttleiq/core/services/public_live_link_setting.dart';
import 'package:throttleiq/features/ride/domain/entities/live_session_entity.dart';
import 'package:throttleiq/features/ride/presentation/providers/ride_recording_provider.dart';

/// How often the RTDB relay may write the rider's position while sharing:
/// once per GPS fix at 1 Hz. A hair under a second so a fix arriving 990 ms
/// after the last one isn't skipped, which would halve the rate.
const Duration kLiveRelayInterval = Duration(milliseconds: 900);

/// While the RTDB relay is carrying position, only every Nth 10 s Firestore
/// tick is written (so every 20 s). The Firestore doc still carries status,
/// battery and expiry, and is the viewer's fallback; the viewer's 30 s
/// "updates delayed" warning stays clear of a 20 s cadence.
const int kFirestoreTickDivisorWhenRealtime = 2;

/// Coordinates live-sharing sessions: token creation, periodic position updates,
/// permanent user pointers, and durable offline teardown via [OutboxService].
///
/// Position also goes out at 1 Hz over the Realtime Database
/// (`/live_shares/{token}`) when [RealtimeServices] is enabled — see
/// DOCS/For Devs and Contributors/architecture/realtime-database.md. The
/// Firestore session doc stays authoritative for whether the link is live.
class LiveSessionCoordinator {
  LiveSessionCoordinator({
    FirebaseFirestore? firestore,
    Future<bool> Function()? publicLinkEnabled,
    RealtimeServices? realtime,
    @visibleForTesting
    Timer Function(Duration, void Function(Timer))? periodicTimerFactory,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _publicLinkEnabled =
            publicLinkEnabled ?? PublicLiveLinkSetting.isEnabled,
        _realtime = realtime,
        _periodicTimer = periodicTimerFactory ?? Timer.periodic;

  final FirebaseFirestore _firestore;
  final RealtimeServices? _realtime;
  final Timer Function(Duration, void Function(Timer)) _periodicTimer;
  RealtimeLocationPublisher? _relay;
  RealtimeLease? _relayLease;
  String? _relayToken;
  int _ticks = 0;

  /// Whether the rider opted in to the permanent `/r/{username}` link
  /// (Settings → "Public link (/r/@handle)", issues §90.D7). Read per share,
  /// so a change in Settings applies to the next share without a restart.
  final Future<bool> Function() _publicLinkEnabled;
  String? _currentLiveSessionToken;
  Timer? _liveSessionTimer;
  bool _liveShareEnabled = false;

  static const Duration _liveSessionUpdateInterval = Duration(seconds: 10);

  bool get isLiveShareEnabled => _liveShareEnabled;
  String? get currentLiveSessionToken => _currentLiveSessionToken;

  /// The live RTDB relay, for tests and diagnostics. Null when not sharing
  /// or RTDB isn't configured.
  @visibleForTesting
  RealtimeLocationPublisher? get relay => _relay;

  /// Whether the 1 Hz RTDB relay is currently the thing carrying position.
  bool get _relayCarriesPosition =>
      _relay != null &&
      _realtime?.transportNow() == RealtimeTransport.realtime;

  /// Hands one GPS fix to the RTDB relay. Called for every fix while the
  /// ride is active; the relay throttles to [kLiveRelayInterval]. A no-op
  /// unless sharing is on and the relay is up.
  void offerLocation(LocationSample sample) {
    if (!_liveShareEnabled) return;
    _relay?.offer(sample);
  }

  void reset() {
    _stopRelay();
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
    _liveSessionTimer = _periodicTimer(_liveSessionUpdateInterval, (_) {
      _ticks++;
      if (_relayCarriesPosition &&
          _ticks % kFirestoreTickDivisorWhenRealtime != 0) {
        return;
      }
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

      _ensureRelay(uid, token, session.expiresAt);

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
        if (existingToken == null) _maybePublishLivePointer(uid, token),
      ]);

      return token;
    } catch (e) {
      debugPrint('[LiveSession] Failed to publish live session: $e');
      return null;
    }
  }

  /// Publishes `livePointers/{uid}` — the `/r/{username}` permanent link —
  /// ONLY when the rider has turned on the public link setting. The pointer
  /// is `get: if true` in firestore.rules, so anyone who knows the rider's
  /// @handle can follow them unauthenticated; that used to happen silently on
  /// every opt-in share, while the app only ever showed the private
  /// `/live/{token}` link (issues §90.D7). Default OFF.
  Future<void> _maybePublishLivePointer(String uid, String token) async {
    if (!await _publicLinkEnabled()) return;
    // Sharing may have been stopped while the setting was being read.
    if (!_liveShareEnabled || _currentLiveSessionToken != token) return;
    await _publishLivePointer(uid, token);
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
    _stopRelay();
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
    _stopRelay();
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

  /// Starts the RTDB relay for [token], once per token: writes the node's
  /// owner/expiry, then hands position writes to a 1 Hz publisher. Sync on
  /// purpose — it runs after [publishLiveSession]'s "still sharing?" check
  /// and must not open a gap for "Stop sharing now" to land in.
  void _ensureRelay(String uid, String token, DateTime expiresAt) {
    final realtime = _realtime;
    if (realtime == null || !realtime.isEnabled || _relayToken == token) {
      return;
    }
    _stopRelay();
    _relayToken = token;
    _relayLease = realtime.acquire('live-share');
    unawaited(realtime.store.set('live_shares/$token', {
      'uid': uid,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    }).catchError((Object e) {
      debugPrint('[LiveSession] realtime relay init failed: $e');
    }));
    _relay = RealtimeLocationPublisher(
      store: realtime.store,
      path: 'live_shares/$token/location',
      minInterval: kLiveRelayInterval,
      onAck: realtime.health.recordAck,
    );
  }

  /// Stops the relay and removes `/live_shares/{token}` so the 1 Hz channel
  /// dies with the share. The lease is released once the remove is acked (or
  /// has timed out into the SDK's queue), so the socket isn't torn down with
  /// the remove still unsent.
  void _stopRelay() {
    final relay = _relay;
    final lease = _relayLease;
    final token = _relayToken;
    _relay = null;
    _relayLease = null;
    _relayToken = null;
    _ticks = 0;
    if (relay == null || token == null) {
      lease?.release();
      return;
    }
    unawaited(relay
        .stop(removePath: 'live_shares/$token')
        .whenComplete(() => lease?.release()));
  }

  void dispose() {
    _stopRelay();
    _liveSessionTimer?.cancel();
    _liveSessionTimer = null;
  }
}
