# ThrottleIQ: independent critique (2026-10-15)

Reviewer: senior engineer, product and go-to-market. Written from the code on branch `oct14-int` (HEAD `6afb4c3`, 48 commits on top of the baseline `cc6bb1a`). Nothing on this branch is pushed, released or deployed.

**What I ran:**
- `scripts/check.sh --force`: all green in 138 s.
  - `flutter analyze`: clean.
  - `flutter test`: 2105 of 2105 passed.
  - Firestore rules suite (emulator): 288 of 288 passed.
  - Functions pure tests: 12 of 12 passed.
- Functions emulator suite (`npm run test:emulator`): 11 of 11 passed. Covers account erasure, crash claims and GPS retention. This is the first independent run of that suite.
- GitHub API, read-only: release assets and download counts.
- Web search: competitors, store policy, Bangladesh data law.

**What I read:** every changed Dart, Kotlin, TypeScript and rules file since `cc6bb1a`; the Flutter SDK's split-APK version-code logic; the `flutter_foreground_task` 11.0.1 service source; the hosting pages; `SECURITY.md`, the handoff, the scorecard and `decision.md`.

**What I did not do:** run the app on a phone, emulator or simulator; build APKs or IPAs; run the RTDB suite or the integration tests; touch production. I did not open any live URL, so "live" claims about Hosting rest on `judge.md` Update 1, which says Hosting was deployed on 2026-10-14.

"Confirmed" means I traced it in code or reproduced it. "Suspected" means the code points that way, but the outcome depends on a device, a console setting or a reviewer.

---

## 0. Since 2026-10-14

The round did real work. Most baseline bugs are fixed **in code**. But nothing has reached a rider: no push, no release, no rules deploy, no device run. Production today looks exactly as it did yesterday.

### 0.1 Bugs B1-B14

| # | Baseline finding | Status | Evidence |
|---|---|---|---|
| B1 | Account deletion leaves cloud data; privacy page says it is automatic | **Still open** (the copy is now honest) | The dialog says cloud data is deleted by hand within 30 days after an email (`app_en.arb:3159`), and so does `privacy.html` §9. `onUserAccountDeleted` now also deletes chats and the email lookup, and reads Cloudinary secrets (`functions/src/account-erasure.ts:279-281`, `account-deletion.ts:88-99`). The three `userId` overrides are in `firestore.indexes.json:292-381`. Emulator suite 11/11 (I ran it). Not deployed: Spark. Email-to-delete still fails Apple 5.1.1(v) (§10) |
| B2 | Any signed-in user can list public riders' emails | **Fixed in code, not live** | No new email on the public doc (`firestore.rules:377-379`), lists capped at 20 (`:430-431`), lookup by hash (`:1415-1424`, `profile_repository.dart:21-22`, `:394-408`), plus a migration script. Until the rules deploy **and** the migration runs, production still exposes every email. The app strips the field only on explicit sign-in, not on app start (`auth_provider.dart:48-56`), so the migration is the real fix. New issues: N2, N3, N9 |
| B3 | Blocked riders can still write the chat preview, notify and re-follow | **Fixed in code, not live** | Chat create and update (`firestore.rules:1887-1890`, `:1925`, `:1941`), notifications (`:665-668`, both create paths), follows (`:1467-1468`). Six new rules tests pass |
| B4 | Disclosure and "Allow all the time" asked on every ride start | **Fixed** | Manual rides ask for while-in-use once (`ride_recording_provider.dart:82-90`, `:376`). The disclosure moved to the auto-tracking switch, shown until accepted (`recording_gate.dart:31-60`, `auto_tracking_tile.dart:134`). No more trip to Settings. New side effect: N5 |
| B5 | App killed mid-ride stops recording silently | **Partly fixed** | On Android the ride is hosted in the `flutter_foreground_task` service, and the handler takes over after 20 s without a UI heartbeat (`auto_tracking_service.dart:104-176`). Swipe-away is covered. A process kill with only while-in-use permission now posts "Recording stopped" and stops (`:130-139`), so the gap is still lost, though no longer silently. An OEM that blocks the restart still loses it silently. iOS is unchanged. There is an OEM guide (`oem_guide_screen.dart`). Not run on any device. New issues: N5, N6, N7 |
| B6 | Challenges dead under the rules | **Fixed** | Feature deleted. Zero "challenge" strings left in `app/lib` or `app_en.arb` |
| B7 | Self-awarded badges feed rarity percentages | **Fixed as advised** | `badge_rarity.dart` and its provider deleted. Self-award stays (cosmetic). But the global counters are now write-only (§2) |
| B8 | Open unsigned Cloudinary preset; false sweep comment | **Still open** (comment fixed) | The comment now says there is no folder sweep (`cloudinary_upload_service.dart:34-45`). Preset limits are a console job; I cannot see them |
| B9 | RTDB group-ride positions readable by non-members | **Fixed** | `database.rules.json:1-6` denies everything. Group-ride client parked on `park/rtdb-group-ride`. `core/realtime` (829 lines) is still in the app (§2) |
| B10 | Edits never move between devices | **Fixed in code** | Last-writer-wins on `updated_at` (`last_writer_wins.dart:21-65`; upload `cloud_repository.dart:127-161`; download `:696-760`; outbox `outbox_service.dart:671`, `:724`). The transaction path has no test against Firestore, and nobody has tried it on two phones |
| B11 | Crash UI promises contact delivery that does not exist | **Fixed** | Overlay and notification gated on `impactDetectorLiveEnabled` (`notification_service.dart:191`, `active_ride_screen.dart:853`); copy rewritten (`crash_copy_test.dart`) |
| B12 | Dismissing a crash alert reuses `finalizeRide` | **Fixed** | `RideDao.setStatus` (`ride_dao.dart:193-200`), used at `ride_recording_provider.dart:1485` |
| B13 | Mixed local and UTC time formats | **Fixed**, with one leftover | Schema v28 rewrites ride times to UTC (`database_helper.dart:373-456`), the model writes UTC and reads local (`ride_model.dart:10-12`, `:55-56`), day ranges compare UTC (`ride_dao.dart:300-305`), and downloads convert (`cloud_repository.dart:196-203`). The GPX export still writes local time with no offset (N10) |
| B14 | Wrong OSM contact domain | **Fixed** | `app_tile_layer.dart:65` uses hello@blankframe.tech |
| (note) | Uncommitted `Podfile.lock` | **No longer applies** | Committed from a real iOS build (`6c64333`) |

### 0.2 Corner cases

