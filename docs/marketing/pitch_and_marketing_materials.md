# ThrottleIQ — Pitch Deck & Marketing Materials

Written 2026-08-23. Grounded in the app's actual current state — `docs/pitch.md`,
`docs/marketing/marketing.md`, `store_listing/store_listing.md`, `docs/planning/HANDOFF_Document.md`,
and the live codebase — not generic template copy. Two parts: a slide-by-slide
pitch deck outline, then marketing materials broken out by the three real user
groups this app actually serves.

Two things are deliberately left as placeholders rather than invented: the
funding/partnership **ask** (nothing in this repo states one), and the
**SMS/email crash escalation** (built in code but not deployed — Cloud
Functions require the Blaze billing plan this project isn't on yet, per
`docs/planning/Issues.md` §24/§33). Every other claim below is checked against what
the app actually does today.

---

## Part 1 — Pitch deck (slide-by-slide)

### Slide 1 — Title

**ThrottleIQ**
*Machine memory for motorcycles.*
[logo — the speedometer-arc mark, `app/assets/images/app_icon.svg`]

### Slide 2 — The problem

Motorcyclists have no equivalent of a car's onboard computer.

- Every ride's speed, braking, and route disappears the moment it happens.
- Maintenance is tracked in a notebook, a memory, or not at all — a real
  problem in a market with heavy used-bike turnover, where service history
  is usually unknown at resale.
- If a rider goes down alone on a back road, nobody knows until they're
  overdue.
- Existing ride-tracking apps (Strava and similar) are built for cyclists
  and runners — they don't model motorcycle-specific risk (crashes at
  speed, highway fatigue) or motorcycle-specific upkeep (chain/oil/tires
  tied to distance ridden, not to a training calendar).

### Slide 3 — The solution

ThrottleIQ turns a rider's phone into a black box and riding companion:

- **Ride recording & analysis** — GPS + accelerometer capture speed,
  acceleration, braking, jerk, and route, fully offline-first, so recording
  never depends on a signal.
- **Crash detection & live location share** — detects a crash signature
  (impact + speed-drop), starts a cancellable countdown, and lets the rider
  share a live, token-based location link — no account required on the
  other end.
- **Maintenance tracking** — service intervals (chain, oil, tires, etc.)
  tracked against actual distance ridden, not guesswork.
- **Social & community** — ride sharing with audience-tiered privacy,
  brand/model forums, and a rider-built place directory (fuel, garages,
  parts).
- **Garage** — every bike a rider owns, its stats, and its maintenance
  history in one place.

### Slide 4 — Product tour (the core loop)

Record a ride → get an analyzed summary (distance, speed, hard-braking/
acceleration counts, moving time vs. stopped time) → maintenance intervals
update automatically → share to a following with privacy controls → repeat.
Offline-first: a ride recorded with zero signal syncs the moment connectivity
returns.

### Slide 5 — Who it's for

Three real segments, not a generic "motorcyclist" — detailed messaging for
each is in Part 2:

1. **Daily commuters** — price-sensitive, prepaid-data riders on 100–160cc
   bikes in Dhaka/Chattogram/Sylhet, who care about fuel efficiency and
   knowing when the bike actually needs service.
2. **Enthusiast/touring riders** — bigger bikes, Facebook-group touring
   communities, who care about route data, group rides, and saved routes.
3. **Anxious family** — not app users themselves, but the emotional force
   behind crash-detection and live-share adoption, and a real distribution
   channel in a market where motorcycle-accident coverage is high-salience.

### Slide 6 — Why now

Phones already carry every sensor this needs (GPS, accelerometer) — the gap
is software, not hardware. Riders increasingly expect the kind of telemetry
and safety net cars have had for a decade, and no incumbent app is built
rider-first for it. Road safety is a genuinely high-salience topic in
Bangladesh specifically (frequent, often serious motorcycle-accident coverage
in local media), which makes crash detection and live-share a stronger
**emotional** hook here than in markets where riding is more purely
recreational.

### Slide 7 — Where it stands today

Honest, current status, not the stale figures in older docs:

- **Beta `1.0.0-beta.1+1`**, tagged [`beta-v1`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v1)
  on GitHub — signed release **APK only**; no Google Play or App Store
  listing yet. iOS distribution is TestFlight-only once opened.
- Core loop — record, analyze, maintain, share — is fully built and working,
  including offline recording with automatic sync on reconnect, and GPS
  route sync (verified against the live code, not assumed).
