# ThrottleIQ — A Hostile Read

_Claude Opus 5 · 2026-09-20 · commit `e26e329` · branch `main`_

**Scope:** UI/UX, codebase, architecture, feature surface, flow, testing, docs.
Deliberately **not** business/market/monetisation — that was excluded.

**Method:** read the source. `flutter analyze` (clean), `flutter test` (1174
pass, ~52s), plus structural greps across `app/lib` (259 Dart files, 55,684
lines), `functions/src`, `firestore.rules` (1,414 lines), `scripts/`, and the
9,058 lines of `DOCS/Handoff for agents and Todos/`. I did not drive the app on
a device, so every claim below is traceable to a file and line rather than to a
screenshot.

**Where this overlaps existing docs:** `uiux_critique.md`, `issues_open.md §32`,
`new_gravity.md` and `stiiLl_left.md` already name some of this. I've marked
those `[known]` and gone after what they miss. The fact that several of the
harshest findings below are *already written down and still shipping* is itself
one of the findings.

---

## The one-paragraph verdict

This is a genuinely well-engineered app wrapped around a **safety product that
does not work**, and the engineering quality is actively hiding that fact. The
sensor-fusion pipeline, the outbox, the Firestore rules, the privacy clipper,
the 1,174 green tests — all real, all careful. Meanwhile the headline feature,
the one on the README, the onboarding slides and the app's entire reason to
exist as something other than another ride logger, is compiled out behind a
`const false` and backed by a cloud function whose delivery path is a
`console.log`. Everything else on this list — the global-statics theming, the
un-paginated feed, the 43 screens with one screen test, the English-only safety
copy in a Bangladesh-first app — is ordinary technical debt. That first thing is
not debt. It's a liability.

---

## 1. The safety product is a facade, end to end

This is the section that matters. The rest is craft.

### 1.1 Live crash detection is switched off in every build

`app/lib/core/constants/sensor_constants.dart:60`

```dart
static const bool impactDetectorLiveEnabled = false;
```

It's a `const`, so the whole `ImpactDetector` pipeline is never constructed at
runtime. `SensorFusionCoordinator` defaults to it
(`helpers/sensor_fusion_coordinator.dart:21`). The live recorder additionally
passes `detectCrash: false` into `EventDetector.detect()` because the GPS branch
needs an 80 m/s² speed delta a real ride can never produce. Net result: **while
you are riding, nothing in this app can detect a crash.** The only path that
can return `RideAlert.crash` is `auto_ride_reconciler.dart:298` — post-hoc
replay of a ride that already ended.

`stiiLl_left.md` lists this. `issues_open.md §32` lists the settings-screen
symptom. It is still shipping in `beta_v3.0.1`.

### 1.2 Three surfaces advertise it anyway

- **`README.md:35`** — "**Crash detection**: Accelerometer spike + speed drop
  within 2 sec → 60-second countdown", under a "🔐 Safety & Emergency" heading,
  with no caveat. Two lines later: "Emergency contacts: Share live location &
  ride stats with up to 5 emergency contacts."
- **`onboarding_manifest.dart:152`** — every new rider, on first launch, is
  shown a callout pin reading:
  > **Crash Shield** — Impact & tumble detection with 60s emergency cancellation.
- **`arch.md:5`** — "detect critical incidents (e.g., high-g crashes)" in the
  opening sentence.

Settings has honest copy ("Automatic SMS/email alerts aren't live yet"), which
`uiux_critique.md` already flags as *worse* than hiding it. But the honest copy
is buried three taps deep in Settings while the dishonest copy is on the
**first screen a new user ever sees**. That's the wrong way round. A rider who
saw "Crash Shield" at onboarding and never opened Settings believes they have a
crash detector.

### 1.3 Even if it fired, nobody would be contacted

`functions/src/crash-notifications.ts`. The entire emergency pipeline is a mock:

```ts
// MOCK: In production, integrate with Twilio for SMS or SendGrid for email
for (const contact of contacts) { await sendContactNotification(...) }
await snap.ref.update({ status: 'contacted', ... });   // ← line 67
```

`sendContactNotification` builds the SMS and email bodies, then does
`void smsMessage; void emailSubject; void emailBody;` and `console.log`s that it
would have sent something. The document status is then set to **`'contacted'`**.
The per-contact log row correctly says `status: 'mock_not_sent'` — and there's a
good comment explaining why it must not say `'sent'` — but the *parent*
notification doc, the one `escalateCrashAlert` queries and the one any future
dashboard would read, claims the contact was reached. That's the one place the
lie matters and it's the one place it wasn't caught.

Further down the same file:

- `scheduleEscalation()` (line 168) is a function whose entire body is a
  `console.log` and a `// TODO`. It's called, does nothing, and the real
  15-minute scan is a separate `onSchedule` — so the named function is pure
  dead weight that reads like it works.
- `escalateCrashAlert` has `.limit(10)`. Ten escalations per 15 minutes,
  globally, silently truncated. Fine at beta scale; a silent cap on an
  emergency path is the wrong shape regardless of scale.
- The mock SMS body says `your emergency contact ${uid}` — it would text a raw
  Firebase UID to a rider's mother instead of their name. A bug already baked
  into the message the "future Twilio call" is supposed to send.

### 1.4 The detector itself has design problems nobody has stress-tested

`app/lib/features/ride/domain/calculators/event_detector.dart`:

