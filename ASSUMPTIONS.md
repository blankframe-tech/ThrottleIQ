# ThrottleIQ Implementation Assumptions & Notes

**Project**: Complete ThrottleIQ ride tracking app with cloud backend  
**Status**: P0-P4 complete; P5-P9+ in progress  
**Updated**: 2026-07-12

---

## Architectural Decisions (Auto-Implemented)

### Cloud Database & Backend
- **Firestore** for all cloud data (rides, bikes, places, reviews, live sessions)
- **Firebase Storage** for images (POI photos, profile pictures, ride thumbnails)
- **Firebase Authentication** already wired (email/password + anonymous for guest)
- **Cloud Functions** for crash notifications, invite emails, batch operations
- **Security Rules** enforce:
  - Users see only their own rides/bikes/maintenance
  - Places readable to all signed-in users, writable as specified
  - Live sessions readable via token only (capability pattern)
  - Admin operations require custom claims
- **Firestore indexes** auto-created on first query (dev mode); production uses CLI deployment

### Mobile App Behavior
- **Offline-first SQLite** remains source of truth during recording
- **Automatic sync** on app resume/every 5min when online (connectivity_plus gates it)
- **Anonymization**: User data keyed by uid only; names never in public collections
- **Cloud-optional**: App works 100% offline; sync is async background task
- **Auto-recovery**: Crash mid-ride → recover on app restart, finalize ride, sync on reconnect

### Testing Strategy
- **TDD on all business logic**: Pure functions (calculator, formatters, validators) have 100% test coverage
- **Integration tests** on DB layer (sqflite_common_ffi in-memory)
- **Widget tests** on key UI (record screen, summary, map interactions)
- **No unit-test Firebase** (use emulator for integration tests if needed, else skip Firebase-specific tests)
- **E2E**: Manual on real device before pushing major features

### Code Quality Standards
- **No dead code**: Grepping for unused imports/functions before commit
- **Minimal comments**: Only "why" non-obvious; "what" is in function names
- **No secrets in repo**: google-services.json, key.properties, .env all gitignored (templates provided)
- **Type safety**: All variables properly typed; no dynamic unless unavoidable
- **Error handling**: Only at system boundaries (API, UI input); internal code assumes valid state

### Firestore Schema (Auto-Deployed)
```
/users/{uid}
  - email, displayName, photoUrl, role, createdAt, updatedAt
  
/users/{uid}/rides/{rideId}
  - bikeId, startTime, endTime, distanceM, avgSpeedMs, maxSpeedMs, durationS
  - hardBrakeCount, rapidAccelCount, highJerkCount
  - syncedAt (local: DateTime.now() on upload)
  
/users/{uid}/bikes/{bikeId}
  - brand, model, year, cc, color, odoM, photoUrl
  - lastRideAt, totalDistanceM, rideCount
  - syncedAt
  
/users/{uid}/maintenance/{logId}
  - type (oil, service, etc), date, odoKm, cost, notes
  - syncedAt

/rides/{rideId}
  - uid, polyline (encoded), summary (json blob with stats)
  - createdAt (server timestamp)
  
/places/{placeId}
  - name, category (fuel|garage|parts), geo (geohash, lat, lng)
  - address, phone, hours, photoUrls[], verified, createdBy, createdAt
  - ratingSum, ratingCount
  
/places/{placeId}/reviews/{userId}
  - stars, text, imageUrls[], createdAt, flagged
  
/liveSessions/{token}
  - uid, rideId, active, lastLat, lastLng, speedMs, headingDeg, batteryPct
  - status (riding|idle|crash|ended), updatedAt, expiresAt
  - TTL index auto-deletes after 24h
  
/emergencyContacts/{uid}
  - contacts[] = [{name, phone, email}]
```

### Feature Priorities (P5-P9+)
1. **P5 (CRITICAL)**: Cloud sync + profile setup → data survives phone loss
2. **P6 (CRITICAL)**: Emergency contact + crash detection → safety feature (MVP differentiation)
3. **P7 (HIGH)**: POI directory → rider utility (fuel, garages, parts)
4. **P8 (MEDIUM)**: Social (feed, shared routes, challenges) → retention loop
5. **P9+ (LATER)**: Advanced (routing, segments, clubs) → V2 features after beta validation

### Known Limitations (Documented, Not Bugs)
- **Avg speed still mean-of-samples** (will improve to distance/movingTime after beta)
- **Sensor calibration**: Still heuristic (GPS fusion deferred to v1.1)
- **POI search**: Geohash-based (simple), not real-time autocomplete
- **Offline-first limit**: ~10MB local DB on typical device; cleanup policy on rotation
- **No payment yet**: All features free in V1; premium tier (crash escalation, weather) deferred to P8+

### Deployment & CI/CD
- **Build**: `flutter build apk` for Android; `flutter build ios` for iPhone
- **Firebase**: Console-deployed Firestore rules (see `firestore.rules` in repo)
- **Distribution**: Play Store (internal testing), TestFlight (iOS), GitHub Releases (APK)
- **Environment**: TIPSOI_MOCK=0 (live API) in prod; dev uses same unless testing offline

### What's NOT Included (By Design)
- **Backend analytics**: Firebase Analytics wired but dashboards not built
- **Admin panel**: Moderation done via Firebase console (write rules for admin claim)
- **Push notifications**: FCM set up but crash/event notifications in Cloud Function (not shipped yet)
- **In-app payments**: Stripe integration deferred; use Apple/Google IAP if monetizing
- **ML features**: Crash/pothole detection logic in code; TF Lite model not included

### Assumptions About User Env
- **Minimum Android**: SDK 21 (Android 5.0+); target 34+
- **Minimum iOS**: 12.0+
- **Phone hardware**: GPS + accelerometer (universal on modern phones)
- **Connectivity**: Rides work 100% offline; sync requires internet (not critical path)
- **Location privacy**: App declares all permissions; user grants; no silent location tracking

---

## Files & Directories

- `app/` → Flutter project (mobile app)
- `app/lib/features/` → Feature modules (auth, ride, garage, maintenance, etc)
- `app/lib/core/` → Shared utilities, database, theme, constants
- `.gitignore` → Excludes `google-services.json`, `key.properties`, `ios/firebase.json`
- `ASSUMPTIONS.md` → This file
- `README.md` → User-facing onboarding (updated after P5+)

---

## Next Steps (After This File)

1. **P5**: Implement Firestore sync + cloud schema
2. **P6**: Emergency contacts + crash detection with countdown UI
3. **P7**: POI map + directory + ratings
4. **P8**: Feed, shared routes, group rides
5. **P9+**: Turn-by-turn routing, leaderboards, clubs
6. **Final**: E2E testing, README update, GitHub release

---

## Contact & Support

- **Issue tracker**: GitHub Issues (tracked in this repo)
- **Roadmap**: See `plan.md` (original audit + forward plan)
- **Code style**: Dart conventions + Flutter best practices (no lints ignored)
- **License**: ThrottleIQ Source-Available License (TSAL v1.0) — see LICENSE file

---

**Last Updated**: Implementation in progress (P5+ starting)  
**Next Checkpoint**: P5 complete + cloud sync live + test suite passing
