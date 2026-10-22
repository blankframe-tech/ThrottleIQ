> DRAFT for owner review, 2026-10-22

# Decision card: Firebase Blaze upgrade (owner item #3)

## Summary

`throttleiqfb` runs on Spark, the free plan. On Spark, Cloud Functions cannot deploy at all (the `artifactregistry` API needs Blaze, `issues_open.md` §107.1), and setting a Firestore TTL policy fails with `403: billing disabled` (tried 2026-10-08, §4 and §102). So account deletion, GPS and report retention, chat moderation, TTL clean-up and signed Cloudinary uploads are written but switched off. Blaze has no base fee and bills only above each product's free allowance (`backend_options.md`, Option A). Production uses 1,454-7,166 reads a day, 3-14% of the free 50,000 (`quota-rehearsal-2026-10-21.md`), so the Firestore bill at today's usage would be $0 if the free allowances stay as the repo describes. The costs are a card on file and the chance of an uncapped bill, because a budget alert notifies you but does not stop spending (`SECURITY.md` step 5). There are four options: upgrade now with a budget alert, upgrade later at a set trigger, stay on Spark with workarounds, or leave Firebase.

## What Blaze unblocks (each checked in the repo)

| Item | What is blocked today | Source |
|---|---|---|
| `onUserAccountDeleted` (`functions/src/account-deletion.ts:90`) | Server-side clean-up after in-app deletion: shared rides, follows, chats anonymised, Cloudinary media, `users/{uid}`. Until it runs, deletion means an email and a manual runbook within 30 days, which fails Apple 5.1.1(v) | `functions/README.md`; `SECURITY.md` step 5; `judge.md:99`; `needs_attention.md` "Accounts and security" |
| `purgeOldGpsTracks` (`track-retention.ts:69`) | Deleting GPS track chunks older than 12 months. It also runs `purgeOldReportSnapshots` (`report-retention.ts:53`), which drops report evidence 90 days after review and anonymises a deleted rider's closed reports. Note: `purgeOldReportSnapshots` is a helper inside this function, not a function of its own | `functions/README.md`; `SECURITY.md` steps 6 and 8 |
| `onMessageCreate` (`chat-moderation.ts:24`) | Keyword chat moderation. The keyword list is a known-weak placeholder (§62.5) | `functions/README.md`; `issues_open.md` "Follow-ups" §62 |
| `reconcileRideIdentity` (`ride-identity.ts:81`) | A server fix for impersonation on shared-ride cards | `functions/README.md`; `backend_options.md` "What's actually blocked" |
| `onCrashNotification`, `escalateCrashAlert` | Deployable, but both are mocks: nothing is sent, and crash alerts are off (`crashAlertsEnabled = false`) | `functions/README.md`; `issues_open.md` §78.1 |
| Badge counts on the server (`badge-stats.ts`, not exported) | The Blaze version of the client-written `stats/badges` | `functions/src/index.ts` comment; `issues_open.md` "Follow-ups" §62.2 |
| Firestore TTL on `liveSessions.expiresAt` | Expired live sessions are never reaped | `issues_open.md` "Follow-ups" §4, §102 |
| Firestore TTL on `places.expiresAt` | Expired cop checkpoints stay in Firestore; the client only hides them | `issues_open.md` §107.4 |
| Signed Cloudinary uploads | The unsigned preset `throttleiq_unsigned` lets anyone upload. The fix is a callable function that signs uploads | `SECURITY.md` step 7; `backend_options.md` (§33.5) |
| Rate limits | No write throttling on shares, posts, chats, reviews or reports. Needs Functions or per-user counter docs in the rules | `issues_open.md` §62.12 |
| Real SMS and crash escalation | Needs Blaze, an SMS provider and calibrated detection | `needs_attention.md` "Decisions"; HANDOFF ideas list |
| Server-side feed blocking | Rules cannot filter a list query, so filtering blocked riders out of the feed needs a server edge (Blaze) or `not-in` | `issues_open.md` §107.3 (§83.18) |
| Maya partner API (`mayabi` branch) | `partnerApi` and `onRoadSpeedSampleCreated` deploy after Blaze. | Owner page, Maya pilot and Blaze items |
| Firestore backups | "No backups on Spark", which is why the Google import has no pre-import snapshot. [PLACEHOLDER: which backup or PITR feature Blaze enables, and its price] | `scripts/oneoff/revert_google_places.js` header |
| Hard daily quota | Blaze removes the Spark ceiling and bills the overage instead | `backend_options.md` Option A; owner page Blaze item |