- **`_checkSpeedDrop()` requires `newest.speedMs < 1.0`.** The rider must be at
  a dead stop *within the same 2-second window as the impact*, measured by GPS
  speed, which lags by seconds and is often garbage mid-tumble. A highside where
  the bike slides 30 m, or where the phone's GPS holds a stale 8 m/s for three
  fixes, produces no crash. This is a false-negative machine by construction.
- **`_resetCrashState()` calls `_recentSpeeds.clear()`** (line 244). The speed
  history is a general-purpose 2-second ring buffer, but it's wiped every time
  an *unrelated* accel-spike window expires. For up to 2 s after any >8 g blip,
  the detector is blind to speed drops because it threw away the history it
  needed. Two concerns sharing one reset.
- **`detect()` takes seven parameters, two of which are flags that disable half
  the class** (`detectCrash`, `countLongitudinal`). The doc comments explain in
  detail *which caller passes which flag and why* — which is the tell. This
  isn't one detector; it's two detectors in a trenchcoat, and the flags are
  there because nobody wanted to split the file.
- **Overspeed has no hysteresis.** Hard-brake and rapid-accel got proper
  edge-triggering with re-arm thresholds (§78.3, correctly). Overspeed is a bare
  `if (speedMs > overspeedThreshold) return RideAlert.overspeed;` at line 207 —
  it fires on *every single fix* above the line. On the UI side
  (`active_ride_screen.dart:173`) `_triggerAlert` dedupes on
  `alert == _lastAlert`, so the flash is suppressed — until one hard brake
  interleaves, at which point the screen flashes amber again. Sustained
  highway riding with occasional braking = a strobing screen at speed.
- **`elapsedSeconds >= fatigueAlertSeconds` (5400 s) re-fires every 10 seconds,
  forever.** After 90 minutes, "Time for a break" is a permanent alert state
  with no dismissal and no snooze. The rider's only options are stop the ride or
  ignore the app.

### 1.5 The test suite is green on the disabled path

`README.md:168` proudly shows the crash-detection test as the example of test
discipline:

```dart
test('DOES fire on crash: accel spike + jerk spike + speed→0 in 2s', () { ... });
```

It passes. It has always passed. It tests a code path that `const false`
guarantees will never execute on a rider's phone. 1,174 green tests is a real
achievement and it is also, here, a **confidence-manufacturing machine** — the
suite's greenness is being read as evidence the feature works. Tests that guard
dead code should be marked as such, or the flag should be flipped and the
feature field-validated.

> **The honest fix is not "wire up Twilio."** It's: pick one. Either crash
> detection ships — flag on, thresholds field-tested with real drop data,
> Twilio/SendGrid live, contacts actually notified — or every mention of it is
> pulled from the README, `arch.md`, the onboarding manifest and the pitch deck,
> and Settings says "planned," not "not live yet." The current middle state is
> the worst of the three.

---

## 2. Architecture: one decision poisons the whole UI layer

### 2.1 `AppColors` is a mutable global, and it costs you the Navigator

`app/lib/core/constants/app_colors.dart` is a static facade over a swappable
palette. The counts:

| | |
|---|---|
| `AppColors.*` reads | **1,532** |
| `Theme.of(context)` reads | **10** |

So ~99% of the app's colour decisions happen **outside Flutter's element
dependency graph**. A widget that reads `AppColors.primary` has no subscription
to it. Changing the palette can't notify anything.

The workaround is right there in `app/lib/app.dart:172`, with a comment that
states the problem plainly:

```dart
return MaterialApp.router(
  key: ValueKey(appearance),   // ← forces the ENTIRE subtree to unmount/remount
```

**Changing your theme tears down and rebuilds the whole application.** Every
`State` object in the tree is destroyed: scroll positions, map camera positions,
half-typed forms, open bottom sheets, expanded panels, in-flight image loads,
`AnimationController`s. GoRouter's delegate preserves the *location*, so you
land back on the right screen — with everything on it reset. Change the theme
while the active-ride cockpit is up and the map re-centres and the polyline
re-renders from scratch. It's a full app restart with extra steps, triggered by
a settings toggle.

Downstream costs of the same decision:

- **No `ThemeMode.system`.** Zero occurrences of `platformBrightness` or
  `ThemeMode.*` anywhere in `app/lib`. The app cannot follow the OS dark-mode
  setting — a baseline expectation on both platforms since 2019, and the one
  theming feature users actually ask for. Seven hand-tuned colour families, and
  you can't have "match my phone."
- **`const` is dead across the UI.** The class comment admits it: getters mean
  "any `const` expression that embedded one of them must drop the `const`
  keyword." So every styled `TextStyle`, `BoxDecoration` and `Icon` in 1,532
  places is rebuilt and reallocated on every frame that touches it.
- **Static state leaks across widget tests.** Whichever palette the last test
  applied is the palette the next test sees. Doesn't bite today because there
  are almost no widget tests (§6) — it will the moment there are.
- **Golden tests are effectively impossible.** 7 modes × 2 brightnesses × 2
  shapes = 28 appearance combinations, and no way to render two of them in one
  test process without global mutation. Zero `matchesGoldenFile` in the repo,
  which for an app whose differentiator is its look is a notable hole.

The correct shape is a `ThemeExtension<AppPalette>` on `ThemeData`, read via
`Theme.of(context).extension<AppPalette>()`. That's a 1,532-site mechanical
migration — large, but it is *mechanical*, and it deletes the remount hack, the
const ban, the test leakage and the system-brightness gap in one move. Every
month it's deferred adds call sites.

### 2.2 `RideRecordingState`: a 21-field god object with two inverted fields

