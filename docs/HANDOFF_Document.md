# ThrottleIQ — Handoff Document

_Last updated: 2026-08-29 · Branch: `main`_

This is the single living handoff doc for the project: current status, known
limitations, the near-term to-do list, the longer-term feature backlog, and
the Vehicle State Engine architecture/roadmap. Update it (don't fork a new
doc) whenever status changes — see `.claude/settings.json` for the hook that
prompts this after every work session. Feature-by-feature UI detail lives in
`features.md`; tracked defects live in `Issues.md`; see `docs/README.md` for
the full map of what lives where.

**Contents**
- [Part 1 — Status & Handoff](#part-1--status--handoff)
- [Part 2 — Feature Backlog & Ideas](#part-2--feature-backlog--ideas)
- [Part 3 — Vehicle State Engine: Architecture & Roadmap](#part-3--vehicle-state-engine-architecture--roadmap)

---

## Part 1 — Status & Handoff

### Current status

Pre-launch, at **`1.0.0-beta.1+1`**, tagged
[`beta-v1`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v1)
(currently at commit `ea12fc2`). No App Store submission exists yet. **Play
Console progress (2026-08-28):** developer account verified as an individual
("Abrar Masud Nafiz"), app created under package `com.bft.throttleiq`, and
the first release AAB built locally (`flutter build appbundle --release` →
`app/build/app/outputs/bundle/release/app-release.aab`, versionCode 1) for
upload to the Internal testing track — confirm in Play Console whether the
upload/release creation was completed. **Google Cloud project
`throttle-iq-gcc1`** (project number `439350192148`) exists and is linked for
Play Console API access, set up 2026-08-29 to enable automated releases
(service account + Google Play Developer API, e.g. via `fastlane supply` or
Gradle Play Publisher). As of 2026-08-29: the Play Android Developer API is
enabled and a `throttleiq-play-publisher` service account exists with a JSON
key downloaded to `secrets/` (gitignored the same day — `/secrets/` and
`*.json.key` added to `.gitignore` so the key can't be accidentally
committed). **API access verified working 2026-08-29** — the service account
was invited under Play Console's **Users and permissions** page (there's no
longer a separate "API access" page; it's invited by pasting its
`...@throttle-iq-gcc1.iam.gserviceaccount.com` email like a human user, then
granted per-app "Release to testing tracks" only) and confirmed end-to-end by
creating and deleting a real Android Publisher API edit for
`com.bft.throttleiq`. Reuse note: `gcloud auth print-access-token` needs
`--scopes=https://www.googleapis.com/auth/androidpublisher` explicitly — the
default `cloud-platform` scope alone 403s against this API. **Still
pending:** wiring up an actual CLI publishing tool (fastlane `supply` or
Gradle Play Publisher). Test suite: **865/865 green**, `flutter analyze` clean.

**Built and wired end-to-end:** ride recording (offline-first, background
GPS, crash detection with a cancellable countdown), garage + distance-based
maintenance tracking, social (follow, audience-tiered ride sharing, upvote/
downvote, brand + model forums with a rider-created-forum path), POI
directory (fuel/garage/parts, geohash search, Overpass import), saved routes
with offline geometric turn-by-turn, group rides with live positions,
push-to-talk voice notes, and joining by a shared code (invite-free), a
SafeQR device-local medical-info card, home-screen widgets (Android; iOS
needs a one-time Xcode team-assignment step), a 7-color-family ×
boxy/curvy × dark/light Appearance system, Bangla localization (partial —
see "Product (v1.1+)" below), and opt-in background auto-tracking
(`auto_tracking_plan.md`).
Crash reporting (Firebase Crashlytics) was wired in 2026-08-28 — see
`Issues.md` §38.

**What's real but not live yet:**
- **Crash-alert SMS/email escalation is mocked end-to-end.** Cloud Functions
  can't deploy on the current Spark billing plan — see "Soon" below and
  `backend_options.md`. The in-app copy is honest about this (`Issues.md`
  §24.8); no store listing should claim otherwise.
- **The Play Store / App Store submissions haven't started.** See "Play
  Store" below for the concrete step-by-step and the background-location
  review, which is the actual long pole, not a build step.
- `flutter_background_geolocation`'s license key is still the
  `PASTE_LICENCE_KEY_BEFORE_RELEASE` placeholder — every Android release
  build crashes with a licensing error on launch until a real key is bought
  (`Issues.md` §35). **This blocks any further distribution today.**

**What's unverified, in one place — everything else is verified by
`flutter analyze` + the test suite + a clean release build only:**
almost nothing in this app has been tap-tested past sign-in on a device,
because no sign-in or UI-automation tooling exists in the agent environment
that has done most of this work (`Issues.md` §15). See "⚠️ Done, but NOT
yet verified" below for the full, current list — treat every item there as
the actual pre-launch QA backlog, not a formality.

### Versioning history, briefly

The version line has been reset twice, both deliberately: `2.0.0-beta.x`
was scrapped 2026-08-01 for a clean `1.0.0-beta.1+1` start (the first build
meant for hands other than the owner's), and `beta-v1`/`v2`/`v3` were all
deleted again 2026-08-17 once both platforms' home-screen widgets were
confirmed working on real hardware — the current `beta-v1` supersedes all
three earlier ones. **If anyone still has an old `beta-v2` APK: it crashes**
(nested-array GPS-trail upload bug, fixed 2026-08-03 in `1fca84e` — see
`Issues.md` §11). Don't diagnose a crash report against anything but the
current `beta-v1` tag.

Since that reset, `beta-v1`'s tag has been moved forward in place (not
re-versioned — `pubspec.yaml` stays `1.0.0-beta.1+1` for nav-only/skin/
security/dependency changes that don't warrant a version bump) roughly a
dozen times as fixes landed; the tag always points at the latest commit
verified to build and install. **Rebuild before every upload** — the AAB/APK
artifacts aren't committed, so any commit after a build invalidates it.

### Notable feature milestones (dated, most recent first)

Full technical detail and root causes for anything marked with a `§` live in
`Issues.md`; this list is a compact pointer, not the record itself.

- **2026-08-29** — Fixed all six defects from the §46 QA sweep: the
  export-crash `sharePositionOrigin` fix (§48), a GPS-speed fallback for
  when `Position.speed` is unreliable (§49), three forum UX gaps — posts
  appearing immediately instead of after a re-entry, empty-post validation,
  and a spinner while a brand/topic forum resolves (§54) — and "can't
  delete your own post" (§47), which turned out to be an unreleased
  (not just stale) `firestore.rules` ruleset in production, fixed by
  redeploying.
- **2026-08-28 (later still)** — Auto-tracking's licensing crash (§35) fixed
  by replacing the paid `flutter_background_geolocation` plugin with a free
  stand-in (`flutter_activity_recognition` + `flutter_foreground_task` +
  the existing `geolocator` dependency) — a deliberate product decision to
  stay on the free tier for roughly the next three months rather than buy the
  licence key now (§50). `flutter build apk --release` now succeeds with no
  licence-key gate at all, where it previously crashed on launch. Known gap:
  on iOS the tracker doesn't survive the rider force-quitting the app (see
  Known Limitations below). The old implementation is preserved in
  `docs/archives/flutter_background_geolocation-2026-08-28/` in case the
  paid plugin is worth revisiting — pros/cons in the Feature Backlog, Part 2.
- **2026-08-28 (later same day)** — Three competitor-gap items shipped:
  **SafeQR** (`/safe-qr`, device-local scannable medical-info QR card, no
  backend), the Record screen's plain "Ride with friends" button replaced
  with an explicit **Solo/Group choice** (`RideModeSelector`), and **join a
  group ride by code** (`group_ride_join_code.dart` — a 6-character code
  rather than GPS-radius discovery, see `Features.md` §7b for the security
  reasoning). Three related ideas — a pre-ride multi-stop trip planner, fuel
  tracking, and finishing the Bangla localization pass — were deliberately
  left as backlog rather than built same-session; see "Proposed features"
  below. ⚠️ `firestore.rules` has new clauses for the join-code
  feature (`groupRideJoinCodes` collection, a new `groupRides` update
  clause, a widened `members` write clause) that have **not been deployed
  yet** — see "Now" below. 9 new emulator rules tests, 72/72 green.
- **2026-08-27** — Crash reporting wired in (`Issues.md` §38); default
  appearance changed to Calming/Curvy/Light (§40); `record` package bumped
  to 7.1.1, 5.x didn't compile for release (§41); a brand forum now surfaces
  its model forums' posts too; error-message/permission-awareness pass
  across record/auto-tracking/social (§37); push-to-talk voice notes for
  group rides (mic + Bluetooth routing, **unverified on real hardware** —
  see "Done, NOT yet verified"); `flutter_background_geolocation`'s missing
  license key root-caused as the Android "licensing error" crash (§35).
- **2026-08-23** — Security/bug sweep, 18 findings, 16 fixed same session,
  2 deferred pending Blaze (§33) — includes two launch-blocking issues
  (signed-out data leaking to the next user on a shared device; live-share
  links with no server-side expiry). Same day: the flat 10-skin Appearance
  dropdown was replaced with three independent axes — Vibe (boxy/curvy),
  Brightness (dark/light), Color (7 families) — dropping three skins that
  were really duplicates of another family.
- **2026-08-17** — Auto-tracking foundation (background activity-recognition
  trigger + reconciliation) and a stale-UI sync bug shipped and, for the
  first time, actually build-verified rather than just analyzed — 4 real
  breaks surfaced only by a real `flutter build` (§29). Same day: Bangla
  parity for auto-tracking UI, the iOS widget extension target scripted into
  `Runner.xcodeproj` (§30), Android widgets verified end-to-end on an
  emulator (§31), bottom-nav renamed Garage→Profile, Places/Rides tabs
  swapped, a new Cute Analyst skin (later dropped, see 2026-08-23), and the
  second versioning reset described above.
- **2026-08-12** — Per-skin shape (boxy/rounded/terminal) added alongside
  palette; `scripts/seed_dhaka_places.js` (395 real places written to
  production); Bengali font bundled offline; sensor-fusion axis calibration
  via GPS-paired least-squares; `flutter analyze` fixed to stop scanning
  `build/` (6,163 phantom errors → 0, §23).
- **2026-08-11** — Ride survival across a force-kill (`restoreInterruptedRide`
  replacing the old finalize-and-split behavior, §18), discard ride (§20), a
  killed ride's stale live-pointer bug found alongside it (§19), Retro
  redesigned as a true black-and-white terminal skin, Record screen redesign,
  brand/model forum split, bike-photo in-app cropping, and the 2-skin toggle
  becoming a 9-skin dropdown.
- **2026-08-04** — Root-caused the iOS `flutter run` ad-hoc-signing install
  failure (see "Operational notes" below); `usernames` collection-listing
  hole closed (§14, same bug class as §3).
- **2026-08-01 → 08-02** — The full backlog pass: forum moderation and
  rider-created forums, ride captions + route-map feed cards, saved routes
  with offline turn-by-turn, expanded maintenance types, moving-time average
  speed, GPS trail sync, home-screen widgets, the privacy policy published,
  beta data-reset tooling, and the Carbon Mono/Editorial theme system (later
  superseded by the 2026-08-23 Vibe/Brightness/Color redesign). Every
  judgement call made without asking during this pass is recorded in
  `assumptions.md`.
- **2026-07-23** — Vehicle State Engine Phase 1 + 1.5 shipped (sensor fusion,
  confidence scoring, motion classification, adaptive recording thinning) —
  see Part 3 below for the full architecture.
- **2026-07-14** — The 2026-07-14 code audit found several P5–P8 features
  existed as logic/data layers with no UI ever wired to them (crash
  countdown, sync manager, exports, emergency contacts, live-share, the POI
  directory, the whole social feed). All wired in the same pass.

### Operational notes worth not re-discovering

- **iOS install: prefer `flutter build ios --release` → `xcrun devicectl
  device install app` → `devicectl device process launch` over `flutter
  run` on a physical device.** This sequence has installed clean, first try,
  every single time it's been used across many sessions; `flutter run --release`
  has failed with an opaque "Could not run … Try launching Xcode" for at
  least two distinct root causes (an ad-hoc-signed `objective_c.framework`
  from a stale native-assets build — fixed by `flutter clean && flutter pub
  get` then rebuilding; and, separately, a bug in `flutter run`'s own install
  step where the identical bundle installs fine via `devicectl`). Get the
  real error with
  `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app`,
  and compare framework signing identities with `codesign -dvv <path>` — ad-hoc
  (`TeamIdentifier=not set`) means a stale build, not a real signing problem.
  `flutter devices` often misses a paired iPhone at its default timeout; use
  `--device-timeout 30`. `xcrun devicectl list devices` lists known devices
  whether reachable or not — only `available (paired)` (not `unavailable`)
  means installable.
- **`Lost connection to device` is not always the device.** A `pkill -f
  "flutter run"` from *any* Claude Code session on the same machine (this
  repo's or another repo's) kills every matching process, not just its own —
  hit from both directions across `repos/life-manager` and this repo. Scope
  any kill to `pkill -f "flutter run -d <udid>"`, and prefer the
  build-install-launch sequence above (no long-lived host process to lose)
  over `flutter run` when you just need the app on the phone.
- **No screenshot tooling exists for a physical iOS device** in this
  environment (`_flutter.screenshot` fails — Impeller doesn't support
  compressed screenshots; no `idevicescreenshot`/`libimobiledevice`
  installed). For "what's actually on screen," use the VM Service's
  `ext.flutter.debugDumpApp` over HTTP instead — `curl "$VM_URI/getVM"` for
  the isolate id, then `curl "$VM_URI/ext.flutter.debugDumpApp?isolateId=$ID"`
  gives the live widget tree, including which `MaterialApp` key (and
  therefore which theme/skin) is mounted.
- **`keytool` doesn't work out of the box on this Mac** — `/usr/bin/keytool`
  is Apple's stub and silently yields an empty fingerprint under
  `2>/dev/null`, which reads as "not registered" even when it is. Use
  Android Studio's bundled JDK:
  `"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"`.
  The same JBR is also the fix for `firebase emulators` needing a JVM with no
  `java` on `PATH` (`JAVA_HOME` pointed at it — see `npm run test:rules`).
- **A device's actual `textScaler` matters.** Abraar's test iPhone runs at
  `1.1176` with bold text; every widget test runs at `1.0`. A suspected
  clipping bug in the skin dropdown was filed and then disproved by real
  on-device measurement at that scaler (`Issues.md` §16) — don't assume a
  visual bug from a test-only reading.
- **App-admin identity and GCP-project-owner identity are not the same
  account.** Running an Admin SDK script needs `gcloud auth
  application-default login` as `blankframe.technologies@gmail.com` (the
  actual GCP project owner), not `the.abraar.rar@gmail.com` (the in-app
  admin, which has no IAM role on `throttleiqfb` at all) — plus `gcloud auth
  application-default set-quota-project throttleiqfb` afterward.

- **`rsvg-convert` (2.62.3, Homebrew) silently drops all `<textPath>` text —
  and Flutter's `flutter_svg` has the same gap — so text-on-a-curved-path
  must be hand-placed** (one `<text transform="rotate(deg x y)">` per
  glyph, positioned with basic trig around the arc) rather than
  `<text><textPath href="#arc">…`. The bug is silent: the rest of the SVG
  renders fine, the text element just produces nothing, no error. Verify any
  new curved-text asset by actually rasterizing it (`rsvg-convert -o
  out.png`) before trusting it, not just by eyeballing the SVG source. See
  `assets/icons/throttleiq-icon-dark.svg` for the working per-glyph pattern.
- **The Artifact tool has no delete/unpublish action** — `list`, `read`,
  `watch`/`unwatch`, and asset-store actions exist, but there is no way to
  remove a published artifact page itself from Claude Code. `unwatch` only
  stops this session's live-update subscription; the page and its link keep
  existing. Deleting one for real is a user action from claude.ai's
  artifacts UI (or `/artifacts` in the terminal) — say so plainly rather
  than implying `unwatch` accomplished a deletion.
- **A `logo-creator` skill (with its `nanobanana` image-gen dependency) lives
  in `.claude/skills/`**, copied in from the `resciencelab/opc-skills` repo
  for brand/logo work. It needs `GEMINI_API_KEY`, `REMOVE_BG_API_KEY`, and
  `RECRAFT_API_KEY` set in the environment to actually generate anything —
  none are configured as of this writing, so invoking it will fail on the
  first API call until someone sets them.

### Known Limitations (Documented, Not Bugs)
- **Navigation is geometric, not routed** — turn-by-turn follows a saved
  route's own polyline: no street names, no lane guidance, no rerouting (it
  reports "off route" instead). Deliberate: no routing engine or API key
  exists. See `assumptions.md`.
- **Sensor calibration**: heuristic axis pick with a GPS-paired least-squares
  fit (2026-08-12); full IMU fusion into the persisted acceleration value is
  future work (Part 3, Phase 2).
- **POI search**: geohash-based, not real-time autocomplete; `getNeighbors`
  isn't wired into an actual range query yet (`getNearbyPlaces` filters
  in-memory).
