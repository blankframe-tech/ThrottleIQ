---
trigger: always_on
---

# ThrottleIQ QA Gate — Always-On Rules

These rules apply to every coding task in this project without exception.

## The gate: `scripts/check.sh`, once per change set

1. **While iterating, run only the focused tests** for the code you touched
   (`flutter test test/path/to/file_test.dart` from `app/`).

2. **When the change set is done** (before reporting back, committing, or after
   the *last* merge of a batch), run `scripts/check.sh` from the repo root,
   **once**. It runs l10n generation, the format check on changed files, the CI
   guards, `flutter analyze`, the full `flutter test`, and the rules/functions
   suites when those changed, then prints one pass/fail summary. Zero failures
   is the only acceptable result; fix causes and re-run it once.

3. Never delete or comment out a failing test to make the gate pass: fix the
   code or the test. A pass is stamped per commit, so the pre-push hook and
   `deploy.sh` don't re-run it for the same commit.

4. **Add tests for new code.** Every new public method in a domain calculator,
   DAO, or service must have at least a happy-path test and one edge-case test.
   Use the `throttleiq-qa` skill for exact patterns.

5. **Never mock DAOs in database tests.** Use real in-memory SQLite via
   `sqflite_common_ffi` — see `app/test/database/bike_dao_delete_test.dart`.
   Mocks cannot catch the deadlock class of bug documented in issues_fixed.md §7.

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
