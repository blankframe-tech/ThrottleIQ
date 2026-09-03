# ThrottleIQ — Optimizer Plan

> Generated: 2026-09-03 | Status: pre-launch beta `1.0.0-beta.1+5`

This plan identifies concrete, prioritized improvements across performance, reliability, architecture, and user experience. Each item maps to real code already in the repository.

---

## 🔴 P0 — Critical / Launch Blockers

### 1. `ride_recording_provider.dart` is 1 810 lines — split it up

[ride_recording_provider.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/features/ride/presentation/providers/ride_recording_provider.dart) is a 77 KB monolith. It owns:
- GPS position handling, sensor fusion, adaptive thinning, outbox enqueue, wakelock, live-share token management, crash detection flow, fatigue alerting, home-widget refresh, and bike selection.

**Risk**: any change anywhere touches everything. A compiler error mid-function is unreadable.

**Recommended split**:
| New file | Responsibility |
|---|---|
| `ride_session_controller.dart` | Lifecycle (start / pause / stop / restore) |
| `gps_position_handler.dart` | `_onPosition`, haversine fallback, polyline append |
| `crash_alert_coordinator.dart` | 60-second countdown, emergency-contact trigger, live-session teardown |
| `ride_share_coordinator.dart` | Outbox enqueue, share-audience selection |
| `live_session_manager.dart` | Token creation, Firestore pointer, battery broadcast |

> [!CAUTION]
> Do this in a feature branch before any new features land, or merges will be conflict nightmares.

---

### 2. `VehicleStateEstimator` confidence score is unused in the UI

`RideRecordingState.confidence` is computed by [vehicle_state_estimator.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/features/ride/domain/calculators/vehicle_state_estimator.dart) and threaded all the way into state — but the file itself says *"Plumbing only in this phase; not yet surfaced in any screen."*

The confidence score **already gates crash alerts** (`minConfidenceForCrashAlert = 40`) and **adaptive thinning** (`minConfidenceToThinRecording = 70`). If it is wrong or miscalibrated, crashes silently go undetected. Expose it on the debug overlay / developer settings screen so it can be watched during beta rides.

---

### 3. Cloud Functions blocked on Firebase Blaze — unblock with a free-tier alternative

`crash-notifications.ts` is written but **cannot be deployed on the Spark plan**. The README and `docs/backend_options.md` acknowledge this. Before Play Store launch:

- **Option A**: Upgrade to Blaze (pay-as-you-go; crash notification volumes are tiny).
- **Option B**: Route through a free Cloudflare Worker that calls Twilio/SendGrid (no cold-start billing).
- **Option C**: Use Firebase App Distribution's webhook mechanism as a lightweight trigger.

The client-side crash detection and 60-second countdown work fine. The missing piece is the **15-minute escalation** when a contact doesn't acknowledge. Without this, the emergency feature is incomplete for a safety-first product.

> [!IMPORTANT]
> Pick a path before Play Store submission. The store listing advertises crash detection + emergency contacts.

---

## 🟠 P1 — High Impact / Near-term

### 4. `AccelAxisCalibrator` minimum determinant is a magic number, not validated

The doc comment on [accel_axis_calibrator.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/features/ride/domain/calculators/accel_axis_calibrator.dart) says:

> *"Its exact value is a starting point, not a tuned constant — like the hard-brake/rapid-accel thresholds it feeds, getting it right needs real ride logs to check the fitted axis against, which wasn't available here."*

**Action**: After the first 100 beta rides, export ride logs (JSON/GPX already exist), replay them through a validation script, and tune `_minDeterminant` and `_minSamples` against ground-truth. A ride-replay harness skeleton already exists in `AutoRideReconciler`.

---

### 5. `OutboxService` is a global singleton — introduce a proper provider

[outbox_service.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/core/cloud/outbox_service.dart):
```dart
static final OutboxService instance = OutboxService();
```
This pattern bypasses Riverpod entirely, makes the outbox untestable without a real database, and creates an implicit initialization ordering dependency with `SyncManager`. Convert to a Riverpod `Provider` so it participates in the dependency graph and can be overridden in tests.

---

### 6. `RecordingCadencePolicy` shares the same clock for event and thinned points

[recording_cadence_policy.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/features/ride/domain/calculators/recording_cadence_policy.dart) resets `_lastPersistedTimestamp` for **both** forced event points (corners) and throttled steady points. A corner at t=0 will suppress the next steady point until t=5 s, even though it shouldn't — a corner should reset the event clock, not the steady-highway clock.