`ride_recording_provider.dart:52-118`. Twenty-one fields in one immutable state
class, rebuilt **once per second** by the elapsed timer (line 708) plus once per
GPS fix. Against that:

- `.select(` appears **3 times** in the entire app.
- `ref.watch(rideRecordingProvider)` (whole object, no selector) appears **4**
  times — including `active_ride_screen.dart`, which is 877 lines.

So the biggest screen in the app rebuilds in full, every second, for the whole
duration of a ride, while the phone is also running GPS at 1 Hz, IMU at 20-50 Hz,
a map, and a foreground service. That's a battery and thermal cost on exactly
the device state where battery matters most. The `polylineVersion` counter shows
the author knew about selector granularity — it just never got applied to the
rest of the object.

**And the `copyWith` has a trap.** Lines 156-157:

```dart
error: error,                                     // NOT `error ?? this.error`
blockKind: blockKind ?? RecordingBlockKind.none,  // NOT `?? this.blockKind`
```

Two of twenty-one fields clear by default instead of persisting. Every other
field uses `?? this.x`. Worse, the comment sixteen lines above says the exact
opposite:

```dart
// `liveSessionToken: null` means "keep", like every field here
```

That is false for `error` and `blockKind`. The practical consequence: the
per-second elapsed timer calls `copyWith(elapsed:, activeAlert:)` and **wipes
any error and resets `blockKind` to `.none` within one second**. Today the blast
radius is small — the three `error:` assignments are all on pre-start paths
where the timer isn't running yet — so this is a latent trap, not a live bug.
But it's a trap with a comment pointing the wrong way, in the safety-critical
notifier, waiting for the first person who sets an error mid-ride.

### 2.3 Navigation as a build side-effect

`record_screen.dart:68-73`:

```dart
if (rideState.status == RecordingStatus.active || ... paused) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.go('/ride/active');
  });
}
```

A route change scheduled from inside `build()`. It re-queues on every rebuild
while the condition holds, and `build()` runs for reasons that have nothing to
do with recording (unread-notification count, active bike, theme remount). The
`active_ride_screen` has an `_endingRide` boolean whose entire job is to
suppress the *other* half of this same pattern from clobbering the destination
`_stopRide()` wanted — a flag that exists to paper over the first design mistake
rather than fix it. `ref.listen(rideRecordingProvider, ...)` does this correctly
and deletes both the postFrameCallback and the flag.

Same file, line 30: `Provider<(String, String)>` that calls
`Random().nextInt(...)` in its body. A provider whose value is non-deterministic
and unmockable.

### 2.4 "Clean architecture" with hardcoded dependencies

`arch.md §1.3` claims layered clean architecture. In practice:

- `RideRecordingNotifier` news up `RideDao()`, `RidePointDao()`,
  `MotionCalculator()`, `EventDetector()`, `RecordingCadencePolicy()`, and all
  four coordinators as `final` fields in its constructor body
  (`ride_recording_provider.dart:194-202`). None are injectable.
- `maintenance_provider.dart:16` — `final _dao = MaintenanceDao();` as a
  **file-level top-level variable**. A process-wide singleton created at library
  load.
- `FirebaseFirestore.instance` referenced directly in **20** places,
  `FirebaseAuth.instance` in **9**, including inside repository methods
  (`ride_share_repository.dart:225`).
- `CrashCoordinator` accepts an injected `FirebaseFirestore` — so someone knew
  the pattern — and then the notifier that owns it calls the no-arg constructor.

The DI story is "test the pure calculators, don't test anything that touches
I/O." Which is exactly what the test suite reflects (§6).

### 2.5 `catch (_)` as a coping strategy

**53** bare `catch (_)` blocks in `app/lib`, 11 of them with a completely empty
body. Many carry a justifying comment ("already gone, or rules raced us"), and
several of those are legitimate. But the pattern is load-bearing: `auth_provider.dart`
alone has five, `group_ride_repository.dart` four. In a Crashlytics-instrumented
app, 53 swallowed exceptions is 53 failure modes that will never appear in the
dashboard and will be reported to you as "it just didn't work."

---

## 3. Backend, data and privacy

### 3.1 Deleting your account does not delete your data

`functions/src/account-deletion.ts` handles: the profile doc (recursive), the
username reservation, `livePointers`, and queries for `rides`, `liveSessions`,
`crashNotifications`, and follow edges both directions. That's careful work and
the `recursiveDelete` comment shows why it matters.

What it doesn't touch:

- **Every Cloudinary asset the rider ever uploaded.** Avatars, bike photos, ride
  photos, place photos, push-to-talk voice clips. The service has no delete path
  (`cloudinary_upload_service.dart` — zero `destroy` calls anywhere in the repo),
  because unsigned presets can't authorise deletion and there's no API secret
  server-side. Its own doc comment says orphaning is "harmless at this scale."
  It is not harmless after a deletion request: those files stay at public
  `secure_url`s **forever**, reachable by anyone who has or guesses the link, and
  they are exactly the personal-data category a deletion request is about.
- **Comments the rider left on other riders' rides** (`rides/{other}/comments`).
- **Forum threads and posts.** `forums/` is never queried.
- **Chat messages** in `chats/{id}/messages`.
- **Places they added and reviews they wrote** — `places` and `reviews` are
  never queried, and a place doc carries `addedBy`.
- **Group rides they created or joined.**

So "delete my account" leaves the rider's name, words and photographs scattered
across other people's screens with a `userId` pointing at a user that no longer
exists. Google Play's Data Safety section and its account-deletion requirement
both ask specifically about this. The Settings entry cites Apple Guideline
5.1.1(v) (`settings_screen.dart:599`) — it currently satisfies the letter of
"there is a delete button," not the substance.

