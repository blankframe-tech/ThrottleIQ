# ThrottleIQ — Setup Guide

## 1. Firebase Setup (Required)

1. Create a Firebase project at console.firebase.google.com
2. Enable **Authentication** → Email/Password
3. Enable **Cloud Messaging** for push notifications
4. Add Android app with package name: `com.bft.throttleiq`
5. Download `google-services.json` → place at `android/app/google-services.json`
6. Add to `android/build.gradle.kts`:
   ```kotlin
   plugins {
     id("com.google.gms.google-services") version "4.4.0" apply false
   }
   ```
7. Add to `android/app/build.gradle.kts`:
   ```kotlin
   plugins {
     id("com.google.gms.google-services")
   }
   ```

## 2. Google Maps API Key

1. Get an API key from Google Cloud Console with **Maps SDK for Android** enabled
2. In `android/app/src/main/AndroidManifest.xml`, replace:
   ```xml
   android:value="YOUR_GOOGLE_MAPS_API_KEY"
   ```
   with your actual key.

## 3. Run

```bash
flutter pub get
flutter run
```

## Architecture Overview

```
lib/
├── core/           # Theme, DB, Router, Services
├── features/
│   ├── auth/       # Firebase email/password auth
│   ├── garage/     # Multi-bike CRUD
│   ├── ride/       # GPS recording + sensor processing
│   ├── maintenance/# Service logs + reminders
│   ├── chatbot/    # AI chat (wire Claude API here)
│   └── social/     # Social feed (V2)
└── shared/         # Reusable widgets
```

## Wiring the AI Chatbot

In `lib/features/chatbot/presentation/screens/chatbot_screen.dart`, replace the placeholder bot response with a real Claude API call:

```dart
final response = await anthropic.messages.create(
  model: 'claude-sonnet-4-6',
  maxTokens: 1024,
  messages: [MessageParam(role: MessageRole.user, content: text)],
);
```

## Key Design Decisions

- **Offline-first**: All ride data writes go to SQLite immediately. REST sync happens on ride end or reconnect.
- **Physics engine**: `MotionCalculator` computes acceleration/jerk from consecutive GPS points. Event detector fires alerts when thresholds are crossed.
- **State machine**: `RideRecordingState` → IDLE → STARTING → ACTIVE ↔ PAUSED → COMPLETED
- **Riding score**: 100 - (hardBrakes×5 + rapidAccel×3 + highJerk×1), clamped to [0,100]
