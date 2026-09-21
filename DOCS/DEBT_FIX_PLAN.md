# Debt fix plan

_Written 2026-09-21 (evening). Baseline: `main` @ `0222f03`. Numbers below were
re-measured that evening, not copied from the older docs — several had drifted._

This turns `BIGGG_JOBB.md` §6 ("Known debt NOT in the queue") into an ordered plan.
It follows the rule in `BIGGG_JOBB.md` §9: **order by what happens to a rider if the
item is wrong, not by how fast it closes.** It is a plan, not a review — nothing here
is new critique.

Every step ends on the four gates in `BIGGG_JOBB.md` §2, and follows its traps
(§3): no `dart format` across `lib/`, `issues §N` references, tests never touch the
network.

## The measured baseline

| Debt | Ref | Now |
|---|---|---|
| Bare `catch (_)` | §83.14 | **56**, 10 with empty bodies |
| Direct `FirebaseFirestore.instance` | §83.13 | **23** uses in 21 files; `FirebaseAuth.instance` **10** |
| Screens vs screen tests | §83.28 | **43 screens, 1 `*_screen_test`**, 23 files call `pumpWidget`, **0 goldens** |
| `.select(` uses | §83.12 | **12** (was 3 before the cockpit fix) |
| Accessibility | §83.22 | **6** `Semantics(`, **0** `semanticLabel`, 69 `tooltip:`; text scale clamped to 1.0–1.3× in `lib/app.dart:232` |
| Onboarding mockups | §83.26 | `onboarding_ui_mockups.dart` is **1,175** lines |
| Crashlytics call sites | — | **4** in all of `lib/` |

## Sequence at a glance

| # | Work | Size | Blocked on | Why here |
|---|---|---|---|---|
| 1 | Make silent failures visible (§83.14) | S — 1 day | nothing | Cheapest, and it tells you what the rest of the debt costs in production |
| 2 | Injectable I/O seams (§83.13) | M — 3–4 days | nothing | Unlocks 3, 4 and the device-free ride tests |
| 3 | Test the presentation layer (§83.28) | M→L, ongoing | 2 | Every UX defect in §83 lived here |
| 4 | Scale-tolerant layouts + semantics (§83.22) | M | 3 (to prove it) | Outdoor, gloved, sunlit use is the core case |
| 5 | Real onboarding screenshots (§83.26) | S–M | nothing | Removes a file that already fabricated three claims |
| 6 | Blocking, server side (§83.18) | needs a decision | founder | Design call, not a coding task yet |
| 7 | Cloudinary upload abuse (§83.16) | needs a decision | founder | Spark plan constraint |
| 8 | Housekeeping | S | nothing | Small, and one has a clock on it |

1 and 5 can run any time and in parallel with the 2→3→4 chain.

---

## 1. Make silent failures visible (§83.14) — S

**Problem.** 56 `catch (_)` blocks; 10 are empty. Only 4 places in the whole app talk to
Crashlytics, so a failure inside any of these is reported by riders as "it just didn't
work" and never reaches the dashboard.

**Plan.**
1. Add one helper in `core/` — `reportSilently(Object e, StackTrace st, {required String where})`
   — that calls `FirebaseCrashlytics.instance.recordError(e, st, fatal: false)` and is a
   no-op in debug and in tests (same pattern as `analytics_service.dart`). It must itself
   never throw.
2. Triage all 56 into three buckets, in a table in the PR description:
   - **Genuinely expected** (a cache miss, a parse of untrusted input, a permission that
     may legitimately be denied) → keep, but add `on Type` where the type is known and a
     one-line reason in a comment.
   - **Best-effort by design** (the `timesRidden` bump, telemetry) → keep, route through
     `reportSilently` so a *rate* is visible.
   - **A real failure being swallowed** → handle it, or surface it to the rider through
     the existing `ErrorView`/`mapFirestoreError` path.
3. Start with the 10 empty ones and anything under `features/ride/`, `core/cloud/` (outbox
   and sync) — a failure there loses a rider's data.
4. Add a ratchet: a script test that counts `catch (_)` in `lib/` and fails if the number
   goes **up** from a checked-in baseline. Not a lint rule — 56 → 0 is not the goal, "no new
   ones without a reason" is.

**Done when:** the 10 empty catches are gone; every remaining bare catch either has a
reason comment or reports; the ratchet test is in CI.
**Risk:** low. The one trap is a `reportSilently` that throws inside a catch — test it.

## 2. Injectable I/O seams (§83.13) — M