### 3.2 The Cloudinary preset is an open upload endpoint

`cloudinary_upload_service.dart:29`:

```dart
static const _cloudName = 'vjvcigkt';
static const _uploadPreset = 'throttleiq_unsigned';
```

The doc comment is right that these aren't *secrets* — unsigned presets are
designed to be client-callable. It's also missing the point. Anyone who
`strings` the APK gets two values that let them POST arbitrary images, video and
audio to your Cloudinary account, at your bandwidth quota, with no auth, no rate
limit, no size cap and no moderation, from `curl`. The free tier's 25 GB is a
weekend's work for a bored person. And whatever they upload sits on a domain
associated with your app.

There is no signed-upload path, no Cloud Function proxy, and no moderation hook
on the upload — `chat-moderation.ts` moderates chat *text* only.

### 3.3 The privacy clipper's jitter is security theatre against anyone with the source

`privacy_zone_clipper.dart` is good work. Radius-based rather than path-based
clipping is the right call and the reasoning is sound. The jitter is not:

```dart
static double radiusFor(int seed, ...) => radiusM + (seed.abs() % 150);
static int seedForUid(String uid) { /* published FNV-1a */ }
```

The stated threat is: "A fixed radius lets anyone who sees a few of a rider's
shares intersect the circles' edges and triangulate the center." The defence is
a per-rider radius derived deterministically from their uid — and `userId` is a
**plaintext field on every public ride doc** the attacker is already reading.
The repo is source-available on GitHub. So the attacker's work is:

```dart
final r = PrivacyZoneClipper.radiusFor(PrivacyZoneClipper.seedForUid(ride.userId));
```

One line, exact answer, no averaging required. Knowing `r` precisely makes
triangulation *easier* than a fixed 200 m would, because the first surviving
polyline point now sits on a circle of known radius. A secret the client must
compute is not a secret. Either accept fixed-radius clipping and say so, or the
seed has to come from somewhere the viewer can't reach.

Two more, smaller:

- **Clipping is client-side only.** `firestore.rules` cannot verify a polyline
  was clipped. A modified client uploads the raw track and the rules accept it.
- **Mid-ride passes near home are kept**, acknowledged in the doc comment. A
  loop ride from the office that passes the rider's street is unclipped there.
- `clipPolyline` returns `[]` for anything under 3 points or entirely inside the
  zone — a short commute shares as an **empty map**, with no UI acknowledgement
  of why.

### 3.4 Blocking is a client-side filter

`ride_feed_provider.dart:95` filters blocked uids out of the feed **after**
downloading it. So a blocked user's rides, photos and text are fetched to the
victim's device on every refresh; only the rendering is suppressed. There's no
rules-side enforcement, which means blocking also doesn't stop the blocked user
from reading the blocker's public content. For a moderation feature the model is
backwards — blocking should be a server-side edge, not a `.where()` on the
client.

### 3.5 `firestore.rules` is 1,414 lines and doing document reads per row

85 KB, 41 `match` blocks, most of the bulk in explanatory comments. It's
well-reasoned — the `allowedUserIds` materialisation trick to keep list queries
satisfiable is genuinely clever. Two problems:

- `bikesVisibleTo(uid)` does a `get()` of the owner's profile **per bike
  document read**. Its own comment says so and says it's acceptable "for a
  handful of bikes." Rules `get()`s are billed reads and count against the
  10-access-per-single-document / 20-per-query limit. A garage view of a rider
  with several bikes is burning that budget on data that should be denormalised
  onto the bike doc, as the comment itself suggests and nobody did.
- `crashNotifications` create (line 514) is rate-limit-free: any signed-in user
  can write unlimited `pending` crash docs for themselves, each one invoking a
  Cloud Function. Free DoS on your own function quota.

Credit where due: `scripts/test/rules/firestore_rules.test.js` is 1,560 lines
against the real emulator, and it runs in CI. That's better rules discipline
than most production apps have.

---

## 4. UI/UX

`uiux_critique.md` covers the screenshot-level findings — paused-ride scrim
over the stat card, FAB over the last list row, `★ —` for zero reviews, the
doubled riding-score card, the maintenance pill that never escalates, unlabelled
chart axes. All still open in `issues_open.md §32`, none triaged, and I have
nothing to add to them beyond: **they were written on 2026-08-17 and it is now
2026-09-20.** Here's what that review didn't cover.

### 4.1 Accessibility is not implemented

| Signal | Count in `app/lib` |
|---|---|
| `Semantics(` widgets | **5** |
| `semanticLabel` / `semanticsLabel` | **0** |
| `textScaler` / text-scale handling | **0** |
| Hardcoded `fontSize:` | **535** |

Zero semantic labels means every icon-only control — the notification bell, the
map controls, the share button, the vote arrows, the five bottom-nav items — is
an unlabelled tap target to a screen reader. 535 hardcoded font sizes with no
`textScaler` accommodation means a rider using the OS large-text setting gets
overflow, clipping, or nothing at all depending on how each `Row` was built.

For a motorcycle app this is not an abstract compliance point. Your users are
outdoors, in sunlight, wearing gloves, sometimes older, and the app's own
critique already notes "low-contrast grey-on-black throughout — worth a contrast
pass given this is meant to be read outdoors." Accessibility work here *is*
legibility work for every user, not a minority feature.

### 4.2 Bilingual is a claim, not a state

