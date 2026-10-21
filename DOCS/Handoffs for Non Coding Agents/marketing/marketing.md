# Marketing strategy

Getting ThrottleIQ to 1,000+ daily users in Bangladesh. Written 2026-08-02;
rewritten 2026-10-22 to match the app as it is: beta `1.0.0-beta.4.7.1`
(build 29), signed APK on GitHub releases, Play internal testing by invite,
no public Play listing, no iPhone build, crash detection switched off
(shadow mode, nothing is sent to anyone), free, no premium tier.

Ready-to-send copy lives in [`marketing_kit.md`](marketing_kit.md). The pitch
deck outline is [`pitch_deck.md`](pitch_deck.md); the grant submission is
[`iDEA_PITCH_SUBMISSION.md`](iDEA_PITCH_SUBMISSION.md). What the app does today:
`DOCS/Handoff for agents and Todos/features.md`.

---

## 1. Do the math first

1,000 DAU is brutal for an app people open a few times a week. If an active
rider opens it 4 days in 7, 1,000 DAU needs roughly 2,500-3,000 weekly
active riders, and most fitness-adjacent apps lose 60-80% of installs in 30
days. So retention comes before acquisition: an install that opens the app
twice and never returns is wasted effort. Sequence: fix the loop, then pour
in users.

## 2. Segments and positioning

Three real segments. Do not mix them on one asset.

### A. Daily commuters (Dhaka, Chattogram, Sylhet; 100-160cc)

Yamaha, Bajaj, TVS, Runner, Hero riders using the bike for transport.
Price-sensitive, prepaid data, often buying and selling used bikes.
**Positioning:** *ThrottleIQ is the bike computer your commuter motorcycle
never came with: it remembers what your bike needs, all without a signal.*
**Messages, in order:** 1 offline-first (works in the dead zones they ride
through), 2 maintenance by real distance, not memory (service history is
usually lost at resale), 3 free.
**Short copy:** EN "Works when your signal doesn't." BN "সিগন্যাল না থাকলেও, রেকর্ড হতে থাকে।"
**Long copy (BN):**
> রোজকার রাইডে বাইকের হিসাব রাখা কঠিন — কবে চেইন লাগানো হয়েছিল, তেল কবে বদলানো
> দরকার, সবই স্মৃতির উপর নির্ভর করে। থ্রোটল আইকিউ এই হিসাবটা রাখে আপনার বদলে —
> প্রকৃত দূরত্ব দেখে, অনুমানে নয়। আর সিগন্যাল না থাকলেও রাইড রেকর্ড হতেই থাকে,
> কারণ এটা তৈরি বাংলাদেশের রাস্তার জন্যই। সম্পূর্ণ ফ্রি।

**Channels:** BD motorcycle Facebook groups and brand owners' groups; garages
and parts shops offered a free Places listing; street posters near fuel stops
and garages (`posters/`).

### B. Enthusiast and touring riders

Royal Enfield, KTM, bigger Yamaha and Honda owners, often in Facebook touring
clubs on highway or hill-tract routes. More interested in data, group
features and routes; the segment most likely to use group rides and saved
routes. **Positioning:** *ThrottleIQ gives touring riders the telemetry their
bike's dash never showed, and the group tools their club was doing over
WhatsApp screenshots.* **Messages:** 1 real ride telemetry (speed, braking,
route, offline), 2 group ride live map with a join code, saved routes, 3 made
by someone who rides. **Short copy:** "Stop screenshotting the route. Share
it live." **Channels:** 2-3 touring clubs (offer to support one club ride
live), BD moto YouTube and reel reviewers for an honest unpaid review, brand
forums seeded with starter posts.

### C. Anxious family (a distribution channel, not a direct user)

