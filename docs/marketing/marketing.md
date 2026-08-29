# Marketing — Getting ThrottleIQ to 1,000+ Daily Users in Bangladesh

_2026-08-02 · Launch sequence: Play Store (BD) first → iOS via TestFlight
only → public App Store later. This doc is grounded in the app's actual
current state (README, `Features.md`, `store_listing.md`, live code) — not
generic app-marketing advice. Retention mechanics (what keeps someone
opening the app) are covered in depth in `hooked_throttleiq.md`; this doc
is about getting BD riders to install and try it in the first place, then
pointing back to that doc for the loop that keeps them._

---

## 1. The real target isn't 1,000 installs — do the math first

"1,000 daily users" for a ride-tracking app is a DAU target, and DAU is
brutal for an app most people open a few times a week, not daily. A
commuter might open it 4-5x/week; a weekend-only rider 1-2x/week.

Rough math: if the average active rider opens the app ~4 days out of 7
(a reasonable target once maintenance-due notifications exist, per
`hooked_throttleiq.md`), sustaining **1,000 DAU needs roughly
2,500–3,000 weekly-active riders**, which in turn needs a considerably
larger *install base with retention* — because most ride-tracking /
fitness-adjacent apps lose 60-80% of installs within 30 days if the app
never gives them a reason to come back between sessions.

**Implication:** the highest-leverage work isn't just "get more installs,"
it's closing the retention gaps already identified in
`hooked_throttleiq.md` (no push notifications at all today, badges/rank
fire silently, no maintenance-due nudge) *before* spending effort on
acquisition. An install that opens the app twice and never comes back is
wasted acquisition spend. Sequence: fix the loop, then pour in users.

---

## 2. Who you're actually selling to in BD

Three real segments, not a generic "motorcyclist":

1. **Daily commuters** (Dhaka/Chattogram/Sylhet, mostly 100–160cc:
   Yamaha, Bajaj, TVS, Runner, Hero) — care about fuel efficiency,
   traffic-related close calls, and knowing when the bike actually needs
   service (many don't have a dedicated mechanic, buy/sell used bikes
   often). Price-sensitive, prepaid mobile data — **offline-first is a
   real, not cosmetic, selling point here.**
2. **Weekend touring/enthusiast riders** (RE, KTM, bigger Yamaha/Honda,
   often in Facebook-based touring/riding clubs doing highway or
   hill-tract routes) — care about route data, group rides, and are the
   segment most likely to actually use "Ride with friends" and saved
   routes as built.
3. **Anxious family** (parents/spouses of riders) — not app users
   themselves, but the emotional force behind crash detection & live
   share adoption. "I want my son to have this on his bike" is a real
   distribution channel, not just a feature bullet.

Road safety is a genuinely high-salience topic in BD (frequent, often
serious motorcycle accident coverage in local media) — crash detection and
live-share are the app's strongest **emotional** hook here, stronger than
in markets where riding is more purely recreational.

---

## 3. Fix these before spending on acquisition

Every one of these is a real, checked gap — not hypothetical:

- **`public/live-viewer.html` has zero call-to-action.** Today, when a
  rider shares their live location, the person who clicks the link (a
  non-user, by definition) sees the map and nothing else — no "get
  ThrottleIQ" button, no store link. This page is the single most
  qualified acquisition surface the app has (someone already cares enough
  about this specific rider to click) and it currently converts zero of
  them. **Fix this first** — it's a few lines on an existing static page,
  not new infrastructure.
- **Cold-start empty screens.** POI directory, forums, and the ride feed
  are only as good as what's in them. A rider in Sylhet who opens Places
  and sees nothing nearby, or Forums and sees an empty "Yamaha" thread,
  churns immediately. Before a public push, seed: import POIs via the
  existing Overpass integration for Dhaka/Chattogram/Sylhet metro areas,
  and seed 2-3 starter posts in the highest-traffic brand forums yourself
  (or via early testers) so nothing looks abandoned on day one.
- **No Bangla anywhere** — not in the UI (confirmed: no
  `flutter_localizations`/ARB files in the app), and not in the Play
  Store listing (`store_listing.md` is English-only). Full UI
  localization is a real effort and shouldn't block launch, but the
  **Play Store listing itself should ship with a Bangla short description
  and Bangla keywords alongside the English one** — this is pure ASO
  upside with near-zero engineering cost, and it's the first thing a BD
  rider searching "motorcycle app" in Bangla will or won't find you
  through.