`pubspec.yaml` bundles a Bengali variable font specifically so "the app's
Bangla-speaking riders" have glyphs offline from first launch. Excellent
instinct. Then:

| | |
|---|---|
| Files using `AppLocalizations` | **20 of 259** |
| ARB keys (en / bn) | 156 / 156 |
| `l10n.*` call sites | 194 |
| Hardcoded `Text('...')` literals | ~340 |
| Hardcoded `labelText`/`hintText`/`title` literals | ~151 |
| `SnackBar` occurrences | 149 |

So roughly a **quarter** of the user-facing strings are translated. And it's the
wrong quarter. Localised: Settings, the appearance picker, the brightness
labels, the shape-vibe descriptions. **Not** localised:

- The entire **onboarding flow** — 7 slides, 21 feature callouts, all English.
  The single highest-stakes localisation surface in the product, because it's
  where a Bangla-first rider decides whether this app is for them.
- The entire **active ride cockpit**, including the alert strings at
  `active_ride_screen.dart:849-850`: `'Watch your speed'`, `'Time for a break'`.
- The **live-share sheet**: `'Share link again'`, `'Stop sharing now'`, `'The
  link stops working. Your ride keeps recording.'`
- Ride summary, stats, garage, maintenance, forums, chat, places.

The shipped state is: a Bangla-speaking rider can translate the theme picker
into their language, and then read every safety alert in English. If
localisation budget is finite — and for a solo build it obviously is — it should
have gone to onboarding and the cockpit before it went to "Curvy / Boxy."

`stiiLl_left.md` notes the new Bangla strings "require native-speaker review,"
which means even the translated 156 aren't verified.

### 4.3 Error states are exception dumps

Fifteen screens render failures as the raw exception string, in red, centred, on
an otherwise empty page, with no icon, no plain-language message and no retry:

```dart
error: (e, _) => Center(child: Text('$e', style: TextStyle(color: AppColors.danger))),
```

`stats_screen.dart:49`, `all_rides_screen.dart:93`, `maintenance_screen.dart:354`,
`place_detail_screen.dart:112` and `:212`, `routes_list_screen.dart:79`,
`route_detail_screen.dart:134`, `route_navigation_screen.dart:159`,
`notifications_screen.dart:46`, `my_shared_rides_screen.dart:56`,
`my_places_list_screen.dart:26`, `bike_detail_screen.dart:156`,
`ride_summary_screen.dart:223`, and more.

What the rider actually sees when their signal drops mid-ride, in red, as the
entire Stats tab:

> `[cloud_firestore/unavailable] Failed to get document because the client is offline.`

This is the **offline-first app**. The one screen where "you're offline, here's
your cached data" is the whole product promise renders a Firestore error code
instead. Three of the four `.watch`-style empty states in the app got friendly,
instructive copy — `uiux_critique.md` even praises them — and then the error
states got nothing. One shared `AsyncErrorView(onRetry:)` widget replaces all
fifteen.

### 4.4 Lists are built eagerly

> **Correction (2026-09-21):** the headline claim here was wrong about the
> feed specifically. `social_screen.dart:236` is the **search-results** list,
> not the feed; the feed uses `ListView.separated`, which is lazy. The counts
> below are accurate and the pattern is real elsewhere, but "the social feed
> constructs every child up front" was not.

| | |
|---|---|
| `ListView.builder` | **3** |
| `SingleChildScrollView` | **22** |
| Plain `ListView(` / `Column` in scroll views | pervasive |

`social_screen.dart:236` is a non-builder `ListView`. The social feed — cards
with network images, route thumbnails and vote controls — constructs **every**
child up front rather than lazily. Same shape in the rides list, forum threads,
places list. It works at 20 items because the feed is capped at 20 items (§4.5),
which means the cap is masking the problem rather than the problem being solved.

### 4.5 The feed is a dead end, and "Following" is probably empty

`ride_share_repository.dart:169-212` — three queries, each `limit: 20`, merged
and deduped client-side. Across the whole app: **3** occurrences of
`startAfter`/`startAt`/pagination, and none of them in the feed. There is no
"load more," no infinite scroll, no cursor.

So the social feed is **at most ~60 posts, ever**, with pull-to-refresh as the
only interaction. Scroll to the bottom and the product ends.

The sort chips make it worse. `visibleFeedProvider` filters
`FeedSort.following` **client-side** over that already-truncated 20-item public
slice (`ride_feed_provider.dart:88-99`). A rider following 30 people whose posts
aren't in the 20 most recent public rides taps "Following" and sees **an empty
feed**, with no explanation, while those 30 people are actively posting. The
chip looks broken because functionally it is.

### 4.6 N+1 reads on every feed load

`ride_share_repository.dart:224` — `_hydrate()`:

```dart
final votes = await Future.wait(entities.map((ride) => getMyVote(ride.id, currentUserId)));
```

One `get()` per ride, to read the viewer's own vote. Up to 60 ride docs + 60
individual vote-doc reads per feed load, on every pull-to-refresh, on mobile
data in Dhaka. A `votes` collection-group query filtered by uid, or
denormalising the viewer's vote, removes 60 round trips.

### 4.7 Navigation and information architecture

Bottom nav is `Social · Places · Record · Stats · Profile`
(`app_shell.dart:9-15`).

- **The garage is not in the nav.** For a *motorcycle* app, "my bike" is
  reachable only as a section of the Profile tab, and **maintenance is one level
  below that** — Profile → bike card → maintenance. Meanwhile a POI directory
  gets a top-level tab. `_nonTabShellRoutes` exists solely to stop
  `/home/maintenance` from highlighting the wrong tab, which is the IA telling
  you it doesn't fit.