**Problem.** Nothing that touches I/O can be substituted, so nothing that touches I/O is
tested. `RideRecordingNotifier` (`ride_recording_provider.dart:202`) news up its own DAOs,
calculators and four coordinators; `FirebaseFirestore.instance` is called directly in 21
files. `CrashCoordinator` already accepts an injected Firestore — the pattern is known,
the notifier just calls the no-arg constructor.

**Plan — seams first, no behaviour change, one PR per step so each is reviewable:**
1. `firestoreProvider`, `firebaseAuthProvider` (and `currentUidProvider`) in `core/cloud/`.
   Convert the 23 + 10 direct call sites file by file. Mechanical; the analyzer and the
   existing 1,298 tests are the safety net. Add a grep guard (like §1's ratchet) so a
   24th `FirebaseFirestore.instance` fails CI.
2. `RideRecordingNotifier`: take its collaborators through the constructor with the current
   concrete types as defaults, wired in the provider. Then extract the four things the
   GPX replay harness could not reach — `Geolocator` (position stream + permission +
   services check), the foreground service, the wakelock, persistence — behind small
   interfaces. **These four are exactly what `issues_open.md` §78.21 says only a real ride
   could check.**
3. File-level singletons like `maintenance_provider.dart`'s `final _dao = MaintenanceDao()`
   become providers.

**Done when:** a test can construct `RideRecordingNotifier` with fakes and drive a ride
start → fixes → pause → resume → stop with no platform channel; `FirebaseFirestore.instance`
appears only in the provider file.
**Risk:** medium — this touches the ride loop. Keep every step behaviour-neutral and land
each with the full suite green. Do not combine with §83.12 profiling.

## 3. Test the presentation layer (§83.28) — M, then ongoing

**Problem.** 43 screens, 1 screen test, 0 goldens. The pure calculators are covered
exhaustively; the layer where every §83 UX defect lived is not.

**Plan.** Order by rider consequence, not by screen count:
1. **Ride recording** (start / pause / resume / stop / discard, the crash-badge on the
   summary, the navigation banner) using the seams from §2. This is the highest-value
   suite in the app.
2. **Auth and sign-in**, **the outbox / "Sync issues" screen**, **maintenance** (the
   escalating pill).
3. **Goldens** for ~6 key screens across the appearance combinations. The palette work
   made this possible (`AppColorPalette` / `AppShapeProfile` are `ThemeExtension`s;
   `themeFor` in `app_theme_style_test.dart` avoids the google_fonts download — see
   `BIGGG_JOBB.md` §5, JOB 1). The 28 combinations are what `app/scripts/ui_tour/run_tour.sh`
   already walks. Check goldens in at one text scale first; goldens are per-platform, so
   generate them on the same machine class CI uses.
4. Every new screen after this ships with at least a smoke `pumpWidget` — put that in the
   PR checklist, not in a rule.

**Done when:** the ride flow, sign-in and outbox have widget tests that fail when their
behaviour breaks; goldens exist for the six screens.
**Trap:** tests must never touch the network (§3.9); use the existing seams (§3.10).

## 4. Scale-tolerant layouts and semantics (§83.22) — M

**Problem.** Text scale is clamped to 1.0–1.3× because the layouts overflow above that,
not because it is a design choice. There are 6 `Semantics(` widgets and no
`semanticLabel`; the 69 tooltips help but do not name the cockpit's numbers.

**Plan.**
1. With §3's infrastructure, add a **scale sweep test** that pumps the key screens at
   1.0 / 1.3 / 1.6 / 2.0 and fails on a `RenderFlex overflowed` — this makes the problem
   measurable before it is fixed.
2. Fix the fixed-height cockpit rows, chips and stat tiles first (they are what is read
   mid-ride). Prefer `Flexible`/`Wrap`/`FittedBox` and intrinsic heights over per-screen
   font shrinking.
3. Raise the clamp in `app.dart` in steps — 1.3 → 1.5 → 2.0 — only as the sweep passes.
4. `Semantics` on the cockpit: speed, distance, elapsed, and the active alert should read
   as one sentence each ("Speed 42 kilometres per hour"), not as loose digits. Bangla
   labels go through l10n like everything else and into `bn_pending_review.txt`.

**Done when:** the sweep passes at 2.0× and the clamp is gone or ≥ 2.0.
**Note:** the 2026-09-21 Bangla tour ran at text scale 1.0 only, so this is also the
first real look at Bangla at larger scales.

## 5. Real onboarding screenshots (§83.26) — S–M

**Problem.** `onboarding_ui_mockups.dart` (1,175 lines) is a hand-drawn copy of screens,
shipping in the binary, with nothing to catch drift. It already invented a lean-angle
gauge, a "SHIELD: ARMED" badge and "10Hz GPS".

**Plan.**
1. Extend `integration_test/ui_tour_test.dart` (it already exists) to capture the
   half-dozen screens the onboarding tour depicts, with seeded demo data.
2. Ship them as compressed assets per locale; the onboarding slides show images instead
   of widgets. Watch the APK budget (currently 84.7 MB) — WebP, and only the screens shown.
3. Delete the mockups file. Add a version stamp in the asset folder and a test that the
   manifest and the assets agree, so a screen redesign that skips the regenerate step is at
   least loud.

**Done when:** the file is gone and no onboarding slide draws a UI by hand.
**Cost to be honest about:** screenshots need a simulator, so they regenerate by hand
(`run_tour.sh`), not in CI. That is still strictly better than a copy nobody diffs.

## 6. Blocking, server side (§83.18) — needs a decision first

**Problem.** Blocking is a client `.where()` in `visibleFeedProvider`: a blocked rider's
content is still downloaded by the blocker, and the blocked rider can still read the
blocker's public content.

**Why this is not a coding task yet.** Firestore rules cannot filter a *list* query by a
per-document lookup unless the query itself constrains the field, so the obvious
`exists(blocked/...)` rule does not work for the feed. Realistic options, none free:
- **Single-document reads** (a ride, a profile, posting a comment): rules *can* check a
  `blocked` doc there — worth doing, and testable in the rules emulator. This closes "the
  blocked rider reads the blocker's content" for direct access, not for listing.
- **Feed downloads:** needs either a `not-in` on the query (small block lists only) or a
  server-side edge, which means Functions — and Functions means Blaze.

**Ask the founder:** ship the single-document rules and document the listing gap, or wait
for a server. Do not start before that answer; a half-built version gives false safety.

## 7. Cloudinary upload abuse (§83.16, §33.5, §63.3) — needs a decision first

**Problem.** Cloud name and unsigned preset are in the APK; anyone can upload arbitrary
media to the account, and group-ride voice notes live at permanent public URLs.

**What is possible on Spark:**
- **Now, no code:** lock the `throttleiq_unsigned` preset in the Cloudinary dashboard —
  allowed formats, max file size, locked folder, a usage alert. This is in `needs_attention.md`
  and is a dashboard task, so it needs a browser session signed in as the founder.
- **A signing proxy that is not Cloud Functions:** a small free-tier edge worker (for
  example Cloudflare Workers) that verifies the caller's Firebase ID token and returns a
  Cloudinary signature. It works without Blaze, but it is **new infrastructure and a new
  vendor**, so it needs the founder's sign-off. Once it exists, `CloudinaryUploadService`
  requests a signature before each upload and the unsigned preset is turned off.
- Voice-note expiry: set the preset to auto-expire / auto-delete voice notes so they are
  not permanent.

**Ask the founder:** dashboard lock-down only, or also a signing proxy.

## 8. Housekeeping — S

- **Gradle 8.13 → ≥ 8.14.** The release build prints "Flutter support for your project's
  Gradle version (8.13.0) will soon be dropped." Found this evening when building the
  release. Bump `app/android/gradle/wrapper/gradle-wrapper.properties`, rebuild APK + AAB.
  Do it before it becomes a hard failure.
- **Functions on Node 22.** The clock in `BIGGG_JOBB.md` §4 — Node 20 is decommissioned in
  late October 2026. Not fixable without Blaze; the decision should be *made*, not drift
  past the date.
- **Profile the cockpit on a device** (§83.12): the fix is structural and unmeasured.
  `record_screen.dart` (lines ~91, 314, 423) still watches the whole state.
- **§83.23 leftovers that need a decision:** localized month names with Western digits (the
  `DateFormat` / Bengali-digit conflict), and the logic-layer messages that reach the UI in
  English (`group_ride_repository`, `group_ride_selection`, `profile_repository`,
  `place_entity`) — copy the `recordingErrorText()` pattern: keep English in state, localize
  from a stable code in `presentation/`.
- **Stale local branches** (`appcolors`, `i18n`, `job3-ux`, `job4-infra`, `fix/critique-83`,
  `fix/grill-78`, and any others already merged): confirm each is an ancestor of `main`
  (`git branch --merged main`), then delete. They are noise now that everything is merged.
- **`firestore.rules:306`** compiler warning ("Invalid type. Received one of [null]…") is
  benign and pre-dates this work; leave it.

## What this plan deliberately does not do

- More critique passes (`BIGGG_JOBB.md` §9).
- Crash detection, the Blaze upgrade, the §32 taste calls — settled decisions
  (`BIGGG_JOBB.md` §4).
- The pitch deck.
