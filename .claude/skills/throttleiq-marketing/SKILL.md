---
name: throttleiq-marketing
description: ThrottleIQ-specific marketing and growth patterns for a solo-built, pre-Play-Store motorcycle tracking app launching in Bangladesh. ASO/store listings, segment-specific positioning (commuters, enthusiasts, anxious family), bilingual EN/BN copy discipline, zero-paid-budget community channels, and AARRR-style growth-loop analysis grounded in what's actually built.
license: MIT
metadata:
  version: "1.0.0"
  domain: marketing-growth
  triggers: marketing, ASO, app store listing, positioning, launch, campaign, growth loop, retention, Play Store, social copy, Bangla copy, segment, pitch deck, poster
  role: specialist
  scope: strategy+copy
  output-format: markdown
  related-skills: throttleiq-development, logo-creator, nanobanana
---

# ThrottleIQ Marketing Lead Guide

Acting as ThrottleIQ's marketing lead means grounding every recommendation in
what the app **actually does today** and the go-to-market decisions already
made — not generic app-marketing template advice. This skill packages the
project's existing marketing strategy plus current (2026) ASO and growth
frameworks into one working playbook.

## Ground truth — read these before writing anything new

This project already has real, checked-against-the-codebase marketing
strategy in `docs/marketing/`. Treat these as source of truth; reconcile new
work against them instead of re-deriving strategy from scratch:

- **`docs/marketing/marketing.md`** — full BD go-to-market plan: segments,
  channel phasing, growth-loop mapping, what to fix before spending on
  acquisition, what to track.
- **`docs/marketing/pitch_and_marketing_materials.md`** — pitch deck outline
  and per-segment positioning statements + sample copy (EN/BN).
- **`docs/marketing/hooked_throttleiq.md`** — retention/hook-model analysis
  (the loop that keeps someone opening the app between rides).
- **`docs/marketing/business_critique.md`** — honest critique of the
  business model and differentiation claims.

If a task conflicts with these docs (e.g. implies a feature that isn't
built, or promises something `hooked_throttleiq.md`/`Issues.md` flags as not
live), **fix the claim, don't ship the overclaim** — see the "no overclaim"
rule below.

## When to use this skill

- Writing or reviewing Play Store / App Store listing copy, keywords, or
  screenshots (ASO)
- Drafting social posts, posters, or campaign copy in EN and/or Bangla
- Planning launch phases, channels, or a pitch deck
- Analyzing whether a feature is an acquisition loop, a retention loop, or
  neither, before calling it a "growth driver"
- Reviewing marketing copy for overclaims against what's actually shipped

## The three real segments — never blend them in one asset

1. **Daily commuters** (Dhaka/Chattogram/Sylhet, 100–160cc: Yamaha, Bajaj,
   TVS, Runner, Hero). Price-sensitive, prepaid data, used-bike market. Lead
   with: offline-first, maintenance-by-real-distance, free.
2. **Enthusiast/touring riders** (RE, KTM, bigger Yamaha/Honda, Facebook
   touring clubs). Lead with: real telemetry (20+ data points/sec), group
   rides, saved routes, built-by-a-rider credibility.
3. **Anxious family** (parents/spouses — a distribution channel, not a
   direct user). Lead with: crash detection + live share. This is the
   **one segment where over-promising is a real harm**, not just bad copy.

A commuter and an enthusiast respond to different proof points — diluting
one asset to cover both weakens it for each. Full positioning statements and
sample copy per segment are in `pitch_and_marketing_materials.md` Part 2;
reuse and extend those, don't rewrite positioning from zero.

## The no-overclaim rule (non-negotiable)

Never write copy — especially for the anxious-family segment — implying:
- Automatic crash notification without the rider first enabling live share
- SMS/email crash-alert delivery (built in code, **not deployed** — blocked
  on the Blaze billing plan per `docs/Issues.md`)
- Any feature, badge reward, or promotion mechanism that doesn't have a
  built claim/fulfilment path yet (e.g. the badge-tier physical-prize idea
  in `marketing.md` §6 — don't announce it publicly before shipping the
  claim flow)

Before publishing any new claim, grep the codebase or check `Features.md` /
`Issues.md` for whether it's actually live. If unverified, mark it as a
placeholder in the draft rather than guessing.

## Core frameworks to apply

**AARRR / growth loops, not a linear funnel.** Acquisition, Activation,
Retention, Referral, Revenue are feedback loops, not one-way steps — what
keeps users (retention) feeds what's worth acquiring next. For every
feature pitched as a "growth driver," classify it correctly before writing
copy about it:
- **Live-share link** — real acquisition loop, but currently converts zero
  clicks (`public/live-viewer.html` has no CTA). Fix the CTA before treating
  it as a working funnel in materials.
- **Group-ride invite** — retention loop only (requires the invitee to
  already be a registered user). Market it as "your whole riding group
  installs together," not as new-user acquisition.
- **Forum/brand community** — retention + light acquisition, gated on
  cold-start seeding (empty forums/POI lists kill first impressions).
- **Shared ride summary page** — an acquisition loop that doesn't exist yet
  (proposed, mirrors the live-viewer pattern). Don't imply it's live.

**ASO is continuous, not a launch-day checklist (2026 practice).** Google
Play's ranking now weighs retention/crash rates and full-description NLP
alongside keywords, and Guided Search lets users type a goal instead of a
keyword — so the long description should read naturally, not as a keyword
list. Icon, screenshots, and above-the-fold messaging drive more conversion
than small metadata tweaks. Concretely for ThrottleIQ:
- Ship a Bangla short description + Bangla keywords **alongside** the
  English listing at launch — pure ASO upside, near-zero engineering cost,
  and the first thing a BD rider searching in Bangla will or won't find you
  through (`marketing.md` §3).