- **`features.md` documents the nav order wrong** — it says
  `Social · Rides · ●Record· Places · Profile`; the code says
  `Social · Places · Record · Stats · Profile`. The tab is `/home/stats` and its
  label key is `navRidesLabel`. Three names for one thing.
- **42 routes, and 30 of them are full-screen with no bottom nav.** Settings,
  Notifications, Profile, Edit Profile, Ride Summary, Ride Share, all four
  Routes screens, both Forums screens, both Chat screens, My Places, My Shared
  Rides, All Rides, Safe QR, Blocked Users, Sync Issues. The five-tab shell is a
  thin skin over what is really a deep stack-based app, and the rider loses
  their tab context constantly.
- **Two "my stuff" menus.** "My places" and "My shared rides" hang off the
  *garage header's user menu*, per the router comments — not off Profile, not
  off the tabs they belong to.

### 4.8 The cockpit flashes coloured scrims at speed

`active_ride_screen.dart:172-193` flashes a translucent full-screen colour over
the live map on brake / accel / overspeed / fatigue. There is no setting to
disable it (only the overspeed *threshold* is configurable). Combined with the
no-hysteresis overspeed (§1.4), sustained fast riding with traffic produces
repeated amber washes over the map the rider is trying to read. A safety feature
that adds a visual distraction at 100 km/h needs a very high bar, and at minimum
an off switch.

`uiux_critique.md` also notes the live map is "too busy for a glance-while-riding
UI" and that the stat card covers ~40% of the screen. Both still true.

### 4.9 Smaller cuts

- **`HoldToStartButton` completes if press and release land in the same frame**
  — noted in `stiiLl_left.md`, unfixed. The one gesture that starts a ride, with
  a known false-positive path.
- **Slide/hold-to-start for the primary CTA.** `uiux_critique.md` calls it
  friction on the most frequent action; I'd go further — hold-to-confirm is a
  pattern for *destructive* actions, and using it for "begin" teaches the rider
  that the gesture means danger.
- **`onboarding_ui_mockups.dart` is 1,162 lines** — the third-largest file in
  the app — and it is, by name and by content, *drawings of the UI*
  reimplemented as widgets, shipping in the production binary. It will drift
  from the real screens the first time any of them changes, and nothing will
  catch it. Screenshots of the actual app would be smaller, truer, and
  self-updating via the existing `integration_test/ui_tour_test.dart`.
- **Seven-slide feature tour before the first ride.** 21 callout pins, every one
  English, before the rider has recorded a single kilometre. The Record tab's
  hold-to-start is the only thing a new user needs on day one.
- **Places "Browse routes" button** — hardcoded `Size(0, 48)` instead of
  `AppDimensions.controlHeight`; the only control in the app that ignores the
  shape system (`new_gravity.md §1`).
- **`Random()` in a Provider** for the dashboard quote (`record_screen.dart:30`).
- **No analytics of any kind.** Not a single `logEvent`. The README frames this
  as a privacy stance, and it's a defensible one — but it means there is
  literally no way to learn that the "Following" chip shows an empty feed
  (§4.5), or that nobody finds maintenance three levels deep (§4.7). Crashlytics
  tells you when it breaks; nothing tells you when it's merely useless. A
  privacy-respecting app can still count screen views.

---

## 5. Feature surface: the scope is the problem

One person has built, in one app: ride recording with sensor fusion · auto
ride detection via platform activity recognition · crash detection · a garage ·
a maintenance scheduler with 13+ service items · a social feed with votes and
comments · a follow graph with three visibility tiers · **brand/model forums**
with moderation · **1:1 chat** with server-side moderation · **group rides with
live maps and push-to-talk voice notes** · a POI directory with geohash search,
reviews and user submissions · saved routes with turn-by-turn navigation · a
badge system (674 lines) · a stats dashboard with charts · home-screen widgets
for two platforms · a QR medical-info card · emergency contacts · live-location
sharing with tokenised links · an offline outbox · GPX/JSON export · seven
colour families × two brightnesses × two shape languages · and two languages.

That's eight or nine products. The consequences are visible everywhere in this
document: the feed has no pagination because nobody had time; accessibility is
zero because nobody had time; the localisation covered whichever screens were
being touched that week; and **the one feature that justifies the whole
premise — crash detection — is the one that's switched off**, because it's the
only one that can't be finished by writing more Dart.

A blunter way to put it: voice notes for group rides shipped. Crash detection
did not. Both were built. One requires a Twilio account and a field test; the
other required `record` and `just_audio`. The scope grew along the axis of what
was buildable alone, not what the product needed.

Some specifics that stand out even inside that scope:

- **Group-ride voice notes go to public Cloudinary URLs** (§3.2). Push-to-talk
  audio between riders is stored unauthenticated, permanently, and is never
  deleted. Nobody who taps a walkie-talkie button expects that.
- **`seed_police_checkposts.js`, `_v2`, `_v3`** — three generations of the same
  seed script, all committed, each with its own test file. Plus
  `seed_ai_cameras.js`. A police-checkpoint and traffic-camera database is a
  feature with consequences that reach well past "is the code good," and it
  arrived in the repo as three unversioned seed scripts.
- **Route navigation doesn't record the ride** (`stiiLl_left.md`). Two of the
  app's core loops don't compose.