| Case | Baseline verdict | Status now |
|---|---|---|
| GPS loss in tunnels and old-town streets | Good for tunnels; 25 m gate under-counts in dense streets | **Still open, now measurable.** Kept and dropped fixes per ride are logged (`gps_drop_log.dart`, last 20 rides, in the bug report). Threshold unchanged. Nobody has read the numbers yet |
| OEM battery killers | Main field risk | **Partly fixed.** Foreground-service hosting plus a one-time guide for Xiaomi, OPPO, realme and vivo. Unverified on any of those phones |
| App killed mid-ride | Data-safe, gap lost | **Partly fixed.** See B5 |
| Offline ride, later sync | Solid | **No change, still solid.** Uploads are now one transaction per row, which fails fast offline and retries next cycle |
| Duplicate rides | Acceptable; bus false positive | **Still open.** `IN_VEHICLE` still fires on buses and CNGs |
| Sync conflicts | B10 | **Fixed in code.** LWW. Bike totals are whole-row LWW, so two phones on one bike can lose an odometer increment (documented) |
| Clock skew | B13 | **Partly fixed.** Times are UTC now. But LWW trusts the wall clock, so a phone set an hour fast now wins every conflict (`last_writer_wins.dart:12-13`). That exposure is new |
| Units | Fine for BD | **No change needed** |
| Mounted vs pocketed | Hide g and lean until calibrated | **Fixed for g.** The cockpit g readout waits for `AccelAxisCalibrator` (`ride_recording_provider.dart` `imuAxisCalibrated`). Lean comes from GPS heading, so it stays. That is fine |
| Crash false positives | Keep off | **No change.** Still off. A `feat/crash-shadow-mode` branch exists (not reviewed) |
| Crash false negatives | Never market as protection | **No change.** Claims are gone from the listing and the pitch, but not from the install page (N4) |
| Account deletion with shared data | Nothing deleted | **Still open.** The function would now delete chats for both sides; not deployed |
| Old beta builds vs new rules | No forced update | **Partly fixed.** The `minBuild` gate exists, but only in new builds. Split APKs defeat it (N1), and the B2 rules break old builds more than `SECURITY.md` says (N2) |

### 0.3 Security table

| Row | Status now |
|---|---|
| Owner-only private data | **No change, still good.** 288 rules tests pass |
| Live location | **No change** for Firestore live sessions. RTDB now denies all |
| PII exposure (email harvest) | **Fixed in code, not live** (B2) |
| Forging own badges and stats | **No longer applies** (rarity UI removed) |
| Message spam, no rate limits | **Still open.** Block gaps are fixed; there are still no per-sender limits |
| Functions auth | **No change, fine.** Triggers only. A per-uid cap is still needed before any SMS delivery |
| App Check | **Still open.** A runbook now exists (`SECURITY.md`); nothing is enforced |
| Cloudinary | **Still open** (B8) |
| Secrets tracked or in history | **Still clean.** `git ls-files` and `git log --all` are empty for `secret`, `secrets`, `*.keystore`, `**/*.jks`, `*-debug.log` and `app/android/key.properties` |
| Secrets inside the repo tree | **Still open.** The main checkout still holds `secrets/throttle-iq-gcc1-b9771877b5d4.json`, `secret/creds.txt`, `secret/tiles.env` and `throttleiq-release.keystore` at the root (ignored by `.gitignore:99`, `:104`, `:105`). The keystore's link count is 2; a hard link is the same file, not a backup |
| Retention | **Partly fixed.** `purgeOldGpsTracks` is written and emulator-tested (`functions/src/track-retention.ts`), not deployed |
| Analytics consent | **Partly fixed.** The README is now accurate (`README.md:69`). Still on by default, with an opt-out |
| Third parties (OSM tiles, Nominatim) | **Still open.** Default tile URL is `tile.openstreetmap.org` (`app_tile_layer.dart:40-41`) |
| Public repo with real routes and the founder's name | **Still open.** `DOCS/General/screenshots_ui` is 558 MB, untouched, and now shows 28 looks that no longer exist |

### 0.4 Store compliance table

| Item | Status now |
|---|---|
| Play background-location declaration | **Partly fixed.** Only auto-tracking asks now, so the case is honest. The declaration and video are still needed while `ACCESS_BACKGROUND_LOCATION` is in the manifest (`AndroidManifest.xml:7`) |
| Sensitive permissions | **Still open.** `USE_FULL_SCREEN_INTENT` is still declared (`AndroidManifest.xml:57`) while the only full-screen UI (crash) is off. Remove it until crash ships |
| Play data safety | **Partly fixed.** The CSV now declares app interactions and device ID for analytics (`throttleiq_data_safety.csv:69`, `:79`). Not checked against the console |
| Account deletion | **Still open.** Honest copy, but the flow needs an email (§10) |
| Apple | **Partly fixed.** `app/ios/Runner/PrivacyInfo.xcprivacy` added. No manifest for the widget extension, which reads app-group UserDefaults. Still on the personal team; no Sign in with Apple |

### 0.5 Cut list

| Cut | Status now |
|---|---|
| New features until B1-B5 are done and 10 riders are on the latest build | **Mostly respected.** This round was fixes and cuts. The OEM guide and GPS log are small |
| Crash and emergency marketing | **Partly done.** The store listing, iDEA pitch and posters are fixed. The **live install page** still says iOS gets "crash alert signatures" (`public/install/index.html:516`) |
| Speed badges and top-speed leaderboard | **Partly done.** The badges are gone. A personal "top speed" sort remains (`ride_sort.dart:10`), and public feed cards still show max speed (`social_feed_tab.dart:625`) |
| Challenges | **Done** |
| RTDB channel | **Partly done.** Rules deny all; the group-ride client is parked. `core/realtime` stays for live share and chat typing, inert in release builds |
| `storage.rules` | **Done** (deleted) |
| 26 of 28 themes and the 7 ride-mode themes | **Done.** One light, one dark |
| `screenshots_ui` and the 28-theme PDF generator | **Partly done.** Generator deleted; the 558 MB folder stays in the public history |
| Posters `.venv`, `posters.py`, `posters_v2.py` | **Done** |
| Root `*-debug.log` | **Done** (none left in the main checkout root) |
| `seed_police_checkposts.js` and `_v2.js` | **No longer applies.** The handoff shows the three scripts seed different batches. I accept that |
| Release churn | **Done so far.** No release since 2026-10-09 |
| Handoff sprawl | **Still open.** 11,346 lines across the handoff folder |
| Indriyo on the main roadmap | **Still open.** The README still gives it the second section |
| Local branch `test` | **Still open.** `9f44168` is on `test` only |

### 0.6 Top-10 actions

