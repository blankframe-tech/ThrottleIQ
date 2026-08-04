# ThrottleIQ — Handoff Document

_Last updated: 2026-08-03 · Branch: `main`_

This is the single living handoff doc for the project: current status, known
limitations, the near-term to-do list, the longer-term feature backlog, and
the Vehicle State Engine architecture/roadmap. Update it (don't fork a new
doc) whenever status changes — see `.claude/settings.json` for the hook that
prompts this after every work session. Feature-by-feature UI detail lives in
`Features.md`; tracked defects live in `Issues.md`.

**Contents**
- [Part 1 — Status & Handoff](#part-1--status--handoff)
- [Part 2 — Feature Backlog & Ideas](#part-2--feature-backlog--ideas)
- [Part 3 — Vehicle State Engine: Architecture & Roadmap](#part-3--vehicle-state-engine-architecture--roadmap)

---

## Part 1 — Status & Handoff

### TL;DR — where things stand

As of 2026-08-02, the app is pre-launch at **`1.0.0-beta.2+2`, tagged
[`beta-v2`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v2)**
— that release carries both a signed APK (for handing to testers directly)
and an AAB (for the Play Console), and is the build intended for the 12-dev
closed-testing group. `beta-v1` remains on GitHub as the previous build.
Core ride-recording, garage, maintenance, social, POI-directory, and
forum features are built and wired end-to-end — the 2026-07-14 audit's
orphaned screens (crash countdown, sync manager, exports, emergency
contacts, live share) have all since been wired in, see "Done, but NOT yet
verified" below. The Vehicle State Engine's foundation (Phase 1 + 1.5 —
sensor fusion, confidence scoring, motion classification, adaptive
recording thinning) shipped 2026-07-23, and the test suite is **550/550
green** as of 2026-08-03.

**Versioning reset 2026-08-01:** the old `2.0.0-beta.x` line, its git tags,
and all prior GitHub Releases (including the same-day `carbon-ui-` one)
were deleted in favor of a clean `1.0.0-beta.1+1` / **Beta v1** start —
that was the first build meant for external (non-owner) hands (the line has
since moved on to `beta-v2`; see the TL;DR above for current state). The
`carbon-mono` branch was also deleted; `main` now carries both UI modes via
the runtime theme toggle below, so the branch no longer serves a purpose.

**Backlog pass, 2026-08-01 (later the same day):** the whole of
`TODO next.md` and the codeable half of the "To do" list below were worked
through in one session. Landed: forum moderation + rider-created forums,
ride captions + Strava-style route maps on feed cards, a `recreation`
place category, **saved routes with offline turn-by-turn navigation**
(new `features/routes/`), expanded + rider-nameable maintenance types,
the maintenance bottom-nav bug fix, average speed redefined as
distance ÷ moving time, GPS trail sync, **home-screen widgets** (Android
working; iOS needs one Xcode step), the published privacy policy, and
beta data-reset tooling. Test suite went 287 → **550**.

**Three real defects were surfaced and fixed along the way** — all worth
reading in `Issues.md`: live-share sessions were **world-listable** by
unauthenticated clients (§3), the planned live-session TTL policy could
never have deleted anything (§4), and the GPS-trail sync **crashed the app
outright** (§11).

⚠️ **If you handed anyone the `beta-v2` build, it crashes.** That release
(2026-08-01) contains the nested-array trail upload: Firestore refuses the
payload with a native exception that Dart cannot catch, so the app aborts
from a background timer shortly after any ride syncs — no user action
involved, which is why it read as random. Fixed 2026-08-03 in `1fca84e`.
**Cut a beta-v3 before the 12-dev group gets anything**, and don't
diagnose crash reports against beta-v2.

**Pitch site added, 2026-08-02:** a static, dependency-free pitch/marketing
page now lives at `website_demo/index.html` (was an empty placeholder
folder before this), plus `website_demo/ui.html` — a real-UI preview page
(headless-screenshotted from the `designs/` Carbon Mono / Editorial mockup
HTML, saved to `designs/screenshots/`) linked next to Roadmap. No app code,
behavior, or build changed — this is collateral only, not shipped with the
app.

**Hooked Model doc added, 2026-08-02:** `docs/hooked_throttleiq.md` applies
Nir Eyal's Trigger/Action/Variable-Reward/Investment framework to the app,
grounded in the actual codebase (what's live vs. dormant/absent — e.g.
badges and rank-up fire with no celebration moment, `ChallengeType.streak`
is an unused enum, no push/scheduled notifications exist at all yet). It
explicitly avoids re-listing what's already backlogged in Part 2 below;
read it alongside Part 2 rather than as a competing plan.

**Marketing doc added, 2026-08-02:** `docs/marketing.md` — a BD-market
go-to-market plan for the Play Store → iOS TestFlight → App Store launch
sequence, targeting 1,000+ DAU. Surfaced two real, checked gaps worth
fixing before spending on acquisition: `public/live-viewer.html` has no
install call-to-action at all, and there's no Bangla anywhere (UI or Play
Store listing). Builds on `hooked_throttleiq.md` for retention rather than
duplicating it.

Every judgement call made along the way is written up in
`Assumptions Made.md` — read that before questioning why something was
scoped the way it was.

**Just shipped (earlier that day):** a rebrand / theming pass — a new dual theme system
(*Carbon Mono* dark instrument-panel theme, default, vs. *Editorial* light
warm-paper theme; `app_theme_style.dart` + `theme_style_provider.dart`)
wired into Settings' Appearance section, new logo/icon assets
(`app/assets/icons/throttleiq-icon-{dark,light}.svg`) replacing the old
`designs/logos1/` set, and a docs cleanup that removed a dozen stale
planning docs in favor of this file, `Features.md`, and `Issues.md`. The
default (Carbon Mono) theme has been run and screenshotted on the iOS
Simulator, and Beta v1 was run in release mode on a physical iPhone before
this release went out — see "Done, but NOT yet verified" for exactly
what's still unproven (the Editorial toggle itself hasn't been tap-tested
live on a device, only exercised via new automated provider tests).

