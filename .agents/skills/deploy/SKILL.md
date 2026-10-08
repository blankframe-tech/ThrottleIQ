---
name: deploy
description: >
  ThrottleIQ deployment automation runner. Standardizes building, testing,
  deploying release to connected iPhone, compiling Android release APK & AAB,
  and publishing to GitHub Releases. Use whenever user asks to deploy, ddeploy,
  or publish a release.
---

# Deploy Skill

Standardized runbook for deploying ThrottleIQ.

## Prerequisites
- Working tree clean or ready for release commit.
- iOS device (Abraar's iPhone) connected via USB or wireless pairing.
- Android release keystore located at repo root (`throttleiq-release.keystore`).
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
1. **QA Gate**:
   ```bash
   cd app && flutter analyze --no-fatal-infos
   flutter test
   ```

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

4. **Build Android APK & AAB**:
   ```bash
   cd app && flutter build apk --release
   flutter build appbundle --release
   ```

5. **GitHub Release**:
   ```bash
   gh release create <tag> app/build/app/outputs/flutter-apk/app-release.apk app/build/app/outputs/bundle/release/app-release.aab --title "ThrottleIQ — <tag> (v<version>)" --notes "<notes>"
   ```
