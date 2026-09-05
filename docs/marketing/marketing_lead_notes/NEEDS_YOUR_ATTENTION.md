# Needs your attention — marketing-lead session, 2026-09-05

Working autonomously as marketing lead this session (per your instruction).
Everything I could execute directly (copy, docs, low-risk code fixes) is
done and described in the sibling files in this folder. This file is only
the things that need a decision or an action from you — nobody else can
close these.

---

## 1. 🔴 Blocker: Play Console internal-testing track has zero testers

Per `docs/planning/HANDOFF_Document.md` (2026-08-29): versionCode 3
(`1.0.0-beta.1+3`, now superseded by later builds) was uploaded to the
Play Console internal testing track and its status is `completed` — but
**the tester list came back empty via the Android Publisher API.** Nobody
can install this build through Play right now.

This is **UI-only** — the Android Publisher API confirmed it cannot add
individual tester emails (`edits.testers` only accepts a Google Group).
You need to:
1. Play Console → your app → **Test and release → Internal testing →
   Testers** tab.
2. Paste the tester emails into an "Email list" (six were reportedly
   already collected per that handoff note, plus whichever new ones you
   want for Phase 0 recruiting below).

**Why this matters more than it looks:** the entire Phase 0 plan in
`marketing.md` (recruit 20-30 riders from BD Facebook groups as closed
testers) is blocked until this is done — there is no build they can
actually install today except the raw GitHub APK, which is a much higher
friction ask for a non-technical rider than a Play Store internal-testing
link. Closing this one Play Console checkbox is the single highest-leverage
open task in the whole GTM plan right now.

---

## 2. 🔴 Recurring, unresolved: turn on Firebase Blaze billing

This isn't new to this session, but it's important enough for marketing
specifically that I'm re-surfacing it: `docs/architecture/backend_options.md`
recommends enabling Blaze (pay-as-you-go, no base fee, modeled at
single-to-low-double-digit $/month at beta scale) and it's still not done.
`docs/marketing/business_critique.md` names this as the single biggest gap
between the app and a credible pitch: **crash detection + emergency
alerting is the emotional core of every piece of marketing material
written for this app**, and it currently degrades to "a link the rider has
to remember to turn on and manually share" because the SMS/email
escalation (`functions/src/crash-notifications.ts`) can't deploy without
it. Every session this stays unresolved is a session where the core safety
pitch — the strongest hook for the anxious-family segment — stays partially
fictional. This is a billing/card-on-file decision, not a code decision;
nobody but you can make it. The estimate and full tradeoff analysis
(vs. migrating off Firebase, which the doc argues against) is in that file.

## 3. Decide: publish the Bangla store-listing draft as-is?

I drafted a full Bangla short/long description + keyword set at
`store_listing_bn_addendum.md` in this folder, ready to paste into Play
Console → Store presence → **Translations → Add your own translation →
Bengali (Bangladesh)**. I did not paste it in myself (no Play Console
access from here, and translated store copy should get a native-speaker
read before going live even though I've kept the phrasing plain and
checked it against the no-overclaim rule). Please have a Bangla speaker
skim it before it goes live — machine-assisted translation of tone/idiom
can drift even when the literal claims are accurate.

---

## 4. Decide: the badge-tier physical-prize promotion (oil/chain-lube kit)

`marketing.md` §6 proposes a "first to reach badge tier X wins engine oil /
a chain-cleaner kit" promotion, gated on reaching ~100 organic users. It's
explicitly not ready to run: there's no claim/fulfilment mechanism (verify
the badge, collect a shipping address, ship one prize per person, cap
abuse), and no courier relationship or per-unit cost budget. This needs:
- A decision on whether to build the claim/fulfilment flow at all (it's
  the same missing piece blocking the "all badges → free oil" promise
  already flagged in the handoff doc's open questions — one build serves
  both).
- A real BD courier quote before announcing anything publicly.

Not urgent (gated on 100 organic users, which is itself gated on item #1
above), but it's a build-time decision, not a copy decision, so it's yours
to make, not something I should silently draft copy for.

---

## 5. Decide: "the ask" — pitch deck slide 10

`pitch_and_marketing_materials.md` leaves the pitch deck's final slide as
an open placeholder (funding / mentorship / pilot riders / distribution
partners / a specific city-launch budget). Nothing in the repo states
which one you actually want, and I'm not going to invent a funding ask on
your behalf. Tell me which direction (if any) and I'll draft the slide.

---

## 6. Heads-up, not a blocker: QA-seeded forum content is stale in production

`docs/planning/Issues.md` §55 flags that 30 QA test-rider accounts with
old (less authentic) names/bike catalog/post copy are **already live** in
the real `throttleiqfb` Firestore project, visible to real beta testers —
this directly touches the "cold-start empty forums" fix in `marketing.md`
§3 (good: forums aren't empty; not-great: the seeded content reads as
generic/inauthentic to a real BD rider browsing them). Fixing this needs
`cleanup_qa_test_riders.js` (deletes the 30 live accounts — irreversible)
then a fresh reseed with the corrected catalog — both are flagged in
`Issues.md` as needing an explicit go-ahead, which is a production-data
decision I'm treating as yours, not mine, to trigger.

---

## What I did NOT touch, on purpose

- No app code beyond what's already described (I left the in-progress
  uncommitted maintenance-feature changes in your working tree completely
  alone).
- No Play Console / Firebase / production data changes — I have no access
  and wouldn't make production-data changes autonomously regardless.
- No paid-ad spend or budget commitments — `marketing.md` §8 is explicit
  that this stays zero-to-low-paid-spend until organic retention is
  healthy; that's a real budget decision, not a copy decision.
