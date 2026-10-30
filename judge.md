# ThrottleIQ: go-to-market judge

Scored 2026-10-14 from the README, `DOCS/Handoff for agents and Todos/HANDOFF_Document.md`, `scripts/check.sh`, `.gitignore` and the git log. I did not run the gate, the app or CI. Test counts and "real riders testing" are the repo's own statements. Treat the score as +/- 10 points.

## Verdict

**45%, cap 45.** The most mature project in the folder: an offline-first Flutter ride tracker, garage and rider community with Firebase, in English and Bangla. A signed beta (`1.0.0-beta.4.5.0+26`) is said to be with real riders. It is not safe to open publicly yet: the Firebase project is on the Spark plan, so Cloud Functions cannot deploy, and the handoff does not confirm the latest Firestore rules are live. Crash detection and emergency alerts are off.

## What exists

- App (`app/`): ride recording (GPS plus 20 Hz motion sensors), analytics, garage and maintenance, places and routes, social (feed, forums, DMs, group rides), live-share link, data export, account deletion, English and Bangla.
- Backend: Firestore rules (274 emulator tests on 2026-10-09), Cloud Functions (12 tests, written but not deployable), Cloudinary for photos, Hosting.
- Quality gate: `scripts/check.sh` runs l10n, format, CI guards, analyze, 2131 Flutter tests and the rules and functions suites; a pre-push hook and CI call it. Last green per the handoff: 2026-10-13 after the dependabot merge.
- Release keystore and `secret/` are git-ignored (checked); `app/android/key.properties.example` is the only tracked key file.
- Branches on 2026-10-14: `main`, `experimental` (same commit then; it has since diverged), `indriyo` (dash-cam hardware integration), local `test`.

## Gaps (ranked)

1. **Cloud Functions cannot deploy** (Spark plan, needs Blaze): account cleanup, ride identity and chat moderation are not live. `firestore:rules` for badge counters and fuel sync were "NOT yet deployed" on 2026-10-09; no later note confirms it.
2. **Crash detection and emergency alerting are not live** (detector off pending calibration, no SMS or email provider). The README says so plainly, which is the right call.
3. **No device or E2E run** for the latest changes. The `home_widget` 0.10 widgets and the Indriyo HUD are marked unchecked on a device. 2131 tests are unit and widget tests.
4. **Founder-only items open** (2026-10-08): Play and Apple declarations, analytics consent, chat moderation policy, group-ride location function, CSP/SRI, contact email and secrets layout.
5. **No public listing.** Distribution is a GitHub Releases APK and a Play internal track. The iOS team `NJ4675FFUX` is a personal Apple team (no push, no Associated Domains).
6. **Market validation:** how many real riders, how often they ride and whether they would keep using it are not recorded anywhere I read.
7. **Security:** about 150 audit findings (§101) were triaged; most fixes are on a branch pass, and the `functions` emulator suite was not run for that pass. No human review of the rules or auth code.
8. **Hygiene:** `DOCS/General/screenshots_ui` is about 1.9 GB (2,433 tracked files). Fixed since: `SECURITY.md` is real and `AGENTS.md` and `CODING_STANDARDS.md` exist (Update 1); `ios/Podfile.lock` is committed (`6c64333`).

## Scores (0-10)

| Dimension (weight) | Score |
|---|---|
| Product works (25) | 7 |
| Quality and verification (15) | 8 |
| Security and privacy (15) | 6 |
| Legal and compliance (10) | 3 |
| Market validation (15) | 3 |
| Deploy and operations (10) | 4 |
| Claims honesty (10) | 8 |
| **Weighted** | **58** |
| **Cap** | **45** (backend only partly deployed; store declarations and consent policy open) |
| **Final** | **45** |

## Next steps, in order

1. **You:** confirm what is live: `firebase deploy --only firestore:rules,firestore:indexes` and the Blaze decision for Functions. Record the result here.
2. **You:** run the current build on a real phone through one real ride, a widget refresh and an account deletion.
3. **You:** count the beta riders and ask five of them what they would miss if the app vanished.
4. **You:** finish the Play and Apple declarations. Analytics consent decided 2026-10-22: disclosed opt-out stays (default on, Settings toggle, `privacy.html`). Moderation policy done 2026-10-21 (`DOCS/General/Files for Stores/moderation_policy.md`).
5. **Code:** done. `SECURITY.md` replaced and `AGENTS.md` added (Update 1); `Podfile.lock` committed (`6c64333`).
6. **You:** get a human to review `firestore.rules` and the auth and moderation functions.
7. Keep crash detection off until it is calibrated on real rides.

