---
trigger: always_on
---

# ThrottleIQ QA Gate — Always-On Rules

These rules apply to every coding task in this project without exception.

## After every code change, you MUST:

1. **Run static analysis** (`flutter analyze` from `app/`) and fix all errors
   before marking work done. Zero errors is the only acceptable result.

2. **Run the full test suite** (`flutter test` from `app/`) and confirm it is
   green. Never delete or comment out a failing test to make the suite pass —
   fix the code or the test.

3. **Run Firestore rules tests** (`npm run test:rules` from `scripts/`) whenever
   `firestore.rules` or any Cloud Function in `functions/src/` was touched.

4. **Add tests for new code.** Every new public method in a domain calculator,
   DAO, or service must have at least a happy-path test and one edge-case test.
   Use the `throttleiq-qa` skill for exact patterns.

5. **Never mock DAOs in database tests.** Use real in-memory SQLite via
   `sqflite_common_ffi` — see `app/test/database/bike_dao_delete_test.dart`.
   Mocks cannot catch the deadlock class of bug documented in Issues.md §7.

6. **Never call another DAO from inside a transaction.** This produces a silent
   deadlock that hangs the app rather than throwing. CI will time out; a real
   device will freeze permanently.

7. **Never suppress lint errors with `// ignore:` on production code** unless
   it's a false-positive from a generated file. Document any suppression with
   a reason comment.

## Safety-critical files — extra care required:

- `event_detector.dart` — crash detection logic; a wrong threshold can fail to
  alert a real crash or fire on a pothole.
- `vehicle_state_estimator.dart` — confidence score gates crash alerts.
- `sensor_constants.dart` — all thresholds must satisfy the invariants in the
  `throttleiq-qa` skill (Step 5).
- `database_helper.dart` — every schema migration must use
  `_addColumnIfMissing`; a raw `ALTER TABLE` on a live install bricks the app.
- `outbox_service.dart` — a Firestore timeout must result in `deferred`, never
  `discarded`; the rider's intent must survive offline.
- `auto_tracking_service.dart` — the `@pragma('vm:entry-point')` annotation on
  `autoTrackingTaskCallback` must never be removed; without it the tree-shaker
  silently drops it from release builds.

## When to invoke the `throttleiq-qa` skill:

Use the `throttleiq-qa` skill for the full 7-step checklist and report format
any time you complete a feature, fix a bug, or touch infrastructure. For tiny
one-liner fixes (comment updates, string tweaks), Steps 1 and 2 are still
required; the rest may be skipped if no logic changed.
