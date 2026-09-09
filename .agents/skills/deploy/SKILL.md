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
   git push origin master
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