## Cost figures in the repo

Rates are from `backend_options.md` (written 2026-08-23, marked "approximate — verify current rates"):

| | Free per day | Above free |
|---|---|---|
| Reads | 50,000 | $0.06 per 100K (so $0.60 per million) |
| Writes | 20,000 | $0.18 per 100K |
| Deletes | 20,000 | $0.02 per 100K |
| Storage | 1 GiB | $0.18 per GiB per month |
| Egress | 10 GiB a month | about $0.12 per GiB |

- **Cloud Functions:** 2,000,000 invocations a month free, which the doc calls "effectively $0" at its modelled volume.
- **Auth and Hosting:** effectively $0, because there is no phone auth (`backend_options.md`).
- **Not priced anywhere in the repo:** [PLACEHOLDER: Artifact Registry storage for function images], [PLACEHOLDER: Cloud Build minutes for function deploys], [PLACEHOLDER: Cloud Scheduler jobs for `purgeOldGpsTracks` and `escalateCrashAlert`], [PLACEHOLDER: Secret Manager for `CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET`]. [PLACEHOLDER: confirm Blaze keeps the same free allowances as Spark, from the current Google pricing page].

Volumes, from the repo:

- **Today (production, 7 days to 2026-10-21):** 1,454-7,166 reads, 57-881 writes and at most 13 deletes a day, all under the free allowance (`quota-rehearsal-2026-10-21.md`).
- **Worst single activity measured:** a 20-rider group ride for 1 hour uses 75,600 reads. At the rates above, the 25,600 reads beyond the free allowance cost about $0.015 (`load-test-2026-10-15.md`).
- **10K daily users:** `backend_options.md` estimates $20-30 a month, but it assumes about 85 reads per user per day. The later load test measured about 2,700 reads per rider-day (about 640 without the places refetch, which the 104.1 fix removes but which is not released yet). At 640 the same rates give about 6.4M reads a day, or roughly $115 a month for reads alone. That is my arithmetic on repo figures, not a quote, so treat the doc's $20-30 as likely low.

## Options

| Option | What happens | Cost | Risk | Reversible? |
|---|---|---|---|---|
| **1. Upgrade now with a budget alert** | Upgrade in the console, create a budget in GCP Billing the same day, then deploy one function at a time, `onUserAccountDeleted` first (`SECURITY.md` step 5; owner page). Then set the TTL policies, then `purgeOldGpsTracks` after `privacy.html` is updated (step 6), then signed uploads (step 7). | $0 base. Firestore at today's usage: $0. Function infrastructure: see the placeholders above. Budget: `SECURITY.md` suggests $5, `backend_options.md` suggests $25 and $50. About 15 min to upgrade (owner page). | **Runaway bill:** alerts do not cap spending (`SECURITY.md` step 5). There are no rate limits, and App Check is not enforced (§62.12), so a scripted client could run up reads. **Card on file** (owner page). **Deploy mistakes:** a bare `--only functions` would put the crash and keyword functions live (`functions/README.md`), and the Cloudinary `<kind>/<uid>/` prefix must be confirmed before deploying, or the deletion sweep skips every asset (`needs_attention.md` #11). | Mostly. [PLACEHOLDER: whether and how a project can go back from Blaze to Spark, and what happens to deployed functions]. Deployed functions can be deleted. |
| **2. Upgrade later, at a set trigger** | Stay on Spark and keep answering deletion requests by hand. Upgrade when the first of these happens: an App Store submission (Apple 5.1.1(v), `judge.md:99`), a go-ahead for the `mayabi` partner API, or the 80% quota alert firing (`features.md` quota outage mode). | $0 until the trigger. Owner time on manual deletions in the meantime. | The same risks as Option 1, just later. Until then: deletion stays manual (30-day duty), TTL stays off, and uploads stay unsigned. Riders hit a hard quota at about 18 daily active riders under the old places code (`load-test-2026-10-15.md`), fewer since the import made places reads about 2.4x larger. | Yes. Nothing changes until the trigger. |
| **3. Stay on Spark with workarounds** | Build the Spark versions. Deletion: the app writes `deletionRequests/{uid}` and the owner runs a weekly Admin SDK script (`issues_open.md` §109.12). TTL: filter on `expiresAt > now` and have clients delete their own expired docs (§102). Signed uploads and server jobs: a small Cloudflare Workers or Vercel service holding an Admin SDK key (`backend_options.md` Option B, §107.3). Rate limits: per-user counter docs in the rules (§62.12). Reads: ship the 104.1 cache and fix §104.2-104.4. | $0 in fees. Agent time: "a few days" for the edge service (`backend_options.md` Option B), plus the §109.12 and §102 work. Owner time for the weekly deletion run. | Two platforms to run, and polling instead of triggers (`backend_options.md`). A new vendor holds an Admin key. The hard read quota stays. The Maya API stays blocked (owner page). Whether the weekly-script deletion satisfies Apple 5.1.1(v) is [PLACEHOLDER: not confirmed in the repo]. | Yes. You can move to Blaze later, though the workaround code would then be wasted. |
| **4. Leave Firebase (for example Supabase)** | Redesign the data model, rewrite the ~2,300-line `firestore.rules` (backend_options.md still says ~1,500; stale) as Postgres row-level security, rewrite the client repositories, and build a new rules test harness (`backend_options.md` Option C). | "Weeks, dedicated project" (`backend_options.md`). Free tier at first, with its own costs later. | High: every past rules fix (§3, §10, §24, §33) must be re-checked by hand. It also delays every other item. | Expensive to undo. |

