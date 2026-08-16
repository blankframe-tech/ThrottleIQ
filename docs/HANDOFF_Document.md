# ThrottleIQ — Handoff Document

_Last updated: 2026-08-17 · Branch: `main`_

This is the single living handoff doc for the project: current status, known
limitations, the near-term to-do list, the longer-term feature backlog, and
the Vehicle State Engine architecture/roadmap. Update it (don't fork a new
doc) whenever status changes — see `.claude/settings.json` for the hook that
prompts this after every work session. Feature-by-feature UI detail lives in
`Features.md`; tracked defects live in `Issues.md`.

> **Start here if you're picking this up right now:**
> [`WHAT_TO_DO_NOW.md`](WHAT_TO_DO_NOW.md) — a short, dated checklist for
> the immediate state of the tree (everything as of 2026-08-11 is now
> committed and pushed; what's left is a device pass that nothing else can
> substitute for). It is a **snapshot,
> not a second backlog**, and is meant to be deleted once worked through —
> everything durable belongs in this file.

**Contents**
- [Part 1 — Status & Handoff](#part-1--status--handoff)
- [Part 2 — Feature Backlog & Ideas](#part-2--feature-backlog--ideas)
- [Part 3 — Vehicle State Engine: Architecture & Roadmap](#part-3--vehicle-state-engine-architecture--roadmap)

---

## Part 1 — Status & Handoff

### TL;DR — where things stand

As of 2026-08-02, the app is pre-launch at **`1.0.0-beta.2+2`, tagged
[`beta-v2`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v2)**
— that release carries both a signed APK (for handing to testers directly)
and an AAB (for the Play Console), and is the build intended for the 12-dev
closed-testing group. `beta-v1` remains on GitHub as the previous build.
Core ride-recording, garage, maintenance, social, POI-directory, and
forum features are built and wired end-to-end — the 2026-07-14 audit's
orphaned screens (crash countdown, sync manager, exports, emergency
contacts, live share) have all since been wired in, see "Done, but NOT yet
verified" below. The Vehicle State Engine's foundation (Phase 1 + 1.5 —
sensor fusion, confidence scoring, motion classification, adaptive
recording thinning) shipped 2026-07-23, and the test suite is **755/755
green** as of 2026-08-12.

**Versioning reset 2026-08-01:** the old `2.0.0-beta.x` line, its git tags,
and all prior GitHub Releases (including the same-day `carbon-ui-` one)
were deleted in favor of a clean `1.0.0-beta.1+1` / **Beta v1** start —
that was the first build meant for external (non-owner) hands (the line has
since moved on to `beta-v2`; see the TL;DR above for current state). The
`carbon-mono` branch was also deleted; `main` now carries both UI modes via
the runtime theme toggle below, so the branch no longer serves a purpose.

**Backlog pass, 2026-08-01 (later the same day):** the whole of
`TODO next.md` and the codeable half of the "To do" list below were worked
through in one session. Landed: forum moderation + rider-created forums,
ride captions + Strava-style route maps on feed cards, a `recreation`
place category, **saved routes with offline turn-by-turn navigation**
(new `features/routes/`), expanded + rider-nameable maintenance types,
the maintenance bottom-nav bug fix, average speed redefined as
distance ÷ moving time, GPS trail sync, **home-screen widgets** (Android
working; iOS needs one Xcode step), the published privacy policy, and
beta data-reset tooling. Test suite went 287 → **550**.

**Auto-tracking foundation + a stale-UI sync bug, fixed and build-verified,
2026-08-17.** A prior session built the Vehicle State Engine's background
auto-detection layer (`docs/AUTO_TRACKING_PLAN.md`) and, separately, tracked
down why a second device could show fewer rides than the phone indefinitely
(`Issues.md` §28 — a provider invalidation gap, not a sync failure). Both
landed uncommitted, and neither had been run through a real `flutter`
toolchain. This session did: `flutter analyze` alone reported 0 errors, but
a real build surfaced four separate breaks invisible to static analysis —
a dropped pub dependency, a plugin's now-required parameter, a
non-idempotent schema migration, and two native Android/Gradle conflicts —
all fixed, see `Issues.md` §29. After the fixes: `flutter test` **797/797**,
clean `flutter build` on both iOS and Android, and a live `flutter run` on
the iOS simulator gave §28's fix its first runtime confirmation (stat strip
reads 42 rides / 119 km, matching the on-device sqlite dump). Test suite
grew 755 → **797**.

**Bangla parity, a fourth home-screen widget, iOS widget wiring, and
directions-starts-a-ride — 2026-08-17 (same day, later session).** Closed
three of `AUTO_TRACKING_PLAN.md`'s blocking items and did one thing the plan
didn't ask for:
- `AutoTrackingTile` and `BikeConfirmationCard` now read from
  `AppLocalizations` instead of English literals; `AutoTrackingNotifier.enable()`
  returns a typed `AutoTrackingEnableFailure` enum rather than an English
  string, since the provider layer has no `BuildContext` to localize from.
- Added a **Start Auto-Tracking** home-screen widget (Android + iOS) —
  opens Settings rather than flipping the switch itself, for the same reason
  Start Ride only navigates: the tap has no foreground window for a
  permission prompt or a failure to surface in.
- **The iOS `ThrottleIQWidget` extension target is now registered in
  `Runner.xcodeproj`.** This used to be a manual "add through Xcode's New
  Target flow" step (hand-editing `project.pbxproj` was judged too risky to
  script) — it was scripted anyway, with the `xcodeproj` Ruby gem building
  the identical target/build-phase/entitlements structure Xcode's GUI would
  have produced. Hit and fixed two real issues along the way: appending the
  "Embed Foundation Extensions" phase after Flutter's "Thin Binary" script
  phase produced a build-graph cycle (fixed by reordering it before that
  phase), and a file reference created with a bare filename resolved to the
  wrong path because its parent group carries no `path` of its own (fixed by
  matching the sibling `.xcconfig` references' full relative path). Verified
  with `flutter build ios --simulator` and `pluginkit -m -p
  com.apple.widgetkit-extension` listing the extension on the built app.
  **Not yet functional**: with no Apple Developer team assigned in this
  environment, iOS disallows custom entitlements even on the simulator
  (confirmed via `codesign -d --entitlements`), so the App Group is
  structurally wired but inert until someone opens Xcode and picks a team for
  both targets — see `ios/ThrottleIQWidget/README.md`.
- Tapping **Directions** on a place detail screen now starts a ride before
  handing off to the external maps app (Google/Apple Maps), so navigating
  externally still gets a ride logged. Not requested by the plan; requested
  directly and implemented as a deliberate exception to "don't act without
  confirmation" — starting the recording provider is silent-on-failure by
  design (no bike, no permission, already recording), so a rider who only
  wanted directions never sees an error from it.

Verified: `flutter analyze` 0 errors, `flutter test` 804/804, clean
`flutter build` on both platforms.

**Bottom-nav "Garage" renamed to "Profile", on a branch — 2026-08-17 (same
day, third session).** Requested directly, and built on `feature/profile-tab`
rather than `main` since it touches the nav shell. The Profile tab
(`/home/profile`, née `/home/garage` — path kept for a smaller diff, see
`Features.md` §4) now leads with a profile summary plus **Notifications**
and **Settings** entry points moved off `RecordScreen`'s header, with the
existing bike garage underneath as a "Your Bikes" section. `RecordScreen`
now carries no header chrome at all — recording controls only.
`NotificationBellButton` was pulled out to `shared/widgets/` so both screens
can use it. Verified: `flutter analyze` 0 errors, `flutter test` 804/804,
clean builds on both platforms, and confirmed on the iOS simulator — the tab
reads "Profile" with a person icon and Record's header is empty. Interactive
tap-through past the tab bar itself wasn't reliably automatable in this
headless environment (same standing limitation as `Issues.md` §15); the new
screen's content is verified by code review and widget composition rather
than an on-screen tap.

**`feature/profile-tab` merged to `main`, and the widget App Group is real
on a device for the first time — 2026-08-17 (same day, fourth session).**
Merged (fast-forward) and pushed. Then, launching on Abraar's iPhone (cabled)
surfaced the gap `Issues.md` §29 had flagged but not yet hit: `Runner.xcodeproj`
had no `DEVELOPMENT_TEAM` anywhere, so `flutter build ios --release` refused
outright, and forcing it with `-allowProvisioningUpdates` failed again
against a team ID guessed from a certificate string rather than read from
Xcode's own account list. Fixed by setting `DEVELOPMENT_TEAM = NJ4675FFUX`
(the real team, "Abrar Masud Nafiz (Personal Team)") on all three targets —
see `Issues.md` §30 for the part that would have shipped silently broken:
cached provisioning profiles from before the App Group existed had an
**empty** `application-groups` entitlement, which is not a build error, just
a widget that shows placeholders forever. Confirmed installed and running
(non-zero PID) on the physical device via `xcrun devicectl`.

**Three real defects were surfaced and fixed along the way** — all worth
reading in `Issues.md`: live-share sessions were **world-listable** by
unauthenticated clients (§3), the planned live-session TTL policy could
never have deleted anything (§4), and the GPS-trail sync **crashed the app
outright** (§11).

⚠️ **If you handed anyone the `beta-v2` build, it crashes.** That release
(2026-08-01) contains the nested-array trail upload: Firestore refuses the
payload with a native exception that Dart cannot catch, so the app aborts
from a background timer shortly after any ride syncs — no user action
involved, which is why it read as random. Fixed 2026-08-03 in `1fca84e`.
**Cut a beta-v3 before the 12-dev group gets anything**, and don't
diagnose crash reports against beta-v2.

**Pitch site added, 2026-08-02:** a static, dependency-free pitch/marketing
page now lives at `website_demo/index.html` (was an empty placeholder
folder before this), plus `website_demo/ui.html` — a real-UI preview page
(headless-screenshotted from the `designs/` Carbon Mono / Editorial mockup
HTML, saved to `designs/screenshots/`) linked next to Roadmap. No app code,
behavior, or build changed — this is collateral only, not shipped with the
app.

**Hooked Model doc added, 2026-08-02:** `docs/hooked_throttleiq.md` applies
Nir Eyal's Trigger/Action/Variable-Reward/Investment framework to the app,
grounded in the actual codebase (what's live vs. dormant/absent — e.g.
badges and rank-up fire with no celebration moment, `ChallengeType.streak`
is an unused enum, no push/scheduled notifications exist at all yet). It
explicitly avoids re-listing what's already backlogged in Part 2 below;
read it alongside Part 2 rather than as a competing plan.

**Marketing doc added, 2026-08-02:** `docs/marketing.md` — a BD-market
go-to-market plan for the Play Store → iOS TestFlight → App Store launch
sequence, targeting 1,000+ DAU. Surfaced two real, checked gaps worth
fixing before spending on acquisition: `public/live-viewer.html` has no
install call-to-action at all, and there's no Bangla anywhere (UI or Play
Store listing). Builds on `hooked_throttleiq.md` for retention rather than
duplicating it.

Every judgement call made along the way is written up in
`Assumptions Made.md` — read that before questioning why something was
scoped the way it was.

**Just shipped (earlier that day):** a rebrand / theming pass — a new dual theme system
(*Carbon Mono* dark instrument-panel theme, default, vs. *Editorial* light
warm-paper theme; `app_theme_style.dart` + `theme_style_provider.dart`)
wired into Settings' Appearance section, new logo/icon assets
(`app/assets/icons/throttleiq-icon-{dark,light}.svg`) replacing the old
`designs/logos1/` set, and a docs cleanup that removed a dozen stale
planning docs in favor of this file, `Features.md`, and `Issues.md`. The
default (Carbon Mono) theme has been run and screenshotted on the iOS
Simulator, and Beta v1 was run in release mode on a physical iPhone before
this release went out — see "Done, but NOT yet verified" for exactly
what's still unproven (the Editorial toggle itself hasn't been tap-tested
live on a device, only exercised via new automated provider tests).

**Skins — nine palettes behind a dropdown, 2026-08-11.** Settings'
Appearance switch was a two-up segmented control carrying a label *and* a
description per option at full width — the affordance that does not
survive being divided nine ways. It is now a **dropdown**, and the theme
list grew from 2 to 9: the seven style directions from the
`ThrottleIQ Style Directions` deck (Nocturne, Trail Social, Calming,
Positive Vibes, Retro, Analyst Blue, Genesis) joined Carbon Mono and
Editorial. The deck specifies oklch; those were converted to sRGB, and
tokens no direction named (most define no `secondary`; none define
shimmer or status colors) were **derived in the same oklch space** rather
than borrowed from a neighbouring skin. Full table and the
add-a-skin recipe are in `Features.md` §8.

Three things worth knowing before touching this area:

