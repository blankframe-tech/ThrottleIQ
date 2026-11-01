# App Check: owner runbook (decision 2026-10-21)

Goal: enforce App Check on **Cloud Firestore only**. Keep testing iOS with
`flutter run --release` on your iPhone. Android riders install from Google
Play or see a blocking screen. Agents never run these steps.

## What the app does (since 2026-10-21)

- `app/lib/main.dart` activates App Check right after `Firebase.initializeApp`,
  before any Firestore call.
  - Android release: Play Integrity.
  - iOS release: App Attest, with DeviceCheck on devices without App Attest.
  - Debug builds, and release builds with `--dart-define=APP_CHECK_DEBUG=true`:
    the debug provider.
- `app/lib/core/services/app_check_gate.dart`: on an Android release build
  that was not installed by the Play Store and that App Check rejects
  ("App attestation failed"), the app shows a blocking screen: install from
  Google Play, a Play Store button, and "Want to test a build? Send a testing
  request on WhatsApp: 01327045005" (wa.me link, prefilled "ThrottleIQ testing
  request"). English and Bangla.
  - It never blocks iOS, debug-provider builds or Play installs.
  - It never blocks on a network error, a timeout, a disabled App Check API
    or any other error. Those riders get the app; once Firestore is enforced
    their reads fail until the network or the setup is fixed.
  - It blocks **as soon as App Check rejects the build**, whether or not
    Firestore is enforced. So a sideloaded APK of this build or later is
    blocked from the day you register the Android app in App Check.

## Can a `flutter run --release` iPhone build pass App Check?

Yes, with one setting. Sources:

- Firebase: "App Check currently doesn't accept tokens generated in the App
  Attest sandbox environment", and set the App Attest environment to
  `production` in the `.entitlements` file
  (https://firebase.google.com/docs/app-check/ios/app-attest-provider).
- Apple: "If you omit the entitlement during development, your app uses the
  App Attest sandbox servers by default. You can test your app during
  development against the App Attest production servers by setting the
  entitlement to `production`." TestFlight and App Store builds always use
  production
  (https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.devicecheck.appattest-environment).

So a development-signed release build passes **only** with
`com.apple.developer.devicecheck.appattest-environment = production`. Xcode's
App Attest capability writes `development`, which Firebase rejects. The
capability needs the paid team, so the entitlement is **not** in
`Runner.entitlements` yet: adding it while the project still signs with the
personal team `NJ4675FFUX` would break every iPhone build.

Two ways to test, pick one:

- **A. Real App Attest (after the team switch, step 2 below).**
  `flutter run --release` as usual.
- **B. Debug provider, works today on any team.**
  `flutter run --release --dart-define=APP_CHECK_DEBUG=true`. The first launch
  prints a debug token to the device log (Xcode, Window, Devices and
  Simulators, Open Console; search "App Check debug token"). Register it
  (step 5). The token stays the same until you delete the app. Never ship a
  build made with this flag: anyone with the binary can mint tokens.

## Steps, in order

1. **Finish SECURITY.md step 3 first** (rules, indexes, then the email
   migration in the same hour). Done 2026-10-27. Do it before you enforce
   App Check, so that when something breaks you know which switch did it.
   Rules and App Check both reject requests with the same
   `permission-denied`, and the migration runs with the Admin SDK, which App
   Check does not affect.
2. **iOS, paid team.** In the Apple Developer portal, Membership details, note
   the Team ID of the paid team (it may differ from `NJ4675FFUX`). In Xcode,
   Runner and ThrottleIQWidget targets, Signing: pick the paid team. On the
   Runner target add the App Attest capability, then edit
   `app/ios/Runner/Runner.entitlements` so
   `com.apple.developer.devicecheck.appattest-environment` is `production`.
   Also update the team note in `scripts/check.sh` (`guard_entitlements`) and
   in `Runner.entitlements`. For DeviceCheck: Certificates, Identifiers and
   Profiles, Keys, create a key with DeviceCheck enabled, download the `.p8`
   (once only; keep it outside the repo and outside Google Drive), note the
   Key ID.
3. **Firebase console, App Check, Apps** (project `throttleiqfb`):
   - iOS app: register **App Attest** (Team ID from step 2) and **DeviceCheck**
     (the `.p8`, Key ID, Team ID). Set the Team ID in Project settings for the
     iOS app too if it asks.
   - Android app: in Play Console, Test and release, App integrity, Play
     Integrity API, **Link Cloud project** and pick `throttleiqfb` (you must
     be a project Owner). Then in App Check register **Play Integrity** with
     the **SHA-256 of the Play app signing key** (Play Console, App integrity,
     App signing; not the upload key). Leave the Play Integrity settings at
     their defaults: they require `PLAY_RECOGNIZED`, which is what rejects
     sideloaded APKs.
   - Registering also turns on the App Check API. Until then the debug-token
     exchange returns 403 `SERVICE_DISABLED` (issues_open §97).
4. **Ship this build through Google Play** (closed or internal testing track
   counts). Do not publish it as an APK on the install page or GitHub
   Releases: anyone who installs that APK is blocked once step 3 is done.
   Point the install page and the "Update required" link at Google Play, then
   raise `config/app.minBuild` to this build's number, so older sideloaded
   builds (no sideload screen) are sent to Play.
5. **Debug tokens.** For each test device on a debug build or an
   `APP_CHECK_DEBUG=true` build, copy the token from the log (iOS: Xcode
   console, "App Check debug token"; Android: `adb logcat | grep
   DebugAppCheckProvider`, "Enter this debug secret into the allow list").
   App Check, Apps, (the app), menu, **Manage debug tokens**, add it, name it
   after the device. Never commit a token; revoke it when the device is gone.
6. **Watch the metrics for a few days** (App Check, APIs, Cloud Firestore).
   Go on when unverified requests are near zero and come only from builds you
   expect to lose (sideloaded APKs, builds older than `minBuild`).
7. **Enforce Cloud Firestore only.** App Check, APIs, Cloud Firestore,
   Enforce. Leave Realtime Database, Storage and Authentication unenforced.
   Before this, the web live viewer (`public/live-viewer.html`) needs a
   reCAPTCHA Enterprise provider, or partner live links stop working: it
   reads Firestore with no App Check token.
8. **Rollback:** App Check, APIs, Cloud Firestore, Unenforce. It takes effect
   within minutes.

## Status (2026-11-01)

- App Check API enabled. Android: Play Integrity registered (Play app-signing
  SHA-256 `CF:1E:…:3D` on the Firebase Android app). Web: Firebase web app
  `ThrottleIQ Live Viewer` (`1:603325098273:web:be5218289b72e2d9fcf660`);
  `public/live-viewer.html` uses Fraud Defense (reCAPTCHA Enterprise,
  `ReCaptchaEnterpriseProvider`) with site key `6Lc02wou…YlqB` (no secret key;
  classic v3 is deprecated in the console). iOS: owner's iPhone on the debug provider (`APP_CHECK_DEBUG=true`)
  until the paid team switch; other iOS installs fail once Firestore is
  enforced.
- Owner decision 2026-11-01: enforce Firestore right after setup, no
  metrics period. Sideloaded and self-built Android release builds get the
  sideload screen (apply for alpha on WhatsApp, demo mode, Play).

Cloud Functions need nothing: they are all triggers, with no callable or HTTP
function to put `enforceAppCheck` on.
