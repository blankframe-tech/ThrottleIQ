# ThrottleIQ — Weakness Audit & Forward Plan

**Audited:** 2026-07-12 · Codebase: `old_versions/FlutterSpecialistClaude/throttleiq_e` (~4,900 LOC, 47 Dart files)

---

## 0. Repo housekeeping — do this FIRST

The repo itself is in a dangerous state before any code is even considered:

- **The most advanced version of the code is LOST.** `IMPLEMENTATION_SUMMARY.md` (May 14) describes a build with `wakelock_plus`, DB schema v2 + migrations, `period_type` idle-tracking column, `roadmap.md`, and a release APK — all applied to `FlutterSpecialistClaude/throttleiq/`, which is now an **empty directory**. The surviving `throttleiq_e` is byte-identical to the older `FlutterSpecialistClaude 5` copy (DB v1, no wakelock, no migrations). `version_comparison.md` describes dependencies (Riverpod 3.x, go_router 17, workmanager) that exist in **no copy on disk**.
- **No git history.** Six near-identical full copies of the app ("FlutterSpecialistClaude" … "5") substitute for version control. `.DS_Store` files and `.venv` folders are committed.

**Actions:**
1. Accept `throttleiq_e` as the canonical baseline (it's the only complete copy). Move it to the repo root as `app/`.
2. `git init`, commit the baseline, add `.gitignore` (build/, .venv, .DS_Store, google-services.json, key.properties).
3. Delete the five duplicate `FlutterSpecialistClaude N` folders after the baseline commit (they are identical or older).
4. Re-apply the lost May-14 fixes from `IMPLEMENTATION_SUMMARY.md` as tracked commits (wakelock, DB migration scaffold, `period_type` column) — they're small and fully described.

---

## 1. CRITICAL — Background tracking (the app's core promise is broken)

Recording dies the moment the screen locks or the app is backgrounded. For a ride tracker this is a product-defining defect (also the #1 item in `TODO now.md`).

**Evidence:**
- No `<service android:foregroundServiceType="location">` in `AndroidManifest.xml` — the FOREGROUND_SERVICE permissions on lines 23–24 are declared but unused.
- `ride_recording_provider.dart:174` uses plain `LocationSettings`, not `AndroidSettings(foregroundNotificationConfig: …)`, so geolocator never starts its foreground service.
- `ACCESS_BACKGROUND_LOCATION` is declared (manifest line 6) but never requested; `_requestPermissions()` (provider :107–113) accepts `whileInUse` as sufficient.
- No wakelock anywhere; the 1-second elapsed `Timer` and the 20 Hz accelerometer stream both stop on suspend.
- iOS `Info.plist` has **no location usage descriptions at all** (crashes on first location request) and no `UIBackgroundModes: location`.

**Actions:**
1. Switch to `AndroidSettings(accuracy: high, distanceFilter: 5, foregroundNotificationConfig: ForegroundNotificationConfig(...))` — geolocator then runs its own foreground service; add the `<service>` declaration with `foregroundServiceType="location"`.
2. Request background location properly (foreground grant first, then background, per Android 11+ two-step flow); handle `deniedForever` with `Geolocator.openAppSettings()`.
3. Add `wakelock_plus` — enable on `startRide`, disable on stop (re-applies the lost May-14 fix).
4. iOS: add `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `UIBackgroundModes: [location]`.
5. Check `Geolocator.isLocationServiceEnabled()` before starting and surface a "turn on GPS" prompt.
6. Persist recording state so a process death mid-ride can recover the ride on relaunch (see §3 zombie rides).

---

## 2. CRITICAL — Correctness bugs in the ride engine

1. **Jerk detection is dead code.** `event_detector.dart:12` accepts a `jerk` param, but the only call site (`ride_recording_provider.dart:284`) passes only `speedMs` + `elapsedSeconds` — so `highJerkCount` **never increments**. The README's flagship "jerk" metric is computed and stored per point but never counted. Pass `jerk` from the `MotionResult` into `detect()`.
2. **Alerts never clear.** `_onPosition` (:293) keeps `state.activeAlert` forever once set — one overspeed pins the alert for the whole ride; once elapsed ≥ 90 min, `fatigue` overrides everything permanently. Add an alert TTL (e.g. clear after 5 s) and don't re-fire fatigue continuously.
3. **"Max Speed" stat shows current speed.** `active_ride_screen.dart:288` binds the "Max Speed" tile to `currentSpeedMs`. `_maxSpeed` is tracked in the notifier but never exposed in state. Expose and bind it.
4. **Sensor sign heuristic is orientation-dependent.** `_onSensor` (:194) picks the dominant phone axis as "longitudinal" — wrong for any mount orientation; hard-brake vs rapid-accel can be inverted. Fuse with GPS-derived acceleration sign, or calibrate orientation at ride start (gravity vector + first motion direction).
5. **Timestamps: use `pos.timestamp`, not `DateTime.now()`** (:233) — buffered/delayed fixes currently corrupt Δt, hence accel/jerk.
6. **No GPS accuracy gate.** Points with poor `pos.accuracy` (> ~25 m) should be dropped; stationary GPS jitter currently inflates distance (haversine on noise). This is the "sometimes accurate on some devices" complaint in `TODO now.md`.
7. **Avg speed = mean of samples** (:342) — biased by fix rate. Use `distance / movingTime` instead.
8. **Idle/stop segmentation missing** (TODO item): speed < ~1 m/s for 10 s+ → tag points `period_type='idle'` (schema column already designed in the lost v2 migration), keep recording, and report moving-time vs stopped-time in the summary.

---

## 3. HIGH — Data layer integrity & performance

1. **Ride points are written one row per GPS fix, fire-and-forget.** `ride_recording_provider.dart:272` calls `_pointDao.insert(...)` unawaited, no try/catch, one autocommit transaction per point (thousands per ride). `RidePointDao.insertBatch` (a real `db.batch()`) exists but is **never called**. → Buffer points in memory, flush every ~20 points / 10 s via `insertBatch` in a transaction, and flush+await on stop so the tail of the ride isn't lost.
2. **No migration strategy.** `database_helper.dart:17` opens `version: 1`, `onCreate` only. Any schema change = wipe or crash. Add `onUpgrade` now (re-apply the lost v1→v2 migration as the first).
3. **Foreign keys are inert.** Only one FK is declared (`ride_points.ride_id`), without `ON DELETE CASCADE`, and sqflite never runs `PRAGMA foreign_keys = ON` (no `onConfigure`). Bike delete (`bike_dao.dart:26`) orphans its rides, ride_points, and maintenance_logs forever; there is no delete-ride path at all, so points accumulate unbounded.
4. **Zombie rides.** Rides start as `status='active'` and only `stopRide` completes them; a mid-ride kill leaves the ride (and thousands of points) invisible forever since all queries filter `status='completed'`. On app start: recover-or-finalize any `active` ride (this becomes the crash-recovery path in §1.6).
5. **Missing indexes** on `rides(user_id,status)`, `rides(bike_id,status)`, `bikes(user_id)`, `maintenance_logs(bike_id)`; make the points index composite `(ride_id, timestamp)`.
6. **Zero try/catch on any DB op** in DAOs or providers; `fromMap` casts (`ride_model.dart:14-16`) crash on NULLs from partial writes.
7. **Unpaginated point reads.** `ride_summary_screen.dart:34` loads every point of a ride at once; downsample for the polyline (e.g. Douglas-Peucker or every Nth point) or paginate.

---

## 4. HIGH — Data loss: everything is local-only

All rides, bikes, GPS traces, and maintenance logs live solely in on-device SQLite. Lost phone = total loss. Every table has a `synced` column and DAOs have `getUnsynced()`/`markSynced()` — **all dead code, never called**; no `cloud_firestore`/`firebase_storage` dependency exists despite auth being wired.

**Actions (pick one path and commit):**
- **Recommended:** add Firestore sync using the existing `synced`-flag scaffolding — push rides/bikes/logs on completion (points batched or as compressed blobs in Storage), pull on fresh install. `connectivity_plus` (already a dep, unused) gates it. Anonymize/scope by uid — matches the "data stored anonymously" requirement in `TODO now.md`.
- Minimum bar if sync is deferred: a local **export/import** (GPX/JSON) so testers can back up.

---

## 5. HIGH — Performance in the recording path

1. **Unbounded polyline copy per GPS tick** (`_onPosition` :294): `[...state.polyline, point]` is O(n) per fix, O(n²) per ride, all retained in memory alongside the DB copy. Keep a mutable list in the notifier; expose an immutable view; downsample what the map draws.
2. **20 Hz whole-screen rebuilds**: `_onSensor` updates state every 50 ms and `ActiveRideScreen` watches the whole provider (`active_ride_screen.dart:90`), so the map re-renders 20×/sec. Throttle sensor UI updates to ~4 Hz and use `ref.watch(provider.select(...))` per widget.
3. **Navigation/map side-effects inside `build()`** (`record_screen.dart:19`, `active_ride_screen.dart:94-105`) run at the rebuild rate — move to listeners (`ref.listen`).
4. `setState` after `await` without `mounted` guard in `ride_summary_screen.dart:35`.
5. Non-autoDispose recording provider keeps GPS/sensor subscriptions alive if a ride is left paused — intentional for recording, but add a lifecycle guard.

---

## 6. MEDIUM — Auth & security

- Raw `FirebaseAuthException` strings shown to users (`login_screen.dart:38`, `register_screen.dart:41`) — map error codes to friendly messages.
- No password reset, no email verification; email validation is `contains('@')`.
- **Onboarding stores the bike brand as the Firebase `displayName`** (`onboarding_screen.dart:38`) and "onboarding complete" is inferred from `displayName != null` (`user_entity.dart:16`, router redirect `app_router.dart:27`) — user's name becomes "Yamaha", and the async `updateDisplayName` can bounce users back to onboarding. Store onboarding state separately (shared_preferences or Firestore profile).
- `google-services.json` with live API key is committed — restrict the key in Firebase console and gitignore the file.
- `Firebase.initializeApp()` (`main.dart:20`) has no `firebase_options.dart` and no try/catch — iOS init will fail; wrap and surface a friendly failure.
- `permission_handler` and `dio` are dead dependencies — remove or use.

---

## 7. MEDIUM — Release readiness (blocks Play Store beta)

- **Release build signs with the debug keystore** (`build.gradle.kts`: `signingConfig = signingConfigs.getByName("debug")` + TODO comment) — cannot be uploaded to Play. Create a keystore + `key.properties`.
- No R8/ProGuard (`minifyEnabled`/`shrinkResources` absent, no rules file).
- Stock Flutter launcher icon; add `flutter_launcher_icons`.
- `BODY_SENSORS` permission declared but unneeded (sensors_plus doesn't require it) — remove; it invites Play review scrutiny.
- iOS still lists landscape orientations in `Info.plist` while `main.dart` locks portrait.

---

## 8. MEDIUM — UX / navigation / product gaps

- **Two of five nav tabs are fake**: Chatbot echoes a canned "coming soon" string (`chatbot_screen.dart:37`); Social is a static "Coming in V2" panel. Either gate them visibly or replace with real V1.1 features (see roadmap below).
- `context.go()` used for push-style flows (garage → detail → edit, summary close) destroys the back stack — use `context.push()`.
- Ride-summary map is not zoomable/scrollable (TODO item) — enable `InteractionOptions` on the summary `FlutterMap`.
- Maintenance logs don't update service status/reminders (TODO item) — when a log of type X is added, reset that reminder's baseline odometer/date.
- Raw `Text('Error: $e')` in garage/maintenance/summary screens; hardcoded `৳` currency; zero `Semantics`/tooltips (primary record control is a bare `GestureDetector`).

---

## 9. Testing — effectively zero

Only `test/widget_test.dart` with `expect(true, isTrue)`. `mockito` declared, unused. Highest-value targets, all pure and trivially testable:
1. `MotionCalculator` (accel/jerk/haversine — exact-value asserts, Δt=0 guard)
2. `EventDetector` (thresholds, the currently-dead jerk path, counter resets)
3. DAO round-trips + batch insert + cascade delete (sqflite_common_ffi in-memory)
4. Model `toMap`/`fromMap` round-trips incl. NULL tolerance
5. Maintenance reminder math (`_computeReminders`)
6. Riding-score calculation

Adopt TDD for every fix in this plan: write the failing test first (the jerk bug and max-speed bug would each have been caught by one assert).

---

## 10. NEW FEATURES — Rider POI directory (fuel pumps, garages, spare parts shops)

A map/list directory of rider-relevant places: **fuel pumps, garages (repair workshops), and spare-parts shops**.

**Content model — two sources, one listing type:**
- **Admin-added listings** carry a **blue verified tick** (a `verified: true` flag settable only by admin role — enforce via Firestore security rules / custom claims, never client-side).
- **User-added listings**: any signed-in user can add a place (name, category, location pin, photos, phone, hours). Visible to all users immediately, unverified (no tick). Admin can later verify (tick appears) or remove.

**Ratings & reviews:**
- Any user can rate (1–5 stars) and write a review with **photo attachments**.
- One rating per user per place (keyed `placeId_userId`), editable; listing shows average + count.
- Review section per listing: text, images (Firebase Storage, compressed client-side, max ~3 per review), reviewer name, date. Report/flag button for moderation; admin can hide reviews.

**Data model (Firestore):**
```
places/{placeId}: { name, category: fuel|garage|parts, geo (geohash + lat/lng),
                    address, phone, hours, photos[], verified, createdBy, createdAt,
                    ratingSum, ratingCount }   // denormalized avg = sum/count
places/{placeId}/reviews/{userId}: { stars, text, imageUrls[], createdAt, flagged }
users/{uid}: { role: user|admin }             // admin via custom claim
```

**UX:**
- New "Explore" surface (natural home: replace the stub Social tab, or a tab under it): map view (`flutter_map`, geohash query for places in viewport) + filterable list (category chips: ⛽ Fuel / 🔧 Garage / 🛒 Parts), sorted by distance.
- Listing detail: photos carousel, verified badge, call button, directions (launch maps app), rating breakdown, reviews, "Add review" with camera/gallery picker.
- "Add a place" FAB: drop a pin (defaults to current location), category, name, optional photo.
- During an active ride: quick "nearest fuel pump" action from the recording screen (read-only, one tap, big touch target — rider context).

**Build steps:**
1. Add `cloud_firestore` + `firebase_storage`; define security rules (reads public to signed-in users; writes owner-scoped; `verified` writable by admin claim only).
2. Place repository + geohash query (e.g. `geoflutterfire_plus` or manual geohash prefix queries).
3. Explore screen (map + list + filters) → detail screen → add-place flow → review flow with image upload.
4. Admin path: simplest is a `role: admin` claim + in-app verify/hide buttons visible only to admins (no separate admin app needed for V1).
5. Tests: rating aggregation math, geohash query bounds, review-permission rules (Firestore rules unit tests via emulator).

---

## 11. NEW FEATURE — Emergency contact link: crash alert + live rider stats

While riding, the rider can **share a link with an emergency contact**. The contact needs no app or account — the link opens a lightweight web page. Two functions:

1. **Crash alert:** if a crash is detected mid-ride, the contact is notified immediately (the link page flips to alert state showing last known location; plus SMS/email/push notification).
2. **Anytime check-in:** the contact can open the link at any time to see the rider's current/last stats — riding or not, current speed, live location on a map, ride duration, battery %, last-seen time.

**Crash detection (on-device, runs inside the recording engine):**
- Signal: accelerometer spike > ~8–10 g (tunable in `SensorConstants`) OR high-jerk event followed by **speed dropping to ~0 within 2–3 s and staying there** — the combination avoids pothole false positives. (Depends on §1 background execution and §2.4 sensor calibration being done first.)
- On trigger: full-screen countdown ("Crash detected — are you OK?", loud sound + max vibration, 30–60 s). Rider taps "I'm OK" → cancel, log as false positive (feeds threshold tuning). No response → escalate: mark `status: crash` on the live session doc + send notification (FCM → Cloud Function → SMS/email to contact).
- Never auto-call emergency services in V1 — notify the chosen contact only.

**Live share plumbing:**
```
liveSessions/{token}: { uid, rideId?, active, lastLat, lastLng, speedMs,
                        headingDeg, batteryPct, status: riding|idle|crash|ended,
                        updatedAt, expiresAt }
users/{uid}/emergencyContacts/{id}: { name, phone, email }
```
- `token` = unguessable random ID (the capability IS the link — no login needed to view). Share via OS share sheet (`share_plus`): `https://throttleiq.app/live/{token}`.
- The recording engine upserts the session doc every ~10–15 s while riding (coarse cadence — cheap on data/battery; burst to per-second on crash).
- Viewer page: a small **Firebase Hosting web page** (static JS + Firestore web SDK read of that one doc) — map pin, big status banner (green riding / red CRASH), stats, "last updated Xs ago". No Flutter-web app needed.
- Rider controls: pick contact(s) in Profile (name/phone/email — pairs with the profile/blood-group work in P6), toggle "Share my ride" per ride or always-on, revoke link anytime (delete doc), sessions auto-expire (`expiresAt` + TTL policy).

**Privacy/safety notes:**
- Link grants location visibility — creating/sharing it must be an explicit rider action, revocable, with a visible "sharing active" indicator on the ride screen.
- If the phone dies or loses signal, `updatedAt` goes stale — the viewer page must show staleness prominently ("last seen 12 min ago") rather than a false live position. A Cloud Function can optionally notify the contact if a session goes silent mid-ride (> N min) — offer as opt-in "no-signal alert".

**Build steps:**
1. Emergency contacts CRUD in Profile.
2. Live session publisher in the recording engine (throttled writes, battery %, status transitions).
3. Crash detector + countdown UI + false-positive logging. Test with recorded sensor traces (drop-test + real ride data) before trusting thresholds.
4. Cloud Function: on `status → crash`, send SMS (Twilio or similar) / email / FCM to contacts.
5. Hosting viewer page (single HTML/JS file) + Firestore rules: `liveSessions/{token}` readable by anyone with the token, writable only by owner uid.
6. Tests: crash heuristic against fixture sensor traces (must NOT fire on pothole/hard-brake fixtures; MUST fire on crash fixtures), token expiry, rules tests.

---

## 12. Competitor-inspired feature map (Rever · Calimoto · Detecht · Tonit · EatSleepRide · Strava · Life360)

Researched 2026-07-12. Organized by theme, each idea tagged with the app(s) that proved it, an effort estimate (S/M/L), and a tier: **T1 = differentiating & cheap** (build into V1.x), **T2 = strong but needs the cloud backend** (after P5), **T3 = ambitious** (V2+, needs routing engines / critical mass of users).

### A. Ride intelligence & analytics — make the data ThrottleIQ already collects *mean* something
ThrottleIQ's edge is that it already captures accel + jerk per point; competitors mostly show speed/distance. Lean into it.

| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Lean-angle tracking** per ride (max + per-corner), from gyroscope fused with GPS heading. The single most-loved moto-app stat. `sensors_plus` already provides the gyro. | Calimoto, EatSleepRide | M / **T1** |
| **Personal records & trophies** — longest ride, biggest riding day, smoothest ride (lowest jerk/km), most km in a month. Local-only at first; no backend needed. | Strava | S / **T1** |
| **Weekly riding report** — distance, time, events (hard brakes / rapid accel / top speed), trend vs last week. Reuses the riding-score math; render with `fl_chart` (already a dep). | Life360 driver reports, Strava | S / **T1** |
| **Smoothness score trend** — a per-ride 0–100 score charted over months, "your braking got 12% smoother". Turns the jerk data into a retention loop. | Life360 driver reports | M / **T1** |
| **Year in Review ("ThrottleIQ Wrapped")** — shareable summary card: total km, hours, top speed day, favorite road. Big organic-growth lever, cheap once stats exist. | Strava Year in Sport | M / **T2** |
| **Segments & leaderboards** on popular road stretches. Needs cloud + user mass + safety framing (time-based leaderboards encourage speeding — consider *smoothness* leaderboards instead: on-brand and defensible). | Strava, Rever challenges | L / **T3** |

### B. Routes & discovery — give riders a reason to open the app *before* the ride
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Saved routes library** — save a past ride as a named route, re-ride it, share it. Already implied by `TODO now.md` (friends save shared routes to profile). | All moto apps | M / **T2** |
| **Discover roads from friends' rides** — a shared ride doubles as a route others can save. Falls out of P8 social + saved routes. | Tonit, Calimoto | M / **T2** |
| **Curated "best roads nearby"** — admin-seeded scenic/twisty roads (same admin-verified pattern as §10 POIs; a road is just a POI with a polyline). | EatSleepRide (editorial routes), Rever (Butler Maps) | M / **T2** |
| **Ride replay** — animated playback of the polyline with speed/lean overlays on the summary map. High wow-factor, purely client-side. | Rever 3D flyover (lite version) | M / **T1** |
| **Weather along the route / at destination** — one API call (e.g. OpenWeather) on the record screen: "Rain expected in 2h". Rever Pro charges for this. | Rever Pro | S / **T2** |
| **Curvy-route planner + turn-by-turn voice navigation** — the core of Calimoto/Rever. Needs a routing engine (Valhalla/GraphHopper with custom cost functions), offline maps, voice guidance. A product in itself — do NOT attempt before the tracker is solid. | Calimoto, Rever, Detecht | XL / **T3** |

### C. Safety — extend §11 into a full safety suite (the most defensible theme for a BD-market app)
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Crash escalation ladder** — §11's countdown, then: notify contacts → if no contact ACKs within N min, SMS all contacts with last location + a "call rider" deep link. Detecht escalates to a human SOS operator; contacts-only is the right V1 scope. | Detecht (60s countdown), EatSleepRide CRASHLIGHT, Life360, Rever Pro | (in §11) |
| **"Arrived safely" place alerts** — rider sets a destination; contacts on the live link get an automatic arrive/leave notification (geofence on the live session). Kills the "reached?" text message. | Life360 place alerts | S / **T2** |
| **Privacy zones** — auto-hide the first/last ~200 m of shared rides so home location never leaks. **Prerequisite for ANY ride sharing** — build it with P8, not after. | Strava | S / **T2** (required) |
| **Battery + staleness on the live link** — viewer sees rider's phone battery % and "last seen Xs ago" (already specced in §11; Life360 validates surfacing low-battery alerts to the contact). | Life360 | S / (in §11) |
| **Hazard pins** — riders drop "pothole / gravel / police check / flood" pins that appear for nearby riders; auto-expire after 24–48h. Same Firestore geo layer as §10. | Detecht hazard warnings | M / **T2** |
| **Group-ride live map** — every member of a group ride sees the others as pins; "regroup" alert if someone falls > X km behind. Extends the §11 liveSessions doc to a shared session. | Calimoto group rides, EatSleepRide ride groups, Life360 circles | M / **T2** |

### D. Community & gamification — retention once the tracker earns trust
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Challenges & badges** — monthly distance challenges ("500 km in July"), streaks, milestone badges (first 1,000 km). Start with *local* badges (no backend), add community challenges after P5. | Strava, Rever, Tonit | S local / M community · **T1→T2** |
| **Ride feed with kudos + comments** — share a ride card (map thumbnail, stats) to a friends feed; respects privacy zones. This IS the P8 "Social" tab content. | Strava, Tonit, Detecht | M / **T2** |
| **Clubs / riding groups** — join local clubs, group chat-lite (announcements), club ride events. | Tonit (its whole product) | L / **T3** |
| **Events & meetups calendar** — club rides and meetups with RSVP; pairs naturally with group-ride live map. | Tonit | M / **T3** |

### E. Garage & ownership — deepen the existing maintenance moat
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Odometer auto-sync** — ride distance auto-advances each bike's odometer, driving maintenance reminders without manual entry (fixes the `TODO now.md` service-status gap at the root). | (ThrottleIQ-native; no competitor does this well) | S / **T1** |
| **Fuel log** — liters + cost per fill-up → cost/km and mileage (km/L) trends. Huge in cost-sensitive markets; pairs with §10 fuel-pump POIs ("log a fill-up at this pump"). | Fuelio/Drivvo (adjacent category) | M / **T1** |
| **Documents wallet** — registration, insurance, license photos with expiry reminders. BD riders face frequent document checks; low effort, daily utility. | (market-native idea) | S / **T1** |
| **Resale story** — a bike's full maintenance + ride history as an exportable PDF ("full service history, 92% smooth-riding score") to boost resale value. Emotional-value play straight from the README's "machine memory" pitch. | (ThrottleIQ-native) | M / **T2** |

### F. Monetization signal (from competitor pricing)
Competitors prove riders pay for **safety and navigation, not tracking**: Rever Pro $39.99/yr (weather, LiveRIDE safety, premium nav) · EatSleepRide charges $14.99/yr for CRASHLIGHT crash detection alone · Strava $79.99/yr (analytics + Beacon-adjacent features) · Life360 tiers on place alerts + emergency dispatch. Suggested split when the time comes: **free = record + garage + maintenance + basic stats; Pro = crash detection escalation, weather, advanced analytics (lean angle history, smoothness trends), unlimited saved routes.** Keep the §11 basic live-share link free — it's the growth loop (every shared link is an ad).

### Proposed information architecture (UX pass)

Current nav (Social · AI · **Record** · Service · Garage) burns two of five slots on stub tabs. Reorganize to five real top-level destinations (bottom-nav limit ≤5, one job each, secondary features behind hubs — per the UX skill's nav-hierarchy/bottom-nav-top-level rules):

```
┌──────────┬──────────┬──────────┬───────────┬──────────┐
│   Home   │ Explore  │ ● Record │  Analytics│ Profile  │
├──────────┼──────────┼──────────┼───────────┼──────────┤
│ Feed +   │ §10 POIs │ (center, │ Rides list│ Garage   │
│ challenges│ hazards │ default, │ trends    │ Service  │
│ friends' │ routes/  │ big CTA) │ records   │ Fuel log │
│ rides    │ best     │ live map │ score     │ Documents│
│ weekly   │ roads    │ quick-   │ year-in-  │ Friends  │
│ report   │ nearby   │ fuel     │ review    │ Emergency│
│          │ weather  │ SOS      │           │ contacts │
└──────────┴──────────┴──────────┴───────────┴──────────┘
```
- **Record stays the center tab and default screen** (unchanged — it's the product).
- **Explore** replaces the stub Social tab (P7 already planned this): POI map + hazard pins + saved/curated routes + weather chip.
- **Analytics** replaces the stub AI tab: ride history, trends, records, weekly report. (The AI chatbot, when real, becomes an assistant surface *inside* Analytics/Service — "why was my score low?" — not a top-level tab.)
- **Home** hosts the feed/challenges once P8 lands; until then it's the weekly report + recent rides (no fake tabs — per the empty-nav-state rule, don't ship "Coming in V2" panels).
- **Profile** absorbs Garage + Service (matching `TODO now.md`: "Profile bottom nav will replace garage"), plus fuel log, documents, friends, emergency contacts, privacy settings.
- Safety actions (share live link, SOS) live ON the record/active-ride screens where the rider needs them — big touch targets, one-thumb reachable (44pt+ targets, no precision taps at speed; gloved hands argue for oversized controls throughout the ride surfaces).

### Sequencing note
- **T1 items** (lean angle, records/badges, weekly report, ride replay, odometer sync, fuel log, documents) are local-only and slot into **P2–P4** alongside the engine/UX work — they need no backend.
- **T2 items** ride the P5 Firestore foundation and extend P6 (§11 safety) / P7 (§10 Explore) / P8 (social) — fold privacy zones and "arrived safely" into those phases explicitly.
- **T3 items** (turn-by-turn curvy nav, segments, clubs/events) are V2+ bets — revisit after beta retention data says which theme (safety vs routes vs social) pulls hardest.

**Sources:** [Rever](https://www.rever.co/) · [Rever on Google Play](https://play.google.com/store/apps/details?id=com.reverllc.rever&hl=en_US) · [Strava subscription features](https://support.strava.com/en-us/articles/15402044-strava-subscription-features) · [Strava](https://www.strava.com/) · [Life360 driving safety](https://www.life360.com/driving-safety) · [Life360 crash detection](https://www.life360.com/crash-detection) · [Calimoto](https://calimoto.com/en) · [Calimoto review — Motorcycle.com](https://www.motorcycle.com/features/the-calimoto-riding-app-is-more-than-a-gps-app.html) · [Detecht](https://www.detechtapp.com/) · [Detecht crash detection guide](https://www.detechtapp.com/help/help-articles/automatic-crash-detection) · [Tonit](https://tonit.com/about/) · [EatSleepRide](https://eatsleepride.com/)

---

## Suggested execution order

| Phase | Scope | Outcome |
|---|---|---|
| **P0** | §0 repo cleanup + git baseline; re-apply lost May-14 fixes | One canonical, versioned codebase |
| **P1** | §1 background tracking + §2.5/2.6 accuracy gate + §3.1 batched writes + §3.4 crash recovery | The core feature actually works: a full ride records with screen off and survives a kill |
| **P2** | §2 remaining engine bugs (jerk, alerts, max-speed, calibration, idle segmentation) + §9 tests over the engine | Trustworthy metrics |
| **P3** | §3 remaining DB work (migrations, FKs/cascade, indexes) + §5 performance | Solid foundation for scale |
| **P4** | §7 release readiness + §6 auth polish + §8 UX fixes (interactive map, service-status link, back stack) + §12 T1 quick wins (lean angle, records/badges, weekly report, ride replay, odometer sync, fuel log, documents wallet) + §12 IA reshuffle (Explore/Analytics replace stub tabs) | Play Store internal-testing build with real differentiation |
| **P5** | §4 cloud sync/export (Firestore + Storage foundation) + profile (blood group, emergency contacts) | Cloud backend exists; data survives phone loss |
| **P6** | §11 emergency link: live share → crash detection → contact alerts + §12 safety extensions ("arrived safely" alerts, battery/staleness on link) | Safety suite live |
| **P7** | §10 POI directory + §12 Explore extensions (hazard pins, curated best-roads, weather chip) | Explore tab fully real |
| **P8** | Friends/QR + ride feed with kudos + saved/shared routes + group-ride live map + community challenges — **privacy zones ship first, as a prerequisite** (§12) | V2 social wave |
| **P9+** | §12 T3 bets: curvy-route turn-by-turn navigation, segments/smoothness leaderboards, clubs & events — pick by beta retention data | Long-term expansion |

Rule of thumb throughout: no fix ships without a test proving it, and every phase ends with a build installed on a real device and a recorded test ride.
