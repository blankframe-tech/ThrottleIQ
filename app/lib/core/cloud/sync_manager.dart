import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/garage/presentation/providers/garage_provider.dart';
import '../database/database_helper.dart';
import 'cloud_repository.dart';

/// Represents the sync status of the app
enum SyncStatus { idle, syncing, success, failure }

/// Manages automatic sync of local data to Firestore
class SyncManager {
  SyncManager([this._ref]) {
    _initConnectivityListener();
  }

  /// Nullable: only needed to invalidate providers after a download pulls
  /// in new rows (see _performSync). Tests/callers that don't care about
  /// live UI refresh can omit it.
  final Ref? _ref;

  final CloudRepository _cloudRepository = CloudRepository();
  final Connectivity _connectivity = Connectivity();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _autoSyncTimer;
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
        // Internet is back - try to sync
        _performSync();
      }
    });
  }

  /// Start automatic sync with 5-minute interval
  void startAutoSync() {
    if (_autoSyncTimer != null) return; // Already running

    // Perform initial sync
    _performSync();

    // Schedule periodic sync every 5 minutes
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _performSync();
    });
  }

  /// Stop automatic sync
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
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
      _notifyListeners();
      return;
    }

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _notifyListeners();

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
      await _cloudRepository.downloadRides(uid);
      if (pulledBikes) _ref?.invalidate(garageProvider);

      // Fetch unsynced rides
      final unsyncedRides = await db.query(
        'rides',
        where: 'synced = ?',
        whereArgs: [0],
      );

      // Fetch unsynced bikes
      final unsyncedBikes = await db.query(
        'bikes',
        where: 'synced = ?',
        whereArgs: [0],
      );

      // Fetch unsynced maintenance logs
      final unsyncedMaintenance = await db.query(
        'maintenance_logs',
        where: 'synced = ?',
        whereArgs: [0],
      );

      // Upload to Firestore
      if (unsyncedRides.isNotEmpty) {
        await _cloudRepository.uploadRides(uid, unsyncedRides);
      }

      if (unsyncedBikes.isNotEmpty) {
        await _cloudRepository.uploadBikes(uid, unsyncedBikes);
      }

      if (unsyncedMaintenance.isNotEmpty) {
        await _cloudRepository.uploadMaintenance(uid, unsyncedMaintenance);
      }

      _status = SyncStatus.success;
    } catch (e) {
      _status = SyncStatus.failure;
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
      _notifyListeners();
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
