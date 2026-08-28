# ThrottleIQ Setup Guide

Complete setup instructions for local development and production deployment.

## Prerequisites

- Flutter SDK ≥ 3.3.0 (check `flutter --version`)
- Android SDK API 21+ (Android 5.0)
- iOS 12.0+ (XCode 12+)
- Xcode command-line tools (iOS builds)
- Java 17+ (Android signing)

## Local Development Setup

### 1. Clone & Install Dependencies

```bash
git clone https://github.com/blankframe-tech/ThrottleIQ.git
cd ThrottleIQ/app
flutter pub get
```

### 2. Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project (or use existing): "ThrottleIQ" — the live project is
   `throttleiqfb` (asia-south1)
3. Enable these services:
   - Authentication (Email/Password, Google Sign-In)
   - Firestore Database
   - Cloud Messaging (bundled but not currently sending anything — see
     `docs/HANDOFF_Document.md`'s Key facts table)
4. **Not enabled, and not needed today:** Firebase Storage and Cloud
   Functions both require the Blaze (pay-as-you-go) plan, which this project
   isn't on. Photo uploads go to Cloudinary instead — create a free
   Cloudinary account, an unsigned upload preset, and set the cloud
   name/preset in `app/lib/core/services/cloudinary_upload_service.dart`
   (production uses cloud name `vjvcigkt`; use your own for local dev so you
   don't share a quota). Cloud Functions (crash-notification escalation)
   exist as TypeScript source in `functions/src/` but can't deploy on Spark
   — see `docs/backend_options.md` for the real cost estimate and
   alternatives before turning on Blaze.

### 3. Download Google Services Files

**Android:**
1. In Firebase Console → Project Settings → General
2. Add "com.bft.throttleiq" as Android app
3. Download `google-services.json`
4. Place in `app/android/app/google-services.json`

**iOS:**
1. Add "com.bft.throttleiq" as iOS app (or add Bundle ID variant)
2. Download `GoogleService-Info.plist`
3. Place in `app/ios/Runner/GoogleService-Info.plist`

### 4. Android Release Signing

Create keystore and key.properties:

```bash
cd app/android
keytool -genkey -v -keystore ../../throttleiq-release.keystore \
  -keyalg RSA -keysize 4096 -validity 10000 -alias throttleiq-release
```

When prompted:
- Password (≥6 chars)
- First/Last Name: "ThrottleIQ Release"
- Organization: "ThrottleIQ"
- City/State/Country: Your location
- Confirm password

Then create `app/android/key.properties`:

```properties
storeFile=../../../throttleiq-release.keystore
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=throttleiq-release
keyPassword=YOUR_KEY_PASSWORD
```

⚠️ **Never commit key.properties to git** (already in `.gitignore`). **Back
up the keystore file itself somewhere durable** — password manager or
secure cloud, never git. Losing it means the app can never be updated under
the same identity again.

⚠️ On macOS, `/usr/bin/keytool` is Apple's stub and fails (sometimes
silently, under `2>/dev/null`) if no JDK is on `PATH`. Use Android Studio's
bundled runtime instead:
`"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"`.

### 5. Run Locally

```bash
cd app
flutter run
# or for release build:
flutter run --release
```

## Firestore Deployment

### 1. Deploy Security Rules

```bash
# Install Firebase CLI (if not already)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Set project
firebase use --add
# Select your ThrottleIQ Firebase project

# Deploy Firestore rules
firebase deploy --only firestore:rules
```

Test rules against the emulator before deploying: `npm run test:rules` from
`scripts/` (needs a JVM — Android Studio's bundled JBR works if there's no
`java` on `PATH`: `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`).

### 2. Create Firestore Indexes (if prompted)

Firestore will suggest composite indexes on first complex query. Either:
- Click the link in the error to create via console, OR
- Deploy via CLI:

```bash
firebase deploy --only firestore:indexes
```

### 3. Storage — not currently used

Firebase Storage isn't enabled for this project (no `"storage"` key in
`firebase.json`) — it requires the Blaze plan even within its free tier.
Photo uploads (bike photos, profile pictures, forum images) go to Cloudinary
instead, unsigned upload, cloud name `vjvcigkt`. If Storage is ever turned
on, `storage.rules` exists in the repo with size/content-type constraints
already written (`docs/Issues.md` §33.6/§33.15) but dormant.

## Cloud Functions — written, cannot deploy on the current plan

`functions/src/*.ts` (TypeScript) implements the crash-notification
escalation timer (pending → contacted → escalated) and a ride-identity
reconciliation trigger. Both are real code, not stubs, but
`firebase deploy --only functions` fails outright on this project's Spark
billing plan (`artifactregistry.googleapis.com` can't be enabled without
Blaze). See `docs/backend_options.md` for the actual cost estimate and two
alternatives to upgrading before deploying anything here:

```bash
cd functions
npm install
npm run build     # compiles to lib/, gitignored
firebase deploy --only functions   # fails today — needs Blaze
```

## Build for Release

### Android APK

```bash
cd app
flutter build apk --release
# Output: build/app/outputs/flutter-app/release/app-release.apk
```

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS IPA

```bash
flutter build ios --release
# Then in Xcode or use App Store Connect
open ios/Runner.xcworkspace
```

## Deployment to Play Store

1. Upload AAB to [Google Play Console](https://play.google.com/console)
2. Fill in store listing (screenshots, description, privacy policy)
3. Go through review (typically 24-48 hours)
4. Release to internal testing first, then staged rollout

## Troubleshooting

### "google-services.json not found"
- Ensure `app/android/app/google-services.json` exists
- Run `flutter clean && flutter pub get`

### Firestore rules error on write
- Check Firebase Console → Firestore → Rules tab
- Ensure user is authenticated (check `request.auth != null`)
- Run `firebase deploy --only firestore:rules` to apply `firestore.rules`

### iOS build failures
- Run `cd app/ios && pod install --repo-update && cd ../..`
- Ensure `GoogleService-Info.plist` in Xcode project target membership

### APK not signing
- Verify `key.properties` path and passwords are correct
- Check keystore file exists at path specified

## Useful Commands

```bash
# Clean build artifacts
flutter clean
flutter pub get

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .

# Dry run (see what would build)
flutter build apk --release --analyze-size
```

No CI/CD pipeline exists in this repo yet — `flutter analyze && flutter test`
before every push is the manual equivalent today.

---

## Support

- **Issues**: tracked in `docs/Issues.md`, not GitHub Issues
- **Full project status / to-do**: `docs/HANDOFF_Document.md`
- **Firebase Docs**: https://firebase.google.com/docs
- **Flutter Docs**: https://flutter.dev/docs
- **Firestore Security**: https://firebase.google.com/docs/firestore/security

---

**Last updated**: 2026-08-28
