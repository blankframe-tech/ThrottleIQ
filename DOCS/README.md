# Documentation map

Every project doc that isn't code lives here. If you're picking this project
up cold, read in this order:
[`HANDOFF_Document.md`](Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md)
(current status) →
[`features.md`](Handoff%20for%20agents%20and%20Todos/features.md) (what's
actually built) →
[`issues_open.md`](Handoff%20for%20agents%20and%20Todos/issues_open.md) (what's still broken or
undecided). For the history behind a decision, see
[`issues_fixed.md`](Handoff%20for%20agents%20and%20Todos/issues_fixed.md).

**Layout (2026-09-19):** the old lower-case `docs/` tree, plus the root-level
`designs/`, `store_listing/`, `gov-pitch/`, `website_demo/` and `screenshots/`
folders, were consolidated into three audience folders:

| Folder | For |
|---|---|
| `Handoff for agents and Todos/` | Living status, the bug record, the feature list, and working to-do/critique notes. The folder an agent or new contributor opens first. |
| `For Devs and Contributors/` | Setup guide, architecture decisions, archived experiments. |
| `General/` | Business, marketing, store listing, design references, website demo. |

## Ticket references in source comments

Source comments cite two different numbering schemes. Both were normalised on
2026-09-20 (issues_open.md §83.29) so that neither names a file path — paths
move, section numbers don't.

| In a comment | Means |
|---|---|
| `issues §N` | Section `## N.` of [`issues_fixed.md`](Handoff%20for%20agents%20and%20Todos/issues_fixed.md) if resolved, else [`issues_open.md`](Handoff%20for%20agents%20and%20Todos/issues_open.md). Look in `issues_fixed.md` first; if it isn't there, or the section says part of it is still open, check `issues_open.md`. |
| `grill §N` | The 2026-09-20 external-critique verification pass, originally written up in `ANTIGRAVRITY_GRILL/claude_sol.md`. **That file is no longer in the repo** — it was deleted in commit `fc11e99`; recover it with `git show fc11e99^:"ANTIGRAVRITY_GRILL/claude_sol.md"`. The surviving in-repo record is issues §78. |

Do not write a file path into a new code comment — write `issues §N`. Three
earlier conventions all rotted: `docs/Issues.md §N` (the `docs/` tree was
renamed `DOCS/` and `Issues.md` was split on 2026-09-19), `claude_sol.md §N`
(deleted), and a 78-character `DOCS/Handoff for agents and Todos/issues_open.md
or issues_fixed.md §N` that appeared in 28 files and could not decide which of
the two files it meant.

## Start here if you are picking up the active work

[`BIGGG_JOBB.md`](BIGGG_JOBB.md) — the 2026-09-21 handoff: current state, the
four verification gates, the founder's settled decisions, the ordered work
queue, and a **traps** section of failures actually hit (do not run
`dart format` across `lib/`; section numbers collide; `--force` would drop
live indexes). Read it before `HANDOFF_Document.md` if you are here to write
code rather than to check status.

## Living docs, kept up to date every session

| File | What it's for |
|---|---|
| [`HANDOFF_Document.md`](Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md) | The single source of truth for project status: what's shipped, what's verified, the pre-launch to-do list, the feature backlog, and the Vehicle State Engine architecture. Update it whenever status changes. |
| [`issues_open.md`](Handoff%20for%20agents%20and%20Todos/issues_open.md) | Every unresolved issue, plus follow-ups left over from fixed ones. New issues go here with the next free number — see that file's own header, which tracks it. Once fixed, a section moves to `issues_fixed.md` and keeps its number. |
| [`issues_fixed.md`](Handoff%20for%20agents%20and%20Todos/issues_fixed.md) | The dated, numbered record of every resolved issue (§1–§69): root causes, fixes, verification. Other docs cite it by section (`§N`), so the numbers are stable. The latest full-repo review is §69. |
| [`features.md`](Handoff%20for%20agents%20and%20Todos/features.md) | What a signed-in user can actually do today, organized by the bottom-nav tabs. Update it whenever screens or flows change. |

## Working notes (dated snapshots, not kept current)