## Update 1 (2026-10-14, pushed `6ca31db` to `main`)

Done: real `SECURITY.md` (private reports to the owner's email), `AGENTS.md`, `CODING_STANDARDS.md`; `check.sh` passed.
**Deployed to `throttleiqfb`:** Firestore indexes and Hosting. **Not deployed, on purpose:** `firestore.rules`. Per the handoff, old builds lose search, All People and forum post create and delete when the new rules go live, and `users` docs need a `visibility: 'public'` backfill first. Rules compile with one warning (line 455). Functions cannot deploy on Spark.
**Skipped:** the old `seed_police_checkposts` v1 and v2 scripts are required by tests and docs, so they stay. `app/ios/Podfile.lock` stays uncommitted: its diff removes `home_widget`, but `pubspec.yaml` and `pubspec.lock` still list it, so the lockfile and pubspec disagree and need a human look. Local branch `test` and `screenshots_ui` untouched. Score unchanged at 45%.

## Update 2 (2026-10-14): Firestore rules deployed

`firebase deploy --only firestore:rules` to `throttleiqfb` at the owner's request; the CLI reported the rules released ("already up to date, skipping upload": the file matched an existing ruleset, so the live rules may have been unchanged). Compile warning at line 455 remains. The `users` `visibility: 'public'` backfill was **not** run, and no old-build behaviour was checked: if beta riders on old builds report broken search, All People or forum posts, that is the cause named in the handoff.

## Update 3 (2026-10-15, agent round)

Pushed `f2a770e`, `0d4806d`, `2da5af1` (plus this note); `check.sh` passed, nothing deployed.
- **F6 closed:** `scripts/ste_sentence_length.js` finds 0 PRD sentences over the ASD-STE100 limits. 7 passive sentences and 4 non-approved words fixed by hand; record in PRD §13. No full STE-dictionary pass.
- **Rules warning gone:** the line-455 (now ~523) `publicStatsValid(… null …)` call passes `{}`; same behaviour. A new emulator test fails on any compiler issue. Rules not deployed.
- **Backfill written, not run:** `scripts/oneoff/backfill_users_visibility.js` (dry run default, `--project` required, per-doc precondition). How to run: handoff, 2026-10-15 (agent round). Old-build search and All People still wait on the owner running it.
Score unchanged at 45%.

## Update 4 (2026-10-16, agent round)
Proof, not verified: unit tests against the in-memory RTDB fake only; no device, no emulator, nothing deployed.
- **§99.4 closed:** the queued live-share teardown now also removes `/live_shares/{token}` (`removeLiveShareNode`, socket lease held for the write; a timeout makes the outbox retry). A share the app was killed in no longer stays readable until its 24 h `expiresAt`. Review fixes: the RTDB remove now runs after the Firestore revoke and pointer clear, and a rules rejection (the B9 deny-all rules) is logged instead of thrown, so it can no longer park the whole teardown as dead; the doc comment no longer steals `OutboxService`'s. 4 tests (removed, timeout releases the lease, rejection releases the lease, RTDB off). Not tried on a device.
- **E2E harness item was already done** (`setUpAll` initializes Firebase); the todo is ticked. Not re-run on a simulator.
- **Left on purpose:** refreshing `expiresAt` for shares over 24 h (the todo says "if very long shares matter": a product call).
Score unchanged at 45%.

## Update (2026-10-19, review round)

Re-reviewed `main` at `76ed92a` (8 commits since `f464230`). Read-only: live GETs, the diffs and CI (green on `76ed92a`). Nothing deployed, no production writes, no device run.

**Verified fixed**
- **The update link in installed builds works again.** All three published builds (27, 28, 29) carry `https://blankframe.tech/ThrottleIQ/install`; the Hosting link at `app_update_gate.dart:27` is in no release yet. The old link now goes 301, 301, then a redirect page (landing-page `915ba51`, `throttle-iq/old-install-link.html`) to `throttleiqfb.web.app/install/`, whose APK link serves `beta-v4.7.1`. It works only through that redirect, so keep the page for as long as builds 27-29 exist.
- **`minBuild = 29` is live**, not only in the docs: the public `config/app` doc reads 29 (set 2026-10-18 21:55 UTC). Builds 27 and 28 now see the update screen. Builds 26 and older have no gate and are not blocked.
- **Hosting matches the repo.** The live install and privacy pages are byte-identical to `public/`. The date-triggered "live on Google Play" block is gone (`019a663c`), and the iOS copy says no iPhone build exists.

**Bugs found in the new code and data**
- **Medium, Google-sourced places are marked verified.** `scripts/oneoff/import_google_places.js:169` writes `verified: true` on 717 scraped listings, so they get the Verified badge and pass the "verified only" filter. Nobody checked them.
- **Medium, the 80 enriched places can't be cleanly undone.** The undo note covers the 717 creates (one query on `createdBy`). The 80 existing docs only gain a `googlePlaceId` (`:143`); which phone, hours, name or address values came from Google is not recorded. Separating them needs the raw export, which is "kept outside the repo" in a place nobody wrote down.
- **Low, duplicate pins by design.** Matching is same-category only (`:129`), so a Google "Motorcycle shop" (parts) next to an OSM garage becomes a second pin. A Google place whose nearest doc was already claimed is created even if another unclaimed doc is within 60 m (`:139`).
- **Low:** the `/cng/i` title rule (`:86`) files a CNG conversion workshop as a fuel station. Builds up to 29 still show "★ 0 (Not on Google)" on every place, including the 717 that came from Google. `issues_open.md` §105.1 says both "written to production" and "Nothing has been written to Firestore".

**Legal: the Google Maps import.** The 717 new places and the 80 enrichments come from an Apify scrape of Google Maps, not from the Maps Platform API. Google's Maps end-user terms (Additional Terms of Service §2, modified 2026-01-27) forbid copying the content, mass downloads and bulk feeds, and using Google Maps "to create or augment any other mapping-related dataset (including a … business listings database)" for a substantially similar service. A fuel, garage and parts directory on a map is that kind of dataset. Dropping the ratings was right, but name, phone, hours and location are still Google Maps content. Attribution does not license it: there is no attribution that makes this allowed, and a "from Google Maps" label would only document the breach. The likely cost is not a lawsuit. It is a takedown or removal from Google Play (Google owns both), or a due-diligence problem with a grant or fleet partner. To fix it: delete the 717 `system:gmaps-seed-dhaka` docs, strip the Google-filled fields from the 80 enriched docs, and re-collect through riders or field visits. The other option is a written legal opinion before you keep the data. The Places API is no shortcut: its terms limit what you may store (the Place ID is the exception).

**Gaps, ranked by what must happen first**
1. **High, security:** rules and the email migration are still not deployed (SECURITY step 3), so emails stay on public profiles. `minBuild = 29` now unblocks this, once Analytics shows no active tester on build 26 or older.
2. **High, legal:** the scraped Google Maps data is in production (above).
3. **High, ops and cost:** Spark is still the plan and §104.1 (all places within 25 km re-read every 5 km, `live_ride_places_provider.dart:43,55`) now reads 2.4 times as many places. My estimate puts the read quota under 10 daily riders (not simulated). Functions are still not deployed.
4. **High, legal:** account deletion is still an email to hello@blankframe.tech (`privacy.html:526`). That fails Apple 5.1.1(v) until Blaze and `onUserAccountDeleted` are live.
5. **Critical, marketability:** there is no public listing (the Play URL returns 404). The install page labels Play "Recommended", but `scripts/deploy.sh` never uploads to Play, and the last Play build on record is `1.0.0-beta.1+3`, which has no gate.
6. **Critical, profitability:** there is no revenue model and no measured demand. Nobody has recorded weekly active riders.
7. **Medium, security:** the unsigned Cloudinary preset still ships (`cloudinary_upload_service.dart:63`), and its console limits can't be checked from here. The Apify token pasted in chat is not rotated. The service-account key still sits in the Drive-synced `secrets/`.
8. **High, usability:** the rewritten recording path and the new detail screen have never been run on a phone.
9. **High, UX:** riders hit an account wall before they get any value.
10. **Medium, ops:** the update link of builds 27-29 depends on a Jekyll permalink in another repo, on a case-insensitive checkout. If someone deletes that page, the forced-update screen 404s again.

**Next steps, in order**
1. **You:** decide on the Google data. Either take it down (step 2) or get a written legal opinion first. Until then, do not market the places directory.
2. **Agent:** write a revert script (dry run by default) that deletes the `gmaps-seed` docs and, using the saved export, clears the Google-filled fields on the 80 enriched docs. Also stop writing `verified: true` for imported data. **You** run it.
3. **You:** do SECURITY step 3 (rules, indexes, then the email migration in the same hour) after checking Analytics for builds 26 and older.
4. **Agent:** fix §104.1 (cache nearby places by area, and refetch only when the rider leaves it), with tests.
5. **You:** upgrade to Blaze with a $5 budget alert and deploy `onUserAccountDeleted`. Set the Cloudinary preset limits, rotate the Apify token, and move the key out of `secrets/`.
6. **You:** ship the next build (Hosting link, detail-screen fix), upload it to the Play closed track, and do one real ride, a swipe-away test and a deletion on a phone. Keep the landing-page redirect.

**Score:** product works 6, quality 6, security 5, legal 3 → 2 (scraped Google data in production), market 1, deploy 4, claims 6. Weighted 45. **Cap 40:** rules and functions are still not live (deletion by email), production now holds Google Maps data the terms forbid, and nothing has run on a phone. Final **40%**.

## Update (2026-10-21): stale `test` branch merged and deleted

The local-only `test` branch (2 commits, 2026-08-30/31, 419 behind) is merged into `main` so its history stays, then deleted. Almost all of it was obsolete: a Space Grotesk heading font, CartoDB tiles (already undone by its own second commit), pause-button, stat-label, spacing and bike-card tweaks on screens `main` has since rewritten, five per-screen copies of the map tile code (now one `AppTileLayer`), plus screenshots, a 1.7 MB screen recording, `preview.html` and a stray `test_matrix.dart`. All of that resolved to `main`. Kept: its dark-mode map filter (grayscale + invert on OSM tiles), now in `AppTileLayer` with a test. This fixes the "dark map glare" item in `CrtiQue_Oct15.md` §6. Not checked on a phone. Score unchanged.

## Update (2026-10-21): a deleted rider's chats are anonymised, not deleted

Owner decision: "What happens to a deleted rider's chats → Anonymise the deleted rider's side." `deleteUserData` (`functions/src/account-erasure.ts`) no longer deletes every DM the rider is in. In each chat, their uid becomes `deleted-rider` in `participants`, `lastMessage.senderId` and their messages' `senderId`. Their message text is blanked, because `privacy.html` §9 lists messages among the records deleted. Legacy `participantNames`/`participantPhotos` entries for them go, and so do `reportedId`/`originalText` on the automated chat-moderation reports. The other rider keeps the thread and their own messages, and a chat with no live participant left is deleted. One step per chat, the messages first and `participants` last, so a retry finds the chat again (emulator suite: 11/11, including a re-run). The app shows "Deleted rider", "Message deleted" bubbles and a "This rider deleted their account" banner instead of the composer, and it no longer looks up a profile for that rider (widget tests). Privacy policy (effective date now 21 October 2026), the manual deletion runbook and the data-safety notes are updated.
**Kept on purpose:** the chat's doc id still contains the deleted uid (`uidA_uidB`). Moving the doc would re-fire `onMessageCreate` on every copied message and break open rooms. After deletion the uid points at no account, profile or username. Chats carry no attachments and the app has no Firebase Storage, so nothing extra to delete (Cloudinary media already goes through the ledger sweep).
**Not deployed:** `onUserAccountDeleted` (Blaze, SECURITY step 5) and Hosting for the privacy page. No rules change. Score unchanged at 40%.

## Update (2026-10-21, agent round): chat moderation policy

Owner decision: reports plus manual admin review with a written response time. Branch `moderation`; nothing deployed.
- **Existed already:** report sheet (reason picker plus optional details) on chat messages (long-press), rider profiles, forum posts and shared rides; Block on the profile and a Blocked users screen; `reports` rules that let a signed-in rider create a pending report and only the admin read or update; the keyword filter `onMessageCreate` (not deployed). **Missing:** any policy, any response time, a way to find the reported chat message or forum post (only the bare id was stored), a Report/Block route from inside a chat, any alert to the admin, a test of the sheet.
- **Added:** `public/community.html` (rules, how to report and block, human review within **24 hours**, warn/remove/suspend/ban, appeals) linked from the report sheet; `DOCS/General/Files for Stores/moderation_policy.md` (policy summary and admin runbook: console query, review, act, record `status`/`action`/`reviewedAt`/`reviewedBy`/`note`); chat and forum reports now store the full document path; tapping the chat header opens the rider's profile (Report, Block); the sheet scrolls on small phones; `privacy.html` DM row says a reviewer reads reported messages. Tests: 3 widget tests for the sheet, 1 rules test (create-only, no read-back, no impersonation, signed-out denied).
- **Admin alert:** a documented console filter (`status == pending`), checked daily. No email: no mail provider is set up and Functions need Blaze.
- **Open, owner:** deploy Hosting (`community.html` 404s until then; the link is in the next build); one human review of rules and functions (still open, carried from Next steps 6); decide whether 24 hours is the promise you can keep.

## Update (2026-10-21): App Check on Firestore, owner decision

Owner: enforce App Check on Firestore, as long as iOS `flutter run --release` keeps working; sideloaded Android builds may die and should point riders to Play and a WhatsApp testing request.
- **iOS answer:** a development-signed release build passes App Attest only with `com.apple.developer.devicecheck.appattest-environment = production`. Firebase rejects sandbox App Attest tokens, and Apple uses the sandbox by default for development signing. The entitlement needs the paid team, so it is a documented owner step (`DOCS/For Devs and Contributors/guides/app_check.md` step 2), not in `Runner.entitlements` yet: the project still signs with personal team `NJ4675FFUX`. The working path today: `--dart-define=APP_CHECK_DEBUG=true` (debug provider in release, token registered in the console).
- **Code:** `core/services/app_check_gate.dart` plus `SideloadBlockedScreen` (EN and BN). Blocks only an Android release build that was not installed by the Play Store and that App Check rejects ("App attestation failed"). Network errors, timeouts, `SERVICE_DISABLED`, iOS, debug-provider builds and Play installs never block. 9 tests.
- **Checked:** `check.sh` passed; `flutter build ios --release --no-codesign` built; the Android release APK compiled and minified, and failed only at signing (no keystore in the worktree). Not run on a device; the "App attestation failed" string is the Firebase Android SDK's message as commonly reported, not seen from this project.
- **Risk:** this build blocks itself if it is sideloaded once App Check is set up, so it must ship through Google Play, and the install page still serves APKs. Nothing enforced, nothing deployed.
Score unchanged at 40%.

## Update (2026-10-21): Google Maps import revert, ready, not run

Owner has not decided whether to take the 2026-10-19 Google Maps content down; `scripts/oneoff/revert_google_places.js` is ready for when they do. It picks places by the import's own tag (`createdBy == 'system:gmaps-seed-dhaka'`, the 717) and, for the 80 enriched ones, by `googlePlaceId`, which nothing else writes; no other verified place is touched. Mode B `--seeded-only` deletes the 717 (no export needed); mode A `--from=<export>` also clears the Google-derived fields on the 80. Dry run by default; `--apply` needs `--backup=<new file>`, written before the first write, and `--restore=<backup> --apply` undoes it. Reviewed or updated seeds are skipped and listed; writes carry a read-time precondition. **No pre-import snapshot exists** (no backups on Spark), so the 80 are reconstructed from the export; the 69 ratings set to 0 stay 0. Export: `~/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json` (Apify dataset `7tcKVfmd9vYe3nGnS`). How to run: `scripts/README.md`, revert section.
- **Checked:** 6 unit tests; an emulator round trip with the real 897-row export (40 pre-import places, the real import, one rider review): B deleted 766 and kept the reviewed one, A then cleared 30, all 40 pre-import places matched their pre-import data, re-runs had nothing to do, restoring both backups gave back the post-import collection exactly. **Not run against production**, not even the dry run. Not tested: a review landing mid-run (precondition skip).
Score unchanged at 40%.

## Update (2026-10-21): E2E harness on an iOS simulator

Run on `main` `d92f694e` (branch `e2e-run`), iPhone 17 simulator, iOS 27.0, Xcode 27.1, Flutter 3.44.9.
- **Why it "wasn't seen" on 2026-10-18:** not tooling. A parallel agent (PotholeAlertBD) ran `xcrun simctl shutdown all` between this agent's `simctl list` (Booted) and its `flutter test -d`; Flutter only lists *booted* simulators. Doctor, Xcode, runtime and CocoaPods are fine. Parallel agents should not run `simctl shutdown all`.
- **`integration_test/e2e_test.dart`** (`flutter drive`): **0/1 pass.** Fails about 7 s in, at teardown, with `Bad state: … ProviderContainer that was already disposed` (real app bug): `RideRecordingNotifier.dispose()` calls `_liveCoordinator.dispose()` (`app/lib/features/ride/presentation/providers/ride_recording_provider.dart:1592`), and when no ride used live share that first touch runs the `late final` initialiser, which does `_ref.read(realtimeServicesProvider)` (`:304-305`) on a container already being disposed. It fires whenever the root `ProviderScope` is disposed before live share was used (tests, hot restart); a killed app process skips `dispose()`, so riders likely never see it. With a fix (nullable field, `?.dispose()`) applied as a temporary, uncommitted patch: **1/1 pass**, nothing else fails behind it. The fix is not committed (waits on the owner). Note: this test talks to production Firebase (no emulator hook), and its assertions sit behind `if` checks for a signed-in shell, so on a fresh simulator it mostly proves "launch and tear down without throwing".
- **`integration_test/realtime_emulator_test.dart`** (auth + database emulators, default ports 9099/9000, host `127.0.0.1`): **4/4 pass** on unpatched `main`.
Score unchanged at 40%.

## Update (2026-10-21): reported messages and posts keep a protected copy

Closes the gap from the moderation round: a report stored only a path, so the sender could erase the evidence. Branch `report-snapshot` (two commits); nothing deployed.
- **Stored:** chat reports carry `snapshot` {text, senderId, sentAt}; forum-post reports {title, body, imageUrls, senderId, sentAt}. The app reads the document fresh and sends the copy; `firestore.rules` (`snapshotIsReal`) accepts it only if it equals the stored document field for field (`get()`), names its author as `reportedId`, and, for chat, the reporter is in that chat (else the rule would be an oracle for other riders' DMs). Riders can't read, edit or delete reports. If old rules refuse the key, the app files the report without it. Rules-validated client write rather than a trigger: that is the repo's Spark-plan pattern (badge stats), and it works before Blaze. Image URLs are links only; the images can still go from Cloudinary.
- **Retention:** 90 days after `reviewedAt` (task default; no period was documented), then `snapshot` and `originalText` go and the report stays. Runs in the existing daily `purgeOldGpsTracks` (`purgeOldReportSnapshots`, Blaze, not deployed; deploying it also starts GPS retention, SECURITY step 6). Manual purge until then (`moderation_policy.md` §5).
- **Account deletion:** a pending report about the rider is kept whole (uid and copy) and flagged `reportedAccountDeleted`; a closed one, or a flagged one the day after it is closed, gets `reportedId`/`originalText` blanked and `snapshot.senderId: deleted-rider`. Applies to every content type now, not only chat. Reports the rider filed: function leaves them, manual runbook deletes them (open owner decision).
- **Docs:** `privacy.html` §1 (DMs and posts), §8 (EN, plus a machine-written BN line marked for review), §9; `moderation_policy.md`; deletion runbook; data-safety notes; SECURITY step 8; functions READMEs.
- **Tests:** rules suite 314/314 (chat and post: forged, misattributed, outsider, missing doc, wrong type denied; post rule mutation-checked); functions emulator 13/13 (pending kept, closed anonymised, 90-day purge, re-run no-op); 4 Dart tests for `reportSnapshotOf`. The rules tests now read the emulator host from `FIRESTORE_EMULATOR_HOST`, and `check.sh` takes `CHECK_FIREBASE_CONFIG` for other ports (8080 is held by another service on this Mac).
- **Correction to the first commit (e76dface):** it dropped posts and used 180 days; this round restores posts, uses 90, and anonymises the uid after close instead of blanking `reportedId` while keeping it in `snapshot.senderId`.
Score unchanged at 40%.

## Update (2026-10-21): review of the 11 unpushed commits, two fixes

Reviewed `origin/main..main` (screenshots untrack, `test` merge, chat anonymisation, moderation, App Check gate, report snapshots, Google-places revert script) and committed the owner's research docs (no redactions needed: no names, links, phones or tokens; the raw Apify datasets stay gitignored, checked with `git check-ignore`).
- **Fixed:** `RideRecordingNotifier.dispose()` created the live-share coordinator just to dispose it, reading a provider from a disposing container (the E2E teardown failure above). Now a nullable field; unit test disposes the real notifier without live share. **Fixed:** the report retention purge removed the evidence of a report set back to `pending` (an appeal) once its old `reviewedAt` passed 90 days, against `moderation_policy.md` §5; pending is skipped now (emulator test).
- **Checked, no bug:** `snapshotIsReal` builds the copy from three named fields, so moderation's `isToxic`/rewritten text and a `deleted-rider` peer don't break it (rules test added); forged, misattributed, outsider and missing-doc copies are denied; riders can't read or edit reports; 2 `get()`s per report. Concurrent deletions of both riders: the transaction leaves `[deleted-rider, deleted-rider]` and the chat is deleted; re-runs find nothing. Revert script: `--apply` without `--backup` refuses, the backup is written before the first write, a mid-run failure is skipped and listed, a restore of an undeleted doc is skipped. Dark filter: tiles only, light mode untouched, markers and polylines unfiltered.
- **For the owner to decide:** (1) App Check gate: Firebase App Distribution and `adb install` builds are blocked once App Check rejects them; Play internal-app-sharing builds (Play installer, different signing key) and phones without Google Play services are not blocked but will fail once Firestore is enforced. Whether an unregistered app already gets "attestation failed" today is unverified: try one sideloaded release build before shipping. (2) No rate limit on reports. (3) A report filed after the reported rider deleted their account keeps the uid (never flagged). (4) Reports the deleted rider filed (already open). (5) A closed report with no `reviewedAt` is never purged. (6) The WhatsApp number in the sideload screen is public. (7) In dark mode the map's light-grey background still shows where tiles haven't loaded.
- **Gate:** `check.sh` passed (flutter 2282, rules 315/315, functions 12); functions emulator suite 13/13 on other ports. E2E (`integration_test/e2e_test.dart`, `flutter drive`, fresh iPhone 17 Pro simulator, iOS 27.0) now passes with the fix committed: 4/4 including teardown (still mostly launch and tear down, against production Firebase).
Score unchanged at 40%.

## Update (2026-10-25): "Suggest.Bike marketplace + ThrottleIQ predictive e-commerce" plan, triaged

An outside plan proposed selling oil and accessories on Suggest.Bike and driving sales from ThrottleIQ (SSO, a Cloud Function on odometer readings, rich push with discount deep links). Reviewed against this repo; **no ThrottleIQ code changed.**
- **Already exists, on-device and on Spark:** odometer-driven oil-change alerts (`features/maintenance/data/services/maintenance_alerts.dart`: due-soon/overdue alert after a ride, date-driven ones scheduled), with the oil grade picked in setup setting the interval (`domain/catalog/schedule_templates.dart`). Tapping one opens that bike's maintenance page (`core/services/notification_service.dart:516`, `maintenancePayloadPrefix`). A "within 100 km" Cloud Function would duplicate this, needs Blaze, and would need riders' odometers on the server, which they are not today.
- **Dropped, blocked on decisions that are not ThrottleIQ's:** SSO/linked accounts with Suggest.Bike (Suggest.Bike is a static site with no accounts or backend), discount links (no shop exists, nothing to discount), "tap to order Motul 10W-40" (would be a brand-sponsored nudge inside a rider app; and `OrderPartSheet` is a labelled DEMO that sends nothing).
- **If the owner decides to sell (see Suggest.Bike `judge.md`, same date):** the smallest real path is to point `OrderPartSheet` for oil at a Suggest.Bike page with the bike's oil grade (Suggest.Bike now publishes `engineOil` per bike where an owner's manual states it), not to build SSO. Map ThrottleIQ's free-text brand/model to Suggest.Bike ids first.
Score unchanged at 40%.

## Update (2026-10-27, agent round): review-round steps 2 and 4 checked, already done

Both agent steps from the 2026-10-19 "Next steps" were already on `main`; no code changed this round.
- **Step 2 (Google data revert):** `scripts/oneoff/revert_google_places.js` (2026-10-21 update above) deletes the 717 `system:gmaps-seed-dhaka` docs and, with `--from=<export>`, clears the Google-filled fields on the 80; dry run unless `--apply --backup=<file>`. `import_google_places.js` writes `verified: false` since `29b5bb5b`. Re-ran the revert and import unit tests: 12/12. **Not run against production**, not even the dry run: the owner decides (step 1).
- **Step 4 (§104.1):** fixed 2026-10-22 (`42aaefbf`, `issues_fixed.md` §104.1): `RidePlacesCache` reads each geohash cell once (again after 3 days), later refreshes pull only `updatedAt > lastPull`; 8 tests in `ride_places_cache_test.dart`. Not in a release yet. Still open there: `scripts/loadtest/quota_sim.js` models the old 25 km query.
- **Gate:** `check.sh --force` passed on `8a7e8359`. Nothing deployed.
Score unchanged at 40%.

## Update (2026-10-27, agent round 2): rules proven in the emulator

Everything ran in the Local Emulator Suite under `demo-throttleiq` (Homebrew JDK 21, cached emulator jars, no Google network). Nothing deployed, no real project touched. Commit `8953dba0`.
- **Suites:** Firestore rules **351/351** (was 328; +23 in `scripts/test/rules/access_matrix_rules.test.js`), RTDB rules 22/22, functions unit 12/12, functions emulator (`npm run test:emulator`, Firestore + RTDB) 15/15. No Storage rules exist (media is on Cloudinary).
- **New matrix:** signed-out access per collection (only `usernames`, `handleLinks`, `config` and shareable `liveSessions` gets open), owner vs other rider on every owner-only subcollection, email harvesting (account doc, 20-doc public-only search, follow graph), block gaps, the gmaps-seeded places, reviews, admin paths (claim, verified owner email, unverified email denied, config/stats unwritable even by admin). 8 of the 23 fail on the old rules.
- **Holes found and fixed in `firestore.rules`:** (1) `follows` was readable by any signed-in rider, so one unfiltered list returned the whole graph, private riders included. Now either end of an edge, or a viewer of one end's profile; lists must pin `followerUid`/`followeeUid` (every app query does). (2) `places` create had no key list: a rider could set `googlePlaceId` (the revert script then treats the place as gmaps-enriched), a fake Google rating (shown as Google's), or an off-host photo (viewer IP beacon). Now `PlaceModel` keys only, Google fields 0, photo from the rider's own `places/<uid>/` folder, text caps. (3) `reviews` create: key list, integer stars, 5000-char text, no image URLs. (4) A pre-§90.A11 block that left follow edges still showed a `mutual` profile and a followers-only garage; both now check the block.
- **Known gap, pinned by a test:** a blocked rider still reads the blocker's public rides and public profile (§83.18; a rule check would break the public feed query).
- **Also:** `test:rules` pointed at a deleted Android Studio JDK; it now uses `$JAVA_HOME` or Homebrew's. Rules and RTDB tests use `demo-` project ids. `check.sh` already runs the rules suite when rules change; it passed.
- **Owner, in order** (SECURITY.md runbook): finish step 3 (email migration, then Hosting for `privacy.html`), then step 9: `firebase deploy --only firestore:rules --project throttleiqfb` (no new build needed), then check one rider's follower count and one place add with a photo on a real build. Steps 4 to 6 (RTDB rules, Blaze, functions) unchanged.
Score unchanged at 40%.