- **Offline-first limit**: ~10MB local DB on a typical device; no cleanup
  policy on rotation yet.
- **No payment/premium tier**: everything is free today; not yet designed or
  priced (see `business_critique.md` for why this is a real gap, not just an
  unstarted feature).
- **No behavioural analytics**: no `firebase_analytics`, only
  `firebase_crashlytics` (crash diagnostics, added 2026-08-28) — see
  `store_listing/data_safety_and_permissions.md`.
- **Admin panel**: moderation is done via the Firebase console + the
  `admin` custom claim; no in-app admin UI.
- **ML features**: crash/pothole detection is threshold-based; no on-device
  model (see Part 3, Phase 4, for why and when this might change).
- **Auto-tracking on iOS doesn't survive a force-quit**: the free-tier
  detector (`flutter_foreground_task`, since 2026-08-28) keeps running after
  the app is swiped from Android's recents, but on iOS the task is destroyed
  the moment the rider force-quits ThrottleIQ from the app switcher —
  documented plugin behaviour, not a bug in this app's use of it. Backgrounded
  (not force-quit) still works. See `auto_tracking_service.dart`'s doc
  comment and the Feature Backlog (Part 2) for the paid-plugin alternative,
  whose iOS story is only somewhat better (its significant-location-change
  wake-up also doesn't survive a *user-initiated* force-quit, only an
  OS-initiated kill for memory).

