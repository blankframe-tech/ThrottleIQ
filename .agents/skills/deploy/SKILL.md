---
name: deploy
description: >
  ThrottleIQ deployment automation runner. Standardizes building, testing,
  deploying release to connected iPhone (no Android build: Android ships
  only through Google Play, uploaded by hand), and publishing to GitHub Releases. Use whenever user asks to deploy, ddeploy,
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
   git add -A
   git commit -m "chore(release): bump version to <version>"
   git push origin main
   ```

3. **Deploy to connected iPhone**:
   ```bash
   cd app && flutter run --release -d 00008120-001E5D190A85A01E
   ```

4. **No Android build.** Android installs come only from Google Play; no APK or AAB is built here.
   The Play upload is manual. Its versionCode is the pubspec build number after `+`; the
   `config/app.minBuild` gate compares it, and Play rejects a reused one, so bump it every release.

5. **GitHub Release** (notes only, no binaries):
   ```bash
   gh release create <tag> --title "ThrottleIQ — <tag> (v<version>)" --notes "<notes + https://throttleiqfb.web.app/install>"
   ```