- **`style == carbonMono` is no longer "is this dark".** It was the test
  for base brightness, the `ColorScheme` variant, the status-bar icon
  color and which app mark to show — and it silently means "light" for
  the four new dark skins (Nocturne, Trail
  Social, Analyst Blue, Genesis). `AppColorPalette` now carries an **`isDark`**
  flag and every one of those call sites reads it. A test asserts each
  palette's flag agrees with its background's actual luminance.
- **The skin catalogue is compiler-enforced.** `forStyle` and the
  label/description lookups are exhaustive switches with no `default`, so
  a new enum member without a palette or a name fails the build instead of
  rendering as Carbon Mono.
- **Persisted values are asymmetric on purpose.** New skins round-trip
  through `AppThemeStyle.name`; Carbon Mono and Editorial still *write*
  their legacy `carbon`/`editorial` spellings so a rollback to an older
  build keeps the rider's setting. An unrecognised value falls back to
  the default rather than throwing.

Covered by 14 new tests (`test/features/profile/skin_dropdown_test.dart`,
`test/core/theme/app_theme_style_test.dart`, plus additions to the
provider and logo suites); suite is **640/640 green**.

**Device run, 2026-08-11 — partially verified, still not tap-tested.** Ran
on a cabled iPhone (iOS 27.0) in debug: 74.8s Xcode build, 25.5s install,
**no ad-hoc signing failure — `flutter clean` was not needed**, so the
§iOS-install fix above is not a required pre-step every time. Confirmed
live off the Dart VM Service rather than by eye, since no screenshot or
tap tooling exists here for a physical device (see `Issues.md` §15):

- The root key read `MaterialApp-[<AppThemeStyle.editorial>]` — the app
  booted on **Editorial**, decoded from the legacy `editorial` string in
  SharedPreferences. **That's the backward-compatibility path confirmed on
  a real device**, not just in a test, and it is the single thing most
  likely to have silently reset every existing rider to the default.
- App reached `RecordScreen` inside `AppShell` signed in, no Dart
  exceptions after launch.

**Second run, same day — the picker has now been used on device.** The
app was relaunched after a `Lost connection to device` (the phone was still
`connected` per `devicectl`, so the debug connection dropped rather than
the cable) and came back up keyed
**`MaterialApp-[<AppThemeStyle.genesis>]`**. The persisted skin had changed
from `editorial` to `genesis` between runs, and `setStyle` is only
reachable from the dropdown's `onChanged` — so the picker was tapped on the
phone, a **brand-new skin was selected, and it survived an app restart**.
That exercises the new `AppThemeStyle.name` persistence encoding on a real
device, end to end, which the legacy-decode check above could not.

Genesis then rendered `RecordScreen` with **zero exceptions, zero
`RenderFlex` overflows** in either run's log — at the device's actual
`textScaler: 1.1176` with bold text. That is independent corroboration that
`Issues.md` §16 was a false alarm.

Still unproven: **six of the nine skins have never been applied to a real
screen** (everything except Carbon Mono, Editorial, and Genesis), and no
screen beyond Record has been seen under any non-default skin. The two
worth checking first are still Retro (ink-black `border` token) and
Positive Vibes (white `surface` on near-white `background`).

**Correction, same session:** a suspected text-scaling clipping bug in the
picker was filed and then **disproved by measurement** — see `Issues.md`
§16. No code change; the attempted fix was a no-op that would have been a
touch-target regression had the assumption behind it been true. The device
observation that prompted it stands and is worth carrying: this project's
test iPhone runs at **textScaler 1.1176 with bold text**, while every
widget test runs at 1.0.

**Technique worth reusing:** when you can't screenshot a physical iOS
device, `ext.flutter.debugDumpApp` over the VM Service's HTTP endpoint
gives you the live widget tree — which screen is mounted, which widgets
exist, and (because `app.dart` keys `MaterialApp` on the theme style) which
skin is applied. `curl "$VM_URI/getVM"` for the isolate id, then
`curl "$VM_URI/ext.flutter.debugDumpApp?isolateId=$ID"`.

`_flutter.screenshot` returns "Could not capture image screenshot" — the
device log gives the real reason: **`Compressed screenshots not supported
for Impeller`**. That's the renderer, not the device, so it will fail on
the simulator too, and no amount of retrying helps. For real pixels you
need host tooling (`brew install libimobiledevice` → `idevicescreenshot`);
none is installed.

**`Lost connection to device` was not the device.** Two `flutter run`
sessions died that way mid-session and were misread first as the phone
sleeping. The actual cause: a **concurrent Claude Code session** working in
`repos/life-manager` runs `pkill -f "flutter run"` in its launch script —
an unscoped pattern that kills every `flutter run` on the machine, not just
its own. `devicectl list devices` reporting the phone as `connected` right
after a "lost connection" is the tell that nothing was wrong with the
device.

**It happened again on 2026-08-11, from this side.** A ThrottleIQ session
ran bare `pkill -f "flutter run"` twice to stop a simulator run — the exact
pattern this note warns about — while the life-manager session was live.
So this is not a one-way hazard to defend against; it is a rule *this*
repo's sessions have already broken, and the fix has to be applied here
too, not just expected of the other side.

Two things follow. **Scope any `pkill` to the device id** (`pkill -f
"flutter run -d <udid>"`) — and note that even that self-kills if the
pattern also matches the shell running the compound command that contains
it. And when you just need the app on the phone rather than a hot-reload
session, **skip `flutter run` entirely**: `flutter build ios --debug`, then
`xcrun devicectl device install app --device <udid>
build/ios/iphoneos/Runner.app` and `xcrun devicectl device process launch
--device <udid> com.bft.throttleiq`. A debug bundle carries its own
`kernel_blob.bin`, so it runs standalone — no host process to lose, and
nothing for another session to kill. You give up hot reload and the VM
Service tree dump described above.

**Docs review, 2026-08-04:** a pass through this file, `Issues.md`,
`Features.md`, and `TODO next.md` to compile a "what's next" punch list
found that **`TODO next.md` is entirely stale** — all 10 of its items
(Strava-style route maps on shared rides, captions, recreation places +
saved routes, turn-by-turn nav, the garage-forum cache, new forum
topics, rider-created forums with maintainers, the beta data-reset, the
start-ride/stats/maintenance widgets, and the maintenance bottom-nav
bug) are already shipped per `Features.md`. Nothing in it is open work;
it's safe to delete or archive rather than treat as a backlog.

**iOS install failure — root-caused 2026-08-04. Previously mis-diagnosed
here as a timing "flake"; that was wrong.**

Symptom: `flutter run --release -d <device>` fails at install with the
useless "Could not run ... Try launching Xcode". Sometimes an immediate
retry appeared to fix it, which is what made it look like a flake.

**Actual cause:** `objective_c.framework` gets embedded **ad-hoc signed**
(`flags=0x2(adhoc)`, `TeamIdentifier=not set`) while every other framework
carries the Apple Development identity. iOS refuses to install a bundle
containing an ad-hoc-signed framework. `codesign -vvv` reports the
framework "valid on disk", so it looks fine — you have to check the
*identity*, not validity.

That framework comes from `path_provider_foundation` → `objective_c`,
which builds via Flutter's **native-assets / build-hooks** system (the
same subsystem behind the `Target native_assets required define SdkRoot
but it was not provided` warning in build logs). Stale native-asset output
gets re-embedded without re-signing.

**Fix: `flutter clean && flutter pub get`, then rebuild.** That forces the
native-assets step to re-run and the framework to be signed properly —
verified: `flags=0x0(none)`, Apple Development identity, installs first
try with no retry.

⚠️ **That is not the only cause of this symptom — 2026-08-11.** A release
run hit the identical "Could not run … Try launching Xcode" message, but
the ad-hoc diagnosis did **not** apply: the very next command,
`xcrun devicectl device install app` against the same
`build/ios/iphoneos/Runner.app` that `flutter run` had just refused,
installed it successfully on the first try, and the app launched and ran.
Nothing was cleaned or rebuilt in between.

So the failure was in **`flutter run`'s own install step**, not in the
bundle. Treat the message as "the install failed, cause unknown" rather
than as a signature of the signing bug — and **check with `devicectl`
before spending five minutes on a `flutter clean`**, since that is both the
faster diagnostic and, when it succeeds, the fix. This is a second reason
to prefer the build-install-launch sequence below over `flutter run` on a
physical device.

**Getting the real error.** `flutter run` hides it. Use:
```
xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app
```
which names the offending framework and the `0xe8008014` code directly.
Then compare identities:
```
codesign -dvv build/ios/iphoneos/Runner.app/Frameworks/<name>.framework
```
Ad-hoc means the build didn't re-sign it; clean and rebuild.

Related: `flutter devices` often can't see the iPhone at the default
timeout even when `xcrun devicectl list devices` reports it as
`available (paired)`. Use `--device-timeout 30`; the device shows up.

**Ride survival, discard, Retro-as-terminal, Record redesign, model-only
forums — 2026-08-11 (later the same day).** Five requested changes; the
first is the one with teeth.

The defects and gaps behind these are written up in `Issues.md`
**§18–§21**; the Retro/Record/forums items are design changes, not defects.

- **Quitting the app mid-ride no longer ends the ride** (§18). `recoverCrashRide`
  finalized a dangling ride on next launch and filed it in history, so
  swiping ThrottleIQ out of recents at a fuel stop split a ride in two with
  no way to continue the first half. It's now `restoreInterruptedRide`,
  which brings the session back **paused** — distance, top speed, moving
  time, route and ride clock intact — and lets the rider resume, end and
  save, or discard. The screen says "Ride kept from last time" so a paused
  ride nobody paused doesn't read as a bug.
  - Aggregates rebuild from the fixes already on disk (new pure
    `ride_resume.dart`, 9 tests). **Elapsed time is the exception** — it is
    not derivable from the fixes (a ride that sat 40 minutes at a chai
    stall spans far more wall-clock than it recorded), so it's snapshotted
    to prefs every 10s, forced on pause and on backgrounding.
  - **The first fix after any resume drops its derivatives**
    (`_skipNextDistanceDelta`). `MotionCalculator` otherwise measures
    straight across the break: pause, van the bike home, resume, and the
    ride gains the van journey as one straight line. This was already
    latent on ordinary pause/resume; a pause that now survives a restart
    makes the gap unbounded, which is what turned it from theoretical into
    something worth fixing.
  - **Honest gap:** hard-brake / rapid-accel / high-jerk counts restart at
    0 on a resumed ride. They come from `EventDetector`'s live thresholds
    over a continuous sample stream and thinned stored points cannot
    reproduce them. Documented rather than guessed at.
- **Discard ride** (`cancelRide`, §20) — deletes the row and its points, ends
  the live session, clears the `/r/{username}` pointer, drops buffered
  points rather than flushing them. A ride that never reached
  `status = 'completed'` is invisible to every query and to the sync layer,
  so nothing about a discarded ride ever left the device.
- **Retro is now a black-and-white terminal**, per the request, built off
  the deck's Rawblock geometry rather than its mustard/rust palette. It is
  the **first skin that is not purely a palette swap**: square corners, 2px
  ink rules, monospace body type. New `AppTypography` swaps the display
  face alongside `AppColors`, applied together in one place so a skin can't
  half-apply. Full detail and the accessibility trade (severity encoded in
  value, not hue, because a monochrome skin has no red to spend) in
  `features.md`.
