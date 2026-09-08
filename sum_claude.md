# ThrottleIQ — Project Summary (Claude Edition)

> Two independent passes over the same repository, written for two different readers.
> **Part 1** is for an engineer: what's actually built, how it's wired together, what's fragile, and where it's headed.
> **Part 2** is for a marketer or founder: who this is for, why it wins, and how to get it in front of riders.
>
> Everything below is grounded in the current tree as of **2026-09-06**: app version `1.0.0-beta.2.2+7`, **908/908 Flutter tests green** (`flutter test`, run live for this doc), app id `com.bft.throttleiq`, license **ThrottleIQ Source-Available License (TSAL) v1.0** (viewable, not forkable). Where something is written but not yet live (Cloud Functions escalation, App Store), that's called out explicitly rather than glossed over — the project's own `docs/planning/Issues.md` and `HANDOFF_Document.md` are unusually disciplined about this distinction, and this summary tries to inherit that discipline rather than oversell.

---

# PART 1 — TECHNICAL SUMMARY & FUTURE ROADMAP

## 1. What ThrottleIQ actually is

ThrottleIQ is a Flutter mobile app that turns an ordinary smartphone into three things a motorcycle otherwise lacks: a **black box** (GPS + IMU telemetry, recorded continuously, offline), a **maintenance brain** (distance-driven service tracking across 13+ component types), and a **safety net** (multi-signal crash detection, cancellable countdown, live location sharing, an offline medical QR card). Layered on top is a social/utility layer — forums, group rides with push-to-talk, a POI directory, saved routes — built to keep the app relevant between rides, not just during them.

The engineering thesis, stated plainly in the codebase's own doc set: **the local SQLite database is the source of truth, always**. Nothing about starting, recording, pausing, resuming, or finishing a ride depends on network availability. Cloud sync, sharing, and social features are strictly additive and asynchronous. This single invariant shapes almost every architectural decision described below, and it's the reason the app can credibly promise to work in a Dhaka data dead zone or a Sylhet hill pass with zero bars.

## 2. Stack at a glance