| # | Baseline action | Status now |
|---|---|---|
| 1 | Honest deletion copy today; then Blaze and the trigger | **Copy done, not deployed. Blaze not decided** |
| 2 | Remove crash claims from listing and pitch; fix the README analytics line | **Done** (install page missed: N4) |
| 3 | Count riders, interview 5 | **Not done.** No rider number appears anywhere in the repo |
| 4 | Device run on a Xiaomi or realme and an iPhone | **Not done.** More urgent now: the recording path was rewritten |
| 5 | Fix B2 | **Done in code**, not deployed, migration not run |
| 6 | `minBuild` gate | **Done**, but split APKs bypass it (N1) |
| 7 | B4 and B5 | **B4 done, B5 partly** |
| 8 | B3 and Cloudinary limits | **B3 done in code**; Cloudinary limits are with the owner |
| 9 | Store readiness (terms, privacy manifest, justifications, data safety, Apple program) | **Partly.** Privacy manifest and data-safety CSV done. Still no Terms of Service (none in `public/`, none in the ARB) |
| 10 | Hygiene | **Partly.** `Podfile.lock` committed; split APKs added (with N1); challenges, RTDB client and speed badges cut. Secrets, keystore and screenshots history untouched |

---

## 1. Verdict

ThrottleIQ is an offline-first motorcycle ride recorder with a garage and maintenance planner and a rider community, in English and Bangla, for Bangladeshi commuter riders.

This round fixed most of the baseline in code, and fixed it well: email off public profiles, block gaps, last-writer-wins sync, UTC times, honest deletion copy, two themes instead of 28.

None of it has shipped. The rewritten ride-recording path has never run on a phone. Demand is still unmeasured: 19 APK downloads across 20 releases, and the iOS waitlist on the install page stores emails only in the visitor's own browser.

**Continue?** Yes, narrowed to ride log plus maintenance for BD commuters. Stop the agent rounds until this branch is on riders' phones.

**My GTM readiness: 45% for this branch once shipped; 40% for what is live today.** The scorecard's 40% is right for production, which has not changed. The branch earns about 5 points: the email exposure and block gaps close, the claims are honest, and the sync bug is gone. It does not earn more for three reasons. The deletion flow still fails Apple and is weak for Play. The new foreground-service recording path has no device evidence. And one new bug would quietly break the forced-update gate the whole rules plan relies on (N1). Market validation is still close to zero, and code cannot move that.

---

## 2. Code and architecture

**Shape.** Unchanged and right for BD: Flutter, Riverpod, go_router; SQLite as the source of truth (now schema v28); an outbox to Firestore; Cloudinary for images; trigger-only Cloud Functions that are not deployed. 422 Dart files and about 85k lines outside generated l10n.

**What this round did well:**
- **LWW is small and careful.** One 66-line helper (`last_writer_wins.dart`) carries the policy. Uploads are read-then-write transactions. The "mark synced" step is guarded by `updated_at IS ?`, so an edit made during an upload is never marked synced by mistake (`cloud_repository.dart:145-148`). That closes an old race as well as B10.
- **The v28 migration is safe.** It is additive (`_addColumnIfMissing`), rewrites values only, and installs the touch triggers after the backfill so the backfill does not stamp rows as edited now (`database_helper.dart:404-456`). It has 15 real-SQLite tests.
- **The triggers carry the bookkeeping.** `*_touch_updated_at` stamps any update that leaves a row unsynced, so new DAO methods need no extra code. That is the right place for it.
- **The B5 design is sound.** The service runs in the same process; the UI isolate keeps recording; the handler only takes over when the heartbeat stops; `canRecordWithoutUi` respects Android's while-in-use rule for restarted services (`auto_tracking_service.dart:709-713`).
- **Real deletions.** About 8,700 lines removed against 6,200 added outside docs. The theme provider shrank to one brightness choice with a sensible migration (`theme_style_provider.dart:125-144`).

**What is not:**

| Issue | Evidence | Why it matters |
|---|---|---|
| The recorder keeps growing | `ride_recording_provider.dart` is 1,531 lines (was 1,422). Still only 3 test files touch `rideRecordingProvider` | The most safety-relevant file absorbed hosting, rehosting, heartbeats and GPS logging. It has no test of any of that |
| Platform code tested only as pure functions | `manual_ride_hosting_test.dart` tests `uiGone`, `canRecordWithoutUi`, `takeoverPointRow`. Nothing tests the heartbeat, the takeover stream, the MethodChannel or the transaction | The parts most likely to fail on a Xiaomi are the parts with no test |
| Write-only badge counters | Nothing in `app/lib` reads `stats/badges` any more. `badgeStatsDocPath` is used only by the writer (`badge_stats_counter.dart:54`, `:93`, `:120`) | 251 lines of client code, about 200 lines of rules, and 20+ rules tests now maintain a number nobody shows. Sign-up's profile write is coupled to it (`profile_repository.dart:112`) |
| `core/realtime` still live | 829 lines, used by chat typing and the live-share publisher; inert because `RTDB_URL` is unset, and RTDB rules now deny everything | Dead weight with tests; it fails the moment someone sets the URL |
| Dead profile field | `UserProfileEntity.email` is still read from the public doc (`user_profile_model.dart:20`) | Harmless. It will read null after the migration; delete it |
| Hidden singletons beside DI | `AutoTrackingService.instance`, `NotificationService.instance`, `HomeWidgetService.instance` called from the notifier; the handler isolate builds its own DAOs | Same as the baseline. It is why the recorder has thin tests |
| Standards | `CATCH_MAX` is still 66, 643 hard-coded `fontSize:` literals, analyze clean, format clean | The bare-catch ratchet has not moved down in two rounds |

**Process.** 48 commits in this round across five parallel branches, merged into one integration branch. The merge discipline (one worktree each, one gate after the last merge) worked: the gate is green. But 313 commits since 2026-09-15 against 19 downloads is still throughput without feedback.

---

## 3. Bugs (ranked)

Ranked by harm once this branch ships. "N" numbers are new in this round.

**N1. High, Confirmed. Split-per-ABI APKs bypass the `minBuild` gate and trap riders on an un-upgradable version code.**
- `deploy.sh` now builds and attaches `--split-per-abi` APKs (`scripts/deploy.sh:195`). The release notes call the arm64 one "Direct Android Install, most phones" (`:242`). It is about half the size, so BD riders on mobile data will pick it.
- Flutter sets each split's version code to `abi * 1000 + versionCode`: 1xxx for armv7, 2xxx for arm64, 4xxx for x86_64 (Flutter SDK `FlutterPlugin.kt:669-673`, `FlutterPluginConstants.kt:39-45`).
- The gate reads that version code through `package_info_plus` and blocks only when `currentBuild < minBuild` (`app_update_gate.dart:30-31`).
- **Failure 1:** the owner sets `minBuild = 28`. An arm64 rider on build 27 reports 2027 and is never blocked. The gate fails silently for most of the riders it exists for.
- **Failure 2:** that rider later installs the universal APK (version code 28) or joins the Play track (AAB, 28). Android refuses the downgrade. The only way out is to uninstall, which deletes the SQLite database and every unsynced ride.
- None of the 20 existing releases has split APKs (GitHub API), so nobody is trapped yet. The next `deploy.sh` run starts it.
- **Fix:** in `android/app/build.gradle(.kts)`, reset each split output to the base version code (`versionCodeOverride = variant.versionCode`). GitHub sideloads don't need unique codes. Or stop attaching split APKs. Or compare `buildNumber % 1000` in the gate. The first fixes both failures.

