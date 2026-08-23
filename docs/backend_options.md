# Backend options: Blaze billing vs. migrating off Firebase

Written 2026-08-23. Answers a direct question raised after the §33 security/
bug sweep: Cloud Functions cannot deploy at all on this project's current
Firebase plan (Spark/free) — confirmed in `Issues.md` §24 and blocking two of
§33's findings (§33.5 Cloudinary signed uploads, half of §33.6 storage-rules
audience mirroring) — so what are the actual alternatives to turning on
Blaze billing? This is a decision doc, not a plan: nothing here has been
built. See `HANDOFF_Document.md`'s "Soon (requires Blaze pay-as-you-go
plan...)" section for where this was already flagged as a known blocker.

**Bottom line: enable Blaze.** It's pay-as-you-go with no base fee, the
realistic bill at beta scale is single-digit-to-low-double-digit dollars a
month (see the estimate below), and every alternative means giving up
work that's already done and audited — most of all the 960-line
`firestore.rules` file, which has had real, specific vulnerabilities found
and closed across `Issues.md` §3, §10, §24, and §33. Migrating backends
means re-deriving all of that from scratch in a different rules language,
with no guarantee of catching the same bugs a second time.

---

## What's actually blocked right now

- `functions/src/crash-notifications.ts` — the crash-alert escalation timer
  (pending → contacted → escalated) is fully written but is a documented
  mock; it has never run against a real deploy.
- `functions/src/ride-identity.ts` — server-side reconciliation of
  `userName`/`userPhotoUrl` on shared-ride feed cards, closing an
  impersonation gap Firestore rules alone can't (a rider renaming themselves
  after sharing a ride would otherwise leave old feed cards showing the old
  name/photo forever).
- `Issues.md` §33.5 — Cloudinary's upload preset is unsigned (anyone who
  extracts the cloud name/preset from the APK can POST to it directly,
  unbounded). Closing it properly means a Cloud Function that mints a
  signed upload signature per request.
- `Issues.md` §33.6 (half) — `storage.rules` could mirror a ride's
  `public`/`followers`/`mutual` audience via `firestore.get()` the same way
  `firestore.rules`' `rideVisibleTo()` does, but that's moot until Storage
  itself is turned on, which (per `firebase.json` having no `"storage"` key)
  hasn't happened yet either — also gated on the same billing question,
  since Storage's own free tier historically required a card on file the
  same way Functions does now.

All four are real, but none are urgent-urgent: the app functions without
them today (uploads work, just less securely; feed impersonation after a
rename is a cosmetic bug; crash escalation is mocked, not silently broken —
it was never claimed to work).

---

## Option A — Enable Blaze (recommended)

Blaze has **no monthly base fee**. "The bill" is 100% usage-based, and every
Firebase product has its own free-tier allotment that resets daily/monthly
regardless of being on Blaze — Blaze just removes the *hard cap* that Spark
enforces (Spark refuses writes past the free tier; Blaze just starts
charging for the overage).

### Cost estimate at 10,000 DAU

No usage analytics exist in this app yet (nothing tracks real reads/writes
per session), so this is a model calibrated by reading the actual code
paths — not a quote, and it should be re-derived from real Blaze usage data
after a week or two live. Firestore is the only line item likely to matter;
Cloud Functions, Hosting, and Auth all stay near-zero at this scale (see
below).

