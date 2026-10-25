# Is there a better backend than Firebase for ThrottleIQ?

Written 2026-10-25. Short answer: **no, not now. Stay on Firebase and move to Blaze.** No other backend suits this app enough better to pay for a rewrite. The pain points people blame on Firebase are really the Spark plan and a few read-heavy query shapes. Both can be fixed without leaving Firebase.

This file is the verdict. The full option analysis is in `DOCS/For Devs and Contributors/architecture/backend_options.md` (2026-08-23). The Blaze decision card, with costs checked against the repo, is `DOCS/agent_rooms/drafts/decision_card_blaze_upgrade.md` (2026-10-22). That card is owner item 3.

## What the app needs from a backend

| Need | How it works today | Does Firebase fit? |
|---|---|---|
| Offline-first recording | The phone holds the data: SQLite, an outbox and tombstones (`app/lib/core/cloud/`). The cloud is a sync target. | Yes. This part barely depends on the vendor. Any backend would work here. |
| Auth: email/password and Google, plus an admin claim | Firebase Auth | Yes. Free at any scale with no phone auth. |
| Social data with per-audience visibility (public, followers, mutual, blocks) | About 2,300 lines of `firestore.rules`, plus emulator tests that cover each past exploit (§3, §10, §24, §33) | Yes. This is the most expensive part to rebuild anywhere else. |
| Live location (live share, group rides) | Firestore docs polled every 20-40 s | **No.** Billing per read gives N² cost (§104.2). |
| Server jobs (deletion, retention, TTL, signed uploads, rate limits) | Written in `functions/src/`, never deployed | Yes, once on Blaze. It's blocked by the plan, not by the platform. |
| Media | Cloudinary, unsigned preset | Independent of the backend. Signing needs a function. |
| Small static site (live viewer, install, privacy) | Firebase Hosting | Yes |

## The alternatives, judged for this app

| Backend | What it does better | Why it doesn't win here |
|---|---|---|
| **Supabase** (Postgres, RLS, Auth, Storage, Edge Functions) | Flat-rate pricing with no per-read bill. Real SQL for ride analytics. You can export and self-host. | Every visibility rule would need rewriting as RLS, with a new test harness. The data model and every repository under `app/lib/features/*/data/` would need redoing. That's weeks of work, and every past rules fix would need re-checking. The free tier pauses idle projects. Pro costs about $25/mo plus compute (verify current pricing). |
| **PocketBase / Appwrite (self-hosted)** | One cheap VPS with no usage billing | You'd run the uptime, backups and security patches yourself, with no one on call. Same rewrite cost as Supabase. The offline sync story is weaker than Firestore's. |
| **Convex / other real-time BaaS** | Good reactive queries and server functions | Small Flutter SDK, vendor lock-in again, and the same rewrite. |
| **Custom API (Node/Go + Postgres)** | Full control, cheapest at large scale | You'd build auth, sync, real-time and access rules from nothing. It's the wrong trade for a solo-built beta. |
| **Cloudflare Workers / Vercel next to Firebase** | Free server code without Blaze | Not a replacement. It's `backend_options.md` Option B. It only makes sense if a card on Google Cloud is ruled out. |

## What to do instead

1. **Enable Blaze with a budget alert** (decision card, Option 1). This unblocks deletion (Apple 5.1.1(v)), TTL, retention, signed uploads and rate limits. All of that code is already written. At today's usage of 3-14% of the free reads, the bill is $0.
2. **Fix the read hot spots, which cost money on any per-read backend:**
   - §104.1: places cache (on `main`, not released yet).
   - §104.2: one shared positions doc per group ride, or move live positions to **Realtime Database**. RTDB bills by bandwidth and storage, not per read, which suits high-frequency positions. The dormant client code is already in `app/lib/core/realtime/`.
   - §104.3: votes in one doc per user.
   - Add an index exemption for track `points` arrays (`phone_vs_cloud_data.md`: 25 MB of index for 1.5 MB of data).
3. **Enforce App Check** after a release that sends tokens (owner items 17 and 32). Without it, a scripted client can run up reads once spending is uncapped.

## When to look at this again

Leaving Firebase becomes worth the rewrite only if one of these turns out true:

- **The Firestore bill stays above about $150-200/mo** after the read fixes above. The decision card estimates about $115/mo for reads alone at 10K daily riders at 640 reads per rider-day, so `backend_options.md`'s $20-30 is too low. At that point Postgres's flat pricing starts paying back the migration.
- **You need SQL over telemetry.** Examples: cross-rider analytics, the Maya partner API's road-speed aggregates, or reporting that Firestore queries can't express. A cheaper middle path is exporting Firestore to BigQuery for the analytics and keeping the app on Firebase.
- **A hard data-residency or self-hosting requirement** (for example a Bangladesh government or partner contract).

If one of these triggers fires, plan Supabase as a dedicated migration project, starting with the RLS port and its test harness. Don't do it as a side task.
