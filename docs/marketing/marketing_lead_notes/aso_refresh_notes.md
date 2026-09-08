# ASO refresh notes (2026 practice vs. current listing)

Checked `store_listing/store_listing.md` against current (2026) Google Play
ranking practice. Verdict: **the existing listing is already solid and
accurate** — well-scoped, honest about what's not built (SMS/email
escalation), written in plain language rather than a keyword-stuffed list.
The notes below are refinements, not a rewrite; I did not edit
`store_listing.md` directly since it's clearly a carefully hand-checked
source-of-truth file and any change to it should go live in Play Console
in the same pass — flagging suggestions here instead.

## What 2026 Play Store ranking actually weighs (per current ASO guidance)

- Google's algorithm reads the **full long description with NLP**, not
  just exact-match keywords — natural sentences matter more than keyword
  density now. `store_listing.md`'s bullet-point long description already
  reads naturally per section; no change needed there.
- Ranking now also weighs **retention and crash-rate signals** alongside
  keywords — meaning ASO isn't just listing copy anymore, it's also "does
  the app actually hold onto the people search sent it." This is exactly
  why `marketing.md`'s sequencing (fix retention loop before spending on
  acquisition) is doubly correct: it's not just good product sense, it's
  now a ranking factor too.
- **Guided Search** lets a user type a goal ("track my motorcycle rides")
  rather than a keyword — reinforces writing the description around real
  use-cases (which it already does: "RIDE RECORDING", "CRASH DETECTION"
  section headers read as goals, not keyword lists).
- Icon, screenshots, and above-the-fold messaging drive more conversion
  than small metadata tweaks. Assets already exist
  (`store_listing/throttleiq_playstore_icon_512.png`,
  `throttleiq_feature_graphic_1024x500.png`) — **screenshots themselves
  aren't in `store_listing/` yet** (only icon + feature graphic). Adding
  5-8 real device screenshots (not mockups) showing the actual current UI —
  ride-summary card, crash-detection countdown, garage/maintenance screen,
  live group map — is the single highest-conversion addition left to make
  before public launch, per current guidance.

## Concrete suggestions (not applied — for your review before Play Console)

1. **Add screenshots** as described above. Segment-match the order: lead
   with ride-recording/summary (broadest appeal), then maintenance
   (commuter hook), then crash-detection/live-share (family hook), then
   group-map/community (enthusiast hook) — mirrors the message-priority
   order already established per segment in
   `pitch_and_marketing_materials.md`.
2. **Bangla translation** — see `store_listing_bn_addendum.md` in this
   folder, ready to review and paste.
3. **Update the listing once GPS route/track cross-device sync ships**
   (the file's own trailing note says this is now real and safe to
   mention — it currently isn't called out in the bullet list itself).
   Minor, low-priority copy addition, not a correction.
4. **Category** — the file suggests Auto & Vehicles primary, Maps &
   Navigation alternative. Keep Auto & Vehicles: Guided Search and category
   browsing both skew toward "vehicle" framing matching how BD riders
   would search (motorcycle app, bike app) rather than a navigation app.
5. Leave the "under active development" closing line as-is — it's honest
   framing that manages expectations for a solo-built beta, which matters
   for review-score protection (a rider surprised by rough edges after
   being told to expect them rates more forgivingly than one who wasn't).

## Ongoing discipline (2026 guidance: ASO isn't a one-time launch checklist)

Re-check the listing each time a segment-relevant feature ships (next
candidates per the handoff doc's roadmap: curvy-route navigation, club
events) rather than only revisiting before initial submission.
