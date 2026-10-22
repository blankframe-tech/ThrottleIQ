# 🧪 QA & Verification Agent — Action Plan & Todo
**Agent Role:** QA & Test Verification Specialist  
**Execution Context:** Test Runner / Verification Protocols  
**Primary Responsibilities:** Automated Regression Suites, Quality Gates, Integration Testing, Physical Hardware Protocols, Multi-Device Scenarios, and Performance Benchmarks.

---

## 🚨 P0: Automated Regression Suites & CI Quality Gates

- [ ] **1. Maintain 100% Green Quality Gate ([`scripts/check.sh`](../../../scripts/check.sh)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** check.sh green on the integration branch after all lane merges. New: bare `catch (_)` ratchet test (baseline 54, §83.14) and 21 widget tests (§83.28), which found and fixed the Sync issues Retry message bug.
  - **Context:** `scripts/check.sh` is the definitive repository quality gate enforcing analyzer rules, unit tests, and security rule validations.
  - **Verification Targets:**
    - 2,100+ Flutter unit, calculator, and domain tests passing green.
    - 274 Firestore security-rule tests passing green (`scripts/test/rules/`).
    - Cloud Functions TypeScript build and pure unit tests passing green (`functions/`).
    - Verify `places_rules.test.js` covering `updatedAt` server-timestamp validation.

- [ ] **2. Maintain Simulator E2E Integration Suite ([`HANDOFF_Document.md § Start here`](../Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md)):**
  - **Context:** `app/integration_test/e2e_test.dart` validates critical app startup, tab navigation, and teardown flows.
  - **Action:** Run E2E test suite on iOS and Android simulators; verify resolution of the Riverpod disposal crash (§106).

- [ ] **3. Validate Database Migration & DAO Integrity Tests:**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** the database migration and DAO tests run inside check.sh's full `flutter test` and pass.
  - **Context:** SQLite migrations (v13 to v29 schema upgrade) govern data safety across app upgrades.
  - **Action:** Re-run migration test matrix (`app/test/database/database_migration_test.dart`, `schema_v29_merge_test.dart`) to guarantee zero data loss during schema backfills.

---

## 📱 P1: Physical Device Testing Protocols (Manual Field Gates)

*Reference: [`HANDOFF_Document.md § Built but never run on a real phone`](../Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md)*

- [ ] **4. Core Ride Recording Field Verification:**
  - [ ] **Screen-Locked Ride:** Execute a continuous 10+ minute motorcycle ride with the phone screen locked. Confirm GPS points record accurately without gaps.
  - [ ] **Mid-Ride App Swipe-Away:** Force-close the app from recent apps mid-ride. Reopen and verify that the restored ride successfully backfills the missing elapsed minutes (B5).
  - [ ] **Permission Gates:** Test ride start permission flows (location always allowed, background service notification, battery optimization exempt).
  - [ ] **Route Navigation:** Follow a saved route; verify turn banner accuracy at physical corners and off-route recalculation triggers at 100 meters.

- [ ] **5. Offline-First Dead-Zone Simulation:**
  - [ ] **Airplane Mode Ride Completion:** Toggle airplane mode mid-ride and tap Stop. Confirm ride finalizes immediately to local SQLite without spinner delays.
  - [ ] **Offline Post & Photo Queuing:** Create a post with a photo while offline. Verify it queues locally in the Transactional Outbox and publishes cleanly once signal is restored.
  - [ ] **Quota Outage UI Test:** Trigger quota simulation (`scripts/loadtest/quota_sim.js`); confirm the amber "database overloaded" banner renders gracefully without crashing the app.

- [ ] **6. Two-Device Multi-User Interaction Suite:**
  - [ ] **Group Ride Code Sharing:** Create group ride on Phone A; join via code on Phone B. Verify live peer dots update on the map without stale lag.
  - [ ] **Bluetooth Voice Notes:** Test push-to-talk voice transmission through a connected Bluetooth helmet headset.
  - [ ] **Chat & Moderation Flow:** Send direct messages between accounts. Test user report submission and user block; confirm blocked rider messages cease appearing.
  - [ ] **Deleted-Rider View:** Verify that a chat with an account that triggered deletion renders the participant as "Deleted rider" without crashing.

---

## 🔋 P2: Sensor, Battery & Hardware Stress Testing

- [ ] **7. Shadow-Mode Crash Sensor Battery Benchmarking ([`issues_open.md §78.1`](../Handoff%20for%20agents%20and%20Todos/issues_open.md)):**
  - **Action:** Measure battery consumption over 60 minutes of continuous riding with `ImpactDetector` sampling at 50 Hz. Compare handlebar mount vs jacket pocket placement. Verify total battery drain stays below 7% per hour.

- [ ] **8. Budget Android Phone Low-Memory Evaluation ([`issues_open.md §96`](../Handoff%20for%20agents%20and%20Todos/issues_open.md)):**
  - **Action:** Install the latest release build on a 2–3 GB RAM itel, Tecno, or Redmi device. Validate background location persistence against aggressive OEM battery killers (MIUI / HiOS / Transsion).

- [ ] **9. SafeQR Medical Card Optical Scan Check:**
  - **Action:** Generate SafeQR code on phone; test scanning from varying distances and lighting conditions using standard iOS Camera and Google Lens on secondary devices.

- [ ] **10. Synthetic Crashlytics Diagnostic Reporting:**
  - **Action:** Trigger non-fatal diagnostic report in debug mode; verify log payload lands in Firebase Crashlytics dashboard with correct device metadata.
