# Auto-tracking: migration plan against the current code

Written 2026-08-16. Companion to the **Automatic ride tracking** entry in
`HANDOFF_Document.md` (assessed 2026-08-15), which is accurate and is **not**
restated here. That entry establishes what exists, what doesn't, and the three
isolate options. This document does two things it deliberately left open:

1. **Makes the isolate decision** it says to make first, with reasoning.
2. **Adds four findings it doesn't cover** — one of which is a safety issue
   that should gate the feature.

Read the HANDOFF entry first. If the two disagree, the HANDOFF entry is the
older assessment and this one is the newer; reconcile rather than assuming.

---

## Part 0 — Two corrections carried in from the assessment

Both of these are easy to get wrong on a first read of the repo and both were
gotten wrong in the conversation that produced this document, so they are
repeated here as guardrails:

- **A foreground service is not missing.** Android background GPS already runs
  through geolocator's own foreground service
  (`ride_recording_provider.dart:508`), with `FOREGROUND_SERVICE_LOCATION` and
  `ACCESS_BACKGROUND_LOCATION` in the manifest (`AndroidManifest.xml:22-23`,
  `:6`) and `UIBackgroundModes: location` on iOS (`Info.plist:79-82`). Rides
  already record with the app backgrounded. Do not add a second service.
- **`RecordingCadencePolicy` saves disk, not battery.** Its own doc comment is
  explicit that it only thins what reaches `ride_points`. GPS keeps sampling at
  `bestForNavigation` / `distanceFilter: 3` regardless. Any battery claim that
  leans on it is wrong.

---

## Part 1 — The isolate decision

**Recommendation: stage it. Option 1 first as a detection harness, then
option 3. Do not build option 2.**

### Why not option 2 (native service owns recording)

It is the technically best answer and the wrong one for where this product is.
It requires moving recording state out of `RideRecordingNotifier`'s instance
fields — that is the 1,562-line file, and the state it holds
(`_totalDistance`, `_maxSpeed`, `_movingSeconds`, `_estimator`, `_detector`,
`_cadencePolicy`, `_axisCalibrator`, the point buffer, the polyline decimator)
is load-bearing for resume, crash detection, jam time, and the axis fit. This
is a multi-week refactor of the most safety-relevant file in the app, done
before a single real rider has confirmed the *detection* even works. Wrong
order.

### Why option 1 first

Option 1 as described — background isolate writes a "ride detected at T" marker
— is dismissed in the HANDOFF entry as "a prompt, not auto-tracking." That's
correct as a shipping feature and misses its real value: **it is the cheapest
possible way to build the detection corpus the All-day auto-tracking entry says
is a prerequisite** ("Prototype the *detection* offline against recorded rides
before committing to the permission ask").

Ship it to beta testers as an explicitly-labelled experiment. Each detection
writes a row: timestamp, trigger source (AR transition vs SLC), AR confidence,
duration, coarse start/end. On next launch, ask one question — *"We think you
rode around 4:30pm. Was that: your bike / a car or bus / not a trip at all?"*

After ~200 labelled detections across ~10 riders you know your true-positive
and false-positive rate on Dhaka/Sylhet traffic, on the actual handset mix
(Xiaomi, Realme, Samsung), before spending anything on a licence or a refactor.
If the false-positive rate is bad, you've learned that for a week of work
instead of two months.

### Why option 3 second

`flutter_background_geolocation` collapses AR + SLC + foreground service +
headless task + OEM battery-killer handling into one paid dependency. Critically,
**it also dissolves the isolate problem rather than solving it**: the plugin
owns collection and persistence natively, so `RideRecordingNotifier` never has
to run headlessly. It reconciles on next launch instead.

That reconciliation is the work, and it has one concrete blocker — see finding
D below.

**Decision to record:** option 1 now, gated behind a beta flag; option 3 only
if the option-1 corpus shows detection is good enough to be worth paying for.

---

## Part 2 — Four findings the assessment doesn't cover

### A. Crash detection and auto-tracking interact badly. Gate on this.

This is the finding that matters most.

`_onCrashDetected` (`:1267`) sets `crashDetected: true`, fires
`HapticService.maxVibration()`, and starts a **60-second countdown**. If nothing
cancels it, `_handleCrashNotification` (`:1326`) writes to
`crashNotifications`, which is the Cloud Function trigger for contacting the
rider's emergency contacts.

The only cancel path is `dismissCrashAlert()` (`:1294`), **which is called from
the UI**. On a manually-started ride that's fine: the rider started the ride, the
screen is on, the alert is in front of them.

On an auto-started ride it is not fine. The phone is in a jacket pocket, the app
is backgrounded, there is no visible countdown — the rider gets a vibration they
will read as a notification, and 60 seconds later their mother gets a call
saying they've crashed.

Mitigating factors, neither sufficient:

- The crash path is currently inert — crash detection "notifies nobody (Spark
  plan)" per HANDOFF launch item 9. So this is latent, not live. It becomes live
  the moment Blaze is wired, which is an open item.
