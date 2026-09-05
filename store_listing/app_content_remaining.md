# Play Console — remaining "App content" & "Store settings" sections

These are the sections under **Grow → Store presence → App content** and
**Store settings** that aren't covered by `store_listing.md` (main listing —
DONE) or `data_safety_and_permissions.md` (privacy policy, Data Safety form,
background-location declaration, content-rating heads-up). All are
Console-UI-only forms; there's no API for them. Suggested answers below are
based on what's actually in the codebase as of 2026-08-29 — re-check before
submitting if the app has changed.

## Sign-in details

Play asks whether the app requires login, and wants reviewer credentials if
so.

- **"Does your app require log-in?"** → **Yes** — every screen past Splash
  redirects to Login/Register (`app_router.dart`); there's no guest mode.
- **Reviewer test account**: use one of the QA-seeded accounts from
  `scripts/seed_qa_test_riders.js` (`@qa-seed.invalid` domain, password is
  `QA_PASSWORD` from that script's config — Firebase Auth doesn't verify the
  email domain is real, so a `.invalid` address works fine for sign-in). Pick
  one rider handle, confirm it still exists in the `throttleiqfb` project,
  and paste that email + password into the Console field. **Don't reuse the
  admin account** (`the.abraar.rar@gmail.com`) as the reviewer login — give
  reviewers an ordinary rider account so they see the normal experience, not
  moderation controls.
- Add a one-line instruction in the "special access requirements" box: *"Sign
  in with the provided email/password, or tap Continue with Google."*

## Ads

- **"Does your app contain ads?"** → **No.** Confirmed: `pubspec.yaml` has no
  `google_mobile_ads`, `unity_ads`, `applovin`, or any other ad SDK. If ads
  are ever added, this answer and the Data Safety form's "Ads" purpose both
  need updating together.

## Content rating

Already covered in `data_safety_and_permissions.md`'s last section — fill
the IDARC questionnaire honestly; expect above "Everyone" because of UGC
(forums, reviews) and real-time location sharing between users, not because
of anything else in the app.

## Target audience and content

- **Target age groups**: recommend selecting **18 and over only**. The app's
  core function is recording motorcycle rides — riding a motorcycle
  legally requires an adult or licensed-minor status that varies by country,
  and the social features (forums, DMs-via-profile, live location sharing)
  are the kind Play scrutinizes hardest when children are in the target
  range. Selecting a younger age band pulls in the stricter **Families
  policy** and a mandatory ads-and-tracking review that this app doesn't
  need to opt into.
- **"Is your app designed to appeal to children?"** → **No.**
- **"Does your app fall under Google's Families policy?"** → **No**, if the
  above target age is set to 18+ only. If the answer to target age is
  ever changed to include under-13, that flips to Yes and requires a much
  stricter listing review — don't change one without the other.
- This choice is a business decision, not just a technical one — confirm
  it matches the actual intended market before submitting.

## Government apps

- **"Is this a government app?"** → **No.** ThrottleIQ is an independent,
  solo-developer project (confirmed in `docs/planning/HANDOFF_Document.md`'s publisher
  identity note — registered as an individual, not a company or agency).

## Financial features

- **"Does your app provide any financial features?"** → **No.** No payment
  processing, lending, crypto, trading, or insurance SDK/flow exists
  anywhere in `pubspec.yaml` or `app/lib/` — the app has no monetization
  built at all yet. Revisit this section if/when in-app purchases or
  subscriptions are added.

## Health

- **"Does your app provide health-related features?"** → **No.** This
  section is about apps making regulated health claims (fitness tracking
  tied to medical use, health records, telehealth, etc.). ThrottleIQ records
  ride telemetry (speed, GPS, motion for crash detection) for vehicle safety
  and performance purposes, not health/fitness — it doesn't claim to
  measure steps, heart rate, sleep, or any medical metric. No change needed
  here even though the app requests `ACTIVITY_RECOGNITION` — that permission
  is used for automatic ride-start detection, not health tracking, and
  should be described that way if Play ever asks for clarification.

## App category & contact details

(Play Console → Store presence → Main store listing → Categorization /
Contact details — some of this may already be set since the main listing
shipped 2026-08-29; confirm it's actually filled in, since these fields
are separate from the description/screenshots pushed via the API.)

- **App category**: **Auto & Vehicles** (matches `store_listing.md`'s
  existing recommendation; Maps & Navigation is the fallback if Play pushes
  back on Auto & Vehicles for any reason).
- **Tags**: pick from Play's own tag list at submission time — motorcycle/
  ride-tracking isn't a first-class tag, so the closest matches are
  whatever Play offers under Auto & Vehicles.
- **Contact details**:
  - Email: `the.abraar.rar@gmail.com` (already the address used throughout
    `public/privacy.html` and the in-app support/admin contact).
  - Website: `https://throttleiqfb.web.app` (the same Firebase Hosting
    project that serves the privacy policy and live-ride viewer).
  - Phone: optional — leave blank unless the developer wants to list one.

---

**Still open after this doc**: the Data Safety form and Content rating
questionnaire (`data_safety_and_permissions.md`) are the two Console-UI-only
flows explicitly called out as not-yet-done in
`docs/planning/HANDOFF_Document.md`'s Play Store checklist item 5. Everything in this
file is new ground beyond what that checklist already tracked.
