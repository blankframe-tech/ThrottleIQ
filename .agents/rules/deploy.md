# ThrottleIQ Deployment Workflow — Always-On Rule

Whenever the user asks to "deploy", "ddeploy", "release", or "publish", you MUST execute the complete standard deployment pipeline:

## Deployment Pipeline Steps

1. **Pre-flight QA & Guardian Verification**
   - Run static analysis: `flutter analyze --no-fatal-infos` (0 errors required).
   - Run unit test suite: `flutter test` (all tests must pass).
   - Run Onboarding Guardian audit: verify manifest slides against app routes and compile check.

2. **Version Bump & Git Push**
   - Verify/bump version in `app/pubspec.yaml` (e.g. `1.0.0-beta.2.x+y`).
   - Derive the tag name (e.g. `beta-v2.x`).
   - Commit any new/uncommitted work: `chore(release): bump version to <version> ...`.
   - Push to remote `origin/master`.

3. **Deploy Release to Connected iPhone**
   - Detect connected iOS device via `flutter devices` (e.g., Abraar’s iPhone `00008120-001E5D190A85A01E`).
   - Run the app in release mode on the device:
     ```bash
     cd app && flutter run --release -d <device_id>
     ```

4. **Build Android Release Artifacts**
   - Build release APK:
     ```bash
     cd app && flutter build apk --release
     ```
     Binary output: `app/build/app/outputs/flutter-apk/app-release.apk`
   - Build release AAB:
     ```bash
     cd app && flutter build appbundle --release
     ```
     Binary output: `app/build/app/outputs/bundle/release/app-release.aab`

5. **Publish GitHub Release Tag**
   - Create the release and tag on GitHub via `gh release create`:
     ```bash
     gh release create <tag> app/build/app/outputs/flutter-apk/app-release.apk app/build/app/outputs/bundle/release/app-release.aab --title "ThrottleIQ — <tag> (v<version>)" --notes "<changelog>"
     ```

6. **Repeatable Script Alternative**
   - You can execute the entire flow via:
     ```bash
     bash scripts/deploy.sh
     ```
   - Flags available: `--skip-qa`, `--skip-ios`, `--skip-android`, `--skip-github`, `--device <id>`, `--tag <tag>`.