**iOS install failure — root-caused 2026-08-04. Previously mis-diagnosed
here as a timing "flake"; that was wrong.**

Symptom: `flutter run --release -d <device>` fails at install with the
useless "Could not run ... Try launching Xcode". Sometimes an immediate
retry appeared to fix it, which is what made it look like a flake.

**Actual cause:** `objective_c.framework` gets embedded **ad-hoc signed**
(`flags=0x2(adhoc)`, `TeamIdentifier=not set`) while every other framework
carries the Apple Development identity. iOS refuses to install a bundle
containing an ad-hoc-signed framework. `codesign -vvv` reports the
framework "valid on disk", so it looks fine — you have to check the
*identity*, not validity.

That framework comes from `path_provider_foundation` → `objective_c`,
which builds via Flutter's **native-assets / build-hooks** system (the
same subsystem behind the `Target native_assets required define SdkRoot
but it was not provided` warning in build logs). Stale native-asset output
gets re-embedded without re-signing.

**Fix: `flutter clean && flutter pub get`, then rebuild.** That forces the
native-assets step to re-run and the framework to be signed properly —
verified: `flags=0x0(none)`, Apple Development identity, installs first
try with no retry.

**Getting the real error.** `flutter run` hides it. Use:
```
xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app
```
which names the offending framework and the `0xe8008014` code directly.
Then compare identities:
```
codesign -dvv build/ios/iphoneos/Runner.app/Frameworks/<name>.framework
```
Ad-hoc means the build didn't re-sign it; clean and rebuild.

Related: `flutter devices` often can't see the iPhone at the default
timeout even when `xcrun devicectl list devices` reports it as
`available (paired)`. Use `--device-timeout 30`; the device shows up.

### Known Limitations (Documented, Not Bugs)
- ~~**Avg speed still mean-of-samples**~~ **FIXED 2026-08-01** — now distance ÷ moving time (`average_speed.dart`), with stopped time excluded via the same `speed < 1 m/s` cutoff the recorder already stamps as `period_type`. Gaps over 60 s (tunnel / suspended app) aren't counted rather than guessed at.
- **Navigation is geometric, not routed** — turn-by-turn follows a saved route's own polyline: no street names, no lane guidance, and no rerouting (it reports "off route" instead). Deliberate: no routing engine or API key exists. See `Assumptions Made.md`.
- **Sensor calibration**: Still heuristic (GPS fusion deferred to v1.1)
- **POI search**: Geohash-based (simple), not real-time autocomplete
- **Offline-first limit**: ~10MB local DB on typical device; cleanup policy on rotation
- **No payment yet**: All features free in V1; premium tier (crash escalation, weather) deferred to P8+
- **Backend analytics**: Firebase Analytics wired but dashboards not built
- **Admin panel**: Moderation done via Firebase console (write rules for admin claim)
- **ML features**: Crash/pothole detection logic in code; TF Lite model not included