### Deployment & CI/CD
- **Build**: `flutter build apk` / `flutter build appbundle` for Android;
  `flutter build ios` for iPhone.
- **Firebase**: rules/hosting deployed via `firebase deploy --only
  firestore:rules,hosting`; Cloud Functions cannot deploy on the current
  Spark plan (see "Soon" below).
- **Distribution**: GitHub Releases (signed APK) today; Play Store (internal
  testing) and TestFlight are both pre-submission — see "Play Store" below.
- **Rules tests before every rules deploy**: `npm run test:rules` from
  `scripts/` (Firestore emulator, needs a JVM — see the JBR note above).

### Phase priorities (roadmap ordering, historical)
1. **P1**: Emergency contacts + crash detection with countdown UI
2. **P2**: POI map + directory + ratings
3. **P3**: Shared routes, group rides
4. **P4**: Turn-by-turn routing, club managers

All four shipped as of 2026-08-17; see "Notable feature milestones" above
for what actually landed and when. Kept here only as the original ordering
rationale.

---

## ⚠️ Done, but NOT yet verified

These exist in code/config but have never been exercised against the real
backend or a real device. **Treat each as unproven until tested.** This is
the actual pre-launch QA punch list — ordered roughly by risk.

- [ ] 🔴 **Push-to-talk voice notes** (group rides, added 2026-08-27). Mic
  capture and Bluetooth-headset routing can't be verified without real
  hardware — `flutter analyze`/tests/rules-emulator tests all pass, but none
  of that touches a real microphone or paired headset. Needs: two real
  devices (iOS Simulator has no mic — a physical iPhone is required for
  final confirmation), one with a Bluetooth headset paired; confirm a clip
  uploads, auto-plays once through the headset (not the phone speaker), that
  muting/leaving stops playback cleanly, and that a phone call interrupts
  and recovers. A real motorcycle intercom (Sena/Cardo) is the actual target
  hardware and worth testing specifically if available.
- [ ] 🔴 **Offline end / share / resume** (`Issues.md` §25/§26) — the
  highest-value device check outstanding, because the bug it fixed is a
  Firestore SDK timing property no test here can stage (an awaited write
  with no connection never returns). Run in **fly mode**: start a ride, end
  it (must finalize promptly); share with a photo (must return quickly,
  "we'll post it when you're back online"); force-kill mid-ride and reopen
  (must come back paused, not vanish); trigger and dismiss the crash overlay
  (must return to active); re-enable data (the queued share must post
  exactly once).
- [ ] **Auto-tracking, end to end on a real device** — see
  `auto_tracking_plan.md`'s "Blocking before this can ship" list: the
  license key is still a placeholder (blocks ALL Android release builds,
  not just this feature — see "Current status" above), and the full-screen
  crash-alert notification on an auto-started ride has never been forced on
  a locked phone.
- [ ] **Auto-tracking active-hours schedule** (`Issues.md` §37.3) — whether
  the plugin's native schedule actually starts/stops GPS at the configured
  boundary, and whether editing the window while already running takes
  effect without a restart, on a real device.
- [ ] **Nine (now seven) Appearance color families across a whole screen
  each**, not just a swatch — only Carbon Mono has been seen rendering a
  real screen past Record. Retro (must be fully square/monochrome) and any
  `curvy` family on a screen with the 210px Record photo hero are the two
  highest-value checks.
- [ ] **Ride with friends** — needs two real accounts on two devices: invite,
  accept, confirm both riders appear on each other's live map and stale
  positions grey out. The deployed `groupRides` rules have never been
  exercised by a real client.
- [ ] **Join a group ride by code** (added 2026-08-28) — `firestore.rules`
  deployed 2026-08-28 (see "Now" above); still needs two real accounts:
  create a ride, share its code, join from the second account, confirm it
  appears on the shared map without ever having been invited. Rules
  behavior is covered by emulator tests (72/72); no real client has
  exercised it.
- [ ] **SafeQR** (added 2026-08-28) — the QR code itself is rendered by
  `qr_flutter`, a pure widget with no platform code, so it's low-risk, but no
  actual phone camera has scanned a rendered card yet to confirm the payload
  reads cleanly (line length, code density at the 200px render size).
