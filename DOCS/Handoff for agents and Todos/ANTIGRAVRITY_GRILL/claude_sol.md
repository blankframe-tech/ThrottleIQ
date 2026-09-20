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

### 3.4 Raw `as double` casts 🟡 (P2)

**Evidence:** There are 15 sites (`grep -rn "as double\b" lib | grep lat`), including `ride_summary_screen.dart:78`, `ride_share_screen.dart:67`, `save_route_screen.dart:55`, `export_service.dart:131-132`, `ride_persistence_coordinator.dart:147-156`, `ride_share_model.dart:143`, `route_model.dart:58`, `group_ride_model.dart:259`, and `live_session_entity.dart:103-104`.
**Correction:** `ride_points.lat/lng` are `REAL NOT NULL` columns (`database_helper.dart:428`). SQLite's REAL affinity stores `24` as `24.0`, and sqflite returns a `double`, so the SQLite-backed sites are **safe today**. The genuine risk is the **Firestore-backed models**: any value written by a JS client, the console, a Cloud Function, or `live-viewer.html` as an integer comes back as `int`. `downloadRideTrack` also routes Firestore data into SQLite, where affinity coerces it, so that path is fine.
**Fix:** Add `double asDouble(Object? v) => (v as num).toDouble();` and `double? asDoubleOrNull(Object? v) => (v as num?)?.toDouble();` in `core/utils/num_cast.dart`, and replace all 15 sites. Add a CI grep guard: `! grep -rnE "\] as double\b" app/lib`.

### 5.1 Theme change remounts `MaterialApp` 🟡 (P3). Same as UI 4.1.

