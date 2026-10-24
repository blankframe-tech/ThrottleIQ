# ⚙️ Operations Manager Agent — Action Plan & Todo
**Agent Role:** Operations Manager  
**Agent ID:** `agent-1792041478698-nhl5qr`  
**Primary Responsibilities:** Operational Execution, Security Migrations, Store Compliance & Data Safety, Secrets Governance, Runbooks, Release Engineering, and Localization Audits.

---

## 🚨 P0: Security & Compliance Execution

- [ ] **1. Execute SECURITY Step 3 (Email Migration & Privacy Update) ([`owner_works_now.html #2`](../../../../housekeeping/owner_works_now.html), [`SECURITY.md`](../../../SECURITY.md)):**
  - **Context:** `minBuild = 29` is live and Firestore rules are deployed. Old public user profiles still hold plaintext email addresses until the one-off migration script runs.
  - **Action Steps:**
    1. Verify no active riders are on build 26 or older via Firebase Console analytics.
    2. Execute dry run: `FIREBASE_PROJECT_ID=throttleiqfb node scripts/oneoff/migrate_emails_private.js`.
    3. Execute live run with confirmation: `FIREBASE_PROJECT_ID=throttleiqfb node scripts/oneoff/migrate_emails_private.js --yes-i-really-mean-it`.
    4. Run `node scripts/oneoff/set_admin_claim.js` to set custom claims on admin accounts and remove the temporary Gmail fallback in `firestore.rules`.
    5. Update `public/privacy.html` §5 to state that email addresses are strictly private, then deploy Hosting: `firebase deploy --only hosting`.

- [ ] **2. Finalize Google Play Data Safety Form ([`owner_works_now.html #8`](../../../../housekeeping/owner_works_now.html), [`data_safety_and_permissions.md`](../General/Files%20for%20Stores/store_listing/data_safety_and_permissions.md)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** draft: `DOCS/General/Files for Stores/store_listing/throttleiq_data_safety.DRAFT.csv` + `data_safety_review.DRAFT.md` (23 answers changed, 7 owner decisions, `privacy.html` gaps listed).
  - **Context:** Play Console requires exact declarations matching app behavior. Decisions settled: Analytics on by default with disclosed opt-out; Crash research data opt-in.
  - **Action Steps:**
    - Complete entries in `General/Files for Stores/store_listing/throttleiq_data_safety.csv`.
    - Declare: App interactions (analytics with opt-out), Audio recording (voice notes in group rides), Precise location (background telemetry), and Crash logs.
    - Declare opt-in Crash research records under "Other actions" and "Approximate location".
    - Finalize legal position on Health info (SafeQR blood group stored on-device only, never uploaded) and User IDs.

- [ ] **3. Terms of Service & PDPO 2025 Compliance Review ([`owner_works_now.html #30`](../../../../housekeeping/owner_works_now.html)):**
  - **Status 2026-10-22 (branch `integration/agent-rooms-2026-10-22`):** draft: `public/.terms.DRAFT.html` (dot-prefixed, so Hosting never serves it), with `[LAWYER REVIEW]` markers.
  - **Context:** No formal Terms of Service document exists in the repo or on the web. Apple App Store Guideline 1.2 requires an explicit zero-tolerance policy for user-generated content (posts/chats). Bangladesh Personal Data Protection Ordinance 2025 requires baseline governance.
  - **Action:** Draft `public/terms.html` incorporating standard consumer safety and zero-tolerance harassment clauses; coordinate lawyer review; link terms from app Settings and signup screen.

---

## 🛡️ P1: Operational Infrastructure & Runbooks

- [ ] **4. Maintain & Execute Account Deletion Runbook ([`owner_works_now.html #12`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Automated deletion functions cannot run until Blaze billing is active. `privacy.html` routes all deletion requests to `hello@blankframe.tech`.
  - **Action:** Service any manual deletion requests within 30 days using [`DOCS/For Devs and Contributors/guides/account_deletion_runbook.md`](../For%20Devs%20and%20Contributors/guides/account_deletion_runbook.md).

- [ ] **5. Cloudinary Upload Security & Storage Capping ([`owner_works_now.html #11`](../../../../housekeeping/owner_works_now.html), [`SECURITY.md:99–110`](../../../SECURITY.md)):**
  - **Context:** The `throttleiq_unsigned` upload preset accepts direct uploads from mobile clients without backend authentication.
  - **Action:**
    - Configure Cloudinary dashboard: set maximum file size to 10 MB (accommodating audio voice notes and compressed bike photos).
    - Activate usage alerts at 80% quota.
    - Confirm asset public IDs maintain the `<kind>/<uid>/<asset_id>` structure to guarantee future deletion scripts can verify asset ownership.
    - Purge test artifacts from `preset_test/`.

- [ ] **6. Secrets Isolation & Drive Sync Quarantine ([`owner_works_now.html #10`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Keys inside the workspace are continuously synchronized to Google Drive.
  - **Action:**
    - Relocate `secrets/throttle-iq-gcc1-*.json`, `secret/creds.txt`, and `throttleiq-release.keystore` to `~/.secrets/throttleiq/`.
    - Update `app/android/key.properties` with the absolute path to the keystore.
    - In Google Cloud Console, restrict the Firebase API keys (Android package `com.bft.throttleiq` + SHA-1 fingerprints, iOS bundle ID, authorized web domains).

---

## 📦 P2: Release Engineering & Quality Governance

- [ ] **7. Enforce GitHub Ruleset & Dependabot Triage ([`owner_works_now.html #16`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** `main_ruleset` on GitHub currently does not enforce status checks before merge.
  - **Action:**
    - Require status checks: `flutter`, `rules`, and `functions` on GitHub `main` branch.
    - Add repository owner to bypass list to allow automated release script pushes.
    - Triage and merge green Dependabot PRs (#17, #18, #19).

- [ ] **8. Oversee Release Pipeline for Next Version ([`owner_works_now.html #26`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** `main` holds quota outage mode (`c751968e`), App Check sideload gate (`d92f694e`), and E2E stability fixes (`4b914c10`).
  - **Action:** Verify all pre-release quality gates with `scripts/check.sh`; coordinate with the team to trigger `scripts/deploy.sh` once App Check decisions are settled.

- [ ] **9. Native Bangla Review Tracking ([`owner_works_now.html #9, #29`](../../../../housekeeping/owner_works_now.html)):**
  - **Context:** Approximately 1,700 lines of machine-drafted Bangla in `app/lib/l10n/bn_pending_review.txt` (including quota alert banners, moderation sheets, and privacy copy) are scheduled for native speaker review in November 2026.
  - **Action:** Track review batch handoff and schedule `flutter gen-l10n` build verification once corrections arrive.