**Fix**: maintain two separate timestamps, one per reason. Gives more accurate straight-line thinning without losing corner detail.

---

### 7. `DatabaseHelper` schema is at version 12 — add a migration smoke-test

[database_helper.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/core/database/database_helper.dart) already exposes `upgradeSchemaForTesting`. The test suite does not appear to exercise every `_onUpgrade` leg (versions 1→2, 2→3, … 11→12). A single parameterized test that opens version N and upgrades to 12 would catch the deadlock class of bug described in Issues.md §7 before it reaches riders.

---

### 8. iOS auto-tracking gap is undocumented to users

The pubspec and `auto_tracking_service.dart` clearly document the iOS limitation:
> *"on iOS, the task handler does not survive the rider force-swiping ThrottleIQ from the app switcher"*

This is never shown to iOS users. Add a one-time onboarding card (or a `⚠️` badge on the auto-tracking toggle for iOS) explaining: *"For uninterrupted auto-detection, keep ThrottleIQ in the background rather than force-closing it."*

---

## 🟡 P2 — Quality / Maintainability

### 9. `SensorConstants` overspeed threshold is hardcoded to 100 km/h — make it user-configurable

[sensor_constants.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/core/constants/sensor_constants.dart):
```dart
static const double overspeedThreshold = 27.8; // 100 km/h
```
Speed limits vary: a 60 km/h urban rider wants early warning; a highway tourist may want 130 km/h. Even a simple Settings slider (60–140 km/h) persisted to `SharedPreferences` makes this instantly useful.

---

### 10. `EventDetector` crash threshold is not in `SensorConstants`

```dart
static const double _crashAccelThreshold = 80.0; // m/s² (~8.2g)
```
This is a private constant buried in [event_detector.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/features/ride/domain/calculators/event_detector.dart), while the *other* thresholds (hard braking, rapid accel, overspeed) live in `SensorConstants`. Move it there so all tunable sensor values are in one discoverable location. The troubleshooting README already says *"See `sensor_constants.dart` to tune"* — crash sensitivity should be equally accessible.

---

### 11. `OutboxService` only handles two `OutboxKind` values — maintenance sync is missing

The outbox (`share_ride`, `live_session_teardown`) does not cover maintenance-log cloud sync. If a rider logs a service while offline, it goes through a different path (`SyncManager` direct write). Unifying all offline cloud writes through the outbox gives a single retry/backoff surface and a single badge count.

---

### 12. `home_widget_service.dart` makes raw DAO calls — route through providers

[home_widget_service.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/core/services/home_widget_service.dart) instantiates `RideDao`, `BikeDao`, `MaintenanceDao` directly. This duplicates the provider graph's caching and bypasses any provider-level business logic that may be added later. Pass data in from the caller (a Riverpod provider already has the data) rather than having the service re-fetch.

---

### 13. `ride_recording_provider.dart` imports `cloud_firestore` directly