**N2. Medium, Confirmed. Deploying the B2 rules breaks old builds more than `SECURITY.md` says.**
- Old builds (≤ beta 4.5) always write `email` and `emailLower` in `ensureProfile` (baseline `profile_repository.dart:82-85` at `cc6bb1a`).
- The new rule refuses any new email value (`firestore.rules:377-379`). A brand-new profile has no stored email, so `keeps` is false.
- **Failure A:** a rider who installed an old APK signs up after the rules deploy. The sign-up batch and the fallback `set` are both denied. `_seedProfile` swallows the error (`auth_provider.dart:48-56`), so the rider gets no public profile and no username, and never finds out.
- **Failure B:** after the migration strips emails, an old build's `updateDisplayName` calls `ensureProfile` first, which is now denied. The whole block is swallowed, so the display-name change never reaches the profile (`auth_provider.dart:124-134`).
- Old builds have no `minBuild` gate, so they cannot be told to update.
- `SECURITY.md` step 1 mentions only lost find-by-email and All People.
- **Fix:** add both failures to `SECURITY.md`. Release the new build, message every tester to update, wait a few days, then deploy. At under 20 sideload installs this is a WhatsApp message, not a code change.

**N3. Medium, Confirmed in rules. The email lookup trusts an unverified email.**
- An `emailLookup` write needs the hash of the caller's token email (`firestore.rules:1415-1424`). It does not check `email_verified`.
- The app never sends a verification email (no `sendEmailVerification` in `app/lib`).
- **Failure:** someone registers with email and password using an address they do not own, such as a well-known rider's work address that is not on ThrottleIQ yet. They now own its lookup, and anyone searching that address finds them. This is the impersonation that §90.D6 was meant to stop.
- Limited to addresses not already registered, under Firebase's default one-account-per-email setting (Suspected: I can't see the console).
- **Fix:** require `request.auth.token.get('email_verified', false) == true || request.auth.token.firebase.sign_in_provider == 'google.com'` on create and update. Send a verification email at sign-up.

**N4. Medium, Confirmed. The site's iOS waitlist and campaign tracking measure nothing, and the waitlist tells people otherwise.**
- `submitIOSEarlyAccess` saves the email into the visitor's own `localStorage` and shows "✔ You're on the list! We'll email you the TestFlight / App Store invite." (`public/install/index.html:529`, `:649-666`). No email reaches the owner.
- `trackDownload` is a `console.log` (`:669-671`). The `?c=` campaign names are therefore never counted.
- The same page says iOS is in "closed TestFlight testing" (`:510`). The personal team `NJ4675FFUX` cannot use TestFlight. It also promises "crash alert signatures" on iOS (`:516`).
- This page is live per `judge.md` Update 1.
- **Failure:** every interested iPhone rider is lost, and the owner believes there is no iOS demand.
- **Fix:** post the form to a Firestore `waitlist` collection (create-only rule) or a Google Form. Count downloads with the existing Analytics or a redirect. Remove the TestFlight and crash lines.

**N5. Medium. Confirmed in code; the dialog itself is Suspected on device. Pausing or ending a ride can re-ask for permissions.**
- Pause, stop and discard all call `_endHosting` (`ride_recording_provider.dart:542`, `:1073`, `:1163`). That calls `endManualRide`, which calls `stop()` and then `start()` (`auto_tracking_service.dart:659-672`).
- For a rider with auto-tracking on, `start()` re-requests activity recognition, notification permission and the battery-optimisation exemption whenever they are not granted (`:560-583`).
- **Failure:** an auto-tracking rider who declined the battery exemption gets the system "let app always run in background?" dialog at every pause and every ride end. That undoes §90.C11 ("asked once, ever").
- **Fix:** split `start()` into a silent "start the service if allowed" and an "ask for what's missing" step. Only `enable()` should ask.

**N6. Low-Medium, Confirmed in code. A swiped-away ride records until the app is reopened.**
- After a swipe, the handler records every fix (`distanceFilter: 5`, every second; `auto_tracking_service.dart:147-170`) and advances the ride clock. Nothing ends the takeover except the next app launch or a pause from the UI.
- **Failure:** a rider swipes the app away at the office, thinking the ride is over. GPS runs all day. The next morning's ride, and the overnight gap, join the same ride, and the elapsed time includes the night. The notification is visible (channel importance LOW, the plugin default), so it is not silent, but most riders will not read it.
- **Fix:** in the handler, end the takeover after 10-15 minutes without movement and leave the ride for restore. Show "Ride paused: tap to finish" instead.

**N7. Low-Medium, Suspected. If the heartbeat never arrives, the handler records the whole ride a second time.**
- The handler decides the UI is gone after 20 s with no beat (`auto_tracking_service.dart:615`). `sendUiBeat` swallows every error (`:673-680`).
- If the port fails on some phone, the handler's 1 Hz stream and the UI's 2 Hz stream both write `ride_points` for the whole ride. The result is a zig-zag trail, a doubled track upload, and inflated distance on any recompute.
- No test covers the beat path.
- **Fix:** one device check (logcat must never show "UI gone" during a foreground ride). Add a unique index on `(ride_id, timestamp)` or drop takeover points that are less than 1 s from a UI point.

**N8. Low, Suspected. The "Update required" screen points to a page this repo does not host.**
- `kInstallUrl` is `https://blankframe.tech/ThrottleIQ/install` (`app_update_gate.dart:26`). Hosting serves `/install` on `throttleiqfb.web.app`, and `blankframe.tech` is a separate landing site (`public/follow.html:12`).
- If that path 404s, a blocked rider has nowhere to go.
- **Fix:** open the URL once; or point at `throttleiqfb.web.app/install`.

**N9. Low, Confirmed. The B2 fix depends entirely on the migration script.**
- `ensureProfile` strips a legacy email only when it runs, and it runs only on `signIn`, `register` and Google sign-in (`auth_provider.dart:48-56`), not on app start. Most riders never sign in again.
- Until the owner runs `migrate_emails_private.js`, a scraper pages through 20 profiles per query with no limit on the number of pages (`firestore.rules:430-431`).
- **Fix:** run the migration the same hour the rules deploy (it is already step 5 in `SECURITY.md`; make it step 2b). Also call the strip once per app start.

