# ThrottleIQ Hard Critique: The Unvarnished Architectural & Engineering Audit

> **Target:** ThrottleIQ (Offline-first motorcycle telemetry intelligence & vehicle state estimation engine)  
> **Auditor:** Antigravity Agentic Review  
> **Date:** September 20, 2026  
> **Baseline:** 1,038 passing unit tests, zero static analysis issues, production Dart/TypeScript source.

---

## Executive Summary: "Green Tests, Red Reality"

ThrottleIQ presents itself as a sophisticated, offline-first motorcycle telemetry platform with vehicle state estimation, high-g crash detection, privacy-preserving spatial clipping, and deterministic cloud synchronization. Its automated test suite boasts 1,038 passing tests, clean architecture layering, and zero lint warnings.

However, a forensic examination of the production code reveals an alarming gap between the documented claims and runtime execution. The project suffers from:
1. **Safety mechanisms that are mathematically incapable of triggering in real-world crashes.**
2. **Cloud Functions and emergency escalation pipelines that are 100% mocked and deployed to an incompatible Firebase billing tier.**
3. **Data synchronization pipelines with missing call-sites, leaving historical ride maps permanently blank upon reinstallation.**
4. **Privacy filters that leak exact home coordinates due to flawed geometric assumptions.**
5. **A theme management system relying on global mutable statics that nukes the entire Flutter widget tree on every appearance toggle.**
6. **Multi-tenant data leaks that bleed private trip data between users on shared devices.**

Here are the hard technical truths about the ThrottleIQ codebase.

---

## 1. Safety-Critical Telemetry & Crash Detection

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

---

## 2. Infrastructure, Cloud & Emergency Alert Failures

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

---

## 3. Data Integrity & Sync Architecture

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

