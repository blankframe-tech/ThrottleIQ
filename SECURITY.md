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
If the standalone `firebase` binary crashes in predeploy, use
`npx firebase-tools@15` in its place.

### Deploying the 2026-10-14 and 2026-10-15 fixes (B1, B2, B3, B9, N3, retention)

Do these in order.

1. **Ship the client first, then wait for the testers to move.** Release a
   build numbered 27 or higher (the part after `+` in `pubspec.yaml`) with
   `scripts/deploy.sh`. It has the B2 profile changes (email in
   `users/{uid}/private/account`, find-by-email through `emailLookup`), the
   forced-update gate, and the email-verification step. Message every tester
   to install it.

   Builds up to beta 4.5 (build 26) have no update gate, so nothing can block
   them. Once the rules deploy (step 3) lands they break like this
   (CrtiQue_Oct15 N2):
   - They lose find-by-email and the All People list.
   - **A new sign-up on an old build gets no public profile and no
     @username.** The old build writes the email onto the profile, the rules
     refuse that, and the app hides the error.
   - **Display-name changes on an old build fail silently** once the
     migration in step 3 has stripped the email.

   The rules do not let the old write through on purpose: any rule that
   accepts it puts the email back on a profile every signed-in rider can
   read (tested in `scripts/test/rules/critique_oct14_rules.test.js`, "N2").
   So go on only when no active tester is on build 26 or older. Check
   Analytics (Dashboard, app version, last 7 days) or ask each tester.
2. **Set `config/app.minBuild`** (an int) in the console to the build from
   step 1, before the rules deploy. Every build that has the gate is then at
   least that build. Clients cannot write `config/*`. Every Android artifact
   carries the same number (split APKs too, see `scripts/deploy.sh`), so
   one value covers them all.
3. **Rules and indexes, then the email migration in the same hour.** Until
   the migration runs, the old public profiles still hold their emails and
   the new rules only slow a scraper down (N9). Rules work on Spark:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes --project throttleiqfb
   ```
   If the CLI offers to delete indexes that are not in the file, answer no.
   Wait until the four new field overrides show "Enabled" in the console
   (Firestore, Indexes, Single field). Then run the one-off migration. Keep
   the service-account key outside the repo (today it sits in `secrets/`;
   move it first):
   ```bash
   cd scripts
   node migrate_emails_private.js --service-account=/path/key.json
   node migrate_emails_private.js --service-account=/path/key.json --yes-i-really-mean-it
   ```
   The first command is a dry run. A second real run should report 0.
   The migration writes an `emailLookup` entry only for addresses that
   Firebase Auth marks verified (N3). Google accounts are verified. Riders
   with email and password get a verification link from the new build, once,
   and become findable by email after they click it and next open the app.
   Then update `public/privacy.html` §5 (the email is no longer readable by
   other riders; someone who already knows a verified address can find the
   account) and deploy Hosting: `firebase deploy --only hosting --project throttleiqfb`.
4. **Realtime Database rules**, only if an RTDB instance exists (the
   rules now deny everything):
   `firebase deploy --only database --project throttleiqfb`
5. **Account deletion (B1). Needs the Blaze plan.** Upgrade, add a budget
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
6. **GPS retention**, when you are ready to commit to it. Blaze, and update
   `public/privacy.html` first (raw trails older than 12 months are deleted,
   ride summaries kept):
   `firebase deploy --only functions:purgeOldGpsTracks --project throttleiqfb`
7. **Cloudinary upload preset (open).** The app ships the cloud name and the
   unsigned preset `throttleiq_unsigned`
   (`app/lib/core/services/cloudinary_upload_service.dart`), so anyone can
   upload to the account with a plain HTTP POST; checks in the app don't stop
   that. Until uploads are signed, limit the damage in the Cloudinary console,
   Settings, Upload, `throttleiq_unsigned`: allowed formats
   `jpg,jpeg,png,webp,heic,aac,m4a`; max file size 5 MB; turn off
   overwrite and "use filename"; set a usage alert. The real fix needs Blaze:
   a callable function that checks `request.auth` and returns a signature
   made with `CLOUDINARY_API_SECRET`, an app build that sends it, and then the
   preset switched to signed (switching it before that build ships breaks
   every upload).

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