**N10. Low, Confirmed format; impact Suspected. GPX and JSON exports write local time without an offset.**
- `ride_summary_screen.dart:1151` passes `ride.startTime.toIso8601String()` (local, no `Z`) into `export_service.dart:121-130`'s GPX `<time>`. Track points are UTC.
- GPX readers treat a missing offset as UTC, so Strava shows a Dhaka ride 6 hours off.
- **Fix:** `.toUtc().toIso8601String()` at the export boundary.

**N11. Low, Confirmed. A bike with a local photo uploads twice.**
- `uploadBikes` uploads the photo, then `updateImagePath` changes the row. The trigger stamps a new `updated_at`, so the "mark synced if unchanged" step finds no match (`cloud_repository.dart:305-325`, `:145-148`). The bike uploads again next cycle.
- Harmless: one extra write.

**N12. Low (latent), Confirmed. The first sync after v28 is a full pull.**
- `resetPullMarksOnceForV28` clears every watermark once (`sync_manager.dart:215-225`). That is one read per ride, bike, maintenance log and fuel log.
- Fine at 20 riders. At a few hundred riders who all update in one day, it could exhaust Spark's 50k reads, and on Spark that stops the app for everyone until the daily reset.

**Still open from the baseline:** B1 (deletion, not live), B8 (Cloudinary console), and the deploy halves of B2 and B3.

---

## 4. Corner cases and failure modes

Nothing here was run on a device. These are code traces.

| Case | What the code does now | Verdict |
|---|---|---|
| GPS loss in tunnels (Karnaphuli) and Old Dhaka | The same 25 m gate and gap rules; drops are now counted per ride | Read `GpsDropLog` from five testers' bug reports before changing the threshold |
| Xiaomi, OPPO, vivo, realme battery savers | Ride hosted in a sticky foreground service with a wake lock (`auto_tracking_service.dart:546-548`); one-time vendor guide with autostart deep links (`oem_guide_screen.dart:17-43`) | Better. Whether MIUI's autostart switch blocks the sticky restart is the open question. The guide is offered once and cannot be found again (no Settings entry) |
| Swipe from recents mid-ride | The process lives (the service is not `stopWithTask`); after 20-30 s the handler records into `ride_points`; reopening restores the ride paused with those points | Works in theory. Loses about 20-30 s per swipe. Records until reopened (N6) |
| Process killed by the OS | `START_STICKY` restarts the service (`ForegroundService.kt:186-188` in the plugin). With while-in-use only: "Recording stopped" after about 30 s, then the service stops. With "Allow all the time": takeover | Honest now. Most manual riders have while-in-use only, so a real kill still loses the gap |
| Phone reboot mid-ride | `autoRunOnBoot` restarts the service as a system start, which takes the same path as a kill | Acceptable |
| iOS force-quit mid-ride | Unchanged. iOS stops location; restore on next open | Still a gap. Document it in the app |
| Offline sync conflicts | Upload transactions fail fast offline; rows stay `synced = 0`; a newer remote copy is adopted unless the local row changed since it was read (`last_writer_wins.dart:50-65`) | Correct by reading. No two-phone test |
| Duplicate rides | UUIDs; marker check against auto-detection | No change. Bus and CNG false positives remain |
| Clock skew | UTC storage. LWW uses the phone's wall clock | A phone 1 hour fast wins every conflict for an hour. Rare. Add a sanity check: reject `updated_at` more than 5 minutes ahead of server time when adopting |
| Mounted vs pocketed | g hidden until calibrated; lean from GPS | Fixed |
| Crash false positives and negatives | Detector off, UI gated | Keep it off. Shadow-mode logging is the right next step |
| Account deletion with shared data | Function deletes chats for both sides, anonymises forum posts; not deployed | Policy is reasonable; it doesn't run |
| Old builds vs new rules | No gate in old builds; new sign-ups get no profile (N2) | Message testers before the deploy |
| Old builds vs the v28 schema | Old builds drop unknown ride and bike columns, but **skip** maintenance logs written by v28 (they insert verbatim into a table without `updated_at`). The failure pins their watermark, so they re-read those logs every cycle | Documented in the handoff. Set `minBuild` once the v28 build is out, which N1 currently breaks |
| Split-APK rider updating | Version-code downgrade refused; uninstall wipes local data | N1. Fix before the next release |

---

## 5. Security and privacy

| Question | Answer |
|---|---|
| Can one rider read another's rides, tracks, fuel, maintenance or emergency contacts? | No. Owner-only, 288 rules tests pass (I ran them) |
| Can a rider harvest emails? | **Today, yes** (production is unchanged). On this branch, no: lists are capped at 20, email is off the public doc, and the lookup is get-only. But only after the rules deploy **and** the migration (N9) |
| Can a rider impersonate an email? | Yes, for addresses not yet registered, because the lookup ignores `email_verified` (N3) |
| Is the lookup an oracle? | Yes, mildly. Any signed-in user can test whether an address has an account and learn its uid (`firestore.rules:1416`). Acceptable for find-by-email; say so in the privacy page |
| Does blocking work? | On this branch, yes, for chats, messages, notifications and follows. Group-ride invitations still have no block check (`firestore.rules:1693-1703`), so a blocked rider can invite you; the notification is now refused (Low) |
| `config/{doc}` world-readable | Correct for `minBuild`. Never put anything private there |
| RTDB | Deny-all. Good |
| Secrets | Not tracked, never in history. Still inside the repo tree on the owner's disk, where agents run with broad read access. `SECURITY.md` step 5 rightly says to keep the service-account key outside the repo, but it is still inside today |
| Admin by email | `isAdmin()` still falls back to a verified personal Gmail address in a public file (`firestore.rules:136-140`). Run `set_admin_claim.js` once and delete the fallback |
| Cloudinary | Open unsigned preset (B8) |
| App Check | Not enforced; the runbook is sound (enforce only after Play distribution) |
| Retention | Raw tracks kept forever until `purgeOldGpsTracks` deploys. The code is ready and tested |
| Analytics | On by default with an opt-out; documented honestly |
| Public repo | 558 MB of screenshots with real routes and the founder's name are still in public history |

---

## 6. UI

I did not run the app, so this rests on code and the handoff's headless shots. I did not see those shots myself.

- **Two themes.** Light (Calming) and dark (Carbon Mono), curvy only. Settings offers System, Dark and Light. This is the right cut. The default is Light, not System; riders who ride at night will want System.
- **Dark map glare is still there.** The OSM raster stays bright in dark mode (`app_tile_layer.dart` has no dimming or dark style). It is the biggest visual problem at night. A `ColorFiltered` dim in dark mode is a few lines.
- **Cockpit.** The g bar now hides until calibrated: good. "Confidence" is still a cockpit label (`app_en.arb:1056`) and is still jargon.
- **Record screen.** The slide-to-start track is gone; the 900 ms hold ring stays. Good.
- **New screens** (update required, OEM guide) are plain Material with fixed 15-pt text. Fine for a rare screen.
- **Bangla.** 1,652 keys sit in `bn_pending_review.txt`, including the delete-account legal copy and the Play disclosure. Machine-quality Bangla in a disclosure is a review risk.