Parents and spouses of riders. "I want my son to have this on his bike" is a
real motion. **Positioning:** *Before a long ride, your rider sends you a
link, and you can see where they are.* **The one claim that is true:** Live
Share, a link the rider starts and sends to chosen people; it shows location,
speed and battery in any browser with no login and stops after 24 hours.
**Never write for this segment:** crash detection, automatic notification,
SMS or email delivery, "someone will know if you go down". None of it exists.
**Short copy:** BN "সে রাইডে, আপনি নিশ্চিন্তে।" **Channel:** reached through
the rider (equip segments A and B with a "show this to your family" frame).

Road safety is a high-salience topic in Bangladesh, so Live Share is the
strongest emotional hook today; crash detection would be stronger but only
once it is calibrated on real roads and delivery exists
(`DOCS/General/CRASH TESTING/`).

## 3. Positioning, one line each

- "Works when your signal doesn't." Offline-first, framed for Dhaka-Sylhet and
  Dhaka-Cox's Bazar reality.
- "Your bike's memory, not your notebook's." Maintenance against real distance.
- "Send your family a link." Live Share.
Lead with the local pain, not the spec sheet ("20+ data points a second" is a
spec, not a reason to care).

## 4. Fix before spending on acquisition

- **Cold-start empty screens.** Places, forums and the feed are only as good
  as their content. The Dhaka places are seeded from Google Maps and Apify
  data (owner decision pending); seed 2-3 starter posts in the biggest brand
  forums so nothing looks abandoned on day one.
- **Bangla.** The app has a Bangla UI (partly machine-written, native review
  pending) and a Bangla store listing draft
  (`DOCS/General/Files for Stores/store_listing/store_listing_bn_addendum.md`).
  Ship the listing in both languages together.
- **Real screenshots** for the Play listing (shot list in the kit, section 6).
- **A shareable ride summary** outside the app does not exist as a public page
  for a finished ride. The live viewer proves the pattern (public page, no
  login); extending it makes every shared ride a small billboard.

## 5. Channel plan

