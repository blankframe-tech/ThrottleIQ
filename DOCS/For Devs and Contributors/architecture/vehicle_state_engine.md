# Vehicle State Engine: roadmap and design notes

_Moved from `HANDOFF_Document.md` Part 3 on 2026-10-22 (written 2026-07-23, checked against the code 2026-10-22)._

The current layer-by-layer state is in [`arch.md`](arch.md) §4. This file keeps the reasons: what Phase 1 left alone on purpose, and why Phases 2-4 wait.

The goal: every consumer (recording, crash detection, scoring, analytics) reads one `VehicleState` (position, altitude, speed, acceleration, heading, angular velocity, confidence, motion flags, sensor quality, later a matched road) instead of computing these on its own.

## Built (2026-07-23)

- **Phase 1, foundation.** `VehicleState`, `SensorValidator` (the one place that decides a sample is garbage), `VehicleStateEstimator` (complementary filter: GPS course blended with integrated gyro yaw rate), a heuristic 0-100 confidence and `imuQuality`, motion classification (moving, stopped, cornering, braking, accelerating), and a confidence gate on the crash path (`SensorConstants.minConfidenceForCrashAlert = 40`).
- **Schema v6** added `ride_points.heading_deg`, `confidence`, `imu_quality`, `is_cornering`. Not stored on purpose: braking/accelerating (reproducible from the stored `acceleration` and the thresholds) and moving/stopped (already in `period_type`).
- **Phase 1.5, adaptive recording.** `RecordingCadencePolicy` persists at most one point per 5 s (`minPersistIntervalOnSteadyStretches`) when confidence is at least 70 (`minConfidenceToThinRecording`) and the bike is not cornering, braking or accelerating. Every other fix is kept.

## What Phase 1 left alone, and why

- **`MotionCalculator` still owns speed, distance, acceleration and jerk** (GPS-derivative). `VehicleState.accelerationMs2` is not IMU-fused: the phone's mount orientation is unknown, and this path has the deepest test coverage. The IMU is used for what it does well: heading between GPS fixes, motion classification and confidence.
- **`EventDetector`'s signature is unchanged**, which protects `crash_detector_test.dart`. Only its caller changed (the confidence gate).
- **GPS polling is fixed** (5 m / 1 s). geolocator can't change its settings mid-stream, so Phase 1.5 thins what is written, not what is sampled. It saves disk, not battery.
- **Known trade-off, signed off before it was built:** the ride summary and share screens rebuild the polyline from `ride_points`, so steady stretches look coarser there. The live in-ride polyline, the ride totals and `MotionCalculator` still see every fix.

## Phase 2: full EKF (not started)

Replace the estimator's internals with an Extended Kalman Filter (position, velocity, heading, yaw rate, maybe an accel-bias term).

- **Why not yet:** an EKF is only as good as its noise tuning (Q, R). Tuned without real ride logs, it is more likely to be confidently wrong than better. The complementary filter degrades gracefully with imperfect constants; a badly tuned EKF can diverge.
- **Prerequisite:** `vector_math` is only a transitive dependency (via `flutter_map`), not in `app/pubspec.yaml`, and stops at 4×4 matrices. Add it directly and hand-roll the maths, or add a linear-algebra package.
- **Constraint:** keep the estimator's sample-driven interface (`addGpsSample`, `addAccelSample`, `addGyroSample`, `currentState`) so the internals can change without touching callers.

## Phase 3: map matching (deferred)

`VehicleState.estimatedRoad` is always `null`. Snapping to roads needs a road network. Options seen, none chosen: OSRM's public demo server (free, rate-limited, not for production) or a paid API such as Mapbox Map Matching (recurring cost and a new secret). A curviness route planner needs the same engine (`issues_open.md` §92.A6).

## Phase 4: on-device model (deferred, designed for)

A small model on top of `VehicleState` that learns smooth vs aggressive riding, commute vs touring, pothole vs crash, and what is normal for one rider. It needs a real ride corpus, which a pre-launch app doesn't have. The per-point `confidence`, `heading_deg`, `is_cornering` and `imu_quality` columns are stored now so that corpus builds up (`issues_open.md` §92.A4).

## Open: tune on real rides

None of these has been tuned on a real ride: the `imuQuality` penalties, the confidence weights, the cornering threshold, and the thinning floor (70) and interval (5 s). Do it once rides from a real phone exist.
