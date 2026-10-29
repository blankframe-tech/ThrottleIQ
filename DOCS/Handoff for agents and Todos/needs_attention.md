# Needs Attention

_Rewritten 2026-10-22 against `main`. Only what the founder must do: an account, money, a real
device, a decision, or a deploy. Steps for each item are on the owner page,
`~/Everything/dev/housekeeping/owner_works_now.html` (ThrottleIQ block); `#N` below is its item
number. Done items are deleted, not ticked; git history keeps them._

## Release and deploy

- [ ] **Security sweep follow-ups (new 2026-10-30, PR #98, GitHub #92 #93 #94 #96 #97):** deploy
      `firestore.rules` (`--only firestore:rules`; the fixes are public in the repo, the live rules are
      not); rotate the Play review account password (old one is in git history); restrict the
      Cloudinary `throttleiq_unsigned` preset; check the Firebase API key restrictions; decide on
      `secret/`. Before functions go live on Blaze, confirm the crash-alert caps (5 contacts, 3 alerts
      an hour). Details: `security_sweep_2026-10-30.md` "Before you deploy".
- [ ] **Deploy (#30, #31):** rules, indexes and Hosting last went out 2026-10-27 (critique fixes
      included). Left: Cloud Functions once on Blaze (deletion, retention, chat moderation).
- [x] **Vote `uid` (`SECURITY.md` step 11):** rules and indexes deployed 2026-10-29 (`4a16cc37`);
      backfill ran 2026-10-29, 110/110 vote docs, re-run reports 0. Run it again once
      `config/app.minBuild` passes the next release (item below).
- [ ] **After the next release is the minimum build (#56, new 2026-10-28, issues §115):** raise
      `config/app.minBuild`, ask an agent for the §115 cleanup (vote `uid` required, polyline cap
      of 1,000 points, drop the legacy comment-delete clause, remove the vote scan), deploy the
      rules, and run the vote backfill once more.
- [ ] **Next release (#26):** ships the Firestore quota outage mode (merged 2026-10-22, `c751968e`).
      Since 2026-10-28 it also carries the 2026-10-27 critique fixes (`issues_fixed.md` §115).
      Builds from `main` also carry the App Check sideload gate, so settle #17 and #32 first
      (`For Devs and Contributors/guides/app_check.md`). Since 2026-10-22 it also carries the §104 read
      savings, the 8 s screen-write timeout, hour-rounded crash timestamps and the legacy-likes removal.
- [ ] **Rules and indexes for share-to-groups (#50, new 2026-10-25):** deployed 2026-10-25. Left:
      confirm the two new `posts` indexes show Enabled (Firebase console › Firestore › Indexes) before
      releasing; until then the All Riders feed errors and cross-posts are missing from group feeds.
- [ ] **Legacy likes, steps 2-3 (#45, new 2026-10-22):** after that release, raise
      `config/app.minBuild`, then delete the `likes` rule and deploy rules (issues §80).
- [ ] **App Check enforcement (#17):** only after riders are on a build that sends tokens.
      Enforcing early locks out every older build.
- [ ] **Check that the Firestore quota alert emails reach you (#24).** The rehearsal sent 6 to
      blankframe.technologies@gmail.com on 2026-10-21. If they are in Spam, mark them Not spam.

## Google Play and stores

- [ ] **Play Console (#4, #8):** internal then closed testing; add testers (the install page asks
      for tester emails). Declarations: background location and the full-screen intent stay
      (decided 2026-10-21).
- [ ] **Data Safety form** from `General/Files for Stores/store_listing/throttleiq_data_safety.csv`:
      app interactions (analytics on by default with a disclosed opt-out, decided 2026-10-22), audio,
      precise location, crash logs, plus (2026-10-22) Other actions for impact records and
      Approximate location, opt-in, for the crash research copy. Decide the two open calls in
      `data_safety_and_permissions.md` ("Crash detection records") first: Health info, User IDs.
      Draft answers for review (2026-10-22): `throttleiq_data_safety.DRAFT.csv` and
      `data_safety_review.DRAFT.md` in the same folder (23 answers change, 7 calls for you).
- [ ] **SafeQR now syncs medical info (new 2026-10-28, issues §117):** tick Health info in the Data
      Safety form (collected, optional, not shared, App functionality) and deploy hosting so the
      updated `public/privacy.html` goes live. It ships in +33.
- [ ] **privacy.html is behind the app (#46, new 2026-10-22):** bike photos are uploaded, and the
      camera permission, Nominatim lookups and group-ride positions aren't disclosed; the app has no
      link to the policy (`data_safety_review.DRAFT.md`).
- [ ] **Terms of Service and a PDPO 2025 review by a lawyer (new 2026-10-22).** No terms exist in
      `public/` or the app (issues §109.14). Draft for the lawyer: `public/.terms.DRAFT.html` (2026-10-22,
      never served).
- [ ] **Before any App Store submission:** enrol in the Apple Developer Program (#21), then the
      widget extension's privacy manifest and Sign in with Apple.

## Accounts and security

- [x] **Admin claim (#2):** claim set, Gmail fallback removed from `isAdmin()` and rules deployed
      2026-10-29 (`941a7e9a`, issues §110.4).
- [ ] **Unused key (new 2026-10-28, optional):** `secret/throttle-iq-gcc1-b9771877b5d4.json` is a
      key for another Google Cloud project (`throttle-iq-gcc1`) that no ThrottleIQ script uses.
      Delete it in that project's console if nothing else needs it.
- [ ] **Secrets (#9):** rotate the Apify token, move keys out of the Drive-synced repo, restrict the
      Firebase API keys.
- [ ] **CodeQL (#49, new 2026-10-22):** the push of `a0bf4f4f` bypassed the main ruleset while CodeQL
      was pending; check its result.
- [ ] **Cloudinary (#11):** size cap and usage alert on the `throttleiq_unsigned` preset (formats are
      locked). Before any functions deploy, confirm public IDs keep the `<kind>/<uid>/` prefix, or
      the deletion sweep's ownership check skips every asset.
- [ ] **Security scans (#55, new 2026-10-28):** `security.yml` (gitleaks + osv-scanner) and
      `.gitleaks.toml` are written but uncommitted; tell an agent to commit and push them.
- [ ] **CI (#16):** GitHub CI runs and passes, but `main` has no required checks. Make `flutter`,
      `rules`, `functions`, `secrets` and `dependencies` required; turn on Secret scanning and Push
      protection (Settings › Code security); approve or close the Dependabot PRs.
- [ ] **Deletion requests by hand within 30 days**, with
      `For Devs and Contributors/guides/account_deletion_runbook.md`, until the deletion function
      runs on Blaze.

## Needs a phone, a bike or a person

- [ ] **Critique fixes on a phone (new 2026-10-28):** vote and un-vote a ride, comment, follow a
      forum (it always failed before), reply to a post, share a ride with a photo, make a route
      public. Then boot a simulator and run
      `cd app && flutter drive --driver=test_driver/integration_test.dart --target=integration_test/e2e_test.dart`.

- [ ] **Real-phone test (#5).** Nothing on `main` since the last release has run on hardware. The
      checklist is the "Device checks" follow-up at the top of `issues_open.md` and the HANDOFF's
      "Built but never run on a real phone" list (widgets and the ride ⋮ menu: issues §107.7;
      battery with the 50 Hz shadow-mode crash detector).
- [ ] **Crash calibration recordings (new 2026-10-22):** phyphox recordings on the bike, so the
      shadow-mode thresholds rest on measurements (issues §78.1, §78.12).
- [ ] **Bangla review (#12, #28):** a native reviewer for `app/lib/l10n/bn_pending_review.txt`
      (includes the quota strings), the draft Bangla in `marketing_kit.md`, and the Bangla store
      listing.
- [ ] **Beta riders (#6):** count them and talk to five.
- [ ] **A budget Android phone (new 2026-10-22):** one day of normal use on a 2-3 GB itel, Tecno
      or Redmi: OEM battery managers, the all-day wakelock, low-RAM recovery (issues §96).
- [ ] **Maintenance schedules (new 2026-10-22):** check the templates against Bangladesh service
      booklets and 2-3 mechanics (issues §95.2-§95.4).

## Decisions

- [ ] **Unused code on `main` (#57, new 2026-10-28, critique #19):** park the Realtime Database code
      (`core/realtime/`, typing channel, viewer RTDB path, `firebase_database`) on a
      branch, or keep it. Ties to #3 (Blaze). Indriyo decided 2026-10-29: kept, in every
      build behind Settings → Advanced.

- [ ] **Google Maps data in production (#1):** take it down or keep it. Decision card:
      `DOCS/agent_rooms/drafts/decision_card_scraped_places.md` (2026-10-22).
- [ ] **Blaze (#3)**, or how far to go on Spark (decision card: `DOCS/agent_rooms/drafts/decision_card_blaze_upgrade.md`). Blocked without Blaze: Firestore TTL policies
      (`liveSessions.expiresAt`, and `places.expiresAt` for expired checkpoints, issues §107.4;
      tried 2026-10-08: 403 billing disabled), real SMS and escalation, signed Cloudinary uploads,
      account deletion (a Spark workaround is issues §109.12), rate limits. Cloud Functions Node 20
      is decommissioned late October 2026; `functions/` already targets Node 22.
- [ ] **Blocking and Cloudinary uploads on Spark** (issues §83.18, §83.16): the options are in
      issues §107.3.
- [ ] **Pitch (#22):** slide 9 (the team) and slide 10 (the ask). The iDEA submission names three
      roles and an advisory panel; git shows one author.
- [ ] **PRD success-metric targets (new 2026-10-22):** PRD §10 lists five proposals for you to
      confirm.
- [ ] **Smaller calls:** reports filed by a deleted rider (#29), report rate limit and retention
      (#33), the public WhatsApp number on the install page (#34), ranking the forum ideas (#35, the
      front-plate guide only helps before 15 Nov), the badge-tier prize promotion (new), the beta-only
      order-parts button: keep it for a partner or remove it (new, issues §95.11), "Verified" places vs
      the SafeSpot flyer (#47), and the Maya pricing in the public repo (#48).

## Outside contributors (new 2026-10-28)

- [ ] **Lawyer review of LICENSE §1A and CLA.md (#53)** before announcing; also fix §9 governing law.
- [ ] **Post the contributor outreach (#54):** `Handoffs for Non Coding Agents/marketing/contributor_outreach.DRAFT.md`.

## Indriyo training data (new 2026-10-29)

Licences checked by an agent; nothing downloaded or trained. Indriyo stays on `main` (decided 2026-10-29), so this no longer waits on #57.

- [ ] **DhakaAI (#58):** [Harvard Dataverse](https://doi.org/10.7910/DVN/POREXF) (CC0, the original) /
      [Kaggle](https://www.kaggle.com/datasets/rifat963/dhakaai-dhaka-based-traffic-detection-dataset) (mirror, says GPL 2).
      About 3K images, 21 classes including rickshaw, CNG and human hauler. Can train the shipped model.
      **You:** confirm the photos are the authors' to give away (CC0 may cover only the labels if the
      photos were scraped); give the agent a GPU account and token (Kaggle or Colab); test on a real
      phone with the Indriyo camera and record rear-facing rides. **Agent alone:** download, convert,
      map classes, fine-tune a small Apache-licensed detector (not Ultralytics, AGPL), export
      TFLite/Core ML, wire into `IndriyoNotifier.updateThreatState`, tests, `scripts/check.sh`.
- [ ] **RSUD20K (#59, decision):** [Kaggle](https://www.kaggle.com/datasets/hasibzunair/rsud20k-bangladesh-road-scene-understanding) /
      [GitHub](https://github.com/hasibzunair/RSUD20K) / [paper](https://arxiv.org/abs/2401.07322).
      20K dashcam images on Bangladesh roads, but CC BY-NC 4.0 (non-commercial). Recommended: use it
      only to test the DhakaAI model (scratchpad only, never committed, never trained into the shipped
      model, its weights never shipped). If Indriyo heads to sales, you email the authors for a
      commercial licence; the agent can draft the email.

## Settled, don't re-ask

- Keystore backed up (2026-09-21). Map tiles: Thunderforest. `config/app.minBuild = 29`.
- hello@blankframe.tech delivery confirmed (2026-10-22). Analytics: on by default with a disclosed
  opt-out (2026-10-22).
- Crash detection runs in shadow mode only: nothing is sent to anyone.
- `gov-pitch/` materials aligned with `iDEA_PITCH_SUBMISSION.md` and `marketing.md` (2026-10-22): crash detection framed as uncalibrated shadow-mode research; claims of live crash detection and automated SMS alerting removed; "Do not submit" banners removed.
- Deleting a bike archives it; the Profile tab is "Garage"; Bangla dates use English-style digits
  in the Bangla font.
