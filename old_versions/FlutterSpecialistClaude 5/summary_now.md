# ThrottleIQ — Session Summary
**Date:** 2026-04-28  
**Project path:** `throttleiq/` (Flutter app)  
**APK built:** `throttleiq/build/app/outputs/flutter-apk/app-release.apk` (56.1 MB, release)

---

## What Was Built (V1 MVP — Complete)

Full motorcycle tracking Flutter app built from a PRD (Goal.md). Offline-first architecture.

### Stack
- Flutter + Riverpod (AsyncNotifier pattern, no codegen/build_runner)
- go_router for navigation
- Firebase Auth (email/password)
- SQLite via sqflite (offline-first, `synced` flag on all tables)
- geolocator + sensors_plus for GPS + motion data
- fl_chart for charts, flutter_map for maps, dio for networking

### Features Implemented

#### Auth
- `SplashScreen` → `LoginScreen` → `RegisterScreen` → `OnboardingScreen` (set display name)
- Firebase Auth via `authStateProvider` (StreamProvider)
- go_router redirect guards based on auth + displayName state

#### Garage
- Add/edit/delete bikes (brand, model, year, CC, image)
- Active bike selection
- Per-bike stats: total distance, ride count, last ride
- Screens: `GarageScreen`, `BikeDetailScreen`, `AddEditBikeScreen`

#### Ride Recording
- GPS ride recording with state machine (`RideRecordingProvider`)
- Physics engine: speed, acceleration, jerk from GPS + accelerometer (`MotionCalculator`)
- Event detection: hard brakes, rapid acceleration, high jerk (`EventDetector`)
- Screens: `RecordScreen` (pre-ride), `ActiveRideScreen` (live), `RideSummaryScreen`
- Ride points stored in SQLite (`ride_points` table with lat/lng/speed/acceleration/jerk)

#### Maintenance
- Log service events: Oil Change, Air Filter, Chain Lube, Tire Check, Custom
- Fields: service type, date, odometer (km), cost, notes
- Reminders system (`MaintenanceReminder` entity with ReminderStatus: ok/dueSoon/overdue)
- Screens: `MaintenanceScreen`, `AddMaintenanceLogScreen`

#### AI Chatbot
- `ChatbotScreen` (UI shell — actual AI integration not wired up yet)

#### Social
- `SocialScreen` (UI shell — not fully implemented)

### Core Infrastructure
- `DatabaseHelper` — SQLite schema, version 1
  - Tables: `bikes`, `rides`, `ride_points`, `maintenance_logs`
- `AppRouter` — all routes with auth guards
- `AppTheme` + `AppColors` — dark theme
- `AppShell` — bottom nav (Social, Chatbot, Record, Maintenance, Garage)
- `HapticService`, `SpeedFormatter`, `DateTimeExtensions`
- Shared widgets: `AppCard`, `StatCard`

---

## Bug Fixed This Session

**Splash screen infinite loading on installed APK.**

- **Root cause:** `SplashScreen` used `ref.listen(authStateProvider, ...)` which only fires on *changes*. If Firebase Auth resolves before the splash widget's first build completes, the initial stream emission is missed — listener never fires, spinner runs forever.
- **Fix:** Added `ref.watch(authStateProvider).whenData(...)` with `addPostFrameCallback` alongside the existing `ref.listen`. This catches the case where auth state is already resolved on first build.
- **File:** `lib/features/auth/presentation/screens/splash_screen.dart`

---

## Setup Required to Run (Not Done Yet)

1. Firebase project → `google-services.json` in `android/app/`
2. Google Maps API key in `android/app/src/main/AndroidManifest.xml`
3. See `throttleiq/SETUP.md` for full steps

---

## TODO / Feature Backlog

### P0 — Required to fully function
- [ ] Wire up actual Firebase project (`google-services.json`)
- [ ] Add Google Maps API key to AndroidManifest
- [ ] `ChatbotScreen`: connect to actual AI backend (Claude API or similar)
- [ ] `SocialScreen`: implement actual social feed / sharing

### P1 — Fuel & Cost Tracking (User Feature Request)
> User request (Bengali): *"app এ মাইলেজ হিসাব, কতো খরচ করলাম গাড়িতে, পার কিলো চলতে কতো খরচ হল"*  
> Translation: Mileage calculation, total vehicle spend, cost per kilometer

- [ ] **Fuel fill-up log** — new feature, not in current codebase
  - Add `fuel_logs` table to SQLite: `id, bike_id, date, liters, price_per_liter, total_cost, odometer_km`
  - Add `FuelEntity`, `FuelModel`, `FuelDAO`
  - Add `ServiceType.fuelFillup` or separate fuel section in Maintenance screen
  - UI: log form (liters, price/liter, odometer at fill-up)
- [ ] **Mileage calculation** (km per liter)
  - Formula: `km_since_last_fillup / liters_added`
  - Show per-fillup and rolling average on bike detail screen
- [ ] **Total spend tracking**
  - Sum: `fuel_logs.total_cost` + `maintenance_logs.cost` per bike
  - Breakdown chart on bike detail: fuel vs. maintenance spend
- [ ] **Cost per kilometer**
  - Formula: `total_spend / total_distance_km`
  - Show on bike detail and optionally per-ride if fuel is prorated
- [ ] **Fuel screen / tab** — dedicated screen or section under Maintenance

### P2 — Quality & Polish
- [ ] Database migration system — current schema is version 1, no migration path. Needed before adding `fuel_logs` table
- [ ] Ride history list screen (no dedicated history browser built yet)
- [ ] Map route replay on `RideSummaryScreen`
- [ ] Export ride data (GPX / CSV)
- [ ] Push notifications for maintenance reminders (firebase_messaging already in pubspec)
- [ ] iOS build + `GoogleService-Info.plist`
- [ ] Unit tests (test/ only has default widget_test.dart)

### P3 — Future
- [ ] Cloud sync (rides, maintenance, fuel — `synced` flag already in schema, no sync logic written)
- [ ] Social sharing of ride stats
- [ ] Wear OS / smartwatch integration

---

## Key File Map (for quick pickup)

| What | Where |
|---|---|
| Entry | `lib/main.dart`, `lib/app.dart` |
| Router + auth guards | `lib/core/router/app_router.dart` |
| DB schema | `lib/core/database/database_helper.dart` |
| Auth provider | `lib/features/auth/presentation/providers/auth_provider.dart` |
| Splash (fixed) | `lib/features/auth/presentation/screens/splash_screen.dart` |
| Ride state machine | `lib/features/ride/presentation/providers/ride_recording_provider.dart` |
| Physics engine | `lib/features/ride/domain/calculators/motion_calculator.dart` |
| Event detector | `lib/features/ride/domain/calculators/event_detector.dart` |
| Maintenance entity | `lib/features/maintenance/domain/entities/maintenance_entity.dart` |
| Maintenance DAO | `lib/core/database/daos/maintenance_dao.dart` |
| Colors/theme | `lib/core/constants/app_colors.dart`, `lib/core/theme/app_theme.dart` |
