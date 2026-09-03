import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/bike_dao.dart';
import '../database/daos/ride_dao.dart';
import '../../features/garage/presentation/providers/garage_provider.dart';
import '../../features/ride/presentation/providers/ride_recording_provider.dart';
import '../../features/stats/presentation/providers/rider_stats_provider.dart';
import '../database/database_helper.dart';
import 'cloud_repository.dart';
import 'outbox_service.dart';

/// Represents the sync status of the app
enum SyncStatus { idle, syncing, success, failure }

/// Manages automatic sync of local data to Firestore
class SyncManager {
  SyncManager([this._ref, OutboxService? outbox])
      : _outbox = outbox ?? OutboxService.instance {
    _initConnectivityListener();
  }

  /// Nullable: only needed to invalidate providers after a download pulls
  /// in new rows (see _performSync). Tests/callers that don't care about
  /// live UI refresh can omit it.
  final Ref? _ref;

  final CloudRepository _cloudRepository = CloudRepository();
  final OutboxService _outbox;
  final Connectivity _connectivity = Connectivity();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _autoSyncTimer;
  bool _autoSyncEnabled = false;
  int _consecutiveFailures = 0;
  bool _isSyncing = false;
  SyncStatus _status = SyncStatus.idle;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final List<VoidCallback> _listeners = [];

  bool get isSyncing => _isSyncing;
  SyncStatus get status => _status;

  void addListener(VoidCallback callback) {
    _listeners.add(callback);
  }