**Phase 0, before the public listing (2-4 weeks).** Seed data (section 4).
Recruit 20-30 riders from 2-3 large BD motorcycle Facebook groups and
brand groups as closed testers (Play requires a closed test before
public release). Ask: does offline recording survive a real dead zone, and
how is the battery on your phone.
**Phase 1, public launch, first 4-6 weeks.** Post into the same groups ("we
built this, tested it with riders here, now it is live"); it beats an ad in
these ad-skeptical communities. Free installs for 2-3 reviewers. One or two
touring clubs, with a live club-ride demo of the group map. Garages and parts
shops listed free.
**Phase 2, months 2-4.** Re-engage the first testers when the retention fixes
(section 7) ship: "we shipped what you asked for". iPhone is not a channel:
there is no build. Apple Developer enrollment is decided; an iPhone beta
would be a retention channel for Android riders' iPhone friends, not a way to
acquire.
**Phase 3, months 4-6.** Repeat Phase 1 channels in Chattogram, Sylhet,
Khulna. If DAU is far from target, suspect retention first, not distribution.

## 6. Growth loops, what exists

- **Live Share link (acquisition).** Rider shares a link, a non-user opens
  it, sees the map. The viewer page carries an install call-to-action
  (`public/live-viewer.html`). Track click-through to install.
- **Group ride (retention, not acquisition).** Invites reach registered users
  only (in-app notification, no push to outsiders). Market it as a reason for
  a riding group to install together.
- **Forums (retention, light acquisition).** Only works when non-empty.
- **Shared ride summary page (acquisition, not built).**
- **"First to a badge tier wins a maintenance kit" (idea, not built).** Badge
  tiers (Bronze to Diamond) still exist; the rarity UI was removed 2026-10-14.
  Gate it on about 100 organic users, and on a claim and fulfilment path
  (verify the badge, collect an address, one prize per person, a BD courier
  quote). Owner decision pending; do not announce it.

## 7. Retention levers (from the Hooked analysis, rechecked 2026-10-22)

The loop is ride, summary, glance at stats, next ride. The "between rides"
half is the weak one.
- **Built:** local maintenance-due notifications (`scheduleMaintenanceAlert`
  in `app/lib/core/services/notification_service.dart`), home-screen
  widgets, onboarding of two screens, export of rides as JSON and GPX
  (do not cut it to manufacture lock-in), garage and service history as
  accumulating investment.
- **Not verified, check before relying on them:** a celebration the moment a
  badge or rank is newly earned; a "new personal best" flag on the ride
  summary; push (FCM) for group-ride invites and forum replies (as of the
  last check, notifications are in-app only).
- **Do not propose:** challenges (removed 2026-10-14) or a daily-login streak
  (it punishes weekday-only and weekend-only riders; key any streak to the
  rider's own cadence).
- **Ideas, unbuilt:** a demo ride on first launch so a new rider sees a
  populated summary before adding a bike; a Sunday weekly digest.

## 8. What to track

Weekly, not daily, for the first 2-3 months (DAU is noisy at low volume). Pull
from Play Console cohorts; no analytics pipeline needed. One row per week:

| Week of | New installs | Day-7 retained | Day-30 retained | Logged a ride in first session | Live-share click to install | Top channel | Notes |
|---|---|---|---|---|---|---|---|

"Logged a ride in the first session" is the aha moment and predicts Day-30
retention better than installs do. Attribution needs the "how did you hear
about us" field (spec in the kit; not built). Read the table before adding a
channel or spending anything.

## 9. Budget

Zero to low paid spend: community seeding, organic groups, earned reviews, one
or two club rides. Paid installs in BD are cheap but low-intent and would
tank Day-7 and Day-30 numbers. Hold paid acquisition until Phase 2-3 and
healthy organic retention.

## 10. Honest risks (a skeptic's read, updated 2026-10-22)

For anyone pitching this to a partner or investor.
1. **"No competitor" is false globally.** Rever, Calimoto, Detecht, Tonit and
   EatSleepRide exist. The defensible claim: no Bangladesh-specific,
   Bangla-localized, BD-road-context competitor. A local moat, not a category
   moat.
2. **The most marketable feature is not live.** Crash detection runs in
   shadow mode and alerts nobody; SMS and email escalation does not exist
   (needs Blaze and gateways). Live Share is what works. Every asset must say
   so (the kit's no-overclaim rule). Copy drifts toward overclaiming this
   feature (it happened in the Settings copy and two poster drafts), and the
   cost of one miss is disproportionate.
3. **No monetization is built.** The iDEA submission proposes a Pro tier
   (BDT 99 a month) and fleet SaaS; none is built or priced in the app. The
   growth segment (price-sensitive commuters) and the paying segment
   (enthusiasts) are different people. Expect low ARPU in Bangladesh
   (ads, a very cheap tier, dealer or insurer partnerships).
4. **Distribution is the biggest blocker.** APK sideloading ("unknown
   sources") is friction for exactly the commuter segment; the public Play
   listing needs the 14-day closed test first. Get on Play before spending on
   acquisition.
5. **Retention is diagnosed, partly fixed** (section 7).
6. **Solo-founder risk.** One person is the only line of defense on an app
   that handles live location; two security sweeps already found
   launch-blocking issues. State the plan plainly (there is none yet).
7. **Cloud cost.** Firebase is on the free Spark plan; the quota outage mode
   covers running out. The `backend_options.md` estimate ($20-30 a month at
   10K DAU) should be re-run with a monetization assumption attached.

## 11. Name candidates

Brainstorm of 2026-09-11, not a decision: Kickstand (approachable, no tech
oversell), RevBook or TorqueBook (logbook framing), MotoSight (awareness),
PowerBand (RPM sweet spot, also a two-stroke term), MindfulMoto (calm, pairs
with the family segment), RideIQ (closest swap, keeps the "IQ"), BlackBox
Moto or FlightBox Moto (the "flight recorder" pitch; careful, it implies
crash recording), Odomind (odometer plus mind).
