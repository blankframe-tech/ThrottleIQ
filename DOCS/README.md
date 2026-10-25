# Documentation map

Every project doc that isn't code lives here, sorted by who reads it.
Folder names contain spaces, so links URL-encode them (`%20`).

**New here?** Read in this order:
[`HANDOFF_Document.md`](Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md)
(current status) →
[`features.md`](Handoff%20for%20agents%20and%20Todos/features.md) (what is
built) →
[`issues_open.md`](Handoff%20for%20agents%20and%20Todos/issues_open.md) (what
is still broken or undecided). What only the founder can close (accounts,
money, devices, decisions) is in
[`needs_attention.md`](Handoff%20for%20agents%20and%20Todos/needs_attention.md).

**Layout (2026-10-22):** six folders.

| Folder | For |
|---|---|
| [`agent_rooms/`](agent_rooms) | Autonomous and collaborating agent action hubs: specific todos for Architect, PM, Operations Manager, Chief of Staff, and QA. |
| [`Handoff for agents and Todos/`](Handoff%20for%20agents%20and%20Todos) | Coding agents and contributors: status, features, open and fixed issues, owner to-dos. Five living files, nothing else. |
| [`Handoffs for Non Coding Agents/`](Handoffs%20for%20Non%20Coding%20Agents) | Marketing, pitch, posters and social art. |
| [`For Devs and Contributors/`](For%20Devs%20and%20Contributors) | Architecture, how-to guides, load-test reports. |
| [`General/`](General) | Store files (listing, data safety, moderation policy) and the crash-test evidence. |
| [`old/`](old) | Frozen history. Not maintained; don't cite it as current. |

## Agent Rooms

Task assignments and role-bounded action hubs for autonomous and collaborating agents:

| File | What it's for |
|---|---|
| [`agent_rooms/README.md`](agent_rooms/README.md) | Agent directory, roster, communication protocol, and status index. |
| [`agent_rooms/architect_todo.md`](agent_rooms/architect_todo.md) | Principal Software Architect: Firestore reads optimization, rules/indexes, Cloud Functions migration, and sensor telemetry. |
| [`agent_rooms/product_manager_todo.md`](agent_rooms/product_manager_todo.md) | Product Manager: PRD metrics, store listings, forum ideas, and B2B pilot definitions. |
| [`agent_rooms/operations_manager_todo.md`](agent_rooms/operations_manager_todo.md) | Operations Manager: Security execution, Data Safety forms, runbooks, release governance, and localization review. |
| [`agent_rooms/chief_of_staff_todo.md`](agent_rooms/chief_of_staff_todo.md) | Chief of Staff: Executive owner decision triage, real-bike/hardware test scheduling, and cross-agent alignment. |
| [`agent_rooms/qa_engineer_todo.md`](agent_rooms/qa_engineer_todo.md) | QA Specialist: Automated test suite maintenance, emulator E2E suites, and manual physical device verification protocols. |

## Handoff for agents and Todos

Update these in the same session as the change they describe.

