# ThrottleIQ Deployment Workflow — Always-On Rule

Whenever the user asks to "deploy", "ddeploy", "release", or "publish", you MUST execute the complete standard deployment pipeline:

## Deployment Pipeline Steps

1. **Pre-flight QA & Guardian Verification**
   - Run `scripts/check.sh` once (analyze, tests, guards, format; 0 failures required).
   - Run Onboarding Guardian audit: verify manifest slides against app routes and compile check.

2. **Version Bump & Git Push**
   - Verify/bump version in `app/pubspec.yaml` (e.g. `1.0.0-beta.2.x+y`).
   - Derive the tag name (e.g. `beta-v2.x`).
   - Commit any new/uncommitted work: `chore(release): bump version to <version> ...`.
   - Push to remote `origin/main`.

3. **Deploy Release to Connected iPhone**
   - Detect connected iOS device via `flutter devices` (e.g., Abraar’s iPhone `00008120-001E5D190A85A01E`).
   - Run the app in release mode on the device:
     ```bash
     cd app && flutter run --release -d <device_id>
     ```

4. **No Android build.** Android installs come only from Google Play; the deploy pipeline builds no APK or AAB. The Play upload is done by hand outside this pipeline.
   - **versionCode:** the pubspec build number (after `+`). The `config/app.minBuild` gate compares it and Play rejects a reused code, so bump it every release.

5. **Publish GitHub Release Tag (notes only, no binaries)**
     ```bash
     gh release create <tag> --title "ThrottleIQ — <tag> (v<version>)" --notes "<changelog + https://throttleiqfb.web.app/install>"
     ```

6. **Repeatable Script Alternative**
   - You can execute the entire flow via:
     ```bash
     bash scripts/deploy.sh
     ```
   - Flags available: `--skip-qa`, `--skip-ios`, `--skip-github`, `--device <id>`, `--tag <tag>`.