- **Crash rides have no badge in history** (`stiiLl_left.md`). A ride flagged as
  a suspected crash looks identical to a commute in the list.

---

## 6. Testing: excellent coverage of the third of the app that's easy

1,174 tests, all passing, in ~52 seconds. `flutter analyze` clean, enforced in
CI with `--fatal-infos`-equivalent strictness plus a custom grep guard against
raw `as double` casts. 1,560 lines of Firestore rules tests against the real
emulator. That's real discipline and it deserves saying plainly.

Now the shape of it:

| | |
|---|---|
| Test files | 123 (18,653 lines) |
| Files that `pumpWidget` | **18** |
| **Screens in `app/lib`** | **43** |
| **Screens with a test file** | **1** |
| `matchesGoldenFile` | **0** |

The distribution: 19 calculator test files, 16 social, 14 core/utils, 11
database. The pure functions are covered exhaustively. The 43 screens — where
every UX bug in §4 lives, where the raw-exception error states live, where the
un-paginated feed lives, where the `addPostFrameCallback` navigation lives —
have essentially no automated coverage at all.

That's not an accident, it's §2.4: nothing that touches I/O is injectable, so
nothing that touches I/O can be tested, so the tests went where the seams were.
The DI problem and the screen-coverage problem are the same problem.

Two more:

- **CI has never run.** `stiiLl_left.md`: "CI exists but hasn't run on GitHub,
  and branch protection is missing." The workflow's own comment says to mark the
  jobs as required checks — nobody has. So the discipline above is enforced on
  your laptop and nowhere else.
- **Tests hit live OSM tile servers** (`new_gravity.md §2`) — `flutter test`
  makes real HTTP requests to `tile.openstreetmap.org`. Flaky, slow, and rude to
  a volunteer-funded service.
- **No keystore backup** (`stiiLl_left.md`). Lose `throttleiq-release.keystore`
  and the app can never be updated on Play again. This is a five-minute fix that
  has been open long enough to be written down.

---

## 7. The documentation is eating the codebase

I want to be careful here, because the commenting in this repo is unusually
*good*: it explains **why**, it records the failure mode that motivated the
code, and several times while reading I understood a subtle decision purely from
a comment. That is rare and valuable.

It has also metastasised.

| | |
|---|---|
| `app/lib` total lines | 55,684 |
| Comment lines | 7,919 (~14%) |
| Handoff docs | **9,058 lines** across 8 files |
| `issues_fixed.md` alone | 5,433 lines |
| `§N` cross-references embedded in Dart source | **119** |
| Source comments pointing at `docs/Issues.md` or `claude_sol` (paths that no longer exist) | **30** |
| Comments literally reading **"issues_open.md or issues_fixed.md"** | **42**, across 28 files |

That last row is the one to sit with. Forty-two comments in the production
source say, in effect, *"this is documented in one of these two files, I'm not
sure which."* For example, `active_ride_screen.dart:195`:

```dart
/// Tapping this button IS the opt-in (DOCS/Handoff for agents and Todos/issues_open.md or issues_fixed.md §24.1).
```

That's a 78-character path, containing spaces, offering two alternatives, inside
a doc comment. It's the fossil record of an automated path-rewrite that couldn't
decide, and it was committed 28 files wide. Thirty more comments point at
`docs/Issues.md`, which was renamed on 2026-09-19 and no longer exists.

The underlying problem is that **the source has been annotated with a bug
tracker**. `§78.1`, `§33.8`, `§62`, `§24.8` appear as load-bearing references in
code comments — 119 of them. Every one is a dependency on a 5,433-line changelog
that has already been renamed once. A comment should explain the code in front
of it; if you need the ticket to understand the comment, the comment failed.

Two more symptoms:

- **`features.md` documents the bottom-nav order incorrectly** (§4.7) and opens
  by admitting it was written "by reading the screen source... not by driving
  the iOS Simulator," with "Screenshots: mostly still TODO." A 341-line document
  describing an app nobody looked at.
- **`arch.md` opens with** "offline-first motorcycle telemetry intelligence
  platform and vehicle state estimation engine" and "treats a motorcycle ride as
  an evolving continuous state vector." The engineering underneath mostly earns
  it. The register does not match a product whose social feed caps at 20 posts.

---

## 8. What is genuinely good

Not filler — these are things I went looking to criticise and couldn't.

1. **The offline-first core is real.** SQLite as sole author, outbox with
   `deferred` state on timeout, 8-second cap, sync fully decoupled from the UI
   thread, interrupted rides restored *paused* rather than silently resumed.
   The hard part of an offline-first app is the recovery paths, and they exist.
2. **The Firestore rules.** Materialising `allowedUserIds` at share time so that
   three visibility tiers become three independently-satisfiable list queries is
   a genuinely good solution to a real Firestore constraint, and it's explained
   well enough that the next person will understand it. 1,560 lines of emulator
   tests behind it.
3. **The sensor pipeline's honesty.** `impactThreshold` is labelled
   **UNCALIBRATED** with a specific warning about budget-phone accelerometer
   saturation and an explicit "re-tune from field data before any safety claim."
   Somebody resisted the temptation to ship a number they'd made up. That
   instinct is exactly right — the failure was not carrying it through to the
   README and onboarding.
4. **`notificationLog` says `mock_not_sent`, not `sent`,** with a comment
   explaining that a log saying "sent" would be read as proof someone was
   reached. Precisely the right reasoning. (§1.3 is the same reasoning not being
   applied one field over.)
5. **The Bengali font is bundled, not fetched** — with a comment about patchy
   connections for exactly the audience most likely to have them. Right call for
   the right reason.
