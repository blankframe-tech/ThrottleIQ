# ThrottleIQ Hard Critique: The Overlooked Architectural, Data & Hardware Gaps
**Document:** `ANTIGRAVRITY_GRILL/other_gaps.md`  
**Date:** September 20, 2026  
**Auditor:** Antigravity Agentic Review  
**Scope:** Forensic examination of unaddressed weaknesses across data pipelines, offline durability, map tile streaming, audio routing, background automation, security rules, and DevOps infrastructure.

---

## Executive Summary: "The Unexamined Fault Lines"

The preceding audits in `ANTIGRAVRITY_GRILL/` rigorously exposed the non-functional 8g crash detection threshold (`codebase.md`), the phantom co-founders and non-existent payment rails (`bussness.md`), and the cockpit ergonomic hazards (`UI_UX.md`).

However, beneath those headline issues lies a secondary tier of systemic engineering vulnerabilities, data destruction traps, and platform liabilities that have gone completely unmentioned.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                       THE UNEXAMINED DISCONNECT                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  DOCUMENTED CLAIM / INTENT                ACTUAL CODEBASE REALITY            │
│                                                                              │
│  "Retire or switch bikes freely"          Deleting a bike cascade-deletes    │
│                                           all lifetime rides and GPS tracks. │
│                                                                              │
│  "Offline-first motorcycle mapping"       Zero tile caching. OSM streaming   │
│                                           breaks upstream policy & turns     │
│                                           into a blank grey grid offline.    │
│                                                                              │
│  "Push-to-talk group intercom"            just_audio API misuse cuts audio   │
│                                           within 10ms; clips never play.     │
│                                                                              │
│  "Durable offline outbox"                 Only 3 calls are buffered; poison  │
│                                           pills retry indefinitely forever.  │
│                                                                              │
│  "Crash alert SOS dispatch"               Bypasses outbox; a network drop    │
│                                           in a dead zone discards the alert! │
│                                                                              │
│  "Intelligent auto-ride detection"        CNG/bus/taxi commutes inflate bike │
│                                           odometers; service leaks on logout.│
│                                                                              │
│  "Enterprise code quality (1,038 tests)"  Zero CI/CD pipelines. Release      │
│                                           keystore exists only on one laptop.│
└──────────────────────────────────────────────────────────────────────────────┘
```

Here is the unvarnished analysis of the weaknesses and blind spots that were left out of the other audit documents.

---

## 1. Data Loss, Retention & Deletion Bombs

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

### 1.2 `liveSessions` Deletion Lock & Timestamp Type Corruption
* **Code Reference:** [`firestore.rules:478-484`](file:///Users/blackbird/Everything/dev/ThrottleIQ/firestore.rules#L478-L484) & [`live_session_coordinator.dart:181-188`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/helpers/live_session_coordinator.dart#L181-L188)
* **The Flaw:**
  1. In `firestore.rules`:
     ```javascript
     match /liveSessions/{token} {
       allow get: if resource.data.get('shareable', false) == true && ...;
       allow create: if request.auth.uid == request.resource.data.uid;
       allow update: if request.auth.uid == resource.data.uid;
     }
     ```
     **Notice there is NO `allow delete` rule.** If a rider accidentally shares their live link with an unauthorized person, or ends a ride and wishes to immediately revoke tracking access, the client **physically cannot delete the live tracking document**. It must sit active until the 24-hour TTL window expires.
  2. In `live_session_coordinator.dart:186`, status updates write:
     `'updatedAt': DateTime.now().toIso8601String()` (a plain String), whereas `toFirestore()` explicitly documents that TTL policies only trigger on real Firestore `Timestamp` objects. Updating a live session status corrupts the document's timestamp type.

### 1.3 Incomplete Account Deletion (Apple Guideline 5.1.1(v) & GDPR Failure)
* **Code Reference:** [`account-deletion.ts:38-41, 83-92`](file:///Users/blackbird/Everything/dev/ThrottleIQ/functions/src/account-deletion.ts#L38-L41)
* **The Flaw:**
  - Even if the Cloud Functions backend were deployable (it is currently blocked by Spark billing), `onUserAccountDeleted` explicitly admits in its own header comments:
    *`Still NOT covered: community content the rider authored inside other people's spaces (forum posts/replies, place reviews, comments on others' rides, group-ride membership, chats).`*
  - Cloudinary assets (the user's profile avatar, uploaded ride photos, and push-to-talk voice recordings) are **never deleted**.
  - When follows are deleted in `account-deletion.ts:90-91`, the `followerCount` and `followingCount` counters on other riders' profiles are never decremented.
  - Deleting an account leaves orphaned forum posts, hanging UGC, dangling storage files, and permanently corrupted profile statistics across the user base. Apple App Store reviewers routinely test account deletion by inspecting leftover public assets; this will trigger immediate rejection.

---

## 2. Offline-First Architectural Illusions & Outbox Traps

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

### 2.2 The 80% Unbuffered Outbox Coverage Gap
* **Code Reference:** [`outbox_service.dart:18-31`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/cloud/outbox_service.dart#L18-L31)
* **The Flaw:**
  - ThrottleIQ markets itself on its robust transactional offline outbox.
  - However, `OutboxKind` only supports three things: `share_ride`, `live_session_teardown`, and `maintenance_log`.
  - **Every other cloud write in the application bypasses the outbox entirely:**
    - Adding or replying to forum threads ([`forum_repository.dart:75`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/forums/data/repositories/forum_repository.dart#L75) uses `runTransaction` directly, which crashes when offline).
    - Upvoting, downvoting, or liking shared rides and forum posts.
    - Adding places or submitting reviews in the POI directory.
    - Sending direct chat messages ([`chat_room_screen.dart:496`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/chat/presentation/chat_room_screen.dart#L496) clears text input and fires unbuffered Firestore writes).
    - Following or unfollowing other riders.
  - If a rider goes on a remote tour without cellular data, 80% of the app's interactive features freeze, throw unhandled network errors, or drop user input.

### 2.3 Emergency Crash Alert Bypasses the Outbox (Cellular Dead-Zone Abandonment)
* **Code Reference:** [`crash_coordinator.dart:88-109`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/helpers/crash_coordinator.dart#L88-L109)
* **The Flaw:**
  ```dart
  await _bestEffortWrite(
    'crash notification',
    () => _firestore.collection('crashNotifications').add({
      'uid': uid,
      'rideId': rideId,
      'status': 'pending',
      ...
    }),
  );
  ```
  - While mundane ride sharing uses the durable SQLite outbox, **emergency crash alert dispatch does NOT use `OutboxService`**.
  - It relies on `_bestEffortWrite`, which applies a strict 8-second timeout (`kOutboxAttemptTimeout`).
  - If a rider crashes in a mountain pass, a rural road, or an underpass with zero cellular coverage, the emergency dispatch times out after 8 seconds and is **permanently discarded**. It is not queued to SQLite, and it will never be retried when the phone reconnects to a cell tower.
  - The single feature where guaranteed, durable delivery is life-critical is the one feature built without durability!

---

## 3. Maps, POI & Navigation Infrastructure

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

---

## 4. Telemetry Calculation & Sensor Drift Realities

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

### 4.2 Auto-Tracking Commute Contamination & Persistent Service Leak on Logout
* **Code Reference:** [`auto_tracking_service.dart:65-67`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/services/auto_tracking_service.dart#L65-L67) & [`auth_provider.dart:131-137`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/auth/presentation/providers/auth_provider.dart#L131-L137)
* **The Flaw:**
  1. `_isVehicleLike` treats `ActivityType.IN_VEHICLE` and `ActivityType.ON_BICYCLE` as motorcycle rides. If a rider rides a bicycle, takes a public bus, rides in an Uber, or travels by train, the background tracker wakes up and logs fixes.
  2. On next launch, `AutoRideReconcilerService` automatically promotes the trip to the active motorcycle in the garage, increments the bike's odometer, and reduces oil-change intervals based on a bus ride!
  3. When a user taps "Sign Out" ([`auth_provider.dart:131`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/auth/presentation/providers/auth_provider.dart#L131)), `AutoTrackingService.stop()` is **never called**. The foreground task keeps running, logging fixes while unauthenticated, and attributes them to the next user who signs in on that device.

### 4.3 Open-Meteo Weather Local vs. UTC Timezone Offset Skew
* **Code Reference:** [`weather_service.dart:55-69`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/services/weather_service.dart#L55-L69)
* **The Flaw:**
  - `fetchForRide` queries Open-Meteo with `timezone=auto`. The API returns an array of timestamps in local solar time (e.g. `2026-09-20T14:00`).
  - The comparison loop compares `t.difference(at).abs()`, where `at` is the device's recorded timestamp.
  - If `at` was generated or stored as a UTC `DateTime` while Open-Meteo's strings are parsed as local, the comparison suffers from a 6-hour timezone offset (in Bangladesh, UTC+6). A ride completed at 2:00 PM will match weather conditions from 8:00 PM or 8:00 AM.

---

## 5. Audio, Hardware & Platform Constraints

### 5.1 Push-To-Talk Voice Notes are Dead-On-Arrival (`just_audio` Execution Race)
* **Code Reference:** [`group_ride_map_screen.dart:340-354`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/social/presentation/screens/group_ride_map_screen.dart#L340-L354)
* **The Smoking Gun:**
  ```dart
  try {
    await session.setActive(true);
    await _voicePlayer.setUrl(note.audioUrl);
    await _voicePlayer.play();
  } catch (_) {
  } finally {
    await _deactivateVoiceAudioSession();
    if (mounted) setState(() { _isPlayingVoiceNote = false; });
    unawaited(_playNextVoiceNote());
  }
  ```
* **The Reality Check:**
  - In `just_audio`, `AudioPlayer.play()` is a `Future<void>` that completes **as soon as the audio starts playing**. It does NOT await playback completion.
  - Because of this, execution jumps into the `finally` block **within 10 milliseconds of the audio starting**!
  - `_deactivateVoiceAudioSession()` immediately executes:
    ```dart
    await session.setActive(false, avAudioSessionSetActiveOptions: ...notifyOthersOnDeactivation);
    ```
  - This immediately terminates the audio session on iOS/Android, cutting off the voice note before the first syllable is heard!
  - It then calls `_playNextVoiceNote()`, causing the queue to rapidly skip through all incoming audio clips in a fraction of a second.
  - **Group ride push-to-talk voice playback is 100% broken in production.**

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

---

## 6. DevOps, Infrastructure & Release Pipeline Gaps

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

---

## Prioritized Remediation Roadmap

```
REMEDIATION MATRIX
┌─────────────────────────────────────────────────────────────────────────────┐
│ P0: DATA INTEGRITY & CRITICAL FIXES     P1: ARCHITECTURE & DURABILITY       │
│ - Fix just_audio playback completion    - Wire Outbox to crash notifications│
│ - Stop cascade-deletion of rides on     - Add max retry/poison quarantine   │
│   bike delete (detach bike_id instead)    to OutboxService                  │
│ - Add allow delete to liveSessions      - Integrate tile caching provider   │
│                                           (flutter_map_cache)               │
│                                                                             │
│ P2: SCALABILITY & ACCURACY              P3: DEVOPS & COMPLIANCE             │
│ - Replace whole-DB scan in Places       - Establish GitHub Actions CI/CD    │
│   with Geohash bounding box query       - Back up signing keystore          │
│ - Stop auto-tracking service on logout  - Implement GPX file import         │
│ - Fix GPS gap idle-time accumulation    - Enable landscape window support   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: P0 Immediate Data & Audio Fixes (Days 1–3)
1. **Fix `just_audio` Playback Completion:**
   In [`group_ride_map_screen.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/social/presentation/screens/group_ride_map_screen.dart), await player state completion (`await _voicePlayer.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed)`) before deactivating the audio session.
2. **Prevent Ride Annihilation on Bike Delete:**
   In [`bike_dao.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/database/daos/bike_dao.dart), remove `txn.delete('rides')` and `txn.delete('ride_points')`. Instead, set `bike_id = 'unassigned'` or add an `is_archived = 1` flag to the bike.