| File | What it's for |
|---|---|
| [`optimizerplan.md`](Handoff%20for%20agents%20and%20Todos/optimizerplan.md) | 2026-09-03 prioritized performance/reliability plan (written at `1.0.0-beta.1+5`). Check each item against `issues_open.md` before acting on it. |
| [`uiux_critique.md`](Handoff%20for%20agents%20and%20Todos/uiux_critique.md) | A screenshot-grounded UI/UX critique, ready to turn into an `issues_open.md` punch list. |
| [`todo_now_antigravity.md`](Handoff%20for%20agents%20and%20Todos/todo_now_antigravity.md) | Trust & Safety / messaging task checklist from another agent's session. |
| `SKILLS/` | Third-party mobile-design skill files kept for reference (formerly `NEWORKS/`). Their internal links point at sibling files from their original package that were never copied here. |
| `bugs/` | Local bug-report screenshots. Gitignored on purpose. |

## For devs and contributors

| File | What it's for |
|---|---|
| [`../arch.md`](../arch.md) | High-level system architecture: layers, state estimation pipeline, offline-first sync, safety invariants. |
| [`guides/SETUP.md`](For%20Devs%20and%20Contributers/guides/SETUP.md) | Local dev setup: Firebase, Cloudinary, Android signing, iOS certificates, build commands. |
| [`architecture/assumptions.md`](For%20Devs%20and%20Contributers/architecture/assumptions.md) | Every non-obvious judgement call made without asking, and why. |
| [`architecture/auto_tracking_plan.md`](For%20Devs%20and%20Contributers/architecture/auto_tracking_plan.md) | Background auto-tracking design decisions and implementation status. |
| [`architecture/backend_options.md`](For%20Devs%20and%20Contributers/architecture/backend_options.md) | Blaze billing vs. a surgical workaround vs. leaving Firebase, with a cost estimate. |
| [`archives/`](For%20Devs%20and%20Contributers/archives) | Abandoned approaches kept for reference (the `flutter_background_geolocation` experiment, early logo concepts). |

Package-level READMEs live next to the code: `app/README.md`,
`app/lib/**/README.md`, `app/test/**/README.md`, `functions/README.md`,
`scripts/README.md`, `public/README.md`.

## General: business, store, design

| Path | What it's for |
|---|---|
| [`store_listing/`](General/store_listing) | Play Store listing copy, the Data Safety form answers (`data_safety_and_permissions.md` plus the importable `throttleiq_data_safety.csv`), and store graphics. Must stay consistent with `public/privacy.html`. |
| [`marketing/pitch_and_marketing_materials.md`](General/marketing/pitch_and_marketing_materials.md) | Pitch deck outline and per-segment marketing copy. |
| [`marketing/marketing.md`](General/marketing/marketing.md) | Bangladesh go-to-market plan: channels, phased launch, growth loops, what to track. |
| [`marketing/hooked_throttleiq.md`](General/marketing/hooked_throttleiq.md) | Retention analysis via the Hooked framework. |
| [`marketing/business_critique.md`](General/marketing/business_critique.md) | A skeptic's read of the business case. |
| [`marketing/marketing_lead_notes/`](General/marketing/marketing_lead_notes) | A marketing-lead working session: campaign copy, ASO notes, outreach templates, launch calendar. Start with its `NEEDS_YOUR_ATTENTION.md`. |
| [`marketing/gov-pitch/`](General/marketing/gov-pitch) | The iDEA government-grant submission (deck, video script, defense FAQ). |
| `designs/`, `website_demo/`, `*.html` | Standalone HTML design references (theme style directions, Carbon Mono / Editorial BW mockups, business card) and the marketing-site demo. Not kept in sync with the app. |

## Housekeeping

- If you add a doc, put it in one of the three folders above and add a row
  here with a path relative to `DOCS/`. Folder names contain spaces, so
  URL-encode them in links (`%20`).
- The 2026-08-28 renames (`Assumptions Made.md` → `assumptions.md`,
  `AUTO_TRACKING_PLAN.md` → `auto_tracking_plan.md`, `aaaaa.md` →
  `pitch_and_marketing_materials.md`, `dum.md` → `business_critique.md`)
  still apply. The deleted `pitch.md`, `WHAT_TO_DO_NOW.md`, `tonight.md` and
  `TODO next.md` were folded into `HANDOFF_Document.md` first.
