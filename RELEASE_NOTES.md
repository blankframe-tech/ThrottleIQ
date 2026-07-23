# ThrottleIQ Release Notes

## v2.0.0-beta.4+6 (2026-07-24) — Notifications, sync fixes, and a real app icon

**Status:** ✅ Released (pre-release) · signed APK on GitHub · package
`com.bft.throttleiq`

Everything below shipped on `main` (see `HANDOFF_V2.md` §1–§9 for the full
technical account — there was never a separate `feat/v2-social` branch,
despite this file's history of implying one). Two rounds of real live-usage
testing drove most of this release, on top of the previously-completed v2
social/community rework (profiles, follow, forums, garage/service, places,
Rides tab, safety).

### Fixed — the safety-critical one
- **Ride data lost when the app was killed mid-ride with the screen off.**
  The ride-recovery path existed but was never actually called, and an
  interrupted ride's status never flipped to "completed" — so it just
  vanished from history rather than showing up damaged. Now recovers real
  stats from whatever GPS points made it to disk, and the write-buffer/
  screen-off-flush changes shrink how much can be lost in the first place.
  Also requested Android's battery-optimization exemption, since several
  OEMs kill background recording even with an active foreground service
  without it.

### Fixed — sync, navigation, forums
- Bikes (and rides/maintenance) now sync **both ways** between devices —
  sync was upload-only before, so a second device signing into the same
  account never saw data from the first.
- The garage screen's "Tap for maintenance" link now reliably opens
  maintenance instead of silently falling through to bike detail.
- Forum-post creation no longer crashes (`TextEditingController` used after
  disposal — took three attempts across this and the prior release to
  actually find the real cause; see `HANDOFF_V2.md` §8a for the account).
- Forum vote failures now show an error instead of silently reverting with
  no feedback (looked exactly like "my vote disappeared").
- Fixed a Navigator crash on the garage user menu and bike delete
  confirmation, and a Firestore permission-denied error on the Social feed.

### Added
- **Usernames + public profiles.** Every rider now gets an @handle
  (auto-assigned from their email, editable at signup and later), and a new
  profile screen (avatar, bio, follow button, total km/rides, earned
  badges) reachable from search results or a forum post's author byline.
  Profile visibility can be set to everyone / mutual followers / only me.
- **Follow notifications** — in-app (bell icon + notifications screen), not
  a phone push (that needs Cloud Functions, blocked on the same
  no-payment-card constraint as Firebase Storage below).
- Swipe-to-start replaces hold-to-start for beginning a ride recording.
- Rotating dashboard taglines instead of the same static "Your ride,
  smarter." every time.
- A real app icon (the gauge mark), replacing the placeholder — the
  launcher-icon config pointed at files that didn't exist before this.

### Improved
- Speed display responsiveness: tightened GPS settings (including a
  previously-missing iOS-specific tuning branch) and added smooth
  interpolation between readings on the active-ride screen.
- Rides tab: distance/speed charts and 13 milestone badges (previously 5).
- Firebase Storage dropped in favor of Cloudinary for avatar/photo uploads
  — the project has no payment card, and Storage now requires the Blaze
  plan even within its free tier.

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
