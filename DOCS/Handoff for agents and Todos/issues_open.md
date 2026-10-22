# Issues: open

_Was `Issues.md` until 2026-09-19. Resolved sections moved to `issues_fixed.md`._
Every issue that's still unresolved, in its original numbered section.
Section numbers (`§N`) never change. When something here gets fixed, move
its section or subsection to `issues_fixed.md` and keep the number.

New issues go at the end of this file with the next free number: **§112**. (§103–§106 are in use. §107–§110 were reserved on 2026-10-22 for leftovers from retired working notes. §97 names two different writeups: the Places/Forums first-iPhone-run findings, and the forum photos / paddock counts fix in `issues_fixed.md`. §85's open stub was folded into its `issues_fixed.md` writeup on 2026-10-22, so §85 now lives only there. §102 heads two different sections, and §79 is used twice (both now in `issues_fixed.md`); `issues_fixed.md` §83 also labels two items 81.29/81.30. §78 sub-items run to 78.30; §83 to 83.31. Check BOTH this file and `issues_fixed.md` before claiming a number.)

---

## Follow-ups on fixed issues

These sections are in `issues_fixed.md` because the core problem is resolved,
but each one leaves a smaller item behind:

- **§4:** the Firestore TTL policy on `liveSessions.expiresAt` is still off. The console refused it on 2026-10-08 (`403: billing disabled`, see §102), so it waits on Blaze (owner item #3). Older docs with string timestamps will never be reaped.
- **§62:** five items marked PARTIALLY FIXED list their remaining work inline: 62.2 (public stats and badges are still client-authored; a server-side recount needs Cloud Functions), 62.3 (the client sends the crash alert once instead of through the outbox; latent while crash alerts are off), 62.5 (`functions/src/chat-moderation.ts` still matches a 6-word English list), 62.9 (`deleted_bikes`, `auto_fixes` and pre-migration `auto_detections` rows have no owner column, so a deleted account's rows linger on a shared device) and 62.10 (keys on disk: owner item #9).
- **§89:** Gradle is still 8.13 (`app/android/gradle/wrapper/gradle-wrapper.properties:5`) and Flutter warns it will drop support below 8.14. Upgrade before the warning becomes an error, then run a release build.
- **Device checks (owner item #5).** None of these has run on a real phone:
  - the auto-tracking schedule (§37);
  - a real ride through the road-speed baseline publish, and a live Open-Meteo call (§42's "NOT yet verified" block);
  - the GPS-speed fallback; simulator playback leaves `Position.speed` empty (§49);
  - route navigation on a real ride (§78.21);
  - the open55 changes: the §87 checklist, the maintenance layout and ride-cost card, the collage visuals, the SQLite v17→18 upgrade on a real install (§88.3);
  - Bangla on a real device and above 1.0× text scale (§83.23);
  - the home and lock screen widgets (Apex Hunter, Ride Stats, Maintenance) on an iPhone release build and on Android, including App Group sharing in Xcode and the Lock Screen accessory layouts, plus the in-app cockpit widgets `DualLeanArcGauge`, `GForceFrictionCircle` and `ConsumablesHealthCard` (from item 8 of `todo_now_antigravity.md`, retired 2026-10-22, added in `1e98cf0e`; this bullet used to cite §98 by mistake).

---

## 33. Bug & vulnerability sweep — 5 parallel reviews, 18 findings, 16 fixed same session, 2 deferred (2026-08-23) (open parts)

> The resolved parts and the full context of this section are in `issues_fixed.md` §33.

### 33.5 Cloudinary unsigned-upload credentials are public and unbounded — HIGH

`app/lib/core/services/cloudinary_upload_service.dart:62-63` ships the cloud
name (`vjvcigkt`) and the unsigned upload preset (`throttleiq_unsigned`) in the
binary; `strings` on the APK/IPA pulls them out. Anyone can then POST images,
video or audio straight to Cloudinary (`/image/upload`, `/video/upload`) into
any folder, with no ThrottleIQ account, no auth and no rate limit. That is a
quota-exhaustion and abusive-hosting vector: a Cloudinary ToS suspension would
take down every avatar, ride photo and group-ride voice note at once. Voice
notes also sit at permanent public URLs. §63.3 and §83.16 are the same finding.

- **Now (owner item #11, partly done):** in the Cloudinary console, cap file
  size and formats on the `throttleiq_unsigned` preset and set a usage alert.
  No code change.
- **Real fix, after Blaze (owner item #3):** a callable Cloud Function mints a
  short-lived signature with a server-only `CLOUDINARY_API_SECRET`, and
  `CloudinaryUploadService` asks for one before each upload. Verify against a
  real Cloudinary account and deployed Functions; a blind change risks
  breaking every upload path (avatars, ride photos, voice notes).

---

## 62. Full-repo bug/vulnerability/architecture sweep — 4 parallel reviews, 26 findings, most fixed same session (2026-09-10) (open parts)

> The resolved parts and the full context of this section are in `issues_fixed.md` §62.

### 62.12 No App Check enforcement, no rate limiting — MEDIUM

Nothing in `firestore.rules` throttles write volume for ride shares, forum
posts, chat messages, reviews or reports, so a scripted client can flood
feeds at will and, with §62.2's leftover, pad leaderboards. App Check is
active in the client (§83.19, `app/lib/main.dart` `_activateAppCheck()`)
but not enforced: owner items #17 (when to enforce) and #32 (the sideload
gate). Enforce only once a build with App Check is what riders run, or older
builds get locked out. Rate limits need either Cloud Functions (Blaze) or
per-user counter docs checked in the rules; owner item #33 asks the same
question for reports.

### 62.13 Architecture notes (not bugs, but raise the odds of the next one)

- `firestore.rules` is a 2,252-line monolith (2026-10-22) that grew
  patch-by-patch, many clauses citing past fixes, rather than from an
  upfront threat model.
- `app/lib/core/cloud/cloud_repository.dart` (968 lines) is a
  God-repository spanning bikes, rides, maintenance, tracks and backups.
- `isAdmin` is hardcoded to one email client-side
  (`app/lib/features/forums/domain/forum_permissions.dart:10`) and mirrored
  by hand in `firestore.rules:136-141` (which also accepts an `admin`
  claim). Not spoofable, but the two can drift silently.
- `scripts/oneoff/seed_police_checkposts.js`/`_v2.js`/`_v3.js` reimplement
  the same geohash encoder and dry-run scaffolding three times (~500 lines).

---

## 64. Open parts of §64 (chat `permission-denied` report) — 63.3 Cloudinary unsigned preset NOT FIXED; the resolved parts are in `issues_fixed.md` §64

> The resolved parts and the full context of this section are in `issues_fixed.md` §64.

### 63.3 Cloudinary unsigned upload preset lets anyone who decompiles the app bypass it entirely — MEDIUM

Same finding as §33.5; the status, the interim mitigation and the real fix
are tracked there.

---

## 69. Full-repo critique pass — 12 fixed, 16 open (2026-09-19) (open parts)

> The resolved parts and the full context of this section are in `issues_fixed.md` §69, including the open-list items closed on 2026-10-22.

### Open — found, not fixed

- **69.O3 Crash alerts can't be cancelled server-side.** Once the countdown
  expires and a `crashNotifications` doc is written, "I'm OK" only resets
  local state: `firestore.rules` gives the client create only on that
  collection, so escalation would still fire. Latent while
  `SensorConstants.crashAlertsEnabled` is `false`
  (`app/lib/core/constants/sensor_constants.dart:70`). Solve before real SMS
  ships.
- **69.O14 `GoogleService-Info.plist` is tracked**
  (`app/ios/Runner/GoogleService-Info.plist`) although `.gitignore:83` lists
  it; it was committed before the ignore rule. Client config, not a secret,
  but the rule misleads. Untrack it, or drop the rule with a comment.

### Deploy needed

- `firebase deploy --only functions` (69.8–69.10, and `onUserAccountDeleted`,
  which has never been deployed): blocked until the project is on Blaze
  (owner items #3 and #31).

---

## 78. Antigravity grill verification: still open (surfaced 2026-09-20)

The grill's verdicts were in `ANTIGRAVRITY_GRILL/claude_sol.md`, later
`grillings/claude_sol.md` (retired 2026-10-22; read it from git). The fixed
items, and the open-list items closed on 2026-10-22, are in
`issues_fixed.md` §78.

- **78.1 Crash detection runs in shadow mode only.** Phases 1–3 of
  `DOCS/General/CRASH TESTING/crash_analysis_and_detection_plan.html` were
  built on 2026-10-15 (features.md, "Shadow-mode crash detection"), and the
  `firestore.rules` and `firestore.indexes.json` changes for
  `impactEvents`/`crashEvents` were deployed the same day. The live alarm
  stays off (`SensorConstants.crashAlertsEnabled = false`). The first real
  field crash (2026-10-14, a low-speed fall at a railway crossing, not
  detected) is analysed in `DOCS/General/CRASH TESTING/`. Still open:
  - **Not built:** the next-app-open prompt for auto-detected rides, Track v2
    (see the track gaps below), and a retention job for old sensor windows
    (`functions/src/track-retention.ts` only purges GPS trails).
  - **Calibration:** Phase 0 phyphox recordings and padded drop tests, then
    field rides to set the thresholds. The founder's task.
  - **Battery** cost of 50 Hz IMU sampling is unmeasured; needs a real ride
    (owner item #5).
  - **Store forms:** Play Data safety and the App Store labels must mention
    the opt-in research sharing before a release ships it (owner item #4).
    `public/privacy.html` §7 already does; the store drafts in
    `DOCS/General/Files for Stores/store_listing/`
    (`data_safety_and_permissions.md`, `throttleiq_data_safety.csv`) don't
    yet (2026-10-22). Updating the drafts is agent work.
  - `onUserAccountDeleted` erases `crashEvents`, but only once Cloud
    Functions can deploy (Blaze, owner item #3).
  - Turning the alarm on also needs the founder's choice of alert delivery
    (`needs_attention.md`) and §69.O3.
- **Track sync gaps (2026-10-14, see `DOCS/For Devs and Contributors/architecture/phone_vs_cloud_data.md`).**
  The `track.points` index exemption is done (`firestore.indexes.json:397`,
  deployed 2026-10-15). Still open:
  - (b) Only 5 of the 16 `ride_points` columns sync
    (`app/lib/core/cloud/ride_track_codec.dart:44`, `fieldsPerPoint = 5`). A
    reinstall loses altitude, accuracy, heading, confidence, period_type and
    segment_start. This has already happened for 115 of the founder's rides.
  - (c) The codec has no format version, and older builds step through flat
    chunks 5 values at a time, so they would misread wider ones. "Append a
    field at the end" is unsafe: add a version number before any field (this
    is Track v2).
- **78.12 Gyro heading sign and axis**
  (`app/lib/features/ride/domain/calculators/vehicle_state_estimator.dart`).
  Needs a phone mounted on a bike to verify, so it wasn't attempted.

---

## 80. Retired `likes`: the legacy `likes` rules block is still there (2026-09-20)

Code and data are done (`issues_fixed.md` §80, "79 / 80" and "80 (rest)").
One item left: `firestore.rules:1033` keeps `match /likes/{userId}` because
the app still lists that subcollection to sweep legacy docs when a share is
deleted (`app/lib/features/social/data/repositories/ride_share_repository.dart:519`),
and a list on a path with no rule is denied even when it would return
nothing. A 2026-09-21 sweep found no like documents anywhere. Order: drop
the sweep from the app, raise `config/app.minBuild` past that build, then
delete the rules block (ship the app before the rules, §78.27).
- **Step 1 done 2026-10-22 (branch `lane/a-reads-likes`, not on `main` or in a release yet):**
  `deleteSharedRide` no longer lists or deletes `likes`. **Owner actions left:** once a build
  with this change is out, raise `config/app.minBuild` past it, then delete the `likes` block
  from `firestore.rules` and deploy the rules.

---

## 83. Full-app critique pass (UI/UX, codebase, architecture, flow) — open parts (surfaced 2026-09-20, mostly fixed 2026-09-21)

Most of this section is resolved; see `issues_fixed.md` §83, including the
items closed on 2026-10-22. Full original writeup (folder deleted
2026-10-06, see §91): `git show 4b1a1b2^:ANTIGRAVITY_GRILL/Claude_CRTITISIZE.md`.

What is still open:

### 83.12 — the active-ride screen rebuilt in full, once per second — MOSTLY FIXED 2026-09-21

> Writeup in `issues_fixed.md` §83.12 (part). The outer build now selects three
> fields and the fast-moving panels select their own.

**Still open:** the argument is structural and **has not been measured on a
device** (profile a real ride for battery, heat and frame times).
`app/lib/features/ride/presentation/screens/record_screen.dart:110` and
`:326` still watch the whole `RideRecordingState`: the pre-ride screen, far
lower stakes than the cockpit, but the same pattern.

### 83.13 — DI is inconsistent with the "clean architecture" claim

`RideRecordingNotifier` news up its DAOs, calculators and coordinators as
`final` fields (`ride_recording_provider.dart:274-311`);
`maintenance_provider.dart:35` is a file-level `final _dao = MaintenanceDao()`;
`app/lib` references `FirebaseFirestore.instance` 27 times and
`FirebaseAuth.instance` 11 times (2026-10-22). `CrashCoordinator` accepts an
injected Firestore, so the pattern was known, and the notifier calls the
no-arg constructor anyway. **Same root cause as 83.28:** nothing that touches
I/O is injectable, so nothing that touches I/O is tested.

### 83.14 — 54 bare `catch (_)` blocks — PARTLY FIXED 2026-10-22

54 in `app/lib` (2026-10-22, down from 65), held there by the ratchet test
`app/test/core/utils/error_reporter_test.dart` (`_bareCatchBaseline = 54`; it
replaced the `CATCH_MAX` grep in `scripts/check.sh`). Many carry a justifying
comment and several are legitimate, but in a Crashlytics-instrumented app
each is a failure mode that never reaches the dashboard and gets reported as
"it just didn't work".

Done 2026-10-22: `reportSilently(e, st, where:)` in
`core/utils/error_reporter.dart` (non-fatal via `reportNonFatal`, no-op in
debug and tests and for Firestore `unavailable` / `deadline-exceeded`, never
throws). 11 swallowed catches now report it, behaviour
unchanged: auth (seed profile, display-name sync, local wipe on account
delete), ride (start-failure cleanup, public stats push), outbox payload
decode (`outbox_dao.dart`, `database_helper.dart`), badge sync, malformed
cloud bike, corrupt medical info, Cloudinary ledger write.

**Still open:** triage the other 54. Non-UI first: `features/ride/`
(`ride_recording_provider.dart` battery-opt prompt and wakelock,
`ride_summary_screen.dart` 2, `active_ride_screen.dart` 1),
`bug_report_service.dart`, `privacy_zone_salt.dart`, `nominatim_service.dart`.
Then UI (`group_ride_map_screen.dart` 8, social providers and screens,
`place_launch_actions.dart`). Some are expected and may stay (Google
sign-out, "already gone" deletes in `group_ride_repository.dart`,
`isServiceRunning`). `outbox.decodePayload` and `profile.parseBike` report
again on every read of the same broken row; add a once-per-key guard if that
gets noisy. Lower the baseline as they are replaced.

### 83.16 (part) — the Cloudinary preset is still an open upload endpoint

Same finding as §33.5; tracked there.

### 83.18 — blocking is partly a client-side filter

The rules now hide `followers`/`mutual` rides from a rider the author
blocked (`firestore.rules:27-39`, `dc4fad1d`) and stop chats, follows and
notifications between the two. Public rides are not covered (an `exists()` there would make
the public feed query unprovable, per the comment above `rideVisibleTo`), so
`visibleFeedProvider`
(`app/lib/features/social/presentation/providers/ride_feed_provider.dart:103`)
still downloads a blocked rider's public rides and filters them on the
device, and a blocked rider can still read the blocker's public content.
Wants a server-side edge, not a `.where()`.

### 83.22 (part) — accessibility is a stopgap

Icon-only buttons got tooltips and text scaling is clamped to 1.0–1.3×
(`app/lib/app.dart:371-372`), but `app/lib` has 0 `semanticLabel`s and 29
`Semantics(` widgets in 445 files (2026-10-22), and the clamp exists because
layouts overflow above ~1.3× rather than reflowing. Make the fixed-height
cockpit rows, chips and stat tiles scale-tolerant so the clamp can be raised
or dropped. For an app read outdoors in sunlight through gloves this is
legibility work, not a minority feature.

### 83.23 (part) — localization: what is left

The main pass is done (`issues_fixed.md` §83.23 (rest) and (part)).
Remaining:

- **Bangla review by a native speaker (the real gate, owner item #12,
  deferred to November).** `app/lib/l10n/bn_pending_review.txt` lists the
  machine-drafted strings by batch (1,703 non-comment lines on 2026-10-22),
  including the strings from §78.28 and §88.4. Nothing in it has been read by
  a native speaker. `arb_parity_test.dart` keeps the list from naming dead
  keys.
- **Bangla on a device:** the 2026-09-21 UI tour walked 82 screens in Bangla
  on the iPhone 17 Pro simulator at text scale 1.0 (0 overflow lines). Not
  covered: a real device (see the device-check follow-up at the top), text
  scale above 1.0 (§83.22), and ~21 sections whose controls the tour finds by
  English text.

### 83.28 — screen tests and goldens

8 `*screen*_test.dart` files, 61 test files that pump a widget, 0 goldens
(2026-10-22). The tests cover the pure calculators exhaustively and the
presentation layer thinly, which is where the UX defects in this section
lived. Same root cause as 83.13.

**2026-10-22 (lane H), now covered** (the §107.2 order):
- Active ride: `test/features/ride/presentation/screens/active_ride_screen_test.dart`.
  Pause/resume, pause disabled during a transition, End Ride hold → summary (not
  the idle redirect), Keep riding, Discard ride (keep / confirm), crash takeover
  stays hidden while `crashAlertsEnabled` is off, restored-ride banner, idle →
  Record. Fake recorder via `implements RideRecordingNotifier`.
- Sign-in: `test/features/auth/login_screen_test.dart`. Validation, trimmed
  email, a Firebase error shown in words, password eye, Sign Up link.
- Sync issues: `test/features/profile/sync_issues_screen_test.dart`, real
  in-memory SQLite outbox. Account scoping, Retry (delivered / failed again),
  Discard (cancel / confirm). **Bug it found, fixed:** the Retry SnackBar never
  showed. `retryDead` revives the row, the list reloads without it, the card
  unmounts, and `if (!mounted) return` swallowed the result.
- Maintenance already had screen tests (`test/features/maintenance/`).

**Still open:** `RecordScreen` (its `initState` reads `FirebaseAuth.instance`,
§83.13, so it can't be pumped without Firebase); the crash countdown overlay
itself (private and unreachable while `SensorConstants.crashAlertsEnabled` is
a `const false`; test it when tier 2 ships); settings and onboarding steps
beyond `onboarding_tour_test.dart`; register; 0 goldens. The `_endingRide`
guard in `_cancelRide` has no test of its own (its redirect lands on the same
`/home/record`); the one in `_stopRide` is covered.

---

## 84. Four orphan-candidate Firestore indexes (2026-09-21)

The four indexes the project had but `firestore.indexes.json` didn't are now
declared in the file (12 → 16 on 2026-09-21), so a `--force` deploy can no
longer drop them silently. **Still open:** retire them deliberately. No query
in `app/lib` or `functions/src` uses them (re-checked 2026-10-22):

| Collection | Fields | Why it looks dead |
|---|---|---|
| `liveSessions` | `userId`, `expiresAt` | No matching query; possibly console-made for the §4 TTL work |
| `rides` | `allowedUserIds`, `createdAt` | Superseded by the 3-field `(allowedUserIds, audience, createdAt)` the live query needs |
| `rides` | `isPrivate`, `createdAt` | `isPrivate` predates `audience`; never queried |
| `rides` | `public`, `startTime` | `public` is only a value of `audience`; `startTime` is queried on `groupRides` only |

Before deleting, check the `scripts/` utilities, queries run by hand in the
console, and `functions/`. Then remove each from the file and the console
together. A dropped index breaks its query at once in production
(`failed-precondition`, the §82 failure in reverse). **Never run
`firebase deploy --force` to clear the "4 indexes not in your file"
warning.**

---

## 86. Social redesign (mock was `ANTIGRAVITY_GRILL/new_task`, deleted, see §91.6) was left half-wired with fake data — FIXED (2026-09-27), two follow-ups still open

> The fix, the `groupRides` list-rule deploy and the iOS signing notes are in
> `issues_fixed.md` §86 (moved 2026-10-22).

- **Solo "riding now" cards** for a followed rider who is live but not in a
  group ride were deliberately not built: there is no backend signal for
  "someone I follow is live right now", and `liveSessions`/`livePointers` are
  non-enumerable for privacy on purpose (see the `firestore.rules` comments).
  Needs a design pass on what is safe to show followers.
- **A per-card location label** needs a one-time reverse-geocode at share
  time, cached on the ride doc (`SharedRideEntity` has no place-name field).
  See features.md §7 for why geocoding per card live isn't safe.

---

## 90. Full-codebase audit — 5 parallel reviews (2026-10-06) — MOSTLY FIXED; open: architecture debt, one silent failure

Fixed in code in `6264d72` (2026-10-06). `issues_fixed.md` §90 lists every fixed ID and
keeps the findings as first logged (90.A–90.E, the triage order, the architecture verdict).
Re-checked against `main` (`3ebbd21d`) on 2026-10-22. Still open:

- **90.A13 — LOW — deleting from My Shared Rides fails silently.**
  `my_shared_rides_screen.dart:43` awaits `RideShareRepository().deleteSharedRide(rideId)`
  with no try/catch, so a failure shows nothing. *Fix:* try/catch around the delete, with a
  SnackBar on failure.
- **90.B4 — MEDIUM — repositories are hidden singletons** (update to §83.13). 10 repositories
  use a static `_instance` + `factory X() => _instance` (e.g. `cloud_repository.dart:26-28`;
  `forum_repository.dart:135-140` adds a test setter), and `XRepository()` is called 66 times
  outside `data/`. Tests can't fake them. *Fix:* providers for Firestore/Auth/DB/current uid,
  and repositories behind providers.
- **90.B5 — MEDIUM — layering is partly nominal.** 7 presentation files still import
  `cloud_firestore`/`firebase_auth` directly. The other 2026-10-06 counts (presentation files
  importing `data/`, domain leaks, `core/` files importing features) were not re-measured.
- **90.B6 — MEDIUM — bare catches** (update to §83.14). `app/lib` has 54 bare `catch (_)` (2026-10-22),
  held by the ratchet test in `error_reporter_test.dart`. Many catches only `debugPrint`,
  which is invisible in release (about 42 on 2026-10-06; not re-counted). *Fix:* route
  them to `reportNonFatal` (`core/utils/error_reporter.dart`), then lower the ratchet.
- **90.B7 — MEDIUM — god files.** Over 1,000 lines on 2026-10-22: `ride_recording_provider.dart`
  1,623, `settings_screen.dart` 1,498, `ride_summary_screen.dart` 1,319, `database_helper.dart`
  1,260, `group_ride_map_screen.dart` 1,208, `active_ride_screen.dart` 1,197,
  `shared_ride_detail_screen.dart` 1,094. The planned ride-provider split
  (`RideSessionController` / `GpsPositionHandler` / `CrashAlertCoordinator` /
  `LiveSessionManager`, old §92.A8) was never done.
- **90.B8 — LOW — dead code is still in the tree.** `features/ride/domain/repositories/ride_repository.dart`,
  `features/ride/data/repositories/ride_repository_impl.dart`,
  `features/ride/presentation/providers/ride_repository_provider.dart` (and
  `test/repositories/ride_repository_test.dart`), `core/constants/motorcycle_quotes.dart`,
  `core/utils/extensions/datetime_extensions.dart`, `features/auth/domain/entities/user_entity.dart`,
  and `test/widget_test.dart` (`expect(true, isTrue)`). The 2026-10-06 session's permission
  check blocked the delete. Confirm nothing imports them, then delete.
- **90.B9 — MEDIUM — test shape** (update to §83.28). `RideRecordingNotifier` can now be built
  in a test container (`ride_recording_dispose_test.dart`, `4b914c10`), but its
  start/pause/resume/stop flow has no direct test. There are no golden tests.
- **90.B10 — MEDIUM — dependency majors held back** (unchanged since 2026-10-06):
  `google_sign_in ^6`, the FlutterFire set (`firebase_core ^3`, `firebase_auth ^5`,
  `cloud_firestore ^5`, …), `flutter_riverpod ^2.5`, `go_router ^13`, `geolocator ^11`,
  `flutter_local_notifications ^17`, `permission_handler ^11`, `sensors_plus ^4`,
  `flutter_lints ^3`. *Order:* FlutterFire + `google_sign_in` in one PR, then
  permissions/geolocator/notifications, then go_router/riverpod after launch. Plugin bumps
  need a device pass.
- **90.B13 — LOW — router.** The bottom nav is a plain `ShellRoute`, so every tab switch
  rebuilds the screen and loses its scroll state. *Fix:* `StatefulShellRoute.indexedStack`,
  together with the go_router upgrade (B10) and a device pass.
- **90.B14 — LOW — repo hygiene, what is left.** The generated
  `app/lib/l10n/app_localizations*.dart` files are tracked, so every regen adds diff noise.
  (The root clutter is gone, `DOCS/General/screenshots_ui/` was untracked in `44c131eb`, and
  the keystore is no longer at the repo root.)
- **Founder items:** make the `flutter`, `rules` and `functions` checks
  required on `main` (B1); deploy rules and indexes, then run
  `scripts/oneoff/backfill_users_visibility.js`; the Play declarations for background location,
  the full-screen intent and the battery-optimization exemption (B12); before the first
  functions deploy, confirm Cloudinary's folder mode, because the D2 sweep only destroys public
  ids under `<kind>/<uid>/`.
- **Device checks** (never run on hardware): pause stops the Android foreground notification,
  and resume restarts GPS and the notification (C1); `FlutterForegroundTask.isRunningService`
  from the UI isolate (C2); the background isolate sees the ride marker after `prefs.reload()`
  (C3); the C4 pointer transaction; the iOS microphone and camera prompts after `pod install`
  (B2/B3); the 20 s group-ride cadence.

---

## 91. Critique leftovers carried over when `ANTIGRAVITY_GRILL/` was deleted (2026-10-06)

The root `ANTIGRAVITY_GRILL/` folder (the 2026-09-20 critique `Claude_CRTITISIZE.md` and the
Social Redesign mock HTML/PDF) was deleted. The items below were never fixed and weren't
tracked in §83. The original writeup is in git history:
`git show 4b1a1b2^:ANTIGRAVITY_GRILL/Claude_CRTITISIZE.md`. Re-checked 2026-10-22: all still open.

- **91.1 — LOW — `bikesVisibleTo(uid)` does a `get()` of the owner's profile per bike read**
  (`firestore.rules:102-104`). These are billed rules reads and count against the 10/20 access
  limits. Fix: denormalise the visibility onto the bike doc.
- **91.2 — LOW — `crashNotifications` create has no rate limit** (`firestore.rules:894`). The
  doc id must equal the `rideId`, but ride ids are client-chosen, so a signed-in client can
  still write unlimited `pending` docs for itself. Each would trigger a Cloud Function once
  functions deploy (Blaze). App Check (§83.19) narrows this but doesn't bound volume.
- **91.3 — LOW — the cockpit alert flash can't be switched off.**
  `active_ride_screen.dart:231-243` washes the live map with a translucent colour on brake /
  accel / overspeed / fatigue. Only the overspeed threshold is configurable. Add an off switch
  in settings.
- **91.4 — LOW — eager lists.** On 2026-10-22, `app/lib` had 32 `SingleChildScrollView` uses
  and 34 `ListView.builder`/`.separated`. Convert the long lists (rides list, forum threads,
  places list) to lazy builders. `SavedPlacesTab` was converted on 2026-10-07 (`b600f103`).
- **91.5 — LOW — the onboarding tour before the first ride is long and English-heavy**
  (`onboarding_manifest.dart`, `kOnboardingManifestVersion = 5`). Consider cutting it to the
  Record tab's hold-to-start. Related: §102.6, §83.26 and §83.23.
- **91.6 — DESIGN — Social Redesign mock deleted.** The §86 follow-ups (solo "riding now"
  cards, per-card location label) were designed against that mock. It's in git history:
  `git show 4b1a1b2:"ANTIGRAVITY_GRILL/new_task/ThrottleIQ Social Redesign – Main.html"`.

---

## 92. Not-yet-done items carried over from `sum_claude.md` / `sum_gemini.md` (2026-10-06) — engineering ideas

Both 2026-09-08 summaries are in git history (`git show 15b42f1:sum_claude.md`, `:sum_gemini.md`).
`optimizerplan.md`, which some items pointed to, was deleted in `8af74c9f` (2026-10-09). The
go-to-market, monetisation and launch-copy parts (old 92.B–92.D) moved to `issues_fixed.md` §92;
their content lives in `DOCS/Handoffs for Non Coding Agents/marketing/`. 92.A8 is now §90.B7
and 92.A9 is §96.1. Ideas, none built unless noted:

- **92.A1 — crash/sensor thresholds are theoretical.** 80 m/s² crash, -4.0/3.5 m/s² brake/accel
  and 100 km/h overspeed were set from first principles. Validate them against real ride
  telemetry across mounts (tank bag, handlebar, jacket pocket). Crash detection runs in shadow
  mode only, so this is what would let it alert. Field notes: `DOCS/General/CRASH TESTING/`.
- **92.A2 — lean-angle telemetry: partly built.** Lean and g charts exist since 2026-10-09
  (§102.5), but they are GPS estimates. No roll-rate lean from the IMU, no corner entry/exit
  asymmetry.
- **92.A3 — threshold presets** (Urban Commute / Highway Touring / Track Day).
- **92.A4 — on-device crash classifier** (TFLite/ONNX trained on real waveforms to tell crashes
  from potholes, speed bumps, railway crossings). Needs the corpus from 92.A1 first.
- **92.A5 — predictive maintenance** from riding intensity (jerk, hard braking, stop-and-go
  time) instead of fixed km intervals. The §95 adaptation factors are a heuristic first step.
- **92.A6 — real map matching** (Valhalla/GraphHopper offline) and a "curviness" route planner.
  The precision-7 geohash baselining is the stopgap.
- **92.A7 — BLE OBD-II / TPMS** for RPM, throttle, coolant temp, tyre pressure.

## 93. Auto-tracking daily summary + beta jam labels — follow-ups (2026-10-06) — device checks left

What shipped is in `features.md`. The done parts (93.1, 93.2, 93.4, 93.5, 93.6) and the 93.8
note moved to `issues_fixed.md` §93. The Bangla review (93.7) is part of the Bangla review in
`needs_attention.md`. Still open:

- **[needs-you] 93.3 Needs a device test:**
  - how quickly auto-tracking stands down after a manual Start;
  - whether the background service on Android can show `flutter_local_notifications`;
  - the 9pm digest replacing the fixed "Tap to see your day" message (the fixed text may show for
    up to about 60 s first);
  - iOS at 9pm, where the background handler may not be alive and opening the app is the fallback.

## 95. Maintenance redesign (2026-10-07) — committed `238d12b`, not checked on a device

What shipped is in `features.md` §5. The closed parts (95.6, 95.8, the fixed half of 95.12) are
in `issues_fixed.md` §95, and 95.13 is in `issues_fixed.md` §95.13. The Bangla review (95.7) is
part of the Bangla review in `needs_attention.md`. Still open:

- **[needs-you] 95.1 Device test.** None of the following has been run on a phone yet:
  - setup → Log a visit → Undo → edit → delete (then reinstall: the deleted
    visit must stay gone);
  - notifications: due-soon/overdue after a ride, scheduled date reminders,
    paperwork, tap → page;
  - the home widget's new wording;
  - PDF share;
  - receipt photo after an app update (iOS container path change is handled by
    `BikeImageResolver`, untested here);
  - the 60-day strip at small widths;
  - Bangla layout.
- **[needs-you] 95.2 Schedule templates are mostly approximate.**
  - Only the Bajaj Pulsar 150 template was read off a manual, and that was the
    Indian BS-VI manual.
  - Hornet 160, FZ, R15/MT-15, Gixxer, Apache 160 and the three generic
    templates come from coupon schedules and owner reports. The UI labels them
    "Approximate".
  - Each needs checking against the BD-market manual from ACI Yamaha, BHL Honda,
    Uttara Bajaj, Rancon Suzuki and TVS.
  - Each template's `source` note is English-only.
- **[needs-you] 95.3 Free-service counts per BD distributor are unverified.** The templates
  carry Indian schedules.
- **[needs-you] 95.4 Adaptation factors are a heuristic**, not OEM figures:
  - stop-and-go 0.8/0.9 at 35%/20% idle;
  - hard braking 0.85 at ≥ 3 per 100 km;
  - dusty/wet roads 0.7 on the air filter and chain;
  - floor 0.7.

  Validate them with 2–3 mechanics. The rider can switch adaptation off.
- **[needs-you] 95.5 Receipt photos aren't backed up.** They are stored only in the app
  documents folder; the path syncs, the image doesn't. There is no receipt OCR
  either. Uploading private receipts needs a non-public store (Cloudinary
  presets here are unsigned/public).
- **[doable-now] 95.9 Detected-trip credits go to the active bike**, since a detection carries
  no bike (`detected_odometer_credit.dart:28`, `:102-109` picks `is_active DESC, last_ride_at
  DESC`). A rider who switches bikes without changing the active one credits the wrong bike.
  The credits table is local; the bike's `odometer_km`, which holds the total, does sync. If the
  rider has no bike, the trip credits nothing (`:78`).
- **[needs-you] 95.10 Open product questions:**
  - Should Maintenance get a bottom-nav tab? Garage cards now show "next due".
  - Should snooze also support "100 km later"?
  - Should the hero hide when everything is unknown?
- **[needs-you] 95.11 The order button is still a demo.** It is gated to
  `BetaTesters.partOrdering` (`beta_testers.dart:18`). It needs a parts partner before a real
  flow.
- **[doable-now] 95.12 Still open from the 2026-10-07 code review** (not re-checked 2026-10-22
  unless noted):
  - The new-bike baseline is derived from `odometer_km − credits`. An odometer
    sync or a reinstall (credits are local) can push "km at add" past 500, and
    never-logged checks then flip to "unknown". Fix: store the odometer reading
    at add time.
  - Receipt image files aren't deleted with their visit (no delete path found 2026-10-22).
  - A page left open past midnight shows yesterday's day counts until something
    refreshes it.
  - The home-screen widget text is English and km-only (`home_widget_service.dart`). Alerts
    follow the km/mi choice since §101.R10.
  - On a fresh install, paperwork added *before* the first sync restores still
    replaces the cloud paperwork list. Sync runs at sign-in, so the window is
    small.

---

## 96. Budget-phone readiness for Bangladesh riders (surfaced 2026-10-07, partly started)

The Play Console device count (12,312 phones, `minSdk 24`) already covers the
budget phones sold in Bangladesh, so installing isn't the problem. The risk is
whether the app keeps working on them once installed. Nothing below has been
tested on a real budget phone yet. A full screen-off ride on a 2–3 GB itel,
Tecno or Redmi would check all three.

- **96.1 OEM battery managers kill background services — HIGH.** Xiaomi
  MIUI/HyperOS, Tecno/Infinix/itel (HiOS/XOS) and Realme/Oppo (ColorOS) kill
  background services aggressively. That can silently stop auto-tracking and
  crash detection.
  - **Partly done 2026-10-15 (critique B5, not on a device):** Xiaomi/Redmi/POCO,
    OPPO, realme and vivo/iQOO get a one-time guide after the first finished
    ride (`oem_guide_screen.dart`: vendor autostart screen, app info, lock in
    recents, dontkillmyapp link). Manual rides now run in the foreground-task
    service and keep recording when the UI goes away.
  - **Still open (checked 2026-10-22):** Tecno, Infinix, itel and Samsung have no guide
    (`oem_guide_screen.dart` knows only Xiaomi, OPPO, realme and vivo), and nothing in settings
    reopens the guide (only `record_screen.dart:61-76` offers it). See dontkillmyapp.com for
    each brand's steps.
- **96.2 Phones with no gyroscope / weak accelerometer — MEDIUM.** Many budget
  phones have no gyroscope. The manifest already marks the accelerometer and
  gyroscope `required="false"`, so the app installs. Still to check: crash
  detection and lean-angle (`sensor_fusion_coordinator.dart`,
  `vehicle_state_estimator.dart`) degrade gracefully when there's no gyroscope
  stream. They should not crash, show 0° or fake lean, or fire false crash
  alerts. The UI should say clearly when lean angle isn't available on the
  phone.
- **96.3 Low RAM (1–3 GB) — MEDIUM.** The OS is more likely to kill the app
  mid-ride, and map screens can stutter. Check ride recovery after a process
  kill on a low-RAM device, and map/ride-screen performance there. Measure the all-day
  auto-tracking wakelock (§101.C6) on the same phone.

## 101. Full-project audit (2026-10-07, read-only, 7 parallel passes) — MOSTLY FIXED 2026-10-08; open remainder

Every item, with its 2026-10-08 verdict and resolution, is in `issues_fixed.md` §101. Re-checked
2026-10-22:
- **Fixed since the audit:** B2 (`app/ios/Runner/PrivacyInfo.xcprivacy`, `5c2db5bf`); the S2
  code (the `posts`/`replies`/`comments` `userId` overrides are in `firestore.indexes.json`,
  `d1205d53`; not deployed); S12 (`public/privacy.html` shows hello@blankframe.tech, `0c0de47b`);
  the C10 disclosure (`privacy.html` lists Open-Meteo); P3's tile contact (hello@blankframe.tech,
  delivery confirmed 2026-10-22); D3 (`new_gravity.md` deleted in `8af74c9f`); D1
  (`DOCS/General/screenshots_ui/` untracked in `44c131eb`); S13's key question (`git grep
  'BEGIN PRIVATE KEY'` finds no file at `d7ea7fe`, `f1d252d`, `1b1e5cf`, `a572868` or their
  parents).
- **Obsolete:** S6 and the group-ride half of A2. RTDB denies every read and write since
  `8872feff`, and the group-ride RTDB client was removed in `4cb96a8f` (2026-10-14).

**Still open, agent work.** Each was REAL-BUT-SKIP on 2026-10-08 for the reason given in
`issues_fixed.md` §101. Only the items marked "checked" were re-read on 2026-10-22.
- **101.C1** no timeouts on sync `batch.commit()`. A timeout doesn't cancel the write, so this
  needs cancel tokens or idempotent batches first.
- **101.S3** username squatting (tie `usernames` to `users/{uid}.usernameLower`);
  `groupRides/members` writes by non-members (needs a Cloud Function).
- **101.S7** full CSP and SRI for `public/live-viewer.html` (Leaflet from unpkg, Firebase from
  gstatic). Checked: `firebase.json` sends only `frame-ancestors 'none'`. Needs a browser check.
- **101.S9** `scripts/` pins `firebase-admin ^12`, `functions/` `^14`.
- **101.S10** actions aren't SHA-pinned; CI runs twice (push and PR).
- **101.S11** stale indexes in `firestore.indexes.json` (checked): `liveSessions (userId,
  expiresAt)` though the field is `uid`, the `crashNotifications` COLLECTION_GROUP index, and the
  legacy `rides` indexes. Remove them only together with an index deploy (§84).
- **101.C9** outbox `next_attempt_at` is stored as local time (needs a compat read); the router
  treats auth loading/error as signed out; `bug_report_service.dart:74` hard-codes version
  `'1.0.0'` (checked); some notification channel names are English.
- **101.R2** no warning when a log's odometer is below the previous one. **101.R3**
  `latestLogFor` picks the highest odometer, not the latest date (needs a product rule for
  odometer resets). **101.R5** a tiny `deltaT` inflates jerk. **101.R9** `forecast_strip`
  diamond semantics, `_UnitSegment` visual size, the swatch Auto tile reads 'Bike color'.
  **101.R10** the recording clock isn't a `Stopwatch`.
- **101.A4** the remaining `GestureDetector` semantics in the `social_feed_tab` group-ride card
  and the username link.
- **101.P5** the English `displayName` fallback is stored in Firestore; no ODbL attribution on
  the places list and detail (the map tiles carry it). **101.P6** `searchPlacesByName` is
  case-sensitive; `getGeohashesForViewport` (`geohash_utils.dart:24`) has no callers.
  **101.P7** `LocaleNotifier` has no try/catch around prefs.
- **101.B3** CI has no release build. **101.B5** proguard keep rules are over-broad;
  `targetSdk` follows Flutter. **101.B8** CI never runs `integration_test/` and has no coverage
  step.
- **101.C6** auto-tracking holds a CPU wakelock all day (`auto_tracking_service.dart:548`
  `allowWakeLock: true`). Measure the battery cost on a budget phone (§96.3).

**Founder items:** the S2 index deploy; GitHub secret scanning (S10, a
repo setting); move local secrets out of the repo tree (S13) and restrict the Firebase API keys
(S14); the Play declarations (B4); a valid App Store marketing version (B7: `pubspec.yaml` is
`1.0.0-beta.4.7.1+29`) once the Apple Developer Program enrolment is done; darken `textTertiary`
and the light `success`/`warning` colours (P2, a design call); keep or delete the reports a
deleted rider filed (S4).

---

## 102. Founder decisions of 2026-10-08 — BUILT and committed (`2f892e35`); one gap left

The decisions (bike archive, Garage tab, English-style Bangla dates) and that day's notes
(E2E, GitHub security, Cloudinary preset, TTL attempt, CI cleanup) moved to `issues_fixed.md`
§102. Their founder items: required CI checks and the Dependabot PRs, the Cloudinary size cap
and usage alert (delete the `preset_test/` assets too), Blaze (for TTL), Pitch Slide 9. Blocking and Cloudinary scope stay in §83.18 and §83.16. Also founder: if
CodeQL default setup still fails for `java-kotlin` and `swift` (it cannot autobuild a Flutter
app), untick both in Settings → Code security. Still open:

- **LOW — expired `liveSessions` docs are never cleaned up.** TTL on `liveSessions.expiresAt`
  needs Blaze (`403: Project throttleiqfb has billing disabled`, 2026-10-08). The fallbacks were
  never built: filter reads on `expiresAt > now`, delete the rider's own expired docs from the
  client, and clear old string-timestamp docs by hand.
- **Device check:** the archive flow's share-sheet export and cleanup options, and the 90-day
  purge on app start.

---

## 102. Themes / analytics / badges / QR / tour pass — open follow-ups (2026-10-09)

Committed since. 102.2 (the done part) and 102.8 (obsolete) moved to `issues_fixed.md` §102. The Bangla
review (102.7, deferred to November 2026) is in `needs_attention.md`. Still open:

- **102.1 Badge counters.** The rarity UI was removed in `12209669` (2026-10-14), so skewed counts
  no longer show. The client still writes `stats/badges` (`badge_stats_counter.dart`) because
  `firestore.rules` pairs those writes with `earnedBadges`. Riders can still self-award
  `earnedBadges` docs (rules gap), and `totalRiders` counts every account. The rules need a
  `firestore:rules` deploy (founder).
- **102.2 (open part) iOS Universal Links are off** (2026-10-09). Team `NJ4675FFUX` is a personal team, which
  Apple never allows Associated Domains, so the entitlement was removed from
  `Runner.entitlements`. iPhone camera scans open the web page, whose "Open in ThrottleIQ" button
  uses `throttleiq://u/<uid>`. After the Apple Developer Program enrolment, re-add the
  entitlement and serve `/.well-known/apple-app-site-association` (application/json, no
  redirect) from blankframe.tech (founder: the enrolment).
- **102.3 QR gaps** (not re-checked): no deferred deep link (after installing, the rider must
  re-scan); a well-formed uid for a non-existent rider still writes a harmless follow doc (rules
  make missing and private look the same); QR buttons only on `/profile`, not the Garage tab
  header; the saved QR PNG keeps the colors of first render.
- **102.4 Widgets:** the theme-following home-screen widgets were never checked on a device. (The
  shape-vibe part is obsolete: two themes since `24024501`.)
- **102.5 Charts remainder:** the bike odometer isn't advanced by a higher fill-up reading (not
  re-checked); fuel units are hard-coded (`'L'` at `add_fuel_log_screen.dart:313`, `'km/L'` at
  `fuel_presentation.dart:22`, `'km/l'`/`'mpg'` at `running_costs_sheet.dart:187`); no tour slide
  for fuel. Lean/g are GPS estimates and legacy rides get elevation only, by design.
- **102.6 Tour:** card tour + "Show me" rather than real-widget coach marks; no floating banner on
  `/profile`. `.agents/skills/onboarding-guardian/SKILL.md` accepts the v4 step list.

## §103 Shared-ride card / owner actions follow-ups (2026-10-15)

103.1 and 103.4 are done (`issues_fixed.md` §103). Still open:

- **103.2 Delete ride:** the bike's odometer and stats are not rolled back when a ride is deleted
  from history. Checked 2026-10-22: `RideDao.deleteWithTombstone` (`ride_dao.dart:324`) removes
  the ride, its points and impact events, and writes the tombstone; nothing touches the bike.
  Shared-post delete there is best-effort (silent offline).
- **103.3 Detail screen:** the rider card still shows `bikeName · bikeType` ("Motorcycle"
  fallback) at `shared_ride_detail_screen.dart:666`. Only the feed card was changed.
- **103.5 Cockpit:** the `_GroupRideTalkPill` comment in `active_ride_screen.dart` sits above
  `PhonePlacementSelector` (cosmetic). With a large iPhone bottom safe area, the controls (~174 px)
  may still reach the speed panel's fixed `bottom: 160` (`active_ride_screen.dart:790`; not
  checked on a device).

## §104 Spark quota load test (2026-10-15, `714f8d6`; report `DOCS/Handoff for agents and Todos/load_test/load-test-2026-10-15.md`)

Emulator simulation of the app's real query shapes (`scripts/loadtest/quota_sim.js`, `npm run loadtest:quota`). Verdict: fail. Reads run out first, at about 18 daily active riders (about 9 at the 50% target).

- **104.2 HIGH — group-ride reads grow with N².** Measured: N² + N reads per 20 s tick. A 20-rider ride uses the whole daily read quota in about 40 min. The RTDB relay is gone (`4cb96a8f`, `8872feff`), so the fix is a wider interval and move gate, or one shared positions doc per ride.
  - **Mitigated 2026-10-22 (branch `fix/reads-104`):** the publish interval now grows with the ride size (20-40 s); details in `issues_fixed.md` §104.2. **Still open:** reads still grow with N² per tick; the real fix (one shared positions doc per ride) needs a rules change, a rules deploy and a data-model move.
- **104.3 MEDIUM — feed vote hydration costs 40 of 63 base reads per page.** 20 vote `get()`s, each with a rules `get()` on the ride (`ride_share_repository.dart:350`). *Fix:* one per-user votes doc or one query.
  - **Partly fixed 2026-10-22 (branch `fix/reads-104`):** rides nobody voted on cost no vote reads now; details in `issues_fixed.md` §104.3. **Still open:** a voted ride still costs 2 reads. One read per page needs a per-user votes doc or a `uid` field plus a collection-group rule and a backfill of production vote docs.
- **104.4 LOW — the per-author restricted query costs 3 reads even when the author has no such posts** (query + 2 rules `exists()`). The `hasRestrictedPosts` flag from §90.A1 was never built.
  - **Not done (2026-10-22, branch `fix/reads-104`):** the flag is a data-model change. Sharing a followers/mutual ride must set it on the author's profile (a rules change for that field), and every existing author needs a production backfill before the feed may skip anyone; skipping before the backfill would hide their followers-only posts. Needs a founder-approved backfill and a rules deploy. Cost today: 3 reads per followed author per first page (`ride_feed_provider.dart`, `restricted:<author>` sources; exhausted authors are not re-queried on later pages).
- **104.5 Founder:** real per-user usage from Firebase console → Usage. The local gcloud account (Play publisher SA) cannot read Cloud Monitoring.
- **104.6 Outage mode:** merged to `main` in `c751968e` (2026-10-22), not in a release yet. What it does, the rehearsal and the alerting are in `issues_fixed.md` §104; rehearsal report: `DOCS/Handoff for agents and Todos/load_test/quota-rehearsal-2026-10-21.md`. Still open:
  - About 20 transaction-based social actions (forums, comments, votes, group-ride join/leave, new chats, reviews, onboarding username) fail with the overload message.
  - The `SyncManager` writes (`deleteBikeRemote`, `deleteRideRemote`, `deleteMaintenanceRemote`, `deleteFuelLogRemote`, `uploadTrack`, `uploadImpactEvents`) await without a timeout. There a timeout needs a per-write choice between "done" (a later refusal is lost) and "retry" (stacks duplicate writes). The screen writes were fixed on branch `fix/reads-104` (`issues_fixed.md` §104.6, screen writes).
  - A write-only outage is caught only when a transactional upload or outbox delivery fails; until then `SyncManager` can sit on an untimed write.
  - Whether realtime reads get refused later in a spent day.
  - The native Android/iOS SDKs weren't rehearsed (same design as the JS SDK).

## 107. Leftovers from retired working notes: BIGGG_JOBB, DEBT_FIX_PLAN, uiux_critique, websockets_todo, plan_ride_minimize_menu, todo_now_antigravity (2026-10-22)

Those six files are deleted (text in git history: `git show 3ebbd21d:"DOCS/Handoff for agents and Todos/<file>"`). Everything else in them was done, obsolete, or already tracked (§83, §89, §99, §101, §104; owner page). What was still open:

- **107.1 MEDIUM — add three deploy and test rules to `.agents/rules/deploy.md` and `qa-gate.md`.** They were only in `BIGGG_JOBB.md` §3. Source: BIGGG_JOBB §3.5-3.7, §3.9, §3.11.
  - Ship the app before any rule that tightens a write contract. `firestore.rules` deployed first made new chats fail for old builds once (§78.27).
  - Never `firebase deploy --force`: it deletes live indexes missing from `firestore.indexes.json` and breaks their queries at once. When diffing indexes, strip the implicit `__name__` field first.
  - Tests never touch the network (`AppTileLayer` swaps in a blank tile provider under `FLUTTER_TEST`, `app_tile_layer.dart:95`). Cloud Functions cannot deploy on Spark (`artifactregistry` needs Blaze), so server-side code written now fixes nothing until Blaze.
- **107.2 MEDIUM — the order and method for the §83 debt, in one place.** Source: DEBT_FIX_PLAN §1-§5 (details of each item stay in §83.12-83.28). Order by what a rider loses, not by effort.
  1. §83.14: add `reportSilently(e, st, where:)` in `core/` (Crashlytics `recordError`, `fatal: false`, no-op in debug and tests, never throws). Triage every bare `catch (_)` as expected, best-effort or a real failure; start with the empty ones and `features/ride/`, `core/cloud/`. Add a ratchet test that fails when the count of `catch (_)` in `lib/` rises above a checked-in baseline.
  2. §83.13: add `firestoreProvider`, `firebaseAuthProvider`, `currentUidProvider` in `core/cloud/`, convert the direct `.instance` call sites, then give `RideRecordingNotifier` constructor-injected collaborators (Geolocator, foreground service, wakelock, persistence behind small interfaces). Turn the 11 `static final _instance` repositories into providers. One behaviour-neutral PR per step. Add a grep guard so a new `FirebaseFirestore.instance` fails CI.
  3. §83.28: widget tests in this order: ride recording, sign-in, outbox ("Sync issues"), maintenance; then goldens for about 6 screens on the CI machine class.
  4. §83.22: a scale sweep test that pumps key screens at 1.0, 1.3, 1.6, 2.0 and fails on `RenderFlex overflowed`; fix cockpit rows, chips and stat tiles; raise the clamp (`app.dart`) in steps, then add cockpit `Semantics` ("Speed 42 kilometres per hour") through l10n.
  5. §83.26: capture the onboarding screens with `integration_test/ui_tour_test.dart` (seeded data, WebP per locale), delete `onboarding_ui_mockups.dart`, add a manifest-vs-assets test.
- **107.3 MEDIUM — design options for the two server-side gaps** (needs the owner's choice, see §83.16 and §83.18). Source: DEBT_FIX_PLAN §6-§7.
  - Blocking (§83.18): rules can check a `blocked` doc on single-document reads (ride, profile, comment), which is testable in the emulator. They cannot filter a list query, so the feed needs `not-in` (small block lists) or a server edge (Blaze).
  - Cloudinary (§83.16): besides locking the preset in the dashboard (owner page), a signing proxy on a free edge worker that checks the Firebase ID token would work without Blaze, but it is a new vendor. Auto-expire voice notes in the preset.
- **107.4 LOW — cop checkpoints have no abuse limit.** `ride_actions_menu.dart` lets any rider add a public `police` pin, permanent if chosen, with no dedupe or rate limit. Rules only bound `expiresAt` (`firestore.rules`, places create). A Firestore TTL policy on `places.expiresAt` is not set (production config, owner's go-ahead): expired docs stay, and the client hides them in `nearbyViaGeohashRanges`. Source: plan_ride_minimize_menu "Known limits".
- **107.5** Same item as §110.1; tracked there.
- **107.6 LOW — marketing idea, not started:** `apify/facebook-posts-scraper` on motorcycle-brand and BikeBD pages, for launch timing and content that gets engagement. Source: todo_now_antigravity §11.
- **107.7 MEDIUM — device checklist for the widgets and gauges (needs a phone; owner page item 5 covers the ride).** Source: todo_now_antigravity §8, F8.
  1. `cd app && flutter run --release -d 00008120-001E5D190A85A01E` (iPhone) or `flutter run` (Android). Launch once so `HomeWidgetService.bootstrap()` writes baseline values to the App Group `group.com.bft.throttleiq`.
  2. Xcode, `ios/Runner.xcworkspace`: the `ThrottleIQWidget` target has a Team and the App Group ticked, with no provisioning warning.
  3. Home screen: Apex Hunter (small and medium: max lean left/right, lean rating badge, symmetry score), Ride Stats and Maintenance (live values, overdue chips), Start Ride and Auto-Tracking (one-tap deep link).
  4. iOS 16+ lock screen: `.accessoryCircular` (lean gauge), `.accessoryRectangular` (the three summaries), `.accessoryInline`.
  5. In app: `DualLeanArcGauge` and `GForceFrictionCircle` stay smooth during a ride and a replay; `ConsumablesHealthCard` wear gauges match the check intervals and respond to taps.
  6. F8: the §97 Places and Forums fixes were checked by code and tests only; look at them on the device too. Also run the ride actions menu (cop checkpoint, parking pin, minimize, strip, Directions to bike) once, from `plan_ride_minimize_menu`'s verification list.

## 108. Leftovers from the retired Antigravity grill (`grillings/`, `issues_solved.md`) (2026-10-22)

The five grill files (2026-09-20 critique plus the `claude_sol.md` verification pass) and `issues_solved.md` were deleted. Fixed parts: `issues_fixed.md` §78. Still-open parts were already in §78 and §91. Code comments that say `grill §N` or `claude_sol §N` point into the deleted text; read it with `git show 3ebbd21d:"DOCS/Handoff for agents and Todos/grillings/claude_sol.md"`. Only items checked against the code on 2026-10-22 and found neither fixed nor tracked are listed here. All LOW.

- **108.1 Auto rides: no "Not a motorcycle ride" action.** `auto_ride_reconciler.dart` attributes a bus or car trip to the active bike and calls `incrementStats` at once, even at `bike_confidence='low'`. The daily prompt (`ride_dao.getUnconfirmedAutoRides`, `auto_tracking_provider.dart`) only asks which bike. Fix: add the action (delete the ride, reverse `incrementStats`); defer odometer and maintenance increments until confirmed or 48 h pass; add a bus-pattern and max-speed filter. Source: grill `claude_sol` §2 item 4.2.
- **108.2 Forum create and reply transactions fail offline.** `app/lib/features/forums/data/repositories/forum_repository.dart` has about 8 `runTransaction` calls (lines 178, 208, 253, 419, 437, 723, 764). Plain writes queue offline, transactions don't. Fix: move counters to `FieldValue.increment` in a batch, or catch `unavailable` and show "You're offline"; don't `await` fire-and-forget writes in UI handlers. Source: `claude_sol` §2 item 2.2.
- **108.3 Haversine is copied in about 7 files** beside `app/lib/core/utils/geo_math.dart` (`motion_calculator.dart`, `auto_ride_reconciler.dart`, `daily_ride_summary.dart`, `ride_resume.dart`, `privacy_zone_clipper.dart`, `live_session_coordinator.dart`, `turn_instruction.dart`). Fix: one shared function. Source: `codebase.md` item 6.1 (scoreboard #32).
- **108.4 The shared-ride detail still shows runner pace.** `shared_ride_detail_screen.dart:358` builds `m'ss" /km`; the ride summary already shows average moving speed. Fix: show km/h there too. Source: `claude_sol` §3 item 3.4.
- **108.5 No GPX import.** Export exists (`export_service.dart`); import doesn't. Feature idea, not a bug. Source: `other_gaps.md` item 3.4 (scoreboard #38).
- **108.6 Profile stat cards may look tappable and aren't** (Rides, Routes). Not verified by the grill and not rechecked here. Fix: give them `onTap` (`/rides/all`, `/routes`) or restyle. Source: `claude_sol` §3 item 5.5.

Dropped on purpose (no action): weather timezone skew (only wrong when the phone's timezone differs from the ride's; `weather_service.dart:56` notes it), unencrypted SQLite (`allowBackup=false`; rooted-device only), portrait lock (deliberate, `main.dart:66`), the crash-detector findings (shadow mode only, §78.1), and the claims `claude_sol` §6 marked false.

## 109. Leftovers from the retired 2026-10-14/15 critiques (CrtiQue_Oct14.md, CrtiQue_Oct15.md) (2026-10-22)

Both critiques were retired on 2026-10-22 (old text: `git show 3ebbd21d:"DOCS/Handoff for agents and Todos/CrtiQue_Oct15.md"`). Every finding was checked against `main` at `3ebbd21d`. Done in the oct14/oct15 rounds: B1 copy, B2, B3, B4, B6, B7, B9 to B14, N1 to N5, N8 (`kInstallUrl` is `throttleiqfb.web.app/install`), the install-page claims, the dark-map filter, schema v28 and last-writer-wins. Owner-side asks map to owner items (Blaze #3, SECURITY step 3 #2, Play #4, real phone #5, riders #6, Cloudinary #11, App Check #17, Apple $99 #21, pitch #22). What is left for an agent:

- **109.1 N6, LOW-MEDIUM: a swiped-away ride records until the app is reopened.** `app/lib/core/services/auto_tracking_service.dart` `_watchManualRide` / `_startTakeover` (`:100-175`). Nothing ends the takeover. A rider who swipes the app away at the office keeps recording all day, and the next morning joins the same ride. Fix: end the takeover after 10-15 min without movement and leave the ride for restore; say "Open ThrottleIQ to finish" in the notification text. Source: CrtiQue_Oct15 N6.
- **109.2 N7, LOW-MEDIUM, suspected: a missing UI heartbeat makes two writers record the same ride.** Same file, `uiGone` (`:697`) and `sendUiBeat` (swallows errors). If the beat fails on a phone, the handler (1 Hz) and the recorder (2 Hz) both write `ride_points`: zig-zag trail, doubled upload. `idx_ride_points_ride_timestamp` (`database_helper.dart:140`, `:1076`) is not unique. Fix: drop takeover points less than 1 s from a UI point, or add a unique index on `(ride_id, timestamp)`; one logcat check on a real phone ("UI gone" must never show in a foreground ride, see owner #5). Source: CrtiQue_Oct15 N7.
- **109.4 LOW: public max speed.** `social_feed_tab.dart:652` and `shared_ride_detail_screen.dart:733` show max speed on public shared rides; `ride_sort.dart:10` keeps a "top speed" sort. Under the Motor Vehicle Act 2018 a published speed is self-incriminating, and it sits badly with the safety pitch. Fix: hide max speed on shared rides by default (opt-in toggle), and decide whether the sort stays. The speed badges are already gone. Source: CrtiQue_Oct14 §7 and §11, Oct15 §0.5.
- **109.5 LOW: write-only badge counters.** Nothing reads `stats/badges` since the rarity UI went (`12209669`). `app/lib/features/stats/data/badge_stats_counter.dart`, `badge_sync_provider.dart`, `profile_repository.dart` (sign-up write coupled to it), the `stats/badges` rules in `firestore.rules` and their rules tests keep a number nobody shows (about 450 lines). Also delete the dead `UserProfileEntity.email` (`user_profile_model.dart:20`; reads null after the email migration). Cut or keep on purpose. Source: CrtiQue_Oct15 §2 and §14.
- **109.6** Same item as §110.4; tracked there.
- **109.7 LOW: last-writer-wins trusts the phone clock** (`app/lib/core/cloud/last_writer_wins.dart:13`). A phone an hour fast wins every conflict for that hour. Fix: when adopting a remote row, reject an `updated_at` more than 5 min ahead of server time. Source: CrtiQue_Oct15 §0.2 and §4.
- **109.8 LOW: first sync after v28 is a full pull** (`sync_manager.dart:231`, `resetPullMarksOnceForV28`): one read per ride, bike, maintenance and fuel row. Fine at 20 riders; a few hundred riders in one day can use up Spark's 50k reads. Watch it with the quota alert (owner #3 status); no code change unless riders grow. Source: CrtiQue_Oct15 N12.
- **109.9 LOW, UX: two small rider-facing gaps.** (a) The one-time OEM guide (`oem_guide_screen.dart`, shown from `record_screen.dart`) cannot be found again after "Not now": add a Settings entry "Rides keep stopping?". (b) The "Update required" screen (`app/lib/shared/widgets/update_required_screen.dart`) hides the rider's own data: add "Export my rides". Source: CrtiQue_Oct15 §7.
- **109.10 LOW, unverified: group-ride invitations have no block check** (`firestore.rules`, `groupRides` `invitedIds`). The invite notification is refused for a blocked rider, but the invite itself is not. Check, then add the `blocks` `exists()` check and a rules test. Source: CrtiQue_Oct15 §5.
- **109.11 LOW, measure first: GPS drops in dense streets.** The 25 m accuracy gate under-counts in Old Dhaka. Kept and dropped fixes per ride are logged (`gps_drop_log.dart`, last 20 rides, in the bug report). Read the numbers from five testers (owner #6) before changing `SensorConstants.maxGpsAccuracyM`. Source: CrtiQue_Oct15 §0.2.
- **109.12 LOW: account deletion via a Spark-compatible request.** Deletion is still an email (`judge.md`: fails Apple 5.1.1(v) until Blaze). Option that needs no Blaze: the app writes `deletionRequests/{uid}` (create-only rule) before deleting the Auth user, and the owner runs an Admin-SDK script weekly that calls the emulator-tested `deleteUserData`. Update the dialog and `privacy.html` to match. Decide together with Blaze (owner #3). Source: CrtiQue_Oct15 §10, top-10 #4.
- **109.13 LOW: Android sensitive permissions and a v1 without auto-tracking.** Owner #8 decided to submit as is. If Play review pushes back, the fallback is: drop `USE_FULL_SCREEN_INTENT` (`AndroidManifest.xml:57`, only crash alerts use it and they are off) and ship v1 without auto-tracking (no `ACCESS_BACKGROUND_LOCATION`, no activity recognition, no bus false positives). Source: CrtiQue_Oct15 §10.
- **109.14 LOW, store readiness: Terms of Service and the widget privacy manifest.** No Terms of Service exists in `public/` or the app (Apple 1.2 wants a no-tolerance clause for user content). `app/ios/Runner/PrivacyInfo.xcprivacy` exists; the widget extension (reads app-group UserDefaults) has none. Sign in with Apple (guideline 4.8) needs the paid program (owner #21). The Bangladesh Personal Data Protection Ordinance 2025 (gazetted 2025-11-06, 18-month window, so about May 2027) needs a lawyer's read. Source: CrtiQue_Oct14 §10-11, Oct15 §10-11.
- **109.15 REFERENCE (not a task): competitor and demand facts from the critiques.** Direct competitors for the garage wedge: BDHonda+ (Honda Bangladesh: service booking, maintenance guidance, service-centre finder) and My Suzuki (service history, ride tracking); both cover only their own brand. Medium: Trackers BD and Finder GPS (hardware trackers), Meetap (BD rider community), crash-detection apps EatSleepRIDE, Detecht, Triumph SOS, RealRider. Facebook groups and BikeBD own social. Pitch line the critique found defensible: "one service book for any bike, at any garage", in Bangla, offline. Buyers in order: B2B fleets, garages and parts sellers (leads), oil and parts sponsors, premium exports. Demand evidence on 2026-10-15: 19 APK downloads across 20 GitHub releases, 4 stars, no rider count. The iDEA pitch lists three named team roles and an advisory panel while git shows one author, and targets 50,000 users in year one (owner #22). Sources: BikeBD posts on BDHonda+, My Suzuki and Trackers BD (`bikebd.com/blog`), plus App Store listings; the full list is in the retired file.

## 110. Leftovers from the HANDOFF to-do and unverified lists (2026-10-22)

Open developer items found while rewriting `HANDOFF_Document.md` that no other section tracks. Owner items went to the owner page; device checks are in the handoff's "Built but never run on a real phone" list.

- **110.1 Unused l10n key `n0NotGoogle`.** `app/lib/l10n/app_en.arb:3767` and `app_bn.arb:806`; nothing in `app/lib` reads it since `4535b6e8` hid the Google column on place detail. *Fix:* delete the key in both ARB files and regenerate. Harmless, but it keeps a "Not on Google" string the app no longer shows. Source: HANDOFF 2026-10-19 (places).
- **110.2 PRD says the fix purge is never called.** `DOCS/For Devs and Contributors/architecture/PRD.md:133` (AUT-7, "No code calls the purge yet") and open item 3 (`:310`). The purge runs: `auto_tracking_service.dart:367` calls `DailyRideSummaryRepository.purgeOldFixesIfDue()` (14 days, `auto_detection_dao.dart:354`). *Fix:* mark AUT-7 built; keep open item 3 only for its second question (store day totals before the purge, since purged detections drop out of older daily summaries, `auto_tracking_plan.md:249`). Source: HANDOFF 2026-10-15 (agent round).
- **110.4 Admin check still falls back to an email.** `firestore.rules:136-141` (`isAdmin()` accepts a verified `the.abraar.rar@gmail.com` token), plus client copies in `forum_permissions.dart:5` and `jam_label_provider.dart:14`. Nobody recorded running `scripts/oneoff/set_admin_claim.js`, so the `admin` claim may not exist. *Fix:* after the owner sets the claim and signs in again, delete the email branch from `isAdmin()` and its rules tests. Why: admin rights should not depend on one mailbox's address. Source: HANDOFF Key facts, "Admin account" (2026-08-12).
- **110.6 `main`'s pre-push hook lacks the linked-worktree fix.** `mayabi` (`ef83fe03`) unsets git's local env vars before the gate in `.githooks/pre-push`; without it, `GIT_DIR` made Flutter report `0.0.0-unknown` and `pub get` fail in a linked worktree. `main`'s hook has no such line. Not reproduced on `main`. *Fix:* write the same few lines on `main` (the owner asked for no cherry-picks from `mayabi` without asking). Source: `mayabi` branch HANDOFF, "Pre-push in a worktree".

## 111. People tab: suggested-rider cards overflow by 1 px (2026-10-22)

Found by the UI screenshot tour (debug build, iPhone 17 simulator, dark theme). On Social → People, every "Suggested for you" card overflows its fixed-height row by 1 px at the bottom: `A RenderFlex overflowed by 1.00 pixels on the bottom`, once per card. Debug builds draw the yellow-black stripe under the Follow button; release builds clip 1 px of the card instead.

- **Where:** the row is a `SizedBox(height: 140)` in `app/lib/features/social/presentation/screens/social_people_tab.dart:172-173`; the card is `_SuggestedRiderCard` (same file, `:254`), whose column comes out 1 px taller than the row.
- *Fix:* let the row size to the card (or raise the height by the 1 px, or trim one gap), then check at 1.3× text scale and in Bangla, where the name line runs taller.

## Cloud Functions audit leftovers, architect to-do #5 (2026-10-22, lane C)

- **The report purge re-reads every old report on each run.** Pass 1 pages through all reports reviewed before the 90-day cutoff, including those already purged. At very high volume it could use the whole 480 s budget, and pass 2 (closed reports about deleted riders) would then never run. Already marked `shortcut:` in `report-retention.ts`. *Fix when needed:* a `purged` flag plus a composite index.
- **The auto-report can reopen a reviewed report.** `onMessageCreate` writes `reports/auto_chat_<chat>_<msg>` with `set` and `status: "pending"`. If the trigger were ever retried after an admin closed it, the report would go back to pending and lose its review fields. v2 Firestore triggers don't retry by default, so this can't happen today. *Fix if retries are turned on:* `create()`, treating ALREADY_EXISTS as done.
- **Erasure loads each query fully into memory.** The owned-query, anonymise, report and chat-message steps `.get()` all matching docs before batching. That's fine for one rider's data, but not bounded. Not changed.
