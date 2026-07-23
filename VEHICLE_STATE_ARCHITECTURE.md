# Vehicle State Engine — Architecture & Roadmap

_Last updated: 2026-07-23 · Branch: `main`_

## 0. Vision

ThrottleIQ shouldn't be thought of as "a GPS speed tracker." It should be
thought of as a **vehicle state estimation engine**. The output isn't GPS
coordinates — it's a `VehicleState`: timestamp, position, altitude, speed,
acceleration, heading, angular velocity, a confidence score, motion
classification flags (moving/stopped/cornering/braking/accelerating), sensor
quality signals, and (eventually) a map-matched road. Everything else —
ride recording, crash detection, ride scoring, future analytics — reads from
that object instead of computing speed/accel/heading independently in
different places.

That's the target architecture. This doc is honest about how much of it
exists today, phases the rest, and records why each phase was scoped the way
it was.

---

## 1. The 10-layer architecture — current state

| # | Layer | Status |
|---|---|---|
| 1 | Sensor collection | 🟡 Partial — GPS + accelerometer collected; gyroscope now collected (Phase 1); magnetometer unused |
| 2 | Validation | ✅ Phase 1 — `SensorValidator`, single source of truth |
| 3 | Time synchronization | ⬜ Not built — deliberately unneeded for a complementary filter (see §3) |
| 4 | Sensor fusion | 🟡 Phase 1 — complementary filter, not a full Kalman/EKF (see §3) |
| 5 | Confidence engine | ✅ Phase 1 — heuristic 0-100 score |
| 6 | Motion classification | ✅ Phase 1 — isMoving/isStopped/isCornering/isBraking/isAccelerating |
| 7 | Event detection | 🟡 Pre-existing (`EventDetector`) — untouched in Phase 1, gained one confidence gate on crash alerts |
| 8 | Adaptive recording | ⬜ Not built — fixed 5m/1s GPS sampling regardless of ride state (see §4) |
| 9 | Map matching | ⬜ Deferred entirely (see §5) |
| 10 | Analytics | 🟡 Pre-existing (`rider_stats.dart`, `riding_score.dart`, badges) — untouched, reads ride-level aggregates only |

**Before Phase 1**, layers 2-6 didn't exist at all: GPS and the accelerometer
were two completely disconnected pipelines. `MotionCalculator` derived
`acceleration`/`jerk` purely from consecutive GPS speed samples; the
accelerometer was separately low-pass filtered and used *only* for instant
haptic alerts — never persisted, never reaching `EventDetector`. The
gyroscope and magnetometer were entirely unused despite being available in
`sensors_plus`. No heading was computed anywhere despite `Position.heading`
being available. There was no confidence concept — a crash alert fired on
threshold math alone, with no way to know whether the underlying sensor data
was trustworthy at that moment.

---

## 2. Phase 1 — Foundation (done, 2026-07-23)

Built: `VehicleState` (unified per-tick entity), `SensorValidator` (single
source of truth for "is this sample garbage"), `VehicleStateEstimator` (the
complementary-filter fusion engine), gyroscope now wired in alongside the
existing accelerometer stream, a heuristic confidence/imuQuality score,
motion classification, and a confidence gate on the crash-detection alert
path (Epic G follow-up — don't act on a crash signal derived from garbage
sensor data, e.g. mid-tunnel GPS loss).

**What Phase 1 deliberately did NOT change**, to keep blast radius small and
protect existing test investment:
- `MotionCalculator` (GPS-derivative speed/distance/accel math, 567 lines of
  existing test coverage) — untouched. `VehicleState`'s heading/confidence/
  classification is an **additive parallel pipeline**, not a replacement.
  `VehicleState.accelerationMs2` is still GPS-derivative, not IMU-fused —
  fusing the accelerometer into the persisted acceleration value is real
  signal-processing work (the phone's mounting orientation is unknown/
  arbitrary — see the existing "dominant axis" heuristic on the haptic
  alert path) and touches the one code path with the deepest existing test
  investment. The IMU is used for what it's uniquely good at instead:
  heading dead-reckoning between GPS fixes, motion classification, and
  confidence scoring.
- `EventDetector`'s public signature — untouched, protects
  `crash_detector_test.dart`. Only what its caller passes it changed (the
  confidence gate).
- The existing accelerometer-driven haptic alert path (`_onSensor`'s
  dominant-axis low-pass filter) — untouched, works today, no reason to risk
  it without live-device testing available in this environment.
- No UI/screen changes. `RideRecordingState` gained one plumbing field
  (`confidence`) so a future screen can surface it cheaply — nothing
  currently displays it.

**Database**: `ride_points` schema v5→v6 adds 4 nullable columns —
`heading_deg`, `confidence`, `imu_quality`, `is_cornering`. Deliberately
*not* persisted: `isBraking`/`isAccelerating` (exactly reproducible from the
already-stored `acceleration` column via the existing thresholds) and
`isMoving`/`isStopped` (already encoded by the existing `periodType`
column) — avoiding redundant schema bloat.

