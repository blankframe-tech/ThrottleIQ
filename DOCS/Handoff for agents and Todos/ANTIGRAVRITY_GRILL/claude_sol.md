# claude_sol.md: Verified Findings and Fix Instructions for the Antigravity Grill

**Date:** 2026-09-20
**Inputs:** `codebase.md`, `other_gaps.md`, `UI_UX.md`, `bussness.md` (this folder)
**Method:** I checked every claim against the code at `a0c906b` (master) by reading the cited files, running greps, and checking library source where behavior depended on a library (e.g. `just_audio` in `~/.pub-cache`). Many of the grill's file paths are stale. For example, `features/record/...` is really `features/ride/presentation/screens/...`, and `app_colors.dart` palettes live in `core/theme/app_theme_style.dart`. The corrected paths are given below.

**Cross-references:** `§<part>.<grill item>`. Part 1 is `codebase.md`, 2 is `other_gaps.md`, 3 is `UI_UX.md`, and 4 is `bussness.md`. For example, §1.2.2 is `codebase.md` item 2.2. All code paths are relative to `app/lib/` unless shown otherwise.

### Verdict legend

| Mark | Meaning |
|---|---|
| ✅ CONFIRMED | The defect exists as described. |
| 🟡 PARTIAL | The defect is real, but the mechanism, severity, or location is wrong. The real version is stated. |
| ❌ FALSE | The code does not behave this way, or the issue has already been fixed. No action needed, or only a doc correction. |
| ⚪ NOT CODE-VERIFIABLE | This is a business, legal, or market judgment or a hardware estimate. Treated as advice. |

---

## 0. Scoreboard (deduplicated, sorted by priority)

Several issues appear in more than one grill doc. Each appears here once, with its sources.

