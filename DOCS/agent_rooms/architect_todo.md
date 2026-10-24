# 📐 Architect Agent — Action Plan & Todo
**Agent Role:** Principal Software Architect  
**Agent ID:** `agent-1792041018615-yq0zmn`  
**Primary Responsibilities:** System Design, High-Level Architecture, Firestore Read Optimization, Cloud Functions, Security Rules & Indexes, Sensor Algorithms, and Branch Management.

---

## 🚨 P0: Critical Path & Pre-Launch Blockers

- [x] **1. Firestore Read Optimization & Live Places Cache ([`issues_open.md §104.1`](../Handoff%20for%20agents%20and%20Todos/issues_open.md)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** done on `main` before this run (`issues_fixed.md` §104.1).
  - **Context:** The Google Maps gap-fill import increased the `places` collection from 521 to 1,238 documents. Nearby places re-query every 5 km during active rides, multiplying reads by 2.4×.
  - **Action:** Complete and verify the geohash tile cache (`app/lib/features/poi_directory/data/ride_places_cache.dart`). Ensure places within 10 km are cached locally in SQLite and only docs with `updatedAt > lastPull` are fetched from Firestore. Re-read the full cell only once every 3 days.
  - **Verification:** Run `app/test/features/poi_directory/data/ride_places_cache_test.dart` and confirm emulator reads are reduced by >90%.

- [ ] **2. Group Ride N² Read Scaling & Feed Vote Hydration ([`issues_open.md §104.2–§104.4`](../Handoff%20for%20agents%20and%20Todos/issues_open.md)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** mitigated: publish interval grows 2 s per rider (20-40 s), stale threshold 200 s; feed skips vote reads for rides with no votes. Still open: one shared positions doc per ride (§104.2) and one-read-per-page votes (§104.3); §104.4 needs a backfill plus a rules deploy (owner).
  - **Context:** Group ride real-time locations scale reads quadratically with $N$ riders. Additionally, feed ride items unnecessarily trigger vote hydration reads even when `voteCount == 0`.
  - **Action:** Dynamically scale group location publish intervals based on group size (e.g., 20 riders: throttle updates to prevent 1,260 reads/min; increase stale threshold from 160s to 200s). Gate feed vote reads to only fetch when `voteCount > 0`.

- [ ] **3. Legacy Security Rules & Orphan Indexes Clean-up ([`issues_open.md §80, §84`](../Handoff%20for%20agents%20and%20Todos/issues_open.md)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** step 1 done: the app no longer sweeps `likes` on share delete. Owner: raise `config/app.minBuild`, then delete the `likes` rule and deploy. Index audit drafted in `DOCS/agent_rooms/drafts/``index_audit_84.md` (verdict: remove all 4, one after a tester-build check).
  - **Context:** Retired `likes` rules block remains in `firestore.rules`. Four unused/orphan candidate composite indexes exist in `firestore.indexes.json`.
  - **Action:**
    - Safely remove legacy `likes` security rules; verify with `npm run test:rules` in `scripts/test/rules/`.
    - Audit query profiles for the 4 candidate indexes; remove confirmed orphans to decrease write latency and storage overhead.
    - Confirm strict `request.resource.data.updatedAt == request.time` validation on place edits.

- [ ] **4. Web Live Viewer ReCAPTCHA & App Check Enforcement ([`owner_works_now.html #17, #32`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Enforcing App Check on Cloud Firestore will protect against abuse, but will immediately reject the public web live-share viewer (`/liveShares/{token}`) unless reCAPTCHA v3 / Enterprise is wired into the web client.
  - **Action:** Integrate reCAPTCHA verification on the web live viewer before recommending production Firestore App Check enforcement.

---

## ⚡ P1: Backend & Cloud Functions (Blaze Migration Prep)

- [x] **5. Cloud Functions Node 22 Readiness & Audit ([`HANDOFF_Document.md`](../Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** audited: both purges page in batches with a 480 s budget, erasure re-run is safe (username claims found by uid), moderation writes the report before hiding the message. Emulator tests added. Not deployed (Spark).
  - **Context:** Cloud Functions Node 20 is decommissioned late October 2026. The codebase targets Node 22 (`package.json`, `firebase.json`), but functions have never been deployed to production due to the Spark tier.
  - **Action:**
    - Audit all 4 core background triggers: `onUserAccountDeleted`, `purgeOldGpsTracks`, `purgeOldReportSnapshots`, and `chatModeration`.
    - Verify transactional safety of chat anonymization (`account-erasure.ts`: uid converted to `deleted-rider`, participant array sanitized, messages cleared, but chat ID preserved for the counterparty).
    - Ensure `purgeOldGpsTracks` runs with bounded batching to prevent timeout on large point histories.

- [ ] **6. Spark-to-Blaze Upload Security Architecture ([`issues_open.md §107.3, §83.18`](../Handoff%20for%20agents%20and%20Todos/issues_open.md)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** design drafted: `DOCS/For Devs and Contributors/architecture/signed_uploads_design.DRAFT.md` (recommends option B with Blaze). Owner decision.
  - **Context:** On Spark, image uploads rely on an unsigned Cloudinary preset (`throttleiq_unsigned`), which leaves an open POST endpoint.
  - **Action:**
    - Model two architectural options: (A) A lightweight Cloudflare Workers / Fastly Edge signing proxy that generates short-lived signed upload signatures without Blaze; or (B) Direct signed uploads via Cloud Functions once on Blaze.
    - Standardize asset public ID conventions (`<kind>/<uid>/<asset_id>`) to guarantee ownership-based deletion sweeps function correctly.

---

## 🔬 P2: Motion Telemetry & Sensor Calibration

- [ ] **7. Crash Detection Shadow-Mode Battery & Sensor Tuning ([`issues_open.md §78.1, §78.12`](../Handoff%20for%20agents%20and%20Todos/issues_open.md)):**
  - **Context:** The crash detection pipeline is implemented but runs strictly in shadow-mode. 50 Hz accelerometer polling can introduce significant battery drain if unmanaged.
  - **Action:**
    - Profile CPU and battery usage of the 50 Hz `ImpactDetector` background service.
    - Prepare data ingestion pipeline for the upcoming Phyphox motorcycle sensor recordings (`DOCS/General/CRASH TESTING/phase0/`).
    - Resolve gyroscope heading drift and verify GPS-speed fallback algorithm (§49).

- [ ] **8. Time Precision & De-identification in `crashEvents` ([`owner_works_now.html #18`](../../../../housekeeping/owner_works_now.html)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** `crashEvents.createdAt` is now floored to the UTC hour (`issues_fixed.md`). Still open: `updatedAt` is `request.time` (needs a rules change) and docs already uploaded keep exact times (one-off backfill, owner).
  - **Context:** Opt-in research logs currently record the exact millisecond timestamp alongside `ownerUid`, creating re-identification risk.
  - **Action:** Round `createdAt` in `impact_event_payload.dart` to the nearest hour (or preserve only `hourLocal` and `weekday`) while retaining `ownerUid` for statutory user account deletion.

---

## 🌿 P3: Branch Maintenance & External Integrations

- [x] **9. Maya Ride Kit (`mayabi`) Rebase & Alignment ([`HANDOFF_Document.md`](../Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** `main` merged into `mayabi` (merge, not rebase, so no force-push), check.sh green, vendored files re-synced.
  - **Context:** The `mayabi` branch contains the partner API (`functions/src/partner-api/`) and client SDK (`mayabi/`), but is 52 commits behind `main`.
  - **Action:** Rebase `mayabi` onto `main`; resolve conflicts in `app_en.arb`/`app_bn.arb`, `active_ride_screen.dart`, and `firebase.json`. Run `scripts/check.sh` and sync vendored files into `mayabi/lib/src/vendor/`.

- [x] **10. Indriyo ADAS HUD Branch Sync:**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** `main` merged into `indriyo`, HUD wiring checked, check.sh green.
  - **Context:** Indriyo HUD is 6 commits ahead of `main`.
  - **Action:** Merge `main` into `indriyo`; verify HUD display wiring against `context.palette` and `rideRecordingProvider`.
