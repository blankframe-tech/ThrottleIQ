---
name: throttleiq-qa
description: >-
  ThrottleIQ project QA runner. Executes the full quality gate — static
  analysis, unit tests, Firestore rules tests, and a structured test-coverage
  audit — after any code change. Use whenever you finish editing Dart source
  files, adding features, fixing bugs, or touching infrastructure. Produces a
  pass/fail QA report and lists any gaps that need new tests.
---

# ThrottleIQ QA Skill

This skill runs the full ThrottleIQ quality gate and produces a structured
report. Follow every step in order; do not skip steps even if earlier ones
pass.

---

## Prerequisite: Understand the Test Topology

ThrottleIQ has four test layers. Know which layer is relevant to the change:

| Layer | Location | Runner | What it covers |
|---|---|---|---|
| **Calculator unit tests** | `app/test/calculators/` | `flutter test` | Pure-logic classes: `EventDetector`, `MotionCalculator`, `VehicleStateEstimator`, `AccelAxisCalibrator`, `RecordingCadencePolicy`, etc. No I/O. |
| **Database tests (real SQLite)** | `app/test/database/` | `flutter test` | DAOs exercised against a real in-memory SQLite via `sqflite_common_ffi`. **Do not mock these** — mocks cannot catch deadlock regressions (Issues.md §7). |
| **Feature / integration tests** | `app/test/features/` | `flutter test` | Repository + provider-level behaviour per feature (ride, garage, social, etc.). |
| **Firestore rules tests** | `scripts/test/rules/` | `npm run test:rules` (from `scripts/`) | Security rules exercised against the Firebase emulator. |

---

## Step 1 — Static Analysis

```bash
# Run from: f:\BlankFrameTechnologies\ThrottleIQ\app
flutter analyze
```

**Pass criteria**: exit code 0, zero errors. Warnings are acceptable but must
be documented in the QA report. The `build/` directory is already excluded in
`analysis_options.yaml` — do not re-add it.

If analyze fails:
- Fix all errors before proceeding.
- Never suppress with `// ignore:` unless the lint is a false-positive from
  a generated file; document any suppression in the report.

---

## Step 2 — Full Unit + Database Test Suite

```bash
# Run from: f:\BlankFrameTechnologies\ThrottleIQ\app
flutter test --reporter expanded
```

**Pass criteria**: all tests green, zero failures, zero timeouts.

Key behaviours to watch for:
- **Hanging tests** (no output for > 20 s) almost always mean a DAO is calling
  another DAO from inside a transaction (deadlock, Issues.md §7). If this
  happens, check the `database/` tests first.
- The `@Timeout(Duration(seconds: 20))` on `bike_dao_delete_test.dart` is
  intentional — a hang here is a regression signal, not a flake.

If a test fails, do **not** delete or comment it out. Fix the code or the test.

---

## Step 3 — Coverage Report (identify gaps)

```bash
# Run from: f:\BlankFrameTechnologies\ThrottleIQ\app
flutter test --coverage
```

Then inspect `coverage/lcov.info`. Focus coverage audit on:

1. **All files changed in this coding session** — every modified file needs
   ≥ 1 test exercising the changed lines.
2. **Safety-critical paths** — the following must never drop below 80 % branch
   coverage:
   - `lib/features/ride/domain/calculators/event_detector.dart`
   - `lib/features/ride/domain/calculators/vehicle_state_estimator.dart`
   - `lib/features/ride/domain/calculators/accel_axis_calibrator.dart`
   - `lib/core/database/database_helper.dart` (migration ladder)
   - `lib/core/cloud/outbox_service.dart` (backoff + retry logic)
3. **New public methods** — every `public` method added must have at least one
   test for the happy path and one for an edge/error case.

If coverage gaps are found, add tests **before** marking the QA run complete.

---

## Step 4 — Firestore Rules Tests

```bash
# Run from: f:\BlankFrameTechnologies\ThrottleIQ\scripts
npm run test:rules
```

**Pass criteria**: all rule specs pass. Run this whenever:
- `firestore.rules` was modified.
- A new collection or subcollection was introduced.
- Auth logic in any Cloud Function was changed.

If the Firebase emulator is not installed:
```bash
npm install -g firebase-tools
firebase setup:emulators:firestore
```

---

## Step 5 — Sensor Threshold Sanity Check

After any change to `sensor_constants.dart` or `event_detector.dart`, verify
that the threshold constants still satisfy these invariants:

```
hardBrakingThreshold  < 0           (negative = deceleration)
rapidAccelThreshold   > 0           (positive = acceleration)
|hardBrakingThreshold| < crashAccelThreshold/g   (crash >> normal brake)
overspeedThreshold    > 0 m/s       (sanity: not negative)
fatigueAlertSeconds   >= 3600       (minimum 60 min; never alert before 1 h)
minConfidenceForCrashAlert  < minConfidenceToThinRecording
    (crash gate must be stricter than thinning gate)
```

These are checked manually by reading `sensor_constants.dart` — no automated
test exists yet (add one if you change the file).

---

## Step 6 — Database Migration Smoke Test

After any change to `DatabaseHelper._onCreate` or `DatabaseHelper._onUpgrade`:

Run the migration suite if it exists, or at minimum verify:
- Every `ALTER TABLE ADD COLUMN` uses `_addColumnIfMissing` (not raw ALTER).
- The `version` constant at the top of `_openDb` was incremented.
- A new upgrade leg was added in `_onUpgrade` for the new version.
- `createSchemaForTesting` was updated to match.