| File | What it's for |
|---|---|
| [`HANDOFF_Document.md`](Handoff%20for%20agents%20and%20Todos/HANDOFF_Document.md) | Current status: branches, what is released and deployed, what has never run on a real phone, key facts, and a dated log of recent sessions (newest first). |
| [`features.md`](Handoff%20for%20agents%20and%20Todos/features.md) | What a signed-in rider can do today, by bottom-nav tab, with the known gaps. |
| [`issues_open.md`](Handoff%20for%20agents%20and%20Todos/issues_open.md) | Every open issue in its numbered section. New issues go at the end with the next free number (the file's header tracks it). |
| [`issues_fixed.md`](Handoff%20for%20agents%20and%20Todos/issues_fixed.md) | The record of every resolved issue: root cause, fix, verification. When an issue is fixed, its section moves here and keeps its number. |
| [`needs_attention.md`](Handoff%20for%20agents%20and%20Todos/needs_attention.md) | Items only the founder can close. The full owner list, with steps, is `~/Everything/dev/housekeeping/owner_works_now.html` (outside the repo). |

## Handoffs for Non Coding Agents

| Path | What it's for |
|---|---|
| [`marketing/marketing.md`](Handoffs%20for%20Non%20Coding%20Agents/marketing/marketing.md) | Bangladesh go-to-market strategy: segments and copy, channels, growth loops, retention, what to track, honest risks, name candidates. |
| [`marketing/marketing_kit.md`](Handoffs%20for%20Non%20Coding%20Agents/marketing/marketing_kit.md) | Ready-to-use copy: outreach templates, captions, FAQ, press fact sheet, tester onboarding message, Play shot list, launch calendar. |
| [`marketing/pitch_deck.md`](Handoffs%20for%20Non%20Coding%20Agents/marketing/pitch_deck.md) | Pitch deck outline. |
| [`marketing/iDEA_PITCH_SUBMISSION.md`](Handoffs%20for%20Non%20Coding%20Agents/marketing/iDEA_PITCH_SUBMISSION.md) | The iDEA government-grant submission (used by the `idea-pitch` skill). |
| [`posters/`](Handoffs%20for%20Non%20Coding%20Agents/posters) | `batch_one/`: the 61 numbered posters as made. `batch_two/`: the posters that used an old colour scheme, redone in the current brand (same numbers). How they are made and the colour mapping: [`generator_helper_files/README.md`](Handoffs%20for%20Non%20Coding%20Agents/posters/generator_helper_files/README.md). |
| [`social/facebook/`](Handoffs%20for%20Non%20Coding%20Agents/social/facebook) | Facebook page cover (`cover.html` is the source of `cover_photo.png`). |

## For Devs and Contributors

| Path | What it's for |
|---|---|
| [`architecture/arch.md`](For%20Devs%20and%20Contributors/architecture/arch.md) | System architecture: layers, the telemetry pipeline, offline-first sync, safety invariants. |
| [`architecture/PRD.md`](For%20Devs%20and%20Contributors/architecture/PRD.md) | Product requirements, in Simplified Technical English. |
| [`architecture/assumptions.md`](For%20Devs%20and%20Contributors/architecture/assumptions.md) | Judgement calls made without asking, and why. |
| [`architecture/auto_tracking_plan.md`](For%20Devs%20and%20Contributors/architecture/auto_tracking_plan.md) | Background auto-tracking design and status. |
| [`architecture/backend_options.md`](For%20Devs%20and%20Contributors/architecture/backend_options.md) | Blaze billing vs a workaround vs leaving Firebase, with costs. |
| [`architecture/phone_vs_cloud_data.md`](For%20Devs%20and%20Contributors/architecture/phone_vs_cloud_data.md) | What the phone stores vs what the cloud stores, and the gaps. |
| [`architecture/realtime-database.md`](For%20Devs%20and%20Contributors/architecture/realtime-database.md) | The parked Realtime Database design (no RTDB access on `main`). |
| [`architecture/indriyo_ideas.md`](For%20Devs%20and%20Contributors/architecture/indriyo_ideas.md) | Indriyo (in `main`, off unless built with `INDRIYO=true`): ideas not built yet, starting with on-device object detection on the mirror feed. |
| [`guides/SETUP.md`](For%20Devs%20and%20Contributors/guides/SETUP.md) | Local setup: Firebase, Cloudinary, signing, build commands. |
| [`guides/account_deletion_runbook.md`](For%20Devs%20and%20Contributors/guides/account_deletion_runbook.md) | How to delete a rider's account and data by hand. |
| [`guides/app_check.md`](For%20Devs%20and%20Contributors/guides/app_check.md) | App Check setup and enforcement runbook. |
| [`guides/ThrottleIQ_Maya_Ride_Integration_Guide.pdf`](For%20Devs%20and%20Contributors/guides/ThrottleIQ_Maya_Ride_Integration_Guide.pdf) | For Maya Ride (2026-10-25): integrating the `mayabi/` kit, hosted API vs self-hosting, Blaze cost estimate, permission to reuse this branch. |
| [`load_test/`](For%20Devs%20and%20Contributors/load_test) | Spark-quota load test (2026-10-15) and the quota outage rehearsal (2026-10-21). |

Package READMEs live next to the code: `app/README.md`, `functions/README.md`,
`scripts/README.md`, `public/README.md`, and others under `app/lib/` and
`app/test/`.

## General

| Path | What it's for |
|---|---|
| [`Files for Stores/store_listing/`](General/Files%20for%20Stores/store_listing) | Play listing copy (EN and the Bangla addendum), Data Safety answers (`data_safety_and_permissions.md` and the importable CSV), remaining App Content forms, store graphics. Must match `public/privacy.html`. |
| [`Files for Stores/moderation_policy.md`](General/Files%20for%20Stores/moderation_policy.md) | Moderation policy: report handling, review times, retention. |
| [`CRASH TESTING/`](General/CRASH%20TESTING) | The 2026-10-14 real crash: analysis, detection plan, log extract, screenshots. The raw GPS track and phone database stay off git (`.gitignore`). |
| `partnerships/` | Local only, never tracked (`.git/info/exclude`): partner strategy and pricing. |

## old/ (frozen)

`apify/` (scrape notes and the 2026-10-21 Facebook bike-group research),
`background_geolocation/` (the abandoned paid-plugin experiment),
`ui_stuff/` (old theme mockups and Calming light screenshots, used as
poster sources), `website_demo/` (the September marketing-site demo; its
claims are out of date).

## Labels in code comments

Comments cite section labels, never file paths: paths move, numbers don't.

| In a comment | Where to read it |
|---|---|
| `issues §N` | Section `N` of [`issues_fixed.md`](Handoff%20for%20agents%20and%20Todos/issues_fixed.md) if resolved, else [`issues_open.md`](Handoff%20for%20agents%20and%20Todos/issues_open.md). A section partly fixed appears in both. |
| `grill §N` | The 2026-09-20 Antigravity grill verification, retired 2026-10-22: `git show 3ebbd21d:"DOCS/Handoff for agents and Todos/grillings/claude_sol.md"`. Resolved parts are in issues §78; leftovers in issues §108. |
| `CrtiQue_Oct14 B7`, `CrtiQue_Oct15 N3` | The 2026-10-14/15 critiques, retired 2026-10-22: `git show 3ebbd21d:"DOCS/Handoff for agents and Todos/CrtiQue_Oct14.md"` (or `CrtiQue_Oct15.md`). Leftovers in issues §109. |

Other notes retired on 2026-10-22 (`BIGGG_JOBB.md`, `DEBT_FIX_PLAN.md`,
`uiux_critique.md`, `websockets_todo.md`, `plan_ride_minimize_menu.md`,
`todo_now_antigravity.md`; leftovers in issues §107) and the old marketing
notes (merged into `marketing.md` and `marketing_kit.md`) can be read the
same way at `3ebbd21d`.

Do not write a file path into a new code comment. Write `issues §N`.

## Adding a doc

Put it in the folder for its reader, add a row here, and link it with a path
relative to the linking file. Prefer extending an existing doc over a new
file.