### 3.4 Fatal `as double` Typecast Bombs
* **Code References:** [`save_route_screen.dart:55`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/routes/presentation/screens/save_route_screen.dart#L55), [`ride_share_screen.dart:67`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/social/presentation/screens/ride_share_screen.dart#L67), [`live_session_entity.dart:103-104`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/domain/entities/live_session_entity.dart#L103-L104), [`ride_summary_screen.dart:61`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/screens/ride_summary_screen.dart#L61)
* **The Flaw:** Raw casts like `p['lat'] as double` assume that numbers deserialized from SQLite or JSON are always Dart `double`. If SQLite or Firestore encodes an exact coordinate like `24` or `90` as an `int`, Dart throws:
  `_CastError (type 'int' is not a subtype of type 'double' in type cast)`
  This crashes the screen immediately instead of using `(p['lat'] as num?)?.toDouble()`.

---

## 4. Privacy & Security Vulnerabilities

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

---

## 5. Architectural & UI/UX Anti-Patterns

### 5.1 Global Mutable Statics & The Remounting Disaster
* **Code References:** [`app_colors.dart:16-23`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/constants/app_colors.dart#L16-L23) & [`app.dart:157-177`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/app.dart#L157-L177)
* **The Anti-Pattern:**
  - The codebase eschews `Theme.of(context)` and `ThemeExtension` in favor of static facades: `AppColors.background`, `AppDimensions.radiusMd`, `AppTypography.style`.
  - Because static getters cannot trigger reactive widget rebuilds, `app.dart` forces theme updates with:
    ```dart
    return MaterialApp.router(
      key: ValueKey(appearance),
      ...
    );
    ```
  - Toggling Dark/Light mode or selecting a color vibe **unmounts and remounts the entire application subtree**. This destroys active navigation stacks, uncommitted form inputs, text controllers, and scroll positions.

### 5.2 Chat Repository $O(N)$ Read Cost & Race-Condition Duplication
* **Code Reference:** [`chat_repository.dart:44-65`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/chat/data/repositories/chat_repository.dart#L44-L65)
* **The Flaw:**
  - `getOrCreateChat` executes `where('participants', arrayContains: currentUserId).get()`, downloading every chat document the user possesses just to find an existing match.
  - If two riders tap "Message" concurrently, both queries return empty, and both call `chats.add()`. This spawns **two distinct parallel chat rooms** between the same pair of users, bifurcating conversation history.
  - A deterministic document ID format like `[uidA, uidB].sort().join('_')` would eliminate both the query scan and the race condition.

### 5.3 Uncontrolled Stream Subscriptions in Chat Lists
* **Code Reference:** [`chat_list_screen.dart:95-104`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/chat/presentation/screens/chat_list_screen.dart#L95-L104)
* **The Flaw:** Inside `ListView.separated`'s `itemBuilder`, the code invokes `ref.watch(profileProvider(otherUserId))`. For a list of 50 chats, this instantiates 50 concurrent real-time Firestore document streams, triggering rapid quota depletion and UI stutter during scrolling.

### 5.4 Chat Bypasses User Blocks
* **Code Reference:** [`chat_list_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/chat/presentation/screens/chat_list_screen.dart) & [`chat_repository.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/chat/data/repositories/chat_repository.dart)
* **The Flaw:** While user profiles hide the "Message" button if a user is blocked, `ChatListScreen` and `ChatRoomScreen` contain zero checks against `blockedUsersProvider`. A blocked user can continue sending messages in pre-existing chat rooms, and their conversations remain visible in the inbox.

---

## 6. Algorithmic & Mathematical Gaps

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

---

## 7. Mobile Hardware & Battery Realities

### 7.1 Battery Drain & Thermal Throttling
* **Telemetry Stack:**
  - Continuous GPS with `LocationAccuracy.bestForNavigation` at 1 Hz.
  - Accelerometer stream at 20–50 Hz.
  - Gyroscope stream at 20–50 Hz.
  - Screen Wakelock active (`WakelockPlus.enable()`).
  - Active map rendering up to 2,000 polyline points, redrawn at 5 Hz.
  - Periodic Firestore live session publishing every 10 seconds.
* **Impact:** On mid-range hardware, this stack draws 25%–35% battery per hour. When mounted on a motorcycle handlebar under direct sunlight, thermal throttling will frequently dim the screen or force OS-level process termination.

### 7.2 iOS Auto-Tracking Impossibility
* **Code Reference:** [`auto_tracking_service.dart:29-37`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/services/auto_tracking_service.dart#L29-L37) & [`Info.plist:90-105`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/ios/Runner/Info.plist#L90-L105)
* **The Flaw:** `flutter_foreground_task` on iOS relies on standard background fetch. iOS executes background fetch arbitrarily (often hours apart). Without native `CLLocationManager.startMonitoringSignificantLocationChanges()` or persistent CoreMotion activity subscriptions, auto-tracking will practically never detect rides on iOS devices.

### 7.3 Unencrypted Local Database
* **Code Reference:** [`database_helper.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/database/database_helper.dart)
* **The Flaw:** SQLite database `throttleiq.db` is stored unencrypted without SQLCipher. Anyone with physical access to a rooted device or file extraction tools can recover the rider's complete historical GPS routes, timestamps, and home addresses.

---

## Priority Action Plan

1. **[CRITICAL] Repair Crash Detection Pipeline:** Route raw `UserAccelerometerEvent` peaks from `SensorFusionCoordinator` into `EventDetector` so mechanical impact shocks can trigger crash evaluation.
2. **[CRITICAL] Wire Track Downloads:** Call `CloudRepository.downloadRideTrack` in `RideSummaryScreen._loadPolyline` when local points are empty.
3. **[HIGH] Fix Privacy Zone Geometry:** Rewrite `PrivacyZoneClipper` to clip points within a 200m Euclidean radius circle from the origin.
4. **[HIGH] Replace Theming Subtree Remounting:** Migrate `AppColors` from static facades to standard Flutter `ThemeExtension` or `InheritedWidget`.
5. **[MEDIUM] Secure Cloudinary & Storage:** Transition to backend-signed uploads to prevent unauthenticated quota abuse.
6. **[MEDIUM] Upgrade Firebase Billing:** Enable Blaze plan to permit Cloud Functions deployment for crash alerts.
