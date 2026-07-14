# ThrottleIQ — What Works & What's Next

_Last updated: 2026-07-14 · Release: [v1.0.0-beta.1](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/v1.0.0-beta.1)_

This is the honest state of the project: **Done & verified** means it was actually exercised and confirmed; **Done, not yet verified** means the code/config exists but hasn't been tested end-to-end; **To do** is future work.

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

- [ ] **On-device behaviour** — the app has never been installed on a physical phone. Ride recording, background tracking, crash countdown, sync, POI, social: all need a real-device pass.
- [ ] **Unit/widget test suite** — 50+ test files exist, but the full `flutter test` run hasn't completed on this machine (an environment issue was fixed late; suite needs a clean re-run).
- [ ] **Google sign-in end-to-end** — config + code are in place; needs one real tap-through on a device.
- [ ] **Firestore rules under real traffic** — rules deployed but only compiler-checked; exercise with a real account (read own rides, fail reading someone else's).
- [ ] **Live-share viewer** — `public/live-viewer.html` is written but **not hosted anywhere yet**, and the app generates links to `throttleiq.app` which doesn't exist (see TODO).

---

## 📋 To do

### Now (before inviting beta testers)
- [ ] **Wire the orphaned features** (see [features.md](features.md) §6 for order): crash countdown modal → SyncManager bootstrap in `main.dart` → export buttons on Ride Summary → Settings/Profile screen (logout + emergency contacts) → connect the social screens → build POI UI
- [ ] **Back up the signing keystore** — `throttleiq-release.keystore` + `app/android/key.properties` exist ONLY on the dev machine. If lost, the app can never be updated under the same identity. → password manager / secure cloud, never git.
- [ ] **Install the beta APK on a real phone** and run the smoke test: register → record a ride → stop → summary → confirm the ride appears in Firestore console.
- [ ] **Run the test suite** — `flutter test` (with `PUB_CACHE=C:\pub_cache` set) and fix anything red.
- [ ] **Deploy the live-share viewer** — `firebase deploy --only hosting` (works on the free plan → `throttleiqfb.web.app`), then update the share-link base URL in the app from `throttleiq.app` to the hosted URL.

### Soon (requires Blaze pay-as-you-go plan — still ~$0/mo at beta scale)
- [ ] **Cloud Functions** — deploy `functions/` (crash-notification escalation). Currently SMS/email are mocked; wire Twilio (SMS) and/or SendGrid (email) with real credentials via functions config.
- [ ] **Firebase Storage bucket** — new projects require Blaze for Storage; until then review/profile photo uploads fail. Enable bucket + deploy storage rules.
- [ ] **Firestore TTL policy** on `liveSessions.expiresAt` so expired live-share docs auto-delete.

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
| Android package | `com.throttleiq.throttleiq` |
| Firebase Android app ID | `1:603325098273:android:eca9cb27d75372cffcf660` |
| Signing keystore | `throttleiq-release.keystore` (repo root, gitignored) — **back it up** |
| Local pub cache | `C:\pub_cache` (moved out of the spaced user path; keep `PUB_CACHE` set) |
| Android SDK | `C:\Android\sdk` (junction; cmdline-tools installed) |
| Release | `v1.0.0-beta.1` — APK + SHA-256 on the GitHub release |
