# ThrottleIQ — What Works & What's Next

_Last updated: 2026-07-24 · Latest release: [v2.0.0-beta.4+6](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/v2.0.0-beta.4+6) · Active branch: `main`_

> **Correction (2026-07-23):** despite this doc's history of saying
> `feat/v2-social`, no such branch was ever actually created — everything
> below is on `main` (see `HANDOFF_V2.md`'s branch note for the full story).
> The "⛔ Blocker" callout right below is also now resolved: §1 of
> `HANDOFF_V2.md` re-registered `com.bft.throttleiq` in Firebase and Epics
> F/G shipped after it, so all 8 epics are code-complete. `HANDOFF_V2.md` is
> the up-to-date single source of truth, including two more real-usage bug
> waves (§8a/§8b) that landed after this file was last substantively
> written — read that doc first; this one is kept mostly for the P0–P8
> history below, which is still accurate.

This is the honest state of the project: **Done & verified** means it was actually exercised and confirmed; **Done, not yet verified** means the code/config exists but hasn't been tested end-to-end; **To do** is future work.

---

## 🚧 v2 social rework — in progress (see `HANDOFF_V2.md` for the full plan)

**Shipped & verified on `main`:** the Editorial BW redesign (7 screens rebuilt to
`designs/ThrottleIQ Editorial BW.html`, blue accent + orange attention) →
released as `v2.0.0-beta.3+5` (signed APK on GitHub).

**On `feat/v2-social` (analyze-clean, NOT runtime-tested — Android build blocked, see below):**
- ✅ **Package rename** `com.throttleiq.throttleiq` → `com.bft.throttleiq` (code side).
- ✅ **Phase A**: user profiles (nickname/bio/photo/@username), open follow graph,
  audience-tier ride visibility, upvote/downvote + votes rules, username
  reservation — backend + Firestore rules/indexes.
- ✅ **Fix**: ride sharing no longer errors on short/near-home rides.
- ✅ **Epic B**: social UI — end→share page (photo + audience picker), feed
  search+follow, upvote/downvote on ride cards.
- ✅ **Epic C**: forums — slug bug fixed (hyphen/space/underscore now unify),
  general (non-bike) topic forums, forums-home is a list, post voting, avatars.
- ✅ **Epic D**: garage/service — bike odometer (real DB migration v4→v5),
  add-bike moved below the list, garage header is now a user menu (first-ever
  Edit Profile screen), maintenance moved into per-bike garage buttons.
- ✅ **Epic E**: nav + places — bottom nav swaps Service for Places (renamed
  Insights→Rides), map-pin location picker for adding a place, manual OSM
  Overpass import (fuel/repair/dealer POIs), "My Places" screen.
- ✅ **Epic F**: Rides tab charts (fl_chart) + 13 milestone badges.
- ✅ **Epic G**: crash-detection threshold fix (was comparing g-force in the
  wrong units, tripped ~10x too easily) + a later confidence-gated crash
  alert (Vehicle State Engine Phase 1, see `VEHICLE_STATE_ARCHITECTURE.md`).

**⛔ Blocker — RESOLVED 2026-07-23:** `com.bft.throttleiq` is now registered
in the `throttleiqfb` Firebase project with fresh config files pasted in —
see `HANDOFF_V2.md` §1. All 8 epics are code-complete.

**Since then (2026-07-23, same day — see `HANDOFF_V2.md` §8/§8a/§8b for full
detail):** the project owner did real live-usage testing for the first time
this project has had, across three waves. Fixed: a forum-post crash
(mis-diagnosed twice before the real cause — a disposed `TextEditingController`
— was found), a Social-feed permission-denied query bug, a Navigator
key-collision crash, a swipe-to-start gesture replacing hold-to-start, a
maintenance-page nav dead spot, silently-failing forum votes, and — the most
serious one — **the app losing ride data when killed mid-ride with the
screen off**, now mitigated with a smaller write buffer, a screen-off flush
trigger, an Android battery-optimization exemption request, and a rewritten
ride-recovery path. Also shipped: bikes/rides/maintenance now sync **both
ways** between devices (was upload-only before, so a second device never saw
data from the first), and a new username + public-profile-with-privacy
feature. None of §8a/§8b has been re-confirmed by a live retest yet — see
`HANDOFF_V2.md` §7 for the highest-priority things to test next.

**Then (2026-07-24, §8c):** a polish wave — in-app follow notifications
(bell icon, not a phone push — blocked on the same no-Cloud-Functions
constraint as the mocked crash-SMS pipeline), tuned GPS settings + smoothed
speed display for the "speed feels slow" report, a real app icon (the
launcher-icon config pointed at files that didn't exist), and rotating
dashboard taglines. Released as `v2.0.0-beta.4+6`, x86_64 build, signed APK
on GitHub.

---

## ✅ Done & verified

### Build & release
- [x] **Release APK builds** — 56.2 MB, `flutter build apk --release` passes (R8 minify + resource shrink on)
- [x] **Release signing** — dedicated 4096-bit RSA keystore, V2 signature verified with `apksigner`
- [x] **GitHub repo** — all P0–P8 code on `main` at https://github.com/blankframe-tech/ThrottleIQ
- [x] **Beta release published** — `v1.0.0-beta.1` (pre-release) with `app-release.apk` + SHA-256 checksum attached
- [x] **No secrets in git** — keystore, `key.properties`, `google-services.json` all gitignored (verified with `git check-ignore` + full-history scan)

### Firebase backend (project `throttleiqfb`)
- [x] **Project created** under blankframe.technologies@gmail.com
- [x] **Android app registered** — `com.throttleiq.throttleiq`, `google-services.json` wired into the build
- [x] **Firestore database** — `(default)`, region `asia-south1` (Mumbai), free tier
- [x] **Security rules deployed** — user-scoped data, public-ride reads, token-based live sessions, admin-gated place verification
- [x] **Query indexes deployed** — rides (user+time, public+time), places (geohash+category), reviews, live sessions
- [x] **Email/Password auth enabled**
- [x] **Google sign-in enabled** — provider on in console; release **and** debug signing certs (SHA-1 + SHA-256, 4 total) registered with the Firebase Android app

### Code (implemented across P0–P8)
- [x] Ride recording engine — GPS + accelerometer, background-safe (foreground service, wakelock), crash-recovery of interrupted rides
- [x] Metrics — speed/max/avg, jerk, hard-brake & rapid-accel counters, overspeed + fatigue alerts, GPS-accuracy gating, idle tagging
- [x] SQLite layer — migrations v1→v4, foreign keys + cascade deletes, composite indexes, buffered point writes
- [x] Crash **detection** — signal fusion (>8 g spike + jerk >10 m/s³ + speed→0 in 2 s), unit-tested — ⚠️ but see below: no countdown UI is wired
- [x] Google sign-in flow in the app — "Continue with Google" on the login screen

> ⚠️ **Correction (2026-07-14, after a code audit — see [features.md](features.md)):** several P5–P8 features exist as **logic/data layers only, with no UI wired to them**: the crash countdown modal (state exists, no widget renders it), SyncManager (never instantiated → rides stay local-only), JSON/GPX export (no button), emergency contacts (no screen), live-share (no share button; viewer unhosted), the POI directory (no presentation layer at all), and the social feed/routes/group-ride screens (files exist but are orphaned — the Social tab shows a "Coming in V2" placeholder). `features.md` §4 has the full gap table and a suggested wiring order.

---

## ⚠️ Done, but NOT yet verified

These exist in code/config but have never been exercised against the real backend or a real device. **Treat each as unproven until tested.**

- [x] ~~**On-device behaviour**~~ **PARTIALLY VERIFIED 2026-07-23** — the project owner has now tested the live app directly (see `HANDOFF_V2.md` §8/§8a/§8b), surfacing several real bugs since fixed. Still open specifically: a real ride with the screen off for several minutes, to confirm the mid-ride-kill data-loss fix (§8b) actually holds — see `HANDOFF_V2.md` §7.
- [x] ~~Unit/widget test suite~~ **VERIFIED 2026-07-14** — 184/184 green.
- [ ] **Google sign-in end-to-end** — config + code are in place; needs one real tap-through on a device.
- [ ] **Firestore rules under real traffic** — rules deployed but only compiler-checked; exercise with a real account (read own rides, fail reading someone else's).
- [x] ~~Live-share viewer~~ **HOSTED 2026-07-14** at `throttleiqfb.web.app/live/{token}` (HTTP 200 verified); end-to-end with a live ride still needs a device test.

---

## 📋 To do

### Now (before inviting beta testers)
- [x] ~~Wire the orphaned features~~ **DONE 2026-07-14**: crash countdown overlay, SyncManager bootstrap, export buttons, Settings screen (logout + emergency contacts) all wired; live viewer deployed to `throttleiqfb.web.app`. Remaining genuine builds: POI UI and a real social feed (the agent "screens" were empty stubs).
- [ ] **Back up the signing keystore** — `throttleiq-release.keystore` + `app/android/key.properties` exist ONLY on the dev machine. If lost, the app can never be updated under the same identity. → password manager / secure cloud, never git.
- [ ] **Install the beta APK on a real phone** and run the smoke test: register → record a ride → stop → summary → confirm the ride appears in Firestore console.
- [x] ~~Run the test suite~~ **DONE 2026-07-14** — 184/184 green (fixed a real EventDetector regression + bad test expectations found on the first-ever full run).
- [x] ~~Deploy the live-share viewer~~ **DONE 2026-07-14** — hosted at `throttleiqfb.web.app` (verified 200); the app’s share links point there.

### Soon (requires Blaze pay-as-you-go plan — still ~$0/mo at beta scale)
- [ ] **Cloud Functions** — deploy `functions/` (crash-notification escalation). Currently SMS/email are mocked; wire Twilio (SMS) and/or SendGrid (email) with real credentials via functions config.
- [x] ~~Firebase Storage bucket~~ **SUPERSEDED 2026-07-23** — the project owner has no payment card, and Storage now requires Blaze even within its free tier. Avatar/photo uploads moved to Cloudinary instead (`HANDOFF_V2.md` §1b) — no bucket needed.
- [ ] **Firestore TTL policy** on `liveSessions.expiresAt` so expired live-share docs auto-delete.
- [ ] **Sync `ride_points` (GPS trails) to Firestore** — bikes/rides-metadata/maintenance sync both ways as of 2026-07-23, but the point-by-point GPS track never has (upload or download) — see `HANDOFF_V2.md` §8b/§6.

### Play Store
- [ ] Google Play developer account ($25 one-time)
- [ ] Build an **App Bundle** (`flutter build appbundle`) — Play prefers `.aab` over `.apk`
- [ ] Internal testing track → closed beta → production
- [ ] Privacy policy page (required for apps using location + Play data-safety form)
- [ ] Bump `version:` in `pubspec.yaml` (versionCode) for every new upload

### Product (v1.1+ — from plan.md)
- [ ] Average speed = distance ÷ moving time (currently mean-of-samples)
- [ ] Sensor calibration via GPS fusion (current: heuristic axis pick)
- [ ] Crash-detector threshold tuning from real false-positive logs
- [ ] Geohash search → proper neighbor-table implementation (current neighbor calc is approximate)
- [ ] Weather on record screen (OpenWeather)
- [ ] Leaderboards (smoothness-based), clubs & events
- [ ] Turn-by-turn curvy-route navigation
- [ ] iOS build & TestFlight (config scaffolding exists; needs a Mac + Apple Developer account)

### Housekeeping
- [ ] Remove `logo2.zip` / `logos1.zip` from repo root once the logos are extracted into `app/assets/`
- [ ] App icons — `flutter_launcher_icons` is configured but `assets/images/app_icon*.png` are placeholders; drop in the real logo and run `dart run flutter_launcher_icons`
- [ ] Delete the unused `test project` created in the Firebase console during setup
- [ ] Consider CI (GitHub Actions): `flutter analyze` + `flutter test` on every PR, release builds on tag

---

## Key facts (for whoever picks this up)

| Thing | Value |
|---|---|
| Firebase project | `throttleiqfb` (asia-south1) |
| Android package (all code, `main`) | `com.bft.throttleiq` — **registered in Firebase** since §1 (2026-07-23): App ID `1:603325098273:android:94694220f44cbf63fcf660` |
| File storage | Cloudinary (unsigned upload, cloud name `vjvcigkt`), **not** Firebase Storage — see `HANDOFF_V2.md` §1b for why |
| Signing keystore | `throttleiq-release.keystore` (repo root, gitignored) — **back it up** |
| Local pub cache / Android SDK paths | Machine-specific — whatever's in your own `flutter doctor` output, not fixed values to copy |
| Latest release | [`v2.0.0-beta.4+6`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/v2.0.0-beta.4+6) — signed x86_64 APK on GitHub |
| Test suite | 282/282 green as of 2026-07-24 (§8c) |
