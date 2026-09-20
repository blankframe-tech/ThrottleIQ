# Issues Solved (from ANTIGRAVITY_GRILL)

## codebase.md
### 1.1 The 8g GPS Deceleration Paradox (Crash Detection is Dead Code)
* **Code Reference:** [`event_detector.dart:106-115`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/domain/calculators/event_detector.dart#L106-L115) & [`ride_recording_provider.dart:611-625`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/ride_recording_provider.dart#L611-L625)
* **The Claim:** ThrottleIQ detects violent vehicle crashes using a tri-factor rule: acceleration spike $>8g$ ($78.48\,\text{m/s}^2$), jerk spike $>10\,\text{m/s}^3$, and rapid deceleration to near-zero speed within 2 seconds.
* **The Reality:**
  - In [`ride_recording_provider.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/ride_recording_provider.dart#L611), `_detector.detect()` is **only called inside `_onPosition`**, which processes the **1 Hz GPS location stream**.
  - The `accel` parameter fed to `detect()` is computed by [`MotionCalculator`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/domain/calculators/motion_calculator.dart#L31) strictly from GPS fixes: $\Delta v / \Delta t$.
  - At a standard $1.0\text{ s}$ GPS fix rate, generating an acceleration magnitude $>78.48\,\text{m/s}^2$ ($8g$) requires the vehicle speed to drop by **at least $78.48\,\text{m/s}$—which is $282.5\,\text{km/h}$ ($175.5\,\text{mph}$)—in a single second**.
  - If a rider crashes into a vehicle or barrier at $80\,\text{km/h}$ ($22.2\,\text{m/s}$), the GPS deceleration over 1 second is at most $22.2\,\text{m/s}^2$ ($\approx 2.26g$), which **completely fails the $8g$ threshold**.
  - Meanwhile, the hardware IMU (accelerometer/gyroscope) running at 20–50 Hz—which *actually* registers the 15g–30g physical impact shock—is routed exclusively to [`SensorFusionCoordinator.onAccelEvent`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/helpers/sensor_fusion_coordinator.dart#L61-L113). There, it is low-pass filtered with $\alpha = 0.1$ and checked *only* for hard braking ($<-4.0\,\text{m/s}^2$) and rapid acceleration ($>+3.5\,\text{m/s}^2$). **The raw accelerometer impact spike is never passed to `EventDetector`!**
  - **The Smoking Gun:** The unit test [`crash_detector_test.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/test/calculators/crash_detector_test.dart#L47-L55) passes because the test author manually passed `accel: 90.0, jerk: 12.0` directly into `detector.detect()`. In the live app, this call site never receives IMU data. In production, **crash detection will never trigger at survivable road speeds.**

### 1.2 Moving Average Erases Jerk Spikes
* **Code Reference:** [`event_detector.dart:127-130`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/domain/calculators/event_detector.dart#L127-L130)
```dart
if (_highAccelStart != null) {
  _peakJerkInWindow = (_peakJerkInWindow == 0)
      ? jerk.abs()
      : (_peakJerkInWindow + jerk.abs()) / 2; // Moving avg
}
```
* **The Flaw:** `_peakJerkInWindow` tracks an exponential moving average with weight 0.5 rather than `math.max(_peakJerkInWindow, jerk.abs())`. If a crash registers an initial jerk spike of $14\,\text{m/s}^3$ followed by a settling sample of $5.5\,\text{m/s}^3$, `_peakJerkInWindow` immediately drops to $9.75\,\text{m/s}^3$. Because `_crashJerkThreshold` is $10.0\,\text{m/s}^3$, the detector concludes no jerk spike occurred and aborts the crash alert.

### 1.3 Event Counter Double-Counting
* **Code References:** [`sensor_fusion_coordinator.dart:101-105`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/helpers/sensor_fusion_coordinator.dart#L101-L105) & [`event_detector.dart:163-172`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/domain/calculators/event_detector.dart#L163-L172)
* **The Flaw:** When a hard brake occurs, `SensorFusionCoordinator.onAccelEvent` mutates `detector.hardBrakeCount++` directly on the IMU thread. Moments later, when the next GPS fix arrives, `_onPosition` calls `_detector.detect(accel: gpsAccel)`. If the GPS speed drop also exceeds $-4.0\,\text{m/s}^2$, `detect()` increments `hardBrakeCount++` a second time on the same instance. Ride analytics summaries systematically double-count aggressive riding metrics.

### 2.1 Emergency Escalation is a Mock on an Undeployable Tier
* **Code Reference:** [`functions/src/crash-notifications.ts:53-75, 165-175`](file:///Users/blackbird/Everything/dev/ThrottleIQ/functions/src/crash-notifications.ts#L53-L75)
* **The Flaw:**
  1. The app markets automated emergency contact dispatch via SMS/email.
  2. In Cloud Functions, `sendContactNotification` is hardcoded as:
     ```typescript
     // MOCK: In production, integrate with Twilio for SMS or SendGrid for email
     status: 'mock_not_sent'
     ```
  3. Escalation scheduling is a stubbed `console.log`:
     ```typescript
     function scheduleEscalation(uid, rideId, notificationId) {
       console.log(`Scheduled 15-min escalation check...`);
       // TODO: Implement via Cloud Tasks or Pub/Sub delayed task
     }
     ```
  4. Even if implemented, `throttleiqfb` is on the **Spark (free) tier**. Google Cloud enforces that Cloud Functions requires the Blaze (pay-as-you-go) tier (`artifactregistry.googleapis.com` is locked). **Not a single line of backend crash handling code has ever run or can run.**

### 2.2 Crashed Rides are Permanently Excluded from Cloud Backup
* **Code Reference:** [`ride_dao.dart:178-183`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/database/daos/ride_dao.dart#L178-L183) & [`ride_recording_provider.dart:993-996`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/ride_recording_provider.dart#L993-L996)
```dart
// ride_recording_provider.dart
await _rideDao.finalizeRide(state.ride!.id, {
  'status': 'crash',
  'end_time': DateTime.now().toIso8601String(),
});

// ride_dao.dart
Future<List<Map<String, dynamic>>> getUnsynced(String userId) async {
  return db.query('rides',
      where: 'user_id = ? AND synced = 0 AND status = ?',
      whereArgs: [userId, 'completed']);
}
```
* **The Flaw:** If a crash is flagged, the ride status is saved as `'crash'`. But `RideDao.getUnsynced()` **strictly queries `status = 'completed'`**. If the rider's phone is smashed or lost in an accident, the crash telemetry is never synced to the cloud.

### 2.3 SafeQR Medical Card Passcode Trap
* **Code Reference:** [`safe_qr_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/profile/presentation/screens/safe_qr_screen.dart)
* **The Flaw:** The SafeQR medical card (blood type, allergies, emergency contacts) is advertised as an on-device card for first responders. But it lives inside an authenticated screen within the application. When an accident occurs, the rider is typically incapacitated and the phone is locked. Paramedics cannot unlock the device or launch ThrottleIQ. Without Lock Screen widget or Apple/Google Wallet integration, this feature is unusable when needed most.

### 2.4 Android 14+ `USE_FULL_SCREEN_INTENT` Rejection
* **Code Reference:** [`AndroidManifest.xml:49`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/android/app/src/main/AndroidManifest.xml#L49)
* **The Flaw:** The app declares `USE_FULL_SCREEN_INTENT` for crash alert popups. As of Android 14 (API 34), Google Play restricts full-screen intents exclusively to calling and alarm apps unless an explicit Play Console policy declaration is granted. Without this, Play Store updates are rejected, or the OS silently revokes the capability at runtime, preventing the alert from appearing over the lock screen.

### 3.1 `downloadRideTrack` is Uncalled Dead Code (Blank Maps on Reinstall)
* **Code Reference:** [`cloud_repository.dart:417`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/cloud/cloud_repository.dart#L417) & [`ride_summary_screen.dart:56-65`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/screens/ride_summary_screen.dart#L56-L65)
* **The Flaw:**
  - `CloudRepository.downloadRideTrack(uid, rideId)` was written and documented with the comment:  
    *`Called when a ride's summary/share screen needs a polyline and the local DB has none`*
  - **This method is called zero times in the entire codebase.**
  - `RideSummaryScreen._loadPolyline` only queries local SQLite (`RidePointDao.getForRide`).
  - When a user signs in on a new device, `downloadRides` restores the ride metadata table, but **every past ride map is permanently blank**.

### 3.2 Sync Ordering Abandons Track Points on Network Drop
* **Code Reference:** [`sync_manager.dart:268-285`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/cloud/sync_manager.dart#L268-L285)
* **The Flaw:**
  ```dart
  await _cloudRepository.uploadRides(uid, unsyncedRides);
  for (final ride in unsyncedRides) {
    try {
      await _cloudRepository.uploadRideTrack(uid, rideId);
    } catch (e) { ... }
  }
  ```
  `uploadRides` sets `synced = 1` on the `rides` table in SQLite before track uploads commence. If `uploadRideTrack` fails or times out, the error is caught, but on the next sync cycle, `getUnsynced()` ignores the ride because `synced == 1`. The GPS track points are permanently stranded on the local phone and will never be uploaded.

### 3.3 Batch Size Hard Limits Cause Unhandled Deletion Failures
* **Code Reference:** [`cloud_repository.dart:48-62`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/cloud/cloud_repository.dart#L48-L62)
* **The Flaw:** `deleteBikeRemote` fetches all rides associated with a bike and deletes them in a single `_firestore.batch()`. Firestore batches have a hard ceiling of **500 operations**. If a rider has 500 or more rides on a bike, `batch.commit()` throws `IllegalArgumentException: A maximum of 500 writes are allowed in a single batch`, permanently preventing the bike from being deleted. Furthermore, the `track` subcollections under those rides are not deleted, leaving orphaned documents in Firestore.

### 4.1 PrivacyZoneClipper is a Geometric Illusion
* **Code Reference:** [`privacy_zone_clipper.dart:41-73`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/social/domain/utilities/privacy_zone_clipper.dart#L41-L73)
* **The Flaw:**
  - `_findClipIndex` walks along the polyline accumulating path distance until $\sum \text{segment} \ge 200\text{m}$.
  - If a rider warms up their engine in their driveway, idles at a curb, or circles an apartment garage, GPS drift accumulates $200\text{m}$ of path distance **while remaining within 10 meters of their front door**.
  - The clipper trims the stationary drift points and begins the public polyline directly outside their house.
  - A real privacy zone must clip points within a **$200\text{m}$ Euclidean radius circle** ($\text{haversine}(p_i, p_0) \le 200\text{m}$), not accumulated odometer distance.

### 4.2 Shared Device Multi-Tenant Contamination
* **Code References:** [`database_helper.dart:524-538`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/database/database_helper.dart#L524-L538) & [`auto_ride_reconciler_service.dart:65-76`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/data/repositories/auto_ride_reconciler_service.dart#L65-L76)
* **The Flaw:**
  - The `auto_detections` and `auto_fixes` SQLite tables contain no `user_id` column.
  - `DatabaseHelper.deleteUserData(userId)` intentionally does not clear these tables on account deletion/logout to avoid wiping in-flight queues.
  - If User A logs out and User B logs in on the same device, User A's un-reconciled trip chunks remain in SQLite.
  - When User B opens the app, `AutoRideReconcilerService` sweeps `pendingDetections()`, grabs User B's `uid`, and assigns User A's trip data to User B's profile, syncing it to User B's cloud Firestore.

### 4.3 Static Follower Snapshot in Audience Rules
* **Code References:** [`ride_share_repository.dart:73-77`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/social/data/repositories/ride_share_repository.dart#L73-L77) & [`firestore.rules:9-15`](file:///Users/blackbird/Everything/dev/ThrottleIQ/firestore.rules#L9-L15)
* **The Flaw:**
  - When a ride is shared with `audience: 'followers'`, the author's current followers are snapshotted into `allowedUserIds`.
  - A new follower who joins tomorrow can **never see historical follower-only rides**.
  - A follower who is blocked or unfollows the author tomorrow **retains permanent read access** to previously shared rides.

### 4.4 Unbounded Unsigned Cloudinary Credentials
* **Code Reference:** [`cloudinary_upload_service.dart:28-40`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/services/cloudinary_upload_service.dart#L28-L40)
* **The Flaw:** Plaintext `cloudName: 'vjvcigkt'` and `uploadPreset: 'throttleiq_unsigned'` are embedded directly in Dart code. Anyone decompiling the APK can issue unauthenticated HTTP POST requests to Cloudinary with arbitrary files, bypassing Firebase Auth, exceeding quota caps, or hosting abusive media on ThrottleIQ's account.

### 4.5 Public Unauthenticated Voice Notes
* **Code Reference:** [`cloudinary_upload_service.dart:48-54`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/services/cloudinary_upload_service.dart#L48-L54)
* **The Flaw:** Push-to-talk voice clips recorded during group rides are uploaded to Cloudinary as public URLs. Anyone with the URL can listen to private rider communications without authentication or access control.

### 4.6 Hardcoded Admin Identity
* **Code References:** [`forum_permissions.dart:5`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/forums/domain/forum_permissions.dart#L5) & [`firestore.rules:91`](file:///Users/blackbird/Everything/dev/ThrottleIQ/firestore.rules#L91)
* **The Flaw:** System administration rights are hardcoded to `'the.abraar.rar@gmail.com'` in both the Flutter client and Firestore security rules. There is no role-based access control (RBAC) via Firebase Auth Custom Claims.

### 5.2 Chat Repository $O(N)$ Read Cost & Race-Condition Duplication
* **Code Reference:** [`chat_repository.dart:44-65`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/chat/data/repositories/chat_repository.dart#L44-L65)
* **The Flaw:**
  - `getOrCreateChat` executes `where('participants', arrayContains: currentUserId).get()`, downloading every chat document the user possesses just to find an existing match.
  - If two riders tap "Message" concurrently, both queries return empty, and both call `chats.add()`. This spawns **two distinct parallel chat rooms** between the same pair of users, bifurcating conversation history.
  - A deterministic document ID format like `[uidA, uidB].sort().join('_')` would eliminate both the query scan and the race condition.

### 6.1 Six Duplicate Haversine Implementations
* **Code References:**
  1. `turn_instruction.dart:100`
  2. `privacy_zone_clipper.dart:88`
  3. `place_repository.dart:194`
  4. `ride_resume.dart:155`
  5. `geohash_utils.dart:113`
  6. `motion_calculator.dart:51`
* **The Flaw:** The same spherical trigonometry formula is duplicated 6 times across features rather than centralized in a shared math utility.

### 6.2 Gyroscope Dead-Reckoning Sign Inversion
* **Code Reference:** [`vehicle_state_estimator.dart:140-146`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/domain/calculators/vehicle_state_estimator.dart#L140-L146)
```dart
final deltaDeg = yawRateRadS * dtSeconds * (180 / pi);
_fusedHeadingDeg = _normalizeHeading(_fusedHeadingDeg! + deltaDeg);
```
* **The Flaw:** On Android and iOS, when the phone is mounted screen-up, rotation around the $+Z$ axis is positive in the counter-clockwise direction (turning left). In compass navigation, heading degrees increase clockwise (turning right from North toward East). Adding positive `deltaDeg` directly to `_fusedHeadingDeg` causes a left turn to erroneously increment the heading toward the East.

### 6.3 Axis Calibration False Positives from Potholes
* **Code Reference:** [`accel_axis_calibrator.dart:19-25`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/domain/calculators/accel_axis_calibrator.dart#L19-L25)
* **The Flaw:** Before 20 paired samples are gathered, `dominantAxisSignedMagnitude` assigns the entire 3D magnitude to whichever single axis has the largest value. Hitting a sharp pothole produces a large vertical spike ($a_z \approx -10\,\text{m/s}^2$). The calibrator picks $Z$ as dominant and classifies the bump as an extreme $-10\,\text{m/s}^2$ hard braking event.

### 7.2 iOS Auto-Tracking Impossibility
* **Code Reference:** [`auto_tracking_service.dart:29-37`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/services/auto_tracking_service.dart#L29-L37) & [`Info.plist:90-105`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/ios/Runner/Info.plist#L90-L105)
* **The Flaw:** `flutter_foreground_task` on iOS relies on standard background fetch. iOS executes background fetch arbitrarily (often hours apart). Without native `CLLocationManager.startMonitoringSignificantLocationChanges()` or persistent CoreMotion activity subscriptions, auto-tracking will practically never detect rides on iOS devices.


## other_gaps.md
### 1.1 The Garage Cascade Annihilation (Deleting a Bike Wipes Lifetime Ride History)
* **Code Reference:** [`bike_dao.dart:43-57`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/database/daos/bike_dao.dart#L43-L57) & [`cloud_repository.dart:48-62`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/cloud/cloud_repository.dart#L48-L62)
* **The Flaw:**
  ```dart
  await db.transaction((txn) async {
    final rides = await txn.query('rides', columns: ['id'], where: 'bike_id = ?', whereArgs: [id]);
    for (final ride in rides) {
      await txn.delete('ride_points', where: 'ride_id = ?', whereArgs: [ride['id']]);
    }
    await txn.delete('rides', where: 'bike_id = ?', whereArgs: [id]);
    await txn.delete('maintenance_logs', where: 'bike_id = ?', whereArgs: [id]);
    await txn.delete('bike_maintenance_configs', where: 'bike_id = ?', whereArgs: [id]);
    await txn.delete('bikes', where: 'id = ?', whereArgs: [id]);
  });
  ```
* **The Reality Check:**
  - When a rider sells their motorcycle or upgrades to a new bike, they tap "Delete Bike" in the Garage.
  - In normal vehicle tracking apps (Strava, Garmin, Rever, Detecht), removing a vehicle archives the bike or leaves historical rides attributed to an unassigned/archived bike ID.
  - **In ThrottleIQ, deleting a bike permanently obliterates every single ride ever taken on that motorcycle.** 200 rides, hundreds of hours of telemetry, personal achievements, and GPS breadcrumbs are instantly purged from both local SQLite and remote Firestore.
  - The modal dialog in [`bike_detail_screen.dart:238`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/garage/presentation/screens/bike_detail_screen.dart#L238) mentions this in one sentence, but providing no option to "Archive Bike" or "Keep Ride History" is a catastrophic data-loss trap.

### 1.3 Incomplete Account Deletion (Apple Guideline 5.1.1(v) & GDPR Failure)
* **Code Reference:** [`account-deletion.ts:38-41, 83-92`](file:///Users/blackbird/Everything/dev/ThrottleIQ/functions/src/account-deletion.ts#L38-L41)
* **The Flaw:**
  - Even if the Cloud Functions backend were deployable (it is currently blocked by Spark billing), `onUserAccountDeleted` explicitly admits in its own header comments:
    *`Still NOT covered: community content the rider authored inside other people's spaces (forum posts/replies, place reviews, comments on others' rides, group-ride membership, chats).`*
  - Cloudinary assets (the user's profile avatar, uploaded ride photos, and push-to-talk voice recordings) are **never deleted**.
  - When follows are deleted in `account-deletion.ts:90-91`, the `followerCount` and `followingCount` counters on other riders' profiles are never decremented.
  - Deleting an account leaves orphaned forum posts, hanging UGC, dangling storage files, and permanently corrupted profile statistics across the user base. Apple App Store reviewers routinely test account deletion by inspecting leftover public assets; this will trigger immediate rejection.

### 2.1 The Outbox Poison-Pill Infinite Retry Loop
* **Code Reference:** [`outbox_service.dart:294-307`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/cloud/outbox_service.dart#L294-L307)
* **The Flaw:**
  ```dart
  } catch (e) {
    debugPrint('[Outbox] ${entry.kind} ${entry.id} failed: $e');
    await _dao.recordFailure(
      id: entry.id,
      error: e.toString(),
      nextAttemptAt: DateTime.now().add(outboxBackoff(entry.attempts)),
    );
    _changes.add(null);
    return OutboxDeliveryResult.deferred;
  }
  ```
  - When a write throws a fatal exception (e.g., Firestore `permission-denied` due to security rules, an invalid payload schema, or an account mismatch), the outbox marks it as `deferred` and schedules an exponential retry capped at 30 minutes.
  - **There is NO maximum attempt ceiling, NO dead-letter queue, and NO quarantine mechanism.**
  - If User A queues a ride share and logs out, and User B logs in on the same device, User A's outbox writes fail with `permission-denied` (because the auth token belongs to User B). Those items will wake up the network radio, attempt to sync, fail, and reschedule **indefinitely every 30 minutes forever**, wasting CPU cycles, bandwidth, and battery.

### 3.1 OpenStreetMap Fair-Use Policy Breach & Zero Offline Map Caching
* **Code Reference:** [`active_ride_screen.dart:71-74`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/screens/active_ride_screen.dart#L71-L74)
* **The Flaw:**
  ```dart
  TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.bft.throttleiq',
  )
  ```
  1. **Upstream Policy Violation:** The OpenStreetMap Foundation's Tile Usage Policy explicitly states: *"OpenStreetMap data is free for everyone to use. Our tile servers are not... Heavy use (e.g. distributing an app that uses tiles from openstreetmap.org) is strictly forbidden without prior permission."* Streaming raw raster tiles directly to mobile app clients from `tile.openstreetmap.org` without a commercial host (Mapbox, Maptiler, Stadia) or caching proxy invites automated HTTP 429/403 IP and User-Agent bans.
  2. **Zero Offline Map Tiles:** `TileLayer` is not wrapped in `flutter_map_cache`, `dio_cache_interceptor`, or vector tile packages (MBTiles/PMTiles). When a rider enters an area without high-speed cellular data, **the map is rendered as an empty, grey checkerboard grid.** For an app advertising offline-first navigation, this is an existential defect.

### 3.2 Unbounded $O(N)$ Geo-Scan in `PlaceRepository.getNearbyPlaces`
* **Code Reference:** [`place_repository.dart:165-175`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/poi_directory/data/repositories/place_repository.dart#L165-L175)
* **The Flaw:**
  ```dart
  final places = await getAllPlaces(category: category);
  for (final place in places) {
    final distance = _calculateDistance(latitude, longitude, place.latitude, place.longitude);
    if (distance <= radiusKm) nearby.add(place);
  }
  ```
  - While `geohash_util.dart` has tests for calculating 8 bounding box neighbors, **it was never integrated into Firestore queries**.
  - To find nearby spots within 5 km, `PlaceRepository` downloads **every single place document across the entire country** from Firestore, deserializes them, and iterates through all of them running Haversine trigonometry on the Dart main isolate.
  - At 2,000–10,000 POIs, every tap on the "Places" tab downloads megabytes of data, consumes hundreds of Firestore read quotas per user per session, and triggers severe UI stutter.

### 3.3 Overpass POI Import: Sequential Network Choke & Identity Hijacking
* **Code Reference:** [`places_provider.dart:122-136`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/poi_directory/presentation/providers/places_provider.dart#L122-L136)
* **The Flaw:**
  - `importNearbyOsmPlaces` iterates over candidates with a sequential `for (...) await _placeRepository.addPlace(...)` loop. Importing 40 fuel stations in a city requires 40 individual, sequential Firestore network round-trips while the user stares at a loading indicator.
  - Line 132 sets `createdBy: uid`. Every imported public gas station, cafe, and repair shop is permanently attributed to the rider who tapped the import button.
  - When that rider opens their personal "My Places" screen ([`place_repository.dart:131`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/poi_directory/data/repositories/place_repository.dart#L131)), it is flooded with dozens of generic OpenStreetMap amenity nodes.

### 3.4 One-Way GPX Island: Zero Route Import & The Double Cast Bomb
* **Code Reference:** [`export_service.dart:131-132`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/cloud/export_service.dart#L131-L132)
* **The Flaw:**
  1. **No Ingestion Pipeline:** ThrottleIQ supports exporting recorded rides to GPX, but contains **zero GPX import capabilities**. Riders cannot import GPX files shared by riding clubs, downloaded from community forums (Wikiloc, ADVrider), or created in Garmin BaseCamp. The route feature is an isolated island.
  2. **Typecast Bomb in GPX Generation:**
     ```dart
     final lats = ridePoints.map<double>((p) => p['lat'] as double).toList();
     final lngs = ridePoints.map<double>((p) => p['lng'] as double).toList();
     ```
     Just like the typecast bugs flagged in `codebase.md` §3.4, if SQLite deserializes an exact integer coordinate (e.g. `24` or `90`), `p['lat'] as double` throws a fatal `_CastError`, crashing the export flow.

### 4.1 Moving-Time Distortion from GPS Gap Oversimplification
* **Code Reference:** [`ride_recording_provider.dart:536-540`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/ride_recording_provider.dart#L536-L540)
* **The Flaw:**
  ```dart
  if (gapMs <= _maxMovingGapSeconds * 1000) {
    if (speedMs >= SensorConstants.movingSpeedThresholdMs) {
      _movingMilliseconds += gapMs;
    }
  }
  ```
  - `_maxMovingGapSeconds` is set to 60 seconds.
  - Suppose a rider stops at a traffic light for 50 seconds. Because the bike is stationary, GPS updates pause or jitter below the distance filter.
  - When the light turns green, the rider accelerates to 20 km/h. A new GPS fix arrives with a 50-second timestamp gap.
  - Because `speedMs >= 1.0 m/s` at that instant, the algorithm evaluates the condition as true and **adds the entire 50 seconds of stationary idle time to `_movingMilliseconds`!**
  - In stop-and-go city riding, this flaw severely inflates moving time, corrupts average moving speed, and distorts the "jam time" traffic metric.

### 5.2 Global Window Portrait Lock in `main.dart`
* **Code Reference:** [`main.dart:32-35`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/main.dart#L32-L35)
* **The Flaw:**
  ```dart
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  ```
  - While `UI_UX.md` §1.5 noted that the cockpit HUD cards overflow in landscape mode, the root barrier is even more severe: **the app is hard-locked to portrait orientation at the engine level in `main.dart`**.
  - Any motorcyclist using a horizontal handlebar stem mount (standard for QuadLock, Peak Design, and SP Connect to keep phone cameras clear of windshields) will find ThrottleIQ permanently rotated sideways with zero OS-level landscape support.

### 5.3 Home Widget SQLite Table-Scan Scalability Trap
* **Code Reference:** [`home_widget_service.dart:437-440`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/services/home_widget_service.dart#L437-L440)
* **The Flaw:**
  ```dart
  final rideRows = await _rideDao.getAllForUser(uid);
  final rides = rideRows.map(RideModel.fromMap).toList();
  final totalKm = rides.fold<double>(0, (sum, r) => sum + r.distanceKm);
  ```
  - Every time the home-screen widget is refreshed (on app launch, app resume, or ride completion), it queries all rides for the user from SQLite, instantiates hundreds of `RideModel` objects into memory, and iterates over them in Dart to sum the distance.
  - For an active rider with 500+ rides, this unindexed full-table scan and object allocation causes noticeable launch-frame stutter instead of executing a single SQL query: `SELECT SUM(distance_m) FROM rides WHERE user_id = ?`.

### 6.1 Zero CI/CD, Automated PR Gating, or Cloud Quality Enforcers
* **Code Reference:** Repo Root (`.github/` is completely missing)
* **The Flaw:**
  - There are no GitHub Actions workflows, no GitLab CI configurations, and no automated PR validation hooks in the entire repository.
  - All QA guarantees in `qa-gate.md` (running `flutter analyze`, running `flutter test`, running rules emulator) depend entirely on the memory and diligence of a single developer on a single MacBook.
  - If external contributions or git branches are pushed, zero automated tests are executed in the cloud. Broken builds, broken rules, and failing tests can be merged to `master` completely undetected.

### 6.2 The Single-Laptop Keystore Vulnerability (Catastrophic Key Loss Risk)
* **Code Reference:** [`HANDOFF_Document.md:727-730, 1052`](file:///Users/blackbird/Everything/dev/ThrottleIQ/DOCS/Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md#L727-L730)
* **The Flaw:**
  - The Android release keystore `throttleiq-release.keystore` and `key.properties` exist exclusively on the local developer machine and are gitignored.
  - There is no automated backup, no encrypted secret vault (1Password/Bitwarden), and no CI repository secret storage.
  - If the developer's laptop suffers SSD corruption, liquid damage, or theft, **the release signing key is permanently gone**. In Google Play, losing an upload keystore without Google Play App Signing key reset access means the app package `com.bft.throttleiq` can never be updated again, effectively killing the published app.


## UI_UX.md
### 1.3 Map Locked North-Up & The Static Dot (Spatial Disorientation)
* **The Crime:** In both [`active_ride_screen.dart:159-163`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/record/presentation/active_ride_screen.dart#L159-L163) and [`route_navigation_screen.dart:106-113`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/routes/presentation/route_navigation_screen.dart#L106-L113):
  ```dart
  _mapCtrl.move(currentPoint, _mapCtrl.camera.zoom);
  ```
  - `_mapCtrl.rotate()` is **never called**.
  - In `active_ride_screen.dart`, the user's position is a static non-directional circle:
    ```dart
    CircleAvatar(backgroundColor: AppColors.primary, radius: 10)
    ```
  - In `route_navigation_screen.dart`, the vehicle marker is an `Icons.navigation` glyph permanently pointing toward the top of the phone screen, regardless of vehicle heading!
* **The Reality Check:**
  - If a rider travels South on a highway, the map stays North-up. When they take a left turn onto an off-ramp, their screen shows the dot moving **to the right and down**.
  - A rider's brain must execute a 180-degree mental rotation while navigating traffic. This is a notorious cause of missed exits and dangerous sudden lane changes.
* **The Fix:** Bind GPS bearing / gyro heading to camera rotation: `_mapCtrl.rotate(-bearing)`. Keep the vehicle heading pointing straight UP, rotating the world under the bike.

### 1.4 Zero Audio Turn Guidance (The Head-Down Riding Death Wish)
* **The Crime:** Inspect [`route_navigation_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/routes/presentation/route_navigation_screen.dart).
  - Turn cues are calculated purely as distance steps:
    ```dart
    Text('${nextStep.distanceRemainingMeters.round()}m ahead', style: TextStyle(fontSize: 22))
    ```
  - There is **zero integration with `flutter_tts`**, zero audio prompts, and zero Bluetooth headset profile handling (A2DP/HFP).
* **The Reality Check:**
  - 95% of touring motorcyclists ride with helmet communicators (Cardo PackTalk, Sena, or Bluetooth earbuds).
  - Safe motorcycle navigation is 90% audio (*"In 500 meters, take the second exit at the roundabout"*) and 10% visual confirmation.
  - Forcing a motorcyclist to stare down at a 6-inch screen mounted between their triple clamps to know when a turn is coming is unacceptable.

### 1.5 Landscape Cockpit Obliteration
* **The Crime:** Most dedicated motorcycle mounts (Beeline, QuadLock horizontal stem mount, SP Connect) place the phone in landscape mode to avoid blocking the motorcycle's actual instrument cluster.
* Look at [`active_ride_screen.dart:330-360`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/record/presentation/active_ride_screen.dart#L330-L360):
  ```dart
  Positioned(top: 16, left: 16, right: 16, child: TopBar()),
  Positioned(bottom: 160, left: 16, right: 16, child: SpeedAndLeanCard()),
  Positioned(bottom: 24, left: 16, right: 16, child: ControlButtons()),
  ```
* **The Reality Check:**
  - A typical smartphone in landscape has a logical vertical height of ~390dp.
  - `top: 16` + `TopBar (~60dp)` + `SpeedAndLeanCard (~220dp)` + `bottom: 160` + `ControlButtons (~80dp)` = **536dp of vertical space required!**
  - Result: On a landscape handlebar mount, the speed card collides with and renders directly over top of the TopBar and control buttons. The app is completely broken in landscape.
* **The Fix:** Use `OrientationBuilder`. In landscape, place the map on the left 50% and a high-contrast digital instrument cluster on the right 50%.

### 1.6 The Paused-Ride Scrim Disaster
* **The Crime:** As identified in [`issues_open.md:50-53`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/../DOCS/Handoff%20for%20agents%20and%20Todos/issues_open.md#L50-L53):
  When a ride is paused, the app drops a dark, translucent modal scrim across the **entire screen**, including the speed, distance, lean, and duration stats card.
* **The Reality Check:**
  - Why does a rider pause? Usually when stopped at a traffic light, railway crossing, or scenic overlook.
  - That stop is the **single moment** the rider actually has time to look down and inspect their numbers!
  - Dimming the telemetry card into a washed-out grey-on-black mush at the exact moment the rider looks at it is completely backwards.
* **The Fix:** Scrim the map background only. Keep the telemetry cluster fully bright, high-contrast, and prominently badged with an amber "PAUSED" indicator.

### 2.3 The Maintenance Screen Dead-End & The Missing Link
* **The Crime:**
  1. Open [`maintenance_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/maintenance/presentation/maintenance_screen.dart). **It has no `AppBar` and no back button.** It lives inside `ShellRoute`, so the bottom navigation bar is present, but there is no arrow or button to go back to the screen that summoned it.
  2. Open [`bike_detail_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/garage/presentation/bike_detail_screen.dart). Search for any mention of maintenance or service logs. **There is none.**
* **The Reality Check:**
  - A user viewing a specific bike in their garage has zero access to that bike's maintenance history!
  - If a user enters `MaintenanceScreen` from anywhere, they cannot "go back" to where they came from without tapping a bottom nav tab to reset the stack.
* **The Fix:** Add a standard `AppBar` with `automaticallyImplyLeading: true` to `MaintenanceScreen`. Add a prominent "Service & Maintenance Records" section with full status cards inside `BikeDetailScreen`.

### 2.4 The Add-Bike Hijacking Loop
* **The Crime:** Look at [`add_edit_bike_screen.dart:156-162`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/garage/presentation/add_edit_bike_screen.dart#L156-L162):
  ```dart
  if (widget.bikeId == null) {
    context.pushReplacement('/maintenance/config?bikeId=$id');
  } else {
    context.pop();
  }
  ```
  Then in [`maintenance_config_screen.dart:182`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/maintenance/presentation/maintenance_config_screen.dart#L182):
  ```dart
  context.pushReplacement('/maintenance?bikeId=${widget.bikeId}');
  ```
* **The Reality Check:**
  - A user adds their motorcycle. They hit "Save".
  - Instead of seeing their newly added motorcycle in their garage, they are forcibly redirected to configure maintenance intervals.
  - Once they configure maintenance, they are redirected again into the maintenance log screen (which, as shown above, has no back button!).
  - The user is completely hijacked across two route replacements without their consent.
* **The Fix:** When a bike is saved, `context.pop()` immediately back to the Garage. Show an in-context banner or SnackBar: *"Yamaha R15 added! [Set Maintenance Intervals]"*. Let the user choose whether to configure intervals now or later.

### 2.6 The Global Notification Blindspot
* **The Crime:** Where is the notification bell icon located in ThrottleIQ?
  - Home tab? No.
  - Social tab? No.
  - Chat room list? No.
  - It is buried exclusively in the top AppBar of [`garage_screen.dart:81-86`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/garage/presentation/garage_screen.dart#L81-L86).
* **The Reality Check:**
  - Notifications in ThrottleIQ cover social comments, group ride invitations, chat pings, and safety alerts.
  - None of those relate directly to the Garage.
  - A user hanging out in the Social or Home tab will never see unread notification badges because the bell icon is sequestered on a completely unrelated tab.

### 3.1 "Navigate" Does NOT Record a Ride
* **The Crime:** Look at [`routes_list_screen.dart:254`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/routes/presentation/routes_list_screen.dart#L254) and [`route_navigation_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/routes/presentation/route_navigation_screen.dart):
  - A rider finds a great twisty mountain route. They hit **"Navigate"**.
  - `RouteNavigationScreen` opens and guides them along the polyline.
  - **It does NOT record the ride.**
  - **It does NOT track maximum lean angle or G-forces.**
  - **It does NOT run crash detection (`event_detector.dart`).**
  - When the rider finishes the route, the screen closes and nothing is saved to their ride log.
* **The Reality Check:**
  - Every rider expects that when they are riding a route inside a motorcycle telemetry app, the app is recording their telemetry!
  - If a rider has an accident while following a route in `RouteNavigationScreen`, **the automated emergency crash workflow is 100% dead**.
* **The Fix:** Unify navigation and recording into a single execution engine. When starting navigation, automatically start a recording session bound to that route ID.

### 4.2 WCAG AA Contrast Failure in Default Theme (`calmingLight`)
* **The Crime:** In [`app_colors.dart:12-21`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/theme/app_colors.dart#L12-L21):
  ```dart
  static const calmingLight = ThemePalette(
    primary: Color(0xFF84A98B),   // Muted Sage Green
    accent: Color(0xFF52796F),
    background: Color(0xFFF7F9F6),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2F3E46),
  );
  ```
  Primary buttons throughout the app use:
  ```dart
  backgroundColor: AppColors.primary, // #84A98B
  foregroundColor: Colors.white,      // #FFFFFF
  ```
* **The Contrast Mathematics:**
  - `#84A98B` (Sage Green) relative luminance: ~0.37
  - `#FFFFFF` (White) relative luminance: 1.0
  - **Calculated Contrast Ratio: 2.62:1**
  - **WCAG AA Minimum Required: 4.5:1**
  - **WCAG AAA Minimum Required: 7.0:1**
* **The Reality Check:**
  - The out-of-the-box default theme for new users fails basic accessibility standards by a massive margin.
  - In direct sunlight outdoors, white text on `#84A98B` is virtually invisible.
* **The Fix:** Replace `#84A98B` with a darker forest/racing green (`#2D5A43`, contrast 5.2:1) or use dark text (`#1A252C`) on buttons.

### 4.5 Sub-48dp Touch Targets (Fitts's Law Violations)
* **The Crime:** Look at [`tour_floating_banner.dart:130-138`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/auth/presentation/widgets/tour_floating_banner.dart#L130-L138):
  ```dart
  InkWell(
    onTap: () {
      ref.read(activeTourGuideProvider.notifier).state = null;
    },
    child: const Padding(
      padding: EdgeInsets.all(4.0),
      child: Icon(Icons.close, size: 16, color: Colors.white54),
    ),
  )
  ```
* **The Reality Check:**
  - An icon of size 16 with 4dp padding gives a total touch bounding box of **24 x 24 dp**.
  - Apple Human Interface Guidelines and Google Material Design both mandate a **minimum touch target of 48 x 48 dp** for bare hands.
  - For gloved hands on a motorcycle, touch targets should be **56 x 56 dp minimum**.
  - Tapping this close icon on a moving or idling motorcycle requires microsurgical precision.

### 5.2 The "Fake Private Profile" Error Screen
* **The Crime:** Look at [`user_profile_screen.dart:78-95`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/profile/presentation/user_profile_screen.dart#L78-L95):
  ```dart
  profileAsync.when(
    data: (profile) {
      if (profile == null) {
        return const Center(child: Text('This profile is private or not found'));
      }
      return _buildProfile(context, profile);
    },
    error: (e, _) => const Center(child: Text('This profile is private or not found')),
  )
  ```
* **The Reality Check:**
  - If a rider is offline, if Firebase has a 503 outage, or if a network request times out, the app tells the user: **"This profile is private or not found"**.
  - This falsely implies the rider blocked them or marked their account private, when in fact the phone simply lost cellular connectivity!
* **The Fix:** Never mask network errors as privacy blocks. Show a dedicated offline/error state with an explicit retry button.

### 5.3 Silent GPS Fallback to Dhaka, Bangladesh
* **The Crime:** Look at [`add_place_screen.dart:187-191`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/places/presentation/add_place_screen.dart#L187-L191):
  ```dart
  final lat = _selectedLocation?.latitude ?? 23.8103;
  final lng = _selectedLocation?.longitude ?? 90.4125;
  ```
* **The Reality Check:**
  - If a rider in California, Germany, or Chittagong opens "Add Place" before their phone acquires a GPS satellite lock, the coordinates silently default to `23.8103, 90.4125` (Dhaka).
  - When they tap Save, their local café or twisty road is saved in the middle of Old Dhaka!
* **The Fix:** If GPS has not acquired a fix, disable the Save button and display: *"Acquiring GPS fix..."*.

### 5.4 The SafeQR Dead End
* **The Crime:** Inspect [`safe_qr_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/profile/presentation/safe_qr_screen.dart).
  - The screen renders an ICE (In Case of Emergency) QR code containing medical info and emergency contacts.
  - **There is no Save to Photos button.**
  - **There is no Share / Print button.**
* **The Reality Check:**
  - A SafeQR code is completely useless if it only lives on the rider's phone screen. If the rider crashes, the phone screen might be shattered or locked.
  - The entire premise of emergency QR stickers is to **print them out and stick them on the rider's helmet, tank, or jacket**.
  - Showing a QR code on a mobile screen with no way to export, save as image, or print is an unfinished feature.

### 6.1 The "Built for Bangladesh" Localization Mirage
In the iDEA pitch and marketing materials, ThrottleIQ is pitched as *"Bangladesh's first indigenous two-wheeler telemetry platform built specifically for local road conditions."*

**Yet in the code:**
- **39 production screens have zero Bengali strings.**
- The entire active ride screen, emergency alert dialogs, crash countdown, maintenance logs, and login screens are **100% English only**.
- Emergency crash countdown: *"CRASH DETECTED! Alerting emergency contacts in 30s..."*
  If a commuter in rural Bogura or Sylhet crashes and a bystander picks up their phone, they will see English technical copy that most local bystanders will not understand.
- For a project seeking Bangladeshi government grants, having zero Bengali localization on life-saving safety screens is an indefensible oversight.

### 6.3 False Sense of Security in Emergency Features
Look at [`settings_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/settings/presentation/settings_screen.dart):
Under "Emergency Contacts", it allows users to enter names and phone numbers, with fine-print text:
> *"Logged if a crash is detected... Automatic SMS/email alerts aren't live yet."*

**This is a liability nightmare.**
Users do not read fine print. A rider who enters their mother's or spouse's phone number into an "Emergency Contacts" section genuinely believes the app will text them if they crash.
Shipping an inactive safety feature that openly admits it won't alert anyone gives riders a false sense of security that could have tragic real-world consequences.


## bussness.md

## claude_sol.md
### 1.1 Crash detection is unreachable ✅ (P0)

**Evidence**
- `features/ride/presentation/providers/ride_recording_provider.dart:611` is the only `_detector.detect(...)` call. It sits inside `_onPosition` (the GPS callback).
- `accel` comes from `MotionCalculator.calculate` (`features/ride/domain/calculators/motion_calculator.dart:31`): `(currentSpeedMs - prev.speedMs) / deltaT`, i.e. GPS speed delta.
- `SensorConstants.crashAccelThreshold = 80.0` (`core/constants/sensor_constants.dart:26`).
- Speeds above 70 m/s are rejected (`maxPlausibleSpeedMs`), so a drop of 80 m/s within 1 s cannot happen. **The accel spike condition can never be true on a live ride.**
- The IMU goes to `SensorFusionCoordinator.onAccelEvent` (`features/ride/presentation/providers/helpers/sensor_fusion_coordinator.dart:61-113`). That code low-pass filters with α=0.1 and checks only hard-brake/rapid-accel. It never checks for a crash.
- Correction to `bussness.md` §1.3: the `maxPhysicalAccelMs2` clamp limits only *speed increases* written to `speedMs`. It does **not** clamp the `accel` value passed to the detector, which uses `rawSpeedMs`. The conclusion is unchanged, but the mechanism is the speed plausibility cap and GPS rate, not the clamp.

**Fix**
1. **Add a dedicated `ImpactDetector`** (`features/ride/domain/calculators/impact_detector.dart`) that consumes **raw, unfiltered** IMU samples:
   - Input: `UserAccelerometerEvent` magnitude `|a| = sqrt(x²+y²+z²)` at the existing 50 ms sampling period (`ride_recording_provider.dart:430`). Consider 20 ms (`SensorInterval.gameInterval`) during rides.
   - Spike condition: `|a| ≥ impactThreshold` for at least 1 sample, **or** ≥3 consecutive samples within 2% of the highest value seen this ride. The second condition catches saturation on budget phones whose range tops out at 4-8 g.
   - Start with `impactThreshold = 4 g ≈ 39 m/s²` as a *provisional* value. Add it to `SensorConstants` with a comment saying it is uncalibrated.
2. **Confirm with GPS and stillness, not jerk from GPS.** Within 5 s after the spike, require both of:
   - GPS speed < 2 m/s (reuse `EventDetector._checkSpeedDrop` logic), **and**
   - post-impact stillness: IMU magnitude variance below a small threshold for ≥3 s, or the orientation (gravity vector from `accelerometerEventStream`) rotated by >45° versus the pre-impact baseline (bike on its side).
3. **Rewire**
   - In `SensorFusionCoordinator.onAccelEvent`, call `impactDetector.addSample(t, x, y, z)` **before** the low-pass filter.
   - In `_onPosition`, call `impactDetector.addSpeed(t, speedMs)`.
   - Have `ImpactDetector` expose a `Stream<CrashSignal>` or callback. `RideRecordingNotifier` wires it to `_onCrashDetected()` with the existing `minConfidenceForCrashAlert` gate.
   - Remove the crash branch from `EventDetector.detect`, or leave it unused but documented. It must not be the live path.
4. **Log near-misses** to a local table `impact_candidates` (timestamp, peak, speed before/after, stillness result). Upload them with rides. This is the data needed to calibrate thresholds. `falseCrashPositives` already exists for dismissals; add true negatives too.
5. **Tests**
   - Keep the pure-math tests, but add a **pipeline test** that feeds synthetic `UserAccelerometerEvent` plus `Position` streams through `RideRecordingNotifier` (or at least `SensorFusionCoordinator` + `ImpactDetector`) and asserts a crash fires. The existing test is green only because it calls `detect(accel: 90)` directly, bypassing the wiring.
   - Add a negative test: pothole-shaped spikes (1-2 samples at 4-6 g while speed stays >8 m/s) must **not** fire.
6. **Field validation before any claim.** Record at least 10 real rides on a handlebar mount and confirm zero false positives. Do a padded drop test (phone in a padded box dropped about 1 m while a mock location is at 30 km/h, then mock speed 0). Record the device models and their observed max ranges.
7. Until step 6 passes: **change marketing/pitch copy** (see §4.1) and the in-app copy on the emergency contacts screen.

### 1.2 Jerk averaging erases the peak ✅ (P0, do with 1.1)

**Evidence:** `event_detector.dart:127-129` uses `(_peakJerkInWindow + jerk.abs()) / 2`.
**Fix:** Use `_peakJerkInWindow = math.max(_peakJerkInWindow, jerk.abs());` and add a unit test with the sequence [14, 5.5] that asserts the peak stays 14. If the crash path moves to `ImpactDetector`, apply the same "max, not average" rule there.

### 1.3 Brake/accel counters over-count ✅, plus a worse bug the grill missed (P1)

**Evidence**
- Double counting is real. The IMU path does `detector.hardBrakeCount++` (`sensor_fusion_coordinator.dart:101`), and the GPS path increments the same counter in `EventDetector.detect` (`event_detector.dart:163`).
- **New, worse bug:** `_lastSensorEvent` (the 2 s cooldown) is only updated when `sensorAlert != currentActiveAlert` (`sensor_fusion_coordinator.dart:108-111`). `state.activeAlert` is never cleared back to `none` during a ride (it is reset only in `startRide`, line 362, and `alertToShow` at line 641 keeps the old value). So after the first hard brake, **every IMU sample (20 Hz) below −4 m/s² increments `hardBrakeCount`**. One 1-second brake can add about 20.

**Fix**
1. Pick **one owner** of longitudinal event counts. Recommendation: the IMU path once `axisCalibrator.isCalibrated`, and the GPS path before that. Implement this by adding `bool countLongitudinal` to `EventDetector.detect(...)`, passed as `!_sensorCoordinator.axisCalibrator.isCalibrated`.
2. Make the IMU path **edge-triggered with hysteresis**. Count once when `_filteredAccel` crosses below −4.0, then re-arm only after it rises above −2.0. Do the same for rapid accel. Update `_lastSensorEvent` on every counted event, not only on UI alert change.
3. Clear `activeAlert` after a TTL. Add a timer, or have `_onPosition` set `activeAlert: effectiveAlert` when the last alert is older than 5 s.
4. Test: feed 60 samples at −5 m/s² and assert `hardBrakeCount == 1`.

### 2.1 Emergency escalation is a mock and undeployed ✅ (P0, product decision)

**Evidence:** `functions/src/crash-notifications.ts:53,157` sets `status: 'mock_not_sent'`, and lines 163-175 are `scheduleEscalation` as a `console.log` plus TODO. `HANDOFF_Document.md` lines 23-26, 185, and 542 confirm Functions are blocked on Spark.
**Fix (choose one path explicitly)**
- **Path A (ship it):** Enable Blaze with a budget alert (e.g. $5/month cap alert). Implement SMS through a local gateway (SSL Wireless / Infobip BD / Twilio). Store the API key in `functions:secrets` (`defineSecret`). Implement escalation with Cloud Tasks (`@google-cloud/tasks`, 15 min delay) that re-checks `crashNotifications/{id}.status`. Add an `allow update` rule so the owner can set `status: 'cancelled'`; this closes issues_open §69.O3.
- **Path B (no backend yet):** Do client-side SMS. When the countdown expires, open the SMS composer with `url_launcher` and `sms:` plus a prefilled body and live link. Also offer to auto-call the first contact (`tel:`). This needs no backend, but it requires the phone to be usable. Label it honestly as "we'll help you alert contacts".
- Either way: until one path is live, the emergency contacts UI and all marketing must say "alerts are not automatic yet". See §3.6.3.

### 2.2 Crash-status rides never sync, and their stats are never written ✅ (P0)

**Evidence:** `_onCrashDetected` calls `finalizeRide(id, {'status':'crash','end_time':...})` (`ride_recording_provider.dart:993`). `getUnsynced` filters `status = 'completed'` (`core/database/daos/ride_dao.dart:181`). The crash path also never writes distance, duration, max speed, or counts, because only `stopRide` computes those (≈ line 859).

**Fix**
1. Change `ride_dao.dart:getUnsynced` to `where: "user_id = ? AND synced = 0 AND status IN ('completed','crash')"`.
2. Extract the stats map built in `stopRide` into `_buildFinalStats()` and merge it into the crash `finalizeRide` call.
3. After a crash finalize, trigger `syncManager.syncNow()` (or equivalent) so the ride goes up immediately while the phone still works.
4. Check the UI lists that query `status = 'completed'` (`ride_dao.dart:16,25,48`) and decide whether crash rides should appear. They probably should, with a badge.
5. Test: a DAO test showing a `crash` ride appears in `getUnsynced`.

### 2.3 SafeQR is unusable when the phone is locked ✅ (P2). See UI 5.4 for export.

**Fix:**
- Add "Save image / Share / Print" (see §3.5.4). The printed sticker on the helmet is the real product.
- Android: add a lock-screen-visible persistent notification option ("Medical ID") with `visibility: public` showing blood group and one ICE number, opt-in.
- Point users to the OS-native Medical ID (iOS Health → Medical ID, Android Emergency information) with a deep link or instructions in the SafeQR screen.

### 2.4 `USE_FULL_SCREEN_INTENT` ✅ (P1, before Play production)

**Evidence:** `android/app/src/main/AndroidManifest.xml:49`, used at `core/services/notification_service.dart:173`.
**Fix:**
1. In Play Console, complete the "Full-screen intent" declaration. Argue that the crash countdown is a time-sensitive, alarm-like safety alert. Expect a possible rejection.
2. At runtime (API 34+), check `NotificationManager.canUseFullScreenIntent()` through a small method channel. If false, deep-link to `Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` from the emergency setup screen. Otherwise fall back to a heads-up notification with the alarm category plus sound and vibration. This fallback already works without FSI.
3. Show the permission state in Settings → Emergency.

### 3.1 `downloadRideTrack` is never called ✅ (P1)

**Evidence:** The only occurrence is its definition, `core/cloud/cloud_repository.dart:417`. `RideSummaryScreen._loadPolyline` (`features/ride/presentation/screens/ride_summary_screen.dart:73-86`) reads only `RidePointDao`.
**Fix:**
```dart
Future<void> _loadPolyline() async {
  final dao = RidePointDao();
  var points = await dao.getForRide(widget.rideId);
  if (points.isEmpty) {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid != null) {
      try {
        if (await ref.read(cloudRepositoryProvider).downloadRideTrack(uid, widget.rideId)) {
          points = await dao.getForRide(widget.rideId);
        }
      } catch (e) { debugPrint('[RideSummary] track download failed: $e'); }
    }
  }
  if (!mounted) return;
  setState(() { /* existing mapping, using num casts (see 3.4) */ });
}
```
Apply the same "local, else download" pattern in `ride_share_screen.dart:67`, `save_route_screen.dart:55`, and `export_service.dart:131`. Extract a helper `RideTrackLoader.load(rideId)` so it lives in one place. Add a loading state ("Fetching route…") and an empty state ("Route not available") instead of a blank map. Add a `mounted` check too; the current code calls `setState` after `await` without one.

### 3.2 Track upload failure strands points ✅ (P1)

**Evidence:** `sync_manager.dart:268-285` sets `synced=1` in `uploadRides` before `uploadRideTrack`. A caught failure is never retried.
**Fix:**
1. Migration: `ALTER TABLE rides ADD COLUMN track_synced INTEGER NOT NULL DEFAULT 0`. Backfill existing `synced=1` rows as `track_synced=0` so they get re-uploaded once; the upload is idempotent (chunk docs keyed by index).
2. Add `RideDao.getTrackUnsynced(uid)` → `synced = 1 AND track_synced = 0 AND status IN ('completed','crash')`.
3. In `SyncManager`, after `uploadRides`, loop over `getTrackUnsynced` (not over `unsyncedRides`). Call `markTrackSynced(id)` on success.
4. `finalizeRide` must also reset `track_synced = 0`.
5. Test: a failing fake `uploadRideTrack` on the first sync followed by a succeeding one on the second sync ends with `track_synced = 1`.

### 3.3 `deleteBikeRemote` batch limit and orphaned tracks ✅ (P1). Fix together with other_gaps 1.1 (§2.1.1 below).

**Evidence:** `cloud_repository.dart:48-62` uses a single batch and never touches the `rides/{id}/track` subcollections.
**Fix:** If the product decision in §2.1.1 is to archive, most of this disappears because rides are no longer deleted. For whatever is still deleted (account deletion, explicit "delete rides too"):
```dart
Future<void> _deleteInChunks(List<DocumentReference> refs) async {
  for (var i = 0; i < refs.length; i += 400) {
    final batch = _firestore.batch();
    for (final r in refs.skip(i).take(400)) batch.delete(r);
    await batch.commit();
  }
}
```
Collect each ride's `track` docs (`ride.reference.collection('track').get()`) before deleting the ride doc.

### 4.1 Privacy clipper uses path distance ✅ (P1)

**Evidence:** `features/social/domain/utilities/privacy_zone_clipper.dart` `_findClipIndex` accumulates segment lengths until the total reaches 200 m.
**Fix:** Clip by **radius**, and make the radius unpredictable:
```dart
static List<LatLng> clipPolyline(List<LatLng> pts, {double radiusM = 200, int seed = 0}) {
  if (pts.length < 3) return [];
  final start = pts.first, end = pts.last;
  // stable per-user jitter so the circle edge can't be triangulated
  final r = radiusM + (seed.abs() % 150); // 200-350 m
  bool hidden(LatLng p) =>
      haversineDistance(p, start) <= r || haversineDistance(p, end) <= r;
  var i = 0; while (i < pts.length && hidden(pts[i])) i++;
  var j = pts.length - 1; while (j >= 0 && hidden(pts[j])) j--;
  if (i >= j) return [];
  return pts.sublist(i, j + 1);
}
```
- Pass `seed` from a hash of the uid.
- Trimming only leading and trailing hidden runs keeps the middle of a loop ride that happens to pass near home. If you want to hide *any* point near home, also filter interior points and split into multiple polylines. The share model currently stores one list, so that is a larger change.
- Longer term, add user-defined privacy zones (home/work pins) and apply them to every point.
- Tests: (a) 300 m of GPS drift within 10 m of the start leaves nothing within `r` of the start; (b) a straight 5 km ride trims about 200-350 m at each end.

### 4.2 `auto_detections`/`auto_fixes` have no owner ✅ (P1)

**Evidence:** `database_helper.dart:273-319` has no `user_id`. `deleteUserData` intentionally skips these tables (lines 510-537). `AutoRideReconcilerService.reconcilePending` (`features/ride/data/repositories/auto_ride_reconciler_service.dart:62-76`) assigns every pending row to whoever is signed in.
**Fix:**
1. Migration: `ALTER TABLE auto_detections ADD COLUMN user_id TEXT`. Leave existing rows as `NULL`.
2. `AutoTrackingService.start()` runs only when signed in (`app.dart:143`). Persist the uid for the background isolate: `FlutterForegroundTask.saveData(key: 'uid', value: uid)`. In `_AutoTrackingTaskHandler._maybeBegin`, read it with `getData('uid')` and stamp `user_id` on the detection row.
3. `AutoDetectionDao.pendingDetections(uid)` → `WHERE status='pending' AND user_id = ?`. For legacy rows with `NULL`, discard with reason `'unowned_legacy'` if older than 7 days; otherwise show a one-time "Was this your ride?" confirmation.
4. On sign-out (`app.dart:147-150`), after `AutoTrackingService.stop()`, call `FlutterForegroundTask.removeData(key: 'uid')`.
5. Test: a pending detection with `user_id = A` is not reconciled for B.

### 4.3 Follower audience is a frozen snapshot ✅ (P3)

**Evidence:** `ride_share_repository.dart:73-77` writes `allowedUserIds = getFollowers(...)` at share time, and `firestore.rules:9-15` checks `request.auth.uid in allowedUserIds`.
**Fix (no Blaze needed for the most important half):**
- **Block/unfollow revocation:** When the author blocks someone or removes a follower, the author's own client runs a batched `arrayRemove(uid)` over their own `rideShares` where `audience == 'followers'`. The author owns those docs, so the rules already allow it.
- **New followers seeing old posts:** Either accept the behavior and document it ("followers-only posts are visible to people who followed you at the time"), or, after Blaze, add a Function `onFollowCreate` that `arrayUnion`s the new follower into the author's follower-audience shares.

### 4.4 Unsigned Cloudinary preset in the binary ✅ (P2)

**Evidence:** `core/services/cloudinary_upload_service.dart:28-29`.
**Fix, in stages:**
1. **Now, in the Cloudinary console, no code:** on preset `throttleiq_unsigned`, set:
   - allowed formats `jpg,png,webp,heic,aac,m4a`
   - max file size (images 5 MB, audio 1 MB)
   - `folder` locked to a prefix
   - "Unique filename", "Overwrite: false"
   - incoming transformation `c_limit,w_2048`
   - an upload rate-limit or usage alert on the account
2. **After Blaze:** add an HTTPS callable `signCloudinaryUpload` (verifies `context.auth`, returns `signature`, `timestamp`, `api_key`, and a folder scoped to `uid`). Switch the client to signed uploads and delete the unsigned preset.
3. Rotate the cloud name's API secret if it was ever committed anywhere.

### 4.5 Voice notes are public URLs ✅ (P2)

**Fix:**
- Short term: add a Cloudinary auto-delete for the `voiceNotes/` folder (an Admin API cleanup script, or an upload preset with `expires_at`-style lifecycle). Make the URL unguessable: it already is by default (random public_id), so keep `unique_filename=true`. Declare "Audio: voice recordings" in the Play Data Safety form.
- After Blaze: use `type: authenticated` uploads plus short-lived signed delivery URLs from a callable that checks group-ride membership. Alternatively, move voice notes to Firebase Storage with `storage.rules` checking membership.

### 4.6 Admin identity hardcoded ✅ (P3)

**Evidence:** `features/forums/domain/forum_permissions.dart:5`, `firestore.rules:64-67`.
**Fix:** Custom claims **don't need Blaze**. Write a one-off local Node script with `firebase-admin` and the service account key (`secrets/…json`, which is already gitignored): `auth.setCustomUserClaims(uid, {admin: true})`. In rules, replace the email check with `request.auth.token.admin == true`. In the client, have `isAdmin` read `(await user.getIdTokenResult()).claims?['admin'] == true` (cache it in a provider). Delete `kAdminEmail`.

### 5.2 Chat: O(N) lookup and duplicate rooms ✅ (P2)

**Evidence:** `features/chat/data/repositories/chat_repository.dart:44-65`.
**Fix:**
```dart
String dmId(String a, String b) => (a.compareTo(b) < 0) ? '${a}_$b' : '${b}_$a';

Future<String> getOrCreateChat(String me, String other) async {
  final id = dmId(me, other);
  final ref = _firestore.collection('chats').doc(id);
  await _firestore.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (!snap.exists) {
      tx.set(ref, {'participants': [me, other], 'updatedAt': FieldValue.serverTimestamp()});
    }
  });
  return id;
}
```
- Rules: on create, require `chatId == participants[0] + '_' + participants[1]` in sorted order, or at least that `request.auth.uid in participants` and `participants.size() == 2`.
- Legacy random-id chats: before creating, fall back **once** to the old `arrayContains` query. If a legacy room exists, return it. Otherwise create the deterministic one. Remove the fallback after a release or two.

### 6.1 Six haversines ✅ (P3)

**Fix:** Create `core/utils/geo_math.dart` with `double haversineMeters(double lat1, double lng1, double lat2, double lng2)` plus a `LatLng` overload. Replace the copies in `turn_instruction.dart`, `privacy_zone_clipper.dart`, `place_repository.dart`, `ride_resume.dart`, `geohash_utils.dart`, and `motion_calculator.dart`. Keep one test file for it.

### 6.2 Gyro heading sign ✅, plus an axis problem (P2)

**Evidence:** `vehicle_state_estimator.dart:132-144` uses raw `gz` as yaw and **adds** it to a clockwise compass heading. A positive `gz` is counter-clockwise (right-hand rule), which is a left turn, so the heading goes the wrong way. It is also only correct for a **flat, screen-up** phone. Handlebar mounts are near-vertical, where yaw is mostly on the device Y axis.
**Fix:** Project the gyro onto the "up" axis. Keep a low-passed gravity vector from `accelerometerEventStream` (not `userAccelerometer`); at rest it points up:
```dart
final up = _gravity.normalized();                 // from accelerometer LPF
final yawRateCcw = gx*up.x + gy*up.y + gz*up.z;   // rad/s, CCW about up
final deltaDeg = -yawRateCcw * dt * 180 / pi;     // compass heading is CW
```
Verify on a device: rotate the mounted phone clockwise by 90° while stationary and assert the heading increases by about 90°. Until then, raise `headingGpsWeight*` so GPS dominates.

### 6.3 Pothole read as braking before calibration ✅ (P2)

**Evidence:** `accel_axis_calibrator.dart:19-25` falls back to the dominant axis with full magnitude.
**Fix:** Before `isCalibrated`, don't raise IMU brake or accel events at all. Let the GPS path do it (this ties into §1.3's single owner). If a pre-calibration estimate is still needed, remove the gravity-aligned (vertical) component first and use the horizontal magnitude only.

### 7.2 iOS auto-tracking ✅ (P3)

**Fix:** Bangladesh is overwhelmingly Android, so **hide the auto-tracking toggle on iOS** (`Platform.isIOS`) with the note "Available on Android". Revisit later with a native `CLLocationManager.startMonitoringSignificantLocationChanges` plus `CMMotionActivityManager` plugin. The constant `significant_location_change` already exists in `auto_detection_dao.dart:18` as a placeholder.

### 1.1 Deleting a bike wipes its ride history ✅ (P1)

**Evidence:** `core/database/daos/bike_dao.dart:41-57` deletes `ride_points`, `rides`, logs, and configs. `cloud_repository.dart:48-62` deletes the cloud rides. The dialog at `bike_detail_screen.dart:238` warns "All ride history for this bike will be deleted."
**Fix: archive by default.**
1. Migration: `ALTER TABLE bikes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0` (and the same field in Firestore).
2. Replace the delete dialog with two options:
   - **"Archive bike (keep rides)"**, the default and primary button: sets `archived=1` and hides the bike from the garage and bike pickers, but keeps rides attributed so stats and history stay intact.
   - **"Delete bike and all its rides"**, a destructive secondary action that requires typing the bike name.
3. `garageProvider` filters `archived = 0`. The all-rides and stats screens still show rides from archived bikes, labeled "(archived)".
4. Add an "Archived bikes" section in the garage with Unarchive.
5. The hard-delete path keeps the current code, plus the chunked remote delete from §1.3.3.

### 1.3 Account deletion incomplete ✅ (P2, Blaze-gated)

**Evidence:** `functions/src/account-deletion.ts:38-41` lists the gaps itself. Counter decrements and Cloudinary cleanup are missing.
**Fix (after Blaze):**
1. Decide anonymize vs delete for forum posts, replies, reviews, and comments. Recommendation: **anonymize** (`authorId → 'deleted'`, name "Deleted rider") to keep threads coherent.
2. In the function, paginate with `collectionGroup` queries per UGC type (≤400 per batch).
3. For each deleted follow edge, `FieldValue.increment(-1)` the counterpart's `followerCount`/`followingCount`.
4. Delete Cloudinary assets by prefix with the Admin API: `avatars/{uid}`, `rideShares/{uid}`, `voiceNotes/...`. This requires uploads to use uid-scoped folders; enforce that in §1.4.4.
5. Until Blaze: disclose in the delete-account screen what is kept, and offer an email request path, which Apple accepts as long as deletion is initiated in-app.

### 2.1 Outbox: no dead-letter; replays across accounts ✅ (P1)

**Evidence:** `outbox_service.dart:294-307` shows the catch retries forever. `outboxBackoff` caps the exponent at 10 (`:57`). `drain()` (`:253-265`) replays **every** due entry regardless of the signed-in user.
**Fix:**
1. `drain()` skips entries whose payload uid (`userId` or `uid`) ≠ `FirebaseAuth.instance.currentUser?.uid`. Leave them untouched; don't count an attempt.
2. Classify errors. Treat `FirebaseException.code in {'permission-denied','invalid-argument','not-found','failed-precondition'}` as **permanent**. After 3 attempts with a permanent code, or 20 attempts of any kind, move the entry to `status='dead'` (new column) instead of retrying.
3. Surface dead entries in Settings → "Sync issues" with Retry and Discard. `pendingCount` should exclude dead entries.
4. Tests: (a) a permission-denied entry dies after 3 attempts; (b) user A's entry is not attempted while B is signed in.

### 3.1 OSM tile policy and no offline tiles ✅ (P1, policy)

**Evidence:** Eight `TileLayer`s hit `https://tile.openstreetmap.org` directly (active ride, summary, shared detail, group ride, route nav, location picker, full-screen map, ride route map). There is no tile cache package in `pubspec.yaml`.
**Fix:**
1. Centralize: create `shared/widgets/app_tile_layer.dart` returning the one configured `TileLayer`, and replace all 8 call sites.
2. Switch the provider to a hosted tile service with a free tier (MapTiler, Stadia, Thunderforest, or Protomaps PMTiles on your own CDN). Keep the key in `--dart-define` and restrict it by app package in the provider's dashboard. Keep the OSM attribution widget.
3. Add a caching tile provider: `flutter_map_cache` plus `dio_cache_interceptor_file_store` (or `flutter_map_tile_caching` for region downloads), with a 30-day max-stale policy. Later, add a "Download this area for offline" action on routes.

### 3.2 Nearby places downloads everything ✅ (P2)

**Evidence:** `place_repository.dart:159-175` calls `getAllPlaces()` and then filters in Dart. Places already store `geohash` (`places_provider.dart:129`).
**Fix:** Query by geohash ranges. For a 5 km radius use precision 5 (~4.9 km cells): the center cell plus its 8 neighbors (`GeohashUtil` already has neighbors). Run 9 `where('geohash', isGreaterThanOrEqualTo: h).where('geohash', isLessThan: h + '~')` queries in parallel, dedupe, then do the exact haversine filter. Add a composite index (`category`, `geohash`) in `firestore.indexes.json`. Test with an in-memory fake that asserts places 50 km away are never fetched.

### 3.3 OSM import is sequential and attributed to the importer ✅ (P3)

**Evidence:** `places_provider.dart:122-136`.
**Fix:**
- Write with `WriteBatch` chunks of 400 (use `doc()` ids).
- Set `createdBy: 'osm-import'` and `importedBy: uid`, and have `getPlacesByOwner` keep using `createdBy`. Update rules to allow `createdBy == 'osm-import'` only when `osmId` is present, and require `importedBy == request.auth.uid`.
- Better long-term: use a deterministic doc id `osm_{osmId}` so duplicate imports are idempotent and `getExistingOsmIds` becomes unnecessary.

### 3.4 No GPX import ✅ (feature) and the cast issue 🟡 (see §1.3.4)

**Fix:** Add `core/cloud/gpx_import_service.dart` using the `gpx` or `xml` package. Use `file_picker` for `.gpx`, parse `trkpt`/`rtept`, simplify (Douglas-Peucker to ≤2,000 pts), and save it as a personal route through the existing route repository. Register an Android intent filter for `application/gpx+xml` so "Open with ThrottleIQ" works.

### 4.1 Idle time counted as moving ✅ (P2)

**Evidence:** `ride_recording_provider.dart:536-539` adds the whole gap (≤60 s) whenever the **current** fix is moving.
**Fix:** For gaps longer than a normal interval (> 3 s), attribute moving time by distance rather than by endpoint speed:
```dart
if (gapMs <= 3000) {
  if (speedMs >= moving) _movingMilliseconds += gapMs;
} else if (gapMs <= _maxMovingGapSeconds * 1000) {
  final prevMoving = (_lastPoint?.speedMs ?? 0) >= moving;
  if (prevMoving && speedMs >= moving) {
    _movingMilliseconds += gapMs;                         // moving the whole time
  } else {
    final avg = ((_lastPoint?.speedMs ?? 0) + speedMs) / 2;
    final est = avg > 0 ? (distDelta / avg * 1000).round() : 0;
    _movingMilliseconds += est.clamp(0, gapMs);           // only the part explained by distance
  }
}
```
Test: a 50 s gap with 0 → 5 m/s and 10 m of distance adds about 4 s, not 50 s.

### 5.2 Portrait lock ✅ (P3). See UI 1.5.

**Evidence:** `main.dart:32-35`.
**Fix:** Keep portrait app-wide. Allow landscape **only on the active ride and route navigation screens**: call `SystemChrome.setPreferredOrientations([...all])` in `initState` and restore portrait in `dispose`. Then build the landscape layout (UI 1.5). Don't unlock globally before the layouts exist, or the other 40 screens will break.

### 5.3 Home widget sums in Dart ✅ (P3)

**Evidence:** `core/services/home_widget_service.dart:437-440`.
**Fix:** Add `RideDao.totalsForUser(uid)`: `SELECT COUNT(*) c, COALESCE(SUM(distance_m),0) d FROM rides WHERE user_id=? AND status IN ('completed','crash')`. Also add `weeklyDistanceM(uid, since)` with `start_time >= ?`. Make sure there is an index on `rides(user_id, start_time)`.

### 6.1 No CI ✅ (P1)

**Evidence:** `.github/` does not exist.
**Fix:** Add `.github/workflows/ci.yml`:
```yaml
name: ci
on: [push, pull_request]
jobs:
  flutter:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: app } }
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
  rules:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm i -g firebase-tools
      - run: ./scripts/test/rules/run.sh   # adjust to the actual rules test entrypoint
  functions:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: functions } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci && npm run build
```
Pin the Flutter version to match local. Protect `main`/`master` with required checks.

### 6.2 Keystore on one laptop ✅ (**P0, do today, 10 minutes**)

**Evidence:** `throttleiq-release.keystore` is at the repo root and gitignored (`.gitignore:93`), as are `app/android/key.properties`, `secret/`, and `secrets/`.
**Fix:**
1. Confirm **Play App Signing** is enabled (Play Console → Setup → App integrity). If it is, the file is only the *upload* key, and a lost one can be reset through Play support. If not, enable it now.
2. Put the keystore, the passwords from `key.properties`, `secrets/*.json`, and `secret/creds.txt` into a password manager vault (1Password/Bitwarden secure file). Also keep an encrypted offline copy, e.g. `age`/`gpg` on a USB drive.
3. For CI release builds later, store the keystore as a base64 GitHub Actions secret.
4. Move the keystore **out of the repo working tree** (e.g. `~/keys/`) and point `key.properties` at the absolute path. One `git add -f` mistake away is too close.

### 1.3 North-up map, non-directional marker ✅ (P2)

**Evidence:** `active_ride_screen.dart:56` and `route_navigation_screen.dart:125` call `.move(...)` only, with no `rotate`. The route-nav `Icons.navigation` marker (`:221`) is not rotated.
**Fix:**
- Add a "heading-up / north-up" toggle, default heading-up during navigation.
- On each fix with speed > 3 m/s, call `_mapCtrl.moveAndRotate(pos, zoom, -headingDeg)`. Use `vehicleState.headingDeg`, or GPS `pos.heading` until §1.6.2 is fixed.
- When stopped, freeze the rotation so the map doesn't spin.
- In north-up mode, wrap the marker in `Transform.rotate(angle: heading * pi / 180)`.

### 1.4 No voice turn guidance ✅ (P2)

**Fix:** Add `flutter_tts`. In `route_navigation_screen.dart`, speak at thresholds of 500 m, 200 m, and 50 m per step (track "already announced" per step). Configure `audio_session` with `duck others` so music and intercom duck. Add a mute toggle. Provide Bangla phrases where the TTS engine supports `bn-BD`, falling back to English.

### 1.5 Landscape layout ✅ as design debt, but it currently can't overflow because of the portrait lock (P3)

**Fix:** After §2.5.2 unlocks these two screens, use an `OrientationBuilder`. In landscape: `Row(map: flex 3, cluster: flex 2)`, with the cluster showing speed, distance, time, lean, and the end/pause controls stacked.

### 1.6 Pause scrim dims the stats ✅ (P2)

**Evidence:** `active_ride_screen.dart:543-551` places a full-screen `0xCC000000` overlay above the speed panel.
**Fix:** Move the scrim in the `Stack` so it sits **directly above the map layer only**, below the top bar and speed panel. Keep the amber PAUSED pill (`_StatusPill`). One reorder, no new widgets.

### 2.3 Maintenance screen has no back button; bike detail has no maintenance section ✅ (P2)

**Evidence:** `maintenance_screen.dart` has no `AppBar`. `bike_detail_screen.dart` has no maintenance reference.
**Fix:**
- Give `MaintenanceScreen` an `AppBar`. When `bikeId != null` and `context.canPop()`, show a back button.
- Add a "Service & maintenance" card in `BikeDetailScreen` showing the next due item and a "View all" link to `/home/maintenance?bikeId=`.

### 2.4 Add-bike redirects twice ✅ (P2)

**Evidence:** `add_edit_bike_screen.dart:181` does `pushReplacement('/home/maintenance/configure?...&isFirstTime=true')`, then `maintenance_config_screen.dart:125` does `context.go('/home/maintenance?...')`.
**Fix:**
1. After saving, `pop` back to the garage with a SnackBar: "Bike added. [Set service intervals]".
2. Keep the configure screen reachable from that action and from bike detail.
3. When `isFirstTime`, `pop()` back rather than `go()`.
4. Maintenance works with default intervals when no config exists; confirm the provider falls back to `SensorConstants` values.

### 2.6 Notification bell only on the Profile tab ✅ (P3)

**Evidence:** `NotificationBellButton` is used only in `garage_screen.dart`.
**Fix:** Add it to the Social and Record app bars. Also consider a badge on the Social bottom-nav icon driven by the same unread-count provider.

### 3.1 "Navigate" doesn't record ✅ (P1)

**Evidence:** `route_navigation_screen.dart` never touches `rideRecordingProvider`.
**Fix:** On "Navigate", call `rideRecordingProvider.notifier.startRide(routeId: route.id)` (add an optional `routeId` column to `rides`). Better: render the route polyline inside `ActiveRideScreen` when `state.ride.routeId != null` and retire the separate nav screen's map, so there is one cockpit with one crash pipeline. Minimum step: start a recording from the nav screen and stop it on exit, with a confirm.

### 4.2 Default theme fails WCAG AA ✅ (P1, one line)

**Evidence:** The default appearance is Calming/Light (`core/theme/theme_style_provider.dart:40,160`). `calmingLight.primary = #84A98B` (`core/theme/app_theme_style.dart:345`). Button foreground is white (`app_theme.dart:165-167`). The contrast I computed is **2.62:1** (AA needs 4.5).
**Fix:** In `calmingLight`, swap `primary` to its own `primaryDark: #537D5C` (4.71:1 with white, and it stays in the same hue family). Then make the old `#84A98B` the `primaryHighlight` for non-text fills. Add a unit test that computes the contrast of `primary` vs the button foreground for **every** palette and asserts ≥ 4.5.

### 4.5 24 dp close target ✅ (P3)

**Evidence:** `tour_floating_banner.dart:130-138`.
**Fix:** `IconButton(icon: Icon(Icons.close, size: 20), constraints: BoxConstraints.tightFor(width: 48, height: 48), onPressed: …)`.

### 5.2 Network errors shown as "private profile" ✅ (P3)

**Evidence:** `user_profile_screen.dart:116-124` shows "This profile is private" for **any** error.
**Fix:** Branch on the error: `FirebaseException(code: 'permission-denied')` → "This profile is private". `unavailable`/timeouts → "You're offline" with a Retry button that calls `ref.invalidate(profileProvider(uid))`. Anything else → "Couldn't load profile" with Retry.

### 5.3 Add Place falls back to Dhaka ✅ (P2)

**Evidence:** `features/poi_directory/presentation/screens/add_place_screen.dart:22,141` shows `_pickedLocation ?? _fallbackCenter` used on **save**.
**Fix:** Keep the fallback for the map's *initial camera* only. On save, `if (_pickedLocation == null) { show "Pick the location on the map"; return; }`. Initialize `_pickedLocation` from `currentPositionProvider` when available.

### 5.4 SafeQR has no export ✅ (P2)

**Evidence:** `features/profile/presentation/screens/safe_qr_screen.dart` renders a `QrImageView` (`:114`) with no share or save action.
**Fix:**
- Wrap the QR card in a `RepaintBoundary(key: _qrKey)`, then `toImage(pixelRatio: 4)` → PNG → temp file → `Share.shareXFiles([XFile(path)])` (`share_plus` is already a dependency).
- Also offer "Print sticker": render a PDF with the `printing` package, using a 5×5 cm sticker layout that includes "SCAN IN EMERGENCY / জরুরি অবস্থায় স্ক্যান করুন".

### 6.1 Bangla localization ✅ (P2)

**Evidence:** 38 `*_screen.dart` files have no `AppLocalizations`/`l10n` usage, including login, register, onboarding, active ride, record, garage, all maintenance screens, places, routes, chat, and forums.
**Fix, in order of safety impact:**
1. The crash countdown overlay (`active_ride_screen.dart:700-760`) and the crash notification text in `notification_service.dart`.
2. The active ride and route navigation screens.
3. Onboarding, login, and register.
4. The rest.

Add a CI check: a test that fails if a new `*_screen.dart` has string literals in `Text('…')` without l10n. Use a simple regex allowlist to start.

### 6.3 Emergency contacts create false security ✅ (P0, copy change)

**Fix:**
- Until §1.2.1 ships, the Emergency Contacts section header should read: "⚠️ ThrottleIQ does not yet alert these contacts automatically."
- Use a warning-colored banner, not fine print.
- Show a one-time acknowledgement dialog when the first contact is added.

### 4.1 Crash detector can't fire ✅. Engineering fix in §1.1.1. Claim hygiene is P0.

**Evidence:** Same as §1.1.1. The pitch claims it: `DOCS/General/marketing/iDEA_PITCH_SUBMISSION.md:36,76,107`.
**Budget-phone ±2/4 g claim:** ⚪, overstated. Most current Android accelerometers default to ±8 g or ±16 g, but saturation on cheap phones is plausible. The saturation handling in §1.1.1 covers it either way.
**Fix:** Until field validation passes, rewrite the pitch, the store listing, and the posters. Say "crash-detection **in development / beta**", or lead with maintenance and ride logging as the grill suggests. Replace the claims at lines 36 and 76 and the comparison table row at 107.

### 4.2 Team roster ✅ (P0 for the grant)

**Evidence:** Slide 9 (`iDEA_PITCH_SUBMISSION.md:233-242`) lists an Embedded & Sensor Systems Lead, a Growth Lead, and an Advisory Panel. The video script (`gov-pitch/Part-2-Video-Pitch-Script.md:11`) requires "Founder/CEO, Tech Lead, Growth Lead" on camera. Every commit author in `git log` is the founder under different identities, plus one `blankframe-tech` commit.
**Fix:**
- If those people are real and committed, add their names and roles and get their consent and NIDs ready.
- If not, rewrite Slide 9 as "Solo technical founder; grant funds hire (1) embedded/sensor engineer, (2) growth lead". Put those roles in the fund-utilization table and edit the video script to a single presenter.

### 4.4 Distribution funnel ✅ (P0)

**Evidence:** `DOCS/General/marketing/marketing_lead_notes/NEEDS_YOUR_ATTENTION.md` §1 says the Play internal track has zero testers, and §3 says `website_demo/` has no deploy target (`firebase.json` Hosting serves `public/`).
**Fix (founder actions, 1 hour total):**
1. In Play Console → Internal testing → Testers, create an email list of 20+ riders and share the opt-in link.
2. Deploy the site. Either add a second Hosting target (`firebase target:apply hosting site website_demo` plus a `hosting` array entry in `firebase.json`; Hosting works on Spark), or copy `website_demo/` into `public/` if a single site is fine. Point every outreach template at that URL and the Play opt-in link, not GitHub.

### 4.5 Bangla-first mismatch ✅. See §3.6.1.

### 4.7 Legal/privacy items ✅. Engineering fixes in §1.2.1, §1.4.4, §1.4.5, §3.6.3.

In addition, update the Play **Data Safety** form: audio (voice notes), precise location, health info (SafeQR medical data stays on-device; declare it if it is ever synced), and crash logs.