| # | Issue | Sources | Verdict | Priority |
|---|---|---|---|---|
| 1 | Crash detector can never fire (GPS-derived accel vs 80 m/s² threshold; IMU never reaches detector) | codebase 1.1, bussness 1 | ✅ | **P0** |
| 2 | Jerk "peak" is a running average | codebase 1.2 | ✅ | P0 (with #1) |
| 3 | Emergency SMS/email backend is a mock and undeployed (Spark) | codebase 2.1, bussness 6.1 | ✅ | **P0 (product/claims)** |
| 4 | Hard-brake/rapid-accel counters over-count (worse than the grill says) | codebase 1.3 | ✅ + new bug | P1 |
| 5 | Crash-status rides never sync; stats never written | codebase 2.2 | ✅ | P0 |
| 6 | `downloadRideTrack` never called, so maps are blank after reinstall | codebase 3.1 | ✅ | P1 |
| 7 | Track upload failure strands points forever | codebase 3.2 | ✅ | P1 |
| 8 | Deleting a bike wipes all its rides (local + cloud) | other_gaps 1.1 | ✅ | P1 |
| 9 | `deleteBikeRemote` >500-op batch and orphaned `track` subcollections | codebase 3.3 | ✅ | P1 (with #8) |
| 10 | Privacy clipper uses path distance, not radius | codebase 4.1 | ✅ | P1 |
| 11 | `auto_detections` have no owner, so another user's trips get attributed | codebase 4.2 | ✅ | P1 |
| 12 | Auto-tracking keeps running after sign-out | other_gaps 4.2(3) | ❌ (stopped in `app.dart:149`) | none |
| 13 | Bus/car/bicycle trips counted as motorcycle rides | other_gaps 4.2(1-2) | 🟡 | P2 |
| 14 | Live session stays readable after ride end; no delete rule | other_gaps 1.2 | 🟡 (real issue is `shareable` never cleared) | P1 |
| 15 | Outbox: no retry ceiling or dead-letter; not scoped to current user | other_gaps 2.1 | ✅ | P1 |
| 16 | Crash notification bypasses outbox | other_gaps 2.3 | 🟡 | P2 (moot until #3) |
| 17 | Push-to-talk playback cut off | other_gaps 5.1 | 🟡 (clip 1 plays fine; clips 2+ break) | P1 |
| 18 | GPS gap: idle time counted as moving time | other_gaps 4.1 | ✅ | P2 |
| 19 | Unsigned Cloudinary preset in binary | codebase 4.4, bussness 6.2 | ✅ | P2 |
| 20 | Voice notes are public URLs | codebase 4.5, bussness 6.3 | ✅ | P2 |
| 21 | Admin hardcoded by email | codebase 4.6 | ✅ | P3 |
| 22 | Follower audience is a frozen snapshot | codebase 4.3 | ✅ | P3 |
| 23 | Chat: O(N) lookup plus duplicate-room race | codebase 5.2 | ✅ | P2 |
| 24 | Chat list: one never-disposed profile stream per row | codebase 5.3 | 🟡 | P3 |
| 25 | Blocked users can still message | codebase 5.4 | 🟡 (rules already reject sends; UI doesn't reflect it) | P3 |
| 26 | Raw `as double` casts | codebase 3.4, other_gaps 3.4 | 🟡 (SQLite REAL paths are safe; Firestore paths are the risk) | P2 |
| 27 | `MaterialApp` remount on theme change | codebase 5.1, UI 4.1 | 🟡 (router location survives; ephemeral state doesn't) | P3 |
| 28 | Default theme primary fails WCAG AA (2.62:1) | UI 4.2 | ✅ | P1 (one-line) |
| 29 | Dark-on-red End Ride button unreadable | UI 4.3 | ❌ (dark surface on `#DC7672` is 5.41:1, passes AA) | none |
| 30 | Gyro heading sign / axis | codebase 6.2 | ✅ (plus an axis problem) | P2 |
| 31 | Calibrator fallback mistakes potholes for braking | codebase 6.3 | ✅ | P2 |
| 32 | Six duplicate haversines | codebase 6.1 | ✅ | P3 |
| 33 | `USE_FULL_SCREEN_INTENT` Play restriction | codebase 2.4 | ✅ | P1 (before Play production) |
| 34 | SafeQR unusable when locked; no export | codebase 2.3, UI 5.4 | ✅ | P2 |
| 35 | OSM tile servers used directly; no tile cache | other_gaps 3.1 | ✅ | **P1 (policy)** |
| 36 | Places "nearby" downloads the whole collection | other_gaps 3.2 | ✅ | P2 |
| 37 | OSM import is sequential and attributed to the importer | other_gaps 3.3 | ✅ | P3 |
| 38 | No GPX import | other_gaps 3.4 | ✅ (feature gap) | P3 |
| 39 | Weather UTC/local 6h skew | other_gaps 4.3 | ❌ in practice (only wrong when device timezone ≠ ride location) | P4 |
| 40 | Portrait lock / landscape cockpit | other_gaps 5.2, UI 1.5 | ✅ (lock is real; the overflow can't happen *because* of the lock) | P3 |
| 41 | Home widget sums rides in Dart | other_gaps 5.3 | ✅ | P3 |
| 42 | No CI | other_gaps 6.1 | ✅ | P1 |
| 43 | Release keystore exists only on the laptop | other_gaps 6.2 | ✅ | **P0 (do today)** |
| 44 | Account deletion incomplete | other_gaps 1.3 | ✅ | P2 (Blaze-gated) |
| 45 | Outbox covers only 3 kinds | other_gaps 2.2 | 🟡 (Firestore's own offline queue covers most "freeze" claims) | P3 |
| 46 | iOS auto-tracking impractical | codebase 7.2 | ✅ | P3 (hide on iOS) |
| 47 | Unencrypted SQLite | codebase 7.3 | 🟡 (`allowBackup=false` already set; rooted-device only) | P4 |
| 48 | Battery 25-35%/h | codebase 7.1 | ⚪ | measure |
| 49-68 | UI/UX items | UI_UX.md | see §3 | P1-P3 |
| 69-75 | Business/pitch items | bussness.md | see §4 | P0 for the pitch |

---

## 1. `codebase.md`: Verification and Fixes

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

### 3.4 Raw `as double` casts 🟡 (P2)

**Evidence:** There are 15 sites (`grep -rn "as double\b" lib | grep lat`), including `ride_summary_screen.dart:78`, `ride_share_screen.dart:67`, `save_route_screen.dart:55`, `export_service.dart:131-132`, `ride_persistence_coordinator.dart:147-156`, `ride_share_model.dart:143`, `route_model.dart:58`, `group_ride_model.dart:259`, and `live_session_entity.dart:103-104`.
**Correction:** `ride_points.lat/lng` are `REAL NOT NULL` columns (`database_helper.dart:428`). SQLite's REAL affinity stores `24` as `24.0`, and sqflite returns a `double`, so the SQLite-backed sites are **safe today**. The genuine risk is the **Firestore-backed models**: any value written by a JS client, the console, a Cloud Function, or `live-viewer.html` as an integer comes back as `int`. `downloadRideTrack` also routes Firestore data into SQLite, where affinity coerces it, so that path is fine.
**Fix:** Add `double asDouble(Object? v) => (v as num).toDouble();` and `double? asDoubleOrNull(Object? v) => (v as num?)?.toDouble();` in `core/utils/num_cast.dart`, and replace all 15 sites. Add a CI grep guard: `! grep -rnE "\] as double\b" app/lib`.

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

### 5.1 Theme change remounts `MaterialApp` 🟡 (P3). Same as UI 4.1.

**Evidence:** `app.dart:157-162` sets `key: ValueKey(appearance)`. The comment says it is deliberate, to support ~565 static `AppColors.x` reads.
**Correction:** The `GoRouter` instance comes from `routerProvider` and outlives the remount, so the **current location is preserved**. What is lost is ephemeral widget state (text fields, scroll offsets, running animations) on a theme toggle. That is a Settings-screen action, so the real-world impact is small. It is not a disaster, but it is tech debt.
**Fix (incremental; don't big-bang it):**
1. Create `AppPalette extends ThemeExtension<AppPalette>` holding the `AppColorPalette` fields. Register it in `AppTheme.build(appearance).extensions`.
2. Add `extension AppColorsX on BuildContext { AppPalette get colors => Theme.of(this).extension<AppPalette>()!; }`.
3. Codemod feature by feature: `AppColors.primary` → `context.colors.primary`. Where there is no `BuildContext` (e.g. static helpers), pass colors in.
4. When `grep -rn "AppColors\." lib | wc -l` reaches 0 outside `core/theme`, remove the `ValueKey`. Track the count in CI as a ratchet: fail if it increases.

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

### 5.3 One profile stream per chat row 🟡 (P3)

**Evidence:** `chat_list_screen.dart:99` watches `profileProvider(otherUserId)`, a `StreamProvider.family` **without `autoDispose`** (`profile_providers.dart:12`). `ListView` builds only visible rows, so the grill's "50 simultaneous" is overstated. But every stream ever opened stays open for the session.
**Fix:** Make it `StreamProvider.autoDispose.family` (check other callers; `keepAlive` where needed), or denormalize `participantInfo: {uid: {name, photoUrl}}` onto the chat doc and refresh it on send.

### 5.4 Chat and blocks 🟡 (P3)

**Evidence:** `firestore.rules:1370-1373` already rejects a message from a user blocked by either participant. The grill's "a blocked user can continue sending" is **false at the server**. What is true: `chat_list_screen.dart` and `chat_room_screen.dart` don't filter or disable anything. The sender types, the message clears, and a permission error appears in a SnackBar.
**Fix:** Filter the chat list by `blockedUsersProvider`. In the room, show a "You can't message this rider" banner and disable input when either side has blocked the other. Note that the rule hardcodes `participants[0]` and `participants[1]`; that is fine for DMs, but document it.

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

### 7.1 Battery drain ⚪ (measure it)

The numbers are an estimate, not verifiable from code. Measure with a 1-hour ride on two phones using Android Battery Historian (or `adb shell dumpsys batterystats`). Then consider an "Eco" recording mode: screen may sleep with the wakelock off, map redraw throttled to 1 Hz, IMU at 50 ms, and live-session publishing every 30 s.

### 7.2 iOS auto-tracking ✅ (P3)

**Fix:** Bangladesh is overwhelmingly Android, so **hide the auto-tracking toggle on iOS** (`Platform.isIOS`) with the note "Available on Android". Revisit later with a native `CLLocationManager.startMonitoringSignificantLocationChanges` plus `CMMotionActivityManager` plugin. The constant `significant_location_change` already exists in `auto_detection_dao.dart:18` as a placeholder.

### 7.3 Unencrypted SQLite 🟡 (P4)

`android:allowBackup="false"` is already set (`AndroidManifest.xml:76`), so data isn't extractable through adb or cloud backup on non-rooted devices. Only rooted or forensic access remains. If desired later, use `sqflite_sqlcipher` with the key in `flutter_secure_storage`, migrating via `ATTACH … KEY` plus `sqlcipher_export`. It is low value for the cost right now.

---

## 2. `other_gaps.md`: Verification and Fixes

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

### 1.2 `liveSessions` 🟡 (P1). The real problem is different.

**Evidence and corrections**
- Correct: there is no `allow delete` rule (`firestore.rules:460-465`).
- **Wrong premise:** revocation doesn't need delete. The `get` rule requires `shareable == true`, so a single update would revoke access.
- **Real bug:** the teardown (`core/cloud/outbox_service.dart:395-399`) sets `active:false, status:'completed'` but **never sets `shareable:false`**. The ended session, including its last lat/lng, stays publicly readable by anyone holding the link until `expiresAt`.
- `updatedAt` as a String (`live_session_coordinator.dart:186`, `outbox_service.dart:398`) is inconsistent typing, but it does **not** break TTL: TTL is on `expiresAt`, which is a real `Timestamp` (`live_session_entity.dart:87-93`).

**Fix:**
1. In `_deliverLiveTeardown`, add `'shareable': false` and use `'updatedAt': FieldValue.serverTimestamp()`. Do the same in `updateLiveSessionStatus` when `status == completed`.
2. Also add `allow delete: if request.auth != null && request.auth.uid == resource.data.uid;` and give the rider a "Stop sharing now" button that deletes the doc.
3. Rules test: after teardown, an unauthenticated `get` on the token is denied.
4. Normalize every `updatedAt` write in these files to a server timestamp. `LiveSessionEntity._dateFrom` already reads both formats.

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

### 2.2 Only 3 outbox kinds 🟡 (P3)

**Correction:** Firestore on mobile has **persistent offline write queuing** by default. Plain `add()`, `set()`, and `update()` calls (likes, follows, chat sends, place adds) are cached and delivered on reconnect, even across restarts. The real offline failures are:
- **Transactions** (`forum_repository.dart:75,105,149`), which fail offline.
- UI that `await`s a write, which hangs until back online.
- Cloudinary uploads.

**Fix:** For the forum create and reply transactions, either move counter updates to `FieldValue.increment` in a batched write (works offline) or catch `unavailable` and show "You're offline; post when connected". Don't `await` fire-and-forget writes in UI handlers; use `unawaited` with an error handler. Add the outbox only for flows with media (share with photos: already done; place with photo: add a kind).

### 2.3 Crash notification bypasses the outbox 🟡 (P2)

**Evidence:** `crash_coordinator.dart:88-99` uses `_bestEffortWrite` with an 8 s timeout.
**Correction:** On timeout, the Firestore `add()` is **not discarded**. It stays in Firestore's persisted pending-write queue and is delivered on reconnect (the log message on line 106 says so). The risk is narrower: the app or phone dies before reconnecting, and nothing *app-level* retries or tells the rider.
**Fix:** This matters only once §1.2.1 delivers alerts. Then:
- Enqueue an `OutboxKind.crashNotification` (idempotent: generate the doc id client-side and use `set`) in addition to the direct write.
- Show a persistent notification, "Emergency alert pending: no signal", until delivered.
- With Path B (client SMS), SMS works without data, which is the stronger answer for dead zones.

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

### 4.2 Auto-tracking: commute contamination 🟡 and sign-out leak ❌

- **Sign-out leak: FALSE.** `app.dart:147-150` calls `AutoTrackingService.instance.stop()` whenever `authStateProvider` becomes null. The cross-account leak that *does* exist is §1.4.2 (pending rows), fixed there.
- **Commute contamination: real but mitigated.** `IN_VEHICLE` covers cars and buses. The reconciler (`auto_ride_reconciler_service.dart`) attributes to the active bike and **calls `incrementStats` immediately** (≈ line 166), even when `bike_confidence='low'`. The daily confirmation prompt (`ride_dao.getUnconfirmedAutoRides`) exists but only asks *which bike*, not *whether it was a motorcycle ride at all*.

**Fix:**
1. Add a "Not a motorcycle ride" action to the confirmation prompt that deletes the ride and reverses `incrementStats`.
2. Defer odometer and maintenance increments for auto rides until confirmed, or until 48 h pass without rejection.
3. Heuristic filters in `AutoRideReconciler`: reject if the stop pattern matches a bus (many 20-60 s stops at <100 m intervals) or the max speed exceeds a set limit. Tune with real data.

### 4.3 Weather timezone skew ❌ in practice (P4)

**Evidence:** `ride.startTime` comes from local `DateTime.now()` (`ride_recording_provider.dart:324`). Open-Meteo `timezone=auto` times are parsed as device-local. `DateTime.difference` compares instants, so there is no 6 h skew when the device timezone matches the ride location, which is always the case in BD. It breaks only for a traveller whose phone keeps home time.
**Fix (cheap hardening):** Request `timezone=GMT`, parse the times as UTC (`DateTime.parse('${t}Z')`), and compare with `at.toUtc()`.

### 5.1 Push-to-talk "dead on arrival" 🟡 (P1). The mechanism in the grill is wrong; the real bug is below.

**Evidence:**
- The grill's premise is false. `just_audio 0.9.46` documents `play()`: *"The Future returned by this method completes when the playback completes or is paused or stopped."* The **first** clip plays in full.
- **Real bug:** the player is never `stop()`ped or `pause()`d (no such call in `group_ride_map_screen.dart`). After clip 1 completes, `playing` stays `true`, and the same doc says *"If the player is already playing, this method completes immediately."* For clip 2+, `setUrl` starts it, `play()` returns at once, `finally` deactivates the session and dequeues the next clip, whose `setUrl` interrupts clip 2. Clips after the first get cut off.

**Fix** (`features/social/presentation/screens/group_ride_map_screen.dart` ≈ line 340):
```dart
} finally {
  try { await _voicePlayer.stop(); } catch (_) {}
  await _deactivateVoiceAudioSession();
  ...
}
```
Optionally, after `play()`, also `await _voicePlayer.processingStateStream.firstWhere((s) => s == ProcessingState.completed || s == ProcessingState.idle)` with a timeout. Device test: queue 3 notes and confirm all 3 play fully.

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

---

## 3. `UI_UX.md`: Verification and Fixes

Paths are corrected. Screens live in `features/<feature>/presentation/screens/`.

### 1.1 End-ride dialog is glove-hostile 🟡 (P1)

**Evidence:** `features/ride/presentation/screens/active_ride_screen.dart:227-285`. The grill's code is out of date. The current dialog has a full-width End Ride button, with Cancel and a small "Share ride" checkbox in a row above it. The small Cancel and checkbox targets are still there, and the whole thing is still a standard `AlertDialog`.
**Fix:** Replace it with a bottom sheet or full-screen panel containing:
- a **hold-to-end** button (1.2 s press with a progress ring plus haptic ticks) at 72 dp height
- a full-width Share toggle row at 56 dp
- a 56 dp "Keep riding" button

Hold-to-end removes the accidental-tap risk without needing precision. There is no need for an `action_slider` dependency; a `GestureDetector(onLongPressStart/End)` with an `AnimationController` is enough.

### 1.2 Small telemetry text 🟡 (P2)

**Evidence:** Primary speed is already **64 pt** (`active_ride_screen.dart:506`); the grill is wrong there. Genuinely small: `BRAKE`/`ACCEL` labels at 9 pt (`:790,795`), values at 11 pt (`:793`), the status pill at 11 pt (`:851`), and secondary stats at 12-14 pt (`:510,677,868`).
**Fix:** Set a cockpit minimum of 14 pt for labels and 20 pt for values. Use `AppTypography` tokens (`cockpitLabel`, `cockpitValue`), not literals. Drop the G-bar's text labels in favor of color plus icons if space is tight.

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

### 2.1 "Profile" tab opens the garage 🟡 (P3)

**Evidence:** `core/router/app_router.dart:258-264` maps `/home/profile` → `GarageScreen`. The grill's code (StatefulShellBranch, `/garage`) is outdated. The screen now **leads with a profile summary header and Settings/Notifications** (`garage_screen.dart:17-50`), so it is a hybrid, not "garage pretending to be profile". The mismatch is milder than claimed: the label is Profile, but the body is mostly bikes.
**Fix:** Pick one of these:
- (a) Rename the tab to "Garage" with `Icons.two_wheeler` and move the profile header and settings to an avatar button in the Home/Record app bar; or
- (b) keep "Profile" but make `/home/profile` a real profile page with a "My bikes" section.

(a) is less work and more honest.

### 2.2 Nested tap target in the bike card 🟡 (P3)

**Evidence:** `garage_screen.dart:291-310` already uses `HitTestBehavior.opaque`, which fixes the "outer wins" arena problem the grill describes (see the comment there). The remaining issue is target size: a ~28 dp row.
**Fix:** Replace it with a `TextButton.icon` or `ActionChip`, `minimumSize: Size(48, 48)`, placed in the card's footer.

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

### 2.5 "Routes" chip navigates 🟡 (P3)

**Evidence:** `places_list_screen.dart:122-127`. It is intentional (see the comment), but it looks like a filter.
**Fix:** Move "Routes" out of the chip row into an app-bar action or a distinct `OutlinedButton.icon("Browse routes →")` above the list.

### 2.6 Notification bell only on the Profile tab ✅ (P3)

**Evidence:** `NotificationBellButton` is used only in `garage_screen.dart`.
**Fix:** Add it to the Social and Record app bars. Also consider a badge on the Social bottom-nav icon driven by the same unread-count provider.

### 3.1 "Navigate" doesn't record ✅ (P1)

**Evidence:** `route_navigation_screen.dart` never touches `rideRecordingProvider`.
**Fix:** On "Navigate", call `rideRecordingProvider.notifier.startRide(routeId: route.id)` (add an optional `routeId` column to `rides`). Better: render the route polyline inside `ActiveRideScreen` when `state.ride.routeId != null` and retire the separate nav screen's map, so there is one cockpit with one crash pipeline. Minimum step: start a recording from the nav screen and stop it on exit, with a confirm.

### 3.2 "Directions" silently starts a ride 🟡 (P2)

**Evidence:** `place_detail_screen.dart:440-448`. The grill says it doesn't set a destination; **that's wrong**. It opens Google/Apple Maps with directions to the place. But it also silently calls `startRide()`.
**Fix:** Before launching maps, ask with a bottom sheet: "Record this ride in ThrottleIQ? [Record & go] [Just directions]". Remember the choice with a "Don't ask again" option.

### 3.3 Save-as-route / share close button 🟡 (P3)

- "No Save as Route on summary": **FALSE**. `ride_summary_screen.dart:590,785` push `/routes/save/:rideId`.
- "X on share screen destroys the back stack": **TRUE**. `ride_share_screen.dart:262-263` calls `context.go('/home/record')`.

**Fix:** `onPressed: () => context.canPop() ? context.pop() : context.go('/ride/summary/$rideId')`. The "End ride + Share" path uses `context.go('/ride/share/…')` (`active_ride_screen.dart:286`), so there is nothing to pop. That is why the fallback goes to the summary.

### 3.4 Running pace shown to motorcyclists 🟡 (P3)

**Evidence:** It is in `ride_summary_screen.dart:537` (`$paceFormatted/km`), not in `shared_ride_detail_screen`.
**Fix:** Replace it with "Avg moving speed: NN km/h" (`distance / movingSeconds`) and "Moving / stopped: 42m / 8m". Remove `ridingPaceLabel` from ARB files or repurpose it.

### 4.1 Theme remount 🟡. See §1.5.1.

### 4.2 Default theme fails WCAG AA ✅ (P1, one line)

**Evidence:** The default appearance is Calming/Light (`core/theme/theme_style_provider.dart:40,160`). `calmingLight.primary = #84A98B` (`core/theme/app_theme_style.dart:345`). Button foreground is white (`app_theme.dart:165-167`). The contrast I computed is **2.62:1** (AA needs 4.5).
**Fix:** In `calmingLight`, swap `primary` to its own `primaryDark: #537D5C` (4.71:1 with white, and it stays in the same hue family). Then make the old `#84A98B` the `primaryHighlight` for non-text fills. Add a unit test that computes the contrast of `primary` vs the button foreground for **every** palette and asserts ≥ 4.5.

### 4.3 Dark-on-red End Ride ❌

**Evidence:** In dark mode the theme foreground is `AppColors.surface` (`app_theme.dart:167`). For Calming Dark that is `#211F16` on `danger #DC7672`, which is **5.41:1** and passes AA. White on that red would be 3.05:1, which is *worse*. Keep it as is. The contrast test from 4.2 will cover it.

### 4.4 Hardcoded dark surfaces 🟡 (P3)

- `ThemeData.dark()` in the date picker: **not found** anywhere in `lib/`. Already gone.
- Tour banner `Color(0xFF181D22)`: **TRUE** (`features/auth/presentation/widgets/tour_floating_banner.dart:29`). Replace it with `AppColors.ink` / `AppColors.onInk`, or with `context.colors` after §1.5.1.

### 4.5 24 dp close target ✅ (P3)

**Evidence:** `tour_floating_banner.dart:130-138`.
**Fix:** `IconButton(icon: Icon(Icons.close, size: 20), constraints: BoxConstraints.tightFor(width: 48, height: 48), onPressed: …)`.

### 5.1 Chat input cleared before send 🟡 (P3)

**Evidence:** `chat_room_screen.dart:58` calls `clear()` before `await sendMessage`.
**Correction:** Offline, the batch is queued by Firestore and not lost. The text is lost only when the write is **rejected** (permission-denied, e.g. blocked).
**Fix:** In the `catch`, restore it: `if (_textController.text.isEmpty) _textController.text = text;` and show a "Retry" SnackBar action.

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

### 5.5 Profile stat cards not tappable ⚪ (P4)

Not verified in detail. If they look like cards, give Rides → `/rides/all` and Routes → `/routes` an `onTap`, or restyle them as plain text.

### 6.1 Bangla localization ✅ (P2)

**Evidence:** 38 `*_screen.dart` files have no `AppLocalizations`/`l10n` usage, including login, register, onboarding, active ride, record, garage, all maintenance screens, places, routes, chat, and forums.
**Fix, in order of safety impact:**
1. The crash countdown overlay (`active_ride_screen.dart:700-760`) and the crash notification text in `notification_service.dart`.
2. The active ride and route navigation screens.
3. Onboarding, login, and register.
4. The rest.

Add a CI check: a test that fails if a new `*_screen.dart` has string literals in `Text('…')` without l10n. Use a simple regex allowlist to start.

### 6.2 Social "ghost town" ⚪ (P3)

This is a product judgment. Two cheap fixes:
- Seed the feed with curated public routes, or "Featured rides" from the founder account, when the following count is 0.
- Paginate forums (`limit(20)` plus `startAfterDocument`). Worth verifying `forums_home_screen` queries separately.

### 6.3 Emergency contacts create false security ✅ (P0, copy change)

**Fix:**
- Until §1.2.1 ships, the Emergency Contacts section header should read: "⚠️ ThrottleIQ does not yet alert these contacts automatically."
- Use a warning-colored banner, not fine print.
- Show a one-time acknowledgement dialog when the first contact is added.

---

## 4. `bussness.md`: Verification and Instructions

### 4.1 Crash detector can't fire ✅. Engineering fix in §1.1.1. Claim hygiene is P0.

**Evidence:** Same as §1.1.1. The pitch claims it: `DOCS/General/marketing/iDEA_PITCH_SUBMISSION.md:36,76,107`.
**Budget-phone ±2/4 g claim:** ⚪, overstated. Most current Android accelerometers default to ±8 g or ±16 g, but saturation on cheap phones is plausible. The saturation handling in §1.1.1 covers it either way.
**Fix:** Until field validation passes, rewrite the pitch, the store listing, and the posters. Say "crash-detection **in development / beta**", or lead with maintenance and ride logging as the grill suggests. Replace the claims at lines 36 and 76 and the comparison table row at 107.

### 4.2 Team roster ✅ (P0 for the grant)

**Evidence:** Slide 9 (`iDEA_PITCH_SUBMISSION.md:233-242`) lists an Embedded & Sensor Systems Lead, a Growth Lead, and an Advisory Panel. The video script (`gov-pitch/Part-2-Video-Pitch-Script.md:11`) requires "Founder/CEO, Tech Lead, Growth Lead" on camera. Every commit author in `git log` is the founder under different identities, plus one `blankframe-tech` commit.
**Fix:**
- If those people are real and committed, add their names and roles and get their consent and NIDs ready.
- If not, rewrite Slide 9 as "Solo technical founder; grant funds hire (1) embedded/sensor engineer, (2) growth lead". Put those roles in the fund-utilization table and edit the video script to a single presenter.

### 4.3 Financial model ⚪ (P1 for the pitch)

The payment-rail part is confirmed: there are no hits for `bkash|nagad|sslcommerz|aamarpay|in_app_purchase` in `app/lib` or `pubspec.yaml`. The rest is market judgment.
**Fix:**
- Replace the 3-year table with a conservative base case: sub-1% paid conversion, with bKash tokenized checkout listed as a funded milestone.
- Drop the B2B fleet ARR line unless a letter of intent exists. Keep "fleet pilot" as an experiment.
- The grill's alternatives (a one-time paid "verified service logbook" for resale, service-center affiliates) fit the product that actually works today. Consider leading with them.

### 4.4 Distribution funnel ✅ (P0)

**Evidence:** `DOCS/General/marketing/marketing_lead_notes/NEEDS_YOUR_ATTENTION.md` §1 says the Play internal track has zero testers, and §3 says `website_demo/` has no deploy target (`firebase.json` Hosting serves `public/`).
**Fix (founder actions, 1 hour total):**
1. In Play Console → Internal testing → Testers, create an email list of 20+ riders and share the opt-in link.
2. Deploy the site. Either add a second Hosting target (`firebase target:apply hosting site website_demo` plus a `hosting` array entry in `firebase.json`; Hosting works on Spark), or copy `website_demo/` into `public/` if a single site is fine. Point every outreach template at that URL and the Play opt-in link, not GitHub.

### 4.5 Bangla-first mismatch ✅. See §3.6.1.

### 4.6 Retention: "zero push notifications" 🟡 (P2)

**Correction:** Local notifications exist: a daily summary (`notification_service.dart:245-311`), ride confirmation, and crash alert. **Missing:** maintenance-due reminders and badge-unlock notifications. FCM is absent.
**Fix:**
- Add `scheduleMaintenanceDue(bikeId)` in `NotificationService`. After each ride finalize, compute the remaining km per service type. When a type is within 10% of its interval, show "Oil change due in ~120 km". Throttle to one per type per 3 days.
- Fire a local notification on badge unlock.

This needs no Blaze.

### 4.7 Legal/privacy items ✅. Engineering fixes in §1.2.1, §1.4.4, §1.4.5, §3.6.3.

In addition, update the Play **Data Safety** form: audio (voice notes), precise location, health info (SafeQR medical data stays on-device; declare it if it is ever synced), and crash logs.

### 4.8 "Productive procrastination" ⚪

This is not a code issue. The practical translation: freeze new features until the P0 list in §5 is done.

---

## 5. Recommended Execution Order

**Today (≤2 h, no code risk)**
1. Back up the keystore and secrets, and confirm Play App Signing (§2.6.2).
2. Enroll testers and deploy the landing page (§4.4).
3. Change the emergency-contacts copy and remove automatic-alert and crash-detection claims from the pitch and store listing (§3.6.3, §4.1, §4.2).
4. Change `calmingLight.primary` to `#537D5C` and add the contrast test (§3.4.2).

**Sprint 1: safety and data integrity**
5. `ImpactDetector` plus the jerk-max fix and a pipeline test (§1.1.1, §1.1.2). Then field testing.
6. Crash rides: sync plus stats (§1.2.2).
7. Counter ownership and edge-triggering (§1.1.3).
8. `track_synced` plus `downloadRideTrack` wiring (§1.3.1, §1.3.2).
9. Archive instead of delete bike, plus chunked remote delete (§2.1.1, §1.3.3).
10. Live session `shareable:false` on teardown plus a delete rule (§2.1.2).
11. Outbox: user scoping plus dead-letter (§2.2.1).
12. The voice-note `stop()` fix (§2.5.1).
13. CI workflow (§2.6.1).

**Sprint 2: privacy and correctness**
14. Radius-based privacy clipping with jitter (§1.4.1).
15. `auto_detections.user_id` plus confirm-before-odometer (§1.4.2, §2.4.2).
16. Moving-time gap fix (§2.4.1).
17. Tile provider plus cache (§2.3.1).
18. Geohash nearby query (§2.3.2).
19. Firestore-side `num` casts (§1.3.4).
20. Deterministic chat ids (§1.5.2).
21. Gyro yaw projection plus pre-calibration suppression (§1.6.2, §1.6.3).
22. Full-screen intent declaration and runtime check (§1.2.4).

**Sprint 3: cockpit UX**
23. Hold-to-end, pause scrim reorder, cockpit font floor (§3.1.1, §3.1.6, §3.1.2).
24. Heading-up map, navigation that records, TTS (§3.1.3, §3.3.1, §3.1.4).
25. Maintenance back button, bike detail section, add-bike flow (§3.2.3, §3.2.4).
26. SafeQR export and print (§3.5.4).
27. Bangla for crash and cockpit screens first (§3.6.1).
28. Maintenance-due local notifications (§4.6).

**After Blaze**
29. Real SMS dispatch plus escalation plus server-side cancel (§1.2.1).
30. Signed Cloudinary uploads and private voice notes (§1.4.4, §1.4.5).
31. Complete account deletion (§2.1.3).
32. Follower fan-out function (§1.4.3).

**Later / optional**
33. Theme `ThemeExtension` migration (§1.5.1).
34. Landscape cockpit (§3.1.5).
35. GPX import (§2.3.4).
36. SQLCipher (§1.7.3).
37. iOS auto-tracking (§1.7.2).
38. Tab rename (§3.2.1).

---

## 6. Grill Claims That Were Wrong (don't spend time on these)

| Claim | Reality |
|---|---|
| Auto-tracking keeps running after sign-out (other_gaps 4.2) | `app.dart:147-150` stops it on auth → null. |
| just_audio `play()` returns immediately, so every clip is cut (other_gaps 5.1) | `play()` awaits completion. Only clips 2+ break, because the player is never stopped. |
| Live link can't be revoked without delete (other_gaps 1.2) | An update to `shareable:false` revokes it. The bug is that teardown never sets it. |
| String `updatedAt` breaks TTL (other_gaps 1.2) | TTL is on `expiresAt`, which is a real `Timestamp`. |
| Crash alert is permanently discarded offline (other_gaps 2.3) | Firestore's persisted write queue delivers it on reconnect. The only risk is process death, and it's moot while the backend is a mock. |
| Blocked users can keep sending messages (codebase 5.4) | `firestore.rules:1370-1373` rejects them. Only the UI is missing. |
| SQLite `as double` casts crash on integer coordinates (codebase 3.4) | REAL column affinity returns `double`. Only Firestore-sourced casts are at risk. |
| Physics clamp caps GPS accel at 12 m/s² (bussness 1.3) | The clamp affects `speedMs`, not `accel`. The detector still can't fire, for the reasons in §1.1.1. |
| Dark-on-red End Ride is unreadable (UI 4.3) | 5.41:1. It passes AA. |
| Date picker forces `ThemeData.dark()` (UI 4.4) | No longer in the codebase. |
| Ride summary lacks "Save as Route" (UI 3.3) | It exists (`ride_summary_screen.dart:590,785`). |
| "Directions" doesn't set a destination (UI 3.2) | It opens Google/Apple Maps to the place. The silent `startRide()` is the real problem. |
| Speed readout is microscopic (UI 1.2) | Speed is 64 pt. Only the labels and secondary stats are small. |
| Weather is off by 6 h in BD (other_gaps 4.3) | It is only wrong when the device timezone differs from the ride location. |
| Default theme colors live in `app_colors.dart:12-21` (UI 4.2) | They are in `core/theme/app_theme_style.dart:337`. The defect itself is real. |