- **Framework:** Flutter 3.3+/Dart 3.3+, Material 3.
- **State:** `flutter_riverpod` (providers + StateNotifiers throughout).
- **Routing:** `go_router`, declarative, with modal and nested-tab hierarchies.
- **Local persistence:** `sqflite`, schema currently at v12 with additive `_addColumnIfMissing` migrations (no destructive migrations — a deliberate constraint given rides already exist on testers' devices).
- **Cloud:** Firebase Auth (email/password + Google Sign-In) + Cloud Firestore, rules-gated per-user (`/users/{uid}/...`), on the **Spark (free) plan** — this ceiling matters, see §5.
- **Media:** Cloudinary (not Firebase Storage — Storage needs Blaze; Cloudinary sidesteps that with unsigned upload presets for photos and PTT voice clips).
- **Maps/GIS:** `flutter_map` + OpenStreetMap tiles, Overpass API for POI seeding, Open-Meteo for keyless weather context.
- **Audio:** `record` + `just_audio` + `audio_session`, tuned for Bluetooth SCO/A2DP routing to helmet intercoms (Sena/Cardo/FreedConn-class hardware).
- **Native bridges:** `home_widget` (Android AppWidgets + iOS WidgetKit), `flutter_foreground_task` + `wakelock_plus` for background durability, `firebase_crashlytics` (added 2026-08-28, diagnostics-only — no behavioral analytics SDK anywhere in the app).
- **Testing:** 908 Flutter tests (pure-logic calculators fixture-tested against real Dhaka/Chattogram coordinates; DAOs run against real in-memory SQLite via `sqflite_common_ffi`, not map-based fakes — this distinction previously caught a real transaction-deadlock bug that mocks couldn't see, `Issues.md` §7) plus a separate Firestore-rules emulator suite (73 tests as of the last full count).

## 3. The telemetry pipeline — the actual core IP

The part of this codebase that isn't "just another Flutter CRUD app" is the sensor pipeline. It's a roughly ten-stage pipe from raw hardware to a stored, queryable ride:

1. **Collection** — `geolocator` streams GPS fixes (distance-filtered, ~1 Hz), `sensors_plus` streams 3-axis accelerometer and gyroscope.
2. **Validation** (`SensorValidator`) — single choke point that rejects GPS fixes with horizontal accuracy worse than 25 m, velocity spikes above ~70 m/s, negative delta-times, and IMU noise spikes. Nothing downstream sees unvalidated data.
3. **Time sync** — motion derivatives (velocity, acceleration, jerk) are computed from device **monotonic** clock deltas, not wall-clock timestamps, so NTP jumps or clock changes mid-ride can't corrupt the math.
4. **Sensor fusion** (`VehicleStateEstimator`) — a complementary filter merges GPS heading, gyro yaw rate, and accelerometer impulses into a single `VehicleState` per tick.
5. **Confidence scoring** — a 0–100 heuristic score from GPS HDOP/accuracy and IMU noise floor. This score isn't cosmetic — it directly gates the crash-alert path (see below), which is the difference between "phone dropped in a tunnel" and "silently misses a real crash."
6. **Motion classification** — per-tick flags: `isMoving` (≥1.0 m/s), `isStopped`, `isCornering` (yaw-rate threshold), `isBraking` (<-2.0 m/s²), `isAccelerating` (>2.0 m/s²).
7. **Event detection** (`EventDetector`) — hard braking (<-4.0 m/s²), rapid acceleration (>3.5 m/s²), overspeed (>100 km/h), fatigue alert (>90 min continuous riding), and the crash signature.
8. **Adaptive recording cadence** — on a straight, confident, event-free stretch, points are thinned to one every 5 seconds instead of every 1 second; any turn, brake, or acceleration event forces full-fidelity recording. This is a real storage/battery optimization, not a gimmick — it's the difference between a ride log that's usable for months and one that bloats the local DB.
9. **Spatial baselining** — road segments are bucketed into precision-7 geohash cells (~150 m) to build per-road speed baselines without licensing a commercial road network. This underpins the "faster than usual here" outlier insight (§4.2) and is explicitly a stopgap for full map-matching (Tier 3 roadmap, below).
10. **Ride-level analytics** (`RiderStatsSummary`, `RidingScore`) — aggregate stats, peak values, moving-vs-jam time split, and a 0–100 smoothness score.

### Crash detection, specifically

This is the subsystem most worth scrutinizing, because a false positive (waking someone at 2 a.m. over a pothole) or a false negative (missing a real crash) are both unacceptable failure modes. `EventDetector` requires a **strict, chronological, multi-part signature** before it will fire:

1. Acceleration spike >80.0 m/s² (~8.2g),
2. A high-rate rotational jerk within milliseconds of that spike,
3. Speed collapse to <1.0 m/s within a 2-second post-impact window,
4. **and** the whole path is suppressed if `VehicleState.confidence < 40` — so a GPS-multipath tunnel doesn't fire a false alarm just because the position data is briefly garbage.

Even after all four conditions are met, the alert doesn't escalate immediately: a **60-second, cancellable, full-screen countdown** with haptics and audio gives the rider a chance to say "I'm fine, that was just a big pothole" before anything is sent to a contact. This cancellation window is a UX decision as much as an engineering one, and it's the right one for a v1 — automatic 911 dispatch on a first-generation heuristic classifier would be irresponsible.

## 4. Feature inventory (what's actually built and wired, not aspirational)

Reading `app/lib/features/` directly: `auth`, `ride`, `stats`, `routes`, `garage`, `maintenance`, `social`, `forums`, `chat`, `poi_directory`, `profile`, `moderation`. Each is a real, tested feature, not a stub:

- **Ride recording** — background foreground service, screen-off/pocket-safe, with interrupted-ride recovery (`ride_resume.dart`): if the OS kills the app mid-ride, on relaunch it reconstructs the polyline, moving time, top speed, and distance from persisted SQLite points and offers *Resume / End & Save / Discard* rather than silently losing the ride.
- **Offline outbox** (`core/cloud/outbox_service.dart`) — ride finalization and live-share teardown write locally first, then queue in a durable SQLite `outbox` table with exponential backoff (30s → 30min cap), specifically to dodge the "Firestore write hangs forever with no exception when offline" failure mode. Notably, **this isn't universal yet** — offline maintenance-log writes still go through the plain `SyncManager` path rather than the outbox, a known inconsistency (see §5).
- **Auto-tracking** — `flutter_activity_recognition` + `flutter_foreground_task` detect vehicular motion without a manual tap, with an `AutoRideReconciler` that filters out short walks/subway rides by velocity and distance thresholds.
- **Post-ride analytics** — speed-banded polylines (Idle/Normal/Brisk/Hard), jam-time vs. moving-time split, a geohash-based "faster than usual here" outlier insight, offline turn-by-turn from any saved ride (`turn_instruction.dart` derives directional cards from polyline geometry — no external routing API), and GPX/JSON export.
- **Garage & maintenance** — multi-bike garage with a real Bangladesh-market brand/model catalog (`bike_catalog.dart`: Yamaha, Bajaj, TVS, Honda, Suzuki, Royal Enfield, Hero, Runner, with model-variant normalization, e.g. grouping FZS V2/V3/V4), distance-driven tracking across 13+ service types (oil, filters, chain, brakes, coolant, spark plug, valve clearance, battery, clutch cable, suspension) plus custom user-defined services, and durable local tombstones so a deleted bike/log can't resurrect via a stale sync.
- **Social** — follow + audience-tiered ride sharing, upvote/downvote, brand/model forums that roll individual-model discussion up into the parent brand forum, a moderation feature area, and 1:1 direct messaging (`features/chat`) — Firestore-rules-enforced to exactly two participants, no delete/hide capability yet, messages persist for the life of the account (this is now correctly disclosed in the privacy policy as of 2026-09-05, see §6).
- **Group rides** — join by a 6-character code (no invite friction), live shared map with 5-second position broadcasts, per-member color rings, stale-marker fade after 30s, and push-to-talk voice intercom routed through paired Bluetooth helmet hardware.
- **POI directory** — fuel/garage/parts/recreation categories, seeded from OpenStreetMap/Overpass (395+ verified Dhaka-metro points via `scripts/seed_dhaka_places.js`), geohash-indexed for viewport queries, with ratings/reviews and one-tap "Directions + auto-start recording" combined into a single gesture.
- **Safety** — SafeQR (fully client-side, offline-readable medical card: blood type, allergies, conditions, medications, emergency contacts, encoded as a standard QR via `qr_flutter` — no app install required to read it) and a live-tracking web viewer (`public/live-viewer.html`, zero-dependency, Firebase-Hosted, token-based unguessable URLs or vanity `/r/{username}` links).
- **Home-screen widgets** — 4 Android/iOS widgets (Start Ride, Start Auto-Tracking, Ride Stats, Next Service — the last one flips to a high-visibility red when overdue).
- **Appearance system** — 7 color families (Carbon Mono, Editorial, Nocturne, Trail Social, Calming, Retro Monochrome, Analyst Blue) × 2 shape vibes (Boxy/Curvy) × 2 brightness modes, each with matching control styles (slide-to-start vs. hold-to-start ring). This was recently audited (`Issues.md` §58) after a marketing page understated it as "two themes" — the app itself has shipped all 7 for a while; the docs/marketing surface just hadn't caught up.
- **Bengali localization** — bundled variable font for fully offline rendering, with a deliberate safety rule: numerals stay Western (0–9) even in Bengali text, because glanceability through a helmet visor matters more than localization purity for speed/distance readouts.

## 5. Known technical debt (an honest list, not a hidden one)

The project's own `Issues.md`/`HANDOFF_Document.md` are unusually candid about this, so it's worth carrying that candor into this summary rather than smoothing it over:

1. **`ride_recording_provider.dart` is a ~1,800-line monolith** — GPS streaming, sensor fusion, DB buffering, wakelock orchestration, live-session publishing, outbox enqueueing, and crash-modal state all live in one provider. The natural split (session lifecycle / GPS+polyline handling / crash-alert coordination / live-session broadcasting) is identified but not yet executed.
2. **Crash-alert SMS/email escalation is written but not deployable.** The Cloud Functions code (`functions/src/crash-notifications.ts`) exists and is presumably correct, but Cloud Functions deployment requires the Firebase **Blaze** billing plan, and the project is still on Spark. This is disclosed honestly in-app (per `Issues.md` §24.8) — no store listing claims automatic emergency escalation works today.
3. **Sensor thresholds are theoretical, not empirically validated.** The 80 m/s² crash threshold, the 4.0/3.5 m/s² braking/accel thresholds, etc. were set from first principles, not from a corpus of real crash/near-miss telemetry across different phone-mounting setups (tank bag, handlebar clamp, jacket pocket). This is the single highest-value thing beta telemetry could fix.
4. **The offline outbox isn't universally applied.** Ride-share and live-session teardown use the durable SQLite outbox; maintenance-log writes while offline still go through the plain sync path. Same retry-backoff logic, different code path — worth unifying.
5. **iOS background durability has an OS-level ceiling.** A force-swipe from the App Switcher kills auto-tracking; this needs to be documented for users, not engineered around, since it's an iOS platform constraint.
6. **Almost nothing has been tap-tested on a real device end-to-end.** Per the project's own handoff doc, most of the recent work has landed via an agent environment without device/emulator access — verification is `flutter analyze` (clean) + the test suite (908/908 green) + successful release builds, which verify correctness of logic, not feel-of-use. This is the actual pre-launch QA backlog, and it's a meaningfully different risk than "untested code": the logic is tested, the *device behavior* (permissions prompts, battery behavior, background service survival across OEM skins like Xiaomi/Samsung's aggressive battery managers, which are notorious in the Bangladesh Android market) is not yet confirmed.
7. **Google Sign-In was recently root-caused and fixed (2026-09-05, `Issues.md` §61)** — a debug-keystore SHA-1 was never registered with the Firebase Android app, so any debug build hit `DEVELOPER_ERROR` on tap. Fixed by registering the SHA-1, no app code changed. Worth flagging because it's a reminder that "auth doesn't work" bug reports in this codebase are as likely to be Firebase-console config gaps as Dart bugs — worth checking `firebase apps:android:sha:list` before assuming a code defect.

## 6. Recent notable work (last ~2 weeks, for continuity)

- Google Sign-In debug SHA-1 fix + removal of the login-screen logo (2026-09-05).
- `public/privacy.html` updated to disclose direct messages as a stored data category, and the Play Store Data Safety worksheet updated to match (2026-09-05) — both were real disclosure gaps against a shipped, live chat feature, not cosmetic fixes.
- A repo-wide dead-internal-link sweep across `docs/`, `store_listing/`, and root `README.md` following the 2026-08-28 docs restructure (60+ links fixed, verified back to zero broken).
- The marketing poster set grew from 6 to **12** themes (see Part 2, §11) — `07-highway-telemetry`, `08-privacy-shield`, `09-resale-passport`, `10-offline-deadzone`, `11-fatigue-alert`, `12-group-beacon` — plus a new standalone `public/install.html` landing page (dark, blue/orange/lime accent system, Android APK + iOS early-access CTA) that didn't exist in the previous project snapshot.
- Play Console internal testing track has a build uploaded and marked `completed` via the Android Publisher API, but **zero testers were assigned** as of the last handoff entry — this is a Play-Console-UI-only step (the API's `edits.testers` only accepts a Google Group, not individual emails), so it's a manual action item, not something further automation can close.

## 7. Future roadmap — organized by how far out it is

**Near-term (vehicle-state accuracy):**
- Replace the complementary filter with a 9-DOF Extended Kalman Filter (position/velocity/orientation/sensor-bias states) to hold dead-reckoning accuracy through GPS outages (tunnels, flyovers, multi-story parking).
- Gyroscopic lean-angle telemetry — isolate lateral centripetal acceleration + roll rate to compute continuous lean angle, max lean, and corner entry/exit speed asymmetry.
- User-configurable alert thresholds (Urban Commute / Highway Touring / Track Day presets) instead of hardcoded 100 km/h overspeed and fixed accel/brake limits.

**Mid-term (AI/predictive):**
- An on-device TFLite/ONNX classifier trained on real accelerometer/gyro waveforms to distinguish genuine crash impacts from Dhaka-grade potholes, speed bumps, and railway crossings — directly addresses debt item #3 above.
- Predictive maintenance forecasting (regression on riding intensity — jerk, hard-braking frequency, stop-and-go time — rather than static km intervals) for chain wear, brake pad life, and oil breakdown.

**Long-term (connected/navigation):**
- Real offline map-matching (Valhalla/GraphHopper) and a motorcycle-specific "curviness-optimized" route planner — the current geohash baselining (pipeline stage 9) is an explicit stopgap for this.
- BLE OBD-II / TPMS hardware integration for real RPM, throttle position, coolant temp, and tire pressure.
- Crowd-sourced, geohash-indexed, TTL-expiring hazard pins (checkpoints, construction, flooding, oil spills).

---

# PART 2 — MARKETING SUMMARY

## 8. The one-sentence pitch

**ThrottleIQ is the machine memory a motorcycle was never built with** — it silently remembers every kilometer, every service interval, and every ride, and it keeps working when the signal doesn't. Built specifically for South/Southeast Asian commuter and touring riders, not adapted from a Western fitness or car-navigation app.

## 9. Why this market, why now

Across Bangladesh (and comparable South/Southeast Asian markets), the motorcycle isn't a weekend hobby — it's the primary tool of daily mobility for millions of commuters navigating Dhaka and Chattogram traffic on 100–160cc bikes. And yet this rider has been almost entirely ignored by mobility software:

- **No black box.** A car has a trip computer; a motorcycle's ride data vanishes the second the engine turns off.
- **Maintenance by memory.** Service history lives in a rider's head or a paper notebook. In a market with heavy used-bike turnover, undocumented service history directly destroys resale value and causes preventable breakdowns.
- **Real safety stakes.** Solo highway riders who go down face genuinely dangerous delays before anyone knows to look for them.
- **Foreign apps don't fit.** Strava treats a ride as a workout. Rever/Calimoto assume an adventure bike, a data plan, and Western pricing (\$39–\$59/yr) that doesn't match local willingness-to-pay. None of them work offline the way a prepaid-data commuter needs, and none are localized for Bengali riders, Bengali bike models, or Bengali roads.

ThrottleIQ's answer is blunt and specific: **100% offline-first, zero data burned while recording, a real local motorcycle catalog, and a maintenance system that ties directly to resale value** — not a repackaged fitness tracker.

## 10. Who it's for — three personas, three pitches

**1. The Daily Commuter** (the volume base) — 20s–30s, rides a Yamaha FZ-S / Bajaj Pulsar / TVS Apache / Hero Glamour class bike, prepaid data, plans to sell the bike in 2–3 years.
> *"Never forget an oil change. Track your jam hours. Build a service record that actually raises your resale price. Runs on zero data."*

**2. The Enthusiast/Tourer** (the vocal advocates) — rides an R15/MT-15, CBR, Gixxer SF, or Royal Enfield; runs with a club on weekend highway trips (Cox's Bazar, Sylhet, Sajek); already posts riding content.
> *"Turn your phone into a race dash. See your whole crew on a live map with push-to-talk — no \$300 intercom hardware required."*

**3. Anxious Family** (the adoption catalyst, often a non-rider) — the spouse or parent who texts "reached yet?" every time someone leaves for a night ride.
> *"If they go down, you don't have to wait to find out. Live location, a cancellable crash alert, and a link that opens in any browser — no app install needed on your end."*

## 11. What the go-to-market motion already looks like on disk

This isn't hypothetical positioning — the repo already contains real launch collateral, and it's grown recently:

- **`public/install.html`** — a standalone, dark-themed landing page (blue/orange/lime accent system matching the app's own palette) with an Android APK download CTA and an iOS early-access signup, clearly built for a direct link-share launch motion (Facebook groups, WhatsApp, QR stickers) rather than waiting on store approval.
- **A 12-poster campaign** (`website_demo/assets/posters/`, print + web + SVG, each with a matching QR block) covering: jam-counter signal, pump/maintenance reminders, garage proof-of-service, rate-it reviews, black-box safety, crew/community, **highway telemetry, privacy shield, resale passport, offline dead-zone, fatigue alert, and group beacon** — the last six added most recently, extending the campaign from core-feature awareness into safety/privacy/resale trust messaging. These read as street-poster/garage-counter/fuel-pump collateral, matching the "zero paid ad budget, grassroots community channel" GTM approach documented elsewhere in the project.
- **The live-share tracking page doubles as a funnel.** Every emergency/location-share link a rider sends a family member is a zero-cost acquisition surface — "Tracked with ThrottleIQ — Install Free" on a page a non-user is *already* looking at because someone they care about is riding.
- **Play Console internal testing is live** (build uploaded, marked complete) but has **zero testers assigned** — this is the single concrete, immediate blocker between "built" and "in a beta rider's hands," and it's a five-minute manual step (Play Console → Testers tab → paste emails), not an engineering task.

## 12. The moat, stated precisely

Against Strava (fitness-first, degrades offline), Rever/Calimoto (Western pricing and assumptions, no offline reliability guarantee), Detecht (crash-detection-only, needs active data), and hardware GPS trackers (\$40–100 + a SIM fee):

1. **Offline is structural, not a feature flag.** SQLite-first architecture means "works without signal" is true by construction, not by a fallback mode bolted on.
2. **Maintenance-to-resale is a category no competitor plays in.** Nobody else ties recorded odometer distance to component wear *and* frames that as a resale-value asset — turning a recreational tracker into a daily-use utility with a financial reason to keep opening the app.
3. **Localization runs deep, not just UI strings.** A real Bangladesh bike/brand catalog with model-variant grouping, Bengali typography with a specific Western-numeral safety rule for visor glanceability, and OSM-seeded local POIs — this is the kind of detail a Western incumbent's localization pass typically skips.
4. **Zero hardware, zero subscription friction at the free tier.** No box to wire in, no SIM to provision, no forced trial-to-paywall wall on the core safety/tracking features.

## 13. Retention: why this doesn't die between rides

The single biggest failure mode for any ride-tracking app is that it provides zero value on the days someone doesn't ride — and most riders don't ride daily. ThrottleIQ's answer is to make the *non-riding* moments useful too:

- **Proactive maintenance pings** ("your chain lube is due in 80 km") pull a user back into the app on a maintenance day, not just a ride day.
- **The Next Service home-screen widget** turns "is my bike due for service" into a glanceable fact, no app-open required, with the red-flip-when-overdue treatment doing real behavioral nudging.
- **The garage tab as a pre-ride checklist** gives the app a reason to be opened in the 30 seconds before a weekend trip, independent of whether GPS tracking happens that day.
- **Community surfaces (forums, feed, group rides)** give a reason to open the app on a day the bike stays in the garage entirely.

## 14. Honest gaps a marketer needs to know before writing copy

Because the technical section above isn't decorative — it directly constrains what's safe to claim publicly right now:

- **Do not claim automatic SMS/email crash escalation.** It's coded, not deployable (Blaze billing gate). The in-app copy already says this correctly; store-listing and poster copy must match it.
- **Do not claim App Store availability.** Only Android internal testing exists; no public store listing on either platform yet.
- **The 7-theme Appearance system is real and shippable, but only 2 of 7 color families have marketing screenshots today** (Carbon Mono, Editorial) — a documented, deliberate gap (`Issues.md` §58): the team chose not to claim more in the gallery than it can show, which is the right instinct to preserve when writing new copy.
- **Direct messaging is real** (1:1, rules-locked to participants, no delete) and is now correctly disclosed in the privacy policy — any "your data" trust messaging should reflect that chats persist for account lifetime, same as everything else.

## 15. Messaging bank (existing, worth reusing consistently)

- **Global tagline:** *ThrottleIQ — Machine Memory for Motorcycles.*
- **Commuter angle:** *Works when your signal doesn't. Remembers what your bike needs.*
- **Safety angle:** *Someone will know if you go down.*
- **Bengali primary:** *বাইকের হিসাব থাকুক ফোনেই — অফলাইনেও প্রস্তুত।*
- **Bengali safety:** *সে রাইডে, আপনি নিশ্চিন্তে।*

---

*Compiled directly from the current repository state (app `1.0.0-beta.2.2+7`, 908/908 Flutter tests passing, git HEAD at commit `e3724ae`), cross-checked against `docs/planning/HANDOFF_Document.md` and `docs/planning/Issues.md` rather than restated from memory, so the "known gaps" sections above should stay reliable even as marketing copy gets drafted from this document.*