6. **PII discipline in the functions.** Phone numbers and emails were being
   logged to Cloud Logging; that was caught and fixed, and the fix is documented
   with the threat model (default retention, project Viewers).
7. **1,174 tests, clean analyzer, custom CI lint guards.** On a solo project.
8. **The comments, taken one at a time.** §7 is a complaint about volume and
   cross-referencing, not quality. The `_peakJerkInWindow` comment explaining
   why peak beats average — `[14, 5.5]` averaging to 9.75 and dropping under a
   10.0 threshold — is better than most professional codebases manage.

---

## 9. If you fix seven things

Ordered by consequence, not effort.

1. **Resolve the crash-detection lie this week.** Not the feature — the *claim*.
   Pull it from `README.md:35`, `arch.md:5`, `onboarding_manifest.dart:152`, and
   the pitch deck. Change Settings from "not live yet" to "planned." Then decide
   separately whether to actually ship it. Right now the app tells new users on
   first launch that it will protect them in a crash, and it will not.
2. **Make account deletion delete things.** Add Cloudinary asset tracking (store
   `public_id` alongside every `secure_url`) and a signed server-side delete, and
   extend `account-deletion.ts` to comments, forums, chats, places and reviews.
   This is a Play Store requirement, not a nice-to-have.
3. **Paginate the feed and fix the "Following" chip.** Cursors on all three
   queries, a real "load more," and either a server-side following query or an
   honest empty state. Currently the social half of the app ends after 60 posts
   and one of its three tabs shows nothing to anyone with more than a handful
   of follows.
4. **One `AsyncErrorView` widget with retry**, applied to all fifteen screens
   currently printing `'$e'` in red. Cheapest large perceived-quality win
   available, and it fixes the offline-first app rendering a Firestore error code
   when you go offline.
5. **Kill `AppColors`.** `ThemeExtension<AppPalette>` + `Theme.of(context)`.
   Mechanical, large, and it deletes the full-app-remount-on-theme-change, the
   const ban, the test-state leakage, and the missing system-brightness support
   in one pass. Every week of delay adds call sites to the migration.
6. **Move the localisation budget to onboarding and the cockpit.** A
   Bangla-first rider currently gets a translated theme picker and English
   safety alerts. Reverse that. While you're there: `Semantics` labels on the
   icon-only controls, and one pass for text scaling.
7. **Turn CI on and back up the keystore.** Mark the three jobs as required
   checks on `main`; put the keystore somewhere that isn't one laptop. Both are
   under an hour, both are already written down as open, and one of them is
   unrecoverable if it goes wrong.

---

## 10. The meta-criticism

Everything in §1 is already written down in this repository. `stiiLl_left.md`
says crash detection is off. `issues_open.md §32` says Emergency Contacts is
exposed while non-functional. `uiux_critique.md` says shipping a safety feature
that admits it won't alert anyone "is worse than not showing it — it invites a
false sense of security."

That's the correct analysis. It was written on 2026-08-17. The release since
then is `beta_v3.0.1`, and in the last five commits the work was: removing a
status pill from the ride screen, retiring the likes field, and fixing a button's
height on the Places screen.

The repository has an extraordinary capacity to *observe* itself — 9,058 lines of
handoff docs, 5,433 lines of resolved issues, numbered sections that never
change, multiple AI review passes archived as `sum_claude.md`, `sum_gemini.md`,
`new_gravity.md`. What it doesn't have is a mechanism that forces the severe
findings to outrank the easy ones. Every one of those documents is append-only
and unprioritised, so "the FAB overlaps a list row" and "the crash detector is
switched off while onboarding promises it works" sit in the same file at the
same weight, and the one that gets fixed is the one that takes twenty minutes.

More critique is not what this codebase needs. It has more critique than code
in some directories. What it needs is for someone to take the critique it
already has, sort it by what happens to a rider if it's wrong, and start at the
top.

---

_Written without running the app on a device. Screenshot-level findings are
deferred to `uiux_critique.md`; everything here is traceable to a file and line._

---

## Status (2026-09-21)

Most of this was fixed the day after it was written — see
`DOCS/Handoff for agents and Todos/issues_fixed.md` §83 for the itemised
record and `issues_open.md` §83 for what remains. In summary:

**Fixed:** every false safety claim (§1, including three *more* fabricated
claims in the onboarding tour that this document missed — a lean-angle gauge,
a "SHIELD: ARMED" badge and "10Hz GPS", none of which exist); the crash
function's `'contacted'` lie plus a latent bug that would have crashed it on
first real use; the EventDetector issues; the `copyWith` trap; navigation in
`build`; account deletion; the privacy-clipper seed; feed pagination and the
broken "Following" chip; the 15 raw-exception error screens; OS dark-mode
support; and the comment rot (81 references in source, plus 28 more in
`firestore.rules` that this document didn't count).

**Still open, biggest first:** the `AppColors` static facade and the
whole-app remount it forces (§2.1) — the single largest piece of debt left;
the active-ride screen's full rebuild every second (§2.2); DI and with it the
43-screens/1-test gap (§2.4, §6); accessibility beyond tooltips and a
text-scale clamp (§4.1); onboarding still English-only (§4.2); App Check; the
unsigned Cloudinary upload endpoint; client-side-only blocking.

The meta-point in §10 stands and is the one worth acting on: this repository
is better at producing critique than at ordering it. The remaining items in
§83 should be sorted by what happens to a rider if they're wrong before any
further review pass is commissioned.
