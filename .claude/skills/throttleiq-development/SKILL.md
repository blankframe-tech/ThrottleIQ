---
name: throttleiq-development
description: ThrottleIQ-specific development patterns for motorcycle tracking, real-time GPS/sensor integration, offline-first architecture, and background activity recognition. Riverpod state, Firebase persistence, Firestore sync, battery-efficient location streaming.
license: MIT
metadata:
  version: "1.0.0"
  domain: mobile-backend
  triggers: ThrottleIQ, tracking, GPS, sensors, background-service, offline-first, Riverpod, GoRouter, Firebase, Firestore
  role: specialist
  scope: implementation
  output-format: code
  related-skills: flutter-expert, dart-flutter-patterns, mobile-design
---

# ThrottleIQ Development Guide

Production patterns for motorcycle tracking platform combining real-time GPS, sensor fusion, offline-first persistence, and background activity recognition.

## When to Use This Skill

- Building ride recording, auto-detection, or tracking features
- Integrating Firestore for ride sync or real-time data
- Optimizing battery consumption in background tracking
- Implementing offline-first data flow (SQLite → Firestore)
- Designing state transitions for ride lifecycle
- Managing concurrent Riverpod streams (location, sensors, DB)

## Core Architecture

```
┌─────────────────────────────────────────────────────┐
│                    UI Layer (Riverpod Consumers)    │
│  (Maps, feed, stats - watched providers)            │
└────────────────┬────────────────────────────────────┘
                 │ watches
┌────────────────▼────────────────────────────────────┐
│       Riverpod Providers (State Management)         │
│  ├─ rideRecordingProvider (current ride)            │
│  ├─ sensorStreamProvider (debounced sensors)        │
│  ├─ locationStreamProvider (GPS + accuracy tiers)   │
│  ├─ offlineQueueProvider (Firestore sync queue)     │
│  └─ rideHistoryProvider (SQLite → paginated)        │
└────────────────┬────────────────────────────────────┘
                 │ reads/mutates
┌────────────────▼────────────────────────────────────┐
│         Service Layer (Business Logic)              │
│  ├─ RideRecordingService (coordinates tracking)     │
│  ├─ SensorFusionService (dedup + batch fixes)       │
│  ├─ LocationService (accuracy-adaptive sampling)    │
│  ├─ OfflineSyncService (queue mgmt, retry logic)    │
│  └─ NotificationService (ride alerts + summaries)   │
└────────────────┬────────────────────────────────────┘
                 │ reads
┌────────────────▼────────────────────────────────────┐
│          Data Layer (Persistence)                   │
│  ├─ SQLite (local rides, waypoints, events)         │
│  ├─ Firestore (cloud rides, real-time synced data)  │
│  ├─ SharedPreferences (app state, settings)         │
│  └─ Secure Storage (tokens, sensitive config)       │
└─────────────────────────────────────────────────────┘
```

## Riverpod Provider Patterns for ThrottleIQ

### 1. Current Ride Provider (StateNotifier)