## Update (2026-10-30, agent round): CodeQL re-check and emulator tests for function-written docs

- **CodeQL:** 0 open alerts on `main` `77749bd7` (issue #109, closed with the result). Nothing to fix.
- **Rules (`scripts/test/rules/function_written_shapes_rules.test.js`, 10 tests):** the sweep's "Not checked" item, docs Cloud Functions write through the Admin SDK, read back under client rules. An erased rider's DM (`deleted-rider` participant) stays readable to the other rider, closed to outsiders and to the old uid, and the uid can't be put back. Detached forum posts, replies and ride comments (`userId: ''`) stay readable and nobody can claim them. The automated toxicity report is admin-only, even for the rider it names; a hidden message can't be restored by either side. **Known gaps, pinned by tests:** (1) the remaining rider can still send into a room with a deleted rider (writes only, nobody reads them); (2) issues_open 109.10 confirmed: a creator can put a rider who blocked them in `invitedIds` (rules can't loop over added uids; the invite notification is still refused).
- **Functions emulator:** first tests for `onMessageCreate` (report holds the original text before the hide, whole-word match, retry files no duplicate, no-text message) and `reconcileRideIdentity` (spoof overwritten, no loop, counter bumps skip the profile read, nickname fallback, no profile / no userId left alone). Suite 26 → 35.
- **Not checked:** `badge-*.ts` (not deployed), crash-claim lease edge cases beyond the existing suite, anything on a device or against production. Nothing deployed.
Score unchanged at 40%.
