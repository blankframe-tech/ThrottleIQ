import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show VoidCallback, debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/daos/bike_dao.dart';
import '../database/daos/maintenance_dao.dart';
import '../database/daos/ride_dao.dart';
import '../../features/garage/presentation/providers/garage_provider.dart';
import '../../features/maintenance/presentation/providers/maintenance_provider.dart';
import '../../features/ride/presentation/providers/ride_recording_provider.dart';
import '../../features/stats/presentation/providers/rider_stats_provider.dart';
import '../database/database_helper.dart';
import 'cloud_repository.dart';
import 'maintenance_settings_sync.dart';
import 'outbox_service.dart';
import 'pull_watermark.dart';

/// Represents the sync status of the app
enum SyncStatus { idle, syncing, success, failure }

/// Manages automatic sync of local data to Firestore
class SyncManager {
  // issues §62.13: `outbox` is always passed explicitly in
  // production (see the `syncManagerProvider` below) — this default only
  // matters for a bare `SyncManager()`/`SyncManager(ref)` construction
  // (ad-hoc tests). It used to fall back to a static `OutboxService.instance`
  // singleton, a second, never-drained OutboxService with its own DAO and
  // its own `_changes` StreamController that's never disposed — a latent
  // trap for any future caller that hit this path. A fresh instance per
  // construction is no worse for the (currently nonexistent) callers of the
  // bare constructor and removes the trap entirely.
  SyncManager([this._ref, OutboxService? outbox])
      : _outbox = outbox ?? OutboxService() {
    _initConnectivityListener();
    _initAuthListener();
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
  StreamSubscription<User?>? _authSubscription;
  String? _lastUid;

  /// When the last sync pass started — the connectivity throttle's clock.
  DateTime? _lastSyncStartedAt;
  Timer? _connectivityTimer;

  /// Minimum spacing between connectivity-triggered syncs (§90.C7). A
  /// flapping connection (lift, tunnel, weak cell edge) used to fire a full
  /// sync on every transition.
  static const connectivityThrottle = Duration(seconds: 30);

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

  /// Any transport other than `none` can carry traffic. Checking only
  /// mobile/wifi treated a rider on ethernet or a VPN-only result as offline
  /// forever: no sync, and every cycle counted as a failure.
  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Initialize connectivity listener
  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (_hasNetwork(results)) {
        // Internet is back - reset failure counter and sync, at most once
        // per [connectivityThrottle]: immediately if the last pass was long
        // enough ago, otherwise once the window has passed.
        _consecutiveFailures = 0;
        final delay = connectivitySyncDelay(
          lastSyncStartedAt: _lastSyncStartedAt,
          now: DateTime.now(),
        );
        _connectivityTimer?.cancel();
        if (delay == Duration.zero) {
          _performSync();
        } else {
          _connectivityTimer = Timer(delay, _performSync);
        }
      }
    });
  }

  /// How long a connectivity-triggered sync should wait (§90.C7): zero if
  /// the last pass started at least [window] ago, otherwise the remainder.
  @visibleForTesting
  static Duration connectivitySyncDelay({
    required DateTime? lastSyncStartedAt,
    required DateTime now,
    Duration window = connectivityThrottle,
  }) {
    if (lastSyncStartedAt == null) return Duration.zero;
    final since = now.difference(lastSyncStartedAt);
    if (since >= window || since.isNegative) return Duration.zero;
    return window - since;
  }

  /// "Full pull once per sign-in" (§90.C7): signing out forgets that
  /// rider's pull marks, so their next sign-in starts with a full pull.
  void _initAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      final previous = _lastUid;
      _lastUid = user?.uid;
      if (previous != null && previous != user?.uid) {
        unawaited(PullWatermark.clear(previous));
      }
    });
  }

  /// Whether a ride is being recorded (or sits paused). Downloads are skipped
  /// meanwhile (§90.C7): they compete with the recorder for the main isolate
  /// and the radio, and nothing in them is needed mid-ride.
  bool get _isRecording {
    final status = _ref?.read(rideRecordingProvider).status;
    return status == RecordingStatus.starting ||
        status == RecordingStatus.active ||
        status == RecordingStatus.paused;
  }

  /// One incremental-or-full download of [collection] — see [PullWatermark].
  Future<bool> _pull(
    String uid,
    String collection,
    Future<bool> Function() hasLocalRows,
    Future<PullResult> Function({DateTime? since}) download,
  ) async {
    final mark = await PullWatermark.read(uid, collection);
    final since = PullWatermark.queryFloor(
      watermark: mark,
      hasLocalRows: mark == null ? false : await hasLocalRows(),
    );
    final result = await download(since: since);
    await PullWatermark.write(
      uid,
      collection,
      PullWatermark.advance(
        current: since == null ? null : mark,
        seen: result.maxSyncedAt,
        wasFullPull: since == null,
      ),
    );
    return result.pulledAny;
  }

  /// One full maintenance pull after upgrading to schema v20. Builds before
  /// v20 skipped visit logs they couldn't store but still moved their pull
  /// mark past them, so those logs would never arrive otherwise (§95).
  Future<void> _resetMaintenanceMarkOnceForV20(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flag = 'maintenance_pull_reset_v20_$uid';
      if (prefs.getBool(flag) == true) return;
      await prefs.remove(PullWatermark.key(uid, 'maintenance'));
      await prefs.setBool(flag, true);
    } catch (e) {
      debugPrint('[SyncManager] maintenance mark reset skipped: $e');
    }
  }

  static Future<bool> _hasRows(String sql, List<Object?> args) async {
    final db = await DatabaseHelper.instance.database;
    return (await db.rawQuery(sql, args)).isNotEmpty;
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

    // Claimed BEFORE the first await. Set after the connectivity check (as it
    // used to be), two triggers landing together — startAutoSync() and the
    // connectivity listener's initial event, say — both passed the guard
    // above and ran two full sync passes concurrently.
    _isSyncing = true;
    _lastSyncStartedAt = DateTime.now();
    _connectivityTimer?.cancel();

    // Check connectivity first
    final connectivityResult = await _connectivity.checkConnectivity();

    if (!_hasNetwork(connectivityResult)) {
      _isSyncing = false;
      _status = SyncStatus.failure;
      _consecutiveFailures++;
      _notifyListeners();
      _scheduleNextAutoSync();
      return;
    }

    _status = SyncStatus.syncing;
    _notifyListeners();

    // Anything the rider already committed to while offline goes FIRST, ahead
    // of the bulk ride/bike sync below. Two reasons: these are explicit
    // rider-initiated actions ("end this ride", "share this ride") rather than
    // background bookkeeping, and the bulk pass can be slow enough on a
    // freshly-restored connection that a share would otherwise sit behind it.
    // Failures inside drain() are recorded per-entry and never thrown, so this
    // cannot abort the sync that follows.
    try {
      // Inside the try so an unexpected throw (e.g. the outbox table itself
      // failing to open) still reaches the `finally` below. Outside it, the
      // throw escaped with `_isSyncing` stuck at true, and every later
      // `_performSync` returned immediately for the rest of the session.
      await _outbox.drain();

      // issues §62.13/14: `_auth.currentUser` was checked once at
      // entry (line ~121) then force-unwrapped here, two `await`s later (the
      // connectivity check, and `_outbox.drain()` above). A rider signing
      // out in that window used to throw here, land in the generic `catch`
      // below, and get recorded as a sync *failure* (incrementing
      // `_consecutiveFailures` and scheduling backoff) — the correct
      // behavior is "skip silently, signed out," not a failed sync.
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _status = SyncStatus.idle;
        return;
      }
      final uid = currentUser.uid;
      final db = await DatabaseHelper.instance.database;

      // Pull down anything that exists in the cloud but not locally yet —
      // the case an upload-only sync misses entirely (new device, fresh
      // install, reinstall). Runs before the upload pass below so a bike
      // just pulled down can't immediately re-upload as if it were a local
      // edit. See CloudRepository.downloadBikes's doc comment.
      //
      // Incremental after the first pull since sign-in, and skipped while a
      // ride is being recorded — §90.C7.
      final skipDownloads = _isRecording;
      var pulledBikes = false;
      var pulledRides = false;
      if (!skipDownloads) {
        pulledBikes = await _pull(
          uid,
          'bikes',
          () => _hasRows('SELECT 1 FROM bikes WHERE user_id = ? LIMIT 1', [uid]),
          ({DateTime? since}) =>
              _cloudRepository.downloadBikes(uid, since: since),
        );
        await _resetMaintenanceMarkOnceForV20(uid);
        await _pull(
          uid,
          'maintenance',
          () => _hasRows('''
            SELECT 1 FROM maintenance_logs
            INNER JOIN bikes ON bikes.id = maintenance_logs.bike_id
            WHERE bikes.user_id = ? LIMIT 1
          ''', [uid]),
          ({DateTime? since}) =>
              _cloudRepository.downloadMaintenance(uid, since: since),
        );
        // After downloadBikes: a settings row needs its bike to exist.
        if (await _cloudRepository.downloadMaintenanceSettings(uid)) {
          _ref?.invalidate(maintenanceConfigProvider);
          _ref?.invalidate(isMaintenanceCustomizedProvider);
          _ref?.invalidate(bikeRunningCostProvider);
          _ref?.invalidate(maintenanceProfileProvider);
          _ref?.invalidate(paperworkProvider);
        }
      }
      await _backfillMaintenanceSettings(uid);
      if (!skipDownloads) {
        pulledRides = await _pull(
          uid,
          'rides',
          () => _hasRows('SELECT 1 FROM rides WHERE user_id = ? LIMIT 1', [uid]),
          ({DateTime? since}) =>
              _cloudRepository.downloadRides(uid, since: since),
        );
      }
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
      // (issues §28). Invalidate on the download's own return value
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
      // issues §33.1: scoped to `uid` (the CURRENTLY signed-in
      // rider), same as the bikes/maintenance queries below. Without this, a
      // rider who recorded offline and signed out before it synced would
      // have their still-unsynced rows uploaded under whichever account
      // signs in next on this device — a real cross-account data leak, not
      // just a UX glitch. Rows belonging to a different `user_id` are simply
      // left alone; they sync normally once that rider signs back in here.
      final unsyncedRides = await RideDao().getUnsynced(uid);

      // Fetch unsynced bikes — scoped to `uid` for the same reason.
      // Also include any bikes whose photos are still stored as local files so
      // their images get uploaded to Cloudinary.
      final unsyncedBikes = (await db.query(
        'bikes',
        where: 'synced = ? AND user_id = ?',
        whereArgs: [0, uid],
      )).toList();

      final existingBikeIds =
          unsyncedBikes.map((b) => b['id'] as String).toSet();
      final bikesWithLocalImages = await BikeDao().getBikesWithLocalImages(uid);
      for (final bike in bikesWithLocalImages) {
        if (!existingBikeIds.contains(bike['id'] as String)) {
          unsyncedBikes.add(bike);
        }
      }

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

      // Same for rides deleted on this device (§90.C10) — a discarded crash
      // ride, uploaded the moment crash detection fired, would otherwise
      // sit in the cloud and come back on every new device.
      for (final rideId in await RideDao().pendingRemoteDeletions(uid)) {
        try {
          await _cloudRepository.deleteRideRemote(uid, rideId);
          await RideDao().markDeletionSynced(rideId);
        } catch (e) {
          debugPrint('[SyncManager] remote ride delete failed for $rideId: $e');
        }
      }

      // And maintenance logs deleted here (§94.2): without this the
      // download above restored every deleted log on the next full pull.
      for (final logId in await MaintenanceDao().pendingRemoteDeletions(uid)) {
        try {
          await _cloudRepository.deleteMaintenanceRemote(uid, logId);
          await MaintenanceDao().markDeletionSynced(logId);
        } catch (e) {
          debugPrint(
              '[SyncManager] remote maintenance delete failed for $logId: $e');
        }
      }

      // Upload to Firestore
      if (unsyncedRides.isNotEmpty) {
        await _cloudRepository.uploadRides(uid, unsyncedRides);
      }

      // Then GPS trails, strictly after the ride docs exist so a track can
      // never point at a missing parent. Driven by `track_synced`, not by
      // `unsyncedRides`: looping over the rides just uploaded meant a trail
      // that failed once was never tried again, because by the next cycle
      // its ride was already `synced = 1` (grill §1.3.2).
      await syncPendingTracks(uid, RideDao(), _cloudRepository.uploadRideTrack);

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

  /// One-time upload of maintenance settings saved before they synced
  /// (issues §88.2) — until then, only a fresh save queued an upload, so a
  /// rider who set everything up once and never touched it again would
  /// still lose it on reinstall. Runs after the settings download, so on a
  /// new device it only ever re-uploads what was just restored. The flag is
  /// set only once every bike is queued; a failure retries next cycle.
  Future<void> _backfillMaintenanceSettings(String uid) async {
    final key = 'maintenance_settings_backfilled_$uid';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(key) ?? false) return;
      for (final bikeId in await MaintenanceSettingsSync.bikesWithSettings(uid)) {
        await _outbox.enqueueMaintenanceSettings(
          uid: uid,
          bikeId: bikeId,
          attemptNow: false,
        );
      }
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('[SyncManager] maintenance settings backfill skipped: $e');
    }
  }

  /// Manual sync trigger
  Future<void> sync() => _performSync();

  /// Uploads the GPS trail of every ride whose metadata is synced but whose
  /// trail isn't, marking each one `track_synced` only once its upload
  /// returns. A failure is logged and left at 0 for the next cycle rather
  /// than aborting the sync — the ride metadata is already safely up, and one
  /// bad trail must not hold the others back. Returns how many uploaded.
  @visibleForTesting
  static Future<int> syncPendingTracks(
    String uid,
    RideDao rideDao,
    Future<void> Function(String uid, String rideId) uploadTrack,
  ) async {
    var uploaded = 0;
    for (final ride in await rideDao.getTrackUnsynced(uid)) {
      final rideId = ride['id'] as String;
      try {
        await uploadTrack(uid, rideId);
        await rideDao.markTrackSynced(rideId);
        uploaded++;
      } catch (e) {
        debugPrint('[SyncManager] track upload failed for $rideId: $e');
      }
    }
    return uploaded;
  }

  /// Cleanup resources
  void dispose() {
    stopAutoSync();
    _connectivityTimer?.cancel();
    _connectivitySubscription.cancel();
    _authSubscription?.cancel();
  }
}

/// Riverpod provider for SyncManager
final syncManagerProvider = Provider<SyncManager>((ref) {
  final outbox = ref.watch(outboxServiceProvider);
  final syncManager = SyncManager(ref, outbox);
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