### Deployment & CI/CD
- **Build**: `flutter build apk` for Android; `flutter build ios` for iPhone
- **Firebase**: Console-deployed Firestore rules (see `firestore.rules` in repo)
- **Distribution**: Play Store (internal testing), TestFlight (iOS), GitHub Releases (APK)
- **Environment**: TIPSOI_MOCK=0 (live API) in prod; dev uses same unless testing offline

### Phase priorities (roadmap ordering)
1. **P1**: Emergency contacts + crash detection with countdown UI
2. **P2**: POI map + directory + ratings
3. **P3**: Shared routes, group rides
4. **P4**: Turn-by-turn routing, club managers

> ⚠️ **Correction (2026-07-14, after a code audit):** several P5–P8
> features existed at the time as **logic/data layers only, with no UI
> wired to them**: the crash countdown modal (state existed, no widget
> rendered it), SyncManager (never instantiated → rides stayed local-only),
> JSON/GPX export (no button), emergency contacts (no screen), live-share
> (no share button; viewer unhosted), the POI directory (no presentation
> layer at all), and the social feed/routes/group-ride screens (files
> existed but were orphaned — the Social tab showed a "Coming in V2"
> placeholder). **Status: resolved** — see "Now (before inviting beta
> testers)" below, all marked done 2026-07-14, and confirmed present in
> code as of this 2026-08-01 pass (see `Features.md`).

---

## ⚠️ Done, but NOT yet verified

These exist in code/config but have never been exercised against the real
backend or a real device. **Treat each as unproven until tested.**