[ride_recording_provider.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/features/ride/presentation/providers/ride_recording_provider.dart) line 41:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```
A presentation-layer provider should not import the cloud SDK directly — that belongs in the data/repository layer. The live-session Firestore write should go through a repository or at least the `OutboxService`.

---

### 14. Add `build_runner` + `freezed` for immutable state classes

`RideRecordingState` has a hand-written `copyWith` implementation (typical for large Riverpod apps). With 15+ fields and growing, this is error-prone. `freezed` would generate `copyWith`, `==`, `hashCode`, and `toString` automatically, and enforce immutability.

---

## 🟢 P3 — UX & Product Polish

### 15. Ride-share polyline is stored as `[[lat, lon], ...]` in the outbox payload — this is expensive

For a long ride, encoding every GPS point as a JSON list-of-lists in the outbox SQLite row is large and slow to serialize. The codebase already has [ride_track_codec.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/core/cloud/ride_track_codec.dart) — use its encoded form in the outbox payload, decode on delivery. Reduces outbox row size by ~60–70% for long rides.

---

### 16. `AutoRideReconciler` rejection reasons are stored but never surfaced to the user

[auto_ride_reconciler.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/features/ride/domain/calculators/auto_ride_reconciler.dart) stores `rejectionReason` (`too_few_fixes`, `too_short_distance`, etc.) on discarded detections. Show these in a "Recent auto-detections" section of the Rides screen so a rider who wonders *"why didn't it record my 4-minute trip?"* gets an answer without contacting support.

---

### 17. `fl_chart` upgrade — v0.68 is not the latest

`fl_chart: ^0.68.0` — current stable is 0.70+, which includes significant performance improvements for large datasets. Ride history charts with many data points will benefit.

---

### 18. Bangla localization is partial — complete it before Play Store submission

The pubspec bundles `NotoSansBengali-Variable.ttf` and `flutter_localizations` is set up. If the ARB file is incomplete, every untranslated string renders in English on a Bangla-locale device, which looks unpolished for the target Bangladesh market. Audit `lib/l10n/*.arb` and fill gaps.

---

### 19. `WeatherService` failure is silent — display a "weather unavailable" badge

[weather_service.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/core/services/weather_service.dart) is 3 KB; if it fails (no internet, API rate-limit, bad coordinates), the ride summary silently shows no weather. A small `—` badge with a tooltip *"Weather data unavailable for this ride"* prevents confusion.

---

## 🔵 P4 — Architecture / Future-Proofing

### 20. Introduce a `RideRepository` interface in the domain layer

Currently `RideDao` (SQLite) is imported directly by `ride_recording_provider.dart` and `cloud_repository.dart`. Wrapping it behind a `RideRepository` interface makes swapping or mocking trivial and aligns with the clean-architecture shape already used in features like `profile` and `forums`.

### 21. Evaluate Kalman / EKF for Phase 2 of `VehicleStateEstimator`

`vehicle_state_estimator.dart` is deliberately a complementary filter with a documented roadmap to EKF. Now that the confidence score is working, collect real ride data to validate whether the complementary filter's heading dead-reckoning diverges on long GPS outages (tunnels, underground parking). If it does, Phase 2 EKF is worth prioritizing.

### 22. `SyncManager` 5-minute timer should be exponential-back-off on repeated failure

[sync_manager.dart](file:///f:/BlankFrameTechnologies/ThrottleIQ/app/lib/core/cloud/sync_manager.dart) polls every 5 minutes unconditionally. If a user's Firestore project is misconfigured, this fires 288 times/day of guaranteed failures. The `outboxBackoff` function in `outbox_service.dart` already implements the right pattern — reuse it here.

---

## Summary Table

| Priority | # | Area | Effort |
|---|---|---|---|
| 🔴 P0 | 1 | Split 1810-line provider | High |
| 🔴 P0 | 2 | Surface confidence score in debug UI | Low |
| 🔴 P0 | 3 | Unblock Cloud Functions (Blaze or alternative) | Medium |
| 🟠 P1 | 4 | Tune `AccelAxisCalibrator` from beta ride data | Medium |
| 🟠 P1 | 5 | Convert `OutboxService` singleton to Riverpod provider | Medium |
| 🟠 P1 | 6 | Fix `RecordingCadencePolicy` shared clock | Low |
| 🟠 P1 | 7 | Add `_onUpgrade` migration smoke-tests | Low |
| 🟠 P1 | 8 | iOS auto-tracking onboarding card | Low |
| 🟡 P2 | 9 | User-configurable overspeed threshold | Low |
| 🟡 P2 | 10 | Move crash threshold to `SensorConstants` | Trivial |
| 🟡 P2 | 11 | Add maintenance sync to outbox | Medium |
| 🟡 P2 | 12 | Remove DAO calls from `HomeWidgetService` | Low |
| 🟡 P2 | 13 | Remove Firestore import from presentation layer | Low |
| 🟡 P2 | 14 | Add `freezed` for immutable state | Medium |
| 🟢 P3 | 15 | Use `RideTrackCodec` in outbox payloads | Low |
| 🟢 P3 | 16 | Surface auto-detection rejection reasons | Low |
| 🟢 P3 | 17 | Upgrade `fl_chart` to 0.70+ | Trivial |
| 🟢 P3 | 18 | Complete Bangla ARB localization | Medium |
| 🟢 P3 | 19 | Weather unavailable badge | Trivial |
| 🔵 P4 | 20 | `RideRepository` interface | Medium |
| 🔵 P4 | 21 | Evaluate EKF Phase 2 | High |
| 🔵 P4 | 22 | Exponential back-off in `SyncManager` | Low |
