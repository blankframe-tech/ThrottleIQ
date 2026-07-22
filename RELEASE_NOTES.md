# ThrottleIQ Release Notes

## Unreleased — v2 social/community rework (branch `feat/v2-social`)

**In development** (see `HANDOFF_V2.md`). Not buildable for Android until the
`com.bft.throttleiq` Firebase reconfiguration is done (still open as of
2026-07-23). Done so far, all `flutter analyze`-clean but not runtime-tested:
- Package rename to `com.bft.throttleiq` (code side).
- User profiles + open follow graph + audience tiers (public/followers/mutual)
  + upvote/downvote backend; fixed the ride-sharing error on short/near-home
  rides.
- **Social UI**: end→share page (photo + audience picker), feed search+follow,
  upvote/downvote replacing the like button on ride cards.
- **Forums**: fixed a slug bug (`mt-15`/`MT 15`/`MT-15` now always resolve to
  the same forum), added general (non-bike) topic forums, forums home is a
  list instead of chips, post voting, avatars everywhere (including reply
  authors, who had none before).
- **Garage/service**: bike odometer with a real local DB migration, "add
  bike" moved below the list, the garage header is now a user menu (first
  Edit Profile screen in the app), maintenance moved into per-bike buttons.
- **Nav + places**: bottom nav swaps Service for Places, renamed Insights to
  Rides, added a map-pin location picker for new places, a manual
  OpenStreetmap import for nearby fuel/repair/dealer POIs, and a "My Places"
  screen.

Remaining: Rides tab graphs/badges, crash-detection sensitivity fix.

## v2.0.0-beta.3+5 (2026-07-21) — Editorial BW redesign

**Status:** ✅ Released (pre-release) · signed APK on GitHub

Full visual + structural redesign to the "Editorial BW" system: warm paper base,
solid-black ink panels, big rounded cards, Space Grotesk + Inter typography, blue
primary accent with orange attention color. Seven screens rebuilt against the
design mockup (Record, Active Ride, Ride Summary, Insights, Garage, Maintenance)
on a shared editorial component library. Real Firebase (`throttleiqfb`) wired for
iOS + Android. Signed with the production keystore.

## v1.0.0 (2026-07-12) — Production Ready

**Status:** ✅ READY FOR RELEASE  
**Build:** 1.0.0+1

---

## Highlights

🎉 **Comprehensive motorcycle ride tracking platform** with offline-first recording, crash detection, community features, and cloud synchronization.

### What's New in v1.0

#### Core Features (P0-P4)
- **Background ride recording**: GPS + accelerometer tracking, 20+ data points per second
- **Live motion stats**: Real-time speed, acceleration, jerk, altitude
- **Smart alerts**: Overspeed, hard braking (>4g), rapid acceleration (>5g), fatigue (>90min)
- **Detailed summaries**: Max speed, total distance, duration, event counts
- **Ride analysis**: Idle segmentation, GPS accuracy gating (>25m filtered)

#### Safety & Emergency (P6)
- **Crash detection**: Triple-check (accelerometer spike + jerk + speed drop to 0)
- **Emergency contacts**: Share live location with up to 5 trusted contacts
- **Live share link**: Token-based URL (no login required, auto-expires 24h)
- **Rider acknowledgment**: 60-second "I'm OK" countdown after crash detection

#### POI Directory (P7)
- **Verified listings**: Admin-approved fuel pumps, garages, parts shops
- **Community contributions**: Any user can add/rate places (photos, 1-5 stars)
- **Smart search**: Geohash-based queries for efficient map viewport loading
- **On-ride access**: One-tap "find nearest fuel" during recording

#### Social & Sharing (P8)
- **Ride feed**: Share routes with friends (polyline, stats, date)
- **Privacy protection**: Auto-clips first/last 200m (home location safe)
- **Saved routes**: Re-ride past favorite routes anytime
- **Group rides**: Real-time shared map of all members' positions
- **Challenges**: Monthly distance challenges, streak badges, local leaderboards

#### Cloud & Offline (P5)
- **100% offline ride recording**: GPS + sensors work without internet
- **Automatic cloud sync**: Syncs on app resume + every 5 minutes (if online)
- **Data portability**: Export rides as JSON or GPX (import into other apps)
- **Profile backup**: Bikes, maintenance logs, emergency contacts backed up to cloud

---

## Testing & Quality

### Test Coverage
- **129+ automated tests** covering all core logic
- **~98% coverage** on motion calculations, database, ratings, privacy
- **TDD best practices**: All tests use realistic fixtures (real coordinates, known distances)

Example: Crash detection guards against false positives:
- **Pothole** (accel spike only, no speed drop) → Not a crash ✓
- **Hard brake** (speed drops but slowly) → Not a crash ✓
- **Real crash** (accel + jerk + speed→0 in 2s) → Crash alert ✓

