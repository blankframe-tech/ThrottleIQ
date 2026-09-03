import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:throttleiq/core/cloud/outbox_service.dart';
import 'package:throttleiq/core/services/haptic_service.dart';
import 'package:throttleiq/core/services/notification_service.dart';
import 'package:throttleiq/features/ride/domain/calculators/event_detector.dart';

/// Coordinates crash detection response: haptics, lockscreen notification escalation,
/// 60-second countdown timer, emergency contact notification dispatch, and false-alarm logging.
class CrashCoordinator {
  CrashCoordinator({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  Timer? _crashCountdownTimer;

  bool _crashHandlingActive = false;
  bool get isCrashHandlingActive => _crashHandlingActive;

  /// Starts the crash response sequence: max vibration, lockscreen alert, and 60s countdown.
  Future<void> startCrashSequence({
    required void Function(int secondsRemaining) onTick,
    required Future<void> Function() onExpired,
  }) async {
    if (_crashHandlingActive) return;
    _crashHandlingActive = true;

    await HapticService.maxVibration();
    unawaited(NotificationService.instance.showCrashAlert(secondsRemaining: 60));

    _crashCountdownTimer?.cancel();
    var secondsLeft = 60;

    _crashCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft > 0) {
        secondsLeft--;
        onTick(secondsLeft);
      } else {
        timer.cancel();
        _crashCountdownTimer = null;
        unawaited(NotificationService.instance.cancelCrashAlert());
        onExpired();
      }
    });
  }

  /// Cancels countdown and dismisses crash state (user confirmed safe).
  Future<void> dismissCrashAlert({
    required String? uid,
    required String? rideId,
    required CrashSignal? lastCrashSignal,
  }) async {
    _crashHandlingActive = false;
    _crashCountdownTimer?.cancel();
    _crashCountdownTimer = null;

    await NotificationService.instance.cancelCrashAlert();

    // Log false positive to Firestore for ML/threshold tuning.
    if (uid != null && rideId != null) {
      await _bestEffortWrite(
        'false-positive log',
        () => _firestore
            .collection('users')
            .doc(uid)
            .collection('falseCrashPositives')
            .add({
          'rideId': rideId,
          'timestamp': DateTime.now().toIso8601String(),
          'crashSignal': lastCrashSignal?.toMap(),
        }),
      );
    }
  }

  /// Dispatches emergency notification doc to Firestore when countdown expires.
  Future<void> dispatchEmergencyNotification({
    required String? uid,
    required String? rideId,
    required double? lastLat,
    required double? lastLng,
  }) async {
    if (uid == null || rideId == null) return;

    await _bestEffortWrite(
      'crash notification',
      () => _firestore.collection('crashNotifications').add({
        'uid': uid,
        'rideId': rideId,
        'timestamp': DateTime.now().toIso8601String(),
        'lastLat': lastLat,
        'lastLng': lastLng,
        'status': 'pending',
      }),
    );
  }

  Future<void> _bestEffortWrite(String label, Future<void> Function() write) async {
    try {
      await write().timeout(kOutboxAttemptTimeout);
    } on TimeoutException {
      debugPrint('[Crash] $label not confirmed within '
          '${kOutboxAttemptTimeout.inSeconds}s — queued by Firestore, moving on');
    } catch (e) {
      debugPrint('[Crash] $label failed: $e');
    }
  }

  void dispose() {
    _crashCountdownTimer?.cancel();
    _crashCountdownTimer = null;
    _crashHandlingActive = false;
  }
}
