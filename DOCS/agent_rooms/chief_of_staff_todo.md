# 🎖️ Chief of Staff Agent — Action Plan & Todo
**Agent Role:** Chief of Staff / Team Coordinator  
**Agent ID:** `agent-chief-980b39eadf07f02c`  
**Primary Responsibilities:** Executive Decision Triage, Owner Escalations, Hardware & Field Test Coordination, Inter-Agent Workflow Alignment, and Milestone Governance.

---

## 🚨 P0: Executive Decision Triage (Owner Blockers)

- [ ] **1. Drive Final Decision on Scraped Google Maps Data ([`owner_works_now.html #1`](../../../../housekeeping/owner_works_now.html), [`judge.md:93`](../../../judge.md)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** decision card drafted: `DOCS/agent_rooms/drafts/``decision_card_scraped_places.md` (recommends a full revert, dry run first).
  - **Context:** 717 scraped places + 80 enriched docs violate Google Maps Terms of Service, capping the product audit score at 40 and introducing legal/store takedown risk.
  - **Tradeoff Options:**
    - *Option A (Recommended):* Revert all scraped fields using the saved Apify backup (`revert_google_places.js --from=...`). Places drop from 1,238 to 521, eliminating legal risk. Rebuild directory organically from OpenStreetMap and rider submissions.
    - *Option B:* Delete only the 717 new seeded documents; leaves 80 enriched documents with Google hours/phones.
    - *Option C:* Keep as is with `verified: false` pending formal legal opinion.
  - **Action:** Present concise decision card to the owner; upon approval, instruct the Operations Manager / Architect to run the chosen script.

- [ ] **2. Facilitate Firebase Blaze Plan Upgrade ([`owner_works_now.html #3`](../../../../housekeeping/owner_works_now.html)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** decision card drafted: `DOCS/agent_rooms/drafts/``decision_card_blaze_upgrade.md` (recommends upgrading now with a budget alert).
  - **Context:** ThrottleIQ is running on the free Spark tier. Blocked capabilities: Cloud Functions background triggers, Firestore automated TTL policies (`liveSessions.expiresAt`, `places.expiresAt`), automated account erasure, and signed Cloudinary image uploads.
  - **Action:** Present cost-benefit briefing to the owner (Firebase Blaze includes generous free-tier allowances identical to Spark, with pay-as-you-go billing only upon exceeding thresholds). Secure billing enablement.

- [ ] **3. Apple Developer Program Enrollment ($99/yr) ([`owner_works_now.html #21`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Enrolling in the Apple Developer Program unblocks iOS TestFlight distributions, production App Attest entitlements, and signed iOS widget extensions.
  - **Action:** Track owner enrollment progress and notify the Architect once the team ID and certificates are provisioned.

---

## 🏍️ P1: Real-World Testing & Field Sourcing

- [ ] **4. Coordinate Comprehensive Hardware Test Runs ([`owner_works_now.html #5`](../../../../housekeeping/owner_works_now.html), [`HANDOFF_Document.md § Built but never run`](../Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md)):**
  - **Context:** Code on `main` has not run on physical hardware since `beta-v4.7.1`.
  - **Action:**
    - Schedule and oversee a physical ride test session covering: 10+ minute screen-locked recording, mid-ride app kill and recovery, turn navigation banner behavior, airplane-mode offline completion, and two-phone live share tracking.
    - Consolidate tester telemetry feedback into a post-ride verification report.

- [ ] **5. Source & Schedule Budget Android Device Stress Test ([`owner_works_now.html #28`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Mass-market Bangladesh riders rely on 2–3 GB RAM itel, Tecno, or Redmi smartphones with aggressive OEM battery managers that can terminate background location tracking.
  - **Action:** Arrange a full-day ride evaluation on a borrowed 2–3 GB RAM Android device; verify whether background services survive all-day wakelocks and document memory recovery metrics.

- [ ] **6. Coordinate Phyphox Motorcycle Sensor Data Collection ([`owner_works_now.html #27`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Crash detection thresholds are currently theoretical and run in shadow-mode. Empirical calibration requires labeled accelerometer and gyroscope recordings from real motorcycle rides.
  - **Action:** Coordinate execution of the Phase 0 recording protocol: idle engine vibration, revving to 4k/6k RPM, highway cruising (20/40/60 km/h), speed bumps, hard stops, and intentional phone drops onto grass/foam. Ensure raw CSVs are saved to `DOCS/General/CRASH TESTING/phase0/`.

- [ ] **7. Verify Maintenance Templates with Local Mechanics ([`owner_works_now.html #29`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Factory service templates for Hornet 160, FZ, R15, Gixxer, and Apache 160 are approximate.
  - **Action:** Coordinate collection of Bangladesh dealer service schedule booklets and interview 2–3 motorcycle mechanics on real-world wear factors under local monsoon and stop-and-go driving conditions.

---

## 🤝 P2: Cross-Agent Governance & Milestone Tracking

- [ ] **8. Monitor Inter-Agent Coordination & Message Ceilings:**
  - **Action:** Ensure agent communication stays focused, bounded, and within the 12-message ceiling per thread. Triage blocking dependencies between the Architect, Product Manager, and Operations Manager.
