# ThrottleIQ: independent critique (2026-10-14)

Reviewer: senior engineer, product and go-to-market. Written from the code, not from the handoff.

**What I ran:**
- `flutter analyze`: clean.
- `flutter test`: 2131 of 2131 passed.
- `functions` `npm test`: 12 of 12 passed.
- Firestore rules suite, on a scratch copy against the local emulator: 274 of 274 passed.

**What I read:** the ride recorder, sync, auth, crash, analytics, permissions and tile code; all three rules files; `functions/src`; the Android manifest and iOS plist; the store listing and pitch drafts; the privacy page.

**Also checked:**
- Viewed four of the generated screenshots at phone size.
- Queried GitHub for repo visibility, CI status and release download counts.
- Searched the web for competitors.

**What I did not do:** run anything on a phone, touch production, or run the functions emulator suite or the RTDB suite.

"Confirmed" means I traced it in code (or reproduced it). "Suspected" means the code points that way, but the outcome depends on a device, a console setting or a store reviewer.

---

## 1. Verdict

ThrottleIQ is an offline-first motorcycle ride recorder, garage and maintenance planner and rider community, in English and Bangla, built for Bangladeshi commuter riders. The engineering is well above solo-beta standard: SQLite as the source of truth, an outbox, careful sanity checks on GPS fixes, 2131 passing tests, and rules tests that really run.

The product side is weak:
- No measured demand. The 19 GitHub releases have 19 APK downloads in total.
- A breadth problem: social, forums, places, routes, group rides, challenges, 28 theme combinations and a dash-cam branch, all for a handful of riders.
- One live promise is broken: in-app account deletion leaves every cloud record in place.

**Worth continuing?** Yes, but narrowed to the garage and maintenance plus ride-log core for BD commuters. Stop widening.

**My GTM readiness: 40%** (scorecard: 45%). The weighted score is 41.5, capped at 40.

**Why lower than the scorecard:**
- The scorecard treats this as "backend only partly deployed". The real state is worse in three ways:
  1. A store-facing privacy promise is false today. Account deletion does not delete cloud data, because the trigger that would is not deployed (§3, B1).
  2. Every public rider's email can be listed by any signed-in user (§3, B2).
  3. The draft Play listing and the iDEA pitch advertise crash detection that is switched off in every build (§11).
- Market evidence is close to zero. "Real riders testing" is not backed by any number in the repo, and the public download counter says single digits per release.
- The engineering earns real points. The product cannot yet be put in a public store without misleading people.

---

## 2. Code and architecture

**Structure.**
- Flutter app with feature-first folders: 425 Dart files, about 86k lines excluding generated l10n, plus about 24k generated l10n lines.
- Riverpod (StateNotifier, about 30 notifiers), go_router and Material 3.
- SQLite is the source of truth (schema v27, additive `_addColumnIfMissing` migrations), with an outbox to Firestore.
- Cloudinary for images.
- 13 TypeScript trigger functions, none deployed. The only HTTP endpoint is Hosting.

This is the right shape for offline-first riding in BD, where signal drops are normal.

**What is good:**
- The per-fix sanity rules are pure and shared by the live recorder and the auto-detection replay (`app/lib/features/ride/domain/calculators/fix_kinematics.dart:63-143`). That covers the Doppler distance cap, the acceleration clamp and the rebound suppression.
- Long-gap moving-time handling covers tunnels and signal loss sensibly (`average_speed.dart:87-114`).
- Stop is ordered as finalize first, recovery marker last, so a kill between the two steps never orphans a ride (`ride_recording_provider.dart:1105-1180`).
- There are cross-version download guards (`knownRideColumnsOnly`, `cloud_repository.dart:201`).
- `check.sh` is one gate for local, pre-push and CI. CI on `main` is green (GitHub, 2026-10-14).

**What is not:**

| Issue | Evidence | Why it matters |
|---|---|---|
| God files | `ride_recording_provider.dart` 1422 lines even after the helper split; `ride_summary_screen.dart` 1195; `active_ride_screen.dart` 1103; `home_widget_service.dart` 807 | The most safety-relevant loop is the hardest to change, and only 3 test files touch the recorder |
| Hidden singletons beside DI | `BikeDao()` built inline at `ride_recording_provider.dart:1158`; `AnalyticsService.instance`, `HomeWidgetService.instance`, `NotificationService.instance` called from the notifier | Riverpod is used for UI state but bypassed for services. That couples the recorder to the platform and explains the thin recorder tests |
| Cloud schema = local SQLite row | `ridePayload` copies the whole row, local-time strings, `synced` flag and device file paths included (`cloud_repository.dart:168-188`) | Every column change is a cross-version hazard. The team already pays for this with bespoke guards per column |
| Inert subsystems kept live | RTDB channel: 829 lines in `core/realtime`, plus `database.rules.json`, `live-viewer-core.js` and 45 tests, but release builds never set `RTDB_URL` (`realtime_config.dart:20-30`, not in `scripts/deploy.sh`). Crash pipeline off (`sensor_constants.dart:60`). `storage.rules` is not referenced by `firebase.json`. 13 Functions not deployed. Challenges have no rules (§3, B6) | Maintenance cost for zero rider value |
| Theming surface | 7 colour families x curvy/boxy x light/dark = 28 combinations, plus 7 ride-mode themes; 2433 screenshots generated to cover it | Multiplies QA. Nobody can check 28 x 88 screens on a phone |
| Standards | 66 bare `catch (_)` remain (ratchet at the max, `scripts/check.sh` `CATCH_MAX=66`). Analyze is clean | The ratchet is a good idea, but it has not moved |

