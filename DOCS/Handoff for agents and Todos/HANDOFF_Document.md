# ThrottleIQ — Handoff Document

_Last updated: 2026-10-25._

**Branches (2026-10-25):**
- `main` and `mayabi` are the only long-lived branches (plus `experimental`, which trails `main`). On 2026-10-25 every lane, `worktree-agent-*`, `fix/reads-104`, `integration/agent-rooms-2026-10-22` and `indriyo` branch was merged into `main` (or already in it) and deleted locally and on `origin`.
- `lane/f-wcag-contrast` (WCAG AA palette, owner item 24) was merged into `main` on the owner's instruction, 2026-10-25.
- Three Dependabot branches exist on `origin` (owner item 16).

**Indriyo** (digital rearview mirror / ADAS HUD, `app/lib/features/indriyo/`) lives in `main` since 2026-10-25. It is compiled out unless the build passes `--dart-define=INDRIYO=true` (`kIndriyoEnabled` in `indriyo_provider.dart`), because its HUD defaults to a simulation with fake collision alerts. Store builds never pass the flag; `active_ride_screen_test.dart` checks that the toggle is hidden. The HUD has never run on a device.

**`mayabi`** (Maya Ride integration kit, worktree `.claude/worktrees/mayabi`, 8 commits ahead, last merged `main` 2026-10-22). The kit is `mayabi/` (package `throttleiq_mayabi`), plus `functions/src/partner-api/` on our side. Owner decision 2026-10-17: never merged into `main`, and no cherry-picks into `main` without asking. Details and go-live steps are in the HANDOFF on that branch and in its `mayabi_todos.md`; the pilot is owner item 7.
- Keep it current by merging `main` into it (since 2026-10-22; no rebase, so no force-push), then `scripts/check.sh`, then `git push origin mayabi`. Expect conflicts in `app_en.arb`/`app_bn.arb`, `active_ride_screen.dart`, `firebase.json`, `functions/src/index.ts` and `scripts/check.sh`.
- After a merge that touches a vendored app file, copy it again into `mayabi/lib/src/vendor/` (`test/vendor_sync_test.dart` fails on drift).
- Releases from that branch: its `scripts/deploy.sh` tags `<tag>-<branch>` and publishes a non-latest prerelease, so `releases/latest` stays a `main` build.

## Start here

- **Quality gate:** `scripts/check.sh`, once per change set (CI and the pre-push hook run it too). Rules: `.agents/rules/qa-gate.md`.
- **Deploy and release:** the `deploy` skill / `scripts/deploy.sh` (`.agents/rules/deploy.md`). Firebase deploy order (rules, indexes, Hosting, functions): `SECURITY.md` "Owner runbooks".
- **Parallel agents:** one worktree per agent (`.agents/rules/parallel-agents.md`). Always-on tools: `.agents/rules/efficiency-tools.md`.
- **Open work:**
  - Developer issues: [`issues_open.md`](issues_open.md) (§N numbers never change; fixed ones move to `issues_fixed.md`).
  - Owner items (accounts, money, devices, decisions): [`needs_attention.md`](needs_attention.md) and the owner page `~/Everything/dev/housekeeping/owner_works_now.html` (ThrottleIQ block, items 0–36). "Owner item N" in this file means that page.
  - External review and score: `judge.md` (repo root).
- **What is built:** [`features.md`](features.md). Architecture: `DOCS/For Devs and Contributors/architecture/` (`arch.md`, `PRD.md`, `auto_tracking_plan.md`, `vehicle_state_engine.md`). Machine setup: `DOCS/For Devs and Contributors/guides/SETUP.md`.
- **Updating this file:** change "Current status" when it changes, and add a dated log entry at the top of "Recent sessions". Drop log entries a newcomer no longer needs; git keeps the history.

## Current status

### Release

- **Latest release:** `beta-v4.8.0` (`1.0.0-beta.4.8.0+30`, 2026-10-24) on GitHub, notes only. Android ships through Google Play only: the install page https://throttleiqfb.web.app/install/ has only the Play invite flow. No release carries an APK or AAB any more (all removed 2026-10-24).
- **`config/app.minBuild = 29`** is live (set 2026-10-18). Builds 27 and 28 see the update screen; builds 26 and older have no gate.
- **Old update link:** builds 27-29 link `https://blankframe.tech/ThrottleIQ/install`, which reaches the install page only through a redirect page in the landing-page repo (`throttle-iq/old-install-link.html`). Keep that page while those builds exist.
- **Google Play:** no public listing. The last build on record on the internal track is `1.0.0-beta.1+3` (2026-08-29, no update gate). Owner item 4.
- **iPhone:** no TestFlight or App Store build. The founder's iPhone gets `flutter run --release` builds signed by personal team `NJ4675FFUX`. Apple enrolment: owner item 21.

### On `main`, not released yet