---

## 7. UX

- **Starting a ride is now one tap and one permission prompt.** That is the biggest UX win of the round (B4).
- **The OEM guide fires once, on the Record screen, after the first finished ride** (`record_screen.dart:67-78`). Good timing. But "Not now" loses it for good. Add a Settings entry: "Rides keep stopping?".
- **Swipe-away is now a different product.** Before, a swipe ended recording. Now it continues until reopen (N6). Tell the rider in the notification text: "Recording. Open ThrottleIQ to finish."
- **Pause and end with auto-tracking on** can now pop system dialogs (N5).
- **When things go wrong:**
  - Offline: works, syncs later.
  - Killed with while-in-use: a "Recording stopped, tap to resume" notice. That is honest.
  - Blocked by `minBuild`: a full-screen block with one link (check that it resolves, N8). The screen also hides the rider's own data. Add "Export my rides" on it, so a rider who cannot update right away keeps access.
- **Account deletion** now tells the truth, but asks the rider to send an email. Most won't. They will assume it is done.
- **Social still has no push.** DMs, forum replies and group-ride invites are invisible until the app is opened. The maintenance reminder remains the only working loop.

---

## 8. Accessibility and performance

- **Text scale** is still capped at 1.3x (`app.dart:359`), with 643 hard-coded `fontSize:` literals and 27 `Semantics(` uses. No change.
- **Battery.**
  - Manual rides: screen wake lock for the whole ride, plus `bestForNavigation` at 500 ms. Unchanged.
  - The takeover adds a second GPS client only while the UI is gone.
  - The service holds a partial wake lock (`allowWakeLock: true`) for the whole ride, which is right for reliability and costs some battery.
  - N6 can leave GPS on for hours after a swipe.
  - Still unmeasured (handoff item C6).
- **App size.** Split APKs would take a rider from about 105 MB to about 45 MB, a real win on BD data. Fix N1 first.
- **Slow networks.** Uploads are now one transaction per row: two round trips each. On 3G with 300-800 ms RTT, a 50-ride backlog takes about a minute. Acceptable. Downloads are unchanged.
- **Cold start.** The `minBuild` read does not block start (`app.dart:259-261`; loading counts as "no update").
- **Spark quota.** The v28 full pull (N12) and per-ride vote reads on the feed are the two read spikes to watch.

---

## 9. Testing and verification

| What | Result (I ran it) | What it proves | What it does not |
|---|---|---|---|
| `flutter analyze` | Clean | Types, lints | Behaviour |
| `flutter test` | 2105/2105 | DAOs and the v28 migration on real SQLite; LWW comparisons and `adopt`; the gate's decision logic; the permission helpers; the OEM brand map; the hosting predicates; theme migration | The heartbeat, takeover stream, MethodChannel, service restarts, Firestore transactions, and any old-build interaction. Only 3 test files touch the recorder |
| Rules (emulator) | 288/288 | B2 lookup, the 20-doc limit, B3 blocks, `config` read-only | `email_verified` (N3 is untested because it is unhandled); old-build profile writes (N2) |
| Functions pure | 12/12 | Claim, lease and name logic | Deployment |
| Functions emulator | 11/11 | `deleteUserData` erases everywhere, is re-runnable, records partial failures, signs Cloudinary calls; retention purges old chunks only | That it is deployed, or that Blaze will be bought |
| `migrate_emails_private.test.js` | Exists (pure) | Planning and duplicate detection | A real run |
| Device, emulator, OEM | None | Nothing | Everything in B5, N5, N6, N7 |

**Biggest gap:** the round rewrote how a ride survives the background, and nobody has started one ride with it. One 30-minute device session would check more than the 59 new tests.

**Where I disagree with the handoff:**
- "The existing restore gets the whole ride" holds only for swipe-away. After a real kill with while-in-use, the gap is lost; the notice just says so.
- "A legacy copy is stripped" (`ensureProfile` doc) happens only on explicit sign-in (N9).
- The split-APK change is presented as a size win with no version-code check (N1).

---

## 10. Deploy and operations

- **State.**
  - Hosting and indexes are deployed. The rules are live in whatever form Update 2 found, which this branch would replace.
  - Functions: none deployed (Spark).
  - This branch is unpushed.
- **Release pipeline.** `deploy.sh` is fine for one person. Fix N1 before the next run. 20 releases, 19 downloads, 0 split APKs so far.
- **Monitoring.** Crashlytics only. No alert on rules denials, sync failures or quota. The new `debugPrint`s in the service do not reach Crashlytics; add `reportNonFatal` to the takeover and watchdog failures.
- **Backups.** None. Scheduled backups and point-in-time recovery need Blaze.
- **Rollback.** Rules roll back from the console history. App rollback depends on N1 being fixed.

**The owner's deploy steps in `SECURITY.md`.** The order is right: client, then rules and indexes, then `minBuild`, then the migration, then Blaze. Gaps:
1. Step 1 should list N2 (no profile for new sign-ups on old builds; silent display-name failures).
2. Move the migration to directly after the rules deploy. Until it runs, the rules only slow a scraper (N9).
3. Step 4 (`minBuild`) does not work for split-APK riders until N1 is fixed.
4. Step 5 assumes the service-account key is outside the repo. Today it is in `secrets/`.
5. Steps 6-7 (Blaze) are fine. The budget-alert advice is right.

**Store compliance:**

| Item | State |
|---|---|
| Play background location | Needed only for auto-tracking now. **Consider shipping v1 without auto-tracking**: drop `ACCESS_BACKGROUND_LOCATION` and the activity-recognition permissions, skip the declaration and video, and avoid the bus false positives |
| Foreground-service type | `location` declared and used for both jobs. Play's FGS declaration needs a short video of a manual ride with the notification visible |
| `USE_FULL_SCREEN_INTENT` | Remove until crash alerts ship. Play restricts it to calling and alarm apps |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Justifiable for a ride recorder. Expect questions |
| Data safety | CSV updated. Check it against the console, including analytics on by default |
| Account deletion | Play needs an in-app path that deletes the data, plus a web link. Apple 5.1.1(v) says apps outside regulated industries "should not require people to ... send an email". **The email step fails Apple and is weak for Play.** A Spark-compatible fix: the app writes `deletionRequests/{uid}` before deleting the Auth user, and the owner runs a small Admin-SDK script that calls the existing `deleteUserData` (it passes 11/11 on the emulator) once a week. No Blaze, no email, about 3-4 hours of agent work |
| Apple | Paid program needed. Sign in with Apple (or an equivalent) is needed alongside Google sign-in (guideline 4.8). The widget extension needs its own privacy manifest |

