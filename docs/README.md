# Documentation map

Every project doc that isn't code lives here. If you're picking this project
up cold, read in this order: `planning/HANDOFF_Document.md` (current status) →
`planning/features.md` (what's actually built) → `planning/Issues.md` (why
things are the way they are, when you need the history behind a decision).

**Note:** these docs were reorganized into subfolders (`planning/`,
`guides/`, `architecture/`, `marketing/`) on 2026-08-28 — this map's links
were out of date pointing at the old flat layout until 2026-09-05; fixed
below.

## Living docs — kept up to date every session

| File | What it's for |
|---|---|
| [`planning/HANDOFF_Document.md`](planning/HANDOFF_Document.md) | The single source of truth for project status: what's shipped, what's verified, the pre-launch to-do list, the feature backlog, and the Vehicle State Engine architecture. Update this whenever status changes. |
| [`planning/Issues.md`](planning/Issues.md) | Dated, numbered record of every bug found and fixed. Cited by section (`§N`) from every other doc — treat the numbers as stable references, not just narrative. |
| [`planning/features.md`](planning/features.md) | What a signed-in user can actually do today, organized by the bottom-nav tabs. Regenerate/update whenever screens or flows change. |

## Reference docs — durable, updated when their subject changes

| File | What it's for |
|---|---|
| [`guides/SETUP.md`](guides/SETUP.md) | Local dev setup: Firebase, Cloudinary, Android signing, iOS certificates, build commands. |
| [`architecture/assumptions.md`](architecture/assumptions.md) | Every non-obvious judgement call made without asking, and why — read before questioning why something was scoped a certain way. |
| [`architecture/auto_tracking_plan.md`](architecture/auto_tracking_plan.md) | The background auto-tracking feature's design decisions and implementation status. |
| [`architecture/backend_options.md`](architecture/backend_options.md) | Blaze billing vs. a surgical workaround vs. migrating off Firebase entirely, with a real cost estimate. Answers "why not just leave Firebase." |

## Business & product docs

| File | What it's for |
|---|---|
| [`marketing/pitch_and_marketing_materials.md`](marketing/pitch_and_marketing_materials.md) | The current pitch deck outline and per-segment marketing copy (commuters / enthusiasts / anxious family). Supersedes the old `pitch.md`. |
| [`marketing/marketing.md`](marketing/marketing.md) | The Bangladesh go-to-market plan: channels, phased launch sequence, growth loops, what to track. |
| [`marketing/hooked_throttleiq.md`](marketing/hooked_throttleiq.md) | Retention analysis via the Hooked (Trigger/Action/Variable-Reward/Investment) framework — what keeps a rider opening the app between rides. |
| [`marketing/business_critique.md`](marketing/business_critique.md) | A skeptic's read of the business case, not the product — load-bearing weaknesses to fix before pitching this to anyone. |
| [`marketing/marketing_lead_notes/`](marketing/marketing_lead_notes) | A dated marketing-lead working session's output: campaign copy, ASO notes, outreach templates, a launch calendar, and a `NEEDS_YOUR_ATTENTION.md` of open decisions. Start with that file's own `README.md`. |
| [`planning/uiux_critique.md`](planning/uiux_critique.md) | A screenshot-grounded UI/UX critique, ready to turn into an `Issues.md` punch list if picked up as work. |

## Adjacent, not project docs

- [`extras/`](extras) — standalone HTML design references (the theme style-direction deck, a business card mockup). Not markdown, not kept in sync with the app.
- [`store_listing/`](../store_listing) (repo root) — Play Store listing copy and the Data Safety form answers, kept separate since it's a submission deliverable, not a dev doc.
- [`../README.md`](../README.md) — the repo's front door; keep it accurate but brief, and point here for depth.

## Housekeeping notes

- **`assumptions.md`** was `Assumptions Made.md` and **`auto_tracking_plan.md`** was `AUTO_TRACKING_PLAN.md` until 2026-08-28 — renamed for consistency, content unchanged.
- **`pitch_and_marketing_materials.md`** was untracked as `aaaaa.md`; **`business_critique.md`** was untracked as `dum.md`. Same rename pass.
- `pitch.md` (superseded by `pitch_and_marketing_materials.md`), `WHAT_TO_DO_NOW.md`, `tonight.md`, and `TODO next.md` were deleted 2026-08-28 — all four were dated, self-describing snapshots that said outright they should be deleted once worked through. Anything still relevant from them was folded into `HANDOFF_Document.md` first.
- 2026-08-28's restructure moved every file above into `planning/`, `guides/`, `architecture/`, or `marketing/` but didn't update this map's links to match — fixed 2026-09-05. If you add a new doc, put the path relative to `docs/` here, not the bare filename.
