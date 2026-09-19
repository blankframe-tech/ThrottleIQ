# Weekly growth tracking log

A fillable version of `marketing.md` §7 ("what to track") — that section
described the metrics but didn't leave anywhere to actually record them
week over week. Copy a new row each week; don't retrofit history you don't
have, just start from whichever week you begin filling this in.

**Why weekly, not daily:** DAU is noisy at low volume for the first 2-3
months and will discourage you if it's the only number you watch
(`marketing.md` §7). Pull these numbers from Play Console's own stats
(installs, retention cohorts) — no analytics pipeline needs to be built for
this.

| Week of | Installs (new) | Day-7 retained % | Day-30 retained % | Logged ≥1 ride in first session? | Live-share clicks → installs | Top attribution channel | Notes |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
| | | | | | | | |
| | | | | | | | |

**Column notes:**
- **Day-7 / Day-30 retained %** — from Play Console's cohort retention
  chart, not a custom calculation.
- **Logged ≥1 ride in first session?** — the real "aha moment" per
  `hooked_throttleiq.md`; track what fraction of new installs did this,
  it's a stronger predictor of Day-30 retention than the install number
  itself.
- **Live-share clicks → installs** — only fillable once
  `public/live-viewer.html`'s CTA has real traffic; this single number
  tells you whether that acquisition loop is actually converting.
- **Top attribution channel** — once the "how did you hear about us" field
  ships (spec in `outreach_templates.md` §6), fill this from that data;
  until then, leave blank rather than guess.

**Review cadence:** read this log back before deciding to add a new
channel or spend on anything paid — `marketing.md` §5 Phase 3 is explicit
that if DAU is short of target, the fix is almost always retention (check
the Day-7/Day-30 columns first), not another acquisition channel.
