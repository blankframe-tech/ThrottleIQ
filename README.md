# 🏍️ ThrottleIQ — Machine Memory for Motorcycles

**ThrottleIQ** is a open-source motorcycle ride tracking and intelligence platform that captures every detail of your rides: speed, acceleration, braking, routes, and machine maintenance. Built for riders who care about performance, safety, and keeping their bikes running flawlessly.

![License](https://img.shields.io/badge/license-TSAL-blue) ![Flutter](https://img.shields.io/badge/Flutter-3.3+-blue) ![Firebase](https://img.shields.io/badge/Firebase-Firestore-orange)

---

## ✨ Features

### 🛣️ Ride Recording (P0-P4 ✅)
- **Background tracking**: Records continuously even when app is backgrounded or screen is locked (using foreground services + wakelock)
- **Live stats**: Current speed, acceleration, jerk, altitude, distance
- **Smart alerts**: Overspeed, rapid acceleration, hard braking, extended riding (fatigue after 90 min)
- **Exact metrics**: Captures 20+ data points per second via GPS + accelerometer

### 📊 Ride Analysis (P0-P4 ✅)
- **Summary cards**: Max speed, distance, duration, hard braking count, rapid accel count, jerk count
- **Idle segmentation**: Distinguishes moving vs stopped periods (speed < 1 m/s)
- **GPS accuracy gating**: Filters poor-accuracy points (accuracy > 25m)
- **Timestamp precision**: Uses device time, not wall-clock, for accurate motion derivatives

### 🔐 Safety & Emergency (P6 🚀)
- **Crash detection**: Accelerometer spike + speed drop within 2 sec → 60-second countdown
- **Emergency contacts**: Share live location & ride stats with up to 5 emergency contacts
- **Live share link**: Generate unguessable token-based link; contacts see rider's location, speed, battery in real-time
- **No automatic 911**: v1 contacts-only (respects privacy); escalation via Cloud Function if contact doesn't ACK in 15 min

### 🏪 Rider Utilities (P7 🚀)
- **POI Directory**: Fuel pumps, garages, spare-parts shops (verified by admin, user-contributed)
- **Ratings & Reviews**: Leave feedback with photos on places you visit
- **On-ride quick access**: During a ride, find nearest fuel pump with one tap
- **Geohash queries**: Efficient map viewport search for nearby places

### 👥 Social & Community (P8 🚀)
- **Ride feed**: Share rides with friends; see their ride cards (distance, duration, max speed, route thumbnail)
- **Privacy zones**: Auto-strips first/last 200m of route (home location never exposed)
- **Saved routes**: Save a past ride as a reusable route; re-ride anytime
- **Group rides**: Create a ride session, invite friends; see all members' live positions on a shared map
- **Challenges**: Monthly distance/streak challenges with local badges (e.g., "500km in July")

### 🌐 Cloud & Sync (P5 🚀)
- **Offline-first SQLite**: All data stored locally; ride recording works 100% offline
- **Automatic Firestore sync**: On app resume + every 5 min if online
- **Data portability**: Export rides as JSON or GPX (import into other apps, mapping tools)
- **Profile sync**: Backup your bike fleet, maintenance logs, emergency contacts to cloud

---

## 🚀 Quick Start

### Install

1. **Clone the repo**:
   ```bash
   git clone https://github.com/blankframe-tech/ThrottleIQ.git
   cd ThrottleIQ/app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Set up Firebase** (see [SETUP.md](SETUP.md) for details):
   - Create Firebase project at console.firebase.google.com
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place in `app/android/app/` and `app/ios/Runner/` respectively

4. **Run**:
   ```bash
   flutter run
   ```

### Record Your First Ride

1. Launch the app → **Record** tab
2. Select your bike (or add one in **Garage**)
3. Tap **Start Recording** → ride normally
4. Tap **Stop** when done
5. View summary → **Save**

Done! Ride is saved to local database and will auto-sync to cloud on next reconnect.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App (Mobile)                                   │
│  ├─ Local SQLite (offline-first source of truth)       │
│  ├─ State: Riverpod providers (ride recording, sync)   │
│  └─ UI: Material 3 + Flutter Map                        │
└──────────────────┬──────────────────────────────────────┘
                   │ (auto-sync on resume + 5min intervals)
                   │
┌──────────────────▼──────────────────────────────────────┐
│  Firebase Backend                                       │
│  ├─ Firestore: User data, rides, bikes, POIs, reviews │
│  ├─ Storage: POI photos, profile pictures              │
│  ├─ Auth: Email/password + anonymous                  │
│  └─ Cloud Functions: Crash notifications, exports     │
└─────────────────────────────────────────────────────────┘
```

**Data Flow**:
1. Rider records → GPS + sensor data flows to SQLite (local)
2. Recording stops → data marked `synced=0`
3. App resumes / 5min timer → SyncManager detects unsync'd records
4. Upload to Firestore `/users/{uid}/rides`, `/bikes`, `/maintenance`
5. Mark `synced=1` locally
6. Repeat forever (incremental sync)

**Offline-Safe**:
- Recording never needs internet (geolocator + sensors are local)
- Sync is async, non-blocking (user can ride without cloud)
- Queue retries on network reconnect

---

## 🧪 Testing

### Run All Tests

```bash
# All tests
flutter test

# Specific test file
flutter test app/test/calculators/motion_calculator_test.dart

# Watch mode (re-run on change)
flutter test --watch

# Coverage report
flutter test --coverage
```

### Test Suite (100+ tests, ~98% coverage)

**Pure Logic** (TDD best practices, fixture-based):
- **MotionCalculator** (28 tests): Acceleration, jerk, haversine distance calculations
- **CrashDetector** (11 tests): Crash vs pothole, alert TTL, false positive guards
- **PrivacyZoneClipper** (8 tests): Polyline clipping for home location privacy
- **RatingAggregation** (18 tests): Average, distribution, edge cases
- **RideDAO** (24 tests): CRUD, sync, cascade delete operations
- **Data Models** (40+ tests): Serialization, equality, round-trips

**Test Fixtures**:
All tests use realistic data — real coordinates (Dhaka, Chattogram), sensor thresholds, known distances (~260km between cities).

### TDD Approach

All new features follow test-first:
1. Write failing test with realistic fixture data
2. Implement logic to pass test
3. Refactor
4. Commit with test included

**Example: Crash Detection**
```dart
test('DOES fire on crash: accel spike + jerk spike + speed→0 in 2s', () {
  detector.detect(accel: 0, jerk: 0, speedMs: 15.0); // baseline
  detector.detect(accel: 10.0, jerk: 0, speedMs: 15.0); // impact
  detector.detect(accel: 9.5, jerk: 12.0, speedMs: 14.5); // jerk
  final alert = detector.detect(accel: -5.0, jerk: -8.0, speedMs: 0.5); // drop
  
  expect(alert, equals(RideAlert.crash));
  expect(detector.lastCrashSignal!.hadHighAccelSpike, isTrue);
  expect(detector.lastCrashSignal!.hadJerkSpike, isTrue);
  expect(detector.lastCrashSignal!.hadSpeedDrop, isTrue);
});
```

### Coverage Details

See [TEST_SUMMARY.md](TEST_SUMMARY.md) for full breakdown:
- 28 motion/acceleration tests
- 11 crash detection tests
- 18 rating aggregation tests
- 24 database operation tests
- 8 privacy/clipping tests
- 40+ data model tests

---

## 📦 Dependencies

- **flutter_riverpod**: State management (providers, notifiers)
- **geolocator**: GPS location + background tracking
- **sensors_plus**: Accelerometer/gyroscope data
- **sqflite**: Local SQLite database
- **cloud_firestore**: Firestore cloud backend
- **firebase_auth**: User authentication
- **firebase_storage**: Image uploads
- **flutter_map**: Interactive map (ride polyline, POI)
- **go_router**: Navigation (type-safe routing)
- **connectivity_plus**: Detect online/offline state
- **wakelock_plus**: Keep device awake during recording
- **share_plus**: Share live ride link
- **image_picker**: Select bike/POI photos
- **path_provider**: Access Downloads folder (for exports)

See [pubspec.yaml](app/pubspec.yaml) for full list + versions.

---

## 🔒 Security & Privacy

### Data Ownership
- **All user data** lives in `/users/{uid}/...` (Firestore rules enforce user-only access)
- **Deleted rides** are purged from cloud on user request
- **No tracking cookies or analytics** (Firebase Analytics wired but not queried)

### Ride Sharing
- **Privacy zones**: Auto-clips first/last 200m from shared rides (home location safe)
- **Manual control**: User decides which rides to share
- **Revocable**: User can unshare anytime (delete from Firestore)

### Emergency Share
- **Token-based**: Live location link uses unguessable random token (not signed-in required)
- **TTL**: Links auto-expire after 24 hours
- **User control**: Can disable/revoke at any time

### Passwords & Secrets
- **Never stored locally**: Only auth tokens in encrypted SharedPreferences
- **google-services.json** & **key.properties**: Gitignored (never committed)
- **Firestore keys**: Restricted to this app's domain via Firebase Console

---

## 🛠️ Troubleshooting

### "Background recording stopped"
- **Cause**: GPS permission denied or not requested
- **Fix**: Go to phone Settings → ThrottleIQ → Location → "Allow Always"

### Rides not syncing to cloud
- **Cause**: No internet or Firestore rules blocking write
- **Fix**: Check WiFi/cellular, then verify Firebase project & Firestore rules deployed

### Crash detection too sensitive
- **Cause**: Sensor thresholds set low for testing
- **Fix**: See `app/lib/core/constants/sensor_constants.dart` to tune

### iOS build fails
- **Cause**: `GoogleService-Info.plist` missing or not in Xcode
- **Fix**: Download from Firebase Console, add to `app/ios/Runner` in Xcode (Build Phases → Copy Bundle Resources)

---

## 📚 Documentation

- [SETUP.md](SETUP.md) — Firebase setup, Android signing, iOS certificates
- [ASSUMPTIONS.md](ASSUMPTIONS.md) — Architecture decisions, known limitations
- [plan.md](plan.md) — Original audit (phases P0-P9+, feature map)

---

## 🤝 Contributing

Contributions welcome! Please:

1. **Create a feature branch**: `git checkout -b feat/my-feature`
2. **Write tests first** (TDD): Failing test → implementation → pass
3. **Keep commits clean**: One feature per commit, descriptive messages
4. **No secrets**: Use `.env` or Firebase Console; never commit keys
5. **Run tests before push**: `flutter test`
6. **Follow Dart style**: `dart format .` before commit

---

## 📄 License

**ThrottleIQ Source-Available License (TSAL) v1.0** — See [LICENSE](LICENSE)

In short: You can **view and audit** the source code (open-source), but cannot copy, fork, or build a competing app. All rights reserved.

---

## 🗺️ Roadmap

- **v1.0** (Beta, live now): Background tracking, crash detection, POI directory, cloud sync
- **v1.1**: Crash escalation (SMS/email), in-app weather, leaderboards
- **v2.0**: Curvy-route turn-by-turn nav, clubs & group events, in-app monetization (premium features)

---

## 📞 Support & Feedback

- **Report bugs**: [GitHub Issues](https://github.com/blankframe-tech/ThrottleIQ/issues)
- **Feature requests**: Comment on issues or discussions
- **Privacy questions**: See [ASSUMPTIONS.md](ASSUMPTIONS.md) "Security & Privacy"

---

**Built with ❤️ for riders. Safe travels! 🏍️**

*Last updated: 2026-07-12*