```dart
// Sealed state for ride lifecycle
sealed class RideState {}

final class RideIdle extends RideState {}

final class RideRecording extends RideState {
  final String rideId;
  final DateTime startedAt;
  final int waypointCount;
  
  RideRecording({
    required this.rideId,
    required this.startedAt,
    this.waypointCount = 0,
  });
}

final class RideUploadingToFirestore extends RideState {
  final String rideId;
  final double uploadProgress;
  
  RideUploadingToFirestore({
    required this.rideId,
    required this.uploadProgress,
  });
}

final class RideError extends RideState {
  final String message;
  final String? rideId;
  
  RideError(this.message, {this.rideId});
}

// Notifier manages ride lifecycle
@riverpod
class RideRecordingNotifier extends _$RideRecordingNotifier {
  late final RideRepository _rideRepo;
  late final FirestoreService _firestore;
  
  @override
  RideState build() {
    _rideRepo = ref.watch(rideRepositoryProvider);
    _firestore = ref.watch(firestoreServiceProvider);
    return const RideIdle();
  }
  
  // Start manual recording
  Future<void> startRide() async {
    try {
      final rideId = const Uuid().v4();
      final ride = Ride(
        id: rideId,
        startedAt: DateTime.now(),
        waypoints: [],
        detectionMethod: DetectionMethod.manual,
      );
      
      // Save to SQLite first (offline-safe)
      await _rideRepo.insertRide(ride);
      state = RideRecording(rideId: rideId, startedAt: ride.startedAt);
      
      // Start location/sensor streams
      ref.read(locationStreamProvider.notifier).startTracking(rideId);
      ref.read(sensorStreamProvider.notifier).startTracking(rideId);
    } catch (e) {
      state = RideError('Failed to start ride: $e');
    }
  }
  
  // End ride and queue for Firestore sync
  Future<void> endRide() async {
    if (state is! RideRecording) return;
    
    final rideId = (state as RideRecording).rideId;
    state = RideUploadingToFirestore(rideId: rideId, uploadProgress: 0);
    
    try {
      // Stop streams immediately
      ref.read(locationStreamProvider.notifier).stopTracking();
      ref.read(sensorStreamProvider.notifier).stopTracking();
      
      // Queue for async upload; don't block UI
      ref.read(offlineSyncQueueProvider.notifier).enqueueRide(rideId);
      state = const RideIdle();
    } catch (e) {
      state = RideError('Failed to end ride: $e', rideId: rideId);
    }
  }
}

final rideRecordingProvider = 
    StateNotifierProvider<RideRecordingNotifier, RideState>(
  (ref) => RideRecordingNotifier(),
);
```

### 2. Location Stream (Auto-Dispose + Sensor Fusion)

```dart
// Accuracy-adaptive location updates: high when moving fast, low when slow
@riverpod
Stream<LocationFix> locationStream(Ref ref) {
  final rideId = ref.watch(rideRecordingProvider).maybeWhen(
    recording: (id, _, __) => id,
    orElse: () => null,
  );
  
  if (rideId == null) return const Stream.empty();
  
  return Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, // 5m to avoid noise
      timeLimit: const Duration(seconds: 30), // Fallback every 30s
    ),
  )
    .throttleTime(
      const Duration(seconds: 2), // Don't write DB more than every 2s
      trailing: true,
    )
    .asyncMap((position) async {
      // Fuse with accelerometer to filter stationary noise
      final accel = await _getAccelerometerMagnitude();
      if (accel < 0.5) return null; // Stationary jitter
      
      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        speed: position.speed,
      );
    })
    .whereType<LocationFix>()
    .doOnData((fix) async {
      // Batch write to SQLite (not every fix)
      await ref.read(locationBatchBufferProvider.notifier).add(fix, rideId);
    });
}

final locationBatchBufferProvider = 
    StateNotifierProvider.family<LocationBatchNotifier, List<LocationFix>, String>(
  (ref, rideId) => LocationBatchNotifier(rideId: rideId),
);
```

### 3. Offline Sync Queue (Ensures No Data Loss)

```dart
// Queue Firestore writes for rides recorded offline
@riverpod
class OfflineSyncQueueNotifier extends _$OfflineSyncQueueNotifier {
  late final RideRepository _localDb;
  late final FirestoreService _cloud;
  
  @override
  List<PendingSync> build() {
    _localDb = ref.watch(rideRepositoryProvider);
    _cloud = ref.watch(firestoreServiceProvider);
    
    // Auto-sync on app startup
    _autoSync();
    
    return [];
  }
  
  void enqueueRide(String rideId) {
    state = [...state, PendingSync(id: rideId, type: SyncType.rideUpload)];
    _autoSync(); // Kick off sync loop
  }
  
  Future<void> _autoSync() async {
    for (final pending in state) {
      try {
        // Poll every 2s if network is available
        while (!await _isConnected()) {
          await Future.delayed(const Duration(seconds: 2));
        }
        
        // Read from SQLite, push to Firestore
        final ride = await _localDb.getRide(pending.id);
        if (ride == null) continue;
        
        await _cloud.uploadRide(ride);
        state = state.where((s) => s.id != pending.id).toList();
      } on FirebaseException catch (e) {
        // Exponential backoff on conflict; skip other errors
        if (e.code == 'permission-denied') {
          await Future.delayed(Duration(seconds: 2 << (pending.retryCount++)));
        }
      }
    }
  }
  
  Future<bool> _isConnected() => Connectivity().checkConnectivity()
      .then((result) => result != ConnectivityResult.none);
}

final offlineSyncQueueProvider = 
    StateNotifierProvider<OfflineSyncQueueNotifier, List<PendingSync>>(
  (ref) => OfflineSyncQueueNotifier(),
);
```