- `accel` fed to `EventDetector` is the **GPS-speed derivative**, not raw
  accelerometer, and the threshold is 80 m/s². That takes a GPS position jump,
  not a pothole — and there's a confidence gate
  (`minConfidenceForCrashAlert`, `:762`). But GPS jumps are exactly what dense
  urban canyons produce, and Dhaka is dense urban canyon.

**Required before auto-tracking ships:** crash alerts raised on an auto-started
ride must escalate through a **full-screen local notification with an "I'm OK"
action**, not just a haptic and an in-app countdown. `flutter_local_notifications`
is already a dependency. Alternatively — and simpler — **disable crash detection
on auto-started rides entirely** until the notification path exists, and say so
in the UI. A ride tracked without crash detection is honest; a crash alert
nobody can see is not.

### B. Auto-started rides have no reliable bike attribution

`startRide()` reads the bike from `_ref.read(activeBikeProvider)` (`:380`) and
bails with *"Please add a bike before recording a ride"* if it's null.

Headlessly this is worse than it looks. ThrottleIQ's maintenance model is
distance-based — service intervals, chain lube, `computeNextService`. A ride
silently attributed to the wrong bike doesn't just mislabel a row in history, it
**corrupts the maintenance math on two bikes at once**, and the rider has no
reason to suspect it.

For a single-bike rider this is a non-issue. For a multi-bike rider — exactly
the enthusiast segment this product targets — it's a data-integrity bug that
compounds silently.

Options, in order of preference:

1. **Bluetooth identity.** If a bike has a paired intercom/head unit, the
   connected device MAC identifies the bike unambiguously. Also gives you a
   near-instant trigger with no AR delay. Best answer, requires the rider to
   have the hardware.
2. **Ask, don't guess.** Auto-started rides land in a "needs confirmation"
   state and the day-end summary asks which bike. Costs one tap per ride,
   never wrong.
3. **Attribute to `activeBike` and mark the ride `bikeConfidence: low`,**
   surfacing it for correction. Acceptable only if the correction UI actually
   exists.

Do **not** ship silent `activeBike` attribution.

### C. `WakelockPlus.enable()` must not run on an auto-started ride

`startRide()` calls `await WakelockPlus.enable()` (`:444`) unconditionally.

That's correct for a manual ride — the rider slid to start and is looking at the
live screen. It is actively harmful for an auto-started one: the app holds a
screen wakelock for a phone that's face-down in a pocket. Battery cost on top of
GPS, and a hot phone against the rider's leg.

Fix is small: `startRide({bool userInitiated = true})`, and gate the wakelock on
it. Note this is *separate* from geolocator's `enableWakeLock: true` in
`ForegroundNotificationConfig` (`:511`), which is a CPU partial wakelock and
should stay.

Non-breaking: `startRide()` has only three call sites
(`record_screen.dart:240`, `:305`, `group_ride_map_screen.dart:100`), all of
which are genuinely user-initiated, so a defaulted named parameter changes no
existing behaviour.

### D. `EventDetector` is not replay-safe — blocks the option-3 reconciliation

Under option 3, fixes are collected natively and replayed through the Dart
pipeline on next launch. That works for `VehicleStateEstimator`: every entry
point takes an explicit `timestamp`, and `_rebuild`/`tick` take an explicit
`now`. It is already replay-safe.