```bash
# Run from: f:\BlankFrameTechnologies\ThrottleIQ\app
flutter test test/database/
```

---

## Step 7 — QA Report

After all steps complete, produce a structured report in this format:

```
## ThrottleIQ QA Report — <date> <time>

### Changed Files
- <list every file edited>

### Step 1 — Static Analysis
PASS / FAIL — <error count, warning count>

### Step 2 — Unit + Database Tests
PASS / FAIL — <N tests, N failures>

### Step 3 — Coverage
PASS / GAPS FOUND
Changed files:
  - <file>: <covered/total lines>%
Safety-critical:
  - event_detector.dart: <branch coverage>%
  - vehicle_state_estimator.dart: <branch coverage>%
  - accel_axis_calibrator.dart: <branch coverage>%
  - database_helper.dart: <branch coverage>%
  - outbox_service.dart: <branch coverage>%
Gaps:
  - <list any uncovered new public methods>
  - <list any safety-critical file below 80%>

### Step 4 — Firestore Rules
PASS / SKIPPED (rules not changed) / FAIL

### Step 5 — Sensor Thresholds
PASS / SKIPPED (constants not changed) / VIOLATIONS FOUND

### Step 6 — DB Migration
PASS / SKIPPED (schema not changed) / FAIL

### Overall: PASS ✅ / FAIL ❌

### New Tests Added This Session
- <list any new test files or test cases added>

### Known Gaps (deferred)
- <list any coverage gaps intentionally deferred with reason>
```

---

## Best Practice Rules — Always Apply

### When adding a new calculator or domain class
1. Create `app/test/calculators/<class_name>_test.dart`.
2. Test: constructor initializes cleanly, `reset()` clears all state, happy
   path, at least two edge cases (zero input, extreme input).
3. If the class has a time window (like `EventDetector`'s 2-second crash
   window), pass explicit `DateTime` values — never rely on `DateTime.now()`
   in tests.

### When adding a new DAO
1. Create `app/test/database/<dao_name>_test.dart`.
2. Use the real in-memory SQLite pattern from `bike_dao_delete_test.dart`:
   ```dart
   sqfliteFfiInit();
   databaseFactory = databaseFactoryFfi;
   db = await databaseFactory.openDatabase(inMemoryDatabasePath);
   await DatabaseHelper.instance.createSchemaForTesting(db);
   DatabaseHelper.overrideDatabaseForTesting(db);
   ```
3. Test: insert, read-back, update, delete, foreign-key enforcement.
4. **Never call another DAO from inside a transaction** — the deadlock is
   silent and the test will hang rather than fail.

### When adding a new Riverpod provider
1. Test it with `ProviderContainer` + override of any dependencies.
2. Verify `dispose()` releases resources (timers, stream subscriptions).
3. If the provider talks to SQLite or Firestore, inject mocks or in-memory
   fakes — do not hit real services in unit tests.

### When modifying `firestore.rules`
1. Add at least one `allow` case and one `deny` case per new rule.
2. Run `npm run test:rules` from `scripts/` before committing.

### When modifying `outbox_service.dart`
1. The `outboxBackoff` function is pure — add a unit test for any change.
2. Verify the `kOutboxAttemptTimeout` value is still appropriate (8 seconds).
3. Test that a Firestore timeout (not a failure) results in `deferred`, not
   `discarded`.

---

## Windows Path Note (username has spaces)

The user profile `Abraar at Inovace` contains spaces. Flutter's native-assets
hook passes paths with Unix-style single quotes, which Windows cmd doesn't
honour. **Always run Flutter commands via the `C:\flutter` junction** and set
`PUB_CACHE` to avoid the `'C:\Users\Abraar' is not recognized` error:

```powershell
$env:PUB_CACHE   = "C:\pubcache"   # junction → C:\Users\Abraar at Inovace\AppData\Local\Pub\Cache
$env:FLUTTER_ROOT = "C:\flutter"   # junction → C:\Users\Abraar at Inovace\flutter
C:\flutter\bin\flutter.bat test --reporter expanded --no-pub
C:\flutter\bin\flutter.bat analyze --no-pub
```

Junctions are already created. If they disappear after a reboot, recreate with:
```powershell
New-Item -ItemType Junction -Path "C:\flutter"  -Target "C:\Users\Abraar at Inovace\flutter"  -Force
New-Item -ItemType Junction -Path "C:\pubcache" -Target "C:\Users\Abraar at Inovace\AppData\Local\Pub\Cache" -Force
```

---

## Quick Reference: Running Individual Suites

```powershell
# Full suite (Windows — always use junction paths)
$env:PUB_CACHE = "C:\pubcache"; C:\flutter\bin\flutter.bat test --reporter expanded --no-pub

# Static analysis
$env:PUB_CACHE = "C:\pubcache"; C:\flutter\bin\flutter.bat analyze --no-pub

# One test file
C:\flutter\bin\flutter.bat test test/calculators/crash_detector_test.dart --no-pub

# One test group by name
C:\flutter\bin\flutter.bat test --name "EventDetector - Crash Detection" --no-pub

# Database tests only
C:\flutter\bin\flutter.bat test test/database/ --no-pub

# Feature tests only
C:\flutter\bin\flutter.bat test test/features/ --no-pub

# Calculator tests only
C:\flutter\bin\flutter.bat test test/calculators/ --no-pub

# With coverage
$env:PUB_CACHE = "C:\pubcache"; C:\flutter\bin\flutter.bat test --coverage --no-pub

# Firestore rules (from scripts/ directory)
npm run test:rules
```