- [ ] **Bike visibility tiers** (`public`/`followers`/`private`) — confirm
  read access actually matches the tier on a device; this rules change
  *widened* default read access (`assumptions.md` #15).
- [ ] **Turn-by-turn navigation at real road speed** — geometry is
  unit-tested; the 30m "turn reached" / 100m "off route" thresholds need
  tuning from an actual ride.
- [ ] **GPS trail sync round-trip** — record, sync, reinstall, confirm the
  polyline comes back rather than an empty map.
- [ ] **OS app icon border-flush fix** (added 2026-08-28, `Issues.md` §44) —
  the squircle border now sits flush against the icon's outer edge instead
  of floating inset; confirmed only by rendering the PNGs, not by a fresh
  install on a physical device (unlike §43, which was device-verified).
- [ ] **Home-screen widgets on a real launcher** (Android confirmed on an
  emulator, §31; iOS structurally wired but inert until an Apple Developer
  team is assigned in Xcode for both targets).
- [ ] **DB schema upgrades over a real existing install** (currently v11) —
  covered by an in-memory migration test, but never run over an actual
  rider's on-disk database.
- [ ] **Google sign-in end-to-end** and **Firestore rules under real traffic**
  (own rides readable, someone else's not) — config/rules are in place, only
  ever exercised by the emulator and by reasoning, not a live account.
- [x] ~~Run `scripts/seed_dhaka_places.js` against production~~ **DONE
  2026-08-12** — 395 places live in `throttleiqfb`. Still to check on a
  device: opening Places in Dhaka renders them, and "Import nearby" adds
  nothing (osmId dedup holds).
- [ ] **The §46 QA sweep's six fixes** (`Issues.md` §47–§49, §54, 2026-08-29):
  export-crash fix, GPS-speed fallback, three forum UX fixes
  (new-post-appears-immediately, empty-post validation, brand-forum-open
  spinner), and the delete-your-own-post rules release. All
  `flutter analyze`/`flutter test` (862/862) clean and (for the rules) 73/73
  `npm run test:rules`, but none re-run through the same
  accessibility-driven device sweep that found them. The speed fallback in
  particular needs a real recorded ride, not just simulator GPS playback, to
  confirm avg/max speed come out sane; the delete fix needs an actual
  delete-your-own-post tap against the now-released production rules.

## 📋 To do

- [x] ~~Deploy `firestore.rules`~~ **DEPLOYED 2026-08-29** — the QA sweep's
  "can't delete your own forum post" (`Issues.md` §47) turned out not to be
  a rules-*text* bug: the post-delete rule already correctly allows the
  author (new `npm run test:rules` case `'a rider can delete their own
  post'`, 73/73 green). `firebase deploy --only firestore:rules --project
  throttleiqfb` reported the content as already uploaded but **not yet
  released** — this deploy is what made it the live-serving ruleset, which
  lines up with what QA actually saw.
- [x] ~~Buy the `flutter_background_geolocation` license key~~ **RESOLVED
  DIFFERENTLY, 2026-08-28** — instead of buying the key, the plugin was
  replaced with a free stand-in (`flutter_activity_recognition` +
  `flutter_foreground_task`, see `auto_tracking_service.dart`'s doc comment
  and `Issues.md` §50). `flutter build apk --release` now succeeds with no
  licence gate. Product decision: stay on the free tier for roughly the next
  three months. Reconsider the paid plugin (pros/cons under "Proposed
  features" in Part 2) if the free tier's gaps — mainly, weaker iOS survival
  and no true OS-native scheduled start/stop — turn out to matter in
  practice; the old implementation is archived at
  `docs/archives/flutter_background_geolocation-2026-08-28/` and can be
  dropped back in.
- [ ] **Back up the signing keystore.** `throttleiq-release.keystore` +
  `app/android/key.properties` exist ONLY on the dev machine. If lost, the
  app can never be updated under the same identity → password manager /
  secure cloud, never git.
- [ ] **On-device verification that a crash actually reaches the Firebase
  Crashlytics console** — added 2026-08-28 (`Issues.md` §38), never run on a
  device or simulator.
- [x] ~~Deploy the updated `firestore.rules`~~ **DEPLOYED 2026-08-28** for
  the join-a-group-ride-by-code feature (`Features.md` §7b) — new
  `groupRideJoinCodes` collection, a new `groupRides` update clause (a
  stranger adding themselves to `memberIds` on an active ride), and a
  widened `members/{uid}` write clause. `npm run test:rules` was green
  (72/72) beforehand; `firebase deploy --only firestore:rules --project
  throttleiqfb` shipped it live. Joining by code should now work against
  production — still needs the real-device check listed under "Done, but
  NOT yet verified" above.
- [x] ~~Close the two launch-blocking security findings~~ **CODE FIXED
  2026-08-12, DEPLOYED 2026-08-14.** Audit found 8 findings (`Issues.md`
  §24.1–§24.9); all fixed and the rules deploy is live on `throttleiqfb`.
  Two loose ends: **Cloud Functions still can't deploy** (needs Blaze — see
  "Soon" below, blocks §24.8/§24.9's server-side pieces), and
  `scripts/set_admin_claim.js` still needs a human to run it once with real
  credentials (the email-fallback admin check keeps working until then, so
  this isn't blocking).
- [x] ~~Second security/bug sweep~~ **16 of 18 FIXED, 2 DEFERRED, 2026-08-23**
  — `Issues.md` §33. Includes two more launch-blocking findings: signing out
  didn't clear local data on a shared device, and live-share links had no
  server-side expiry. Both closed.
- [x] ~~Release key's SHA-1 registered with the Android OAuth client~~
  **VERIFIED 2026-08-11** — `google-services.json` carries the release
  keystore's fingerprint, so Google sign-in works in release builds. Re-check
  after any keystore change, including a future Play App Signing upload-key
  rotation (a second fingerprint that also needs registering).
- [x] ~~Wire the orphaned P5–P8 features~~ **DONE 2026-07-14** — crash
  countdown overlay, SyncManager, exports, emergency contacts, live share,
  POI directory, social feed all wired end-to-end.
- [x] ~~Deploy `firestore.rules` + hosting~~ **DONE, re-run after every rules
  edit.** `firebase deploy --only firestore:rules,hosting`. **Test rules
  first**: `npm run test:rules` from `scripts/` (Firestore emulator — see the
  JBR note in "Operational notes" above). Careful with rules that require a
  field only the newest client build sends — ship the app before the rule,
  not after (this bit the §24.7/§24.11 batch).
- [x] ~~Run the test suite~~, ~~deploy the live-share viewer~~ **DONE
  2026-07-14.**

### Soon (requires the Blaze pay-as-you-go plan — still ~$0/mo at beta scale)

> **Considering avoiding Blaze entirely (a Supabase migration, or similar)?**
> See `backend_options.md` — weighs enabling Blaze against a surgical
> Cloudflare/Vercel workaround and a full backend migration, with a real
> 10K-DAU cost estimate. Short version: enable Blaze — migrating means
> rewriting `firestore.rules` (960 lines, audited across `Issues.md`
> §3/§10/§24/§33) as Postgres RLS from scratch.

- [ ] **Cloud Functions** — deploy `functions/` (crash-notification
  escalation via Twilio/SendGrid). Needs the project owner's own accounts
  and API keys, not just code — the code side is ready (`functions/`
  gained the `index.ts`/`package.json main` it was missing, `Issues.md`
  §24.10).
- [ ] **Firestore TTL policy** on `liveSessions.expiresAt` — [Firestore →
  Time-to-live](https://console.firebase.google.com/project/throttleiqfb/firestore/ttl),
  collection group `liveSessions`, field `expiresAt`. Won't clean up
  documents written before the Timestamp fix (`Issues.md` §4) — those hold
  string expiries TTL ignores; delete by hand if it matters.
- [x] ~~Firebase Storage bucket~~ **SUPERSEDED 2026-07-23** — Storage needs
  Blaze even within its free tier; photo uploads use Cloudinary instead
  (cloud name `vjvcigkt`), no bucket needed.
- [x] ~~Deploy the privacy policy~~ **DONE 2026-08-01** —
  `https://throttleiqfb.web.app/privacy.html`.
- [x] ~~Sync GPS trails to Firestore~~ **DONE 2026-08-01** — chunked
  `track/{i}` docs, 500 points each. **Still unverified**: a reinstall
  actually restoring polylines from the cloud.

### Play Store & App Store — step by step

> **🔴 The long pole is a Google review, not a build step.**
> `AndroidManifest.xml` declares `ACCESS_BACKGROUND_LOCATION` with a
> `foregroundServiceType="location"` service, which triggers Google's
> **Background Location Access declaration**: a Play Console form needing a
> video demo and written justification, reviewed in **days to weeks**.
> Production, open testing and closed testing are all gated on it —
> **internal testing is normally exempt** (confirm in Console, don't assume).
> Plan the launch date around this review, not around the code being ready.
> Two more policy notes for the same submission: `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
> is a restricted permission and a common rejection reason — have the
> justification written before submitting — and the **Data Safety form**
> must declare precise location, photos, email, *and* that location is
> shared with other users (live-share counts as third-party sharing under
> Play's definition; see `store_listing/data_safety_and_permissions.md`,
> already drafted).
>
> **Also decide before the listing copy is written:** crash detection
> currently notifies nobody (Cloud Functions can't deploy on Spark — see
> "Soon" above). The in-app copy is honest about this; a store listing that
> markets crash detection as a safety feature while nothing is actually sent
> is both a policy risk and a real one. Either upgrade to Blaze and wire the
> SMS/email provider, or keep the claim out of the listing.

**Play Store**
1. **Finish Play Console signup** ($25, one-time) —
   <https://play.google.com/console/signup>. Identity verification can take
   up to 48h — start this first.
2. ~~**Decide the publisher identity**~~ **RESOLVED 2026-08-28** — Play
   Console's Android developer verification page confirms the account is
   registered as an **individual**, "Abrar Masud Nafiz" (Dhaka, BD), not a
   company. That matches the current privacy policy's "independent,
   solo-developer project" framing already — no "Blankframe.tech" company
   name needs adding. (The old privacy policy naming "Blankframe.tech" /
   `blankframe.technologies@gmail.com` is stale and can stay superseded.)
3. ~~**Create the app** in Play Console~~ **DONE 2026-08-28** — created
   under `com.bft.throttleiq` (the correct registration; `com.bft.throlleiq`
   is an unused typo, left alone). First release AAB built at versionCode 1
   (`flutter build appbundle --release`). **Every future upload** needs
   `version:`/versionCode bumped in `pubspec.yaml` before rebuilding, per #8
   below.
4. **Upload to Internal testing track first** — exempt from the background-
   location review, so it's the fastest way to a real build on real devices.
   AAB upload/release creation started 2026-08-28 — confirm in Play Console
   whether it completed. That draft's warnings (no testers assigned yet, no
   deobfuscation file) are addressed as of later the same day: testers still
   need assigning in the console, but a **new** `app-release.aab` was
   rebuilt with R8/ProGuard re-enabled (`Issues.md` §51) — upload it in
   place of the first one, along with
   `build/app/outputs/mapping/release/mapping.txt`, to close the
   deobfuscation warning. Still versionCode 1 — the draft release hadn't
   rolled out yet, so no version bump was needed to replace it.
5. Fill in **Store listing** (`store_listing/store_listing.md`), **Data
   Safety form** (`store_listing/data_safety_and_permissions.md`), and the
   **Content rating questionnaire**.
6. Submit the **Background Location Access declaration** — see the 🔴 note
   above. Gates closed/open/production testing.
7. Once background-location clears: promote internal → closed beta →
   production.
8. Bump `version:`/versionCode in `pubspec.yaml` for every new upload —
   build artifacts aren't committed, so any commit after a build invalidates
   it.

**App Store**
1. **Enroll in the Apple Developer Program** ($99/yr) —
   <https://developer.apple.com/programs/enroll/>.
2. Create the App ID / bundle identifier.
3. **Fix the two things that get an automatic rejection, before submitting**:
   an **in-app account-deletion flow** (required —
   <https://developer.apple.com/support/account-deletion/>; none exists
   yet), and a **report/block mechanism** for forum/social UGC (Guideline
   1.2; none exists yet).
4. Create the app record in **App Store Connect**, fill in **App Privacy**
   (nutrition labels).
5. Archive and upload a build (Xcode Organizer or Transporter) — add the iOS
   widget extension target first (`app/ios/ThrottleIQWidget/README.md`,
   one-time Xcode GUI step).
6. **TestFlight internal testing** — no review needed, available immediately
   once a build is up.
7. When ready for the public: store listing, screenshots, **Submit for
   Review** (usually 24h–a few days for a first submission; expect a bounce
   if #3 isn't done).

**Marketing sequencing — organic first, not paid ads.** Don't spend ad
money until: crash reporting has a real crash-free-sessions number to show
(added 2026-08-28, not yet device-verified — see "Now" above), the "Done,
NOT yet verified" list above is meaningfully shorter, and the store
submissions are actually live (Play's background-location review alone
can take weeks, so there's no "buy ads → users install from Play" path
until it clears anyway). Get it into a few hundred real riders' hands
organically first — BD motorcycle Facebook/WhatsApp groups, forums, a
dealership contact — with a direct feedback channel, for 2–4 weeks; see
`marketing.md` for the full channel plan. Early store ranking is sticky on
early signal, so banking good reviews from a smaller, forgiving organic
group first matters more than speed.
### Open questions for the product owner

- ❓ **Does the quote belong on the Record screen at all?** It now shares a
  card with the greeting and name (small type). But the Record screen is
  the pre-ride screen, and a rider standing at their bike wants the bike
  picker and the start control, not prose. **Alternative worth
  considering:** show the quote on an *intermediate screen between
  tapping start and recording beginning* — a two-second "here we go"
  moment, where a line of personality actually lands instead of competing
  with the controls. That screen could also carry the GPS-lock status,
  which currently has nowhere to live. Decide before the beta; it's a
  cheap move now and awkward later.
- ❓ **Badge completion reward.** The intent is that a rider completing
  every badge gets an engine oil from us. Nothing in the app encodes that
  yet — no "all badges earned" state, no fulfilment path, no way to claim.
  Decide whether it's a real promise (needs a claim flow, an address, and
  a cost model) or aspirational copy, before it goes in front of testers.
  See also `marketing.md` §6's related-but-different **"first to badge"
  promotion idea** (physical prizes — engine oil, chain cleaner — for the
  first riders to reach specific badges, gated on hitting ~100 organic
  users) — the two proposals should probably share one claim/fulfilment
  mechanism rather than each getting its own.

### Proposed features (not built — for discussion)

- ✅ **Automatic ride tracking (start recording without tapping start) —
  BUILT, opt-in, off by default, 2026-08-16/17.** The assessment and isolate
  decision below are superseded by `auto_tracking_plan.md`, which has the
  full design (option 1, a trigger-only detection harness, chosen over a
  native-service rewrite) and its "Implementation status" section listing
  exactly what shipped: clock-injected `EventDetector`, a two-profile GPS
  split by `userInitiated`, schema v11 (`is_auto`/`bike_confidence`/
  `auto_detections`/`auto_fixes`), the background trigger + reconciler, bike
  attribution with a correction card, and three new notification channels.
  **Still blocking before this is trustworthy in production**: an on-device
  test of the full-screen crash-alert notification on an auto-started ride
  (see "Done, NOT yet verified").

  **2026-08-28 — swapped the paid detection plugin for a free one, staying
  free-tier for ~3 months.** The licence key for `flutter_background_geolocation`
  was never bought (`Issues.md` §35 — the crash it caused). Rather than buy
  it, the plugin was replaced with `flutter_activity_recognition` +
  `flutter_foreground_task` (both MIT) — see `auto_tracking_service.dart`'s
  doc comment for the new architecture and `Issues.md` §50 for the full
  write-up. The old implementation is kept at
  `docs/archives/flutter_background_geolocation-2026-08-28/` (code +
  restore instructions) in case it's worth reviving. Pros/cons, for whoever
  revisits this after the 3 months:

  | | `flutter_background_geolocation` (paid) | Free stand-in (current) |
  |---|---|---|
  | Cost | One-time, per-app-id; price wasn't published without a quote from https://shop.transistorsoft.com | $0 |
  | Android survives force-swipe from recents | Yes | Yes (`flutter_foreground_task`'s foreground service) |
  | Android survives OEM battery killers | Tested/tuned by the vendor across OEMs | Best-effort — `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` prompt only, no vendor-specific handling |
  | iOS survives a *user-initiated* force-quit | No (documented Apple platform limit, not a plugin gap) | No (same underlying limit) |
  | iOS survives an *OS-initiated* kill (memory pressure) | Yes — significant-location-change relaunches the app | No — the task is simply gone until next manual open |
  | Active-hours scheduling | Native OS-level start/stop — genuinely stops GPS outside the window | Dart-side gating at trip-start only; a trip already running when the window ends finishes uncut (see `auto_tracking_service.dart`) |
  | Isolate architecture | Two handlers to keep in sync (UI isolate + headless isolate) | One handler — the foreground-service isolate runs regardless of whether the UI is open |
  | Maintenance | Vendor-maintained, single dependency | Two free dependencies to track for breakage/abandonment (`flutter_activity_recognition` was last published ~24 months ago as of 2026-08-28 — check it's still alive before leaning on it long-term) |

  **Revisit trigger:** if beta feedback shows the iOS gap or OEM battery-kill
  reliability actually costing detected rides, or once there's revenue to
  justify a recurring infra cost that used to be "should we spend money
  pre-revenue" — not before.
- 🔮 **Auto-pause in traffic.** Detect a stop (already possible — the
  recorder classifies `period_type` as moving/idle at the 1 m/s cutoff)
  and pause recording automatically. ~~surface the jam time back to the
  rider after the ride~~ **DONE 2026-08-12** — ride summary now shows
  moving vs. jam time (`jam_time.dart`, `rides.moving_s`, schema v9; see
  `Features.md` §2). What's **still open** is only the auto-pause policy
  itself: today jam time is reported but the ride keeps recording through
  it (correctly — moving time already excludes it from the average-speed
  denominator). Auto-pausing would need to watch out for a long traffic
  light vs. a genuine stop, and not double-counting against the existing
  manual pause.
- 🔮 **iOS start/stop widget.** The Android widget already exists and the
  iOS sources are written (`app/ios/ThrottleIQWidget/`), but iOS widgets
  can't *start a recording* from the widget itself — they can only deep
  link into the app. A true start/stop control needs App Intents
  (iOS 17+) plus background-location handoff. Worth scoping properly
  rather than assuming parity with Android.
- 🔮 **ThrottleIQ Partner** — a companion surface for the people who worry
  about a rider: spouse, parent, friend. Today live-share is one link per
  ride; Partner would let someone follow **multiple** riders (son,
  husband, father, friend) from one place, seeing who's currently out and
  where. Web first (the live viewer is already a web page and the
  permanent per-rider link is the natural building block), then a small
  standalone app. Note this is a **second product** with its own auth,
  its own privacy model, and its own consent story — a rider must be able
  to revoke a follower, and "always visible to my spouse" is a very
  different consent posture from "here's a link to this one ride". Do not
  start it before the main app has real users.
- 🔮 **Badge tiers as a collectible set** — bronze/silver/gold/platinum/
  diamond families are in as of 2026-08-04. The natural extensions:
  seasonal/limited badges, a shareable badge card, and club-level badges.

### Product (v1.1+)
- [x] ~~Average speed = distance ÷ moving time~~ **DONE 2026-08-01** (`average_speed.dart`, 12 tests)
- [x] ~~Sensor calibration via GPS fusion (current: heuristic axis pick)~~ **DONE 2026-08-12** — `accel_axis_calibrator.dart`. Fits a 3D "which way is forward" axis by least-squares against `MotionCalculator`'s GPS-derived acceleration (normal equations, solved incrementally, no stored sample history), and projects raw accelerometer samples onto it instead of picking whichever raw axis happens to read largest that instant. Falls back to the old dominant-axis heuristic until ~20 GPS-paired samples have accumulated *and* the fit is well-conditioned (guards against a near-singular matrix from straight-line-only riding). 6 tests, including recovering a known tilted axis from synthetic noisy data. **The near-singular-matrix determinant threshold is an unvalidated starting point** — as expected, tuning it (and re-checking whether the existing hard-brake/rapid-accel thresholds still fire right against the new, more accurate projection) needs real ride logs, which weren't available here.
- [ ] Crash-detector threshold tuning from real false-positive logs
- [x] ~~Geohash search → proper neighbor-table implementation (current neighbor calc is approximate)~~ **DONE 2026-08-12** — `GeohashUtil.getNeighbors` (`core/utils/geohash_util.dart`) now returns the correct 8 compass neighbors via the standard bit-interleaved neighbor-table algorithm (the same technique behind `geofire-common`), replacing the old re-encode-`center±cellWidth` approximation, which only ever found 4 neighbors and could drift across a cell boundary on float rounding. Cross-checked against an independent from-scratch bit-interleaving implementation (12,000 random points, 0 mismatches) and the `north(south(x))==x` round-trip identity; matches the classic "ezs42" worked example used across the wider geohash-library ecosystem. 8 tests, including antimeridian wraparound. Note the algorithm's one shared, known limitation: longitude correctly wraps at ±180°, but latitude has no "north of the pole" case, so it wraps too at the very top/bottom row — irrelevant at Bangladesh's ~20–26°N, so left as documented rather than special-cased. `getNeighbors` itself still isn't called from any query path (`PlaceRepository.getNearbyPlaces` fetches every place and filters in memory) — wiring it into an actual geohash-range nearby-query is separate, unstarted work.
- [ ] Weather on record screen (OpenWeather) — needs an API key, none available
- [ ] Leaderboards (smoothness-based), clubs & events
- [x] ~~Turn-by-turn navigation~~ **DONE 2026-08-01**, but *following a saved route*, not curvy-route *planning*. Planning a new route still needs a routing engine (Calimoto/Rever's core, XL/T3 — see Part 2).
- [x] ~~**Open discovered (public) routes**~~ **DONE 2026-08-02** — `?owner=<uid>` on the detail and navigate routes; read-only for non-owners.
- [x] ~~**Bundle a Bengali font**~~ **DONE 2026-08-12** — Noto Sans Bengali (variable font, OFL-licensed, `assets/fonts/`) bundled as a real pubspec `fonts:` asset rather than fetched via `google_fonts` at runtime, so Bangla glyphs render correctly offline from first launch. Wired as `AppTypography.bengaliFallback` and appended to every text style the app hands out — the shared `textTheme` via `TextTheme.apply(fontFamilyFallback:)`, plus the handful of standalone `GoogleFonts.xxx()` styles (app bar title, button labels, snackbar) that sit outside `textTheme` and needed their own `.copyWith`. 10 tests assert every named style and every standalone style carries it.
- [ ] **Translate the rest of the app** — a BD-market competitor analysis raised the priority of this one: a rival app's feature *names themselves* are Bengali, not just translated UI strings, which reads as meaningfully more Bangla-committed than ThrottleIQ's current partial pass. Only the settings screen was localized as of 2026-08-11; **partially picked up 2026-08-12**: the bottom nav (`app_shell.dart`), the Record-screen bike-picker hero and stat strip, and the full ride summary screen are now localized (34 new ARB keys, real Bangla translations, all passing the existing `arb_parity_test.dart` suite — no partial/placeholder translations). Two widget tests (`bike_picker_card_test.dart`, `rider_stat_strip_test.dart`) needed the same `localizationsDelegates`/`supportedLocales` MaterialApp wrapper `skin_dropdown_test.dart` already used, since pumping a widget that calls `AppLocalizations.of(context)` without it throws.
  **Still hardcoded, by remaining string count** (rough — literal single-line `Text('...')` call sites only, so an undercount for hint/label/multi-line text): active_ride_screen.dart (~14), forum_thread_screen.dart (~13), edit_profile_screen.dart (~12), user_profile_screen.dart (~11), my_shared_rides_screen.dart / add_place_screen.dart / garage_screen.dart / bike_detail_screen.dart (~10 each), stats_screen.dart (~9), route_detail_screen.dart (~8), social_screen.dart / ride_share_screen.dart / login_screen.dart (~7 each), and smaller counts across the rest of `features/*`. record_screen.dart itself is mostly *already* dynamic copy (`greetings.dart`) rather than literal strings, so it's a smaller lift than its raw count suggests. Also still open from `marketing.md`: the Play Store listing has no Bangla.
  **Not verified on a device**, same caveat as everything else in this pass: whether the (longer, on average) Bangla translations actually fit the tight stat-cell columns on the ride summary screen and the 11pt bottom-nav labels without wrapping or truncating.
- [ ] iOS build & TestFlight (config scaffolding exists; needs a Mac + Apple Developer account)

---

## Key facts (for whoever picks this up)

| Thing | Value |
|---|---|
| Firebase project | `throttleiqfb` (asia-south1) |
| Android package (all code, `main`) | `com.bft.throttleiq` — **registered in Firebase** since 2026-07-23: App ID `1:603325098273:android:94694220f44cbf63fcf660` |
| File storage | Cloudinary (unsigned upload, cloud name `vjvcigkt`), **not** Firebase Storage — see the "Soon" section above for why. **Needs a manual check** (`Issues.md` §24.9): the unsigned preset `throttleiq_unsigned` is client-extractable from the APK by design — that's not itself a bug — but confirm in the Cloudinary dashboard (Settings → Upload → Upload presets) that it restricts resource type, file size, and has moderation enabled, so a pulled-preset client can't be used for quota exhaustion or hosting arbitrary/illegal content. This needs dashboard login, so it wasn't something fixable from a code change |
| Signing keystore | `throttleiq-release.keystore` (repo root, gitignored) — **back it up**. Its SHA-1 is registered with the Android OAuth client (verified 2026-08-11); `keytool` needs Android Studio's bundled JDK on this machine |
| Local pub cache / Android SDK paths | Machine-specific — whatever's in your own `flutter doctor` output, not fixed values to copy |
| Latest release | [`beta-v1`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v1) — signed release **APK only** (no AAB yet), currently at commit `c531179` (moved forward 2026-08-28: the free-tier auto-tracking fix, the app-icon regeneration that had never actually been committed, and a bike paint-color feature — see the milestones list above and `Issues.md` §50), `pubspec.yaml` version `1.0.0-beta.1+1`. Moved forward in place well over a dozen times since the 2026-08-17 versioning reset (see "Versioning history" above); `beta-v2`/`beta-v3` are dead links, deleted in that reset. |
| Test suite | 862/862 green as of 2026-08-28 (`flutter test`, re-run after the auto-tracking swap above). Plus Node tests in `scripts/` (`npm test`) for the seed scripts' pure logic, and `npm run test:rules` (Firestore emulator, 72/72 green) for the rules. DAOs run against real in-memory SQLite via `sqflite_common_ffi` — see `Issues.md` §7 for why that mattered |
| Privacy policy | `https://throttleiqfb.web.app/privacy.html` — live, needed by the Play listing |
| Judgement calls | `assumptions.md` — every non-obvious decision from the backlog pass, with the file to change if you disagree |
| Admin account | `the.abraar.rar@gmail.com`, hardcoded in `forum_permissions.dart` (client-side, cosmetic only) AND, as of 2026-08-12, checked via the `admin` custom claim FIRST with this email as a fallback in `firestore.rules` (`Issues.md` §24.9). Run `scripts/set_admin_claim.js --email the.abraar.rar@gmail.com --yes-i-really-mean-it` once (needs real Firebase Admin credentials) to actually grant the claim, then sign out/in on that account to pick up the new token — the email fallback can be deleted from `firestore.rules` once that's confirmed working |
| DB schema | **v11** (`is_auto`/`bike_confidence` on `rides`, plus `auto_detections`/`auto_fixes` for auto-tracking, added 2026-08-16 — `auto_tracking_plan.md`). v10 added `outbox`, the offline write queue (`Issues.md` §25); v9 added `rides.moving_s`; v7 added `custom_label` on `maintenance_logs` |
| Offline writes | Anything the rider explicitly asked for that needs the cloud goes through `core/cloud/outbox_service.dart`, **not** a bare `await` on Firestore. An awaited Firestore write with no connection never completes — it doesn't throw — so a direct `await` on a user-facing path hangs the app. `SyncManager` drains the queue on connectivity change, login, and its 5-minute timer. Optional telemetry uses `_bestEffortWrite()` (same idea, just a timeout, no durability) |

---

## Part 2 — Feature Backlog & Ideas

Ideas surveyed against competitor apps, not yet scheduled into a phase.
Effort/tier tags (`T1`/`T2`/`T3`) are rough sizing, not commitments.

### Competitor-inspired feature map (Rever · Calimoto · Detecht · Tonit · EatSleepRide · Strava · Life360)

#### A. Ride intelligence & analytics — make the data ThrottleIQ already collects *mean* something
ThrottleIQ's edge is that it already captures accel + jerk per point; competitors mostly show speed/distance. Lean into it.

| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Lean-angle tracking** per ride (max + per-corner), from gyroscope fused with GPS heading. The single most-loved moto-app stat. `sensors_plus` already provides the gyro. | Calimoto, EatSleepRide | M / **T1** |
| **Personal records & trophies** — longest ride, biggest riding day, smoothest ride (lowest jerk/km), most km in a month. Local-only at first; no backend needed. | Strava | S / **T1** |
| **Weekly riding report** — distance, time, events (hard brakes / rapid accel / top speed), trend vs last week. Reuses the riding-score math; render with `fl_chart` (already a dep). | Life360 driver reports, Strava | S / **T1** |
| **Smoothness score trend** — a per-ride 0–100 score charted over months, "your braking got 12% smoother". Turns the jerk data into a retention loop. | Life360 driver reports | M / **T1** |
| **Year in Review ("ThrottleIQ Wrapped")** — shareable summary card: total km, hours, top speed day, favorite road. Big organic-growth lever, cheap once stats exist. | Strava Year in Sport | M / **T2** |
| **Segments & leaderboards** on popular road stretches. Needs cloud + user mass + safety framing (time-based leaderboards encourage speeding — consider *smoothness* leaderboards instead: on-brand and defensible). | Strava, Rever challenges | L / **T3** |

#### B. Routes & discovery — give riders a reason to open the app *before* the ride
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Saved routes library** — save a past ride as a named route, re-ride it, share it. | All moto apps | M / **T2** |
| **Discover roads from friends' rides** — a shared ride doubles as a route others can save. Falls out of the social feed + saved routes. | Tonit, Calimoto | M / **T2** |
| **Curated "best roads nearby"** — admin-seeded scenic/twisty roads (same admin-verified pattern as the POI directory; a road is just a POI with a polyline). | EatSleepRide (editorial routes), Rever (Butler Maps) | M / **T2** |
| **Ride replay** — animated playback of the polyline with speed/lean overlays on the summary map. High wow-factor, purely client-side. | Rever 3D flyover (lite version) | M / **T1** |
| **Weather along the route / at destination** — one API call (e.g. OpenWeather) on the record screen: "Rain expected in 2h". Rever Pro charges for this. | Rever Pro | S / **T2** |
| **Curvy-route planner + turn-by-turn voice navigation** — the core of Calimoto/Rever. Needs a routing engine (Valhalla/GraphHopper with custom cost functions), offline maps, voice guidance. A product in itself — do NOT attempt before the tracker is solid. | Calimoto, Rever, Detecht | XL / **T3** |
| **Pre-ride multi-stop trip planner (scoped down)** — From/Destination/Stops list, date/time, distance/time estimate derived from the rider's own past routes — deliberately **not** the routing-engine item above. A real gap for the touring/enthusiast segment, seen as a strength in a rival BD app; this is the 80%-of-the-value cut that avoids a recurring maps-API cost. Not yet started as of 2026-08-28. | competitor analysis | M / **T2** |

#### C. Safety — extend crash detection into a full safety suite (the most defensible theme for a BD-market app)
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Crash escalation ladder** — countdown, then: notify contacts → if no contact ACKs within N min, SMS all contacts with last location + a "call rider" deep link. Detecht escalates to a human SOS operator; contacts-only is the right V1 scope. | Detecht (60s countdown), EatSleepRide CRASHLIGHT, Life360, Rever Pro | (P1) |
| **"Arrived safely" place alerts** — rider sets a destination; contacts on the live link get an automatic arrive/leave notification (geofence on the live session). Kills the "reached?" text message. | Life360 place alerts | S / **T2** |
| **Privacy zones** — auto-hide the first/last ~200 m of shared rides so home location never leaks. **Prerequisite for ANY ride sharing** — build it, don't defer it. | Strava | S / **T2** (required) |
| **Battery + staleness on the live link** — viewer sees rider's phone battery % and "last seen Xs ago" (Life360 validates surfacing low-battery alerts to the contact). | Life360 | S / (P1) |
| **Hazard pins** — riders drop "pothole / gravel / police check / flood" pins that appear for nearby riders; auto-expire after 24–48h. Same Firestore geo layer as the POI directory. | Detecht hazard warnings | M / **T2** |
| **Group-ride live map** — every member of a group ride sees the others as pins; "regroup" alert if someone falls > X km behind. Extends the live-session doc to a shared session. | Calimoto group rides, EatSleepRide ride groups, Life360 circles | M / **T2** |

#### D. Community & gamification — retention once the tracker earns trust
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Challenges & badges** — monthly distance challenges ("500 km in July"), streaks, milestone badges (first 1,000 km). Local badges already exist (`stats` screen) — add community challenges next. | Strava, Rever, Tonit | S local / M community · **T1→T2** |
| **Ride feed with kudos + comments** — share a ride card (map thumbnail, stats) to a friends feed; respects privacy zones. This is what the Social tab's Feed already does at a basic level — extend with kudos. | Strava, Tonit, Detecht | M / **T2** |
| **Clubs / riding groups** — join local clubs, group chat-lite (announcements), club ride events. | Tonit (its whole product) | L / **T3** |
| **Events & meetups calendar** — club rides and meetups with RSVP; pairs naturally with group-ride live map. | Tonit | M / **T3** |

#### E. Garage & ownership — deepen the existing maintenance moat
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Odometer auto-sync** — ride distance auto-advances each bike's odometer, driving maintenance reminders without manual entry. | (ThrottleIQ-native; no competitor does this well) | S / **T1** |
| **Fuel log** — liters + cost per fill-up → cost/km and mileage (km/L) trends. Huge in cost-sensitive markets; pairs with fuel-pump POIs ("log a fill-up at this pump"). A rival BD app ships a dedicated fuel-log tab; lower priority than the trip planner or the localization pass above, but a real, cheap gap once those land. Not yet started as of 2026-08-28. | Fuelio/Drivvo (adjacent category) | M / **T1** |
| **Documents wallet** — registration, insurance, license photos with expiry reminders. BD riders face frequent document checks; low effort, daily utility. | (market-native idea) | S / **T1** |
| **Resale story** — a bike's full maintenance + ride history as an exportable PDF ("full service history, 92% smooth-riding score") to boost resale value. | (ThrottleIQ-native) | M / **T2** |

### Proposed information architecture (UX pass)

The current nav (Social · Rides · **Record** · Places · Garage, see
`Features.md`) is real and already close to this proposal. This is a
forward-looking reorg if the backlog above gets built out — not yet
implemented:

```
┌──────────┬──────────┬──────────┬───────────┬──────────┐
│   Home   │ Explore  │ ● Record │  Analytics│ Profile  │
├──────────┼──────────┼──────────┼───────────┼──────────┤
│ Feed +   │ POIs     │ (center, │ Rides list│ Garage   │
│ challenges│ hazards │ default, │ trends    │ Service  │
│ friends' │ routes/  │ big CTA) │ records   │ Fuel log │
│ rides    │ best     │ live map │ score     │ Documents│
│ weekly   │ roads    │ quick-   │ year-in-  │ Friends  │
│ report   │ nearby   │ fuel     │ review    │ Emergency│
│          │ weather  │ SOS      │           │ contacts │
└──────────┴──────────┴──────────┴───────────┴──────────┘
```
- **Record stays the center tab and default screen** (unchanged — it's the product).
- **Explore** would fold in POI map + hazard pins + saved/curated routes + weather chip (Places already covers the POI half).
- **Analytics** would fold in ride history, trends, records, weekly report (Rides already covers the core of this).
- **Home** hosts the feed/challenges (Social's Feed tab already covers this).
- **Profile** would absorb Garage + Service, plus fuel log, documents, friends, emergency contacts, privacy settings.
- Safety actions (share live link, SOS) live ON the record/active-ride screens where the rider needs them — big touch targets, one-thumb reachable (44pt+ targets, no precision taps at speed; gloved hands argue for oversized controls throughout the ride surfaces).

---

## Part 3 — Vehicle State Engine: Architecture & Roadmap

_Last updated: 2026-07-23 · Branch: `main`_

### 0. Vision

ThrottleIQ shouldn't be thought of as "a GPS speed tracker." It should be
thought of as a **vehicle state estimation engine**. The output isn't GPS
coordinates — it's a `VehicleState`: timestamp, position, altitude, speed,
acceleration, heading, angular velocity, a confidence score, motion
classification flags (moving/stopped/cornering/braking/accelerating), sensor
quality signals, and (eventually) a map-matched road. Everything else —
ride recording, crash detection, ride scoring, future analytics — reads from
that object instead of computing speed/accel/heading independently in
different places.

That's the target architecture. This doc is honest about how much of it
exists today, phases the rest, and records why each phase was scoped the way
it was.

### 1. The 10-layer architecture — current state

| # | Layer | Status |
|---|---|---|
| 1 | Sensor collection | 🟡 Partial — GPS + accelerometer collected; gyroscope now collected (Phase 1); magnetometer unused |
| 2 | Validation | ✅ Phase 1 — `SensorValidator`, single source of truth |
| 3 | Time synchronization | ⬜ Not built — deliberately unneeded for a complementary filter (see §3) |
| 4 | Sensor fusion | 🟡 Phase 1 — complementary filter, not a full Kalman/EKF (see §3) |
| 5 | Confidence engine | ✅ Phase 1 — heuristic 0-100 score |
| 6 | Motion classification | ✅ Phase 1 — isMoving/isStopped/isCornering/isBraking/isAccelerating |
| 7 | Event detection | 🟡 Pre-existing (`EventDetector`) — untouched in Phase 1, gained one confidence gate on crash alerts |
| 8 | Adaptive recording | ✅ Phase 1.5 — thins what's *persisted* on confident/steady stretches (see §4); GPS hardware polling itself is still fixed 5m/1s |
| 9 | Map matching | ⬜ Deferred entirely (see §5) |
| 10 | Analytics | 🟡 Pre-existing (`rider_stats.dart`, `riding_score.dart`, badges) — untouched, reads ride-level aggregates only |

**Before Phase 1**, layers 2-6 didn't exist at all: GPS and the accelerometer
were two completely disconnected pipelines. `MotionCalculator` derived
`acceleration`/`jerk` purely from consecutive GPS speed samples; the
accelerometer was separately low-pass filtered and used *only* for instant
haptic alerts — never persisted, never reaching `EventDetector`. The
gyroscope and magnetometer were entirely unused despite being available in
`sensors_plus`. No heading was computed anywhere despite `Position.heading`
being available. There was no confidence concept — a crash alert fired on
threshold math alone, with no way to know whether the underlying sensor data
was trustworthy at that moment.

### 2. Phase 1 — Foundation (done, 2026-07-23)

Built: `VehicleState` (unified per-tick entity), `SensorValidator` (single
source of truth for "is this sample garbage"), `VehicleStateEstimator` (the
complementary-filter fusion engine), gyroscope now wired in alongside the
existing accelerometer stream, a heuristic confidence/imuQuality score,
motion classification, and a confidence gate on the crash-detection alert
path (don't act on a crash signal derived from garbage sensor data, e.g.
mid-tunnel GPS loss).

**What Phase 1 deliberately did NOT change**, to keep blast radius small and
protect existing test investment:
- `MotionCalculator` (GPS-derivative speed/distance/accel math, 567 lines of
  existing test coverage) — untouched. `VehicleState`'s heading/confidence/
  classification is an **additive parallel pipeline**, not a replacement.
  `VehicleState.accelerationMs2` is still GPS-derivative, not IMU-fused —
  fusing the accelerometer into the persisted acceleration value is real
  signal-processing work (the phone's mounting orientation is unknown/
  arbitrary — see the existing "dominant axis" heuristic on the haptic
  alert path) and touches the one code path with the deepest existing test
  investment. The IMU is used for what it's uniquely good at instead:
  heading dead-reckoning between GPS fixes, motion classification, and
  confidence scoring.
- `EventDetector`'s public signature — untouched, protects
  `crash_detector_test.dart`. Only what its caller passes it changed (the
  confidence gate).
- The existing accelerometer-driven haptic alert path (`_onSensor`'s
  dominant-axis low-pass filter) — untouched, works today, no reason to risk
  it without live-device testing available in this environment.
- No UI/screen changes. `RideRecordingState` gained one plumbing field
  (`confidence`) so a future screen can surface it cheaply — nothing
  currently displays it.

**Database**: `ride_points` schema v5→v6 adds 4 nullable columns —
`heading_deg`, `confidence`, `imu_quality`, `is_cornering`. Deliberately
*not* persisted: `isBraking`/`isAccelerating` (exactly reproducible from the
already-stored `acceleration` column via the existing thresholds) and
`isMoving`/`isStopped` (already encoded by the existing `periodType`
column) — avoiding redundant schema bloat.

**Why this is the future ML training corpus**: the AI State Estimator idea
(§6) needs a real corpus of labeled ride data to be anything but a guess.
Phase 1 persists `confidence`/`heading`/`isCornering`/`imuQuality` per point
now, even though nothing consumes them yet, specifically so that corpus is
already accumulating by the time Phase 4 becomes viable — additive later,
not a rewrite.

### 3. Phase 2 — Full EKF (future, not started)

Replace `VehicleStateEstimator`'s internals with a proper Extended Kalman
Filter — a real state vector (position×2, velocity×2, heading, yaw-rate,
possibly an accel-bias term), covariance propagation, and Jacobians for the
nonlinear GPS-lat/lng-vs-local-frame relationship.

**Why not now**: an EKF's value is entirely in its noise tuning (process
noise Q, measurement noise R), and tuning those blind — without a real
corpus of ride logs to validate against — is more likely to produce a filter
that's confidently wrong than one that's actually better than the
complementary filter it replaces. The complementary filter degrades
gracefully with imperfect constants; an EKF with bad tuning can diverge.
Phase 1's persisted `VehicleState` data is exactly the corpus this phase
needs to exist first.

**Known prerequisite**: `vector_math` is only a *transitive* dependency
today (pulled in by `flutter_map`), not declared in `pubspec.yaml`, and is
capped at 4×4 matrices — a realistic EKF state vector needs more. Either
promote it to a direct dependency and hand-roll the matrix math, or add a
proper linear-algebra package. Not resolved now.

**Design constraint carried over from Phase 1**: `VehicleStateEstimator`'s
public interface (`addGpsSample`/`addAccelSample`/`addGyroSample`/
`currentState`) was kept intentionally minimal and sample-driven so this
phase can replace the class's *internals* without changing any of its
callers.

### 4. Phase 1.5 — Adaptive recording (done, 2026-07-23)

**Important scoping clarification found while building this**: geolocator
doesn't support changing GPS polling settings mid-stream, so this phase does
**not** touch the underlying 5m-distance/1s-interval GPS sampling rate —
that stays exactly as fixed as it was in Phase 1. What it actually adapts is
which fixes get **persisted** to `ride_points`: a new `RecordingCadencePolicy`
(pure, unit-tested, same pattern as the other calculators) throttles writes
to at most one per `SensorConstants.minPersistIntervalOnSteadyStretches`
(5s, matching the original vision's own "1 point every 5 seconds on a
straight highway" example) whenever `VehicleState.confidence` clears a
conservative floor (70/100) and none of cornering/braking/accelerating are
true. Anything "interesting," or anything the fusion engine isn't
confident about, is always kept at full fidelity.

**Confirmed real trade-off, not just a storage optimization**: both
`ride_summary_screen.dart` and `ride_share_screen.dart` rebuild their
polyline by reading `ride_points` back from the DB — so thinned writes
directly mean a visibly lower-resolution polyline on boring stretches, not
just a storage-only change invisible to the rider. This was confirmed and
explicitly signed off on before building it, rather than assumed.

**What stays untouched, deliberately**: the live in-ride map polyline
(`RideRecordingState.polyline`) still appends every GPS fix, unthinned —
only the post-ride replay/summary/share view is affected. The ride-level
aggregate stats (`distanceM`/`avgSpeedMs`/`maxSpeedMs`) and
`MotionCalculator`'s accel/jerk derivative chain (`_lastPoint`) both still
see every consecutive GPS fix regardless of the persistence decision —
thinning only gates the one `_pointBuffer.add(...)` call.

### 5. Phase 3 — Map matching (deferred entirely)

Snapping GPS to the actual road (`estimatedRoad` on `VehicleState`, always
null today) needs an external road-network source. Two options were
surfaced but **neither was chosen or built**:
- **OSRM's public demo server** — free, no signup, same "free public API"
  precedent as the existing Overpass POI-import integration. Rate-
  limited and not meant for production traffic, so it would need a real
  backend swap before launch.
- **A paid map-matching API** (e.g. Mapbox Map Matching) — production-grade,
  but a recurring cost and a new API key/secret to manage, which this
  project doesn't have any infrastructure for today.

This is a genuinely separate initiative from the fusion engine and doesn't
block anything else in this roadmap. Revisit when it's actually prioritized.

### 6. Phase 4 — AI State Estimator (deferred, designed for)

The original pitch: instead of relying solely on fixed thresholds (hard
brake if decel < -4 m/s², crash if accel > 80 m/s² etc.), train a
lightweight on-device model on a real corpus of rides to recognize patterns
— smooth vs. aggressive riding, urban commuting vs. highway touring,
pothole impacts vs. crash impacts, typical behavior for a specific rider.
The model would sit on top of the fused `VehicleState`, not replace it,
learning what's "normal" per-rider over time.

**Why not now**: the app is pre-launch with no ride corpus to train on —
building this now would mean guessing at a model architecture and training
process against data that doesn't exist yet. **Why it's still designed
for**: Phase 1's persisted per-point `confidence`/`heading`/`isCornering`/
`imuQuality` fields are exactly the kind of clean, structured, per-tick
labels a future model would want. Revisit once there's a real corpus of
completed rides (post-launch, real usage) to work from.

### 7. Open items / honest limitations

- **No live sign-in/ride walkthrough was possible for Phase 1 or 1.5** —
  same environment limitation as previous sessions (no simulator
  input-automation tool available to sign in and record a real ride).
  Verified instead: full unit-test suite (`sensor_validator_test.dart`,
  `vehicle_state_estimator_test.dart`, `recording_cadence_policy_test.dart`,
  282 tests total, all green), `flutter analyze` clean, and a clean
  `flutter run` boot confirming Phase 1's v5→v6 schema migration applies
  without error (Phase 1.5 has no schema changes of its own). A real
  device/ride walkthrough — confirming GPS+gyro actually produce sensible
  confidence/heading values in practice, watching the thinning policy
  actually behave sensibly on a real commute, and tuning the heuristic
  constants (imuQuality penalties, confidence weights, cornering threshold,
  the thinning confidence floor and interval) against real riding — remains
  the first thing to do once this is testable on a real device.
- **iOS location settings**: `_startLocationStream()` unconditionally
  constructs an `AndroidSettings` object with no `IOSSettings`/
  `Platform.isAndroid` branch — pre-existing, not introduced or fixed by
  this work, just noted while reading the file closely.
- **imuQuality/confidence formulas are first-pass heuristics**, explicitly
  expected to need real-device tuning — same honest framing as the
  crash-threshold fix ("user will fine-tune with real rides").
