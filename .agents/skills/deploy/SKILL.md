---
name: deploy
description: >
  ThrottleIQ deployment automation runner. Standardizes building, testing,
  deploying release to connected iPhone, building the Android AAB (no APK;
  Google Play only, uploaded by hand) with EN/BN release notes, and publishing to GitHub Releases. Use whenever user asks to deploy, ddeploy,
  or publish a release.
---

# Deploy Skill

Standardized runbook for deploying ThrottleIQ.

## Prerequisites
- Working tree clean or ready for release commit.
- iOS device (Abraar's iPhone) connected via USB or wireless pairing.
- `gh` CLI authenticated.

## Apple account constraints
Team `NJ4675FFUX` is a **personal** Apple team. Personal teams can never sign paid-only
capabilities: Associated Domains (Universal Links), Push Notifications, iCloud, Sign in with
Apple, and similar. Adding one to `app/ios/Runner/Runner.entitlements` breaks every iPhone build
("Personal development teams ... do not support"). Before merging any entitlements change, prove it signs:
```bash
cd app/ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'id=00008120-001E5D190A85A01E' -allowProvisioningUpdates build
```
App Groups is allowed and already in use (`group.com.bft.throttleiq`).

## Execution via Script
```bash
bash scripts/deploy.sh
```

## Manual Execution Steps
1. **QA Gate**: `scripts/check.sh` (run after committing the version bump, so its pass stamp
   matches the pushed commit and the pre-push hook doesn't run it again).

2. **Commit & Push**:
   ```bash
   git add app/pubspec.yaml   # deploy.sh refuses to run with any other tracked file dirty
   git commit -m "chore(release): bump version to <version>"
   # main takes changes only through PRs: push a release branch and open a PR.
   git push origin HEAD:refs/heads/release/<tag>
   gh pr create --base main --head release/<tag> --title "chore(release): <version>"
   ```
   Merge the PR with a merge commit (not a squash) once the checks pass, so the tagged commit lands on `main`.

3. **Deploy to connected iPhone**:
   ```bash
   cd app && flutter run --release -d 00008120-001E5D190A85A01E
   ```

4. **Android AAB only (no APK).** Android installs come only from Google Play; the upload is manual.
   ```bash
   cd app && flutter build appbundle --release
   ```
   `deploy.sh` writes `release-notes-<versionCode>.md` beside the AAB (`app/build/app/outputs/bundle/release/`)
   with the commits since the last AAB build. Replace its two TODOs with user-facing notes in English (`<en-US>`)
   and Bangla (`<bn-BD>`), each under Play's 500-character limit. versionCode is the pubspec build number after `+`;
   the `config/app.minBuild` gate compares it, and Play rejects a reused one, so `deploy.sh` stops unless it is
   above the last AAB's.

5. **Hosting** (`public/`, `firebase.json`) is separate and is never deployed from a dirty or
   unpushed tree. Push to `main` first, then run `bash scripts/deploy_hosting.sh`. It refuses
   unless `git status --porcelain public firebase.json` is empty and HEAD is on `origin/main`.
   Never run `firebase deploy --only hosting` by hand.

6. **GitHub Release** (notes only, no binaries):
   ```bash
   gh release create <tag> --title "ThrottleIQ — <tag> (v<version>)" --notes "<notes + https://throttleiqfb.web.app/install>"
   ```