- **Record screen redesigned** as an instrument panel: bike-photo hero with
  the greeting overlaid, a rides/km/**current streak** strip, and
  slide-to-start pinned outside the scroll view. The bike picker became a
  sheet; its regression test still guards "picking a bike switches it in
  place, without navigating".
- **"Your bikes" forums are model-only.** Owning one Yamaha used to enrol
  you in the brand forum too, burying the bike you cared about under every
  Yamaha thread ever posted. Brand forums are now opt-in via discovery,
  where **Topics** also moved (Brands and Topics are two labelled groups
  under "Find a forum" rather than Topics being its own section).

**One defect was found while fixing another** (§19): a ride killed
mid-flight left `livePointers/{uid}` still resolving, so anyone holding the
rider's permanent `/r/{username}` link stayed parked on the last position
from before the app died. Same bug class as §3 and §14. Note for whoever
touches this area next — **every** ride teardown path has to clear that
pointer, and there are now four of them.

Suite went 640 → **678 green**, `flutter analyze` clean (0 errors, 0 new
warnings). Also fixed a pre-existing failure in the (uncommitted)
`app_theme_style_test.dart` (§21): every `AppTheme.build` call leaked a
google_fonts download failure onto an unawaited future — the app ships no
font assets and `flutter_test` fails every HTTP request — which failed
whichever test happened to be running when it landed, not the one that
caused it.

**Runs on device in release; still not *seen*.** A release build was built,
installed and launched on the cabled iPhone (iOS 27.0) the same night —
`com.bft.throttleiq` confirmed still running minutes later, so it clears
Firebase init and renders. Debug on the iOS 26.5 simulator boots clean too,
no Dart exceptions in either.

That is where verification stops. Sign-in needs real credentials and there
is no sign-in or tap automation here, and no screenshot tooling for a
physical device — so the redesigned Record screen, the hero, the Retro
skin, the forums changes and the whole kill-and-resume flow are
analyzer-, test- and boots-without-crashing-verified, and nothing more.
**Nobody has looked at them.** Same standing limitation as every previous
session; the ordered device pass that closes it is in
[`WHAT_TO_DO_NOW.md`](WHAT_TO_DO_NOW.md).

**Bike photos can be cropped — 2026-08-11 (same session).** Picking a bike
photo now goes into an in-app cropper (Free / 1:1 / 4:3 / 16:9 + rotate),
and an attached photo gets **Crop** and **Replace** buttons under the
preview. Built rather than pulled in as `image_cropper`, whose native screen
would be the only one in the app that ignores the rider's skin. Full
rationale in `features.md` §4.

Two notes for whoever works on this next:

- **The three-way file split is load-bearing, not tidiness.** `flutter_test`
  runs widget code in a fake-async zone where real file reads and image
  decodes never complete — the first attempt at a widget test for the
  cropper **hung rather than failed**, which is the worst way for this to
  present. Pulling the pixel pipeline out into
  `core/utils/image_crop_io.dart` with an injectable output directory made
  it testable in an ordinary `test()`. Keep I/O out of `State` methods here.
- **Cropped photos land in the app documents directory**, unlike
  as-picked ones which keep their `ImagePicker` cache path. That's a partial
  fix to the stale-path problem `BikePhoto` already works around — worth
  finishing by copying *every* picked photo somewhere durable, which would
  make `BikePhoto`'s fallback a real edge case rather than routine.

Suite 678 → **717 green** (39 new: 29 geometry, 10 pixel pipeline),
`flutter analyze` clean, simulator build clean, and a **release build with
the cropper in it is installed and running on the iPhone** — launched
without incident, though as ever nobody has been past sign-in to look at it.

**The devicectl runbook was used in anger and worked.** Going straight to
`flutter build ios --release` → `xcrun devicectl device install app` →
`devicectl device process launch` installed first try, no failure and no
`flutter clean` — corroborating the ⚠️ added to the iOS-install section
above rather than leaving it a one-off observation. Prefer this sequence
over `flutter run` on a physical device.

Minor device-state note: two ThrottleIQ builds are now installed on that
phone (the pre-cropper one from earlier the same night, and this one). Same
bundle id, so iOS shows one icon and the newer install wins — but delete the
app and reinstall if anything ever looks stale.

**Per-skin shape + a Dhaka places seed — 2026-08-12.** Two independent
pieces of work; neither blocked the other.

**1. Skins now differ in shape, not just palette.** Shape used to be shared:
`AppTheme.build` computed `isTerminal ? 0 : shared`, so all eight non-Retro
skins took the same near-zero instrument-panel radii, and nine visually
distinct directions had identical corners. A palette swap alone can't carry
"Positive Vibes" (health-app energy) away from "Analyst Blue" (a monitoring
console) — the corner radius does as much of that work as the accent hue.

New `core/theme/app_shape_profile.dart` adds a third axis alongside
`AppColorPalette` and `AppTypography`: three profiles (**boxy**, the
historical radii unchanged; **rounded**, 8/10/16/20 with true pills;
**terminal**, Retro's square corners and doubled rules), assigned per skin by
an exhaustive switch. Trail Social / Calming / Positive Vibes round off; the
five dashboard/console/premium/print skins stay boxy. Full table in
`Features.md` §8.

Three things worth knowing before touching this area:

- **`AppDimensions` is now a runtime-swappable facade**, exactly like
  `AppColors` — that is *why* this was a small change. All 96 existing
  `AppDimensions.radius*` call sites across 36 files were untouched; they
  just read the active profile now. Applied from the same
  `ThemeStyleNotifier._applyTokens`, so color + shape + type still land
  atomically and a skin can't be half-applied.
- **The one migration cost was `const`.** The radii stopped being
  `static const`, which broke exactly 8 `const` expressions that had
  embedded them: 5 bottom-sheet `RoundedRectangleBorder`s (dropped the
  `const`), and 3 widgets — `EditorialCard`, `InkPanel`, `RideRouteMap` —
  whose `radius` *parameter defaulted* to a token. Those are now nullable
  with the token resolved in `build`. `flutter analyze` found all 8; there
  was no third category. Note that `paddingSm…Xl`, `bottomNavHeight` and
  `appBarHeight` were deliberately left `static const`: a skin changes how
  the app looks, not where things sit, and keeping spacing constant is what
  makes "no hierarchy change" structurally true rather than a promise. A
  test asserts it.
- **This is the first skin work that has actually been *seen* rendered.**
  Not on a device — via a throwaway golden-image harness (`--update-goldens`
  on a temporary test that pumped a real card/chip/progress/field/button
  stack under each profile, then read the PNGs, then deleted itself). Text
  renders as boxes there (no font assets in the test env), but shape does
  not, which is all this change is. Carbon Mono sharp, Positive Vibes and
  Trail Social visibly rounded with stadium chips, Retro square with 2px
  rules — all as intended, same layout in every one. **Worth repeating this
  trick** for any future purely-visual change: far cheaper than a simulator
  run, and it produces something you can actually look at.

**2. `scripts/seed_dhaka_places.js` — seed Dhaka's pumps, garages and parts
sellers.** So a rider who opens Places in Dhaka sees a real directory on
first launch instead of an empty list waiting for someone else to contribute.
Same OpenStreetMap/Overpass source as the in-app "Import nearby", but a
whole-city bounding box run once from the Admin SDK. Follows
`reset_beta_data.js`'s house style: `--dry-run` default, `FIREBASE_PROJECT_ID`
guard plus a resolved-credentials guard, idempotent and resumable.

**Status: written, tested, verified against live Overpass — not yet run
against production.** The write step needs a service-account key. A real
fetch on 2026-08-12 returned **395 places over Dhaka metro: 256 fuel, 75
garages, 64 parts sellers** (32 unnamed in OSM). Flow, flags and the
rollback recipe are in `scripts/README.md`.

- **The geohash is a line-for-line port of `GeohashUtil.encode`, not an npm
  package.** This one matters: a seeded place whose geohash disagrees with
  what the client computes falls outside the prefix range
  `getPlacesByGeohash` queries, so it exists in Firestore and is **invisible
  on the map with nothing erroring**. Verified against the Dart
  implementation over 4,004 points (2,000 in the Dhaka box, 2,000 worldwide,
  plus origin/poles/antimeridian) — 0 mismatches; 8 pinned as test fixtures.
- **Two places it reaches further than the in-app importer, both Dhaka-
  specific.** It queries `nwr` (ways and relations) not just nodes — most of
  the city's petrol stations are mapped as building polygons, which the app's
  node-only query misses entirely — and it adds `shop=motorcycle_repair` /
  `shop=motorcycle_parts` to the app's three tags. Safe to diverge because
  dedup is by `osmId`: a node the app can't classify is one it will never try
  to re-create. **If the app's importer is ever widened, widen it toward
  this list** rather than the reverse.
- **Two decisions baked in**, both flagged in the README: seeded places are
  `verified: true` (structured source, not an unmoderated rider submission —
  `--unverified` flips it), and `createdBy` is the sentinel
  `system:osm-seed-dhaka` (a real uid there would hand one rider ownership of
  every pump in Dhaka via "My places"; a colon can't appear in a Firebase
  uid, so it can't collide).
- **Coverage is honestly partial** and the script says so on every run. OSM
  maps Dhaka's chain petrol stations well and its small independent garages
  and roadside parts counters much less so. That was the known trade of
  choosing Overpass over a paid Places API — free, no key, no quota, no
  recurring cost, in exchange for an incomplete long tail.
- `scripts/` has unit tests now (`npm test`, node's built-in runner, no new
  dependency): 22 covering the mapping, geohash, dedup and document shape —
  all pure, no network, no Firestore.

Suite 717 → **755 green**, `flutter analyze` clean in `lib/` and `test/`.
Nothing here has been on a device.

**Two follow-ups, same day.**

- **`flutter analyze` is usable again** — `build/**` is now excluded in
  `app/analysis_options.yaml`. **6,782 issues / 6,163 errors → 121 issues / 0
  errors**, and 8.8s → 2.9s. Every one of those errors came from the
  FlutterFire sources SwiftPM checks out under `build/`, none from this
  project; full write-up and the rejected alternative in `Issues.md` §23
  (now marked fixed). A subsequent `flutter build ios --release` succeeded, so
  the exclusion doesn't affect the build — only what gets analyzed.
- **The skin blurbs name the shape**, in both ARBs — "…, rounded" /
  "…, sharp edges" and "…, গোল কোণ" / "…, ধারালো কোণ". Retro and Carbon
  Mono's English already named theirs; Carbon Mono's **Bangla** was corrected
  from "ঝকঝকে" (shiny) to "ধারালো কোণ", because otherwise it would have been
  the one row in a Bangla picker not naming its shape while the other eight
  did — an inconsistency this change would itself have introduced. 15 strings
  across `app_en.arb` / `app_bn.arb`, `flutter gen-l10n` re-run and the
  generated files committed as usual.

**Installed and running on the iPhone 15 — but still not *seen*.**
`flutter build ios --release` → `build/ios/iphoneos/Runner.app` (48.2 MB,
42.3s Xcode build), signed with the `abraar.rar@icloud.com` development
identity, then installed and launched on Abraar's iPhone 15 via the
`devicectl` sequence. Install and launch both succeeded first try, in under 20
seconds total. **No ad-hoc signing failure and no `flutter clean` needed** — a
third consecutive corroboration of the ⚠️ on the iOS-install section above;
treat `flutter build ios --release` → `devicectl device install app` →
`devicectl device process launch` as the default path and `flutter run` as the
fallback.

Note the one process trap worth remembering: `xcrun devicectl list devices`
lists *known* devices whether or not they're reachable, with state
`unavailable` when nothing is cabled/unlocked/trusted. Don't read a populated
table as a connected phone. The `available (paired)` state is the one that
means installable, and `\bavailable\b` (not `available`) is the grep that
distinguishes it from `unavailable`.

**What remains unverified is unchanged, and it is the whole point of the
exercise:** the skins have still never been *looked at* on a real screen. The
app is running but sits at sign-in, and no credentials or tap automation exist
on this side — the standing limitation from every previous device run
(`Issues.md` §15). The rider-side checks queued up for whoever has
credentials: apply **Positive Vibes** (rounded profile on a near-white base,
and the only place a 20px radius meets the Record screen's 210px photo hero),
**Retro** (must be completely square — anything rounded means the terminal
profile isn't applying), and **Carbon Mono** (must look *identical* to before;
any visible change there is a regression, since boxy keeps the historical
radii verbatim). Also worth an eye: whether the lengthened skin blurbs
ellipsize at this device's textScaler 1.1176 with bold text.

### Known Limitations (Documented, Not Bugs)
- ~~**Avg speed still mean-of-samples**~~ **FIXED 2026-08-01** — now distance ÷ moving time (`average_speed.dart`), with stopped time excluded via the same `speed < 1 m/s` cutoff the recorder already stamps as `period_type`. Gaps over 60 s (tunnel / suspended app) aren't counted rather than guessed at.
- **Navigation is geometric, not routed** — turn-by-turn follows a saved route's own polyline: no street names, no lane guidance, and no rerouting (it reports "off route" instead). Deliberate: no routing engine or API key exists. See `Assumptions Made.md`.
- **Sensor calibration**: Still heuristic (GPS fusion deferred to v1.1)
- **POI search**: Geohash-based (simple), not real-time autocomplete
- **Offline-first limit**: ~10MB local DB on typical device; cleanup policy on rotation
- **No payment yet**: All features free in V1; premium tier (crash escalation, weather) deferred to P8+
- **Backend analytics**: Firebase Analytics wired but dashboards not built
- **Admin panel**: Moderation done via Firebase console (write rules for admin claim)
- **ML features**: Crash/pothole detection logic in code; TF Lite model not included

### Deployment & CI/CD
- **Build**: `flutter build apk` for Android; `flutter build ios` for iPhone
- **Firebase**: Console-deployed Firestore rules (see `firestore.rules` in repo)
- **Distribution**: Play Store (internal testing), TestFlight (iOS), GitHub Releases (APK)
- **Environment**: TIPSOI_MOCK=0 (live API) in prod; dev uses same unless testing offline

### Phase priorities (roadmap ordering)
1. **P1**: Emergency contacts + crash detection with countdown UI
2. **P2**: POI map + directory + ratings
3. **P3**: Shared routes, group rides
4. **P4**: Turn-by-turn routing, club managers

> ⚠️ **Correction (2026-07-14, after a code audit):** several P5–P8
> features existed at the time as **logic/data layers only, with no UI
> wired to them**: the crash countdown modal (state existed, no widget
> rendered it), SyncManager (never instantiated → rides stayed local-only),
> JSON/GPX export (no button), emergency contacts (no screen), live-share
> (no share button; viewer unhosted), the POI directory (no presentation
> layer at all), and the social feed/routes/group-ride screens (files
> existed but were orphaned — the Social tab showed a "Coming in V2"
> placeholder). **Status: resolved** — see "Now (before inviting beta
> testers)" below, all marked done 2026-07-14, and confirmed present in
> code as of this 2026-08-01 pass (see `Features.md`).

---

## ⚠️ Done, but NOT yet verified

These exist in code/config but have never been exercised against the real
backend or a real device. **Treat each as unproven until tested.**

- [x] ~~**On-device behaviour**~~ **PARTIALLY VERIFIED 2026-07-23** — the project owner has now tested the live app directly (see §8/§8a/§8b history), surfacing several real bugs since fixed. Still open specifically: a real ride with the screen off for several minutes, to confirm the mid-ride-kill data-loss fix (§8b) actually holds.
- [x] ~~Unit/widget test suite~~ **VERIFIED 2026-07-14** — 184/184 green. (775/775 as of 2026-08-14.)
- [ ] 🔴 **Offline end / share / resume — the 2026-08-14 fix, unexercised on a device.** `Issues.md` §25 and §26. This is the highest-value device check on the list right now, because it was reported by the project owner from real use and because the bug being fixed is a *timing* property of the Firestore SDK that no test in this repo can stage: an awaited write with no connection never returns, so `try`/`catch` never fires and the caller hangs. The exact sequence to run, in **fly mode**:
  1. Start a ride, ride a little, **end it** — it must finalize and show the summary promptly (this was hanging outright, for every rider, shared location or not).
  2. **Share** that ride with a photo — the composer must return quickly and say *"Saved — we'll post it when you're back online"*.
  3. Start another ride, **force-kill the app after ~5 seconds**, reopen — the ride must come back paused rather than vanishing (the <2-stored-points delete path, §26).
  4. Trigger the crash overlay and **dismiss** it — the ride must return to active (it was stalling on a telemetry write).
  5. **Re-enable data.** The queued share must post, the live pointer must clear, and nothing must double-post.
- [ ] **DB schema 9 → 10** (`outbox` table) — unlike the 6 → 7 migration below, this one *is* covered by a test that runs the real `_onUpgrade` ladder over a v9 database with rides in it (`test/database/outbox_migration_test.dart`), because a broken migration here sends `_initDb` into its corrupt-file rescue, which **deletes the database and every stored ride**. Still worth one real upgrade over an existing install, since the test opens an in-memory DB rather than a rider's actual file.
- [ ] **Google sign-in end-to-end** — config + code are in place; needs one real tap-through on a device.
- [ ] **Firestore rules under real traffic** — rules deployed but only compiler-checked; exercise with a real account (read own rides, fail reading someone else's).
- [x] ~~Live-share viewer~~ **HOSTED 2026-07-14** at `throttleiqfb.web.app/live/{token}` (HTTP 200 verified); end-to-end with a live ride still needs a device test.
- [x] ~~**Simulator smoke test of the backlog pass**~~ **PARTIALLY VERIFIED 2026-08-01** — run on the iPhone 17 simulator (iOS 26.5) against a real signed-in account. Confirmed rendering correctly: the Carbon Mono theme; the Forums "Your bikes" list showing **both** brand and model forums from real garage data; the Create-a-forum screen; the Routes list and its Discover tab; the new Recreation category chip in Places; and **feed cards drawing the ride's route map beside the photo**, with the "No route recorded" placeholder for rides with no track. This run found three real defects that the test suite could not — two missing Firestore composite indexes and the Routes reachability/back-button problems (`Issues.md` §5 and §6), all since fixed and deployed. Still not exercised: recording an actual ride, and everything below.
- [ ] **The rest of the 2026-08-01 backlog pass** — forums moderation, ride captions, saving a route, turn-by-turn navigation, expanded maintenance types, the moving-time average speed. Verified by `flutter analyze` (0 errors), 550 passing tests, and release builds — **none of it has been exercised by actually riding.** The riskiest untested paths, in order:
  1. **Turn-by-turn navigation** — the geometry is unit-tested, but nothing has confirmed the banner advances sensibly at real road speeds, or that the 30 m "turn reached" / 100 m "off route" thresholds feel right on an actual bike. Tune these from a real ride.
  2. **The deployed Firestore rules** — forum moderation and route publishing were written and deployed but never exercised against a live account. Confirm a maintainer really can delete a post, and that a non-maintainer really can't.
  3. **The `SharedPreferences` garage-forum cache** — verify adding a bike actually refreshes the "Your bikes" list rather than serving a stale cache.
  4. **DB schema 6 → 7** (`custom_label` on `maintenance_logs`) — migration is written but has only ever run on a fresh install here. Test an *upgrade* over an existing install.
  5. **GPS trail sync** — record a ride, let it sync, reinstall, and confirm the ride's polyline comes back rather than an empty map.
  6. **Home-screen widgets** — Android widgets are confirmed *present in the built APK* (via `aapt2`) but have never been added to a real launcher. Add all three, confirm they show placeholders before any data and real values after a ride, and that the Start-ride widget opens on Record.
  7. **Ride with friends** — needs **two real accounts on two devices**: invite, confirm the invitee sees the in-app notification, accept, and confirm both riders appear on each other's map in different colours and that stale positions grey out. The deployed `groupRides` rules have never been exercised by a real client — and since the roster moved to a subcollection (`Issues.md` §10), the invite → accept → leave path is the specific thing to exercise. Its rule correctness is reasoned, not executed; there's no rules-test harness in this repo.
  8. **Bike visibility** — confirm another rider can see your bikes on `public`, cannot on `private`, and that `followers` tracks the follow edge. Note this rules change *widened* read access (`Assumptions Made.md` #15).
  9. **Bike deletion** — the deadlock is fixed and covered by real-SQLite tests, but confirm on a device that deleting a bike with rides actually removes it and its history.
- [x] ~~Carbon Mono / Editorial theme toggle — default theme~~ **PARTIALLY VERIFIED 2026-08-01** — ran on the iOS Simulator, screenshotted the Record screen: dark Carbon Mono palette, lime accents, sharp corners, and IBM Plex type all render correctly by default. The Editorial toggle in Settings itself was **not** tap-tested live (no `idb`/`cliclick` in this environment, and scripted macOS clicks need an Accessibility grant that wasn't available) — instead it's covered by 5 new tests in `test/core/theme/theme_style_provider_test.dart` exercising the tap → notifier → palette-swap → persistence path directly. Writing those tests caught a real bug, since fixed: `ThemeStyleNotifier._loadPersisted()` could crash with "used after dispose" if the notifier were torn down while its `SharedPreferences` read was still in flight — now guarded with a `mounted` check. Still open: an actual finger-tap of the Settings toggle on a device/simulator. **Widened 2026-08-11:** that toggle is now a nine-skin dropdown, so what's unverified on a device is nine palettes, not two — and only Carbon Mono has ever been seen rendering a real screen. The seven new skins have never been applied to anything but a swatch. Highest-value single check when a simulator is next available: apply **Retro** (its `border` token is full-strength ink rather than a hairline — the one palette that could plausibly look wrong applied app-wide) and **Positive Vibes** (pure-white `surface` on a near-white `background`) and page through Record → Active ride → Ride summary. **Widened again 2026-08-12:** three of the skins now change *shape* as well (rounded corners, stadium chips, taller buttons — see the 2026-08-12 entry above). Those were seen rendered via a golden-image harness at the widget level, which is real pixels but not a real screen; what's unverified is whether the rounded profile holds up across a *whole* screen's worth of nested cards and chips. The two skins to apply on a device are unchanged, plus **Positive Vibes** now doubles as the rounded-profile check.
- [x] ~~**Run `scripts/seed_dhaka_places.js` against production**~~ **DONE
  2026-08-12.** **395 places written to `throttleiqfb`** — 256 fuel, 75
  garages, 64 parts sellers across Dhaka metro, one batch commit. Read back
  and verified against Firestore directly: `places` went 3 → 398 (the 3
  pre-existing rider-contributed places untouched), all 395 carry
  `createdBy: 'system:osm-seed-dhaka'` and `verified: true`, **0 missing or
  malformed geohashes and 0 missing `osmId`s**. A second dry run reports
  `395 already present, 0 new`, which is the idempotency contract proven on
  real data rather than in a test.
  - Two prerequisites that were not obvious and cost time — worth knowing
    before anyone runs any script in `scripts/`:
    1. **`npm install` had never been run in `scripts/`.** `firebase-admin` is
       a dependency of that directory, not of the Flutter app, so a fresh
       checkout fails with "Cannot load 'firebase-admin'" on a script that
       otherwise looks ready.
    2. **Being logged into the Firebase CLI is not enough.** `firebase
       projects:list` showing `throttleiqfb (current)` is a *user* credential;
       the Admin SDK's `applicationDefault()` reads
       `GOOGLE_APPLICATION_CREDENTIALS` or gcloud ADC, neither of which the CLI
       login creates. It needs a service-account key (or
       `gcloud auth application-default login`).
  - `scripts/dhaka_places.json` (the fetched candidate list) is **gitignored**
    — it is a regenerable review artifact, not source. Re-create with
    `npm run seed:dhaka:fetch`.
  - **Still to check on a device:** open Places with a Dhaka location and
    confirm the directory renders, then tap "Import nearby" there and confirm
    it adds nothing — that is the osmId dedup contract between this script and
    the in-app importer, and it has only been proven script-side.
  - **The 32 unnamed entries are now live** as literally "Fuel"/"Garage"/
    "Parts" (OSM has no name for them). If they read badly in the list, they
    are individually deletable, or the whole batch is one
    `createdBy == 'system:osm-seed-dhaka'` query away — but note that window
    effectively closes once riders start leaving reviews, since those live in
    the separate `reviews` collection and would be orphaned rather than
    deleted.

---

## 📋 To do

### 🎯 Do next, in order (assembled 2026-08-15, when a Play launch was being considered)

The checklists below are grouped by *topic*; this is the same work ordered by
what actually blocks what. The dependency that matters is **1 → 2 → 4 → 5**:
Google's background-location review can't start until there's an app in
Console, and it's the one item on this list that cannot be compressed by
working harder. Everything from 6 down runs in parallel with that wait.

**Tonight**
1. **Back up the signing keystore.** 5 minutes. Lose it and the app can never
   be updated under the same identity — a dead end, not a setback. Everything
   below assumes this is done.
2. **Start the Play developer account** ($25). New accounts need identity
   verification that can take **up to 48 hours**; starting it costs nothing.
3. **Install the 2026-08-14 build on the Android device.** Not housekeeping —
   there is a **live regression**: the deployed rules require
   `lastCommentId`/`lastReplyId`, which only that build sends, so
   commenting/replying/reply-deletion fail on any device without it. The
   iPhone has it; the APK is built but uninstalled.
4. ~~**Bump `version:` and rebuild the AAB.**~~ **DONE 2026-08-15 — shipped as
   the `beta-v3` GitHub release**, built from `caa1a48` at `1.0.0-beta.3+3`
   (versionCode 3, verified in the bundle manifest; release-signed, SHA-1
   `8542b8ad…2f10`). Both artifacts are attached to the release, so the AAB
   for the Play upload no longer has to be rebuilt from scratch — download
   `ThrottleIQ-beta-v3.aab` from
   <https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v3>.
   **Standing rule for next time: the build artifacts are not committed, so any
   commit after a build invalidates them — bump to `+4` and rebuild before the
   *next* upload.**
5. **Upload to internal testing, then submit the Background Location Access
   declaration** — the long pole (see the Play Store section's note). The AAB
   from step 4 is ready to upload.

**This week, before anyone else touches it**
6. **Ride with it.** The offline end/share fix, the resume fix and
   hold-to-start all have zero road time. Run the fly-mode sequence under
   "Done, but NOT yet verified".
7. ~~**Delete the dead `<service>` block**~~ **DONE 2026-08-15** (`Issues.md`
   §27) — removed before the AAB in step 4 was built, so the artifact heading
   into the review is clean.
8. **Decide the publisher identity** — blocks the listing.

**Before it's public**
9. **Decide what happens to crash detection.** It notifies nobody (Spark plan).
   Either upgrade to Blaze and wire the SMS/email provider, or keep the claim
   out of the listing. The only item here with real-world rather than merely
   policy consequences.
10. **Data Safety form** (precise location, photos, email, *and* location
    shared with other users via live-share) + the
    `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` justification.
11. **Run `set_admin_claim.js`**, and **verify the Cloudinary preset
    restrictions** in their dashboard.

**Deferred, not before launch**
12. **Auto-tracking** — pick the isolate strategy first (see Proposed features).
13. **iOS widget extension target** — one-time Xcode GUI step.

### Now (before inviting beta testers)
- [x] ~~🔴 **Close the two launch-blocking security findings**~~ **CODE FIXED
  2026-08-12 — NOT YET DEPLOYED.** (Audit 2026-08-12, `Issues.md` §24 — all 8
  findings were open; all 8 now have code fixes, see §24.1–§24.9 in
  `Issues.md` for what each one actually does.) The two blockers composed
  into "any anonymous stranger can watch any rider move in real time":
  - **§24.1 — live sessions published with no consent.** Fixed:
    `_startLiveSessionPublishing()` no longer runs from `startRide()`/
    `resumeRide()` at all. It only ever runs via the new
    `enableLiveSharing()`, triggered by the rider tapping "Share live
    location" — that tap IS the opt-in now, not just a share-sheet trigger
    for a session that already existed. `liveSessions` docs also now carry
    `shareable: true`, and `firestore.rules`' `get` rule on
    `liveSessions/{token}` requires it — so even a future client regression
    that reintroduced always-on publishing still can't be read by a stranger
    without the rule also being wrong.
  - **§24.2 — share tokens used `dart:math` `Random()`.** Fixed: `Random.secure()`.
  - The other six (§24.3 unclipped public routes, §24.4 forum-moderator
    takeover, §24.5 @username impersonation, §24.6 group-ride invite
    escalation, §24.7 vote inflation, §24.8 PII in Cloud Logging) are also
    fixed — see `Issues.md` §24 for each.
  - **✅ DONE 2026-08-14: the 2026-08-12 rules were deployed.**
    `firebase deploy --only firestore:rules` released to `throttleiqfb`, so
    §24.1, §24.4, §24.5, §24.6, §24.9's admin-claim change and §24.7's
    like/vote half are all enforced live.
  - **✅ DONE 2026-08-14: the second rules deploy went out too**, covering
    §24.7's residual and §24.11's two fixes, with `npm run test:rules` (19/19)
    run immediately before it.
  - **🔶 The client half is on ONE device so far.** The live rules require
    `lastCommentId` / `lastReplyId` on counter bumps, which only the
    2026-08-14 build sends — so commenting, replying and reply-deletion fail
    on any install that doesn't have it. Status:
    - **Abraar's iPhone — done 2026-08-14.** `flutter run --release` built and
      installed the iOS release build from `1a735f5`.
    - **Android — APK built but NOT installed anywhere** (see the beta-APK
      item below).
    - Any other device is still in the broken window until updated.
  - **🔶 Cloud Functions cannot deploy at all — needs the Blaze upgrade.**
    `firebase deploy` fails on `artifactregistry.googleapis.com`, which Spark
    won't enable. This blocks §24.8's crash-notification PII fix and §24.9's
    new `reconcileRideIdentity` trigger from ever running. Upgrade at
    <https://console.firebase.google.com/project/throttleiqfb/usage/details>.
    Separately, `functions/` could not even have been BUILT before 2026-08-14
    (no `typescript` dependency, no `predeploy` hook) — both fixed, see
    `Issues.md` §24.10.
  - Also still needs a human: `scripts/set_admin_claim.js` (new — see
    `Issues.md` §24.9) has to be run once, with real
    `GOOGLE_APPLICATION_CREDENTIALS`, to actually grant the `admin` custom
    claim `isAdmin()` now prefers. Until then the email-comparison fallback
    keeps the admin account working, so this isn't blocking, just unfinished.
- [x] ~~**Deploy `firestore.rules` + hosting**~~ **DONE 2026-08-04.** Both
  released to `throttleiqfb`. Verified against the live project rather than
  assumed:
  - `/r/{username}` and `/live/{token}` both serve the viewer (HTTP 200),
    and the deployed HTML contains the permanent-link resolution code.
  - An **unauthenticated** `get` of `usernames/{handle}` returns
    **404 NOT_FOUND, not 403** — i.e. the read is permitted and the handle
    simply doesn't exist. This is the check that mattered: a 403 would have
    meant the rule was still auth-gated and the permanent link would be
    broken for every visitor, since the whole point is that whoever opens
    the link does **not** have the app.
  - `usernames`, `livePointers` and `liveSessions` all return
    **403 PERMISSION_DENIED** on an unauthenticated `list` — the §3/§14 bug
    class is closed in both new places it appeared.

  **Re-run `firebase deploy --only firestore:rules,hosting` after any
  future edit to `firestore.rules` or `firebase.json`** — neither ships
  with the app, and a rules change that isn't deployed silently does
  nothing.

  **Test rules before deploying them: `npm run test:rules` from `scripts/`.**
  Added 2026-08-14 (`Issues.md` §24.11) — 19 emulator-backed tests over the
  engagement-counter and moderation clauses. The Firestore emulator needs a
  JVM and there is no `java` on PATH, so the npm script points `JAVA_HOME` at
  Android Studio's bundled JBR, the same runtime the `keytool` note below
  uses. Two live bugs turned up in the first run, so this is worth doing
  rather than deploying on inspection alone. Note `npm test` in the same
  package stays emulator-free (its glob is non-recursive); the rules tests
  live in `test/rules/` for exactly that reason.

  **Careful with rules that depend on new client fields.** A rule tightened
  to require something only the newest build sends will break every install
  that hasn't updated. Ship the app first, then the rules — this bit the
  §24.7/§24.11 batch and is why it's still sitting undeployed.
- [x] ~~Wire the orphaned features~~ **DONE 2026-07-14**: crash countdown overlay, SyncManager bootstrap, export buttons, Settings screen (logout + emergency contacts) all wired; live viewer deployed to `throttleiqfb.web.app`. Remaining genuine builds: POI UI and a real social feed (the agent "screens" were empty stubs).
- [ ] **Back up the signing keystore** — `throttleiq-release.keystore` + `app/android/key.properties` exist ONLY on the dev machine. If lost, the app can never be updated under the same identity. → password manager / secure cloud, never git.
- [x] ~~**Release key's SHA-1 registered with the Android Google OAuth client**~~ **VERIFIED 2026-08-11.** Worth an explicit line because the failure mode is nasty and silent: if the OAuth client only carries the *debug* keystore's fingerprint, **Google sign-in works in debug and fails in release**, with nothing in the app to explain why. Checked — `app/android/app/google-services.json` carries two Android OAuth fingerprints and `throttleiq-release.keystore`'s SHA-1 is one of them, so ThrottleIQ is not exposed to this. Re-check after any keystore change (including a Play App Signing upload-key rotation, which introduces a *second* fingerprint that also has to be registered).
  - **`keytool` does not work out of the box on this Mac.** `/usr/bin/keytool` is Apple's stub and no JDK is on PATH (`/usr/libexec/java_home` fails). Use Android Studio's bundled runtime: `"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -list -v -keystore throttleiq-release.keystore`. Note that the stub **fails silently under `2>/dev/null`** and yields an empty fingerprint — which compares unequal to everything and reads as "the key isn't registered". That false negative was hit once already; if a fingerprint check says "not registered", verify `keytool` actually ran before believing it.
- [ ] **Install the beta APK on a real phone** and run the smoke test: register → record a ride → stop → summary → confirm the ride appears in Firestore console.
  - **Latest release: `beta-v3`, published 2026-08-15** from `caa1a48` —
    <https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v3>
    (pre-release, `ThrottleIQ-beta-v3.apk` 76 MiB + `ThrottleIQ-beta-v3.aab`
    72 MiB, `1.0.0-beta.3+3`). Carries the security batch, the offline outbox,
    the ride-resume fix, hold-to-start, and Places directions. Tag convention
    is `beta-vN` with title `ThrottleIQ — Beta vN (vX)` and both artifacts
    attached; follow it for the next one.
  - Verified release-signed — `apksigner` reports `CN=ThrottleIQ, OU=BlankFrame Technologies` (not `CN=Android Debug`) with SHA-1 `8542b8ad…2f10`, which **is** one of the two fingerprints in `app/android/app/google-services.json`, so Google sign-in works in this build. That check is cheap and worth repeating each release: a debug-signed "release" APK fails sign-in silently, with nothing in the app to explain why.
  - **iPhone is on this build; Android still isn't.** Abraar's iPhone was launched to directly (`flutter run --release`, 2026-08-15), so it has the client half the deployed rules require. **No Android device has been installed to** — the APK is merely published on the release page. Until someone installs it, commenting/replying/reply-deletion still fail on Android (see §24's note).
  - **This is the build to run the §25/§26 fly-mode sequence on** — see the offline item under "Done, but NOT yet verified" above. It is the whole reason this APK exists.
- [x] ~~Run the test suite~~ **DONE 2026-07-14** — 184/184 green (fixed a real EventDetector regression + bad test expectations found on the first-ever full run).
- [x] ~~Deploy the live-share viewer~~ **DONE 2026-07-14** — hosted at `throttleiqfb.web.app` (verified 200); the app's share links point there.

### Soon (requires Blaze pay-as-you-go plan — still ~$0/mo at beta scale)
- [ ] **Cloud Functions** — deploy `functions/` (crash-notification escalation).
  Currently SMS/email are mocked; wire Twilio (SMS) and/or SendGrid (email)
  with real credentials via functions config — **needs the project owner's
  own Twilio/SendGrid accounts and API keys**, not something fixable in code
  alone. Two things changed 2026-08-12 (`Issues.md` §24.8) that make this
  more urgent, not less: the emergency-contacts screen no longer implies
  contacts ARE notified (the copy was flatly wrong — nobody has ever been
  contacted after a detected crash), and `functions/` gained an
  `index.ts`/`package.json main` it was missing entirely before, so it can
  actually be deployed now — previously `firebase deploy --only functions`
  had no entry point to find. Also worth knowing: the mock no longer logs a
  contact's phone/email or the crash's GPS coordinates (was landing in Cloud
  Logging, §24.8) — a real integration will need to read those from
  `EmergencyContact`/the notification's lat/lng again, they just aren't
  logged anymore.
- [x] ~~Firebase Storage bucket~~ **SUPERSEDED 2026-07-23** — the project owner has no payment card, and Storage now requires Blaze even within its free tier. Avatar/photo uploads moved to Cloudinary instead (cloud name `vjvcigkt`) — no bucket needed.
- [ ] **Firestore TTL policy** on `liveSessions.expiresAt` so expired live-share docs auto-delete. The app-side blocker is fixed (those fields are real `Timestamp`s now, not ISO strings — see `Issues.md` §4). **Two ways to apply it; pick either.**

  **A — Firebase console, no install needed (easiest):**
  1. Open [Firestore → Time-to-live](https://console.firebase.google.com/project/throttleiqfb/firestore/ttl)
  2. **Create policy** → Collection group `liveSessions`, timestamp field `expiresAt`
  3. Save. It takes up to ~24 h to start reaping, and deletions are best-effort — Google does not promise deletion at the exact expiry instant.

  **B — gcloud** (installed 2026-08-03, SDK 578.0.0, on PATH — but still needs an interactive `gcloud auth login` before this will run):
  ```
  gcloud firestore fields ttls update expiresAt \
    --collection-group=liveSessions \
    --project=throttleiqfb \
    --database='(default)' \
    --enable-ttl
  ```

  ⚠️ **This does not clean up the existing backlog.** Documents written before the Timestamp fix hold *string* expiries, and TTL ignores any non-Timestamp field — so those rows linger forever regardless of which method you use. Either delete them by hand in the console (`liveSessions` is small and pre-launch, so this is a few clicks) or accept them. Verify after enabling by checking that a session created *today* disappears within ~24 h of its `expiresAt`.
- [x] ~~**Deploy the privacy policy**~~ **DONE 2026-08-01** — live at [`https://throttleiqfb.web.app/privacy.html`](https://throttleiqfb.web.app/privacy.html) (HTTP 200 verified anonymously). Paste that URL into the Play Console listing and the Data Safety form. Content is derived from what the code actually does; re-check §1–§4 whenever the data flows change.
- [x] ~~**Sync `ride_points` (GPS trails) to Firestore**~~ **DONE 2026-08-01** (`ride_track_codec.dart` + `CloudRepository.uploadRideTrack`/`downloadRideTrack`). Trails are chunked into `users/{uid}/rides/{rideId}/track/{i}` docs of 500 positional points — one doc per point would have been thousands of writes per ride. Upload runs after the ride doc so a track can't orphan; download is on-demand and never clobbers local points. Track docs are owner-only in the rules. **Untested against a real account** — verify a reinstall actually restores polylines.

### Play Store

> **🔴 The long pole is a Google review, not a build step — surfaced 2026-08-14
> when a same-night production launch was considered.** `AndroidManifest.xml`
> declares `ACCESS_BACKGROUND_LOCATION` (line 6) with a
> `foregroundServiceType="location"` service, which triggers Google's
> **Background Location Access declaration**: a Play Console form needing a
> video demo and written justification, with a review that runs **days to
> weeks**. Production, open testing and closed testing are all gated on it.
> **Internal testing is normally exempt** — that's the route to get a build to
> real devices immediately — but confirm that in Console rather than assuming
> it. Plan the launch date around this review, not around the code being ready.
>
> Two more permission/policy notes for the same submission:
> `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` is a restricted permission and a
> common rejection reason — have the justification written before submitting.
> And the **Data Safety form** must declare precise location, photos and email,
> *including* that location is shared with other users (the live-share link is
> a share to a third party by Play's definition).
>
> **Also decide, before the listing copy is written:** crash detection
> currently notifies nobody. Cloud Functions cannot deploy on the Spark plan
> (see §24's note above), so the alert path is a mock. The in-app copy was made
> honest about this on 2026-08-12, but a store listing that markets crash
> detection as a safety feature while nothing is actually sent is both a policy
> risk and a real-world one. Either upgrade to Blaze and wire up the SMS/email
> provider, or keep the claim out of the listing.

- [x] ~~Privacy policy page~~ **DONE** — `https://throttleiqfb.web.app/privacy.html`
- [ ] ❓ **Decide the publisher identity — blocks the listing.** The privacy policy that was replaced on 2026-08-01 named **"Blankframe.tech"** as publisher, with contact `blankframe.technologies@gmail.com`; the GitHub org is `blankframe-tech`. The new policy deliberately names **no company** — it says "an independent, solo-developer project" and uses `the.abraar.rar@gmail.com` — because inventing a legal entity in a privacy policy is not a call to make on someone's behalf. **If Blankframe.tech is the real publishing entity, the policy needs it added**, since Play Console expects the listing's developer name to line up with the policy. Old file is recoverable from git history (`store_listing/privacy-policy.html`, deleted in this pass).
- [ ] Google Play developer account ($25 one-time)
- [x] ~~Build an **App Bundle**~~ **VERIFIED 2026-08-01** — `flutter build appbundle --release` produces `app/build/app/outputs/bundle/release/app-release.aab` (57.0 MB). Rebuild it after any version bump; the artifact itself isn't committed.
  - ⚠️ **Last built 2026-08-15 at `1.0.0-beta.3+3`** (72 MiB, versionCode 3 verified in the merged manifest) — carrying the security, offline and resume work plus the §27 manifest fix, but **not** the Places Directions/Call feature (`a623df8`), which added `url_launcher` and new `<queries>` entries. Rebuild at `+4` before uploading. The artifact isn't committed, so treat any commit after a build as invalidating it.
- [ ] **Add the iOS widget extension target in Xcode** — see `app/ios/ThrottleIQWidget/README.md`. One-time GUI step; iOS widgets don't exist until it's done. Android needs nothing.
- [ ] Internal testing track → closed beta → production
- [ ] Bump `version:` in `pubspec.yaml` (versionCode) for every new upload

### Open questions for the product owner

- ❓ **Does the quote belong on the Record screen at all?** It now shares a
  card with the greeting and name (small type). But the Record screen is
  the pre-ride screen, and a rider standing at their bike wants the bike
  picker and the start control, not prose. **Alternative worth
  considering:** show the quote on an *intermediate screen between
  tapping start and recording beginning* — a two-second "here we go"
  moment, where a line of personality actually lands instead of competing
  with the controls. That screen could also carry the GPS-lock status,
  which currently has nowhere to live. Decide before the beta; it's a
  cheap move now and awkward later.
- ❓ **Badge completion reward.** The intent is that a rider completing
  every badge gets an engine oil from us. Nothing in the app encodes that
  yet — no "all badges earned" state, no fulfilment path, no way to claim.
  Decide whether it's a real promise (needs a claim flow, an address, and
  a cost model) or aspirational copy, before it goes in front of testers.

### Proposed features (not built — for discussion)

- 🔮 **Automatic ride tracking (start recording without tapping start).**
  Assessed against the real code 2026-08-15. Summary: **background *recording*
  already works; what's missing is a background *trigger*, and the honest cost
  is one hard architectural problem plus a battery decision.**

  *What already exists, and is easy to overcount:*
  - iOS `UIBackgroundModes: location` is already set (`ios/Runner/Info.plist:79-82`).
  - Android background location already runs through **geolocator's own**
    foreground service (`ForegroundNotificationConfig`,
    `ride_recording_provider.dart:508`), plus `ACCESS_BACKGROUND_LOCATION` and
    `FOREGROUND_SERVICE_LOCATION` in the manifest. So a ride keeps recording
    with the app backgrounded and the screen off today. Only *starting* needs
    the UI.
  - `startRide()` takes no arguments and reads uid/bike from providers — it has
    **no `BuildContext` or widget coupling** and is already callable headlessly.

  *What does NOT exist, contrary to a first read of the calculators directory:*
  - **There is no IDLE/WALKING/RIDING state machine.**
    `VehicleStateEstimator` is a per-GPS-tick complementary filter that emits a
    `VehicleState` snapshot (`isMoving`, `isCornering`, confidence…). Its
    `_rebuild()` returns early with no GPS fix, so it produces *nothing* until a
    GPS stream is already running — which makes it structurally unable to be the
    auto-start trigger, since the whole point is to decide whether to turn GPS
    on. A trigger needs a *different*, cheap input: platform activity
    recognition, or iOS significant-location-change.
  - **`RecordingCadencePolicy` is not a battery saver in the sense people
    assume.** Its own doc is explicit: it only thins what is *written to disk*.
    It does not change the GPS sampling rate. Current settings are
    `LocationAccuracy.bestForNavigation` with `distanceFilter: 3` (tuned in
    response to a "speed feels laggy" report) — the top of the power envelope.
    **This is the single biggest battery lever and it is currently untouched.**
    Always-on monitoring at those settings is not viable; the trigger must run
    on activity recognition / SLC and only then escalate to full-rate GPS.

  *The actual hard part — isolates, not UI coupling.* Every "wake the app"
  mechanism (`workmanager`, `flutter_background_geolocation`'s headless task,
  a native service callback) runs its Dart in a **separate isolate** with its
  own memory. `RideRecordingNotifier` lives in the UI isolate's
  `ProviderContainer` and holds all recording state in instance fields, so a
  background isolate cannot call `startRide()` on it. Options, cheapest first:
  1. **Trigger-only, arm-on-launch** — background isolate does nothing but
     write a "ride detected at T" marker to SQLite/prefs; the UI isolate picks
     it up. Cheap, but it doesn't record anything until the app is next opened,
     so it's a prompt (*"Looks like you rode. Save it?"*), not auto-tracking.
  2. **Native service owns the recording** — the foreground service collects
     fixes and writes `ride_points` directly; Dart reconciles on next launch.
     Most robust, most native code, and the `LocationForegroundService`
     currently declared-but-missing (`Issues.md` §27) would become real.
  3. **`flutter_background_geolocation`** (paid licence) — bundles activity
     recognition, SLC, foreground service and a headless task. Buys ~all of the
     platform work; costs money and a large dependency.

  *Rough order of work if pursued:* add an activity-recognition source → decide
  the isolate strategy above (this is the design decision, make it first) →
  drop GPS accuracy/`distanceFilter` for the monitoring state and only escalate
  once riding is confirmed → decide the false-positive UX (a car journey looks
  like a ride to any accelerometer). The 63 KB `ride_recording_provider.dart`
  is where option 2 hurts, since recording state would have to move out of
  instance fields.

  *Not scheduled.* Recorded here so the next pass starts from the real state of
  the code rather than re-deriving it.

- 🔮 **Auto-pause in traffic.** Detect a stop (already possible — the
  recorder classifies `period_type` as moving/idle at the 1 m/s cutoff)
  and pause recording automatically. ~~surface the jam time back to the
  rider after the ride~~ **DONE 2026-08-12** — ride summary now shows
  moving vs. jam time (`jam_time.dart`, `rides.moving_s`, schema v9; see
  `Features.md` §2). What's **still open** is only the auto-pause policy
  itself: today jam time is reported but the ride keeps recording through
  it (correctly — moving time already excludes it from the average-speed
  denominator). Auto-pausing would need to watch out for a long traffic
  light vs. a genuine stop, and not double-counting against the existing
  manual pause.
- 🔮 **iOS start/stop widget.** The Android widget already exists and the
  iOS sources are written (`app/ios/ThrottleIQWidget/`), but iOS widgets
  can't *start a recording* from the widget itself — they can only deep
  link into the app. A true start/stop control needs App Intents
  (iOS 17+) plus background-location handoff. Worth scoping properly
  rather than assuming parity with Android.
- 🔮 **All-day auto-tracking** — detect that the rider has got on a bike
  and record without being asked. This is the single biggest retention
  idea in the backlog and also the most dangerous: it means continuous
  motion monitoring, which costs battery, needs "Always" location
  permission (a much harder App Store/Play review conversation, and a
  privacy-policy change), and produces false positives from car and bus
  journeys. Prototype the *detection* offline against recorded rides
  before committing to the permission ask.
- 🔮 **ThrottleIQ Partner** — a companion surface for the people who worry
  about a rider: spouse, parent, friend. Today live-share is one link per
  ride; Partner would let someone follow **multiple** riders (son,
  husband, father, friend) from one place, seeing who's currently out and
  where. Web first (the live viewer is already a web page and the
  permanent per-rider link is the natural building block), then a small
  standalone app. Note this is a **second product** with its own auth,
  its own privacy model, and its own consent story — a rider must be able
  to revoke a follower, and "always visible to my spouse" is a very
  different consent posture from "here's a link to this one ride". Do not
  start it before the main app has real users.
- 🔮 **Badge tiers as a collectible set** — bronze/silver/gold/platinum/
  diamond families are in as of 2026-08-04. The natural extensions:
  seasonal/limited badges, a shareable badge card, and club-level badges.

### Product (v1.1+)
- [x] ~~Average speed = distance ÷ moving time~~ **DONE 2026-08-01** (`average_speed.dart`, 12 tests)
- [x] ~~Sensor calibration via GPS fusion (current: heuristic axis pick)~~ **DONE 2026-08-12** — `accel_axis_calibrator.dart`. Fits a 3D "which way is forward" axis by least-squares against `MotionCalculator`'s GPS-derived acceleration (normal equations, solved incrementally, no stored sample history), and projects raw accelerometer samples onto it instead of picking whichever raw axis happens to read largest that instant. Falls back to the old dominant-axis heuristic until ~20 GPS-paired samples have accumulated *and* the fit is well-conditioned (guards against a near-singular matrix from straight-line-only riding). 6 tests, including recovering a known tilted axis from synthetic noisy data. **The near-singular-matrix determinant threshold is an unvalidated starting point** — as expected, tuning it (and re-checking whether the existing hard-brake/rapid-accel thresholds still fire right against the new, more accurate projection) needs real ride logs, which weren't available here.
- [ ] Crash-detector threshold tuning from real false-positive logs
- [x] ~~Geohash search → proper neighbor-table implementation (current neighbor calc is approximate)~~ **DONE 2026-08-12** — `GeohashUtil.getNeighbors` (`core/utils/geohash_util.dart`) now returns the correct 8 compass neighbors via the standard bit-interleaved neighbor-table algorithm (the same technique behind `geofire-common`), replacing the old re-encode-`center±cellWidth` approximation, which only ever found 4 neighbors and could drift across a cell boundary on float rounding. Cross-checked against an independent from-scratch bit-interleaving implementation (12,000 random points, 0 mismatches) and the `north(south(x))==x` round-trip identity; matches the classic "ezs42" worked example used across the wider geohash-library ecosystem. 8 tests, including antimeridian wraparound. Note the algorithm's one shared, known limitation: longitude correctly wraps at ±180°, but latitude has no "north of the pole" case, so it wraps too at the very top/bottom row — irrelevant at Bangladesh's ~20–26°N, so left as documented rather than special-cased. `getNeighbors` itself still isn't called from any query path (`PlaceRepository.getNearbyPlaces` fetches every place and filters in memory) — wiring it into an actual geohash-range nearby-query is separate, unstarted work.
- [ ] Weather on record screen (OpenWeather) — needs an API key, none available
- [ ] Leaderboards (smoothness-based), clubs & events
- [x] ~~Turn-by-turn navigation~~ **DONE 2026-08-01**, but *following a saved route*, not curvy-route *planning*. Planning a new route still needs a routing engine (Calimoto/Rever's core, XL/T3 — see Part 2).
- [x] ~~**Open discovered (public) routes**~~ **DONE 2026-08-02** — `?owner=<uid>` on the detail and navigate routes; read-only for non-owners.
- [x] ~~**Bundle a Bengali font**~~ **DONE 2026-08-12** — Noto Sans Bengali (variable font, OFL-licensed, `assets/fonts/`) bundled as a real pubspec `fonts:` asset rather than fetched via `google_fonts` at runtime, so Bangla glyphs render correctly offline from first launch. Wired as `AppTypography.bengaliFallback` and appended to every text style the app hands out — the shared `textTheme` via `TextTheme.apply(fontFamilyFallback:)`, plus the handful of standalone `GoogleFonts.xxx()` styles (app bar title, button labels, snackbar) that sit outside `textTheme` and needed their own `.copyWith`. 10 tests assert every named style and every standalone style carries it.
- [ ] **Translate the rest of the app** — only the settings screen was localized as of 2026-08-11; **partially picked up 2026-08-12**: the bottom nav (`app_shell.dart`), the Record-screen bike-picker hero and stat strip, and the full ride summary screen are now localized (34 new ARB keys, real Bangla translations, all passing the existing `arb_parity_test.dart` suite — no partial/placeholder translations). Two widget tests (`bike_picker_card_test.dart`, `rider_stat_strip_test.dart`) needed the same `localizationsDelegates`/`supportedLocales` MaterialApp wrapper `skin_dropdown_test.dart` already used, since pumping a widget that calls `AppLocalizations.of(context)` without it throws.
  **Still hardcoded, by remaining string count** (rough — literal single-line `Text('...')` call sites only, so an undercount for hint/label/multi-line text): active_ride_screen.dart (~14), forum_thread_screen.dart (~13), edit_profile_screen.dart (~12), user_profile_screen.dart (~11), my_shared_rides_screen.dart / add_place_screen.dart / garage_screen.dart / bike_detail_screen.dart (~10 each), stats_screen.dart (~9), route_detail_screen.dart (~8), social_screen.dart / ride_share_screen.dart / login_screen.dart (~7 each), and smaller counts across the rest of `features/*`. record_screen.dart itself is mostly *already* dynamic copy (`greetings.dart`) rather than literal strings, so it's a smaller lift than its raw count suggests. Also still open from `marketing.md`: the Play Store listing has no Bangla.
  **Not verified on a device**, same caveat as everything else in this pass: whether the (longer, on average) Bangla translations actually fit the tight stat-cell columns on the ride summary screen and the 11pt bottom-nav labels without wrapping or truncating.
- [ ] iOS build & TestFlight (config scaffolding exists; needs a Mac + Apple Developer account)

---

## Key facts (for whoever picks this up)

| Thing | Value |
|---|---|
| Firebase project | `throttleiqfb` (asia-south1) |
| Android package (all code, `main`) | `com.bft.throttleiq` — **registered in Firebase** since 2026-07-23: App ID `1:603325098273:android:94694220f44cbf63fcf660` |
| File storage | Cloudinary (unsigned upload, cloud name `vjvcigkt`), **not** Firebase Storage — see the "Soon" section above for why. **Needs a manual check** (`Issues.md` §24.9): the unsigned preset `throttleiq_unsigned` is client-extractable from the APK by design — that's not itself a bug — but confirm in the Cloudinary dashboard (Settings → Upload → Upload presets) that it restricts resource type, file size, and has moderation enabled, so a pulled-preset client can't be used for quota exhaustion or hosting arbitrary/illegal content. This needs dashboard login, so it wasn't something fixable from a code change |
| Signing keystore | `throttleiq-release.keystore` (repo root, gitignored) — **back it up**. Its SHA-1 is registered with the Android OAuth client (verified 2026-08-11); `keytool` needs Android Studio's bundled JDK on this machine |
| Local pub cache / Android SDK paths | Machine-specific — whatever's in your own `flutter doctor` output, not fixed values to copy |
| Latest release | [`beta-v2`](https://github.com/blankframe-tech/ThrottleIQ/releases/tag/beta-v2) — signed release **APK + AAB**, matches `pubspec.yaml` at `1.0.0-beta.2+2`. Upload the `.aab` to Play, hand testers the `.apk`. (`beta-v1` is still there as the previous build.) |
| Test suite | 755/755 green as of 2026-08-12 (717 on 2026-08-11; 550 on 2026-08-03; was 287 before the backlog pass). Plus 22 Node tests in `scripts/` (`npm test`) for the Dhaka seed script's pure logic. DAOs now run against real in-memory SQLite via `sqflite_common_ffi` — see `Issues.md` §7 for why that mattered |
| Privacy policy | `https://throttleiqfb.web.app/privacy.html` — live, needed by the Play listing |
| Judgement calls | `Assumptions Made.md` — every non-obvious decision from the backlog pass, with the file to change if you disagree |
| Admin account | `the.abraar.rar@gmail.com`, hardcoded in `forum_permissions.dart` (client-side, cosmetic only) AND, as of 2026-08-12, checked via the `admin` custom claim FIRST with this email as a fallback in `firestore.rules` (`Issues.md` §24.9). Run `scripts/set_admin_claim.js --email the.abraar.rar@gmail.com --yes-i-really-mean-it` once (needs real Firebase Admin credentials) to actually grant the claim, then sign out/in on that account to pick up the new token — the email fallback can be deleted from `firestore.rules` once that's confirmed working |
| DB schema | **v10** (`outbox`, the offline write queue, added 2026-08-14 — `Issues.md` §25). v9 added `rides.moving_s`; v7 added `custom_label` on `maintenance_logs` |
| Offline writes | Anything the rider explicitly asked for that needs the cloud goes through `core/cloud/outbox_service.dart`, **not** a bare `await` on Firestore. An awaited Firestore write with no connection never completes — it doesn't throw — so a direct `await` on a user-facing path hangs the app. `SyncManager` drains the queue on connectivity change, login, and its 5-minute timer. Optional telemetry uses `_bestEffortWrite()` (same idea, just a timeout, no durability) |

---

## Part 2 — Feature Backlog & Ideas

Ideas surveyed against competitor apps, not yet scheduled into a phase.
Effort/tier tags (`T1`/`T2`/`T3`) are rough sizing, not commitments.

### Competitor-inspired feature map (Rever · Calimoto · Detecht · Tonit · EatSleepRide · Strava · Life360)

#### A. Ride intelligence & analytics — make the data ThrottleIQ already collects *mean* something
ThrottleIQ's edge is that it already captures accel + jerk per point; competitors mostly show speed/distance. Lean into it.

| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Lean-angle tracking** per ride (max + per-corner), from gyroscope fused with GPS heading. The single most-loved moto-app stat. `sensors_plus` already provides the gyro. | Calimoto, EatSleepRide | M / **T1** |
| **Personal records & trophies** — longest ride, biggest riding day, smoothest ride (lowest jerk/km), most km in a month. Local-only at first; no backend needed. | Strava | S / **T1** |
| **Weekly riding report** — distance, time, events (hard brakes / rapid accel / top speed), trend vs last week. Reuses the riding-score math; render with `fl_chart` (already a dep). | Life360 driver reports, Strava | S / **T1** |
| **Smoothness score trend** — a per-ride 0–100 score charted over months, "your braking got 12% smoother". Turns the jerk data into a retention loop. | Life360 driver reports | M / **T1** |
| **Year in Review ("ThrottleIQ Wrapped")** — shareable summary card: total km, hours, top speed day, favorite road. Big organic-growth lever, cheap once stats exist. | Strava Year in Sport | M / **T2** |
| **Segments & leaderboards** on popular road stretches. Needs cloud + user mass + safety framing (time-based leaderboards encourage speeding — consider *smoothness* leaderboards instead: on-brand and defensible). | Strava, Rever challenges | L / **T3** |

#### B. Routes & discovery — give riders a reason to open the app *before* the ride
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Saved routes library** — save a past ride as a named route, re-ride it, share it. | All moto apps | M / **T2** |
| **Discover roads from friends' rides** — a shared ride doubles as a route others can save. Falls out of the social feed + saved routes. | Tonit, Calimoto | M / **T2** |
| **Curated "best roads nearby"** — admin-seeded scenic/twisty roads (same admin-verified pattern as the POI directory; a road is just a POI with a polyline). | EatSleepRide (editorial routes), Rever (Butler Maps) | M / **T2** |
| **Ride replay** — animated playback of the polyline with speed/lean overlays on the summary map. High wow-factor, purely client-side. | Rever 3D flyover (lite version) | M / **T1** |
| **Weather along the route / at destination** — one API call (e.g. OpenWeather) on the record screen: "Rain expected in 2h". Rever Pro charges for this. | Rever Pro | S / **T2** |
| **Curvy-route planner + turn-by-turn voice navigation** — the core of Calimoto/Rever. Needs a routing engine (Valhalla/GraphHopper with custom cost functions), offline maps, voice guidance. A product in itself — do NOT attempt before the tracker is solid. | Calimoto, Rever, Detecht | XL / **T3** |

#### C. Safety — extend crash detection into a full safety suite (the most defensible theme for a BD-market app)
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Crash escalation ladder** — countdown, then: notify contacts → if no contact ACKs within N min, SMS all contacts with last location + a "call rider" deep link. Detecht escalates to a human SOS operator; contacts-only is the right V1 scope. | Detecht (60s countdown), EatSleepRide CRASHLIGHT, Life360, Rever Pro | (P1) |
| **"Arrived safely" place alerts** — rider sets a destination; contacts on the live link get an automatic arrive/leave notification (geofence on the live session). Kills the "reached?" text message. | Life360 place alerts | S / **T2** |
| **Privacy zones** — auto-hide the first/last ~200 m of shared rides so home location never leaks. **Prerequisite for ANY ride sharing** — build it, don't defer it. | Strava | S / **T2** (required) |
| **Battery + staleness on the live link** — viewer sees rider's phone battery % and "last seen Xs ago" (Life360 validates surfacing low-battery alerts to the contact). | Life360 | S / (P1) |
| **Hazard pins** — riders drop "pothole / gravel / police check / flood" pins that appear for nearby riders; auto-expire after 24–48h. Same Firestore geo layer as the POI directory. | Detecht hazard warnings | M / **T2** |
| **Group-ride live map** — every member of a group ride sees the others as pins; "regroup" alert if someone falls > X km behind. Extends the live-session doc to a shared session. | Calimoto group rides, EatSleepRide ride groups, Life360 circles | M / **T2** |

#### D. Community & gamification — retention once the tracker earns trust
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Challenges & badges** — monthly distance challenges ("500 km in July"), streaks, milestone badges (first 1,000 km). Local badges already exist (`stats` screen) — add community challenges next. | Strava, Rever, Tonit | S local / M community · **T1→T2** |
| **Ride feed with kudos + comments** — share a ride card (map thumbnail, stats) to a friends feed; respects privacy zones. This is what the Social tab's Feed already does at a basic level — extend with kudos. | Strava, Tonit, Detecht | M / **T2** |
| **Clubs / riding groups** — join local clubs, group chat-lite (announcements), club ride events. | Tonit (its whole product) | L / **T3** |
| **Events & meetups calendar** — club rides and meetups with RSVP; pairs naturally with group-ride live map. | Tonit | M / **T3** |

#### E. Garage & ownership — deepen the existing maintenance moat
| Idea | Proven by | Effort / Tier |
|---|---|---|
| **Odometer auto-sync** — ride distance auto-advances each bike's odometer, driving maintenance reminders without manual entry. | (ThrottleIQ-native; no competitor does this well) | S / **T1** |
| **Fuel log** — liters + cost per fill-up → cost/km and mileage (km/L) trends. Huge in cost-sensitive markets; pairs with fuel-pump POIs ("log a fill-up at this pump"). | Fuelio/Drivvo (adjacent category) | M / **T1** |
| **Documents wallet** — registration, insurance, license photos with expiry reminders. BD riders face frequent document checks; low effort, daily utility. | (market-native idea) | S / **T1** |
| **Resale story** — a bike's full maintenance + ride history as an exportable PDF ("full service history, 92% smooth-riding score") to boost resale value. | (ThrottleIQ-native) | M / **T2** |

### Proposed information architecture (UX pass)

The current nav (Social · Rides · **Record** · Places · Garage, see
`Features.md`) is real and already close to this proposal. This is a
forward-looking reorg if the backlog above gets built out — not yet
implemented:

```
┌──────────┬──────────┬──────────┬───────────┬──────────┐
│   Home   │ Explore  │ ● Record │  Analytics│ Profile  │
├──────────┼──────────┼──────────┼───────────┼──────────┤
│ Feed +   │ POIs     │ (center, │ Rides list│ Garage   │
│ challenges│ hazards │ default, │ trends    │ Service  │
│ friends' │ routes/  │ big CTA) │ records   │ Fuel log │
│ rides    │ best     │ live map │ score     │ Documents│
│ weekly   │ roads    │ quick-   │ year-in-  │ Friends  │
│ report   │ nearby   │ fuel     │ review    │ Emergency│
│          │ weather  │ SOS      │           │ contacts │
└──────────┴──────────┴──────────┴───────────┴──────────┘
```
- **Record stays the center tab and default screen** (unchanged — it's the product).
- **Explore** would fold in POI map + hazard pins + saved/curated routes + weather chip (Places already covers the POI half).
- **Analytics** would fold in ride history, trends, records, weekly report (Rides already covers the core of this).
- **Home** hosts the feed/challenges (Social's Feed tab already covers this).
- **Profile** would absorb Garage + Service, plus fuel log, documents, friends, emergency contacts, privacy settings.
- Safety actions (share live link, SOS) live ON the record/active-ride screens where the rider needs them — big touch targets, one-thumb reachable (44pt+ targets, no precision taps at speed; gloved hands argue for oversized controls throughout the ride surfaces).

---

## Part 3 — Vehicle State Engine: Architecture & Roadmap

_Last updated: 2026-07-23 · Branch: `main`_

### 0. Vision

ThrottleIQ shouldn't be thought of as "a GPS speed tracker." It should be
thought of as a **vehicle state estimation engine**. The output isn't GPS
coordinates — it's a `VehicleState`: timestamp, position, altitude, speed,
acceleration, heading, angular velocity, a confidence score, motion
classification flags (moving/stopped/cornering/braking/accelerating), sensor
quality signals, and (eventually) a map-matched road. Everything else —
ride recording, crash detection, ride scoring, future analytics — reads from
that object instead of computing speed/accel/heading independently in
different places.

That's the target architecture. This doc is honest about how much of it
exists today, phases the rest, and records why each phase was scoped the way
it was.

### 1. The 10-layer architecture — current state

| # | Layer | Status |
|---|---|---|
| 1 | Sensor collection | 🟡 Partial — GPS + accelerometer collected; gyroscope now collected (Phase 1); magnetometer unused |
| 2 | Validation | ✅ Phase 1 — `SensorValidator`, single source of truth |
| 3 | Time synchronization | ⬜ Not built — deliberately unneeded for a complementary filter (see §3) |
| 4 | Sensor fusion | 🟡 Phase 1 — complementary filter, not a full Kalman/EKF (see §3) |
| 5 | Confidence engine | ✅ Phase 1 — heuristic 0-100 score |
| 6 | Motion classification | ✅ Phase 1 — isMoving/isStopped/isCornering/isBraking/isAccelerating |
| 7 | Event detection | 🟡 Pre-existing (`EventDetector`) — untouched in Phase 1, gained one confidence gate on crash alerts |
| 8 | Adaptive recording | ✅ Phase 1.5 — thins what's *persisted* on confident/steady stretches (see §4); GPS hardware polling itself is still fixed 5m/1s |
| 9 | Map matching | ⬜ Deferred entirely (see §5) |
| 10 | Analytics | 🟡 Pre-existing (`rider_stats.dart`, `riding_score.dart`, badges) — untouched, reads ride-level aggregates only |

**Before Phase 1**, layers 2-6 didn't exist at all: GPS and the accelerometer
were two completely disconnected pipelines. `MotionCalculator` derived
`acceleration`/`jerk` purely from consecutive GPS speed samples; the
accelerometer was separately low-pass filtered and used *only* for instant
haptic alerts — never persisted, never reaching `EventDetector`. The
gyroscope and magnetometer were entirely unused despite being available in
`sensors_plus`. No heading was computed anywhere despite `Position.heading`
being available. There was no confidence concept — a crash alert fired on
threshold math alone, with no way to know whether the underlying sensor data
was trustworthy at that moment.

### 2. Phase 1 — Foundation (done, 2026-07-23)

Built: `VehicleState` (unified per-tick entity), `SensorValidator` (single
source of truth for "is this sample garbage"), `VehicleStateEstimator` (the
complementary-filter fusion engine), gyroscope now wired in alongside the
existing accelerometer stream, a heuristic confidence/imuQuality score,
motion classification, and a confidence gate on the crash-detection alert
path (don't act on a crash signal derived from garbage sensor data, e.g.
mid-tunnel GPS loss).

**What Phase 1 deliberately did NOT change**, to keep blast radius small and
protect existing test investment:
- `MotionCalculator` (GPS-derivative speed/distance/accel math, 567 lines of
  existing test coverage) — untouched. `VehicleState`'s heading/confidence/
  classification is an **additive parallel pipeline**, not a replacement.
  `VehicleState.accelerationMs2` is still GPS-derivative, not IMU-fused —
  fusing the accelerometer into the persisted acceleration value is real
  signal-processing work (the phone's mounting orientation is unknown/
  arbitrary — see the existing "dominant axis" heuristic on the haptic
  alert path) and touches the one code path with the deepest existing test
  investment. The IMU is used for what it's uniquely good at instead:
  heading dead-reckoning between GPS fixes, motion classification, and
  confidence scoring.
- `EventDetector`'s public signature — untouched, protects
  `crash_detector_test.dart`. Only what its caller passes it changed (the
  confidence gate).
- The existing accelerometer-driven haptic alert path (`_onSensor`'s
  dominant-axis low-pass filter) — untouched, works today, no reason to risk
  it without live-device testing available in this environment.
- No UI/screen changes. `RideRecordingState` gained one plumbing field
  (`confidence`) so a future screen can surface it cheaply — nothing
  currently displays it.

**Database**: `ride_points` schema v5→v6 adds 4 nullable columns —
`heading_deg`, `confidence`, `imu_quality`, `is_cornering`. Deliberately
*not* persisted: `isBraking`/`isAccelerating` (exactly reproducible from the
already-stored `acceleration` column via the existing thresholds) and
`isMoving`/`isStopped` (already encoded by the existing `periodType`
column) — avoiding redundant schema bloat.

**Why this is the future ML training corpus**: the AI State Estimator idea
(§6) needs a real corpus of labeled ride data to be anything but a guess.
Phase 1 persists `confidence`/`heading`/`isCornering`/`imuQuality` per point
now, even though nothing consumes them yet, specifically so that corpus is
already accumulating by the time Phase 4 becomes viable — additive later,
not a rewrite.

### 3. Phase 2 — Full EKF (future, not started)

Replace `VehicleStateEstimator`'s internals with a proper Extended Kalman
Filter — a real state vector (position×2, velocity×2, heading, yaw-rate,
possibly an accel-bias term), covariance propagation, and Jacobians for the
nonlinear GPS-lat/lng-vs-local-frame relationship.

**Why not now**: an EKF's value is entirely in its noise tuning (process
noise Q, measurement noise R), and tuning those blind — without a real
corpus of ride logs to validate against — is more likely to produce a filter
that's confidently wrong than one that's actually better than the
complementary filter it replaces. The complementary filter degrades
gracefully with imperfect constants; an EKF with bad tuning can diverge.
Phase 1's persisted `VehicleState` data is exactly the corpus this phase
needs to exist first.

**Known prerequisite**: `vector_math` is only a *transitive* dependency
today (pulled in by `flutter_map`), not declared in `pubspec.yaml`, and is
capped at 4×4 matrices — a realistic EKF state vector needs more. Either
promote it to a direct dependency and hand-roll the matrix math, or add a
proper linear-algebra package. Not resolved now.

**Design constraint carried over from Phase 1**: `VehicleStateEstimator`'s
public interface (`addGpsSample`/`addAccelSample`/`addGyroSample`/
`currentState`) was kept intentionally minimal and sample-driven so this
phase can replace the class's *internals* without changing any of its
callers.

### 4. Phase 1.5 — Adaptive recording (done, 2026-07-23)

**Important scoping clarification found while building this**: geolocator
doesn't support changing GPS polling settings mid-stream, so this phase does
**not** touch the underlying 5m-distance/1s-interval GPS sampling rate —
that stays exactly as fixed as it was in Phase 1. What it actually adapts is
which fixes get **persisted** to `ride_points`: a new `RecordingCadencePolicy`
(pure, unit-tested, same pattern as the other calculators) throttles writes
to at most one per `SensorConstants.minPersistIntervalOnSteadyStretches`
(5s, matching the original vision's own "1 point every 5 seconds on a
straight highway" example) whenever `VehicleState.confidence` clears a
conservative floor (70/100) and none of cornering/braking/accelerating are
true. Anything "interesting," or anything the fusion engine isn't
confident about, is always kept at full fidelity.

**Confirmed real trade-off, not just a storage optimization**: both
`ride_summary_screen.dart` and `ride_share_screen.dart` rebuild their
polyline by reading `ride_points` back from the DB — so thinned writes
directly mean a visibly lower-resolution polyline on boring stretches, not
just a storage-only change invisible to the rider. This was confirmed and
explicitly signed off on before building it, rather than assumed.

**What stays untouched, deliberately**: the live in-ride map polyline
(`RideRecordingState.polyline`) still appends every GPS fix, unthinned —
only the post-ride replay/summary/share view is affected. The ride-level
aggregate stats (`distanceM`/`avgSpeedMs`/`maxSpeedMs`) and
`MotionCalculator`'s accel/jerk derivative chain (`_lastPoint`) both still
see every consecutive GPS fix regardless of the persistence decision —
thinning only gates the one `_pointBuffer.add(...)` call.

### 5. Phase 3 — Map matching (deferred entirely)

Snapping GPS to the actual road (`estimatedRoad` on `VehicleState`, always
null today) needs an external road-network source. Two options were
surfaced but **neither was chosen or built**:
- **OSRM's public demo server** — free, no signup, same "free public API"
  precedent as the existing Overpass POI-import integration. Rate-
  limited and not meant for production traffic, so it would need a real
  backend swap before launch.
- **A paid map-matching API** (e.g. Mapbox Map Matching) — production-grade,
  but a recurring cost and a new API key/secret to manage, which this
  project doesn't have any infrastructure for today.

This is a genuinely separate initiative from the fusion engine and doesn't
block anything else in this roadmap. Revisit when it's actually prioritized.

### 6. Phase 4 — AI State Estimator (deferred, designed for)

The original pitch: instead of relying solely on fixed thresholds (hard
brake if decel < -4 m/s², crash if accel > 80 m/s² etc.), train a
lightweight on-device model on a real corpus of rides to recognize patterns
— smooth vs. aggressive riding, urban commuting vs. highway touring,
pothole impacts vs. crash impacts, typical behavior for a specific rider.
The model would sit on top of the fused `VehicleState`, not replace it,
learning what's "normal" per-rider over time.

**Why not now**: the app is pre-launch with no ride corpus to train on —
building this now would mean guessing at a model architecture and training
process against data that doesn't exist yet. **Why it's still designed
for**: Phase 1's persisted per-point `confidence`/`heading`/`isCornering`/
`imuQuality` fields are exactly the kind of clean, structured, per-tick
labels a future model would want. Revisit once there's a real corpus of
completed rides (post-launch, real usage) to work from.

### 7. Open items / honest limitations

- **No live sign-in/ride walkthrough was possible for Phase 1 or 1.5** —
  same environment limitation as previous sessions (no simulator
  input-automation tool available to sign in and record a real ride).
  Verified instead: full unit-test suite (`sensor_validator_test.dart`,
  `vehicle_state_estimator_test.dart`, `recording_cadence_policy_test.dart`,
  282 tests total, all green), `flutter analyze` clean, and a clean
  `flutter run` boot confirming Phase 1's v5→v6 schema migration applies
  without error (Phase 1.5 has no schema changes of its own). A real
  device/ride walkthrough — confirming GPS+gyro actually produce sensible
  confidence/heading values in practice, watching the thinning policy
  actually behave sensibly on a real commute, and tuning the heuristic
  constants (imuQuality penalties, confidence weights, cornering threshold,
  the thinning confidence floor and interval) against real riding — remains
  the first thing to do once this is testable on a real device.
- **iOS location settings**: `_startLocationStream()` unconditionally
  constructs an `AndroidSettings` object with no `IOSSettings`/
  `Platform.isAndroid` branch — pre-existing, not introduced or fixed by
  this work, just noted while reading the file closely.
- **imuQuality/confidence formulas are first-pass heuristics**, explicitly
  expected to need real-device tuning — same honest framing as the
  crash-threshold fix ("user will fine-tune with real rides").