## Recommendation

**Option 1: upgrade now, set a budget alert the same day, and deploy only `onUserAccountDeleted` at first.** Reasons, from the repo:

1. Today's usage is 3-14% of the free reads, so the likely Firestore bill is $0. `backend_options.md`, `SECURITY.md` and the owner page's docs view all recommend Blaze with an alert.
2. It closes the open Apple 5.1.1(v) gap and the 30-day manual deletion duty, and it unblocks TTL, retention and signed uploads, all already written and emulator-tested (`functions/README.md`).
3. Options 3 and 4 cost days to weeks of work to avoid a bill that is $0 at today's usage.

Before the upgrade, keep the protection against a runaway bill:

- Create budget alerts. `SECURITY.md` suggests $5; `backend_options.md` suggests $25 and $50. Use the $5 one as a canary.
- Keep the existing Cloud Monitoring alert at 80% of daily reads, writes and deletes (`scripts/monitoring/firestore-quota-alert.yaml`). It measures usage counts, so it should still warn at the old free-tier levels [PLACEHOLDER: confirm after the upgrade].
- Ask whether a hard cap is possible: [PLACEHOLDER: whether Google Cloud lets you cap Firestore or Functions usage on Blaze (quota limits or an automatic billing shut-off), and how].
- Follow the abuse fixes already planned: App Check enforcement (#17, after a release that sends tokens), rate limits (§62.12) and the Cloudinary size cap (#11).

If you will not put a card on a Google account, take Option 2 and use the App Store submission as the trigger. Option 3 is only worth it if Option 2's trigger is far off and the manual deletion duty becomes a burden.

## Node runtime note

`needs_attention.md:76-77` (not the HANDOFF) says Cloud Functions' Node 20 runtime is decommissioned in late October 2026. `functions/` already targets Node 22 (`functions/package.json` `engines`, `firebase.json`, `functions/README.md`). Nothing is deployed, so nothing breaks at that date. Any first deploy uses Node 22. [PLACEHOLDER: Google's exact Node 20 decommission date and any Node 22 end date]. Also, `onUserAccountDeleted` stays on 1st-gen (v1) because v2 has no after-the-fact auth delete trigger (`functions/README.md`). [PLACEHOLDER: whether Google has announced a deadline for 1st-gen functions].

## Owner sign-off question

> "Do you approve upgrading `throttleiqfb` to Blaze now, with a GCP budget alert at $[5 / 25 / 50] created the same day, and then deploying only `onUserAccountDeleted` (after setting the two Cloudinary secrets and confirming the upload prefix)? Or do you want to wait until a trigger (App Store submission, a go-ahead for the `mayabi` partner API, or the 80% quota alert), or stay on Spark and have agents build the workarounds?"

## Follow-ups after the decision