`EventDetector` is not. `detect()` opens with `final now = DateTime.now()`
(`event_detector.dart:61`) and uses it for the 2-second crash window
(`_recentSpeeds.removeWhere(...)`) and the alert TTL. Replaying an hour of fixes
in two seconds collapses every sample into one window — the crash detector would
see the entire ride as a single instant and the jerk/speed-drop logic would
produce nonsense.

**Prerequisite refactor:** inject the clock — `detect({required DateTime now,
...})`, passing `pos.timestamp` from `_onPosition`. Small, mechanical, and it
makes `EventDetector` unit-testable against recorded rides, which you want
anyway for tuning the crash thresholds against the `falseCrashPositives`
collection you're already logging (`:1308`).

Do this one early regardless of which option you pick. It has value on its own.

---

## Part 3 — Battery, with this codebase's actual settings

Current in-ride settings are the top of the power envelope by design
(`_startLocationStream`, `:494-515`): `bestForNavigation`, `distanceFilter: 3`,
`intervalDuration: 500ms`, plus ~20 Hz accelerometer and gyro
(`:517-524`), plus a screen wakelock.

| State | Config | Cost |
|---|---|---|
| Monitoring (new) | AR transitions / SLC only, no GPS | ~3–5% **per day** |
| Candidate (new) | GPS ~10s to confirm speed | negligible per event |
| Riding — auto | proposed: `high`, `distanceFilter: 10`, no screen wakelock | ~4–6% per hour |
| Riding — manual | today: `bestForNavigation`, `df: 3`, wakelock, screen on | ~8–12% per hour |

The monitoring figure is only achievable if the trigger never touches GPS. The
moment anything polls location on a timer to "check if they're riding," you're
at 5–10%/hr and the feature is dead.

**Two recording profiles, not one.** A manually-started ride has a rider
watching the live speed readout — `bestForNavigation` and `distanceFilter: 3`
are justified there, and were tuned in response to a real "speed feels laggy"
report. An auto-started ride has nobody watching. `LocationAccuracy.high` with
`distanceFilter: 10` produces an equally good post-ride polyline at meaningfully
lower draw. This is the single biggest lever available, per the HANDOFF
assessment, and splitting the profile by `userInitiated` is how you pull it.

---

## Part 4 — The day-end summary

The request that started this was "at day end it updates you." Flagging a
conflict with existing product thinking rather than silently overriding it:

`hooked_throttleiq.md` argues for a **weekly digest, not a daily one** — "given
the loop is ride-frequency-driven (not daily), a Sunday-evening 'this week: 3
rides, 142km, chain due in 80km' notification fits the actual usage pattern
better than a daily streak nag."

That reasoning holds for a *digest*. It does not hold for a **confirmation
prompt**, which is a different thing and is genuinely daily: auto-detected rides
need labelling while the rider still remembers the trip. "Was 4:30pm your bike
or a bus?" is worthless on Sunday.

**Suggested split:**

- **Daily, and only on days with unconfirmed detections** — a confirmation
  prompt, not a summary. Silent on days with nothing to confirm. This is also
  what feeds the option-1 corpus and, later, bike attribution (finding B).
- **Weekly, Sunday evening** — the actual digest, as already specified.

Both are `flutter_local_notifications`, both read from SQLite, neither needs a
backend or the Blaze plan.

---

## Part 5 — Order of work

**Phase 0 — no auto-tracking yet, all independently valuable**

1. Inject the clock into `EventDetector` (finding D). Add unit tests replaying
   recorded rides.
2. `startRide({bool userInitiated = true})`; gate `WakelockPlus` on it
   (finding C).
3. Split the location profile by `userInitiated` (Part 3).

**Phase 1 — detection harness, beta flag, no recording**

4. Add an activity-recognition source. Manifest needs
   `android.permission.ACTIVITY_RECOGNITION`; iOS needs
   `NSMotionUsageDescription` — **neither is currently declared.**
5. Background isolate writes detection markers only. No GPS, no ride rows.
6. Daily confirmation prompt (Part 4). Log labels to Firestore.
7. Run ~200 detections across ~10 beta riders on the real handset mix.

**Decision gate.** Read the false-positive rate. If a bus ride through Dhaka
looks like a motorcycle ride more than ~15% of the time, stop and fix detection
before going further.

**Phase 2 — real auto-tracking, only if Phase 1 clears the gate**

