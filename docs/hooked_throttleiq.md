# Hooked Model — ThrottleIQ

_2026-08-02 · Applies Nir Eyal's Hooked framework (Trigger → Action → Variable
Reward → Investment) to this app specifically. Every "Today" line below is
grounded in the actual codebase, not a guess — see file refs. Ideas already
on the backlog in `HANDOFF_Document.md` are flagged as such rather than
re-proposed as new._

---

## The core habit loop

ThrottleIQ's natural loop is **ride → summary → glance at stats/garage →
next ride**, not a daily check-in app like a fitness tracker. A commuter
rides once or twice a day; an enthusiast rides on weekends. The loop to
design for is: *does the rider open the app **around** a ride* (before, to
check the bike; after, to see the summary) *and does something outside
that window pull them back in between rides* (maintenance countdown,
someone reacting to their shared ride, a challenge)?

Right now, only the "around a ride" half is strong. The "between rides"
half is almost entirely passive — nothing reaches out to the rider. That's
the single biggest lever in this document.

---

## 1. Trigger

**Today:**
- All notifications are in-app only and reactive — `follow` and
  `groupRideInvite` (`app_notification_entity.dart`). No push (FCM isn't
  wired — explicit in the entity's own doc comment).
- No scheduled/periodic trigger anywhere: no maintenance-due reminder, no
  weekly summary, no "you haven't ridden in a while" nudge. Confirmed
  absent — `flutter_local_notifications` isn't even a dependency.
- Home-screen widgets refresh on data change (app open, ride saved), not on
  a timer — so they're a good *external trigger surface* once something
  actually updates them proactively.
- Internal trigger today is entirely rider-initiated: "I'm about to ride."
  There's no equivalent internal trigger for "I should check on my bike"
  on a day the rider *isn't* riding.

**Ideas:**
- **Maintenance-due local notification.** The distance-to-next-service math
  already exists (`home_widget_service.dart:164-189` `computeNextService`,
  mirrored in `maintenance_screen.dart`). It's computed but never pushed.
  A local notification ("Chain lube due in 150km") turns a passive widget
  into an active trigger — no backend needed, no Blaze plan, just
  `flutter_local_notifications` scheduled off the same data already in
  SQLite. This is the highest-leverage, lowest-cost trigger available.
- **Social reactions as re-entry triggers.** A rider shares a ride; a friend
  upvotes or comments. That's a natural external trigger ("someone reacted
  to your ride") but today it's invisible unless the rider happens to open
  the feed. Once FCM is wired (already planned per `Assumptions Made.md`
  #17 for group-ride invites), route comment/upvote events through the same
  pipe — cheap incremental scope, not a new system.
- **Weekly digest, not daily nag.** Given the loop is ride-frequency-driven
  (not daily), a Sunday-evening "this week: 3 rides, 142km, chain due in
  80km" notification fits the actual usage pattern better than a daily
  streak nag would — see the streak caution in Variable Reward below.

---

## 2. Action

**Today:**
- Onboarding is already lean — 2 screens, 6 fields total (name/username,
  then one bike), both skippable straight to the Record tab
  (`onboarding_screen.dart`). This is a real strength — don't add fields
  to it.
- The Record screen's own reordering (2026-08-01, see `Features.md` §2) —
  greeting → bike picker → slide-to-start — already optimizes for "one
  clear next action." Good, keep protecting this from feature creep.
- Where action gets heavier: a **new** user with no bike hits a warning +
  "Add Bike" wall before they can record anything (`Features.md` §2). That
  wall is correct (you can't ride without a bike in the app's model) but
  it's the one place the "aha moment" — seeing a completed ride's summary
  screen — is more than one action away from install.

**Ideas:**
- **Ghost/demo ride on first launch.** Let a brand-new user tap a sample
  ride card and see a populated Ride Summary screen (score, map, splits)
  *before* they've recorded anything themselves. Shows the payoff up
  front, independent of the add-a-bike requirement. Low cost: one static
  fixture, no backend.
- **Collapse "add bike" into onboarding step 2's skip path.** Today,
  skipping onboarding's bike step and skipping it *again* on Record both
  land the same warning. Consider: if a user skipped onboarding's bike
  step, surface the Add Bike sheet inline on first Record-tab visit
  instead of a second separate warning state — one fewer screen between
  install and first ride.

---

## 3. Variable Reward

**Today:**
- Rank/level (`stats_screen.dart:14-23`, 7 tiers, 500km/level) and badges
  (`core/utils/badges.dart` via `badge_sync_provider.dart`) exist, but both
  are **silent** — recomputed on screen load, rendered as static pills.
  No toast, animation, or notification fires the moment a badge is newly
  earned or a rank is crossed. The reward exists; the *moment* doesn't.
- `ChallengeType.streak` is a defined enum value with zero live feature
  behind it (`challenge_entity.dart`) — a real streak system was modeled
  and never built.
- No "personal best" ever gets flagged — ride summary shows absolute max
  speed / avg speed, never "fastest you've gone" or "longest ride yet,"
  even though the data to compute it (all prior rides) is already local.
- The feed's upvote/downvote `netScore` ordering (`ride_feed_provider.dart`)
  is itself a variable-reward surface — a shared ride's score moves
  unpredictably as others react — but there's no notification tied to it
  (see Trigger, above), so the variability is invisible unless a rider is
  already looking.

**Ideas:**
- **Surface the moment, not just the state.** The cheapest, highest-impact
  change here: when `badgeSyncProvider` detects a *newly* earned badge
  (it already diffs against `earnedBadges` in Firestore — the diff exists
  for the sync, just isn't surfaced to UI), show a one-time celebration
  (bottom sheet or snackbar) instead of silently persisting it. Same for
  crossing a rank threshold. This is UI wiring on top of data that already
  exists, not a new system.
- **"New personal best" on Ride Summary.** Compare the just-finished ride's
  max speed / distance / duration against the rider's own history
  (already queryable via `RideDAO`) and flag it inline if it's a new best.
  Cheap, personal (not competitive, so no social pressure), and directly
  answers "why should I look at this summary" every single ride.
- **Be deliberate about streaks, don't just ship the enum.** A daily-login
  streak fits Duolingo-style apps, not a ride-frequency app — punishing a
  commuter who rides Mon–Fri but not weekends, or a weekend rider who
  rides Sat–Sun only, for "breaking" a streak they never intended to keep
  is the wrong shape of variable reward here and risks feeling punitive
  rather than delightful. If the streak model gets built, key it to
  **riding days relative to the rider's own typical cadence** (e.g. "3
  rides this week, your best week yet") rather than a raw consecutive-day
  count.
- **Regional/friends comparison, scoped carefully.** The generic advice to
  add leaderboards is real but needs a privacy-aware shape given
  `Assumptions Made.md`'s existing stance on home-location privacy: never
  rank by absolute location, only by opted-in metrics (total distance,
  fuel efficiency if/when tracked) among *followed* riders — mirroring the
  audience-tiered sharing model already built for the feed, not a new
  privacy model.

---

## 4. Investment

**Today, and it's already fairly strong:**
- Garage (multi-bike profiles), maintenance history, emergency contacts,
  saved routes, and forum/follow relationships are all real, accumulating,
  user-authored data — the classic "investment" ingredients are present.
- Profile visibility controls (`bikesVisibleTo`, audience picker on Edit
  Profile) mean investment is already paired with *control* over that
  investment, which is the right instinct — forced lock-in erodes trust
  faster than it builds switching cost for a safety-adjacent app like this.
- Export (JSON/GPX) already exists and is described in the README as a
  deliberate feature, not a gap — good; don't cut it to manufacture lock-in.
  Investment should come from the *value* of accumulated history and
  relationships, not from making it hard to leave.

**Ideas:**
- **Let investment compound visibly.** "Your Journey" already tallies
  total km and level — extend it to surface compounding milestones tied to
  *this specific bike's* history ("Ronin 350: 1,200km and 6 services
  logged since you added it") so the investment feels tied to the asset
  (the bike) the rider actually cares about, not just an abstract account.
- **Saved routes as social investment.** A rider who saves and shares a
  route has invested effort *and* made themselves discoverable/useful to
  others — worth surfacing "3 riders have ridden your route" back to the
  creator as both a reward (Variable Reward overlap) and reinforcement of
  the investment already made.

---

## What this doc deliberately does NOT re-propose

`HANDOFF_Document.md` already lists several of the generic Hooked-style
ideas as backlog (T1→T2 in its Community & gamification section):
smoothness-score trend, "arrived safely" geofence alerts, community
challenges beyond the current local badges, and a documents wallet with
expiry reminders. Treat this doc as *sharpening the mechanism* (which
moments get a trigger, which numbers get flagged as a reward) rather than
adding a second, competing backlog.

---

## If prioritizing by effort vs. impact

1. **Maintenance-due local notification** — no backend, uses existing
   computed data, closes the biggest "nothing reaches out to the rider"
   gap.
2. **Badge/rank-up celebration moment** — UI-only, data already diffed.
3. **"New personal best" flag on Ride Summary** — one query against
   existing `RideDAO` history, no schema change.
4. **Route comment/upvote push, once FCM lands** — incremental scope on
   top of the already-planned group-ride-invite push work.
5. **Streak/challenge system** — hold until it can be modeled on riding
   cadence rather than raw daily-login count; otherwise defer.
6. **Friends/regional comparison** — hold until there's a metric worth
   comparing that isn't just raw distance (e.g. once fuel-efficiency or
   smoothness score exist), and reuse the existing audience-tier privacy
   model rather than inventing a new one.