- Localized into Bangla alongside English (bottom nav, Record screen, ride
  summary, and growing).
- A recent security/bug-hardening pass closed 16 of 18 findings, including
  two that would have been launch-blocking (`docs/planning/Issues.md` §33) — this is
  a beta that's had a real audit pass, not just feature work.
- **Not yet live:** automatic SMS/email crash-alert escalation (built,
  mocked pending the Blaze billing plan), Play Store / App Store listings,
  monetization of any kind.

### Slide 8 — What's next

- Wire the crash-detection escalation (SMS/email if an emergency contact
  doesn't acknowledge within 15 minutes) — blocked on a billing-plan
  decision, not on code (see `docs/architecture/backend_options.md`).
- Turn-by-turn "curvy road" navigation for scenic/sport riders.
- Clubs and group-ride events.
- A premium tier (advanced analytics, unlimited history, priority support)
  — not yet designed or priced.
- Play Store launch (Bangladesh first), then public App Store.

### Slide 9 — Competitive landscape

Strava and similar apps are built for cyclists/runners and treated as a
generic fit for motorcyclists at best — no crash detection, no
distance-based maintenance tracking, no motorcycle-specific event detection
(hard-braking, rapid acceleration, overspeed, rider fatigue on long
stretches). ThrottleIQ's differentiation is being **rider-first by design**,
not a running app with a motorcycle skin — every core feature (maintenance
by real distance, crash detection tuned to motorcycle impact/speed-drop
signatures, offline-first for weak-signal highway riding) is something a
generic fitness tracker doesn't and can't do well.

### Slide 10 — The ask

**[Fill in based on the actual conversation: funding / mentorship / pilot
riders / distribution partners / a specific city-launch budget.]** Nothing
in this repo commits to one yet — say plainly what's being asked for before
this slide goes in front of anyone.

---

## Part 2 — Marketing materials by user group

Each group gets its own positioning, message hierarchy, and sample copy.
Don't mix these on one asset — a commuter and an enthusiast rider respond to
different proof points, and diluting the message to cover both weakens it
for each (this is also why the street-poster campaign built earlier this
session runs 10 separate directions rather than one poster trying to say
everything).

### A. Daily commuters (Dhaka / Chattogram / Sylhet, 100–160cc)

**Who they are:** Yamaha/Bajaj/TVS/Runner/Hero riders using the bike for
daily transport, not recreation. Price-sensitive, on prepaid mobile data,
often in the used-bike market (buying/selling every few years). Care about
fuel efficiency, near-miss traffic safety, and not getting surprised by a
bike that suddenly needs an expensive repair.

**Positioning statement:** *ThrottleIQ is the bike computer your commuter
motorcycle never came with — it remembers what your bike needs and watches
out for you in traffic, all without needing a signal.*

**Key messages, in priority order:**
1. Offline-first — works in the dead zones this segment actually rides
   through, not an abstract feature.
2. Maintenance tracked by real distance, not memory or guesswork — directly
   useful for a used-bike-heavy market where service history is often lost.
3. Free.

**Sample copy — short (social/poster):**
- EN: *"Works when your signal doesn't."*
- BN: *"সিগন্যাল না থাকলেও, রেকর্ড হতে থাকে।"*

**Sample copy — long (Facebook post / group intro):**
> রোজকার রাইডে বাইকের হিসাব রাখা কঠিন — কবে চেইন লাগানো হয়েছিল, তেল কবে বদলানো
> দরকার, সবই স্মৃতির উপর নির্ভর করে। থ্রোটল আইকিউ এই হিসাবটা রাখে আপনার বদলে —
> প্রকৃত দূরত্ব দেখে, অনুমানে নয়। আর সিগন্যাল না থাকলেও রাইড রেকর্ড হতেই থাকে,
> কারণ এটা তৈরি বাংলাদেশের রাস্তার জন্যই। সম্পূর্ণ ফ্রি।
>
> *(Keeping track of a bike day-to-day is hard — when the chain was last
> done, when the oil's due, all of it riding on memory. ThrottleIQ keeps
> that record for you, by real distance, not guesswork. And it keeps
> recording even with no signal, because it's built for roads like these.
> Completely free.)*

**Channels:** BD motorcycle Facebook groups and brand-specific owners'
groups (per `docs/marketing/marketing.md` §5); local bike-repair garages and parts
shops, offered a free Places-directory listing in exchange for word of
mouth; street posters near fuel stops and garages (see the [street poster
campaign](docs/marketing/marketing.md) built this session — Carbon Mono and Editorial
directions target this group specifically).

### B. Enthusiast / touring riders

**Who they are:** Royal Enfield, KTM, larger Yamaha/Honda owners, often in
Facebook-based touring/riding clubs doing highway or hill-tract routes.
Less price-sensitive, more interested in data, group features, and route
planning. The segment most likely to actually use "Ride with friends,"
saved routes, and forums as built.

**Positioning statement:** *ThrottleIQ gives touring riders the telemetry
their bike's dash never showed them, and the group tools their riding club
was doing over WhatsApp screenshots.*

**Key messages, in priority order:**
1. Real ride telemetry — speed, braking, route, more than 20 data points a
   second, fully offline.
2. Ride with friends — live group map, saved routes, shared ride feed.
3. Built by someone who actually rides, not a fitness-app port.

**Sample copy — short:**
- EN: *"20+ data points. Every second. Every ride."*
- EN (group-ride angle): *"Stop screenshotting the route. Share it live."*

**Sample copy — long (club/forum pitch):**
> If your riding club is still coordinating routes over WhatsApp and
> comparing top speeds from memory afterward, ThrottleIQ replaces both:
> live group maps during the ride, a real stats breakdown after it (max
> speed, hard-braking count, moving time vs. stopped time), and saved
> routes your whole club can navigate turn-by-turn later. Fully offline on
> the stretches between towers. Free to use — we'd genuinely like your club
> to be one of the first to try it on a real weekend ride.

**Channels:** direct outreach to 2–3 touring/riding clubs, offering to
support one organized club ride live using "Ride with friends" + saved
routes as the demo; BD moto YouTube/Facebook-reel reviewers for an honest
(unpaid) review; brand-specific enthusiast forums seeded with starter posts
before public launch so nothing looks empty on day one. The Analyst Blue and
Trail Social poster directions target this group.

### C. Anxious family (distribution channel, not a direct user)

**Who they are:** parents and spouses of riders — not people who will
install and use the app's ride-recording themselves, but the emotional
force behind adoption of its safety features. "I want my son to have this
on his bike" is a real, distinct distribution motion, not just a feature
bullet aimed at riders.

**Positioning statement:** *ThrottleIQ can't stop a crash, but it makes sure
someone finds out fast — and that someone can be you.*

**Key messages — precisely worded, because this is the one group where
over-promising is a real harm, not just bad marketing:**
1. Crash detection with a cancellable countdown — a false alarm (a pothole,
   a hard stop) doesn't wrongly notify anyone.
2. A live location link the rider can turn on and share with chosen
   contacts — **not** an automatic SMS/email alert; that escalation isn't
   live yet, and no material aimed at this audience should imply it is.
3. Works offline, so "no signal" isn't a gap in coverage.

**Sample copy — short:**
- EN: *"If they go down, you don't have to wait to find out."*
- BN: *"সে রাইডে, আপনি নিশ্চিন্তে।"* (They're riding, you can be at ease.)

**Sample copy — long (aimed at a parent/spouse, not the rider):**
> আপনার প্রিয়জন রাইডে গেলে, একটা প্রশ্ন মনে থেকেই যায় — সব ঠিক আছে তো? থ্রোটল
> আইকিউ ক্র্যাশের মতো ধাক্কা আর আচমকা গতি কমে যাওয়া চিনে নিতে পারে, আর রাইডার
> চাইলে লাইভ লোকেশন শেয়ার করতে পারেন আপনার সাথে — পুরো রাইড জুড়ে। কোনো
> সিগন্যাল না থাকলেও রেকর্ডিং চলতেই থাকে।
>
> *(When someone you care about is out riding, one question always
> lingers — are they okay? ThrottleIQ recognizes a crash-like impact and
> sudden speed drop, and the rider can choose to share their live location
> with you for the whole ride. Recording continues even with no signal.)*

**Do not write, for this group, until it's actually true:** anything implying
automatic notification on crash without the rider first turning on live
sharing, or any promise of SMS/email delivery. The Calming and Nocturne
poster directions were specifically corrected during this session for
exactly this overclaim — see that fix before reusing any of that copy
elsewhere.

**Channels:** this segment isn't reached directly through ads — it's reached
through the rider they care about, so the actual channel is equipping
riders (segment A and B materials) with a "show this to your family" framing,
and word of mouth once a rider actually uses live-share on a real ride.