8. Resolve crash detection (finding A) — full-screen notification, or disabled
   on auto rides. **Blocking.**
9. Resolve bike attribution (finding B). **Blocking for multi-bike riders.**
10. Licence `flutter_background_geolocation`; wire the headless task to persist
    fixes; add the launch-time reconciliation path that replays them through
    the (now clock-injected) Dart pipeline.
11. Play Store: update the Background Location Access declaration and the Data
    Safety form. `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` already needs a
    justification per HANDOFF item 10; auto-tracking makes that conversation
    harder, not easier. Budget review round-trips.

---

## Open questions

- Is `flutter_background_geolocation`'s licence cost acceptable pre-revenue?
  It's the difference between Phase 2 taking weeks and taking months.
- Does the beta cohort have enough multi-bike riders to make finding B urgent,
  or can it be deferred behind a "you have more than one bike" check?
- Should auto-tracking be offered at all on iOS before the widget/App Intents
  work lands, given iOS gives less reliable background wake than a properly
  exempted Android foreground service?

---

# Implementation status — 2026-08-16

Everything below was built in one pass. **Nothing has been compiled or run**:
`flutter analyze` and `flutter test` still need to happen on a machine with the
SDK. Treat this as "written and self-reviewed", not "working".

## Built

| Area | Files |
|---|---|
| Clock injection | `event_detector.dart` (`at:` param), replay-safety tests |
| Ride-profile split | `ride_recording_provider.dart` (`userInitiated`, wakelock gate, two GPS profiles) |
| Schema v11 | `database_helper.dart` (+`is_auto`, `bike_confidence`, `auto_detections`, `auto_fixes`) |
| Staging DAO | `auto_detection_dao.dart` |
| Background trigger | `auto_tracking_service.dart` (config + headless task) |
| Replay | `auto_ride_reconciler.dart` (pure) + `auto_ride_reconciler_service.dart` (app layer) |
| Crash escalation | `notification_service.dart` + `_onCrashDetected` wiring |
| Attribution | `bike_attribution.dart`, `BikeDao.moveRideStats`, `bike_confirmation_card.dart` |
| Notifications | crash / confirmation / day-end summary, three Android channels |
| Entry point | `auto_tracking_tile.dart` in Settings, opt-in and off by default |
| Platform | `ACTIVITY_RECOGNITION`, `USE_FULL_SCREEN_INTENT`, `NSMotionUsageDescription`, background modes, licence-key slot, Gradle repos |

## Deviations from the plan above

- **The Phase 1 harness was skipped.** The plan recommended shipping
  trigger-only detection first to measure the false-positive rate before
  committing to a licence and a reconciliation path. That gate no longer
  exists in the build — detection goes straight to creating rides. The
  measurement is still available (`AutoDetectionDao.recentOutcomes` records
  every accept/discard with its reason), but it now happens *after* riders see
  results rather than before. **Watch the discard reasons on the first beta
  cohort.**
- **`EventDetector.detect` takes `at:` as optional, not required.** Twenty
  existing call sites in `crash_detector_test.dart` rely on real-time
  behaviour; making it required would have rewritten tests that deliberately
  exercise wall-clock windows. Live and replay paths both pass it explicitly.
  New code must too — the doc comment says so.
- **Crash detection stays enabled on auto rides**, escalating through a
  full-screen notification, rather than being disabled. This is the stronger
  option and also the one with more that can go wrong: it is the single most
  important thing to test on a real device.
- **Attribution guesses and flags**, rather than asking first. The correction
  UI the plan named as a precondition for that choice is built
  (`BikeConfirmationCard`), and `moveRideStats` moves distance between bikes so
  a correction reaches the maintenance math.
- **Both a per-ride prompt and a day-end summary.** The per-ride confirmation
  fires when the journey ends, while the rider remembers it; the day-end
  summary reports and stays silent on days with no rides.

## Blocking before this can ship

1. ~~**`flutter pub get && flutter analyze && flutter test`.** None of it has run.~~
   **DONE 2026-08-17.** Run for the first time on a real toolchain — the tree
   didn't actually compile; see `Issues.md` §29 for the four breaks that
   surfaced (a dropped pub dependency, a required plugin parameter, a
   non-idempotent migration, two Android/Gradle conflicts). After fixing:
   `flutter test` 804/804, `flutter build` clean on iOS and Android.