---

## 11. Legal and compliance

- **Bangladesh data law is now concrete.** The Personal Data Protection Ordinance 2025 (Ordinance No. 61) was gazetted on 6 November 2025, with an 18-month compliance window, so about May 2027 (press and law-firm reports; I did not read the gazette). The reports stress explicit consent for collection and use, and localisation for data classed "confidential" or "restricted". Location trails and third parties' phone numbers (emergency contacts) are the likely sensitive classes. Get a BD lawyer to read the ordinance against the data map in `privacy.html` before any public launch.
- **No Terms of Service.** Still none. An app with DMs and forums needs terms with a no-tolerance clause (Apple 1.2) and a limitation of liability, especially for anything safety-adjacent.
- **Privacy page.** It is now honest about deletion and background location. But that version is not deployed. The live page still says cloud records "are then removed automatically" (Hosting was deployed before this change).
- **Claims.**
  - Store listing and pitch: fixed.
  - Install page (live): TestFlight, crash alerts and a fake waitlist (N4).
  - iDEA pitch team slide: three named roles and an advisory panel, while git shows one human author (1 identity under 4 spellings). If those people are not real and committed, a government grant body will treat it as misrepresentation (Suspected; I cannot verify unnamed people).
  - The pitch also targets 50,000 registered users in year one, from 19 downloads.
- **Speed.** Max speed is still public on feed cards (`social_feed_tab.dart:625`). Under the Motor Vehicle Act 2018 that is self-incriminating evidence. Make it private by default.
- **Emergency contacts.** Third-party numbers are stored without their consent; that is disclosed, owner-only, and not deleted on account deletion (B1).
- **Bangla legal text.** The Bangla delete copy and disclosure are unreviewed (`bn_pending_review.txt:93`, `:493`).

---

## 12. Market, demand and marketability

**Who it is for:** Bangladeshi commuters on 100-165 cc bikes, Dhaka first. The pitch cites 4.5M+ BRTA-registered motorcycles and about 500k new ones a year.

**Demand evidence, unchanged since the baseline:**
- GitHub release downloads: 19 in total across 20 releases (beta-v4.5: 1; beta-v4.4: 0). Checked today.
- 4 stars, 0 forks.
- No rider count, no interviews, no retention number anywhere in the repo.
- The site cannot measure interest: the waitlist stays in the visitor's browser and download tracking is a `console.log` (N4).

**Competitors (updated):**

| Competitor | What it does | Threat in BD |
|---|---|---|
| **BDHonda+ (Honda Bangladesh)** | Service booking, maintenance guidance, service-centre finder, parts; Honda is a top-selling brand in BD | **High for the garage wedge.** I missed this in the baseline |
| **My Suzuki (Suzuki Bangladesh)** | Service appointments, service history, ride tracking, bike details | **High for Suzuki owners** |
| Trackers BD, Finder GPS (with BikeBD) | Hardware GPS trackers, live location, engine status | Medium for the safety and anti-theft angle |
| BikeBD and Facebook rider groups | Where BD riders already talk | High for social |
| Strava | Generic ride logging | Low |
| Calimoto, REVER | Routing, tracking, community | Low for commuters |
| EatSleepRIDE, Detecht, Triumph SOS, RealRider | Crash detection with alerts; Triumph and RealRider are paid monthly | Medium for the safety story; they ship what is switched off here |
| Bikeminder and other service-log apps | Generic maintenance logs | Low |
| Google and Apple crash detection | Car-tuned | Low now, high if Apple ships a two-wheeler mode |

**What is still unique:** brand-neutral maintenance (any bike, any garage) in Bangla, BD service intervals, tax-token and insurance reminders, works offline. The brand apps cover only their own bikes and their own service centres. That is the real pitch: "one service book for any bike, at any garage". Social is not unique, and crash detection is off.

**Who pays (in order of plausibility):**
1. B2B fleets: delivery and ride-hailing riders' fleet managers want odometer, maintenance and safety records. This is the only buyer with a budget and a reason.
2. Independent garages and parts sellers paying for leads or listings. That needs a rider base first.
3. Oil and parts brand sponsorship tied to service logs.
4. A premium tier for exports and PDFs. Small.

**Distribution.** GitHub APK plus a Play internal track. BD riders install from Play. Until there is a public Play listing, every channel (Facebook groups, garages, rider clubs) leads to an APK download that Play Protect warns about.

**Why would a rider switch?** From a paper service book or memory: reminders that fire on real km. From BDHonda+ or My Suzuki: only if they own two brands, use independent garages, or want ride logs in Bangla. That is a real but narrow segment. Test it with ten riders before building anything else.

**Pitch and website claims vs reality:**

| Claim | Reality |
|---|---|
| "Real riders are testing" (README) | No number. 19 downloads |
| "Closed TestFlight testing" (install page) | Impossible on a personal team |
| "You're on the list!" (install page) | Stored only in the visitor's browser |
| "Crash alert signatures" on iOS (install page) | Detector off everywhere |
| "Proprietary multi-sensor fusion algorithms" (pitch) | Standard filters in a public, source-available repo. Puffery |
| A three-lead team plus advisors (pitch) | One human author in git (Suspected) |
| "Group rides with live positions" (README) | True, via Firestore member locations |