Everything after `5a935e93` (the 4.7.1 bump):
- Ride ⋮ actions menu, minimize and a ride-in-progress strip (`cc84defc`, `features.md`).
- Speed colours on the full-screen ride map; live-share teardown also removes `/live_shares/{token}` (§99.4).
- Update-gate link points at Hosting (`f4642301`); the place detail screen hides the Google column (§105).
- Moderation: `public/community.html`, findable reports, rules-checked report snapshots with 90-day retention (`DOCS/General/Files for Stores/moderation_policy.md`).
- Chat anonymisation on account deletion (`functions/`, needs Blaze to run).
- App Check sideload gate (`d92f694e`). A build with it must ship through Google Play: once App Check is set up, a sideloaded Android release build blocks itself. Settle owner items 17 and 32 before the next release.
- Live-ride places from an on-device cache with `updatedAt > lastPull` pulls, 10 km around the rider every 5 km (was 25 km straight from Firestore; §104.1, `issues_fixed.md`).
- Quota outage mode (§104.6), the `dispose()` fix (`4b914c10`, §106), and the dark-mode map filter (`fb3b9297`).
- Feature tour v5: real-screen captures with pinned callouts, one accent colour, steps grouped by tab (`ea939409`, `features.md`).

- Critique 2026-10-27 fixes (`DOCS/critic oct27.md`, `issues_fixed.md` §115): counter, forum, block and shared-ride rules; sync after a ride ends and on resume; Edit Bike no longer undoes km; restored rides keep event counts; blocked riders hidden in comments and forums; forum follow fixed. Follow-ups 2026-10-28: shared and public route lines capped at 1,000 points, vote docs carry `uid`, `syncOdometer` fixed, `fake_cloud_firestore` tests. Owner steps: `needs_attention.md` (vote `uid` deploy and backfill before the release; cleanup after it becomes minBuild; phone checks; critique #19). Leftovers: `issues_open.md` §115.

Shipping these is owner item 26.

### Production backend

| Part | State |
|---|---|
| Firestore rules and indexes | Deployed 2026-10-27 from `5bbb53f1` (includes §104.1 places `updatedAt` and the 2026-10-27 follow-graph/places/reviews/legacy-blocks rules). **Email migration ran 2026-10-27:** 53/53 profile emails moved to `private/account`, 8 verified got an `emailLookup`, re-run reports 0 (owner item 2 done). The critique-fix rules and indexes (`7822003a`, `c3f9072c`) were deployed the same day (`SECURITY.md` step 10). **Not deployed:** the vote `uid` rules and `votes.uid` index (`7a3b2add`, 2026-10-28); they and the vote backfill must go out before the next release (`SECURITY.md` step 11, `needs_attention.md`). |
| Hosting | Deployed 2026-10-27 (`privacy.html` §5: email no longer visible to riders, effective date 27 Oct; earlier §1/§8/§9 and `community.html`). |
| Cloud Functions | Never deployed: the project is on Spark (owner item 3). So `onUserAccountDeleted`, `purgeOldGpsTracks`, the report-snapshot purge and chat moderation don't run. Account deletion is manual: `DOCS/For Devs and Contributors/guides/account_deletion_runbook.md`. |
| Quota alert | Live since 2026-10-21 (`scripts/monitoring/firestore-quota-alert.yaml`, policy `alertPolicies/13055223357814148266`). Production used 3-14% of daily reads in the week before. |
| `places` collection | 1,238 docs, including 717 from a Google Maps scrape (2026-10-19). Take-down decision: owner item 1 (`scripts/oneoff/revert_google_places.js`, ready, never run). |
| Realtime Database | No instance; `database.rules.json` denies everything. The dormant client code in `app/lib/core/realtime/` waits on the quota decision (owner item 3). |
| App Check | Nothing registered or enforced (owner items 17, 32; runbook `DOCS/For Devs and Contributors/guides/app_check.md`). |

### Built but never run on a real phone

Owner item 5 covers the core ride; the rest stays here until someone checks it. Simulator E2E (`integration_test/e2e_test.dart`) passes 4/4 but mostly proves launch and teardown.
- **Recording:**
  - A manual ride of 10+ min with the screen locked.
  - Swipe the app away mid-ride: the restored ride must include the missing minutes (B5). Repeat on a Xiaomi or realme with default settings (OEM guide).
  - Ride-start permission flow (B4); minimize and the ride-in-progress strip; the phone-placement pill.
  - Route navigation records the ride (§78.21): turn banner at real corners, off-route at 100 m, closing the banner leaves recording on.
  - GPS-speed fallback (§49), gyro heading (§78.12), and the jam buttons "I'm in a jam" / "Jam released".
- **Crash detection (shadow mode):** `ImpactDetector` at 50 Hz on a mount and in a pocket, the battery cost of 50 Hz (§78.1), and the "Did you fall?" card.
- **Offline:** in airplane mode, end a ride (must finish at once), share with a photo (must return quickly and post once when back online), and kill and reopen mid-ride (§25, §26). The quota strip has only been seen in tests.
- **Auto-tracking (§93.3, §37):** stands down after a manual Start; a jam-split commute counts as one ride; the 9 pm digest; the active-hours window. Note battery % over a day (101.C6).
- **Live share:** in traffic the viewer must never show "updates delayed"; teardown after a kill.
- **Two accounts, two phones:**
  - Group ride: invite, join by code, the "joined" notification, stale dots.
  - Push-to-talk voice notes through a Bluetooth headset.
  - Chat: both directions, the blocked sender, report from chat, the deleted-rider view.
  - The Riding Now strip, and bike visibility tiers.
- **Sync:** two phones on one account (last-writer-wins, UTC ride times); the v29 schema upgrade over a real install; GPS trails restored after a reinstall; Google sign-in.
- **Places:** 1,238 places render in Dhaka, the full-screen map, the carousel against the bottom nav, and the GPS-off flows.
- **Maintenance redesign (§95.1)** and its notifications.
- **Widgets:** `home_widget` 0.10 on both launchers, and the iOS App Group setup (§98).
- **Themes:** both themes across real screens, plus the dark map filter.
- **Other:**
  - A test crash reaching the Crashlytics console.
  - SafeQR scanned off real paper.
  - Bangla on a real device.
  - Account deletion with re-auth.
  - The App Check gate on a sideloaded release build (owner item 32).
- **Vehicle State Engine tuning:** see `vehicle_state_engine.md`.

### Before launch (developer side)

- §104.1: nearby places re-read every 5 km, now 2.4× more reads after the Google import. Fix before launch.
- §104.2-104.4: group-ride reads grow with N², and feed vote hydration.
- §103.2-103.5: shared-ride card and history delete follow-ups.
- §110: leftovers from this handoff's old to-do list.

## Decisions in force

| Area | Decision |
|---|---|
| Firebase plan | Spark until the owner decides (owner item 3). Functions, TTL and full deletion wait on Blaze. |
| Crash detection | Shadow mode only: nothing alerts anyone. Keep it off until it is calibrated on real rides. |
| Multi-device edits | Last-writer-wins (founder C4, 2026-10-14). |
| Detected trips | Add their km to the active bike's odometer (§93.1, 2026-10-07). |
| Deleting a bike | Archives it (§102). |
| Bangla dates | English-style dates in the Bangla font, Western digits (§102). |
| Analytics | On by default, disclosed opt-out (owner item 14, 2026-10-22). |
| Deleted rider's chats | Anonymised, not deleted (owner item 13, 2026-10-21). |
| Moderation | Reports plus manual admin review within 24 h (owner item 15). |
| Google data in Places | Ratings dropped (2026-10-19). Keeping or removing the scraped places: owner item 1. |
| First Play submission | Keeps background location and the full-screen intent, with declarations (owner item 8, 2026-10-21). |
| App Check | Enforce on Firestore once riders install from Play (owner item 17). |
| Apple Developer Program | Enrol (owner item 21, 2026-10-21). |
| Map tiles | Thunderforest `atlas` in release builds; the key is in gitignored `secret/tiles.env`, which `scripts/deploy.sh` reads. Free tier: 150k tiles a month. |
| Impact records | Cloud `impactEvents` copies outlive a local ride delete (2026-10-15 merge). |
| `mayabi` | Never merged into `main` (2026-10-17). |
| Outside contributions | Accepted under TSAL v1.1 §1A (fork only to open a PR) plus `CLA.md`, signed by PR comment via `.github/workflows/cla.yml`; signatures on branch `cla-signatures` (keep it unprotected). PRs go to `main` (2026-10-28). |

## Key facts

| Thing | Value |
|---|---|
| Firebase project | `throttleiqfb` (asia-south1), Spark plan |
| App id | `com.bft.throttleiq` (Android and iOS) |
| Version, schema | `1.0.0-beta.4.8.0+30`; local DB schema v29 (`database_helper.dart`) |
| Tests | 2026-10-21/22: about 2,300 Flutter tests, 315 rules tests, functions unit and emulator suites. All through `scripts/check.sh`. |
| File storage | Cloudinary, cloud `vjvcigkt`, unsigned preset `throttleiq_unsigned` (limits: owner item 11). No Firebase Storage. |
| Signing | `throttleiq-release.keystore` (repo root, gitignored, backed up 2026-09-21) and `app/android/key.properties`. Moving it out of the Drive-synced repo: owner item 9. |
| Accounts | GCP project owner: `blankframe.technologies@gmail.com`. In-app admin: `the.abraar.rar@gmail.com` (`admin` claim, or the email fallback in `firestore.rules`, §110.4). Privacy and deletion contact: hello@blankframe.tech. |
| Play publishing | Service account `throttleiq-play-publisher` in GCP project `throttle-iq-gcc1`; key in gitignored `secrets/`. |
| Founder's iPhone | udid `00008120-001E5D190A85A01E` |
| Privacy policy | https://throttleiqfb.web.app/privacy.html |
| Judgement calls | `DOCS/For Devs and Contributors/architecture/assumptions.md` |
| Offline writes | A write the rider asked for goes through `app/lib/core/cloud/outbox_service.dart`, never a bare `await` on Firestore: an awaited write with no connection never completes (and doesn't throw). Optional telemetry uses a best-effort write with a timeout. |
| Android version codes | The AAB carries the pubspec build number. Bump it for every release; Play rejects a reused code. |
| Release assets | None. `deploy.sh` builds the AAB locally for a manual Play Console upload; GitHub releases hold notes and the install link only. |

## Operational notes

- **Firebase CLI:** use `npx firebase-tools@15` (the standalone binary's npm crashes in predeploy). Never run a bare `firebase deploy`; name the targets.
- **Emulator port:** port 8080 is taken on this Mac. Point `CHECK_FIREBASE_CONFIG` at a copy of `firebase.json` with the Firestore emulator on 8181; the rules tests read `FIRESTORE_EMULATOR_HOST`.
- **Gate base:** when `origin/main` carries another session's rules or functions changes, run `scripts/check.sh --base <fork point>` so the gate doesn't run suites this machine can't.
- **Index check:** Firestore adds an implicit `__name__` field to every composite index. Strip it before diffing the live indexes against `firestore.indexes.json`. Never clear the undeclared ones with `--force` (§84).
- **Admin scripts:** they need throttleiqfb credentials (`GOOGLE_APPLICATION_CREDENTIALS`, or `gcloud auth application-default login` as the GCP owner, then `set-quota-project throttleiqfb`). gcloud's default account here is the Play-publisher service account; use `--account` for the owner. How to run each script: `scripts/README.md`.
- **iOS install:**
  - `flutter run --release -d <udid>` works over USB; skip wireless.
  - If its install step fails, build with `flutter build ios --release`, then `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app` and `xcrun devicectl device process launch --device <udid> com.bft.throttleiq`.
  - An ad-hoc-signed framework (`codesign -dvv` shows `TeamIdentifier=not set`) means a stale build: `flutter clean && flutter pub get`.
  - Personal-team profiles expire; rebuild to re-sign.
  - `flutter devices` may miss the phone; use `--device-timeout 30`.
- **Don't kill other sessions' processes:** scope any kill to `pkill -f "flutter run -d <udid>"`, and never `xcrun simctl shutdown all` (it broke another agent's E2E run on 2026-10-18).
- **Shared working tree:** one session commits. Never `git add -A`, `dart format lib` or `git checkout -- app` in a tree another session uses.
- **Screen content on a physical iPhone:** there is no screenshot tool. Use the VM service: `curl "$VM_URI/getVM"` for the isolate id, then `curl "$VM_URI/ext.flutter.debugDumpApp?isolateId=$ID"`.
- **Text scale:** the test iPhone runs at `textScaler` 1.1176 with bold text; widget tests run at 1.0.
- **JDK:** Android Studio is not installed. Homebrew `openjdk@21` is, with `JAVA_HOME` set in `~/.zshrc` (§89). Use `$JAVA_HOME/bin/keytool`; `/usr/bin/keytool` is Apple's stub and prints an empty fingerprint.
- **SVG text:** `rsvg-convert` and `flutter_svg` drop `<textPath>` text silently. Place curved text glyph by glyph (see `app/assets/icons/throttleiq-icon-dark.svg`) and rasterise to check.
- **Play Console API:**
  - Uploads use the `/upload/androidpublisher/v3/...` path.
  - After a failed upload, start a new edit; the old one is deleted.
  - `gcloud auth print-access-token` needs `--scopes=https://www.googleapis.com/auth/androidpublisher`.
  - Testers can only be added in the Console UI (the API takes only a Google Group). The app category and the content rating are UI-only too.
  - The Data safety API (`applications.dataSafety`) rejected the CSV for a missing `PSL_SUPPORTED_ACCOUNT_CREATION_METHODS` field. Export the Console's CSV first (owner item 4).
- **Claude tooling:** the Artifact tool cannot delete a published page (the owner deletes it on claude.ai). The `logo-creator` skill needs `GEMINI_API_KEY`, `REMOVE_BG_API_KEY` and `RECRAFT_API_KEY`, none of them set.

## Known limitations

- **Crash detection alerts nobody.** `SensorConstants.crashAlertsEnabled` is `false`; the thresholds are uncalibrated; the crash Cloud Function has no SMS or email provider and has never been deployed. No copy may claim otherwise (§78.1).
- **Navigation is geometric:** it follows a saved route's polyline, with no street names or rerouting. No routing engine exists (`assumptions.md`).
- **Nearby places** are fetched for a 25 km radius and filtered in memory; `GeohashUtil.getNeighbors` is not used by any query (§104.1).
- **Spark quota:** reads run out at about 18 daily riders (§104). Outage mode softens it; it doesn't raise the limit.
- **Auto-tracking on iOS** doesn't survive a force-quit (a platform limit). Android OEM battery managers can still kill it; riders get a one-time guide (§96.1).
- **Module choices** ("Your ThrottleIQ") are stored on the device, not synced.
- **No in-app admin UI:** moderation runs on a console query (`DOCS/General/Files for Stores/moderation_policy.md`).
- **No paid tier,** and no revenue model.

## Recent sessions (newest first)

### 2026-10-28

- **Opened to outside contributors (on `main`):** LICENSE → TSAL v1.1 with §1A (fork/modify only to send a PR), new `CLA.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1), `.github/ISSUE_TEMPLATE/` (bug, feature, translation; security → private advisory), PR template, `.github/workflows/cla.yml` (CLA Assistant Lite, pinned SHA). README Contributing/License updated; it used to say branch from `experimental`, which is 87 commits behind `main`. On GitHub: label `translation`, branch `cla-signatures`, starter issues #20–#24 (#25 closed, already fixed by `c4243606`). Discussions on and topics set (via blankframe-tech, same day). Owner: lawyer review, outreach (owner items 53–54).
- **Security scanning in CI (uncommitted):** new `.github/workflows/security.yml` (push, PR, weekly Monday 03:00 UTC): `secrets` runs gitleaks (`.gitleaks.toml` = default rules + the four Firebase client API keys, exact match only), `dependencies` runs osv-scanner on `app/pubspec.lock` and `functions/package-lock.json`. Neither has run yet (local download blocked); `npm audit` on functions: 0. First CI run may go red on an existing pub advisory. Owner: make both jobs required + turn on GitHub secret scanning (owner item 16).
- **Critic oct27 #1–3 verified fixed** (`7822003a`): rules suite 387/387 locally. `.agents/rules/qa-gate.md` rule 4 now requires deny (attacker) tests with every `firestore.rules` change. Enabling secret scanning via `gh api` returned 404 (no admin on this token), so it stays with the owner.
- **Left for the owner (nothing agent-only remains):** owner items #55 (OK to commit and push the security scans), #56 (release, then raise `minBuild`; unblocks the §115 cleanup: comment-delete clause, polyline cap, vote `uid`), #57 (park the RTDB code and indriyo off `main`?), plus #16 (required checks, secret scanning; needs the admin account), #17 (App Check) and #3 (Blaze).

### 2026-10-25

- **Password link /r/@handle (uncommitted, not deployed):** the Settings toggle now asks for a password (8+ chars); every in-app ride auto-shares to `/r/<handle>`; the viewer asks for the password and shows the last ride's end point after the ride. Doc `handleLinks/{sha256("throttleiq-r:uid:password")}`; `livePointers/{uid}` is owner-only now; erasure deletes `handleLinks`. check.sh green apart from the rules step (port 8080), which passed on 8181 (326/326); functions emulator 15/15. Needs rules + hosting deploy and an app build. Marketing brief + poster: `Handoffs for Non Coding Agents/marketing/lost_phone_password_link.DRAFT.md`, `posters/batch_four/`. Follow-ups in issues_open §112.
- **Rider profile showcase (uncommitted, 2026-10-25; release build installed on the iPhone, not yet tapped through):** `/profile/:uid` now shows longest ride, day streak and earned badges, and the rider's shared rides as feed cards (`SharedRideFeedCard`, extracted from the feed) with sort chips and up to 5 pinned rides (`pinnedRideIds`, pin from the card menu on your own profile). Visibility: public, plus followers/mutual by the live follow graph (`riderSharedRidesProvider`). **`firestore.rules` changed** (pin cap 5, bounds on the two new `publicStats` fields): needs a rules deploy; the app works before it (the old rules don't reject the new fields). Tests: `profile_rides_test.dart`, `rider_shared_rides_provider_test.dart`, `badges_test.dart`, rules tests in `firestore_rules.test.js`.
- **Build 1.0.0-beta.4.10.0 (+32), 2026-10-25:** AAB built at `4b0687b6` (signed with the upload key `8542b8ad…`) for a manual Play upload; not uploaded yet. Adds per-ride fuel cost (`ride_fuel.dart`) and the brand/model dropdown fix (§114). Release build installed and launched on the iPhone. No GitHub release or tag yet.
- **Build 1.0.0-beta.4.11.0 (+33), 2026-10-28:** AAB built at `57a8f454` (upload key `8542b8ad…`) for a manual Play upload; supersedes +32. Adds the rider profile showcase, the oct27 critique fixes and WCAG contrast. Release build installed on the iPhone. No GitHub release or tag yet.
- **Release beta-v4.9.0 (+31):** rules + hosting deployed; functions wait on Blaze (§112). Installed on the iPhone (launch failed only because the phone was locked). GitHub release tagged at `2c0e2661`. `deploy.sh` no longer builds any Android artifact (no `--skip-android`): Android ships only through Play, uploaded by hand.
- **On `main`, `check.sh` green:** tour steps lay out screenshot left and text right with no scrolling; Highway Radar banner and map pins removed; the Places tab now shares the on-device places cache, with **Settings → Offline places → Clear**; new forum post page (`/forums/new`): write first, then **Share** picks All Riders plus up to 5 groups (`alsoIn`, `collectionGroup('posts')`). Details in `features.md`. Rules and indexes deployed 2026-10-25; owner item 50 is confirming the `posts` indexes are Enabled. Not checked on a device.
- **check.sh with port 8080 taken:** another local app held 8080, so the rules emulator could not start. `CHECK_FIREBASE_CONFIG` pointing at a copy of `firebase.json` with other emulator ports (and absolute rules/index paths) works.

### 2026-10-24

- **Release `beta-v4.8.0` (+30):** `scripts/deploy.sh --skip-ios` from `007c3593`, shipping everything merged since `beta-v4.7.1` (quota outage mode, moderation, places cache, tour v5, ride actions menu, the 2026-10-22 agent-room lanes). The AAB was handed to the owner for a Play Console upload. `config/app.minBuild` stays 29.
- **APKs retired:** every APK/AAB asset deleted from GitHub releases, every release body now opens with the Play install link, the APK card removed from `public/install/index.html`, and `deploy.sh` builds only the AAB and attaches nothing.

### 2026-10-22 (agent rooms run): eight lanes from `DOCS/agent_rooms/`, merged and pushed

- Coordinator branch `integration/agent-rooms-2026-10-22`, one worktree per lane, a fresh reviewer per lane, `check.sh` once after the last merge; `main` fast-forwarded to `a0bf4f4f`. Nothing deployed, nothing on a device.
- Code: `fix/reads-104` merged, keeping main's §104.1 places cache (§104.2 interval, §104.3 vote skip, §104.6 screen-write `ackOrQueued`); §80 step 1 (no legacy likes sweep); `crashEvents.createdAt` floored to the UTC hour; functions: bounded purges with a time budget, retry-safe erasure, report-first moderation (`ba11d594`); `reportSilently` plus a bare-`catch (_)` ratchet at 54 (§83.14); 21 widget tests (§83.28) that found and fixed the Sync issues Retry message.
- Branches: `main` merged into `mayabi` and `indriyo` (no rebase), pushed. WCAG palette on `lane/f-wcag-contrast`, not merged.
- Drafts for the owner (all marked DRAFT): `DOCS/agent_rooms/drafts/` (deploy/test rules, §84 index audit, prize plan, decision cards for the Maps data and Blaze), signed-upload design, `public/.terms.DRAFT.html`, Data Safety CSV and review, forum starter posts, SafeSpot flyer, Play reviewer video script. Maya meeting prep is local only (`DOCS/General/partnerships/`).
- Owner page items 46-50 added (likes steps 2-3, privacy.html gaps, Verified vs SafeSpot, Maya pricing in public, CodeQL check). Room to-dos carry dated status lines.

### 2026-10-22 (tour): feature tour shows the real screens

- Each step shows a capture of its real screen (`app/assets/images/tour_*.jpg`, 456 KB, from the dark UI screenshots) with the numbered callouts pinned on it. The schematic spotlight and the miniature nav bar are gone.
- One accent (`tourAccent`: primary, body ink where primary fails 3:1) instead of five per-step colours.
- Order walks the app once: Record, cockpit, Rides, Garage, Profile, Auto tracking, Maintenance, Places, Social. A manifest test fails if a tab comes up twice. `kOnboardingManifestVersion` 5.
- Limits: the captures are dark mode only, so light-mode riders see dark screens; with ride tracking off or forums-only the captures still show the full app's nav and tabs. Recapture a step when its screen's layout changes and re-check its `SlidePointer.at` pins.

### 2026-10-22 (engineering tasks): Gradle wrapper 8.14 & GPX export UTC fix

- **§110.3 fixed:** Upgraded Gradle wrapper to 8.14 (`gradle-8.14-all.zip`) in `app/android/gradle/wrapper/gradle-wrapper.properties`. Verified with `./gradlew --version` and `./gradlew tasks --dry-run`.
- **§109.3 fixed:** GPX and JSON exports write UTC ISO-8601 strings (`.toUtc().toIso8601String()`) for ride start/end time in `ride_summary_screen.dart` and normalized in `ExportService.generateGPX`, eliminating Strava timezone skew. Added unit tests in `export_service_test.dart` (4 passing).

### 2026-10-22 (later): production deploy checked; places cache; Data Safety drafts

- **Deploy:** the owner ran `firebase deploy --only firestore:rules,firestore:indexes,hosting` (no index-deletion prompt). Still open from `SECURITY.md` step 3: the email migration, then `privacy.html` §5 and Hosting again. Cloud Functions still wait on Blaze.
- **§104.1 fixed:** `RidePlacesCache` keeps live-ride places on the phone and pulls only `updatedAt > lastPull`; whole geohash cells are re-read every 3 days. Radius 25 → 10 km, still every 5 km. New rule: places `updatedAt` must equal `request.time`. Details and limits in `issues_fixed.md` §104.1.
- **§110.5 fixed:** the Data Safety CSV and notes cover impact records and the crash research copy. The owner fills the Play form (needs_attention).

### 2026-10-22: DOCS clean-up; branches retired and synced; no app change

- **Layout:** `DOCS/` has five folders (map: `DOCS/README.md`). The handoff folder holds five living files: this one, `features.md`, `issues_open.md`, `issues_fixed.md`, `needs_attention.md`.
- **Retired** (all items checked: done, obsolete, tracked, or moved): `BIGGG_JOBB.md`, `DEBT_FIX_PLAN.md`, `uiux_critique.md`, `websockets_todo.md`, `plan_ride_minimize_menu.md`, `todo_now_antigravity.md` (leftovers §107); `grillings/` and `issues_solved.md` (§108); `CrtiQue_Oct14.md`, `CrtiQue_Oct15.md` (§109); stale HANDOFF to-dos (§110). Old text: `git show 3ebbd21d:"DOCS/Handoff for agents and Todos/<file>"`. Code comments keep their `grill §N` and `CrtiQue_Oct14 B7` labels.
- **Pruned:** `issues_open.md` holds only open work (fixed and obsolete sections moved to `issues_fixed.md` with their numbers; next free §111). `features.md` and this file were rewritten to the current state. `needs_attention.md` lists only open owner items, numbered as on the owner page.
- **Marketing:** the 13 lead notes, the critique, Hooked analysis and name list are merged into `marketing/marketing.md` and `marketing/marketing_kit.md`; the deck outline is `marketing/pitch_deck.md`. The Facebook cover now says Live Share, not Crash Detection.
- **Posters:** `posters/batch_two/` holds 49 posters from `batch_one/` that used old skins, redone in Carbon Mono or Calming light (mapping in `posters/generator_helper_files/README.md`). The 12 already on brand are only in `batch_one/`.
- **Branches:** `feat/quota-outage` merged (`c751968e`); it, `feat/crash-shadow-mode` and `data/apify-dhaka-places` deleted; `experimental` = `main`. `indriyo` and `mayabi` got the same `DOCS/` (a docs-only commit each; code not merged).

### 2026-10-21

- **Scripts layout (`03a209b5`, committed 2026-10-22):** the one-off admin scripts are in `scripts/oneoff/`. Run them as `node oneoff/<name>.js` from `scripts/`; the `npm run` names are unchanged. `check.sh`, `deploy.sh`, `crash_stats.js`, `export_impact_events.js` and `ste_sentence_length.js` stay in `scripts/` (`publish_release.sh` was deleted 2026-10-27, critic #20).
- **Quota outage mode (§104.6), merged 2026-10-22, not released, not on a device:**
  - When the Spark daily quota runs out, sync and the outbox pause, riders see `OverQuotaBar`, and sync resumes after the reset.
  - The owner email alert is live: re-apply steps in `scripts/README.md` "Firestore daily quota".
  - Rehearsal on a throwaway project: `DOCS/Handoff for agents and Todos/load_test/quota-rehearsal-2026-10-21.md`. `count()` and transactions fail once reads run out, which triggers the pause; gets and listeners keep working; nothing is lost.
  - E2E 4/4 on an iPhone 17 simulator with `4b914c10`.
  - Left: the release (owner item 26) and the Bangla review of `overQuotaBar` and `errTooManyRequests` (owner item 28).
- **Moderation, deletion and App Check (details: `judge.md`, 2026-10-21 updates), pushed, nothing deployed:**
  - Written policy and `community.html`.
  - Reports store the document path and a rules-checked snapshot, with 90-day retention.
  - A deleted rider's side of each chat is anonymised.
  - The App Check sideload gate.
  - The `RideRecordingNotifier.dispose()` fix (§106).
  - A dry-run revert script for the Google Maps import.
  - The local `test` branch merged (its dark-mode map filter kept) and deleted.
  - `DOCS/General/screenshots_ui` untracked (558 MB, backed up outside git).
- **Facebook bike-group research:** 375 posts from three public groups for $2.65 (the Apify limit is now $10 a month). Write-up: `DOCS/old/apify/2026-10-21_fb_bike_groups.md`; lessons in `DOCS/old/apify/README.md` (raw data gitignored).
  - Top topic: the BRTA front number-plate rule, deadline 2026-11-15 (owner item 35).
  - The Apify token is in `~/.secrets/throttleiq/apify_token`; rotate it (owner item 9).

### 2026-10-19: Google Maps gap-fill in production; Google ratings dropped (§105)

- **Data:** `places` went from 521 to 1,238: 717 new Dhaka fuel, garage and parts places (`createdBy: 'system:gmaps-seed-dhaka'`, keyed by `googlePlaceId`), 80 enriched, and all 69 Google ratings set to 0 (no undo).
  - The importer wrote `verified: true` on the 717.
  - `judge.md` 2026-10-19 explains the Google terms risk. Owner item 1 decides; the export is at `~/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json`.
- **App:** place detail hides the Google column when a place has none. `scripts/oneoff/import_google_places.js` replaced the hand-written ratings script.
- **Read cost:** §104.1 now reads 2.4× as many places per fetch.

### 2026-10-16 and 2026-10-17

- **Release `beta-v4.7.1` (+29):** the live-share write gate, the full-screen map controls fix, the rules warning fix and the visibility backfill script.
- **Ride actions menu, minimize, ride-in-progress strip (`cc84defc`):** `features.md` "⋮ ride actions menu". Not released.
- **§99.4:** the queued live-share teardown also removes `/live_shares/{token}`.

### 2026-10-15

- **Releases `beta-v4.6.0` (+27) and `beta-v4.7.0` (+28):** `scripts/deploy.sh --skip-ios`, then `flutter run --release` to the iPhone separately. Neither was uploaded to Play.
- **Every fix branch merged (`1349db5`):** all `fix/oct14-tiq-*`, `fix/oct15-throttleiq`, `oct14-int` and `merge/oct15-origin-main`, plus `feat/crash-shadow-mode`. Three sessions shared one tree that day, which is where the "one session commits" rule comes from.
- **Live-share writes (`ce82025`):** `shouldWriteLiveSession` (`live_session_coordinator.dart`) writes `liveSessions/{token}` only on a new token, a status change, 100 m of movement or 15 s since the last write. A stopped rider writes every 20 s, inside the viewer's 30 s "updates delayed" warning. The Spark ceiling rose from about 55 to at most 111 live-share hours a day. The real fix is owner item 3.
- **Spark load test:** `scripts/loadtest/quota_sim.js` (`npm run loadtest:quota`). Reads run out at about 18 daily riders. Report: `DOCS/Handoff for agents and Todos/load_test/load-test-2026-10-15.md`; issues §104.
- **Agent round:**
  - PRD style check closed (PRD §13).
  - The `publicStatsValid` compile warning is gone; `scripts/test/rules/rules_compile.test.js` fails on any compiler issue.
  - `scripts/oneoff/backfill_users_visibility.js` is written but not run (owner item 2).
- **Merge of `origin/main` into the fix round:**
  - Schema v29: both sides had a v28 (`schema_v29_merge_test.dart`).
  - `crashAlertsEnabled` gates the crash notification and overlay.
  - With Ride tracking off, nothing reads location.
  - `BikeDao.delete` removes the bike's impact rows.
  - `privacy.html` describes impact records and the opt-in research copy.
- **Shadow-mode crash detection:**
  - Built: a tiered `ImpactDetector`, 50 Hz sensors, `impact_events` with 12 s sensor windows, the phone-placement pill, the "Did you fall?" card, "Report a crash", private `impactEvents` sync and opt-in `crashEvents`.
  - No alert goes out. Open items: §78.1.
  - The 2026-10-14 crash report is in `DOCS/General/CRASH TESTING/`, with a public write-up at blankframe.tech/throttleiq/crash/1.
- **Re-critique fixes (CrtiQue_Oct15 N1-N5):**
  - Android version codes follow the pubspec build number.
  - Email lookups need `email_verified`.
  - The install page says there is no iPhone build and makes no tracking claims.
  - `AutoTrackingService.start()` asks for no permissions unless `enable()` passes `askForMissingPermissions`.
- **Modules:** Settings → Your ThrottleIQ (Community: Everything / Forums only / Off; Places & routes; Ride tracking). The feature tour follows the modules. Details: `features.md`.
- **Ride recording B4, B5, B12:**
  - A ride start asks only for while-in-use location. The background-location disclosure moved to the auto-tracking switch.
  - On Android the ride runs in the `flutter_foreground_task` service. After 20 s without a UI heartbeat the service saves the fixes. A dead service posts "Recording stopped, tap to resume".
  - A one-time OEM battery guide (Xiaomi/Redmi/POCO, OPPO, realme, vivo/iQOO).
  - `RideDao.setStatus`; `GpsDropLog` goes into bug reports; the IMU g bar stays hidden until the axis is calibrated.

### 2026-10-14

- **Two themes:** Calming (light, default) and Carbon Mono (dark); Settings › Appearance is System / Dark / Light. Removed: the 7 colour families, the Boxy vibe, the colour picker, the 28-combination UI tour and its PDF generator, and slide-to-start. A rider's saved brightness picks the nearest theme.
- **Sync, schema v28:**
  - `updated_at` (UTC) and touch triggers on rides, bikes and maintenance logs; ride times rewritten to UTC.
  - Last-writer-wins through read-then-write transactions.
  - Not covered: deletions, a wrong phone clock, and bike totals (whole-row LWW).
  - Details: `arch.md` §5 "Multi-device conflicts".
- **Shell and claims:**
  - The `config/app.minBuild` forced-update gate (`app_update_gate.dart`, fails open).
  - The delete dialog and `privacy.html` §9 send deletion requests to hello@blankframe.tech (handled by hand within 30 days).
  - Crash and SOS claims removed from the listing and pitch.
  - `PrivacyInfo.xcprivacy` in Runner; split-per-ABI APKs.
- **Cut:** challenges, top-speed badges, the badge-rarity UI, the RTDB group-ride client (`4cb96a8f`), `storage.rules` and the old poster scripts.
  - The retired speed badge ids stay in `firestore.rules` and `badge-catalog.ts`, because old builds still award them.
  - `seed_police_checkposts.js` and `_v2.js` stay: v1-v3 seed different batches.
- **Rules B1-B3, B9:**
  - Email moved to `users/{uid}/private/account`; find-by-email goes through `emailLookup/{sha256}`.
  - `/users` lists need `limit <= 20`; block checks on chats, notifications and follows.
  - `onUserAccountDeleted` also removes chats and the email lookup; `purgeOldGpsTracks` keeps 12 months.
  - RTDB rules deny everything; `config/{doc}` is world-readable.
  - `scripts/oneoff/migrate_emails_private.js` has not been run (owner item 2).

### 2026-10-13

- Five Dependabot PRs merged as one tested set. Not checked on a device: the home-screen widgets on `home_widget` 0.10.
- `indriyo` merged `main` (it was 272 commits behind) and its HUD was adapted to `context.palette`.

## Ideas not built

From competitor research and founder sessions; none is scheduled. Monetisation and launch phases: `issues_open.md` §92.
- Weekly riding report or digest (§92.B8), and a shareable "Year in Review" card.
- Ride replay: animated playback with speed and lean overlays on the summary map.
- Curvy-route planner with voice navigation (needs a routing engine, §92.A6), and a scoped-down multi-stop trip planner built from the rider's own past routes.
- "Arrived safely" alerts for live-share viewers (a geofence on the live session).
- Rider-dropped hazard pins (pothole, gravel, flood) that expire after 24-48 h. Today the ride menu can only drop a temporary police checkpoint.
- Crash escalation ladder (notify contacts, then SMS with location if nobody acknowledges). Needs Blaze, an SMS provider and calibrated detection.
- Clubs with events and RSVP; smoothness-based leaderboards (not speed).
- Auto-pause in traffic. Jam time is already reported, but the ride keeps recording.
- iOS start/stop widget: needs App Intents (iOS 17+); today's iOS widgets only deep-link.
- ThrottleIQ Partner: one place for a spouse or parent to follow several riders. A second product with its own consent model; not before real users.
- Seasonal or limited badges, a shareable badge card, club badges. The badge completion reward ("all badges = engine oil") is an open owner call (owner item 23).
- Places: offline cache, closed-place reports, live confirmations, route search. A home-screen widget update was requested 2026-10-15 but never specified.
- Resale PDF with ride history and score (the service-record half exists).

### Reference: the paid background-location plugin

Auto-tracking replaced `flutter_background_geolocation` (paid) with `flutter_activity_recognition` + `flutter_foreground_task` (free) on 2026-08-28 (`issues_fixed.md` §50). The old code is in `DOCS/old/background_geolocation/`. Revisit only if beta riders lose detected rides to the gaps below.

| | Paid plugin | Free stand-in (current) |
|---|---|---|
| Cost | One-time per app id, quote from transistorsoft | $0 |
| Android, swiped from recents | Survives | Survives (foreground service) |
| Android OEM battery killers | Vendor-tuned per OEM | Battery-optimisation prompt and the OEM guide only |
| iOS, user force-quit | Stops (platform limit) | Stops |
| iOS, killed by the OS for memory | Relaunched by significant-location-change | Gone until the next manual open |
| Active hours | Native start/stop | Checked at trip start only; a trip running at the window's end finishes |
| Maintenance | One vendor dependency | Two free dependencies (`flutter_activity_recognition` was last published about 24 months before 2026-08-28) |