| Step | Who |
|---|---|
| Upgrade, then create the budget alert in GCP Billing | Owner |
| Confirm Cloudinary public IDs keep the `<kind>/<uid>/` prefix (`needs_attention.md` #11) | Owner, with an Architect agent checking `cloudinary-ownership.ts` |
| `firebase functions:secrets:set CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET`, then `firebase deploy --only functions:onUserAccountDeleted --project throttleiqfb`, then delete a test account and check `accountDeletions/{uid}` shows `ok: true` (`SECURITY.md` step 5) | Owner |
| Set the TTL policies on `liveSessions.expiresAt` and `places.expiresAt` | Owner (console), with an Operations Manager agent writing the steps |
| Update `privacy.html` for 12-month GPS retention, then deploy `purgeOldGpsTracks` (`SECURITY.md` steps 6 and 8) | Architect agent (text), owner (deploy) |
| Signed-upload build: callable function, app change, then switch the preset to signed only after riders have that build (`SECURITY.md` step 7) | Architect agent |
| Update `privacy.html` deletion text, `needs_attention.md`, HANDOFF "Decisions in force" and `judge.md` gap 4 | Product Manager or docs agent |
| If Option 2 or 3: write the trigger into `needs_attention.md`; for Option 3, scope §109.12, §102 fallbacks and the `backend_options.md` Option B service | Chief of Staff / Architect agent |

## Where the room file and briefing disagree with the repo

- **"Free-tier allowances identical to Spark."** The room claims this. `backend_options.md` says each product keeps its free allowance on Blaze, but the repo does not show they are identical, and deploying functions adds Artifact Registry (§107.1) and other services the repo never prices.
- **Incomplete blocked list.** The room lists four blocked items. The repo also blocks chat moderation, ride-identity reconciliation, GPS and report retention, rate limits, server-side feed blocking, the Maya partner API and backups (table above).
- **Briefing names.** The briefing mentions "chatModeration" and "purgeOldReportSnapshots" as functions. The deployed name is `onMessageCreate` (in `chat-moderation.ts`), and `purgeOldReportSnapshots` is a helper run inside `purgeOldGpsTracks`. The Node 22 deadline is in `needs_attention.md`, not the HANDOFF.
- **`backend_options.md` is out of date in three places.** It says "Spark refuses writes past the free tier", but the 2026-10-21 rehearsal found writes past the limit are queued or accepted, never rejected, and reads were served 8 minutes past the limit. Its cost model of about 85 reads per user per day is far below the load test's 640-2,700. It also says "both existing functions", while there are now six exports.
- **HANDOFF vs `issues_fixed.md`.** HANDOFF "Start here" still lists §104.1 as open, but `issues_fixed.md` §104.1 says it was fixed on 2026-10-22 (not released).

## Sources

- `DOCS/For Devs and Contributors/architecture/backend_options.md` (all sections)
- `SECURITY.md` steps 5-8
- `functions/README.md`; `functions/src/index.ts`; `functions/src/account-deletion.ts:90`, `track-retention.ts:69,75`, `report-retention.ts:53`, `chat-moderation.ts:24`, `ride-identity.ts:81`; `functions/package.json`
- `DOCS/Handoff for agents and Todos/needs_attention.md` "Decisions" (`:71-77`), "Accounts and security", "Release and deploy"
- `DOCS/Handoff for agents and Todos/issues_open.md` "Follow-ups" (§4, §62), §69 "Deploy needed", §78.1, §62.12, §102, §104, §107.1, §107.3, §107.4, §109.12
- `DOCS/Handoff for agents and Todos/issues_fixed.md` §104.1
- `DOCS/Handoff for agents and Todos/HANDOFF_Document.md` "Decisions in force", "Start here"
- `DOCS/Handoff for agents and Todos/features.md` "Firestore quota outage mode"
- `DOCS/Handoff for agents and Todos/load_test/load-test-2026-10-15.md`, `quota-rehearsal-2026-10-21.md`
- `judge.md:96-110` (gaps and next steps)
- `scripts/oneoff/revert_google_places.js` header (no backups on Spark)
- `DOCS/agent_rooms/chief_of_staff_todo.md` item 2
- Owner page `~/Everything/dev/housekeeping/owner_works_now.html`: Blaze and Maya pilot items (outside the repo)