**Sources:**
- [BDHonda+ upgraded app (BikeBD)](https://www.bikebd.com/blog/honda-launches-upgraded-bdhonda-app)
- [BHL BDHonda app (BikeBD)](https://www.bikebd.com/blog/bhl-bdhonda-app-in-bangladesh)
- [My Suzuki app (BikeBD)](https://www.bikebd.com/blog/suzuki-bangladesh-my-suzuki-app)
- [Trackers BD (BikeBD)](https://www.bikebd.com/blog/trackers-bd-a-vehicle-tracking-system)
- [BikeBD and Finder GPS MoU](https://www.bikebd.com/blog/mou-signing-ceremony-between-bikebd-and-finder-gps)
- [Bikeminder (App Store)](https://apps.apple.com/app/id1024640003)
- [Triumph SOS (App Store)](https://apps.apple.com/us/app/id1553736073)
- [Triumph SOS launch (Quad Lock)](https://www.quadlockcase.eu/blogs/news/triumph-sos-smartphone-app-connects-riders-to-emergency-services)
- [Triumph SOS (Practical Motoring)](https://practicalmotoring.com.au/?p=68713)
- [RealRider SOS (App Store)](https://apps.apple.com/us/app/-/id1080699050)
- [Google Play account-deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Apple: offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app)
- [Apple guideline 5.1.1(v)](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion)
- [BD data ordinances gazetted (TBS)](https://www.tbsnews.net/node/1281356)
- [BD data ordinances gazetted (Prothom Alo)](https://en.prothomalo.com/bangladesh/government/teeopu4dfv)
- [PDPO 2025 compliance note (BD-SCL)](https://bd-scl.com/insights/personal-data-protection-ordinance-2025-compliance.html)
- [PDPO 2025 takeaways (Asia News Network)](https://asianews.network/?p=234602)
- Baseline sources (Detecht, EatSleepRIDE, Meetap and others) are in `CrtiQue_Oct14.md` §12.

---

## 13. GTM percentage breakdown

Scores are for this branch as if pushed and deployed. Production today stays at 40%.

| Dimension (weight) | Scorecard (Oct 14) | Mine | One line |
|---|---|---|---|
| Product works (25) | 6 | **6** | Real fixes to recording, sync and permissions, but none on a phone; deletion still manual; social has no push |
| Quality and verification (15) | 6 | **6** | 2105 + 288 + 12 + 11 green (re-run by me). The new platform code is tested only as pure functions; no device or two-phone test |
| Security and privacy (15) | 4 | **5** | B2, B3, B9 closed in code. Not deployed; the migration is pending; unverified-email lookups; secrets in the tree; open Cloudinary preset |
| Legal and compliance (10) | 2 | **3** | Honest privacy page (not yet live). Still no ToS; email-based deletion fails Apple; BD ordinance window running; public max speed |
| Market validation (15) | 1 | **1** | 19 downloads; no rider count; the site's waitlist and tracking capture nothing |
| Deploy and operations (10) | 3 | **4** | Clear owner runbook, forced-update gate, emulator-tested functions. Still Spark, no backups, no alerting; N1 breaks the gate |
| Claims honesty (10) | 5 | **6** | Listing, pitch, README and privacy fixed. The live install page and the pitch's team slide are not |
| **Weighted** | 41.5 | **46** | (6×25 + 6×15 + 5×15 + 3×10 + 1×15 + 4×10 + 6×10) / 10 |
| **Cap** | 40 | **45** | Account deletion still needs an email (fails Apple 5.1.1(v)), and the rewritten recording path has no device evidence. Production is unchanged, so the live score stays 40 |
| **Final** | 40 | **45** (branch) / **40** (live) | |

**Where I disagree with the scorecard and judge.md:**
- The scorecard's 40 is right for today, but it is about to be stale in both directions. The branch removes the two worst live problems, and it adds N1 and N2, which can hurt riders at the very next release.
- The judge's "real riders testing" premise is still unsupported. Market validation deserves 1, not 3.
- The scorecard's note that ThrottleIQ "firestore.rules is not deployed" conflicts with judge Update 2, which says the CLI reported the rules as already live. The deploy plan in `SECURITY.md` works either way.

---

## 14. What to cut or stop doing

| Cut or stop | Why |
|---|---|
| More agent rounds before this branch is on phones | Five parallel branches and 48 commits are now waiting on one device test and one push. Every further round adds untested platform code |
| Split APKs, until N1 is fixed | They break the gate and trap riders |
| Auto-tracking for the first public Play release (consider) | It is the only reason for `ACCESS_BACKGROUND_LOCATION`, the hardest Play review, and the bus false positives. Bring it back after launch |
| `BadgeStatsCounter`, `stats/badges` and their rules | Write-only since the rarity UI went. About 450 lines of code and rules for nothing |
| `core/realtime` (829 lines) | Inert, with deny-all rules. Park it with the group-ride client |
| `USE_FULL_SCREEN_INTENT` | No feature uses it while crash is off |
| The install page's TestFlight line, crash line and fake waitlist | Replace them with a real form |
| Public max speed and the personal top-speed sort | Safety story and legal exposure |
| `DOCS/General/screenshots_ui` (558 MB, 28 removed looks, real routes) | Move it out and rewrite history (public repo) |
| The pitch's unnamed team roles, unless real | A grant body will check |
| Handoff growth (11,346 lines) | Keep one page of current state |
| Indriyo at the top of the README | A second company. Move it to a link at the bottom |
| Local branch `test` | One stale commit |

---

## 15. Top 10 next actions (by value)

| # | Action | Effort | Who |
|---|---|---|---|
| 1 | Fix N1: reset split-APK version codes to the base code in Gradle (or ship universal APK plus AAB only). Add a check in `deploy.sh` that all APKs share one version code | 30 min | Agent |
| 2 | One device session before any push. On a Xiaomi or realme with default settings and on one iPhone: a 30-minute pocket ride; swipe-away mid-ride; force-stop mid-ride; reboot mid-ride; pause and resume with auto-tracking on (N5); logcat must never show "UI gone" during a foreground ride (N7); open the update-screen link (N8) | Half a day | Owner |
| 3 | Ship: push, release, message every tester to update, then deploy rules and indexes and run the email migration the same hour. Amend `SECURITY.md` with N2 and the new order first | Agent: 30 min of docs. Owner: 2 h | Both |
| 4 | Replace email-to-delete with an in-app deletion request plus a weekly Admin-SDK script that calls `deleteUserData`. Update the dialog and privacy page to match. No Blaze needed | 3-4 h | Agent writes; owner runs weekly |
| 5 | Count riders (Auth user count, Analytics weekly actives, Play testers) and interview five: "what would you miss?" Ask specifically about BDHonda+ and My Suzuki. Write the numbers into `judge.md` | 1 day | Owner |
| 6 | Make the site measure: a real waitlist (Firestore create-only or a Google Form), real download counting, and remove the TestFlight and crash lines (N4) | 1-2 h | Agent; owner deploys Hosting |
| 7 | Require a verified email (or Google) for `emailLookup` writes, send verification at sign-up, and add a rules test (N3) | 1-2 h | Agent; owner deploys rules |
| 8 | Recording polish: split `start()` from the permission prompts (N5); idle auto-end for the takeover (N6); a dedup guard on `ride_points` (N7); UTC in GPX export (N10); a Settings entry for the OEM guide | Half a day | Agent, then owner re-tests on a device |
| 9 | Store readiness: decide on auto-tracking for v1; remove `USE_FULL_SCREEN_INTENT`; write Terms of Service; add the widget privacy manifest; get native review of the Bangla legal strings; decide on the Apple program; have a lawyer read the PDPO 2025 | 2-3 days | Owner (legal, accounts); agent drafts |
| 10 | Hygiene and cuts: move `secrets/`, `secret/` and the keystore out of the repo tree, with an offline keystore backup and Play App Signing; delete the badge counters and `core/realtime`; make max speed private; move screenshots out of history; delete branch `test` | Half a day | Agent; owner does the key moves and the history rewrite |