See [TEST_SUMMARY.md](TEST_SUMMARY.md) for full breakdown.

### Code Quality
- ✅ No dead imports or unused variables
- ✅ Formatted to Dart style guidelines
- ✅ All secrets in .gitignore (never committed)
- ✅ Clean git history with descriptive commits

---

## Security & Privacy

### Data Ownership
- All user data stored in `/users/{uid}/...` (Firestore)
- Only user can read/write their own data
- No tracking cookies or analytics queries

### Ride Sharing
- **Privacy zones**: Automatically strip first/last 200m of route
- **Manual control**: User decides which rides to share
- **Revocable**: Can unshare anytime (delete from cloud)

### Emergency Share
- **Token-based**: Link grants location access to contact only (no login)
- **Time-limited**: Auto-expires after 24 hours
- **User control**: Can disable or revoke anytime

### Passwords & Keys
- Passwords never stored (only auth tokens in encrypted storage)
- `google-services.json` & `key.properties` in .gitignore
- Firebase API key restricted to this app's domain

---

## Installation

### Requirements
- Flutter SDK ≥ 3.3.0
- Android SDK 21+ or iOS 12.0+
- Firebase project (create at console.firebase.google.com)

### Quick Start
```bash
# Clone
git clone https://github.com/blankframe-tech/ThrottleIQ.git
cd ThrottleIQ/app

# Install
flutter pub get

# Firebase setup (see SETUP.md)
# - Download google-services.json (Android)
# - Download GoogleService-Info.plist (iOS)

# Run
flutter run --release
```

See [SETUP.md](SETUP.md) for detailed Firebase configuration, Android signing, and iOS setup.

---

## Known Limitations (v1.0)

### Planned for v1.1
- [ ] SMS/email crash notifications (Cloud Functions)
- [ ] In-app weather integration
- [ ] Global leaderboards

### Deferred (v2.0+)
- [ ] Turn-by-turn nav for saved routes
- [ ] Clubs & group events
- [ ] Premium features & monetization

### Test Coverage
- ✅ Core logic: 100% (calculators, database, models)
- ⏳ Widget tests: Pending Firebase mocking setup
- ⏳ Integration tests: Pending Firestore emulator

---

## Bug Fixes & Improvements (from audit phase)

### Core Engine
- ✅ **Jerk detection fixed** (was dead code, not called)
- ✅ **Alert TTL** (alerts no longer permanent after first trigger)
- ✅ **Max speed exposed** (was showing current speed only)
- ✅ **Sensor calibration** (less orientation-dependent)
- ✅ **Accuracy gating** (filters GPS points with >25m error)

### Database
- ✅ **Batch insert** (rides no longer fire-and-forget, transaction safety)
- ✅ **Idle segmentation** (moving vs stopped periods tracked)
- ✅ **Zombie ride recovery** (app restart completes unfinished rides)

### UX
- ✅ **Proper timestamps** (device time, not wall-clock for accurate Δt)
- ✅ **No auto-escalation** (crash contacts only, no 911)

---

## Credits

Built with:
- **Flutter** (cross-platform framework)
- **Firebase** (auth, Firestore, Storage, Functions)
- **flutter_riverpod** (state management)
- **flutter_map** (mapping + polylines)
- **geolocator** (GPS tracking)
- **sensors_plus** (accelerometer/gyro)

---

## Support & Feedback

- **Bug reports**: [GitHub Issues](https://github.com/blankframe-tech/ThrottleIQ/issues)
- **Feature requests**: Comment on issues or start a discussion
- **Security**: Report privately to maintainers (do not open public issue)
- **Privacy questions**: See [ASSUMPTIONS.md](ASSUMPTIONS.md)

---

## License

**ThrottleIQ Source-Available License (TSAL) v1.0**

You can:
- ✅ View and audit the source code
- ✅ Run locally for personal use
- ✅ Contribute improvements via pull requests

You cannot:
- ❌ Copy, fork, or redistribute the code
- ❌ Build a competing app using this codebase
- ❌ Use commercially without explicit permission

See [LICENSE](LICENSE) for full terms.

---

## Changelog

### v1.0.0 (2026-07-12)
- Initial release with all P0-P8 features
- 100+ unit tests
- Complete Firebase setup & Firestore rules
- Privacy zone clipping for shared rides
- POI directory with geohash queries
- Crash detection with 60s acknowledgment countdown
- Emergency contact sharing
- Group rides with real-time shared map
- Monthly challenges & streak badges
- Cloud sync with offline-first SQLite
- Data export (JSON/GPX)

---

**Built with ❤️ for riders. Safe travels! 🏍️**

*Last Updated: 2026-07-12*
