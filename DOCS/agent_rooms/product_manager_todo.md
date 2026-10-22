# 🧭 Product Manager Agent — Action Plan & Todo
**Agent Role:** Product Manager (Alex)  
**Agent ID:** `agent-1792620967421-eu9age`  
**Primary Responsibilities:** PRD & Metrics Governance, Store Presence & Metadata, User Experience & Retention Loops, Content Strategy, Commercial Partnerships, and GTM Execution.

---

## 🚨 P0: Launch Blockers & Product Decisions

- [ ] **1. Formally Confirm PRD §10 Success-Metric Targets ([`owner_works_now.html #23`](../../../../housekeeping/owner_works_now.html), [`PRD.md §10`](../For%20Devs%20and%20Contributors/architecture/PRD.md)):**
  - **Context:** The PRD lists five target metrics as proposals pending founder confirmation. These benchmarks govern beta evaluation and launch gates.
  - **Proposed Targets:**
    1. *Engagement:* 3+ rides per active rider per week.
    2. *Activation:* 60% of active riders have a motorcycle profile completed in Garage.
    3. *Retention:* 25% Day-30 retention for organic signups.
    4. *Stability:* 99.5% crash-free user sessions.
    5. *Integrity:* 0 rides lost after unexpected OS process kills.
  - **Action:** Sign off on baseline targets for the closed beta or specify calibrated adjustments.

- [ ] **2. Resolve Open UX & Feature Edge Cases ([`owner_works_now.html #22`](../../../../housekeeping/owner_works_now.html), [`needs_attention.md:82–85`](../Handoff%20for%20agents%20and%20Todos/needs_attention.md)):**
  - **Call A (Live Share Expiry):** When a rider rides past 24 hours, should the link hard-expire or dynamically refresh `expiresAt` while the ride remains active?
  - **Call B (Group-Ride Location Polling):** The RTDB location check requires Cloud Functions on Blaze; client code is parked. Confirm keeping parked until Blaze upgrade.
  - **Call C (Accessibility / WCAG AA Contrast):** Darken `textTertiary` and bright success/warning tokens that fail WCAG AA contrast ratios in dark mode.
  - **Call D (Maintenance Demo Button):** The cash-on-delivery "Order Parts" button in Maintenance is a demo feature. Decision: remove it completely to prevent user confusion, or gate behind a feature flag until an official parts partner signs ([`issues_open.md §95.11`](../Handoff%20for%20agents%20and%20Todos/issues_open.md)).
  - **Call E (Marketing Copy Claims):** Review Record screen inspirational quotes and clarify that the app makes no active promise of "all badges = free engine oil".

- [ ] **3. Google Play Store Listing & Review Documentation ([`owner_works_now.html #8, #20`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Play Console internal/closed track submission requires finalized text, localization, screenshots, and permission declarations.
  - **Action:**
    - Finalize English and Bangla store descriptions ([`store_listing.md`](../General/Files%20for%20Stores/store_listing/store_listing.md), [`store_listing_bn_addendum.md`](../General/Files%20for%20Stores/store_listing/store_listing_bn_addendum.md)).
    - Execute screenshot shot-list on physical hardware (Shot list in `marketing_kit.md §6`: Ride telemetry, Live Share, Maintenance countdown, Verified Garages, Group ride).
    - Prepare reviewer declaration video script for Background Location and Full-Screen Intent permissions.

---

## 🚀 P1: Community Cold-Start & Content Strategy

- [ ] **4. Prioritize & Ship BRTA Front Number-Plate Guide ([`owner_works_now.html #31`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Scrape of 375 Facebook rider posts revealed that the mandatory BRTA front number-plate deadline (15 November 2026) is the highest-salience topic for Bangladeshi bikers.
  - **Action:** Decide deliverable format by 1 November: a dedicated in-app modal/guide in Forums vs. a viral Facebook/blog guide that funnels riders to ThrottleIQ.

- [ ] **5. Brand Forum Cold-Start Seeding ([`marketing.md §4`](../Handoffs%20for%20Non%20Coding%20Agents/marketing/marketing.md)):**
  - **Context:** Places, feed, and brand forums cannot launch with empty screens.
  - **Action:** Prepare 2–3 high-value starter posts and discussion prompts for top brand forums: Yamaha FZ/R15, Bajaj Pulsar, Suzuki Gixxer, Honda Hornet, and Royal Enfield Bangladesh.

- [ ] **6. Verified SafeSpot Garage Partner Framework:**
  - **Context:** Over 500 local mechanics and workshops need a clear onboarding value proposition.
  - **Action:** Finalize the SafeSpot partner flyer and terms: free verified digital listing in exchange for displaying a ThrottleIQ counter sticker and recommending the app for service reminders.

---

## 💼 P2: Commercial Pilots & Monetization

- [ ] **7. Maya Ride B2B Pilot Structuring ([`owner_works_now.html #7`](../../../../housekeeping/owner_works_now.html), [`maya-ride-partnership.md`](../General/partnerships/maya-ride-partnership.md)):**
  - **Context:** Commercial ride-sharing pilot with Maya Ride offers potential BDT 150–300/rider/month SaaS revenue.
  - **Action:** Review the 10 strategic questions in §13 of `maya-ride-partnership.md`; define data sharing boundaries, SOS dispatch protocols, and revenue share terms before the founder meeting.

- [ ] **8. Badge-Tier Physical Prize Promotion Feasibility ([`owner_works_now.html #24`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** "First to badge tier wins a maintenance kit" promotion was conceived to accelerate viral word-of-mouth.
  - **Action:** Defer launch until 100 active organic riders are reached; draft fulfillment SOP (courier logistics, address verification, anti-fraud telemetry check).