**Process.**
- 530 commits since 2026-07-12; 376 carry a Claude co-author line.
- 264 commits in the last 30 days, and 5 releases between Oct 6 and Oct 9.
- About 11k lines of handoff and issue logs (`issues_fixed.md` alone is 6337 lines).

The repo is optimised for agent throughput, not for learning from riders.

---

## 3. Bugs (ranked)

**B1. High, Confirmed. In-app account deletion leaves all cloud data behind, and the privacy policy says otherwise.**
- `deleteAccount` deletes only the Auth user, local SQLite and the Google session (`app/lib/features/auth/presentation/providers/auth_provider.dart:225-247`). Cloud cleanup is delegated to the `onUserAccountDeleted` trigger, which cannot deploy on Spark.
- `public/privacy.html:477-481` tells riders their cloud records "are then removed automatically".
- The rules also block a client-side cleanup:
  - profile delete is denied once badge stats are counted (`firestore.rules:461-462`);
  - `earnedBadges` delete is `false` (`firestore.rules:604`).
- On Blaze the function would still be incomplete:
  - its collection-group anonymize queries (`functions/src/account-erasure.ts:300-310`) need single-field overrides, but `firestore.indexes.json:292` has `"fieldOverrides": []`;
  - Cloudinary destroy has no credentials.
