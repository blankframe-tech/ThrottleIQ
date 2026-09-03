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
  /// the system clock (docs/Issues.md §24.2).
  String createLiveSessionToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(32, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// Starts live session publishing with explicit rider opt-in.
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
    final token = await publishLiveSession(
      uid: uid,
      rideId: rideId,
      lastLat: lastLat,
      lastLng: lastLng,
      currentSpeedMs: currentSpeedMs,
      crashDetected: crashDetected,
      status: status,
    );

    startPeriodicPublishing(
      onTick: () => publishLiveSession(
        uid: uid,
        rideId: rideId,
        lastLat: lastLat,
        lastLng: lastLng,
        currentSpeedMs: currentSpeedMs,
        crashDetected: crashDetected,
        status: status,
      ),
    );

    return token;
  }

  void startPeriodicPublishing({required VoidCallback onTick}) {
    _liveSessionTimer?.cancel();
    _liveSessionTimer = Timer.periodic(_liveSessionUpdateInterval, (_) {
      onTick();
    });
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

      await _bestEffortWrite(
        'live session publish',
        () => _firestore
            .collection('liveSessions')
            .doc(token)
            .set(session.toFirestore()),
      );

      if (existingToken == null) {
        await _publishLivePointer(uid, token);
      }

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
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }),
    );
  }

  /// Updates live session status ('riding', 'paused', 'crash', 'completed').
  Future<void> updateLiveSessionStatus(LiveSessionStatus status) async {
    final token = _currentLiveSessionToken;
    if (token == null) return;

    await _bestEffortWrite(
      'live session status',
      () => _firestore.collection('liveSessions').doc(token).update({
        'status': status.toString().split('.').last,
        'active': status != LiveSessionStatus.completed,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// Ends the live session and clears the permanent pointer durably via [OutboxService].
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