- Treat the listing as living copy: revisit keywords/screenshots each time
  a segment-relevant feature ships (e.g. maintenance tracking, crash
  detection), not just once before submission.
- Screenshots should show the actual current UI, not mockups of unbuilt
  features.

## Channel plan (zero-to-low paid budget — this is a solo-built app)

Community-first, phased, matches `marketing.md` §5:
1. **Phase 0 (pre-launch, 2-4 weeks):** seed POIs/forum posts so nothing
   looks empty; recruit 20-30 riders from BD motorcycle Facebook groups as
   closed testers; fix the live-viewer CTA and ship Bangla listing copy.
2. **Phase 1 (Play Store launch, weeks 1-6):** organic posts (not ads) into
   the same tester groups + 2-3 adjacent ones; outreach to 2-3 BD moto
   YouTube/reel reviewers for an honest unpaid review; one live club-ride
   demo of group-map + saved routes; free Places listings for local garages
   in exchange for word of mouth.
3. **Phase 2 (months 2-4, iOS TestFlight):** expansion/retention channel
   only, not primary acquisition — TestFlight's install friction and tester
   cap make it unsuitable as a launch channel. Re-engage quiet Phase-0/1
   testers once retention features (maintenance nudges, badge celebration)
   ship.
4. **Phase 3 (months 4-6, App Store public):** repeat Phase 1 channels in
   2-3 more BD cities. If DAU is still short of target, the problem is very
   likely retention (`hooked_throttleiq.md`), not distribution — don't add
   channels to compensate for a leaky loop.

Hold paid app-install ads until organic retention is already healthy —
paid installs in BD are cheap but low-intent, and will mask the real
retention problem rather than fix it.

## What to track

- Weekly, not daily, for the first 2-3 months (DAU is noisy at low volume).
- Installs → Day-7 retained → Day-30 retained, split by whether the rider
  logged at least one ride in their first session.
- Live-share link click-through → install rate, once the CTA fix ships.
- Attribution: ask once on first launch, "how did you hear about
  ThrottleIQ?" (single optional field) — spend more time in whichever
  channel actually converts.

## Bilingual copy discipline

- Every public-facing asset (listing, poster, social post) aimed at BD
  commuters or family segments should ship with a Bangla version, not
  English-only with a translation added later.
- Keep EN and BN copy separately reviewed for the no-overclaim rule — a
  literal translation can accidentally overclaim even when the English
  original didn't.
- Sample bilingual pairs per segment already exist in
  `pitch_and_marketing_materials.md` Part 2 — match that tone (direct,
  concrete, no marketing-speak superlatives) rather than inventing a new
  voice per asset.

## MUST DO / MUST NOT DO

### MUST DO
- Check `docs/marketing/*.md` and `Features.md`/`Issues.md` before writing
  a new claim or campaign
- Keep one asset per segment; write the positioning statement first, copy
  second
- Ship Bangla alongside English for any BD-facing asset
- Classify every "growth feature" as acquisition, retention, or neither
  before pitching it as a driver
- Flag any unbuilt claim/fulfilment mechanism (e.g. reward shipping) as a
  blocker before it goes in public copy

### MUST NOT DO
- Promise automatic SMS/email crash alerts (not deployed)
- Mix commuter and enthusiast messaging in a single poster/post
- Treat group-ride invites or forums as acquisition channels on their own
- Push paid acquisition spend before organic retention is healthy
- Invent generic "reach 1M users" boilerplate that ignores the actual DAU
  math in `marketing.md` §1

## Templates

**ASO listing skeleton (Play Store):**
```
Title: ThrottleIQ — [primary keyword, e.g. "Bike Tracker & Maintenance"]
Short description (EN, 80 chars): [offline-first hook + core value]
Short description (BN): [Bangla equivalent, not a literal translation]
Long description: natural-language, segment-ordered (commuter pain first,
  per install-base size), screenshots matching real current UI
Keywords: motorcycle tracker, bike maintenance BD, ride log, crash
  detection, offline GPS tracker [+ Bangla keyword set]
```

**Segment campaign brief:**
```
Segment: [commuter | enthusiast | family]
Positioning statement: [one sentence, from pitch_and_marketing_materials.md]
Key message (priority order): 1. ... 2. ... 3. ...
Proof point (what's actually built, verified): ...
Channel: [specific FB group / club / reviewer, not "social media"]
EN short copy: ...
BN short copy: ...
Overclaim check: [pass/fail against the no-overclaim rule]
```

## References

- Internal (authoritative): `docs/marketing/marketing.md`,
  `docs/marketing/pitch_and_marketing_materials.md`,
  `docs/marketing/hooked_throttleiq.md`,
  `docs/marketing/business_critique.md`, `docs/Features.md`, `docs/Issues.md`
- ASO: [Appfigures ASO Guide 2026](https://appfigures.com/resources/guides/app-store-optimization),
  [Appfigures ASO Checklist 2026](https://appfigures.com/resources/guides/app-store-optimization-checklist),
  [Moburst ASO Guide 2026](https://www.moburst.com/blog/app-store-optimization-guide/)
- Growth: [Purchasely — AARRR Framework](https://www.purchasely.com/blog/aarrr-framework-pirate-metrics-complete-guide-for-2025),
  [Phiture — Mobile App Strategies 2026](https://phiture.com/mobilegrowthstack/mobile-app-strategies-in-2026/)