**Why this is the future ML training corpus**: the AI State Estimator idea
(§6) needs a real corpus of labeled ride data to be anything but a guess.
Phase 1 persists `confidence`/`heading`/`isCornering`/`imuQuality` per point
now, even though nothing consumes them yet, specifically so that corpus is
already accumulating by the time Phase 4 becomes viable — additive later,
not a rewrite.

---

## 3. Phase 2 — Full EKF (future, not started)

Replace `VehicleStateEstimator`'s internals with a proper Extended Kalman
Filter — a real state vector (position×2, velocity×2, heading, yaw-rate,
possibly an accel-bias term), covariance propagation, and Jacobians for the
nonlinear GPS-lat/lng-vs-local-frame relationship.

**Why not now**: an EKF's value is entirely in its noise tuning (process
noise Q, measurement noise R), and tuning those blind — without a real
corpus of ride logs to validate against — is more likely to produce a filter
that's confidently wrong than one that's actually better than the
complementary filter it replaces. The complementary filter degrades
gracefully with imperfect constants; an EKF with bad tuning can diverge.
Phase 1's persisted `VehicleState` data is exactly the corpus this phase
needs to exist first.

**Known prerequisite**: `vector_math` is only a *transitive* dependency
today (pulled in by `flutter_map`), not declared in `pubspec.yaml`, and is
capped at 4×4 matrices — a realistic EKF state vector needs more. Either
promote it to a direct dependency and hand-roll the matrix math, or add a
proper linear-algebra package. Not resolved now.

**Design constraint carried over from Phase 1**: `VehicleStateEstimator`'s
public interface (`addGpsSample`/`addAccelSample`/`addGyroSample`/
`currentState`) was kept intentionally minimal and sample-driven so this
phase can replace the class's *internals* without changing any of its
callers.

---

## 4. Phase 1.5 — Adaptive recording (future, low-risk once Phase 1 exists)

Today's GPS recording is a fixed 5m-distance/1s-interval filter regardless
of ride state — a straight highway and a tight corner get sampled at the
same rate. The original vision (record less on a confident straight
highway, more mid-corner) becomes a cheap conditional now that
`VehicleState.confidence`/`isCornering` exist per-tick — this is naturally
the lowest-risk, highest-leverage next increment once Phase 1 has been
runtime-verified, but wasn't built as part of Phase 1 itself (kept that
phase scoped to the fusion/confidence foundation, not touching the actual
GPS sampling cadence).

---

## 5. Phase 3 — Map matching (deferred entirely)

Snapping GPS to the actual road (`estimatedRoad` on `VehicleState`, always
null today) needs an external road-network source. Two options were
surfaced but **neither was chosen or built**:
- **OSRM's public demo server** — free, no signup, same "free public API"
  precedent as the existing Overpass POI-import integration (Epic E). Rate-
  limited and not meant for production traffic, so it would need a real
  backend swap before launch.
- **A paid map-matching API** (e.g. Mapbox Map Matching) — production-grade,
  but a recurring cost and a new API key/secret to manage, which this
  project doesn't have any infrastructure for today.

This is a genuinely separate initiative from the fusion engine and doesn't
block anything else in this roadmap. Revisit when it's actually prioritized.

---

## 6. Phase 4 — AI State Estimator (deferred, designed for)

The original pitch: instead of relying solely on fixed thresholds (hard
brake if decel < -4 m/s², crash if accel > 80 m/s² etc.), train a
lightweight on-device model on a real corpus of rides to recognize patterns
— smooth vs. aggressive riding, urban commuting vs. highway touring,
pothole impacts vs. crash impacts, typical behavior for a specific rider.
The model would sit on top of the fused `VehicleState`, not replace it,
learning what's "normal" per-rider over time.

**Why not now**: the app is pre-launch with no ride corpus to train on —
building this now would mean guessing at a model architecture and training
process against data that doesn't exist yet. **Why it's still designed
for**: Phase 1's persisted per-point `confidence`/`heading`/`isCornering`/
`imuQuality` fields are exactly the kind of clean, structured, per-tick
labels a future model would want. Revisit once there's a real corpus of
completed rides (post-launch, real usage) to work from.

---

## 7. Open items / honest limitations

- **No live sign-in/ride walkthrough was possible for Phase 1** — same
  environment limitation as previous sessions (no simulator input-automation
  tool available to sign in and record a real ride). Verified instead: full
  unit-test suite (`sensor_validator_test.dart`, `vehicle_state_estimator_test.dart`,
  272 tests total, all green), `flutter analyze` clean, and a clean
  `flutter run` boot confirming the v5→v6 schema migration applies without
  error. A real device/ride walkthrough — confirming GPS+gyro actually
  produce sensible confidence/heading values in practice, and tuning the
  heuristic constants (imuQuality penalties, confidence weights, cornering
  threshold) against real riding — remains the first thing to do once this
  is testable on a real device.
- **iOS location settings**: `_startLocationStream()` unconditionally
  constructs an `AndroidSettings` object with no `IOSSettings`/
  `Platform.isAndroid` branch — pre-existing, not introduced or fixed by
  this work, just noted while reading the file closely.
- **imuQuality/confidence formulas are first-pass heuristics**, explicitly
  expected to need real-device tuning — same honest framing as Epic G's
  crash-threshold fix ("user will fine-tune with real rides").