## Battery & Performance Optimization

### GPS Power Tiers

```dart
// Adaptive location sampling: high accuracy when moving, low when stationary
enum LocationPowerTier {
  highPerformance, // 1m accuracy, 1Hz, for high-speed detection
  balanced,        // 10m accuracy, 0.5Hz, normal recording
  lowPower,        // 100m accuracy, 0.1Hz, fallback when battery critical
}

Future<LocationPowerTier> _selectTier(Battery battery, double speed) async {
  final level = await battery.batteryLevel;
  if (level < 20) return LocationPowerTier.lowPower;
  if (speed > 30) return LocationPowerTier.highPerformance; // mph
  return LocationPowerTier.balanced;
}
```

### Sensor Debouncing (Android/iOS Activity Recognition)

```dart
// Activity recognition fires every ~10s; coalesce into batches
@riverpod
Stream<ActivityRecognitionEvent> activityStream(Ref ref) {
  return FlutterActivityRecognition.activityUpdates.stream
    .throttleTime(const Duration(seconds: 5), trailing: true)
    .distinct((prev, curr) => prev.type == curr.type) // Only on type change
    .doOnData((event) {
      // Trigger ride auto-start/stop logic
      ref.read(autoTrackingServiceProvider).onActivityChange(event);
    });
}
```

## Firestore Query Patterns

### Ride History with Pagination

```dart
// Avoid loading full history; paginate by date range
Future<List<Ride>> getRidesPaginated(
  String userId,
  DateTime startDate,
  int pageSize,
  DocumentSnapshot? lastDoc,
) async {
  var query = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('rides')
      .where('startedAt', isGreaterThanOrEqualTo: startDate)
      .orderBy('startedAt', descending: true)
      .limit(pageSize + 1); // +1 to detect hasMore
  
  if (lastDoc != null) {
    query = query.startAfterDocument(lastDoc);
  }
  
  return query.get()
    .then((snap) => snap.docs
        .map((doc) => Ride.fromFirestore(doc))
        .toList());
}

// Riverpod provider with cursor management
@riverpod
class RideHistoryNotifier extends _$RideHistoryNotifier {
  @override
  Future<RideHistoryPage> build() async {
    final userId = ref.watch(currentUserProvider).id;
    return getRidesPaginated(userId, DateTime.now().subtract(Duration(days: 30)), 20);
  }
  
  Future<void> loadNextPage() async {
    final current = await future;
    final userId = ref.watch(currentUserProvider).id;
    final next = await getRidesPaginated(
      userId,
      DateTime.now().subtract(Duration(days: 30)),
      20,
      current.lastDoc,
    );
    state = AsyncValue.data(RideHistoryPage(
      rides: [...current.rides, ...next.rides],
      lastDoc: next.lastDoc,
    ));
  }
}
```

## Background Service Lifecycle (Android/iOS)

```dart
// foreground_task keeps native activity-recognition alive across app restarts
@pragma('vm:entry-point')
void taskHandler(Task task) {
  final eventChannel = EventChannel('throttleiq.background/activity');
  
  FlutterActivityRecognition.activityUpdates.stream.listen((event) {
    // Post activity change to Dart
    eventChannel.invokeMethod('onActivityDetected', {
      'type': event.type,
      'confidence': event.confidence,
    });
  });
}

// In main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'throttleiq_tracking',
      channelName: 'ThrottleIQ Auto-Tracking',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: IosNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(Duration(seconds: 30)),
      autoRunOnBoot: true,
      allowWifiLock: true,
    ),
  );
  
  // Start background task
  if (!await FlutterForegroundTask.isRunningService) {
    await FlutterForegroundTask.startService(
      notificationTitle: 'ThrottleIQ Tracking',
      notificationText: 'Monitoring for rides...',
      callback: taskHandler,
    );
  }
  
  runApp(const App());
}
```