3. **Allow `liveSessions` Deletion in Rules:**
   In [`firestore.rules`](file:///Users/blackbird/Everything/dev/ThrottleIQ/firestore.rules), add `allow delete: if request.auth.uid == resource.data.uid;` to `match /liveSessions/{token}`.

### Phase 2: P1 Outbox Durability & Map Caching (Days 4–7)
1. **Route Emergency Notifications through Outbox:**
   In [`crash_coordinator.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/features/ride/presentation/providers/helpers/crash_coordinator.dart), replace `_bestEffortWrite` with a dedicated `OutboxKind.crashNotification` so an emergency alert survives cellular dead zones.
2. **Add Outbox Poison-Pill Quarantine:**
   In [`outbox_service.dart`](file:///Users/blackbird/Everything/dev/ThrottleIQ/app/lib/core/cloud/outbox_service.dart), discard or quarantine entries after 10 failed attempts or when receiving a permanent `permission-denied` error.
3. **Implement Tile Caching:**
   Integrate `flutter_map_cache` with a local SQLite or file-system cache store on `TileLayer` to prevent blank screens in offline areas and comply with OSM terms.

### Phase 3: P2 Scalability & Sensor Precision (Days 8–12)
1. **Geohash Bounding Queries:**
   Refactor `PlaceRepository.getNearbyPlaces` to query Firestore using geohash prefix ranges rather than downloading all places globally.
2. **Halt Auto-Tracking on Sign Out:**
   In `auth_provider.dart:signOut()`, explicitly invoke `AutoTrackingService.instance.stop()` to prevent cross-account trip leakage.
3. **Fix GPS Gap Moving Time:**
   In `ride_recording_provider.dart:536`, interpolate or require continuous fixes before assigning gap durations to moving time.

### Phase 4: P3 Platform & DevOps Hardening (Days 13–18)
1. **GitHub Actions Workflow:**
   Create `.github/workflows/ci.yml` running `flutter analyze`, `flutter test`, and `scripts/test/rules/` on every push and PR.
2. **Unlock Landscape Orientation:**
   In `main.dart`, permit `DeviceOrientation.landscapeLeft` and `landscapeRight` so riders can use horizontal mounts.
3. **GPX Import Support:**
   Add a GPX parsing utility to `export_service.dart` or a new `gpx_service.dart` to allow loading external routes.
