# Security Policy

## Supported versions

Only the latest beta release receives security fixes.

## Reporting a vulnerability

Please report privately by email to the.abraar.rar@gmail.com. Do not open a public issue or pull request for a vulnerability.

Include what you found, steps to reproduce, and the affected version. We aim to acknowledge reports within 7 days.

There is no bug bounty.

---

## Owner runbooks

These are console and deploy steps only the project owner can take. Agents
never run them. Project: `throttleiqfb`. Never run a bare `firebase deploy`:
it would also push undeployed functions (crash alerts, chat moderation).

### Deploying the 2026-10-14 fixes (B1, B2, B3, B9, retention)

Do these in order.

1. **Ship the client first.** Release a build with the B2 profile changes
   (email moves to `users/{uid}/private/account`, find-by-email uses
   `emailLookup`) and the forced-update gate. Once step 2 lands, older
   builds lose find-by-email and the All People list.
2. **Rules and indexes** (works on Spark):
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project throttleiqfb
   ```
   If the CLI offers to delete indexes that are not in the file, answer no.
   Wait until the four new field overrides show "Enabled" in the console
   (Firestore, Indexes, Single field).
3. **Realtime Database rules**, only if an RTDB instance exists (the
   rules now deny everything):
   `firebase deploy --only database --project throttleiqfb`
4. **Set `config/app.minBuild`** (an int) in the console when you want
   older builds blocked. Clients cannot write `config/*`.
5. **Email migration** (one-off, after step 2). Keep the service-account
   key outside the repo:
   ```bash
   cd scripts
   node migrate_emails_private.js --service-account=/path/key.json
   node migrate_emails_private.js --service-account=/path/key.json --yes-i-really-mean-it
   ```
   The first command is a dry run. A second real run should report 0.
6. **Account deletion (B1). Needs the Blaze plan.** Upgrade, add a budget
   alert (for example $5; alerts do not cap spend), then:
   ```bash
   firebase functions:secrets:set CLOUDINARY_API_KEY --project throttleiqfb
   firebase functions:secrets:set CLOUDINARY_API_SECRET --project throttleiqfb
   firebase deploy --only functions:onUserAccountDeleted --project throttleiqfb
   ```
   The key and secret are on the Cloudinary console dashboard. An empty
   secret skips the media sweep and records it in `accountDeletions/{uid}`.
   To check it works, delete a test account and confirm that
   `accountDeletions/{uid}` shows `ok: true` with an empty `failedSteps`.
7. **GPS retention**, when you are ready to commit to it. Blaze, and update
   `public/privacy.html` first (raw trails older than 12 months are deleted,
   ride summaries kept):
   `firebase deploy --only functions:purgeOldGpsTracks --project throttleiqfb`

### App Check enforcement

The app already sends tokens (`app/lib/main.dart`). Android release builds
use Play Integrity, iOS uses App Attest with a DeviceCheck fallback, and
debug builds use the debug provider. Nothing is enforced until you switch it
on per service in the Firebase console (App Check, APIs).

Before you enforce anything:

- **Expect Play Integrity to reject sideloaded APKs.** App Check's Play
  Integrity provider expects an app installed from Google Play, so a build
  from GitHub Releases should get no valid token, and enforcing Firestore
  locks those riders out. Enforce only once riders install from Google Play (a testing track
  counts). Register the app-signing key's SHA-256 (Play Console, App
  integrity) in App Check, Apps, Android.
- **iOS needs the paid Apple Developer Program.** App Attest and DeviceCheck
  need a key and entitlement the personal team `NJ4675FFUX` cannot have.
  Enforcement is per service, not per platform, so it also blocks iOS
  builds that cannot attest.
- **The web live viewer has no App Check.** `public/live-viewer.html` reads
  Firestore directly. Add a reCAPTCHA Enterprise provider to that page
  before you enforce Firestore, or partner live links stop working.

Debug tokens, for development builds:

1. Run a debug build. The token is in the log: Xcode console on iOS
   ("App Check debug token"), `adb logcat` on Android (look for
   `DebugAppCheckProvider`).
2. Add it under App Check, Apps, (your app), Manage debug tokens. Name it
   after the device.
3. Never commit a token. Revoke it when the device is retired.

Per-service switches, in this order:

1. **Realtime Database:** enforce at any time. It denies everything anyway.
2. **Cloud Firestore:** watch the metrics on its App Check page until
   unverified requests are close to zero for a week. Then enforce.
3. **Authentication**, if the console offers it: same test as Firestore.
4. **Cloud Functions:** nothing to do. There are only triggers, no callable
   or HTTP functions.

To roll back, switch enforcement off for that service. It takes effect
within minutes.