- [x] ~~**On-device behaviour**~~ **PARTIALLY VERIFIED 2026-07-23** — the project owner has now tested the live app directly (see §8/§8a/§8b history), surfacing several real bugs since fixed. Still open specifically: a real ride with the screen off for several minutes, to confirm the mid-ride-kill data-loss fix (§8b) actually holds.
- [x] ~~Unit/widget test suite~~ **VERIFIED 2026-07-14** — 184/184 green.
- [ ] **Google sign-in end-to-end** — config + code are in place; needs one real tap-through on a device.
- [ ] **Firestore rules under real traffic** — rules deployed but only compiler-checked; exercise with a real account (read own rides, fail reading someone else's).
- [x] ~~Live-share viewer~~ **HOSTED 2026-07-14** at `throttleiqfb.web.app/live/{token}` (HTTP 200 verified); end-to-end with a live ride still needs a device test.
- [x] ~~**Simulator smoke test of the backlog pass**~~ **PARTIALLY VERIFIED 2026-08-01** — run on the iPhone 17 simulator (iOS 26.5) against a real signed-in account. Confirmed rendering correctly: the Carbon Mono theme; the Forums "Your bikes" list showing **both** brand and model forums from real garage data; the Create-a-forum screen; the Routes list and its Discover tab; the new Recreation category chip in Places; and **feed cards drawing the ride's route map beside the photo**, with the "No route recorded" placeholder for rides with no track. This run found three real defects that the test suite could not — two missing Firestore composite indexes and the Routes reachability/back-button problems (`Issues.md` §5 and §6), all since fixed and deployed. Still not exercised: recording an actual ride, and everything below.
- [ ] **The rest of the 2026-08-01 backlog pass** — forums moderation, ride captions, saving a route, turn-by-turn navigation, expanded maintenance types, the moving-time average speed. Verified by `flutter analyze` (0 errors), 550 passing tests, and release builds — **none of it has been exercised by actually riding.** The riskiest untested paths, in order:
  1. **Turn-by-turn navigation** — the geometry is unit-tested, but nothing has confirmed the banner advances sensibly at real road speeds, or that the 30 m "turn reached" / 100 m "off route" thresholds feel right on an actual bike. Tune these from a real ride.
  2. **The deployed Firestore rules** — forum moderation and route publishing were written and deployed but never exercised against a live account. Confirm a maintainer really can delete a post, and that a non-maintainer really can't.
  3. **The `SharedPreferences` garage-forum cache** — verify adding a bike actually refreshes the "Your bikes" list rather than serving a stale cache.
  4. **DB schema 6 → 7** (`custom_label` on `maintenance_logs`) — migration is written but has only ever run on a fresh install here. Test an *upgrade* over an existing install.
  5. **GPS trail sync** — record a ride, let it sync, reinstall, and confirm the ride's polyline comes back rather than an empty map.
  6. **Home-screen widgets** — Android widgets are confirmed *present in the built APK* (via `aapt2`) but have never been added to a real launcher. Add all three, confirm they show placeholders before any data and real values after a ride, and that the Start-ride widget opens on Record.
  7. **Ride with friends** — needs **two real accounts on two devices**: invite, confirm the invitee sees the in-app notification, accept, and confirm both riders appear on each other's map in different colours and that stale positions grey out. The deployed `groupRides` rules have never been exercised by a real client — and since the roster moved to a subcollection (`Issues.md` §10), the invite → accept → leave path is the specific thing to exercise. Its rule correctness is reasoned, not executed; there's no rules-test harness in this repo.
  8. **Bike visibility** — confirm another rider can see your bikes on `public`, cannot on `private`, and that `followers` tracks the follow edge. Note this rules change *widened* read access (`Assumptions Made.md` #15).
  9. **Bike deletion** — the deadlock is fixed and covered by real-SQLite tests, but confirm on a device that deleting a bike with rides actually removes it and its history.
- [x] ~~Carbon Mono / Editorial theme toggle — default theme~~ **PARTIALLY VERIFIED 2026-08-01** — ran on the iOS Simulator, screenshotted the Record screen: dark Carbon Mono palette, lime accents, sharp corners, and IBM Plex type all render correctly by default. The Editorial toggle in Settings itself was **not** tap-tested live (no `idb`/`cliclick` in this environment, and scripted macOS clicks need an Accessibility grant that wasn't available) — instead it's covered by 5 new tests in `test/core/theme/theme_style_provider_test.dart` exercising the tap → notifier → palette-swap → persistence path directly. Writing those tests caught a real bug, since fixed: `ThemeStyleNotifier._loadPersisted()` could crash with "used after dispose" if the notifier were torn down while its `SharedPreferences` read was still in flight — now guarded with a `mounted` check. Still open: an actual finger-tap of the Settings toggle on a device/simulator.

---

## 📋 To do

### Now (before inviting beta testers)
- [x] ~~**Deploy `firestore.rules` + hosting**~~ **DONE 2026-08-04.** Both
  released to `throttleiqfb`. Verified against the live project rather than
  assumed:
  - `/r/{username}` and `/live/{token}` both serve the viewer (HTTP 200),
    and the deployed HTML contains the permanent-link resolution code.
  - An **unauthenticated** `get` of `usernames/{handle}` returns
    **404 NOT_FOUND, not 403** — i.e. the read is permitted and the handle
    simply doesn't exist. This is the check that mattered: a 403 would have
    meant the rule was still auth-gated and the permanent link would be
    broken for every visitor, since the whole point is that whoever opens
    the link does **not** have the app.
  - `usernames`, `livePointers` and `liveSessions` all return
    **403 PERMISSION_DENIED** on an unauthenticated `list` — the §3/§14 bug
    class is closed in both new places it appeared.

  **Re-run `firebase deploy --only firestore:rules,hosting` after any
  future edit to `firestore.rules` or `firebase.json`** — neither ships
  with the app, and a rules change that isn't deployed silently does
  nothing.
- [x] ~~Wire the orphaned features~~ **DONE 2026-07-14**: crash countdown overlay, SyncManager bootstrap, export buttons, Settings screen (logout + emergency contacts) all wired; live viewer deployed to `throttleiqfb.web.app`. Remaining genuine builds: POI UI and a real social feed (the agent "screens" were empty stubs).
- [ ] **Back up the signing keystore** — `throttleiq-release.keystore` + `app/android/key.properties` exist ONLY on the dev machine. If lost, the app can never be updated under the same identity. → password manager / secure cloud, never git.
- [ ] **Install the beta APK on a real phone** and run the smoke test: register → record a ride → stop → summary → confirm the ride appears in Firestore console.
- [x] ~~Run the test suite~~ **DONE 2026-07-14** — 184/184 green (fixed a real EventDetector regression + bad test expectations found on the first-ever full run).
- [x] ~~Deploy the live-share viewer~~ **DONE 2026-07-14** — hosted at `throttleiqfb.web.app` (verified 200); the app's share links point there.

### Soon (requires Blaze pay-as-you-go plan — still ~$0/mo at beta scale)
- [ ] **Cloud Functions** — deploy `functions/` (crash-notification escalation). Currently SMS/email are mocked; wire Twilio (SMS) and/or SendGrid (email) with real credentials via functions config.
- [x] ~~Firebase Storage bucket~~ **SUPERSEDED 2026-07-23** — the project owner has no payment card, and Storage now requires Blaze even within its free tier. Avatar/photo uploads moved to Cloudinary instead (cloud name `vjvcigkt`) — no bucket needed.
- [ ] **Firestore TTL policy** on `liveSessions.expiresAt` so expired live-share docs auto-delete. The app-side blocker is fixed (those fields are real `Timestamp`s now, not ISO strings — see `Issues.md` §4). **Two ways to apply it; pick either.**

  **A — Firebase console, no install needed (easiest):**
  1. Open [Firestore → Time-to-live](https://console.firebase.google.com/project/throttleiqfb/firestore/ttl)
  2. **Create policy** → Collection group `liveSessions`, timestamp field `expiresAt`
  3. Save. It takes up to ~24 h to start reaping, and deletions are best-effort — Google does not promise deletion at the exact expiry instant.

  **B — gcloud** (installed 2026-08-03, SDK 578.0.0, on PATH — but still needs an interactive `gcloud auth login` before this will run):
  ```
  gcloud firestore fields ttls update expiresAt \
    --collection-group=liveSessions \
    --project=throttleiqfb \
    --database='(default)' \
    --enable-ttl
  ```

  ⚠️ **This does not clean up the existing backlog.** Documents written before the Timestamp fix hold *string* expiries, and TTL ignores any non-Timestamp field — so those rows linger forever regardless of which method you use. Either delete them by hand in the console (`liveSessions` is small and pre-launch, so this is a few clicks) or accept them. Verify after enabling by checking that a session created *today* disappears within ~24 h of its `expiresAt`.
- [x] ~~**Deploy the privacy policy**~~ **DONE 2026-08-01** — live at [`https://throttleiqfb.web.app/privacy.html`](https://throttleiqfb.web.app/privacy.html) (HTTP 200 verified anonymously). Paste that URL into the Play Console listing and the Data Safety form. Content is derived from what the code actually does; re-check §1–§4 whenever the data flows change.
- [x] ~~**Sync `ride_points` (GPS trails) to Firestore**~~ **DONE 2026-08-01** (`ride_track_codec.dart` + `CloudRepository.uploadRideTrack`/`downloadRideTrack`). Trails are chunked into `users/{uid}/rides/{rideId}/track/{i}` docs of 500 positional points — one doc per point would have been thousands of writes per ride. Upload runs after the ride doc so a track can't orphan; download is on-demand and never clobbers local points. Track docs are owner-only in the rules. **Untested against a real account** — verify a reinstall actually restores polylines.

### Play Store
- [x] ~~Privacy policy page~~ **DONE** — `https://throttleiqfb.web.app/privacy.html`
- [ ] ❓ **Decide the publisher identity — blocks the listing.** The privacy policy that was replaced on 2026-08-01 named **"Blankframe.tech"** as publisher, with contact `blankframe.technologies@gmail.com`; the GitHub org is `blankframe-tech`. The new policy deliberately names **no company** — it says "an independent, solo-developer project" and uses `the.abraar.rar@gmail.com` — because inventing a legal entity in a privacy policy is not a call to make on someone's behalf. **If Blankframe.tech is the real publishing entity, the policy needs it added**, since Play Console expects the listing's developer name to line up with the policy. Old file is recoverable from git history (`store_listing/privacy-policy.html`, deleted in this pass).
- [ ] Google Play developer account ($25 one-time)
- [x] ~~Build an **App Bundle**~~ **VERIFIED 2026-08-01** — `flutter build appbundle --release` produces `app/build/app/outputs/bundle/release/app-release.aab` (57.0 MB). Rebuild it after any version bump; the artifact itself isn't committed.
- [ ] **Add the iOS widget extension target in Xcode** — see `app/ios/ThrottleIQWidget/README.md`. One-time GUI step; iOS widgets don't exist until it's done. Android needs nothing.
- [ ] Internal testing track → closed beta → production
- [ ] Bump `version:` in `pubspec.yaml` (versionCode) for every new upload

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

### Proposed features (not built — for discussion)

- 🔮 **Auto-pause in traffic.** Detect a stop (already possible — the
  recorder classifies `period_type` as moving/idle at the 1 m/s cutoff)
  and pause recording automatically, then **surface the jam time back to
  the rider after the ride**: "you spent 14 minutes stopped." That number
  is genuinely interesting in Dhaka and nobody else shows it. The data is
  already being collected — `movingSeconds` exists for the average-speed
  fix — so this is presentation plus a pause policy, not new tracking.
  Watch out for: auto-pause at a long traffic light vs. a genuine stop,
  and not double-counting against the existing manual pause.
- 🔮 **iOS start/stop widget.** The Android widget already exists and the
  iOS sources are written (`app/ios/ThrottleIQWidget/`), but iOS widgets
  can't *start a recording* from the widget itself — they can only deep
  link into the app. A true start/stop control needs App Intents
  (iOS 17+) plus background-location handoff. Worth scoping properly
  rather than assuming parity with Android.
- 🔮 **All-day auto-tracking** — detect that the rider has got on a bike
  and record without being asked. This is the single biggest retention
  idea in the backlog and also the most dangerous: it means continuous
  motion monitoring, which costs battery, needs "Always" location
  permission (a much harder App Store/Play review conversation, and a
  privacy-policy change), and produces false positives from car and bus
  journeys. Prototype the *detection* offline against recorded rides
  before committing to the permission ask.
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
- [ ] Sensor calibration via GPS fusion (current: heuristic axis pick)
- [ ] Crash-detector threshold tuning from real false-positive logs
- [ ] Geohash search → proper neighbor-table implementation (current neighbor calc is approximate)
- [ ] Weather on record screen (OpenWeather) — needs an API key, none available
- [ ] Leaderboards (smoothness-based), clubs & events
- [x] ~~Turn-by-turn navigation~~ **DONE 2026-08-01**, but *following a saved route*, not curvy-route *planning*. Planning a new route still needs a routing engine (Calimoto/Rever's core, XL/T3 — see Part 2).
- [x] ~~**Open discovered (public) routes**~~ **DONE 2026-08-02** — `?owner=<uid>` on the detail and navigate routes; read-only for non-owners.
- [ ] **Bundle a Bengali font** — IBM Plex has no Bengali glyphs, so Bangla falls back to the platform face and renders in a visibly different typeface from the rest of the UI. No tofu, but it looks wrong. Add a Bengali family and set `fontFamilyFallback` in `AppTheme`.
- [ ] **Translate the rest of the app** — only the settings screen is localized; ~700 strings are still hardcoded English. Also still open from `marketing.md`: the Play Store listing has no Bangla.
- [ ] iOS build & TestFlight (config scaffolding exists; needs a Mac + Apple Developer account)

---

## Key facts (for whoever picks this up)

| Thing | Value |
|---|---|
| Firebase project | `throttleiqfb` (asia-south1) |
| Android package (all code, `main`) | `com.bft.throttleiq` — **registered in Firebase** since 2026-07-23: App ID `1:603325098273:android:94694220f44cbf63fcf660` |
| File storage | Cloudinary (unsigned upload, cloud name `vjvcigkt`), **not** Firebase Storage — see the "Soon" section above for why |
| Signing keystore | `throttleiq-release.keystore` (repo root, gitignored) — **back it up** |
| Local pub cache / Android SDK paths | Machine-specific — whatever's in your own `flutter doctor` output, not fixed values to copy |
| Latest release | [`beta-v2`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v2) — signed release **APK + AAB**, matches `pubspec.yaml` at `1.0.0-beta.2+2`. Upload the `.aab` to Play, hand testers the `.apk`. (`beta-v1` is still there as the previous build.) |
| Test suite | 550/550 green as of 2026-08-03 (was 287 before the backlog pass). DAOs now run against real in-memory SQLite via `sqflite_common_ffi` — see `Issues.md` §7 for why that mattered |
| Privacy policy | `https://throttleiqfb.web.app/privacy.html` — live, needed by the Play listing |
| Judgement calls | `Assumptions Made.md` — every non-obvious decision from the backlog pass, with the file to change if you disagree |
| Admin account | `the.abraar.rar@gmail.com`, hardcoded in `forum_permissions.dart` AND in `firestore.rules`. Both must change together; move to a custom claim before public launch |
| DB schema | v7 (`custom_label` on `maintenance_logs`, added 2026-08-01) |

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
| **Fuel log** — liters + cost per fill-up → cost/km and mileage (km/L) trends. Huge in cost-sensitive markets; pairs with fuel-pump POIs ("log a fill-up at this pump"). | Fuelio/Drivvo (adjacent category) | M / **T1** |
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
