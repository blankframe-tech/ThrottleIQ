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
2. Create a new project (or use existing): "ThrottleIQ"
3. Enable these services:
   - Authentication (Email/Password)
   - Firestore Database
   - Storage (for images)
   - Cloud Functions (for crash notifications)

### 3. Download Google Services Files

**Android:**
1. In Firebase Console → Project Settings → General
2. Add "com.throttleiq.throttleiq" as Android app
3. Download `google-services.json`
4. Place in `app/android/app/google-services.json`

**iOS:**
1. Add "com.throttleiq.throttleiq" as iOS app (or add Bundle ID variant)
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

⚠️ **Never commit key.properties to git** (already in `.gitignore`)

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

### 2. Create Firestore Indexes (if prompted)

Firestore will suggest composite indexes on first complex query. Either:
- Click the link in the error to create via console, OR
- Deploy via CLI:

```bash
firebase deploy --only firestore:indexes
```

### 3. Deploy Storage Rules (optional)

Create `storage.rules` with:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can only write to their own folder
    match /users/{uid}/{allPaths=**} {
      allow read, write: if request.auth.uid == uid;
    }
    match /places/{placeId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == resource.metadata.owner;
    }
  }
}
```

Then deploy:

```bash
firebase deploy --only storage
```

## Cloud Functions (Optional - Crash Notifications)

Create `functions/index.js`:

```javascript
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.notifyOnCrash = functions.firestore
  .document("liveSessions/{token}")
  .onWrite(async (change) => {
    const data = change.after.data();
    if (data.status === "crash") {
      const uid = data.uid;
      const user = await admin.firestore().collection("users").doc(uid).get();
      const contacts = user.data()?.emergencyContacts || [];
      
      // Send SMS/email via Twilio or Firebase email
      // TODO: Implement notification logic
      console.log(`Crash detected for ${uid}, notifying ${contacts.length} contacts`);
    }
  });
```

Deploy:

```bash
cd functions
npm install
firebase deploy --only functions
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

## Environment Variables

Set in `.env` (not committed) or Firebase project:

```
TIPSOI_MOCK=0  # Set to 1 for offline demo mode
```

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

# Lint
flutter pub run custom_lint

# Build all
flutter pub run build_runner build

# Dry run (see what would build)
flutter build apk --release --analyze-size
```

## CI/CD (GitHub Actions - Optional)

Create `.github/workflows/build.yml`:

```yaml
name: Build & Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --release
```

---

## Support

- **Issues**: Report bugs via GitHub Issues
- **Firebase Docs**: https://firebase.google.com/docs
- **Flutter Docs**: https://flutter.dev/docs
- **Firestore Security**: https://firebase.google.com/docs/firestore/security

---

**Last Updated**: 2026-07-12  
**Next**: Run `flutter run` to start developing!