**Firestore pricing** (Standard edition, approximate — verify current rates
on Firebase's pricing page before budgeting):

| Operation | Free tier (per project/day) | Rate beyond free |
|---|---|---|
| Reads | 50,000/day | $0.06 / 100K |
| Writes | 20,000/day | $0.18 / 100K |
| Deletes | 20,000/day | $0.02 / 100K |
| Stored data | 1 GiB | $0.18 / GiB / month |
| Network egress | 10 GiB/month | ~$0.12 / GiB |

**Modeled daily usage at 10,000 DAU**, based on this app's actual screens
and sync behavior (`SyncManager._performSync`'s 5-minute cycle, feed
pagination, the `notifications` real-time listener, group-ride
`memberLocations` writes):

- ~85 reads/user/day → sync cycle (~15), feed pagination (~40), forums
  (~10), notifications listener (~10), places/reviews browsing (~10) →
  **850,000 reads/day**
- ~5 writes/user/day average → ride doc + track chunks + bike stat bump,
  amortized across the ~40% of DAU who record a ride that day → **~50,000
  writes/day**
- Group-ride live location is the one write pattern that scales with
  *seconds of active use*, not sessions: if ~2% of DAU do a 30-minute group
  ride with a location ping every 10s, that alone adds **~36,000
  writes/day** — small user % today, but the line item to actually watch as
  that feature gets adopted, since it doesn't shrink the way per-session
  costs do.

| | Daily volume | Free tier | Billable | Monthly cost |
|---|---|---|---|---|
| Reads | 850,000 | 50,000 | 800,000/day | ~$14/mo |
| Writes | 86,000 | 20,000 | 66,000/day | ~$3.60/mo |
| Storage | grows slowly (mostly compact ride metadata/polylines — photos live on Cloudinary, not Firestore) | 1 GiB | small early on | ~$0–10/mo, rising slowly |
| Egress | mostly small JSON payloads | 10 GiB/mo | likely near-free | ~$0–5/mo |

**Rough total: $20–30/month at launch, drifting up slowly as historical
ride data accumulates**, and rising faster specifically if group-ride live
sharing sees heavy adoption.

**Cloud Functions**: both existing functions are event-triggered on rare
writes (a crash report, a shared ride) — even generously assuming 800
ride-shares/day, that's ~24,000 invocations/month against a 2,000,000/month
free tier. Effectively $0.

**Auth**: free regardless of scale — this app uses email/password and
Google sign-in only, no phone/SMS auth (the one Firebase Auth method that
actually costs money).

**Hosting**: `public/live-viewer.html` and the privacy-policy pages are
small static assets; free tier (10 GiB/month transfer) comfortably covers
this at 10K DAU unless live-link sharing goes viral. Effectively $0.

### Safety net

Whatever the real number turns out to be, Blaze supports **budget alerts**
(Google Cloud Billing → Budgets & alerts) — set one at, say, $25 and $50,
and a bad estimate costs a notification, not a surprise invoice. Do this
the same day Blaze is enabled, before any real traffic.

---

## Option B — Surgical: keep Firebase, offload only the Functions-dependent pieces

Instead of enabling Blaze, stand up a small serverless function on a
platform with a real, no-billing-required free tier — **Cloudflare Workers**
or **Vercel Functions** are the natural fits — holding a Firebase Admin SDK
service-account credential, and move exactly the four blocked pieces above
onto it:

- A callable HTTP endpoint that mints a signed Cloudinary upload signature
  (closes §33.5) — the client calls this instead of uploading unsigned.
  `functions/src/index.ts`'s existing logic is easy to port; Admin SDK
  credentials work identically outside Google Cloud.
- A scheduled job (Cloudflare Cron Triggers / Vercel Cron) polling
  `crashNotifications` for the pending → contacted → escalated timer,
  replacing the Firestore-triggered Cloud Function with a poll — slightly
  less elegant (a few seconds of latency instead of instant trigger) but
  functionally equivalent for a safety feature measured in minutes.
- Same pattern for `ride-identity.ts`'s reconciliation — either a poll or a
  webhook if the platform supports it.

**Effort**: a few days, not weeks — the actual business logic in
`functions/src/*.ts` barely changes, only the trigger mechanism and
deployment target. **Firestore, Auth, Hosting, and all of `firestore.rules`
stay exactly as they are** — zero risk to the security work already done.

**Tradeoff**: now two platforms to operate and monitor instead of one, and
polling-based triggers are less immediate than Firestore's native ones.
Reasonable if avoiding a card on Google Cloud specifically matters more than
architectural simplicity; otherwise Option A is strictly less work for a
cost that's likely smaller than the cost of the *time* spent building this.

---

## Option C — Migrate off Firebase entirely (Supabase, or similar)

Supabase (Postgres + Auth + Storage + Edge Functions, genuine free tier, no
card required to start) is the most-asked-about alternative, so it's
assessed directly; the reasoning below applies just as much to AWS
Amplify/AppSync, a self-hosted PocketBase, or any other backend swap — the
expensive part is switching *paradigms*, not the specific vendor.

### What would actually need to be rebuilt

- **The whole data model.** Firestore is a document store; Supabase is
  Postgres. `rides`, `bikes`, `maintenance_logs`, `forums`, `places`,
  `reviews`, `groupRides`, and their subcollections all need a relational
  schema redesign — not a mechanical export, since Firestore's
  subcollection/denormalization patterns (e.g. `allowedUserIds` arrays
  materialized at share-time specifically so Firestore rules can filter a
  list query — see `rideVisibleTo()`'s doc comment in `firestore.rules`)
  don't map 1:1 onto foreign keys and joins.
- **All of `firestore.rules`, as Postgres Row-Level Security policies.**
  This is the biggest and riskiest piece. That file is not simple
  ownership checks — it encodes counter-fraud protection
  (`likeBumpValid`/`voteBumpValid`/`newDocBy` transactional binding,
  `Issues.md` §24.7), audience-tiered visibility (`rideVisibleTo`,
  `profileVisibleTo`, `bikesVisibleTo`), admin-claim handling, and
  capability-token access for live sessions — each one added *because a
  specific exploit was found* (§3, §10, §24, §33 collectively document at
  least a dozen real vulnerabilities closed in this exact file). RLS can
  express equivalent logic, but rewriting ~960 lines of battle-tested rules
  into a different policy language, from scratch, is exactly the situation
  most likely to silently reintroduce a bug that's already been fixed once.
- **Auth.** `supabase_flutter` has a mature SDK with email/password and
  Google OAuth, so this part is genuinely low-risk — but every
  `request.auth.uid` check across the rules file and every
  `FirebaseAuth.instance.currentUser` call in the Dart client still needs
  updating.
  `auth_provider.dart`'s custom-claim handling (`isAdmin()`'s
  `request.auth.token.get('admin', false)`, set via
  `scripts/set_admin_claim.js`) needs a Postgres/Supabase equivalent.
- **Edge Functions.** Supabase Edge Functions run Deno/TypeScript — closer
  to Cloud Functions than the Cloudflare/Vercel option above, so
  `functions/src/*.ts` ports with real but moderate effort.
  **Free tier, no card required.**
- **Storage.** Supabase Storage is free-tier-friendly and S3-compatible;
  either replaces Cloudinary or coexists with it — lowest-risk piece of the
  whole migration.
- **The client SDK layer.** Every repository under `app/lib/features/*/data/
  repositories/` (`ride_share_repository.dart`, `follow_repository.dart`,
  `group_ride_repository.dart`, etc. — a few thousand lines total) talks
  directly to `cloud_firestore`. All of it gets rewritten against
  `supabase_flutter`'s Postgrest/Realtime client.
- **Every rules-emulator test.** `scripts/test/rules/firestore_rules.test.js`
  (32 tests as of §33, covering exactly the exploits found in §24/§33) has
  no Postgres/RLS equivalent yet in this repo — a fresh test harness would
  need to be built before trusting a rewritten policy set at all.

### Effort and risk

This is weeks, not days — realistically a dedicated migration project with
its own testing/audit pass, not a swap done alongside other feature work.
The risk isn't "will it work" (Supabase is a mature, capable platform) —
it's that the security properties this app already has, specifically
because real vulnerabilities were found and fixed against Firestore's rules
language, don't automatically carry over to a rewrite in a different
language. Every one of §3/§10/§24/§33's findings would need to be
re-verified against the new policies, by hand, since the existing tests
don't run against Postgres.

### When this would make sense anyway

Not "avoiding Blaze" — Supabase isn't free at scale either, and its own
Pro-tier costs would need the same kind of estimate as Option A once this
app outgrows its free tier. The real reasons to consider it are unrelated
to billing: wanting SQL joins/reporting Firestore can't express well,
wanting to self-host, or hitting a Firestore-specific limitation
(document size limits, query expressiveness) that's actually blocking a
feature. None of those apply today.

---

## Comparison

| | Effort | Risk to existing security work | Ongoing cost @ 10K DAU |
|---|---|---|---|
| **A. Enable Blaze** | None (a checkbox + a card) | None | ~$20–30/mo, grows slowly |
| **B. Surgical (Cloudflare/Vercel for just the blocked pieces)** | Days | None — Firestore/rules untouched | ~$0 (both platforms' free tiers) |
| **C. Migrate to Supabase/other** | Weeks, dedicated project | High — full rules rewrite, re-audit everything | Free tier now, own cost curve later |

## Recommendation

Enable Blaze (Option A) unless there's a hard constraint on putting a card
on a Google Cloud account specifically — in which case Option B closes the
same four blocked items with no billing plan and no risk to the rules work,
at the cost of operating a second small platform. Option C solves a
billing question with a multi-week rewrite that reintroduces risk into code
that's already been through four rounds of real security hardening
(`Issues.md` §3, §10, §24, §33) — it's the right call if there's an actual
Postgres/self-hosting requirement, not as a way to avoid a ~$20/month bill.