## Testing Patterns

### Unit Test: Offline Sync Retry Logic

```dart
test('offlineSyncQueue retries failed Firestore writes', () async {
  final mockDb = MockRideRepository();
  final mockFirestore = MockFirestoreService();
  final queue = OfflineSyncQueueNotifier();
  
  // First call fails, second succeeds
  mockFirestore.uploadRide.thenThrow(FirebaseException(
    plugin: 'cloud_firestore',
    code: 'network-error',
  )).thenReturn(Future.value());
  
  queue.enqueueRide('ride-1');
  await Future.delayed(Duration(seconds: 2));
  
  expect(queue.state.isEmpty, true); // Retried and succeeded
});
```

### Integration Test: Ride Recording → Firestore Sync

```dart
testWidgets('Manual ride records locally, syncs to Firestore offline', (tester) async {
  // Start with network disabled
  Connectivity.instance.setMockConnectivity(ConnectivityResult.none);
  
  await tester.pumpWidget(const App());
  await tester.tap(find.byIcon(Icons.play_arrow)); // Start ride
  await tester.pumpAndSettle();
  
  // Verify ride in SQLite
  final localRide = await rideDb.getRide(rideId);
  expect(localRide, isNotNull);
  
  // Re-enable network
  Connectivity.instance.setMockConnectivity(ConnectivityResult.mobile);
  await Future.delayed(Duration(seconds: 2)); // Sync kicks off
  
  // Verify ride in Firestore
  final cloudRide = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('rides')
      .doc(rideId)
      .get();
  expect(cloudRide.exists, true);
});
```

## Constraints & Must-Dos

### MUST DO
- Batch GPS writes to SQLite (don't write every fix)
- Validate Firestore writes are queued before stopping ride
- Guard against duplicate activity-recognition events (dedupe by timestamp)
- Use `const` on all static UI widgets to prevent re-render jank
- Test offline flow: record → kill network → restart app → verify sync
- Stop location/sensor streams immediately when ride ends (not on rebuild)

### MUST NOT DO
- Write every GPS fix to Firestore directly (kill write quota + latency)
- Block ride start/end on network availability
- Ignore `mounted` check after async operations in StatefulWidgets
- Hard-code location accuracy; always use adaptive tiers
- Forget to cancel StreamSubscriptions in `dispose()` (memory leak)
- Skip retry-with-backoff for Firestore conflict errors

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Ride uploads to Firestore then duplicate appears in SQLite | App crashed before deleting local copy after upload | Check `offlineSyncQueue` clears after Firestore writes succeed |
| Battery drains fast during manual recording | Location accuracy too high; GPS + screen both on | Use `LocationAccuracy.balanced` (10m) not `best` |
| Gaps in ride waypoints after network interruption | SQLite queue not persisted | Verify `waypointBatchBuffer` writes to DB on every batch flush |
| Auto-detection doesn't trigger after app force-quit | Foreground service stopped | Implement `onBoot` receiver; check Android manifest has `RECEIVE_BOOT_COMPLETED` |
| Activity-recognition fires constantly, app jank | Every activity event rebuilds UI | Use `throttleTime()` + distinct; watch provider, don't subscribe directly |

## References

- **Riverpod:** https://riverpod.dev/docs/essentials/side_effects
- **GoRouter:** https://pub.dev/packages/go_router
- **Firestore Offline Persistence:** https://firebase.google.com/docs/firestore/manage-data/enable-offline
- **Geolocator:** https://pub.dev/packages/geolocator
- **Flutter Activity Recognition:** https://pub.dev/packages/flutter_activity_recognition
- **Flutter Foreground Task:** https://pub.dev/packages/flutter_foreground_task
- **ThrottleIQ Docs:** See `/docs/HANDOFF_Document.md` for full architecture notes