- **Failure:** a rider deletes their account. Their profile and email, shared rides, raw GPS tracks, emergency contacts (other people's phone numbers), forum bylines and chats stay in production. The rider has no way back in. This fails Apple 5.1.1(v) and Play's data-deletion policy.
- **Fix:**
  1. Go Blaze and deploy only this trigger.
  2. Add the three `userId` COLLECTION_GROUP overrides.
  3. Until then, change the privacy page and the delete dialog to say deletion is done by hand within 30 days, and do it by hand from a list.

**B2. High, Confirmed. Any signed-in user can list every public rider's email.**
- Profile docs store `email` (`app/lib/features/profile/data/repositories/profile_repository.dart:83`).
- `allow list` on `/users` requires only `visibility == 'public'`, with no limit (`firestore.rules:428`), and returns the whole document.
- Public is the default.
- **Failure:** one script with a beta account dumps the email of the whole rider base. That is an easy spam or phishing list.
- **Fix:** move email to an owner-only subdoc. Support "find by email" with a lookup keyed on a hash of the lowercased email. Add `request.query.limit <= 20`.

**B3. Medium-High, Confirmed. Blocking does not stop a blocked rider from reaching you.**
- Chat `update` and `create` have no block check (`firestore.rules:1860-1883`), so a blocked rider can write up to 5000 characters into your inbox preview (`lastMessage`).
- Message create does check blocks (around `firestore.rules:1917-1918`). The gap is the parent doc.
- Notifications (`firestore.rules:658-659`) and follow create (`firestore.rules:1419-1421`) also lack block checks. A re-follow puts the blocked rider back into the "followers" tier for bike visibility.
- **Fix:** copy the two `blocks` `exists()` checks into chat update and create, notification create and follow create, and add rules tests for each.

**B4. Medium. Confirmed for the dialog; Suspected for the settings bounce.** Riders who chose "While using the app" get a disclosure and a background-location request on every ride start.
- `ensureLocationDisclosure` shows the dialog whenever permission is not `always` (`app/lib/features/ride/presentation/widgets/recording_gate.dart:24-27`). It is called on every start (`record_screen.dart:320`, `:394`).
- `_requestPermissions` then calls `requestPermission()` again for whileInUse (`ride_recording_provider.dart:345-350`). On Android 11+ that sends the rider to the system settings page.
- Manual rides do not need background location: they run under a location foreground service (`ride_recording_provider.dart:574-587`).
- **Failure:** two extra screens before every ride, for every rider who declined. Play reviewers also reject background-location requests that a foreground service already covers.
- **Fix:**
  - Manual rides ask only for while-in-use, once.
  - Ask for "Allow all the time", behind the disclosure, only when the rider turns on auto-tracking.
  - Show the disclosure once and remember the answer.

**B5. Medium. Confirmed in code; Suspected on device.** An app killed mid-ride stops recording silently.
- Manual rides use geolocator's foreground notification in the main process (`ride_recording_provider.dart:574-591`). Nothing restarts the process.
- `restoreInterruptedRide` (`:1226`) brings the ride back as paused only when the rider next opens the app. Everything between the kill and the reopen is gone.
- Battery optimisation is asked once (`ride_recording_provider.dart:352-366`). There is no OEM-specific guidance (no hits for MIUI, Oppo, Vivo or autostart in `lib/`).
- **Failure:** on a Xiaomi, Realme or Vivo with default settings, a 40-minute commute records as 12 minutes, and the rider never learns why.
- **Fix:**
  - Run manual recording through the existing `flutter_foreground_task` service, as auto-tracking already does.
  - Post "Recording stopped, tap to resume" when the service dies.
  - Add a one-time OEM settings guide (dontkillmyapp-style deep links).
  - Test on two BD-common phones.

**B6. Medium, Confirmed. Challenges are dead against the live rules.**
- `challenge_repository.dart:19`, `:49` read and write `challenges` and `users/{uid}/challengeProgress`.
- `firestore.rules` has no match for either, and the catch-all denies (`firestore.rules:2046-2048`).
- The README still lists challenges.
- **Fix:** delete the feature (my advice) or add rules and tests.

**B7. Medium, Confirmed. Riders can award themselves any badge and inflate public stats.**
- `earnedBadges` is owner-writable for any catalog id (`firestore.rules:598-605`), and each award increments the global owner count.
- `publicStats` accepts large jumps (`firestore.rules:327-338`).
- **Failure:** the "% of riders own this" rarity figure is meaningless, and nothing like a partner discount can rest on badges.
- **Fix:** accept that badges are cosmetic until a server derives them, and remove rarity percentages until then.

**B8. Medium. Confirmed in code; Suspected for console limits.** Image uploads use an open, unsigned Cloudinary preset.
- `app/lib/core/services/cloudinary_upload_service.dart:8-20` documents an unsigned preset, and the cloud name and preset name ship in the app.
- Anyone who unzips the APK can upload to the account with no auth.
- The comments promise a "folder-prefix fallback" deletion sweep (`:44-45`) that does not exist in `functions/src/account-erasure.ts`.
- **Fix:**
  - Set a max file size, allowed formats, a folder lock and moderation on the preset in the Cloudinary console.
  - Delete the false comment, or write the sweep.
  - Long term, sign uploads through a function.

**B9. Medium (latent), Confirmed in the rules.** RTDB group-ride positions are readable by any signed-in user who knows the ride id.
- `database.rules.json:49` gates `locations` on `auth != null`, the ride existing and the reader not being banned. Membership is not checked.
- Inert today, because RTDB is off in release builds.
- **Fix:** keep RTDB off, or delete it, until a function mirrors membership.

**B10. Low-Medium, Confirmed. Edits never move between devices.**
- `downloadRides` skips any ride whose id already exists locally (`cloud_repository.dart:700`). Bikes and maintenance do the same (`:404`, `:481`, `:601`).
- **Failure:** a ride's bike corrected on phone A never reaches phone B, and the next upload from B overwrites A.
- **Fix:** last-writer-wins on an `updatedAt` field. This is the open founder decision C4; pick it.

**B11. Low (latent), Confirmed. The crash UI promises delivery that does not exist.**
- `app_en.arb:1168` says "Your emergency contacts will be notified when the timer ends".
- `app_en.arb:6203` says "Contacting your emergency contacts in {seconds}s".
- The backend is a mock (`functions/src/crash-core.ts:21`, `DELIVERY_IMPLEMENTED = false`).
- Harmless while the detector is off (`sensor_constants.dart:60`). It becomes a false safety claim the day someone flips the flag.
- **Fix:** gate the copy on the same flag, or rewrite it now.

**B12. Low (latent), Confirmed. Dismissing a crash alert reuses `finalizeRide`.**
- `dismissCrashAlert` (`ride_recording_provider.dart:1365-1378`) writes `{'status':'active'}` through `finalizeRide`. That leaves the crash-time `end_time` and final stats on a ride that is still recording.
- **Fix:** add a dedicated `setStatus` DAO method.

**B13. Low. Confirmed format; impact Suspected.** Mixed time formats.
- `start_time` is stored as local time with no offset (`ride_model.dart:51`). GPS point timestamps are UTC.
- Day-range queries compare strings (`ride_dao.dart:282`).
- Fine in one time zone. It breaks for a rider who travels or changes the phone clock, and for rides downloaded onto a phone set to another zone.
- **Fix:** store UTC everywhere, as `toUtc().toIso8601String()`.

**B14. Low, Suspected. Wrong tile contact domain.** The OSM User-Agent gives `contact@blankframe.com` (`app_tile_layer.dart:65`). Every other reference uses blankframe.tech. OSM uses that address to contact you before blocking the app.

**Not a bug: the uncommitted `Podfile.lock` (disagrees with judge.md and the scorecard).**
- The diff drops `home_widget` from CocoaPods because `home_widget` 0.9.3 and 0.10.0 ship a `Package.swift`, while the previously locked 0.6.0 did not.
- The Xcode project uses Swift Package Manager (`FlutterGeneratedPluginSwiftPackage` in `Runner.xcodeproj`).
- So the plugin moved from CocoaPods to SPM. Pubspec and lockfile agree.
- Do one iOS build, then commit it.

---

## 4. Corner cases and failure modes

| Case | What the code does | Verdict |
|---|---|---|
| GPS loss (tunnel, e.g. the Karnaphuli tunnel; urban canyon in Old Dhaka) | Fixes with accuracy > 25 m are dropped whole (`ride_recording_provider.dart:677-680`, `sensor_constants.dart:30`). On re-acquisition the chord distance is credited, capped by the Doppler rule. Gaps up to 60 s count as moving if both ends were moving; longer gaps fall back to distance / 5 m/s (`average_speed.dart:100-112`) | Good for tunnels. In dense old-town streets, 25 m drops many fixes, so distance and moving time **under-count**. That pushes km-based service reminders late. Log the drop rate per ride before tuning |
| OEM battery killers (Xiaomi, Oppo, Vivo, Realme) | One battery-optimisation prompt, ever; no OEM guidance; no restart | Main field risk. See B5 |
| App killed mid-ride | Restored as paused on the next launch, with a "we kept your ride" banner; the gap is lost | Data-safe, not complete. See B5 |
| Offline ride and later sync | Ride stays in SQLite with `synced = 0` and uploads on resume, reconnect or the 5-minute tick; per-ride retry after a batch failure (`cloud_repository.dart:114-153`) | Solid |
| Duplicate rides | UUID ids, so no duplicates on retry. Auto-tracking checks the manual-recording marker (`auto_tracking_service.dart:44-50`). `IN_VEHICLE` also fires on buses, CNGs and cars, so a bus commute becomes a "detected ride" the rider has to dismiss | Acceptable. The bus false positive is a UX tax in Dhaka |
| Sync conflicts across devices | First copy wins; remote edits are ignored | B10 |
| Clock skew | Elapsed time uses the wall clock and deltas use GPS time; start time is local without an offset | B13. A wrong phone clock skews "today" stats, not distances |
| Units | Stored in m and m/s, shown in km/h; overspeed threshold is km/h ÷ 3.6 (`ride_recording_provider.dart:460`). No miles option | Fine for BD. Add miles only if you go global |
| Mounted vs in pocket | `AccelAxisCalibrator` decides whether the IMU or GPS counts braking (`ride_recording_provider.dart:835`); lean and g peaks assume a fixed mount | Pocket rides give noisy lean and g figures. Hide lean and g when the axis is not calibrated |
| Crash false positives (pothole, dropped phone) | Detector off. Threshold is about 4 g raw IMU, uncalibrated (`sensor_constants.dart:46`), with a confidence gate of 40 | A 4 g spike is a dropped phone or a Dhaka pothole on a stiff mount. Keep it off until there are labelled drop, pothole and real-fall recordings |
| Crash false negatives | A low-side slide at 20 km/h may never pass 4 g; a phone in a top box sees little | Never market crash detection as protection |
| Account deletion with shared data | Nothing in the cloud is deleted today. Even on Blaze, forum posts are anonymised, not deleted, and chats are untouched | B1 |
| Old beta builds vs new rules | Judge Update 2 says the deploy reported "already up to date", so the strict rules were **already live**. Old builds have lost search and All People since then, and profiles without `visibility` drop out of search until that rider signs in again (`firestore.rules:420-428`) | The premise "don't deploy, it breaks old builds" is stale. There is no forced-update mechanism (no min-version check anywhere in `lib/`). With fewer than 20 sideload installs, message the testers and move on |

---

## 5. Security and privacy

| Question | Answer |
|---|---|
| Can a user read another user's rides, tracks, fuel or maintenance logs, or emergency contacts? | No. Owner-only (`firestore.rules:465-476`, `:504`, `:512`). Confirmed by rules tests (274 pass) |
| Live location? | Firestore live sessions use about 190-bit `Random.secure` tokens (`live_session_coordinator.dart:94-100`) and a TTL enforced in rules. Anyone with the link sees uid, last position, speed and battery, by design. Expired sessions are not deleted (the privacy page admits this). RTDB is latent (B9) |
| PII exposure | Email harvesting (B2) |
| Forge others' badges or stats? | No, but you can forge your own (B7). Counter bumps are tied to a paired doc in the same commit (`existsAfter`), which is solid |
| Message spam? | No rate limits anywhere; anyone can DM anyone; block gaps (B3). The keyword moderation function is an undeployed list of six English words |
| Functions auth | Triggers only, no callable or HTTP surface. Good. When crash delivery ships, unlimited crash docs plus unvalidated contact numbers would let anyone send paid SMS to arbitrary numbers. Add a per-uid cap and App Check first |
| App Check | Activated client-side (`app/lib/main.dart:34-45`) but not enforced. Enforcing Play Integrity will likely reject GitHub-sideloaded APKs (Suspected), so decide the distribution channel first |
| Cloudinary | Open unsigned preset (B8) |
| Secrets | Not tracked and never in history (`git log --all` is empty for each). Ignored by `.gitignore`: `secret/` (`.gitignore:105`), `secrets/` (`:104`), `throttleiq-release.keystore` (`*.keystore`, `:99`), `database-debug.log` and `firestore-debug.log` (`*-debug.log`, `:160`). `app/android/key.properties` is ignored too. The only Firebase keys in history are the public client configs (`GoogleService-Info.plist`, `firebase_options.dart`, `public/live-viewer.html`). Restrict that API key by app and referrer in the GCP console |
| Secrets risk I do flag | `secrets/` holds what its file name says is a Google Cloud service-account key, inside a folder where AI agents run with broad read access. The release keystore has one local copy. Move both outside the repo tree; keep an offline backup of the keystore; enrol in Play App Signing |
| Retention | Raw GPS tracks are kept in the cloud forever. Auto-detection fixes are purged locally (`purgeOldFixesIfDue`). Set a cloud retention policy (e.g. raw tracks after 12 months, keep the summaries) |
| Analytics consent | Firebase Analytics is **on by default** (`app/lib/core/analytics/analytics_service.dart:86`, `:95`), with an opt-out in Settings. The event list is closed and coarse (good), and the privacy page describes it honestly (`privacy.html:260`). The README says "There is no ad or behavioural-analytics SDK" (`README.md:69`), which is inaccurate |
| Third parties | Google (Firebase Auth, Firestore, Analytics, Crashlytics), Cloudinary (images), OSM tiles and Nominatim, Overpass, Open-Meteo (gets coordinates for weather), optionally MapTiler. Nominatim and the OSM tile servers have usage policies that forbid heavy app traffic; plan a paid tile and geocode provider before any public launch |
| Public repo | The repo is **public** (GitHub API). `DOCS/General/screenshots_ui` shows the founder's real name, real ride photos and real Dhaka routes in the feed (e.g. `02_carbonMono_curvy_dark/018__social__social-feed.jpg`) |

---

## 6. UI

From the generated screenshots (iPhone 17 Pro simulator, 2026-09-19, so they predate the October changes), viewed at 375 px wide:

- **Active ride.**
  - The 96-pt speed numeral is right for a handlebar.
  - The 12-16 pt secondary stats (distance, average, "Confidence 83%") are too small at arm's length in sunlight.
  - "Confidence" is engineering jargon to a rider.
  - The Pause button is a ghost outline over a busy OSM map. In dark mode, "Discard ride" is close to invisible against the map (`02_carbonMono_curvy_dark/015__live-ride__active-ride.jpg`).
- **Dark mode.**
  - The UI chrome is dark, but the OSM raster map stays bright, so at night the top 60% of the screen is a glare panel.
  - Use a dark tile style or dim the map in dark mode.
- **Record screen.** Clean. The 900 ms hold-to-start (`hold_to_start_button.dart:52`) works with gloves and prevents pocket starts. Keep it.
- **Feed (dark).** Good contrast with the lime accent; cards are readable.
- **Consistency.** The 28 appearance combinations are the consistency risk. Visual polish is above the local norm. Spend it on two themes (one light, one dark), not 28.

---

## 7. UX

- **Onboarding.** A 9-step feature tour (manifest v4) before the rider has recorded anything is long. The first-run job is "add bike, ride once, see the summary".
- **Permissions.** See B4. The worst UX bug for the riders you have: two extra screens before every ride for anyone who declined "Allow all the time".
- **Start and stop.** Hold to start, big End button, a "kept your ride" restore, pause that cancels streams (so van rides aren't counted). Good.
- **Social.** There is no push notification channel at all (no `firebase_messaging` in `app/pubspec.yaml`, and the personal Apple team cannot do push). A DM or reply is invisible until the rider opens the app, so DMs, forums and group rides cannot form a loop.
- **Retention.** The one real loop is maintenance-due local notifications. That is the product. Lead with it.
- **Speed badges.** "Ton-up" at 100, "Quick" at 140 and "Speed demon" at 160 km/h (`app/lib/core/utils/badges.dart:475-485`). A "top speed" sort of all rides sits next to overspeed alerts and a safety pitch. In a country where two-wheelers are a large share of road deaths, this is both a product contradiction and a store-review and PR risk.

---

## 8. Accessibility and performance

- **Text scale** is capped at 1.3x (`app/lib/app.dart:350-351`) because of about 535 hard-coded font sizes. Low-vision riders can't enlarge text. There are only 27 `Semantics` uses across 425 files.
- **Battery.**
  - Manual rides use `bestForNavigation` at 500 ms with a 3 m filter (`ride_recording_provider.dart:560-579`).
  - Accelerometer and gyro run at 20 Hz (`:600-611`), and UI pushes are throttled to 200 ms. That part is fine.
  - The real drain is `WakelockPlus.enable()` for every manual ride (`:498`): screen on for the whole ride. The handoff's wakelock battery test (C6) is still open.
  - Make screen-on a toggle that defaults to on only when mounted.
- **Data use.** Low. Tiles are cached for 30 days (`app_tile_layer.dart:68`), tracks upload in 500-point chunks, and sync uses watermarks.
- **App size.** The release APK on GitHub is **105.5 MB** (universal: arm64, armv7 and x86_64; `libapp.so` is about 16-18 MB per ABI; ML Kit barcode adds about 5 MB per ABI). That is heavy for BD mobile data. An arm64-only split would be about 45 MB. Use `--split-per-abi`, and drop x86_64 from release builds.
- **Cold start.** Six awaited steps run before `runApp` (`app/lib/main.dart:62-122`): Firebase, App Check, analytics, Crashlytics, notifications, auto-tracking configure. On a low-end phone that is probably over a second (Suspected; measure it).
- **Spark read quota (Suspected, arithmetic).** The feed hydrates one vote read per ride (`ride_share_repository.dart:333-360`). At 200 active riders, 50k reads/day goes fast. On Spark the app then stops for everyone until reset.

---

## 9. Testing and verification

| What | Result | What it proves | What it does not |
|---|---|---|---|
| `flutter analyze` | Clean (I ran it) | Types and lints | Behaviour |
| `flutter test` | 2131/2131 (I ran it) | Calculators, DAOs on real in-memory SQLite, widgets, sync guards | The recorder's GPS-to-SQLite-to-sync loop end to end. Only 3 test files touch `rideRecordingProvider`. No device, OEM kill or real GPS |
| Firestore rules (emulator) | 274/274 (I ran a scratch copy) | Owner-only paths, counters, live sessions, forums | B2, B3, B6, the places field validation, and old-build compatibility. Nothing proves the live ruleset equals the file |
| RTDB rules | 45 tests exist (not run by me) | Rules shape | Non-member reads (B9) |
| Functions | 12 pure tests pass (I ran them); the emulator suite (account deletion, crash) was not run by anyone recently | Claim, lease and name logic | That deletion works, or that it is deployed |
| `integration_test/` | `e2e_test.dart`, `realtime_emulator_test.dart`, `ui_tour_test.dart` | Nothing; not run per the handoff | |

**Biggest gap:** zero real-device evidence for the latest build, which also means zero evidence for battery, OEM kills, permissions or widgets.

**I disagree with Quality 8/10.** The tests are excellent at unit level. But the scorecard's own 10 says "tested on real devices", and that has not happened since beta 4.2.

---

## 10. Deploy and operations

- **Spark vs Blaze.**
  - Blaze keeps the same free quotas. At this scale the bill is cents to a few dollars a month (functions invocations, the Artifact Registry image).
  - The real risk is a runaway bill from abuse. Mitigate with a budget alert (alerts do not cap spend), App Check enforcement and per-uid caps.
  - Staying on Spark keeps B1 broken. This is the single decision blocking the most.
- **Rules deploy and old builds.**
  - The rules are live already (judge Update 2).
  - Add a `config/app` doc with `minBuild`, read at start, and show a blocking "update" screen.
  - It costs about 2 hours and unblocks every future rules change.
- **Crash reporting.** Crashlytics is wired. There is no alerting on rules denials, sync failures or quota.
- **Release pipeline.** `scripts/deploy.sh` commits, gates, pushes, installs on the founder's iPhone, builds the APK and AAB and makes the GitHub release. Fine for one person. The Play upload is manual. 19 releases in 2 months, against 19 total downloads, is churn without an audience.
- **Store compliance.**

| Item | State |
|---|---|
| Play background-location declaration and video | Open. B4 weakens the case: ask only for auto-tracking |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `USE_FULL_SCREEN_INTENT`, `FOREGROUND_SERVICE_LOCATION`, `RECORD_AUDIO`, `ACTIVITY_RECOGNITION` (`AndroidManifest.xml:30-70`) | Each needs a Play Console justification. Full-screen intent on Android 14+ is meant for calling and alarm apps |
| Play data safety | A draft CSV exists in `DOCS/General/store_listing/`. It must match reality, including analytics on by default |
| Account deletion | Fails until B1 is fixed |
| Apple | Personal team `NJ4675FFUX` cannot publish to the App Store at all; it needs the $99/yr program. No `PrivacyInfo.xcprivacy` in `app/ios/Runner`. Google sign-in without Sign in with Apple likely trips guideline 4.8 (Suspected) |

---

## 11. Legal and compliance

- **False crash claims in drafts.**
  - `DOCS/General/store_listing/store_listing.md:10` says "crash alerts".
  - `store_listing.md:28-29` says "CRASH DETECTION: Detects a likely crash...".
  - The detector is off in every build.
  - `DOCS/General/marketing/iDEA_PITCH_SUBMISSION.md:36-38` calls it a "fully functioning app" that "detects crash impact signatures" and "automatically shares a live, encrypted emergency location link", and promises "Zero unwitnessed motorcycle crashes" (`:56`).
  - Submitting either as written is a misrepresentation to Google and to a government grant body.
  - The README and in-app emergency-contact copy are honest. The drafts are not.
- **No Terms of Service.** There is none in `public/` and no terms or EULA strings in the app. An app with user content (forums, DMs) needs terms with a no-tolerance clause (Apple 1.2) and a limitation of liability. That matters doubly for anything safety-adjacent.
- **Privacy policy.** Detailed and mostly candid (`public/privacy.html`). Two false or risky lines:
  - the automatic deletion claim (`:477-481`);
  - "find you by exact email" (`:211`) undersells the list exposure (B2).
- **Location privacy.**
  - The 200-349 m privacy zone on shared rides is good.
  - Publishing **max speed** on public ride cards (e.g. 85 km/h on a Dhaka city ride in the feed screenshot) is self-incriminating evidence under the Motor Vehicle Act 2018 and BRTA speed limits (verify the current figures).
  - Make max speed private by default.
- **Bangladesh data law.** Personal data protection law in BD has been moving. Have a local lawyer confirm current obligations (consent, data localisation, breach notice) before a public launch. Not verified here.
- **Emergency contacts.** You store third parties' phone numbers and emails without their consent. Disclose it (done), keep it owner-only (done), and delete it on account deletion (B1: not done).

---

## 12. Market, demand and marketability

**Who it is for:** Bangladeshi commuter riders on 100-165 cc bikes (Honda CG125, Bajaj, TVS, Yamaha), Dhaka first. The repo's pitch cites 4.5M+ BRTA-registered motorcycles. The local fit is real:
- Bangla UI;
- BD service schedules ("adjusted for traffic and dusty or wet roads");
- tax-token and insurance expiry reminders;
- fuel km/L;
- seeded Dhaka fuel, garage and parts directory;
- works offline.

**Competitors:**

| Competitor | What it does | Threat in BD |
|---|---|---|
| Strava | Ride logging; no motorcycle focus | Low |
| Calimoto | Curvy-road routing and tracking, freemium | Low for commuters |
| REVER | Tracking, routes, community | Low to medium for enthusiasts |
| EatSleepRIDE | Tracking plus CRASHLIGHT crash detection | Medium for the safety story |
| Detecht (Sweden) | Free tracking and automatic crash detection that alerts emergency contacts | Medium for the safety story |
| MotoSema, RideMesh, eTrax Rider | Newer apps with crash and SOS claims | Low |
| Life360 | Car crash detection, not BD-focused | Low |
| Google Pixel and Apple car crash detection | Car-tuned; no shipping motorcycle mode found; Apple has a two-wheeler patent | Low now; high if Apple ships it |
| Meetap | BD rider community app (clubs, events, chat, rewards); unverified | Medium for social |
| BikeBD and Facebook rider groups | Where BD riders already talk | **High.** Facebook groups own the community feature |

**What is unique:** Bangla plus BD maintenance knowledge plus offline-first. Social is not unique (Facebook wins), and crash detection is not unique (Detecht and EatSleepRIDE ship it, and it is off here). "My bike's service book on my phone, in Bangla, that knows Dhaka roads" is defensible.

**Monetization (none today), in order of plausibility:**
1. Garage and parts lead generation or listings.
2. Oil and parts brand sponsorship, via a rewards-for-service-logs model like Meetap's.
3. B2B fleet: delivery and rideshare riders. Maintenance, odometer and safety for fleets is the strongest wedge, because a fleet manager pays.
4. A premium tier for exports and PDFs.

Insurance telematics is weak in BD (mostly mandatory third-party cover).

**Retention loop:** maintenance due, a ride logs km, the next due date moves closer, a reminder fires. This exists (local notifications). There is no push for social.

**Beta evidence:**
- No rider count, interview or retention figure anywhere in the repo.
- GitHub APK downloads across all 19 releases total **19**. The best were beta-v2 and v2.2 with 6 each; beta-v4.5 has 1.
- The Play internal track count is unknown.
- The repo has 4 stars.
- The PRD's Day-30 retention target of 25% (`DOCS/PRD.md:297`) is a proposal, not a measurement.

**Sources (web search):**
- [Detecht (CB Insights)](https://www.cbinsights.com/company/detecht)
- [Detecht app listing](https://apppricinglab.com/app/apple/1373032762)
- [EatSleepRIDE vs Sizzapp (CB Insights)](https://www.cbinsights.com/compare/eatsleepride-1-vs-sizzapp)
- [MotoSema](https://mwm.ai/apps/motosema-telemetry-gps-lean/6758354871)
- [RideMesh](https://mwm.ai/apps/ridemesh/6768055572)
- [eTrax Rider](https://mwm.ai/apps/etrax-rider/6765995805)
- [Meetap BD rider community](https://contra.com/p/M7rWl2mg-meetap-built-with-flutter-flow-for-motorcycle-tour-enthusiast)
- [Pixel car crash detection (9to5Google)](https://9to5google.com/2022/09/07/google-pixel-car-crash-detection/)
- [Apple two-wheeler crash detection patent (MacTech)](https://www.mactech.com/2025/12/11/apple-wants-the-iphone-and-or-apple-watch-to-call-for-help-in-a-motorcycle-accident/amp/)
- [Crash detection on phones (Tom's Guide)](https://tomsguide.com/news/this-life-saving-google-pixel-feature-just-got-tipped-for-other-android-phones)

---

## 13. GTM percentage breakdown

| Dimension (weight) | Judge | Mine | One line |
|---|---|---|---|
| Product works (25) | 7 | **6** | The core recorder, garage and maintenance work in tests. Deletion is broken live, challenges are dead, RTDB and crash are inert, social has no push, and the latest build has had no device run |
| Quality and verification (15) | 8 | **6** | 2131 + 274 + 12 green (re-run by me), but no device, E2E or OEM test, and the found holes have no tests |
| Security and privacy (15) | 6 | **4** | Private data is owner-only and solid. Email harvest, block bypass, open Cloudinary uploads, undeleted data, App Check off |
| Legal and compliance (10) | 3 | **2** | Candid privacy page, but no terms, a false deletion line, open store declarations, no Apple privacy manifest, speed badges |
| Market validation (15) | 3 | **1** | 19 total APK downloads, no rider count, no interviews, no retention data |
| Deploy and operations (10) | 4 | **3** | CI green, Crashlytics, scripted releases. Spark blocks Functions, no forced update, a single keystore copy, a 105 MB APK |
| Claims honesty (10) | 8 | **5** | README and in-app copy are honest. The store listing and iDEA pitch claim crash detection; the README analytics line and privacy deletion line are false |
| **Weighted** | 58 | **41.5** | (6x25 + 6x15 + 4x15 + 2x10 + 1x15 + 3x10 + 5x10) / 10 |
| **Cap** | 45 | **40** | A store-facing privacy promise (deletion) is false today and cannot be fixed without Blaze; draft store copy advertises a disabled safety feature |
| **Final** | 45 | **40** | |

**Where I disagree with judge.md and the scorecard:**
- **`Podfile.lock`.** It is not a pubspec mismatch (§3, Podfile note).
- **"1.9 GB screenshots".**
  - `screenshots_ui` is **558 MB** on disk and about **412 MB** of the 578 MB git pack (71% of history).
  - The 1.9 GB figure adds `DOCS/General/posters` (1.3 GB), which is almost all an ignored local `.venv`.
- **"Rules not deployed".** Update 2's "already up to date" means they were live before; old builds are already affected.
- **Rules test count.** The judge's 274 matches my run. The functions emulator tests exist but were not run.
- **Quality and claims honesty are scored too high.** Reasons above.

---

## 14. What to cut or stop doing

| Cut | Why |
|---|---|
| New features until B1-B5 are fixed and 10 riders are on the latest build | Breadth is the problem |
| Crash and emergency marketing (store listing, posters, iDEA pitch) | The feature is off. Restore the claims only after field calibration and real delivery |
| Speed badges and the top-speed leaderboard (`badges.dart:475-485`) | They contradict the safety story and invite store and PR trouble |
| Challenges (dead under the rules) | Delete the UI and the repository |
| RTDB channel (inert in release builds) | Park it on a branch; delete it from `main` |
| `storage.rules` (not in `firebase.json`) | Dead file |
| 26 of the 28 appearance combinations, and the 7 ride-mode themes | Keep one light and one dark |
| `DOCS/General/screenshots_ui` (558 MB, 2433 files, public, shows real routes and name) and the 28-theme PDF generator | Move it to Drive, then `git filter-repo` it out of history (public repo: tell any cloners). If you need screenshots, keep 10 current ones |
| `DOCS/General/posters/.venv` (1.3 GB, ignored) and `posters.py`, `posters_v2.py` (keep v3) | Local clutter and stale scripts |
| `*-debug.log` at the root | Ignored and harmless. Delete them locally |
| `seed_police_checkposts.js` and `_v2.js` | Superseded by v3 |
| Release churn (5 releases in 4 days) | Release when riders are waiting, not per agent round |
| Handoff and issue log sprawl (about 11k lines) | Keep one page of current state; archive the rest |
| The Indriyo integration on the main roadmap | Hardware is a second company; keep it on its branch |
| Local branch `test` | Delete it after confirming `9f44168` is on no other branch (per `decision.md`) |

---

## 15. Top 10 next actions (by value)

| # | Action | Effort | Who |
|---|---|---|---|
| 1 | Today, change the privacy page and delete dialog to say deletion is done by hand within 30 days. Handle requests from a list. Then decide on Blaze, set a $5 budget alert, and deploy only `onUserAccountDeleted` with the 3 `userId` collection-group overrides | Copy: 1 h. Deploy: 2 h | Owner decides on Blaze and deploys; agent does the copy, overrides and emulator test |
| 2 | Remove crash-detection claims from `store_listing.md` and the iDEA pitch; fix the README analytics line | 1 h | Agent drafts; owner approves |
| 3 | Count the riders (Firebase Auth user count, Analytics weekly actives, Play track testers). Interview 5: "What would you miss?" Write the numbers into judge.md | 1 day | Owner |
| 4 | Device run of the current build on one Xiaomi or Realme with default settings and one iPhone: a 30-minute ride screen-off in a pocket, a mounted ride, a force-kill mid-ride, a widget refresh, a delete account | Half a day | Owner |
| 5 | Fix B2: move email out of the public profile, add a hash lookup and a list limit, add rules tests. Ship the client first | 4 h | Agent; owner deploys the rules |
| 6 | Add a `minBuild` forced-update gate (`config/app` doc plus a blocking screen) | 2-3 h | Agent |
| 7 | Fix B4 (ask "all the time" only for auto-tracking; disclosure once) and B5 (manual rides through the foreground-task service, a "recording stopped" notice, an OEM guide) | 1-2 days | Agent, then an owner device test |
| 8 | Fix B3 block gaps, and set Cloudinary preset limits (B8) | 2 h + 15 min in the console | Agent writes the rules and tests; owner sets the console limits |
| 9 | Store readiness: Terms of Service; `PrivacyInfo.xcprivacy`; Play permission justifications; data-safety form matching default-on analytics; Apple Developer Program enrolment before any iOS plan | 2 days | Owner (legal, accounts); agent drafts |
| 10 | Hygiene: one iOS build, then commit `Podfile.lock`; move the `secrets/` service-account JSON and the keystore out of the repo tree with an offline backup and Play App Signing; `--split-per-abi` releases; screenshots out of history; delete challenges, RTDB and the speed badges | Half a day | Agent; owner does the key moves and the history-rewrite decision |