**Evidence:** `app.dart:157-162` sets `key: ValueKey(appearance)`. The comment says it is deliberate, to support ~565 static `AppColors.x` reads.
**Correction:** The `GoRouter` instance comes from `routerProvider` and outlives the remount, so the **current location is preserved**. What is lost is ephemeral widget state (text fields, scroll offsets, running animations) on a theme toggle. That is a Settings-screen action, so the real-world impact is small. It is not a disaster, but it is tech debt.
**Fix (incremental; don't big-bang it):**
1. Create `AppPalette extends ThemeExtension<AppPalette>` holding the `AppColorPalette` fields. Register it in `AppTheme.build(appearance).extensions`.
2. Add `extension AppColorsX on BuildContext { AppPalette get colors => Theme.of(this).extension<AppPalette>()!; }`.
3. Codemod feature by feature: `AppColors.primary` → `context.colors.primary`. Where there is no `BuildContext` (e.g. static helpers), pass colors in.
4. When `grep -rn "AppColors\." lib | wc -l` reaches 0 outside `core/theme`, remove the `ValueKey`. Track the count in CI as a ratchet: fail if it increases.

### 5.3 One profile stream per chat row 🟡 (P3)

**Evidence:** `chat_list_screen.dart:99` watches `profileProvider(otherUserId)`, a `StreamProvider.family` **without `autoDispose`** (`profile_providers.dart:12`). `ListView` builds only visible rows, so the grill's "50 simultaneous" is overstated. But every stream ever opened stays open for the session.
**Fix:** Make it `StreamProvider.autoDispose.family` (check other callers; `keepAlive` where needed), or denormalize `participantInfo: {uid: {name, photoUrl}}` onto the chat doc and refresh it on send.

### 5.4 Chat and blocks 🟡 (P3)

**Evidence:** `firestore.rules:1370-1373` already rejects a message from a user blocked by either participant. The grill's "a blocked user can continue sending" is **false at the server**. What is true: `chat_list_screen.dart` and `chat_room_screen.dart` don't filter or disable anything. The sender types, the message clears, and a permission error appears in a SnackBar.
**Fix:** Filter the chat list by `blockedUsersProvider`. In the room, show a "You can't message this rider" banner and disable input when either side has blocked the other. Note that the rule hardcodes `participants[0]` and `participants[1]`; that is fine for DMs, but document it.

### 7.1 Battery drain ⚪ (measure it)

The numbers are an estimate, not verifiable from code. Measure with a 1-hour ride on two phones using Android Battery Historian (or `adb shell dumpsys batterystats`). Then consider an "Eco" recording mode: screen may sleep with the wakelock off, map redraw throttled to 1 Hz, IMU at 50 ms, and live-session publishing every 30 s.

### 7.3 Unencrypted SQLite 🟡 (P4)

`android:allowBackup="false"` is already set (`AndroidManifest.xml:76`), so data isn't extractable through adb or cloud backup on non-rooted devices. Only rooted or forensic access remains. If desired later, use `sqflite_sqlcipher` with the key in `flutter_secure_storage`, migrating via `ATTACH … KEY` plus `sqlcipher_export`. It is low value for the cost right now.

---

## 2. `other_gaps.md`: Verification and Fixes

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

### 2.1 "Profile" tab opens the garage 🟡 (P3)

**Evidence:** `core/router/app_router.dart:258-264` maps `/home/profile` → `GarageScreen`. The grill's code (StatefulShellBranch, `/garage`) is outdated. The screen now **leads with a profile summary header and Settings/Notifications** (`garage_screen.dart:17-50`), so it is a hybrid, not "garage pretending to be profile". The mismatch is milder than claimed: the label is Profile, but the body is mostly bikes.
**Fix:** Pick one of these:
- (a) Rename the tab to "Garage" with `Icons.two_wheeler` and move the profile header and settings to an avatar button in the Home/Record app bar; or
- (b) keep "Profile" but make `/home/profile` a real profile page with a "My bikes" section.

(a) is less work and more honest.

### 2.2 Nested tap target in the bike card 🟡 (P3)

**Evidence:** `garage_screen.dart:291-310` already uses `HitTestBehavior.opaque`, which fixes the "outer wins" arena problem the grill describes (see the comment there). The remaining issue is target size: a ~28 dp row.
**Fix:** Replace it with a `TextButton.icon` or `ActionChip`, `minimumSize: Size(48, 48)`, placed in the card's footer.

### 2.5 "Routes" chip navigates 🟡 (P3)

**Evidence:** `places_list_screen.dart:122-127`. It is intentional (see the comment), but it looks like a filter.
**Fix:** Move "Routes" out of the chip row into an app-bar action or a distinct `OutlinedButton.icon("Browse routes →")` above the list.

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

### 4.3 Dark-on-red End Ride ❌

**Evidence:** In dark mode the theme foreground is `AppColors.surface` (`app_theme.dart:167`). For Calming Dark that is `#211F16` on `danger #DC7672`, which is **5.41:1** and passes AA. White on that red would be 3.05:1, which is *worse*. Keep it as is. The contrast test from 4.2 will cover it.

### 4.4 Hardcoded dark surfaces 🟡 (P3)

- `ThemeData.dark()` in the date picker: **not found** anywhere in `lib/`. Already gone.
- Tour banner `Color(0xFF181D22)`: **TRUE** (`features/auth/presentation/widgets/tour_floating_banner.dart:29`). Replace it with `AppColors.ink` / `AppColors.onInk`, or with `context.colors` after §1.5.1.

### 5.1 Chat input cleared before send 🟡 (P3)

**Evidence:** `chat_room_screen.dart:58` calls `clear()` before `await sendMessage`.
**Correction:** Offline, the batch is queued by Firestore and not lost. The text is lost only when the write is **rejected** (permission-denied, e.g. blocked).
**Fix:** In the `catch`, restore it: `if (_textController.text.isEmpty) _textController.text = text;` and show a "Retry" SnackBar action.

### 5.5 Profile stat cards not tappable ⚪ (P4)

Not verified in detail. If they look like cards, give Rides → `/rides/all` and Routes → `/routes` an `onTap`, or restyle them as plain text.

### 6.2 Social "ghost town" ⚪ (P3)

This is a product judgment. Two cheap fixes:
- Seed the feed with curated public routes, or "Featured rides" from the founder account, when the following count is 0.
- Paginate forums (`limit(20)` plus `startAfterDocument`). Worth verifying `forums_home_screen` queries separately.

---

## 4. `bussness.md`: Verification and Instructions

### 4.3 Financial model ⚪ (P1 for the pitch)

The payment-rail part is confirmed: there are no hits for `bkash|nagad|sslcommerz|aamarpay|in_app_purchase` in `app/lib` or `pubspec.yaml`. The rest is market judgment.
**Fix:**
- Replace the 3-year table with a conservative base case: sub-1% paid conversion, with bKash tokenized checkout listed as a funded milestone.
- Drop the B2B fleet ARR line unless a letter of intent exists. Keep "fleet pilot" as an experiment.
- The grill's alternatives (a one-time paid "verified service logbook" for resale, service-center affiliates) fit the product that actually works today. Consider leading with them.

### 4.6 Retention: "zero push notifications" 🟡 (P2)

**Correction:** Local notifications exist: a daily summary (`notification_service.dart:245-311`), ride confirmation, and crash alert. **Missing:** maintenance-due reminders and badge-unlock notifications. FCM is absent.
**Fix:**
- Add `scheduleMaintenanceDue(bikeId)` in `NotificationService`. After each ride finalize, compute the remaining km per service type. When a type is within 10% of its interval, show "Oil change due in ~120 km". Throttle to one per type per 3 days.
- Fire a local notification on badge unlock.

This needs no Blaze.

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