  void removeListener(VoidCallback callback) {
    _listeners.remove(callback);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Initialize connectivity listener
  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        // Internet is back - reset failure counter and sync immediately
        _consecutiveFailures = 0;
        _performSync();
      }
    });
  }

  /// Start automatic sync with 5-minute interval or adaptive backoff on failure
  void startAutoSync() {
    if (_autoSyncEnabled) return;
    _autoSyncEnabled = true;

    // Perform initial sync
    _performSync();
  }

  /// Stop automatic sync
  void stopAutoSync() {
    _autoSyncEnabled = false;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  void _scheduleNextAutoSync() {
    if (!_autoSyncEnabled) return;
    _autoSyncTimer?.cancel();

    Duration delay;
    if (_status == SyncStatus.failure && _consecutiveFailures > 0) {
      // Exponential backoff capped at 30 minutes on consecutive failures
      delay = outboxBackoff(_consecutiveFailures);
    } else {
      delay = const Duration(minutes: 5);
    }

    _autoSyncTimer = Timer(delay, () {
      if (_autoSyncEnabled) {
        _performSync();
      }
    });
  }

  /// Perform sync with retry logic
  Future<void> _performSync() async {
    if (_isSyncing) return;
    if (_auth.currentUser == null) return;

    // Check connectivity first
    final connectivityResult = await _connectivity.checkConnectivity();
    final hasInternet = connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);

    if (!hasInternet) {
      _status = SyncStatus.failure;
      _consecutiveFailures++;
      _notifyListeners();
      _scheduleNextAutoSync();
      return;
    }

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _notifyListeners();

    // Anything the rider already committed to while offline goes FIRST, ahead
    // of the bulk ride/bike sync below. Two reasons: these are explicit
    // rider-initiated actions ("end this ride", "share this ride") rather than
    // background bookkeeping, and the bulk pass can be slow enough on a
    // freshly-restored connection that a share would otherwise sit behind it.
    // Failures inside drain() are recorded per-entry and never thrown, so this
    // cannot abort the sync that follows.
    await _outbox.drain();

    try {
      final uid = _auth.currentUser!.uid;
      final db = await DatabaseHelper.instance.database;

      // Pull down anything that exists in the cloud but not locally yet —
      // the case an upload-only sync misses entirely (new device, fresh
      // install, reinstall). Runs before the upload pass below so a bike
      // just pulled down can't immediately re-upload as if it were a local
      // edit. See CloudRepository.downloadBikes's doc comment.
      final pulledBikes = await _cloudRepository.downloadBikes(uid);
      await _cloudRepository.downloadMaintenance(uid);
      final pulledRides = await _cloudRepository.downloadRides(uid);
      if (pulledBikes) _ref?.invalidate(garageProvider);
      // Rides that just landed in the local table are invisible until the
      // providers that read that table are rebuilt. riderStatsProvider watches
      // only currentUserProvider and garageProvider, so on a device whose
      // bikes were already local (pulledBikes == false) *nothing* re-read the
      // rides table after a download — the stat strip kept rendering whatever
      // it computed at launch, before this download finished, until the app
      // was restarted. That is the "phone says 43 rides / 119 km, second
      // device says 20 / 26" report: both devices held identical rows, the
      // second one was just showing a pre-download snapshot of them
      // (docs/Issues.md §28). Invalidate on the download's own return value
      // rather than piggybacking on pulledBikes, which is false in exactly
      // the case that matters.
      if (pulledRides) {
        _ref?.invalidate(riderStatsProvider);
        _ref?.invalidate(rideHistoryProvider);
      }

      // Fetch unsynced rides. Goes through the DAO rather than querying
      // `synced = 0` directly: getUnsynced() also filters `status =
      // 'completed'`, and skipping it meant in-progress and abandoned rides
      // were uploaded too. Six zero-distance `active` rows had already
      // reached Firestore this way and been pulled down onto every other
      // device — harmless to the totals (the stats query filters on
      // completed) but pure garbage in the cloud, and a ride still being
      // recorded would sync a half-written row.
      //
      // docs/Issues.md §33.1: scoped to `uid` (the CURRENTLY signed-in
      // rider), same as the bikes/maintenance queries below. Without this, a
      // rider who recorded offline and signed out before it synced would
      // have their still-unsynced rows uploaded under whichever account
      // signs in next on this device — a real cross-account data leak, not
      // just a UX glitch. Rows belonging to a different `user_id` are simply
      // left alone; they sync normally once that rider signs back in here.
      final unsyncedRides = await RideDao().getUnsynced(uid);

      // Fetch unsynced bikes — scoped to `uid` for the same reason.
      final unsyncedBikes = await db.query(
        'bikes',
        where: 'synced = ? AND user_id = ?',
        whereArgs: [0, uid],
      );

      // Fetch unsynced maintenance logs. `maintenance_logs` has no `user_id`
      // column of its own — ownership is via `bike_id` — so scoping to `uid`
      // means joining through `bikes`, same reasoning as above.
      final unsyncedMaintenance = await db.rawQuery('''
        SELECT maintenance_logs.* FROM maintenance_logs
        INNER JOIN bikes ON bikes.id = maintenance_logs.bike_id
        WHERE maintenance_logs.synced = 0 AND bikes.user_id = ?
      ''', [uid]);

      // Push deletions BEFORE uploads. A bike deleted locally still has its
      // rides in the local DB removed, but the remote copies linger — and the
      // download half of this sync would happily pull them back. Removing
      // them first means one sync cycle fully settles a deletion instead of
      // fighting itself.
      for (final bikeId in await BikeDao().pendingRemoteDeletions()) {
        try {
          await _cloudRepository.deleteBikeRemote(uid, bikeId);
          await BikeDao().markDeletionSynced(bikeId);
        } catch (e) {
          // Offline or permission hiccup — leave the tombstone unsynced and
          // retry next cycle. The local tombstone keeps the bike deleted in
          // the meantime, so the rider never sees it come back.
          debugPrint('[SyncManager] remote bike delete failed for $bikeId: $e');
        }
      }

      // Upload to Firestore
      if (unsyncedRides.isNotEmpty) {
        await _cloudRepository.uploadRides(uid, unsyncedRides);

        // Then each ride's GPS trail, strictly after the ride doc exists so a
        // track can never point at a missing parent. A trail failure is
        // logged and skipped rather than aborting the whole sync — the ride
        // metadata is already safely up, and losing a polyline is far less
        // bad than leaving the rest of the queue unsynced.
        for (final ride in unsyncedRides) {
          final rideId = ride['id'] as String?;
          if (rideId == null) continue;
          try {
            await _cloudRepository.uploadRideTrack(uid, rideId);
          } catch (e) {
            debugPrint('[SyncManager] track upload failed for $rideId: $e');
          }
        }
      }

      if (unsyncedBikes.isNotEmpty) {
        await _cloudRepository.uploadBikes(uid, unsyncedBikes);
      }

      if (unsyncedMaintenance.isNotEmpty) {
        await _cloudRepository.uploadMaintenance(uid, unsyncedMaintenance);
      }

      _status = SyncStatus.success;
      _consecutiveFailures = 0;
    } catch (e, stack) {
      _status = SyncStatus.failure;
      _consecutiveFailures++;
      // Was a bare print() with no stack and no tag, which is why the sync
      // gap above took a database dump to diagnose rather than a glance at
      // the console. Everything reachable from here is now per-item
      // fault-isolated (see CloudRepository), so an exception arriving at
      // this catch means the cycle itself broke, not one bad row.
      debugPrint('[SyncManager] sync cycle failed: $e\n$stack');
    } finally {
      _isSyncing = false;
      _notifyListeners();
      _scheduleNextAutoSync();
    }
  }

  /// Manual sync trigger
  Future<void> sync() => _performSync();

  /// Cleanup resources
  void dispose() {
    stopAutoSync();
    _connectivitySubscription.cancel();
  }
}

/// Riverpod provider for SyncManager
final syncManagerProvider = Provider<SyncManager>((ref) {
  final syncManager = SyncManager(ref);
  ref.onDispose(() => syncManager.dispose());
  return syncManager;
});

/// Riverpod provider for sync status
final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  final syncManager = ref.watch(syncManagerProvider);
  return SyncStatusNotifier(syncManager);
});

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  final SyncManager _syncManager;

  SyncStatusNotifier(this._syncManager) : super(SyncStatus.idle) {
    _syncManager.addListener(_onSyncStatusChanged);
  }

  void _onSyncStatusChanged() {
    state = _syncManager.status;
  }

  @override
  void dispose() {
    _syncManager.removeListener(_onSyncStatusChanged);
    super.dispose();
  }
}

/// Riverpod provider for sync is busy
final isSyncingProvider = StateNotifierProvider<IsSyncingNotifier, bool>((ref) {
  final syncManager = ref.watch(syncManagerProvider);
  return IsSyncingNotifier(syncManager);
});

class IsSyncingNotifier extends StateNotifier<bool> {
  final SyncManager _syncManager;

  IsSyncingNotifier(this._syncManager) : super(false) {
    _syncManager.addListener(_onSyncStateChanged);
  }

  void _onSyncStateChanged() {
    state = _syncManager.isSyncing;
  }

  @override
  void dispose() {
    _syncManager.removeListener(_onSyncStateChanged);
    super.dispose();
  }
}