2. **Licence key.** `AndroidManifest.xml` has
   `PASTE_LICENCE_KEY_BEFORE_RELEASE`. Release builds will not start the
   plugin without a real key from transistorsoft. Still open.
3. **On-device crash-alert test.** Force a crash signal with the phone locked
   and confirm the full-screen notification appears and "I'm OK" cancels the
   countdown. This is the one path where a bug contacts someone's family.
   Still open — needs a physical device.
4. ~~**Migration test.** `upgradeSchemaForTesting(db, 10, 11)` — the ladder is
   the failure mode that bricks the app for riders who already have rides.~~
   **DONE 2026-08-17.** This is exactly the test that caught the non-idempotent
   `is_auto`/`bike_confidence` columns in §29 — it was already written, it just
   had never been run before.
5. ~~**Bangla strings.** `AutoTrackingTile` and `BikeConfirmationCard` use
   English literals.~~ **DONE 2026-08-17.** Both widgets, plus
   `AutoTrackingNotifier`'s four failure messages, now read from
   `AppLocalizations`; `enable()` returns a typed
   `AutoTrackingEnableFailure` enum instead of an English string so the
   provider layer never has to know a locale. `arb_parity_test.dart` passes,
   including its Western-digits check (the first Bangla draft used Bengali
   numerals in the battery figure — the test catches exactly that).
6. **Play Store.** Background Location Access declaration and Data Safety form
   both change. `ACTIVITY_RECOGNITION` is a new sensitive permission. Still
   open.
7. **Battery measurement.** The 3–5%/day figure in the settings copy is from
   published telematics benchmarks, not from this app. Measure it before
   leaving that number in front of riders. Still open.
8. **Home-screen widgets, 2026-08-17.** Expanded from 3 to 4 (added Start
   Auto-Tracking) and the iOS `ThrottleIQWidget` extension target — previously
   just loose Swift files with a README describing a manual Xcode "New
   Target" flow — is now actually registered in `Runner.xcodeproj`, built
   programmatically with the `xcodeproj` Ruby gem rather than by hand (see
   `ios/ThrottleIQWidget/README.md`). Verified via `flutter build ios
   --simulator` and `pluginkit -m -p com.apple.widgetkit-extension` listing
   `com.bft.throttleiq.ThrottleIQWidget` on the built app. **Still needs an
   Apple Developer account**: with no signing team in this environment, iOS
   disallows custom entitlements even on the simulator, so the App Group is
   structurally wired but not yet functional — the widgets will appear in the
   picker but keep showing placeholders until a team is assigned in Xcode
   (Signing & Capabilities, both targets) and the App Group registers for
   real. See the README's "What's NOT done" section.
9. **Directions now starts a ride, 2026-08-17.** Tapping "Directions" on a
   place detail screen (`place_detail_screen.dart`) starts recording before
   handing off to the external maps app, so a rider who navigates externally
   still gets a ride logged. Silent on failure by design (no bike, no
   permission, already recording) — the primary action is directions, not
   the ride. Not yet confirmed on a device: starting the recording provider
   requires location permission, and a permission *prompt* needs the app in
   the foreground, which is why the ride-start call happens before
   `launchUrl` rather than after.

---

# Update — 2026-08-28: the licence-cost open question, answered

The first "Open questions" item above — *"Is `flutter_background_geolocation`'s
licence cost acceptable pre-revenue?"* — is answered: no, not for now. Rather
than pay it, the plugin was replaced with a free stack
(`flutter_activity_recognition` + `flutter_foreground_task`), a deliberate
decision to stay on the free tier for roughly the next three months. Full
writeup in `Issues.md` §50; pros/cons for revisiting the paid plugin later
are in `HANDOFF_Document.md`'s Feature Backlog, under "Automatic ride
tracking"; the old implementation is archived at
`docs/archives/flutter_background_geolocation-2026-08-28/`.

This does not change anything else in this document — Parts 0–5 above
describe the detection/reconciliation architecture, which the swap left
untouched (`AutoDetectionDao`, the schema, `AutoRideReconcilerService` are
all unchanged). Only *which plugin feeds the DAO* changed.