- **No shareable-outside-the-app ride summary.** The Ride Feed is
  in-app-only (`Features.md` §7) — a rider can't send a finished ride's
  summary card to a non-user friend on WhatsApp/Messenger the way Strava
  lets you share a public activity link. The live-location viewer proves
  the pattern (public web page, no login) already exists in this
  codebase; extending the same approach to a **finished ride's** summary
  (map + stats, no personal data beyond what audience settings already
  allow) turns every shared ride into a small billboard instead of a
  private, invisible-to-outsiders event.

---

## 4. Positioning: lead with the BD-specific pain, not the feature list

Don't lead marketing copy with "GPS tracker with 20+ data points/sec" —
that's a spec, not a reason to care. Lead with what's actually true and
locally resonant:

- **"Someone will know if you go down."** Crash detection + live share,
  framed around the anxious-family segment above, not just the rider.
- **"Works when your signal doesn't."** Offline-first, framed for the
  highway-between-cities reality (Dhaka–Sylhet, Dhaka–Cox's Bazar), not
  as an abstract architecture note.
- **"Your bike's memory, not your notebook's."** Maintenance tracked
  against real distance, aimed at the used-bike-heavy BD market where
  service history is often unknown or lost at resale.

---

## 5. Channel plan for BD (phased)

**Phase 0 — before the Play Store listing goes live (2-4 weeks):**
- Seed data per §3 (POIs, forum posts) so early installs don't land on an
  empty app.
- Recruit 20-30 riders directly from 2-3 large public BD motorcycle
  Facebook groups and brand-specific groups (e.g. owners' groups for
  Yamaha R15 / Pulsar / RE-type communities) as closed testers — this
  matches the existing beta-testing pattern already referenced in
  `HANDOFF_Document.md` (12-dev closed testing group), just extended to
  real riders instead of developers. Ask specifically for: does crash
  detection false-trigger on BD road conditions (potholes, rickshaw
  traffic), does offline recording survive a real signal dead zone.
- Fix the live-viewer CTA and Bangla listing copy (§3) during this window
  — both are cheap and both compound every day they're live before launch.

**Phase 1 — Play Store launch, first 4-6 weeks:**
- Post launch (not paid ads) into the same Facebook groups used for
  testing, plus 2-3 adjacent ones — a genuine "we built this, been testing
  it with riders here, now it's live" post outperforms an ad in these
  communities, which are close-knit and ad-skeptical.
- Reach out to 2-3 BD moto YouTube/Facebook-reel reviewers with a
  free, no-strings install — ask for an honest review, not a paid
  placement. One credible review in this space reaches more real riders
  than a broad ad spend at this stage.
- Target one or two touring/riding clubs that do organized weekend rides.
  Offer to be present (virtually or via a contact) for one club ride using
  "Ride with friends" + saved routes live — a club ride is the single best
  live demo of the group-map feature, and club members are exactly the
  enthusiast segment (§2.2) most likely to become vocal advocates.
- Reach out to local bike-repair garages / parts shops to list themselves
  in Places for free — solves the cold-start problem in §3 on an ongoing
  basis and creates local-business goodwill that leads to word of mouth.

**Phase 2 — months 2-4, iOS TestFlight opens:**
- TestFlight has a hard cap (10,000 testers via public link, but realistic
  organic reach is far lower) and required manual install steps — treat
  it as a *retention/expansion* channel for existing Android word-of-mouth
  reaching iOS-owning friends, not a primary acquisition channel. Don't
  spend acquisition effort specifically on iOS until App Store launch;
  let it ride on the same community channels.
- Once maintenance-due notifications and the badge/rank celebration
  moment (from `hooked_throttleiq.md`'s priority list) ship, re-engage
  Phase-0/1 installs who went quiet — a direct "we shipped the thing you
  asked about in testing" message to the original 20-30 testers costs
  nothing and re-activates exactly the users most likely to talk about it
  again.

**Phase 3 — months 4-6, App Store public + push toward 1,000 DAU:**
- By this point, DAU growth should be coming from retention mechanics
  (Phase 2) compounding on top of a wider install base (Phase 1-2 channels
  repeated in 2-3 more cities/regions — Chattogram, Sylhet, Khulna groups),
  not from a single new channel. If DAU is still far from target here, the
  problem is very likely retention (re-check `hooked_throttleiq.md`'s
  loop), not distribution — don't just add more channels to compensate for
  a leaky loop.

---

## 6. Growth loops mapped to what's actually built (and what isn't yet)

- **Live-share link (real acquisition loop, needs one fix):** rider
  shares live location → non-user clicks, sees map → **today, dead end;
  fix per §3 and this becomes a genuine loop** where every ride with
  live-share turns into a small number of qualified installs.
- **Group-ride invite (retention loop, not acquisition — know the
  difference):** inviting a friend to a group ride requires them to
  already be a registered ThrottleIQ user (in-app notification only, no
  SMS/push to outsiders — `assumptions.md` #17). This strengthens
  retention among people who already installed together, but it will not
  pull in new users on its own. Don't market it as a growth driver; market
  it as a reason existing riding groups all install together up front.
- **Forum/brand community (retention + light acquisition):** a bike-model
  forum only pulls in new users if it's discoverable and non-empty before
  they arrive — ties directly back to the cold-start seeding in §3.
- **Shared ride summary (acquisition loop that doesn't exist yet):**
  building the public ride-summary page described in §3 turns the highest
  volume in-app action (finishing and sharing a ride) into a second real
  acquisition loop, not just the live-share one.
- 🔮 **Milestone-gated "first to badge" promotion (idea, not built,
  proposed 2026-08-28).** Once the app has reached roughly **100 organic
  users** (a deliberate floor — this is a retention/word-of-mouth play for
  an existing base, not a launch-day acquisition stunt, and running it too
  early would mean giving prizes away to the same 20-30 closed-beta
  testers who already installed for free), run a limited-time promotion on
  top of the existing badge system (`Features.md` §3, bronze → diamond
  tiers): the **first** riders to reach specific named badge tiers win a
  small physical prize relevant to actually maintaining a bike — engine
  oil, a chain cleaner/lube kit, etc. Which badges qualify and how many
  winners per badge should be decided at the time it's run, based on
  which tiers are still realistically reachable "first" by a fresh cohort
  rather than already claimed by early testers.
  - **Why this is worth doing over a generic giveaway**: it rewards actual
    usage (riding enough to earn a real badge) rather than a follow/share
    tap, and the prize category (oil, chain cleaner) reinforces the
    Garage/maintenance-tracking identity that's already ThrottleIQ's
    deepest differentiation (`Features.md` §5, `business_critique.md`).
  - **Not yet solved, before this can run**: a claim/fulfilment path
    (verify the badge was actually earned, collect a shipping address,
    ship a physical item, cap it to one prize per person) — none of that
    exists today. This is the same gap already flagged in
    `HANDOFF_Document.md`'s "Badge completion reward" open question (an
    all-badges-earned engine-oil promise); that item and this one are two
    different concrete proposals riding on the same missing
    infrastructure, and only one claim/fulfilment mechanism should
    probably be built to serve both rather than two separate ones.
  - **Cost/logistics are the real open question**: shipping a physical
    item to riders across Bangladesh needs a courier relationship and a
    per-unit cost budgeted before announcing it — don't promise it
    publicly before that's worked out, for the same "don't promise what
    isn't built yet" reason the crash-alert copy in this repo is kept
    honest.

---

## 7. What to track

- **Weekly**, not daily, for the first 2-3 months — DAU is noisy at low
  volume and will discourage you if it's the only number you watch.
- Installs → Day-7 retained → Day-30 retained, split by whether the rider
  logged at least one ride in their first session (the real "aha moment,"
  per `hooked_throttleiq.md`'s Action section).
- Live-share link click-through → install rate, once §3's CTA fix ships —
  this single number tells you whether the acquisition-loop fix worked.
- Which Facebook group / channel each cohort of installs came from (ask
  in-app once, on first launch: "how did you hear about ThrottleIQ?" — a
  single optional field, not a full survey) — spend more time in whichever
  channel is actually converting, stop guessing.

---

## 8. Budget reality

This is a solo-built app (per `README.md`/`pitch_and_marketing_materials.md`) — the plan above is
built around **zero-to-low paid spend**: community seeding, organic
Facebook groups, earned reviews, and one or two live club-ride
appearances. Paid app-install ads in BD are relatively cheap but attract
low-intent installs that will tank Day-7/Day-30 retention numbers and make
the real problem (the loop) harder to see. Hold paid acquisition until
Phase 2-3, and only once retention from organic channels is already
healthy enough that paid installs have something to stick to.
