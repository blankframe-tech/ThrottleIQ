# Issues: open

_Was `Issues.md` until 2026-09-19. Resolved sections moved to `issues_fixed.md`._
Every issue that's still unresolved, in its original numbered section.
Section numbers (`§N`) never change. When something here gets fixed, move
its section or subsection to `issues_fixed.md` and keep the number.

New issues go at the end of this file with the next free number: **§103**. (§97–§102 are taken in this file. §97 is also used in `issues_fixed.md` for a different writeup: here it is the Places/Forums first-iPhone-run findings, there it is the forum photos / paddock counts fix. §85 exists in both files — the stub here and the writeup in `issues_fixed.md`. §78 sub-items run to 78.30; §83 to 83.31. Note §79 and §81 are each used twice, and §82 was taken before §83 — check BOTH this file and `issues_fixed.md` before claiming a number.)

---

## Follow-ups on fixed issues

These sections are in `issues_fixed.md` because the core problem is resolved,
but each one leaves a smaller item behind:

- **§4:** the Firestore TTL policy on `liveSessions.expiresAt` still has to be enabled, and older docs with string timestamps will never be reaped.
- **§34:** the "signing error" APK report was never confirmed on an affected device. The crash that actually got reported was resolved by §35/§50.
- **§37:** the new auto-tracking schedule feature hasn't been verified on a device yet.
- **§42:** the road-speed baseline has the verification gaps listed in its "NOT yet verified" block.
- **§49:** the GPS-speed fallback still needs verifying on a real device, because simulator location playback doesn't populate `Position.speed`.
- **§53:** testers have to re-open the opt-in link before the internal track reaches them.
- **§62.1–§62.10:** the items marked PARTIALLY FIXED list their remaining work inline.
- **§98:** OS home/lock screen widgets (Apex Hunter, Ride Stats, Maintenance) and in-app cockpit telemetry widgets (DualLeanArcGauge, GForceFrictionCircle, ConsumablesHealthCard) need physical device verification (iPhone 15 release deploy & Android), checking App Group sharing in Xcode and Lock Screen accessory layouts.

---

## 13. QA report

**Status:** Not started.

_No QA pass has been written up yet. When one is done (manual smoke test,
device walkthrough, or a scripted run), record findings here as dated
sub-sections — one per pass — rather than overwriting this placeholder._

---

---

## 32. UI/UX critique of the current screen set — FIXED (2026-09-21)

> Full writeup in `issues_fixed.md` §32. The taste calls (slide-to-start
> friction, "In jam", chart axes, theme-picker previews, low-contrast pass) are
> **deliberately not being done** — do not re-raise them as bugs.

The one item from that list still open is **Emergency Contacts is exposed in
Settings while explicitly non-functional** — the copy says alerts "aren't live
yet". Not part of the 2026-09-21 decision; still a false-sense-of-security risk.

---

## 33. Bug & vulnerability sweep — 5 parallel reviews, 18 findings, 16 fixed same session, 2 deferred (2026-08-23) (open parts)

> The resolved parts and the full context of this section are in `issues_fixed.md` §33.

### 33.5 Cloudinary unsigned-upload credentials are public and unbounded — HIGH

**Status: DEFERRED — not code-fixable right now, documented instead.**
Closing this properly means signed uploads: a Cloud Function mints a
short-lived signature per upload and the client sends that instead of the
public unsigned preset. This project's Cloud Functions cannot deploy at all
today — confirmed in §24's audit — because `throttleiqfb` is on the Spark
(free) plan and `artifactregistry.googleapis.com`, required for any
Functions deploy, needs Blaze. The same blocker that stops §24.8/§24.9's
Cloud Functions from ever running stops a signed-upload fix from ever
running either; shipping the Cloud Function code without the ability to
deploy it would fix nothing while looking fixed. Real fix, once Blaze is
adopted: add a callable Function that returns a signed upload signature,
switch `CloudinaryUploadService` to request one before each upload. Interim
mitigation available today, outside this repo: restrict the
`throttleiq_unsigned` preset in the Cloudinary console itself (max file
size, format allowlist, moderation add-on) — preset-level config, not
something a code change here can reach.

`cloudinary_upload_service.dart:28-31` ships a plaintext cloud name
(`vjvcigkt`) and unsigned upload preset (`throttleiq_unsigned`) in the
binary — trivially extracted via `strings` on the APK/IPA. Anyone can POST
directly to that Cloudinary endpoint from outside the app, indefinitely, with
no ThrottleIQ account and no rate limiting on the client side — a
quota-exhaustion or abusive-content griefing vector against the project's
Cloudinary account.

### 33.6 Storage rules don't mirror Firestore's audience tiers for ride-share photos — MEDIUM

**Status: CORRECTED SCOPE, PARTIALLY FIXED.** Turns out `storage.rules` is
currently **dormant, not a live security boundary**: `firebase.json` has no
`"storage"` key at all (only `firestore`/`functions`/`hosting`), so these
rules are never deployed, and the Flutter client has no `firebase_storage`
dependency in `pubspec.yaml` — every avatar/ride-photo upload goes through
`CloudinaryUploadService` instead (see §33.5), not Firebase Storage at all.
So today there is nothing here to exploit either way.

Fixed anyway, as defense-in-depth for whenever Storage is wired back up:
`storage.rules` now caps write size (5MB avatars / 10MB ride photos) and
requires `contentType` to actually be an image — that part is simple,
self-contained Storage-rules syntax, safe to harden without a live deploy to
verify it against. The audience-tier mirroring itself (calling out to
Firestore from a Storage rule via `firestore.get()` to check the matching
ride's `audience`) is real, documented syntax but was NOT added — this repo
has no Storage-rules emulator test harness the way `scripts/test/rules/`
covers Firestore, and shipping untested cross-service rule syntax for
currently-dormant infrastructure risks a silent typo nobody notices until
the day it actually matters. Left as a follow-up for whenever `"storage"` is
added back to `firebase.json`: mirror `rideVisibleTo()` via `firestore.get()`
on the ride doc, and add it to a real `firebase emulators:exec --only
firestore,storage` test before trusting it. Noted in `storage.rules` itself
so this isn't lost.

`storage.rules:18-21` makes `rideShares/{uid}/{filename}` readable by any
authenticated user, full stop — but the associated ride doc in
`firestore.rules` can be scoped to `followers`/`mutual`/owner-only via
`rideVisibleTo()`. Anyone who obtains the photo path (UUID-based but not
secret) sees it regardless of the ride's actual audience; privacy relies on
URL obscurity, not authorization.

---

## 62. Full-repo bug/vulnerability/architecture sweep — 4 parallel reviews, 26 findings, most fixed same session (2026-09-10) (open parts)

> The resolved parts and the full context of this section are in `issues_fixed.md` §62.

### 62.11 Storage rules: ride-share photos ignore ride audience — MEDIUM (dormant)

**Status: still deferred, unchanged.** This was already correctly deferred
before this audit — `storage.rules`' own comment (§33.6) already explains
why: no Storage emulator test harness exists to verify a cross-service rule
(`firestore.get(...)` from within a Storage rule) against, and the file
isn't even deployed today (`storage` absent from `firebase.json`). Re-fixing
it blind now would repeat the exact mistake that comment already warned
against. Left exactly as-is.

`storage.rules:59-64` grants `read: if request.auth != null` on
`rideShares/{uid}/{filename}` unconditionally, not gated by the matching
ride's `public`/`followers`/`mutual` audience the way the Firestore doc
itself is. Currently inert — `storage` isn't wired in `firebase.json` and
the client has no `firebase_storage` dependency — but if Storage is ever
turned on without this fix, a "followers-only" ride's photos become
readable by any authenticated user, silently breaking the privacy model
users believe they have. Already flagged in the file's own comments as
unresolved.

### 62.12 No App Check, no rate limiting anywhere — MEDIUM

All Cloud Functions are background triggers, not callables, so there's no
missing-auth-on-callable issue — but there's also no App Check enforcement
and nothing in the rules throttles write volume for ride shares, forum
posts, chat messages, or reviews. Combined with §62.1/§62.2/§62.5, a
scripted client can cheaply flood leaderboards, self-grant badges, or spam
feeds at effectively unlimited rate.

### 62.13 Architecture notes (not bugs, but raise the odds of the next one) — none attempted this session

- `firestore.rules` is a 1216-line monolith that grew patch-by-patch (many
  inline comments cite specific past `Issues.md` fixes) rather than from
  an upfront threat model — exactly how §62.1's broad owner-update clause
  could silently outflank the narrow, well-validated bump-counter rules
  sitting right next to it.
- Counter-bump validation (`likeBumpValid`/`voteBumpValid`/`newDocBy`/
  `docRemoved`) is duplicated per collection (rides' likes/votes/comments,
  forum posts' votes/replies) instead of generalized once.
- `cloud_repository.dart` (538 lines) is a God-repository spanning bikes,
  rides, maintenance, tracks, and exports; it also contains a second,
  independent GPX/JSON export implementation
  (`exportToJSON`/`exportToGPX`/`_generateGPX`, `:448-515`) that duplicates
  `export_service.dart:24-121` with different target directories and no
  `<bounds>` computation — a fix to one will drift from the other.
- `isAdmin` is hardcoded to one email client-side
  (`forum_permissions.dart:5,10-11`) and manually mirrored in
  `firestore.rules:87-91` — not currently spoofable, but the two can drift
  silently since nothing ties them together.
- `scripts/seed_police_checkposts.js`/`_v2.js`/`_v3.js` reimplement the
  same geohash-encoder/dry-run scaffolding three times (~500 lines) for
  what should be one shared module plus data files.

---

## 64. Open parts of §64 (chat `permission-denied` report) — 63.3 Cloudinary unsigned preset NOT FIXED; the resolved parts are in `issues_fixed.md` §64

> The resolved parts and the full context of this section are in `issues_fixed.md` §64.

### 63.3 Cloudinary unsigned upload preset lets anyone who decompiles the app bypass it entirely — MEDIUM (no safe code-only fix this session)

**Status: NOT FIXED — flagged, no code change made.**
`app/lib/core/services/cloudinary_upload_service.dart:28-39` embeds a cloud
name and an *unsigned* upload preset as plain Dart constants — trivially
extractable from a strings dump of the compiled APK/IPA, no reverse
engineering needed. Because the preset is unsigned by design (that's the
whole point of an unsigned preset — no API key/secret required), anyone
holding these two strings can `POST` directly to Cloudinary's own API
(`/image/upload` and `/video/upload`, the latter also accepting arbitrary
audio per this file's own comment) with any `folder` of their choosing,
completely bypassing Firebase Auth and the app itself. Concrete abuse:
quota-exhaustion against the project's Cloudinary free tier (denial of
service by cost), or hosting arbitrary/objectionable content under this
project's Cloudinary account, risking a ToS suspension that would take down
avatar/ride-photo/voice-note uploads for every real user at once.

This isn't a bug in the file — the comment there is correct that "nothing
secret is embedded here," that's inherent to how unsigned presets work —
and the real fix (switching to signed uploads, where an authenticated
Cloud Function mints a short-lived signature using a `CLOUDINARY_API_SECRET`
that only ever lives server-side) is a genuine architecture change, not a
bug fix: a new callable Cloud Function, a client-side change to request a
signature before every upload, and end-to-end verification against a real
Cloudinary account and deployed Functions environment this session has no
access to. Attempting it blind risks silently breaking every upload path
(avatars, ride photos, voice notes) with no way to verify the fix actually
works. **Immediate, lower-risk mitigation that doesn't require code
changes:** check Cloudinary console → Settings → Upload →
`throttleiq_unsigned` for a file-size cap and format allowlist — if neither
is set, add them; that alone closes the worst of the quota-exhaustion/
content-hosting abuse without touching a single line of app code. The
signed-upload architecture change is a real follow-up worth doing but
belongs in its own session with Cloudinary/Functions credentials in hand to
verify against.

---

---

## 65. User report: app feels "clunky and slow to respond" during ride sharing and pause/resume — MOSTLY FIXED (2026-09-17) (open parts)

> The resolved parts and the full context of this section are in `issues_fixed.md` §65.

### 65.6 Cold-resume can freeze the launch frame on a long interrupted ride — LOW/MEDIUM

`RideRecordingNotifier.restoreInterruptedRide`
(`ride_recording_provider.dart:842-929`, run at app launch when a ride was
killed while paused) does a fully synchronous aggregate rebuild
(`ride_resume.dart`'s `rebuildRideAggregates`, two linear passes) plus a
point-by-point polyline reconstruction, all on the main isolate. For a ride
with many thousands of stored points this is a plausible freeze right when
the "we kept your ride" recovery banner should appear — which is itself a
resume path.

**Not investigated as bugs, confirmed as already well-engineered** (ruled
out during this audit, worth recording so a future pass doesn't re-check
them): the map widget (`active_ride_screen.dart`'s `const _RouteMap()`)
is deliberately const to skip rebuild on every tick; the sensor fusion
pipeline (`sensor_fusion_coordinator.dart`) already throttles UI pushes to
5Hz against a 20Hz sample rate; the outbox's ride-point buffering
(`ride_persistence_coordinator.dart`) batches SQLite writes sensibly; the
polyline outbox payload already uses the flat-array format called for in
`docs/optimizerplan.md` item 15 (that item is stale/done).

**Status: §65.0–§65.5 fixed this session. §65.6 not fixed** — deliberately
deferred rather than rushed: `rebuildRideAggregates` and the
`_appendToPolyline` replay loop both mutate/read the notifier's own
instance state incrementally, so moving them to a `compute()` isolate
needs restructuring into "compute pure aggregates off-thread, then apply
once on the main isolate" rather than a drop-in change, and on reflection
the actual cost here is smaller than it first looked: `_appendToPolyline`
already decimates to a 2000-point cap in amortized-O(n) work, and
`rebuildRideAggregates` is two cheap linear passes — likely tens of
milliseconds even for a multi-hour ride, not the freeze originally
suspected. Left as a documented low-priority item rather than risking a
main-isolate/state-mutation refactor for a marginal, unconfirmed gain.

**2026-09-19: benchmarked, closing as non-issue.** Ran both loops
(`rebuildRideAggregates` + the `_appendToPolyline` decimation loop) against
36,000 synthetic fixes — the point count a 4-hour ride produces at this
app's `distanceFilter: 3` GPS setting and typical urban riding speed.
Combined: **~10ms** on dev hardware (aggregate rebuild ~8ms, polyline
rebuild ~1.5ms), even at a multi-hour scale well past what most
interrupted rides will hit. A mid-range phone at 3–5x slower is still
comfortably under a frame-drop-visible threshold, and moving this to
`compute()` would spend more on isolate spawn + serializing tens of
thousands of records across the boundary than it would save. No code
change made — the deferred assessment above was correct; this closes the
loop with a number instead of an estimate. **Status: confirmed non-issue,
no fix needed.**

---

## 69. Full-repo critique pass — 12 fixed, 16 open (2026-09-19) (open parts)

> The resolved parts and the full context of this section are in `issues_fixed.md` §69.

### Open — found, not fixed (each needs a decision or a bigger change)

> **69.O7, 69.O9, 69.O11, 69.O12, and 69.O15 were fixed 2026-09-19** (and
> part of 69.O13 — see that entry below) — full writeup in
> `issues_fixed.md` §69. Removed from this list.

- **69.O1 (partially fixed 2026-09-19) Privacy policy contradicted the app
  on the microphone.** `public/privacy.html` §1 said "no microphone", but
  group-ride push-to-talk records audio (`RECORD_AUDIO`, `record` package),
  uploads it to Cloudinary and shares it with ride members. The page text
  was corrected (voice clips added to §1, §4 and §5) and **is now deployed**
  — confirmed live at `https://throttleiqfb.web.app/privacy.html`.
  `store_listing/data_safety_and_permissions.md` is updated to match.
  **Still open:** the actual Play Console Data Safety form itself needs the
  "Audio → Voice or sound recordings: collected, shared" answer set — that's
  a Play Console UI action, not a file in this repo, so it can't be done
  from a code change. Voice-note Cloudinary URLs are also still public to
  anyone who has the URL (a narrower restatement of §33.5/§63.3's unsigned-
  upload issue).
- **69.O2 Account-deletion scope** (see 69.8): decide whether authored
  community content gets anonymized or deleted, and cover Cloudinary assets
  (ride photos, avatars, voice clips). None of those are deleted today.
- **69.O3 Crash alerts can't be cancelled server-side.** Once the countdown
  expires and a `crashNotifications` doc is written, "I'm OK" only resets
  local state. `firestore.rules` gives the client no update on that
  collection, so escalation would still fire. Delivery is a mock today, so
  this is latent, but it has to be solved before real SMS ships.
- **69.O4 (FIXED on `fix/grill-78`, issues_fixed.md §78.C) Outbox has no poison-pill limit.** A write that rules reject
  (e.g. 69.1, or a share queued by user A and drained while user B is
  signed in) retries forever at the 30-min backoff cap. Consider discarding
  `permission-denied` after N attempts and surfacing it to the rider.
- **69.O5 Localization coverage.** 39 screens import no `AppLocalizations`
  at all, including login/register/onboarding, the active-ride screen,
  garage, maintenance, the whole social feed and forums. The EN/BN
  positioning only really holds for the screens that are localized.
- **69.O6 (FIXED on `fix/grill-78`, not deployed; issues_fixed.md §78.F) Cloud Functions runtime.** `firebase.json`/`package.json` pin
  Node 20, which Google has deprecated for Cloud Functions (decommission is
  scheduled for late Oct 2026). `firebase-functions` is `^4.8` (current
  major is 6+). Upgrade before the next functions deploy.
- **69.O8 `USE_FULL_SCREEN_INTENT`** (crash alert). Since Android 14, Play
  restricts full-screen intents to calling/alarm apps unless a declaration
  is approved. Needs a Play Console declaration or a fallback.
- **69.O10 (FIXED on `fix/grill-78`, issues_fixed.md §78.A/§78.B) `crash`-status rides never sync.** `_onCrashDetected` writes
  `status: 'crash'`, and `RideDao.getUnsynced` only uploads `completed`. A
  ride that's killed while in the crash state stays local-only.
- **69.O13 Docs reorganization loose ends (partially fixed 2026-09-19,
  issues_fixed.md §69): a few design assets deleted from `designs/`** (logo
  concepts `logos1/*`, `logo_preview_demo.html`, the Facebook profile
  mockup, `docs/new/*` reference images) weren't carried into `DOCS/`.
  Presumably intentional; they're still in git history. (The stale
  `docs/Issues.md` code-comment citations and the `For Devs and
  Contributers` misspelling, also flagged under this number, are fixed —
  see `issues_fixed.md` §69.)
- **69.O16 `docs/` vs `DOCS/` casing: RESOLVED in the 2026-09-19 reorg
  commit.** On this case-insensitive disk (`core.ignorecase=true`), `git add`
  had quietly staged all 330 moved files under the old lower-case `docs/`,
  which would have broken every `DOCS/…` link on GitHub. Fixed by
  re-staging with `git rm -r --cached docs && git add DOCS`. Watch for it on
  any future case-only rename.
- **69.O14 `GoogleService-Info.plist` is tracked** even though
  `.gitignore` lists it (committed before the ignore rule). It's client
  config, not a secret, but the ignore rule is misleading.

### Deploy needed

- ~~`firebase deploy --only firestore:rules` — 69.1, 69.2.~~ **DEPLOYED
  2026-09-19** — see `issues_fixed.md` §69.13.
- `firebase deploy --only functions` — 69.8, 69.9, 69.10 (and
  `onUserAccountDeleted` itself has never been deployed, per its own doc
  comment). Consider doing 69.O6 first. **Attempted 2026-09-19, blocked**:
  `Your project throttleiqfb must be on the Blaze (pay-as-you-go) plan to
  complete this command` — same pre-existing blocker as the rest of "Soon"
  in `HANDOFF_Document.md`, not something this attempt changed.
- ~~`firebase deploy --only hosting` — 69.O1's privacy-page correction.~~
  **DEPLOYED 2026-09-19** — confirmed live at
  `https://throttleiqfb.web.app/privacy.html`.

## 78. Antigravity grill verification: still open (surfaced 2026-09-20)

The full verdicts and fix instructions are in
`ANTIGRAVRITY_GRILL/claude_sol.md`. Most §78 items were **fixed on 2026-09-20** and are
now on `main` (e351b6c), though not deployed and not device-tested. That work is written up in `issues_fixed.md` §78, which also
lists what still needs a device check.

What remains open:

- **78.1 Crash detection is built but switched off.**
  **DECISION 2026-09-21: leave as-is, no further work.** The flag stays
  `false` and every user-facing claim has been removed (issues_fixed.md
  §83.1). Recorded here so it isn't re-raised. One thing still outstanding
  that the founder owns: the pitch deck (§78.25) still claims working crash
  detection.
  `SensorConstants.impactDetectorLiveEnabled = false`. Turning it on would
  need two things:
  - the founder's choice of alert delivery (`DOCS/needs_attention.md` b);
  - field rides plus a padded drop test to calibrate the thresholds
    (claude_sol §1.1.1 step 6).
- **78.12 Gyro heading sign and axis** (`vehicle_state_estimator.dart`).
  This needs a mounted phone to verify, so it wasn't attempted.
- **78.16 Tile provider not chosen.** The shared cached tile layer is in
  place. Release builds still hit `tile.openstreetmap.org` until `TILE_*`
  defines point at a provider.
    **2026-09-21: the build wiring is done** — `scripts/deploy.sh` passes `TILE_URL_TEMPLATE` / `TILE_API_KEY` / `TILE_ATTRIBUTION` from the environment as `--dart-define` and warns when unset (WIRING DONE). Still needs the founder's provider key; nothing to change in code.
- **78.18 Keystore: ✅ BACKED UP (founder, 2026-09-21).** That half is closed.
  **Still open:** CI exists but has never run on GitHub, and `main` has no
  branch protection — so the analyze/test/rules gates are enforced on the
  founder's laptop and nowhere else. Founder action, scheduled next week.
- ~~**78.21 Route navigation doesn't record the ride.**~~ **DONE 2026-09-21** —
  see `issues_fixed.md` §78.21. Following a saved route now starts (or attaches
  to) a real recording; the navigation session is fed by the recorder's fixes,
  so there is one GPS stream instead of two, and the ride lands in history with
  the route stamped on it (schema v17).
  **What is still open on it:**
  - **Nobody has ridden it.** Narrower than it was: a **GPX replay harness**
    now exists (`test/features/routes/gpx_replay.dart` +
    `navigation_replay_test.dart`, 15 tests) and drives a whole trail through
    the same session the cockpit uses — turns firing in order, off-route
    raised and cleared, corners taken wide, a 20× gap in fixes, pause, and
    ending mid-route. Drop a real exported ride into
    `test/features/routes/fixtures/` and it reads that the same way; the
    checked-in fixture is synthetic and says so.
    **What replay still cannot reach** is everything below the session:
    `Geolocator`, the permission prompts, the foreground service, the wakelock
    and persistence are all constructed inline by `RideRecordingNotifier` and
    can't be substituted (§83.13). A real ride is still the only check on
    those, and on battery/thermal behaviour.
  - **A restored ride doesn't restore its guidance.** `restoreInterruptedRide`
    brings back a ride picked up off disk at launch, and that ride keeps its
    `route_id`, but the navigation session is in-memory and starts empty. The
    rider has to re-open the route to get the banner back. Deliberate — the
    alternative is re-fetching a route document during launch recovery.
  - **Navigating without recording is no longer possible.** That was the
    approved call (the two loops should compose), but it is a real behaviour
    change: a rider who only wants the line on screen now gets a ride they have
    to discard. Worth watching in beta feedback.
  - **A ride that followed a route won't download onto a pre-v17 install.**
    `downloadRides` inserts cloud fields verbatim, and the guard that filters
    unknown columns only exists from this build on. Ordinary rides are
    unaffected (the fields are omitted when null). Bounded by beta scale;
    it disappears once this release is what everyone is running.
  - **`timesRidden` is still a dead counter** — see §85.

- ~~**78.24 SafeQR has no "Print sticker"**~~ **DONE 2026-09-21** — see `issues_fixed.md` §78.24.
- **78.25 The pitch** (`iDEA_PITCH_SUBMISSION.md` Slide 9, lines
  36/76/107) still claims working crash detection and a team the repo
  history doesn't show. It waits on founder decision c. The in-app
  emergency-contacts copy is fixed.
- **New from the fix pass:**
  - ~~**78.26** `HoldToStartButton` same-frame release~~ **FIXED 2026-09-21** — see
    `issues_fixed.md` §78.26 / §78.29.
  - **78.27** The chat-create rule now requires the fixed DM id. Builds
    from before the fix can't start new chats once the rules are deployed.
    Ship the app before the rules.
  - **78.28** New Bangla strings (emergency banner and acknowledgement,
    SafeQR share, moving/stopped) need a native-speaker review. **2026-09-21:
    a reviewer is available** — keep translating and hand off each batch
    marked pending. The §83 cockpit alerts are also awaiting this review.
  - ~~**78.29** "Sync issues" screen not localized; `_attemptOne` not scoped to the rider~~
    **FIXED 2026-09-21** — both halves; see `issues_fixed.md` §78.26 / §78.29.
  - ~~**78.30** crash badge in ride history~~ **DONE 2026-09-21** — see
    `issues_fixed.md` §78.30.

## 79. Places screen: "Browse routes →" button clashes visually with its neighbors — FIXED (2026-09-20)

> Full writeup in `issues_fixed.md` §79.

---

## 79. QA-seed likes/comments written to the live feed, and the cleanup script doesn't remove them (2026-09-20)

On request, 14 likes and 3 comments were written by hand onto the
founder's public shared ride `5a905c0a-a468-46a0-823c-b43ae3573c82`
("Saturday state of mind"), using 14 of the 30 `qaSeed` rider accounts.
The post's `likes`/`comments` tallies were set to match the documents, so
the rules' tally checks still hold and the in-app like/comment flow keeps
working on top of it.

- Every document carries `qaSeed: true`, like the rest of the seeded
  content.
- **The gap:** `cleanup_qa_test_riders.js` deletes seeded users,
  usernames, shared rides and forum posts, but **not** likes or comments a
  seeded account left on someone else's post. So these 17 documents
  survive a cleanup, and their counter bumps stay on a real rider's post.
  Either extend the cleanup script (a `collectionGroup` sweep for
  `qaSeed == true` on `likes`/`comments`, decrementing each parent's
  tally) or write a one-off remover.
- **STATUS 2026-09-21: APPLIED to production. This item is closed** — see
  `issues_fixed.md` §79/§80 for the before/after counts and the verification run.
  The blocker was mechanical: the script's typed-confirmation prompt has no TTY in
  an agent shell, so `--non-interactive` (which it already supported) is what the
  earlier session needed. History below, kept because the dry-run numbers are the
  record of what was on the live project.
  `scripts/cleanup_qa_engagement.js` (dry-run by default; typed confirmation) finds
  seeded comments/likes per shared ride with single-field queries (no collection-group
  index needed) and lowers each parent's `comments` tally. **Production dry run:**
  98 shared rides scanned; exactly the documented **3 comments on `5a905c0a-…`**
  (tally 3 → 0); 0 likes (already gone); 47 `qashare_*` rides carry the dead `likes`
  field (§80). The agent session that wrote it was **blocked by the environment from
  running the live write**, so someone with the go-ahead has to run it:
  `cd scripts && FIREBASE_PROJECT_ID=throttleiqfb npm run cleanup:qa-engagement:execute`
  (then the dry-run command again should report nothing). Uses application-default
  credentials that must resolve to `throttleiqfb`.
- This is on `throttleiqfb`, the same project real beta testers use, so
  the comments are visible to them.
- Fabricated engagement on a founder post shouldn't be used as evidence of
  traction in the pitch or store listing. See §72 for the earlier
  marketing-overclaim pass.

---

## 80. Retired `likes`: 97 QA-seed rides still carry a dead `likes` number (2026-09-20)

**Code and the real data: DONE** — see `issues_fixed.md` §80.

**CLEARED 2026-09-21** by the same script as §79 (`cleanup_qa_engagement.js`) — the live
count was **47** rides, not 97, and is now **0**. The only thing still outstanding here is
the rules tidy-up noted at the bottom of this section.

**What's left:** a sweep of the feed found **no like documents anywhere**,
but 97 shared rides still carry a `likes` integer on the ride doc. All 97
are `qashare_*` QA seed rides whose counts were fabricated by
`seed_qa_test_riders.js`; that script no longer writes the field. Nothing
reads it, so this is cosmetic — clear it on the next reseed, or with a
`FieldValue.delete()` sweep.

~~`firestore.rules` still has its `likes` clauses.~~ **DONE and DEPLOYED 2026-09-21
(evening)** to `throttleiqfb` (`firebase deploy --only firestore:rules`; 114 rules tests
passing first). The create/owner-update tally clauses, the ±1 bump branch and the
now-unused `likeBumpValid` helper are gone; three rules tests pin the new
contract (114 passing, was 113). **The `match /likes/{userId}` block stays on
purpose** — `deleteSharedRide` still *lists* that subcollection to sweep up
legacy documents, and a list against a path with no matching rule is denied
even when it would return nothing, so removing it would turn every share-delete
into permission-denied. It can go one release after the app stops sweeping, in
that order (§78.27: ship the app before the rules).

**Deployed. Consequence to know about:** a build that can still *like* a ride now fails
at that write. `beta-v3.0.2` (released after the like button was retired, d7a915b) has
no like button, so the exposure is installs older than that only. The `match
/likes/{userId}` block is still there and is the only §80 item left — it goes one
release after the app stops sweeping that subcollection.

---

## 82. User report: Places category chips (Fuel/Garage/etc.) fail with "Something went wrong, try again" — "All" works — FIXED (2026-09-20)

> Full writeup in `issues_fixed.md` §82.

---

## 83. Full-app critique pass (UI/UX, codebase, architecture, flow) — open parts (surfaced 2026-09-20, mostly fixed 2026-09-21)

**Most of this section is resolved — see `issues_fixed.md` §83** for the 20+
sub-items fixed on 2026-09-21 (safety claims, EventDetector, feed pagination,
account deletion, privacy salt, error states, comment rot). Full original
writeup (folder deleted 2026-10-06, see §91): `git show 4b1a1b2^:ANTIGRAVITY_GRILL/Claude_CRTITISIZE.md`.

**Where the fixed work lives:** merged to `main` and pushed 2026-09-21
(`b32165e..49c6b0e`). Firestore **rules and indexes are deployed and
verified**; **functions are not** — still blocked on Blaze, which is why the
Cloudinary deletion sweep and the account-deletion anonymization in §83.15 do
not run yet. See `HANDOFF_Document.md` for the verification detail.

What is still open:

### 83.12 — the active-ride screen rebuilt in full, once per second — MOSTLY FIXED 2026-09-21

> Writeup in `issues_fixed.md` §83.12 (part). The outer build now selects three
> fields and the fast-moving panels select their own; `.select(` went 3 → 11.

**Still open:** the argument is structural and **has not been measured on a device**
(profile a real ride for battery/thermal and frame times). `record_screen.dart`
(lines ~91, 314, 423) still watches the whole `RideRecordingState` in three places —
the pre-ride screen, so far lower stakes than the cockpit, but the same pattern.

### 83.13 — DI is inconsistent with the "clean architecture" claim

`RideRecordingNotifier` news up its DAOs, calculators and all four
coordinators as `final` fields; `maintenance_provider.dart:16` is a file-level
`final _dao = MaintenanceDao()`; `FirebaseFirestore.instance` is referenced
directly in 20 places and `FirebaseAuth.instance` in 9. `CrashCoordinator`
accepts an injected Firestore — so the pattern was known — and the notifier
that owns it calls the no-arg constructor anyway. **This is the same root
cause as 83.28:** nothing that touches I/O is injectable, so nothing that
touches I/O is tested.

### 83.14 — 53 bare `catch (_)` blocks

11 with empty bodies. Many carry a justifying comment and several are
legitimate, but in a Crashlytics-instrumented app this is 53 failure modes
that will never reach the dashboard and will be reported as "it just didn't
work."

### 83.16 (part) — the Cloudinary preset is still an open upload endpoint

Deletion is fixed (§83.15). The upload path is not: cloud name + unsigned
preset are in the APK, so anyone can POST arbitrary image/video/audio to the
account with no auth, rate limit, size cap or moderation. Needs a signed
server-side upload proxy, which needs the Blaze plan. Group-ride push-to-talk
voice notes therefore still live at permanent public URLs.

### 83.18 — blocking is a client-side filter

`visibleFeedProvider` removes blocked riders *after* downloading them, so a
blocked user's content still reaches the victim's device on every refresh, and
nothing stops a blocked user reading the blocker's public content. Wants a
server-side edge, not a `.where()`.

### 83.19 (part) — App Check: client activation done, console enforcement still off

**Done in code:** `app/lib/main.dart` `_activateAppCheck()` calls
`FirebaseAppCheck.instance.activate` (Play Integrity / App Attest, debug provider in
debug builds) right after `Firebase.initializeApp`. See `issues_fixed.md` §83.19.

**Still open (founder, console action):** register the debug token and switch on
App Check enforcement in the Firebase console. Do this only after a release with
this code is what riders run, or older builds get locked out (same rule as §78.27).
Until then rules cannot bound request volume, and any signed-in client can still
drive function invocations.

**APPROVED 2026-09-21: enable it.** Free, and works on Spark.

### 83.22 (part) — accessibility is a stopgap

27 icon-only buttons got tooltips and text scaling is clamped to 1.0-1.3×, but:
**0** `semanticLabel`s outside those, 5 `Semantics(` widgets in 259 files, and
the clamp exists *because* the layouts overflow above ~1.3× rather than
reflowing. The fixed-height cockpit rows, chips and stat tiles need to be made
scale-tolerant so the clamp can be raised or dropped. For an app read outdoors
in sunlight through gloves this is legibility work, not a minority feature.

### 83.23 (part) — localization: what is left after the 2026-09-21 pass

The main pass is done on branch `i18n` (see `issues_fixed.md` §83.23 (rest)):
every screen, dialog, sheet, error mapper, notification, badge, rank, turn
instruction and greeting is localized — 88 of 265 files use `AppLocalizations`,
the rest are data/domain/plumbing with nothing to translate. What remains:

- **Bangla review (the real gate).** **1,064 keys** of machine-drafted Bangla are
  listed in `app/lib/l10n/bn_pending_review.txt`, grouped by batch. A reviewer is
  available; hand each batch over. Nothing here has been read by a native
  speaker. A test (`arb_parity_test.dart`) keeps the list from naming dead keys.
- **Bangla has been seen on a simulator, not a device.** The 2026-09-21 UI tour walked 82
  screens in Bangla on the iPhone 17 Pro simulator (one appearance combo, text scale 1.0):
  0 overflow lines, no stripes. Not covered: a real device, text scale above 1.0 (this app
  has known overflow above ~1.3×, §83.22), ~21 sections whose controls the tour finds by
  English text.
- **Messages from logic layers still reach the UI in English**, because those
  files have no `BuildContext` and need a code-vs-text refactor, not a string swap:
  `group_ride_repository.dart` (3: bad code / ended / full),
  `group_ride_selection.dart` (2: min/max friends), `profile_repository.dart`
  (2: username taken / invalid), `place_entity.dart`'s `reviewsSummarySubtitle`
  ("N Google · M ThrottleIQ", "No reviews yet"). The pattern to copy is
  `recordingErrorText()` in `record_screen.dart` (English stays in state, the UI
  localizes from a stable code/kind).
- **Dates show English month names in Bangla** ("17 Aug", "August 2026", "Riding with us since August 2026")
  — `formatRideDate` and friends don't pass a locale to `DateFormat`. Not a one-line fix: `intl`'s Bangla
  locale also emits Bengali digits, which `numeric_locale.dart` deliberately forbids, so this needs a
  decision (localized month names with Western digits) before anyone touches it. Found in a Bangla tour.
- **Onboarding mockup chrome is still English** (seen in a Bangla tour screenshot): the mock
  map's filter chips ("All / Fuel / Workshops / Cafes") and a few labels inside
  `onboarding_ui_mockups.dart` — chrome strings my extractor's heuristics missed, not the
  sample data. Small; localize them with the rest of that file's labels.
- **Deliberately English, do not "fix":** units (`km`, `km/h`, `mi`, `°C`, `g`),
  brand/model names and hint examples, the onboarding mockups' sample data,
  forum topic/brand lookup lists, and every string that is *data* other people
  read — report reasons, `Unknown Bike`, audience values, challenge titles, the
  SafeQR payload, SQL.
- **Foreground-service and notification text is a snapshot** taken at ride start /
  send time (`resolveL10n` / `savedL10n`), not reactive to a mid-ride language change.

### 83.25 — information architecture (decided: leave as-is for now)

The garage is not in the bottom nav — it is a section of the Profile tab, with
maintenance one level below that — while the POI directory gets a top-level
tab. `_nonTabShellRoutes` exists solely to stop `/home/maintenance`
highlighting the wrong tab. 30 of 42 routes are full-screen with no shell, and
"My places"/"My shared rides" hang off the garage header's user menu.
**Product decision 2026-09-20: leave the nav alone** — no relearning for
existing beta testers. Recorded here because the IA cost is real, not because
work is pending.

### 83.26 — `onboarding_ui_mockups.dart` is a 1,162-line hand-drawn copy of real screens

The fabricated readouts are fixed (§83.1), but the structural problem stands:
the third-largest file in the app is an illustration of screens it cannot stay
in sync with, shipping in the production binary. `integration_test/ui_tour_test.dart`
already exists and could supply real screenshots.

### 83.27 — no analytics of any kind — CODE DONE 2026-09-21 (branch `job4-infra`); release + Data Safety pending

Zero `logEvent`. Defensible as a privacy stance (and stated as one in the
README), but it means nothing would ever have surfaced the empty "Following"
feed or the buried maintenance flow. A privacy-respecting app can still count
screen views.

**APPROVED 2026-09-21: add privacy-respecting analytics** — screen views and
funnel events only, no ad SDK, no behavioural profiling.

**This is not a code-only change.** `public/privacy.html`,
`store_listing/data_safety_and_permissions.md` and the Play Console Data
Safety form all state no behavioural analytics today; §69.O1 is the last time
that exact mismatch bit. They move in the same pass, or the app ships
contradicting its own privacy policy.

### 83.28 — 43 screens, 1 screen test, 0 goldens

18 files `pumpWidget` at all. The 1,195 passing tests cover the pure
calculators exhaustively and the presentation layer essentially not at all —
which is where every UX defect in this section lived. Same root cause as
83.13.

### 83.31 — triage, not more critique

§32's safety finding was written 2026-08-17 and sat open for a month while
smaller items shipped. This file is append-only and unprioritised, so "the FAB
overlaps a list row" and "the crash detector is off while onboarding promises
it works" sit at equal weight. **Suggest ordering §32/§78/§81's remainder by
what happens to a rider if it's wrong, before commissioning further review
passes.**

**Doc-integrity note:** two sections in this file are both numbered **§79**
(the Places button, and the QA-seed likes/comments), and §82 was used while
§81 was free. Section numbers are meant to be unique and never change, so
renumbering isn't proposed — flagging it so the header pointer stays
trustworthy.

---

## 84. Four Firestore indexes exist in the project but not in `firestore.indexes.json` (2026-09-21)

**Status 2026-09-21: the four are now DECLARED in `firestore.indexes.json`** (12 → 16, matching the
project exactly, definitions read from `firebase firestore:indexes`), so the file is honest and a
`--force` deploy can no longer silently drop them. They are still **orphan candidates** — retiring
them is a separate, deliberate step (delete from the file *and* the console, after re-checking
`scripts/`, hand-run console queries and the undeployed `functions/`). Not deployed; a deploy would
be a no-op for these four. Original finding follows. Found during the §83 rules/indexes deploy,
which printed:

> `firestore: there are 4 indexes defined in your project that are not present
> in your firestore indexes file. To delete them, run this command with the
> --force flag.`

The four, from `firebase firestore:indexes --project throttleiqfb`:

| Collection | Fields |
|---|---|
| `liveSessions` | `userId`, `expiresAt` |
| `rides` | `allowedUserIds`, `createdAt` |
| `rides` | `isPrivate`, `createdAt` |
| `rides` | `public`, `startTime` |

**Why it matters.** `firestore.indexes.json` is supposed to be the source of
truth, and it currently isn't — so anyone reading the file gets an incomplete
picture of what the project actually has, and anyone running
`firebase deploy --force` deletes four indexes without being told which. A
dropped index breaks its query **immediately and in production**, surfacing as
`failed-precondition` — the same class of failure as §82 and §178, but in the
opposite direction.

**Evidence they're orphaned (not proof).** Grepping every `where(`/`orderBy(`
against `rides` and `liveSessions` in `app/lib` and `functions/src`:

- `isPrivate` — **no query anywhere.** The visibility model is `audience`
  (`public`/`followers`/`mutual`); `isPrivate` looks like the pre-`audience`
  field.
- `public` as a *field* — **no query anywhere.** `'public'` appears only as a
  *value* of `audience`. Likewise `startTime` is never queried on `rides`
  (only on `groupRides`), so `rides (public, startTime)` looks doubly stale.
- `rides (allowedUserIds, createdAt)` — superseded. The live query is
  `allowedUserIds arrayContains + audience whereIn + orderBy createdAt`, which
  needs the 3-field `(allowedUserIds, audience, createdAt)` that IS in the
  file. This 2-field form is the version from before the `audience` co-filter
  was added (see `getSharedToMe`'s doc comment for why that filter exists).
- `liveSessions (userId, expiresAt)` — no matching query in the app or the
  functions. Possibly console-created for the TTL work in §4.

**Before removing any of them,** check the places this grep can't see: the
`scripts/` node utilities, anything run by hand from the Firebase console, and
the undeployed `functions/` code. Then either delete them with `--force` or —
better, since it keeps the file honest either way — add them to
`firestore.indexes.json` with a comment saying what they served, and retire
them deliberately.

**Do not run `firebase deploy --force` to clear the warning.** That is the
failure mode this section exists to prevent.

---

## 85. `RouteEntity.timesRidden` was a dead counter — FIXED (2026-09-21)

> Full writeup in `issues_fixed.md` §85.

Correction to how this was first written up: `RouteRepository` **already had**
an `incrementTimesRidden` — it had simply never been called from anywhere, so
`timesRidden` sat at the 1 `saveRoute` writes and "ridden 1×" was the same on
every route forever. (The original note said no such method existed; that came
from a truncated grep.) It is now called from `ActiveRideScreen._stopRide`, on
completion rather than on start, and never from `_cancelRide`.

**Still open, deliberately:** the bump is best-effort and not outboxed, so one
made offline is lost. That is the right trade for a cosmetic counter — see the
method's doc comment for the line that has to move if it ever becomes
load-bearing (ranking Discover by it, say).

---

## 86. Social redesign (mock was `ANTIGRAVITY_GRILL/new_task`, deleted, see §91.6) was left half-wired with fake data — FIXED (2026-09-27), two follow-ups still open

An earlier same-day pass at the Rides/People/Forums mock was caught
uncommitted before it landed: the AppBar search had been silently
disconnected, the People tab was a bare `Center(child: Text('People'))`, and —
the part that would have actually shipped to riders — the "Riding Now" strip
and every feed card's location pill were the **mock's own literal sample
text** hardcoded into the widget tree ("Rafi's Squad", "Nadia Rahman",
"Chittagong Hill Tracts" on every card regardless of where the ride was).
Scratch `clean_up*.py`/`fix_social.py`/`rewrite_social_screen.py` scripts and
`tmp_*`/`.bak` files from the attempt were left in the repo root too.

**Fixed:** search restored (now a `SearchDelegate` off the AppBar icon rather
than the old always-on field); People tab rebuilt with real rider search + a
real Following list; "Riding Now" rebuilt against a genuine
`GroupRideRepository.watchActiveGroupRidesForUser()` query (hides itself when
the rider has no active group ride, rather than showing anything invented);
location pill removed outright rather than faked (see features.md §7 for why
reverse-geocoding it live isn't safe to do per-card). `firestore.rules`'
`groupRides` `list` rule extended for the new query shape; 119/119 emulator
tests green. Scratch files deleted. Full detail in features.md §7.

**Still open:**
- The `groupRides` `list` rule extension is **not deployed to production** —
  committed to `firestore.rules` but the deploy was blocked by the session's
  auto-mode classifier as a production-affecting action. Run
  `firebase deploy --only firestore:rules` by hand; until then "Riding Now"
  silently shows nothing against prod rather than erroring.
- Solo "riding now" cards for a followed rider who's live but not in a group
  ride (the mock's other card style) were deliberately not built — there is no
  backend signal today for "who I follow is live right now," and
  `liveSessions`/`livePointers` are intentionally non-enumerable for privacy
  (see `firestore.rules` comments on that collection). Needs its own design
  pass on what's safe to expose to followers, not a rushed addition.
- A real per-card location label needs a one-time reverse-geocode at ride-share
  time with the result cached on the ride doc (`SharedRideEntity` has no
  place-name field at all today) — not attempted here; see features.md §7.
- `flutter run --release` on a connected iPhone failed at codesigning during
  this session's verification pass: Xcode has no Apple ID under
  Settings → Accounts, and the one valid codesigning identity in the keychain
  (`Apple Development: abraar.rar@icloud.com`, team `29BPVM86G5`) doesn't match
  the project's configured `DEVELOPMENT_TEAM` (`NJ4675FFUX`) on the Runner and
  ThrottleIQWidget targets. Needs the account owner to sign into Xcode and
  confirm which team should actually sign this app — not something fixable
  headlessly.
  - **Root-caused and fixed (2026-09-28), separate issue found alongside it:**
    every build also failed earlier with "no XCFramework found" errors
    pointing at `/Users/blackbird/Everything/dev/ThrottleIQ/...` — the repo's
    path *before* it moved under `2_Ongoing/`. Cause: 10 stale
    `~/Library/Developer/Xcode/DerivedData/Runner-*` caches (PIFCache) still
    carried the old absolute path from before the move, and Xcode's package
    artifact resolution was reading from one of them instead of the current
    project. Fixed by deleting all `Runner-*` DerivedData directories and
    `app/build/ios/SourcePackages` and letting Xcode re-resolve clean — this
    part is a machine/cache issue, not a code issue, and needed no source
    change. **The Apple ID/provisioning-profile blocker above is unaffected
    and still the reason the run can't complete.**
  - **Apple ID signed into Xcode (2026-09-28) — build and codesigning now
    succeed.** `flutter run --release` builds clean and `xcrun devicectl
    device install app` installs `Runner.app` on "Abraar's iPhone"
    successfully. What's left is a **separate, one-time on-device step**:
    launch fails with `FBSOpenApplicationServiceErrorDomain error 1` /
    "invalid code signature, inadequate entitlements or its profile has not
    been explicitly trusted by the user" — standard iOS behavior the first
    time an app signed by a new developer profile is installed. Needs, once,
    directly on the phone: **Settings → General → VPN & Device Management →
    [the developer's name under "Developer App"] → Trust**. Nothing left to
    fix in the project or the toolchain; this is the last step before the
    app actually launches on the device.
  - **RESOLVED 2026-10-05 — the app now runs in release mode on the iPhone.**
    The developer certificate was trusted on the device, and
    `xcrun devicectl device process launch --device <udid> com.bft.throttleiq`
    returned "Launched application with com.bft.throttleiq bundle identifier."
    Two things to carry forward: (1) `flutter run --release` still fails at its
    own install step ("Could not run build/ios/iphoneos/Runner.app") even though
    the Xcode build succeeds — the working path is to let the build finish, then
    `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app`
    and launch with devicectl; (2) the profile is a **free personal team**
    (`Apple Development: abraar.rar@icloud.com`, team NJ4675FFUX) and
    **expires 2026-10-12** — after that the app stops launching on the device
    and needs a re-sign.

---

## 88. Follow-ups left by the open55 pass (2026-10-01)

- **88.1:** ~~a post shared to `followers` or `mutual` saves its allowed viewers when it's shared...~~ Fixed (code). Live follower visibility check implemented in Firestore rules.
- **88.2:** ~~running-cost settings phone-only~~ Fixed (code, not yet device-checked): each bike's maintenance settings (tracked checks incl. typical cost, fuel price, mileage) back up via the outbox to the owner-only `users/{uid}/private/maintenanceSettings_{bikeId}` and restore on reinstall/new device (fills empty tables only, never overwrites). Existing rules already cover the path, so no rules deploy. See `core/cloud/maintenance_settings_sync.dart`.
- **88.3:** the open55 changes haven't been checked on a device: the checklist in §87, the maintenance layout and ride-cost card, the collage visuals, and the SQLite v17→18 upgrade on a real install.
- **88.4:** the Bangla strings added in open55 haven't been reviewed (listed in `bn_pending_review.txt`).

---

## 89. No JDK on the machine — Android release builds (APK/AAB) could not run — FIXED (2026-10-05)

- **Symptom:** `flutter build apk --release` and `flutter build appbundle --release`
  both fail immediately at `Running Gradle task 'assembleRelease'` with
  `The operation couldn't be completed. Unable to locate a Java Runtime.`
  (exit 1, ~30ms — Gradle never starts). `flutter doctor` reports
  `[!] Android toolchain ... ✗ Could not determine java version`.
- **Cause:** there is no JDK installed anywhere on this Mac. `JAVA_HOME` is
  unset, `/usr/libexec/java_home` finds nothing, Android Studio is not
  installed (so there's no bundled JBR to fall back on), and there is no
  Homebrew/SDKMAN JDK. The Android *SDK* (37.0.0) is present — only the Java
  runtime is missing. Note the release build was verified on the
  Pixel_10_Pro emulator on 2026-08-28, so a JDK existed then and has since
  gone away.
- **Fix (APPLIED 2026-10-05):** installed JDK 21 via the Homebrew *formula*
  `brew install openjdk@21` (→ `/opt/homebrew/Cellar/openjdk@21/21.0.12.1`).
  Used the formula rather than the `temurin` cask because the cask installs
  into `/Library/Java/JavaVirtualMachines` and needs an interactive `sudo`
  password; the formula installs under `/opt/homebrew` with no sudo. It also
  upgraded 7 existing brew deps (libpng, pcre2, glib, xorgproto, cairo,
  harfbuzz, xz). `openjdk@21` is **keg-only**, so it is NOT auto-linked and
  needs an explicit PATH entry — added to `~/.zshrc`:
  `export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"`
  and `export PATH="$JAVA_HOME/bin:$PATH"`. Flutter was also pointed at it
  independently of the shell with
  `flutter config --jdk-dir "$JAVA_HOME"` so GUI editors work too.
  `flutter doctor` now reports `[✓] Android toolchain` (was
  `✗ Could not determine java version`).
  **Use JDK 21, not the current `temurin`/`openjdk` (27).** This project is Gradle
  8.13 + AGP 8.11.1 compiling to Java 17 target
  (`sourceCompatibility`/`jvmTarget` = 17); JDK 21 is the supported LTS for
  that combination, and 27 is likely to break the Gradle/AGP toolchain.
- **Unblocks:** nothing in the app code is wrong — signing is already set up
  correctly (`android/key.properties` present and wired into
  `signingConfigs`, keystore file resolves, `google-services.json` in place),
  so both builds should go through as soon as a JDK exists.
- **Verified 2026-10-05:** both release builds now succeed.
  `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
  (85.2 MB) and `flutter build appbundle --release` →
  `build/app/outputs/bundle/release/app-release.aab` (83.3 MB), both exit 0.
  `apksigner verify` confirms the APK is signed with the **release** key
  (`CN=ThrottleIQ, OU=BlankFrame Technologies`), APK Signature Scheme v2,
  1 signer — not a debug key.
- **Two non-blocking warnings seen during the build, both left alone:**
  (a) `Flutter support for your project's Gradle version (8.13.0) will soon be
  dropped. Please upgrade ... to at least 8.14.0` — worth doing before it
  becomes an error; (b) `SDK processing. This version only understands SDK XML
  versions up to 3 but an SDK XML file of version 4 was encountered` — harmless
  cmdline-tools/SDK version skew.

---

## 90. Full-codebase audit — 5 parallel reviews (2026-10-06) — MOSTLY FIXED (see status)

**Status after the 2026-10-06 fix pass:** fixed in code (commit `6264d72`, not checked
on a device) — see `issues_fixed.md` §90 for every ID. **Still open:**
- **Owner actions:**
  - Turn on branch protection (B1).
  - Run `pod install` and do on-device iOS mic/camera checks (B2/B3).
  - Ship the app, then deploy rules and indexes together.
  - Backfill `users.visibility`.
  - Check Cloudinary folder mode before the functions deploy (D2).
  - Approve deleting the dead files (B8): `ride_repository.dart`,
    `ride_repository_impl.dart`, `ride_repository_provider.dart`,
    `test/repositories/ride_repository_test.dart`, `motorcycle_quotes.dart`,
    `datetime_extensions.dart`, `auth/domain/entities/user_entity.dart` and
    `test/widget_test.dart`. Removing them was blocked by the session's
    permission check.
- **Device checks:**
  - Pause now stops the Android foreground notification; check that resume
    restarts GPS and the notification (C1).
  - Does `FlutterForegroundTask.isRunningService` work from the UI isolate (C2)?
  - Does the background isolate see the ride marker after `prefs.reload()` (C3)?
  - The C4 pointer transaction.
  - The 20 s group-ride cadence.
- **Not done (large refactors, or need a device):**
  - B4/B5: providers for Firestore/Auth/DB/uid and the layering.
  - B6: migrating about 42 debugPrint-only catches to `reportNonFatal`.
  - B7: the other god files.
  - B9: `RideRecordingNotifier` is still not constructible in tests.
  - B10: dependency majors.
  - B12: Play Console declarations.
  - B13: `StatefulShellRoute`. Skipped because it changes every tab's lifecycle;
    do it with the go_router upgrade and a device pass.
  - B14: repo clutter, PDFs/LFS and the keystore location.
- **Accepted / partial:**
  - D9: the `follows` list stays unconstrained. Every client query filters on
    one side, and the list exposes uids only, not emails.
  - D6: profile emails spoofed before this fix aren't cleaned up.
  - D8: no follow requests. The "Followers" label is kept in the edit-profile
    garage control because the longer text doesn't fit there.
  - A8: one vote read per visible forum post remains.
- Paused rides block auto-detection until the rider resumes or ends them. This
  is deliberate.
- **90.A13 (new, LOW):** the delete in My Shared Rides fails silently.
  `my_shared_rides_screen.dart:43` awaits `deleteSharedRide` with no try/catch, so
  a failure shows nothing. Until the D1 rules are deployed, a shared ride with
  comments can't be deleted, and the rider gets no message. *Fix:* try/catch
  around the delete, with a SnackBar on failure.

Read-only audit across security/rules, ride pipeline + sync, social data layer,
architecture/tests/tooling and docs accuracy. Each item was deduped against
§§33–89 and checked by reading the code; nothing here has been fixed yet.
Sections: A social data layer · B architecture/CI/platform · C ride pipeline
and sync · D security/rules · E docs sweep.

**Triage order (do these first):**
1. **§90.B1** fix the 3 lints so `main` CI goes green, then require the checks. About 10 min.
2. **§90.B2 + §90.B3** iOS mic define and camera/photo usage strings. Config only;
   the camera one is a crash.
3. **§90.D1** make comment delete possible, plus the create gate. Owners can't unshare today.
4. **§90.C1, C2, C3** ride data integrity: van distance on resume, truncated
   auto rides, duplicate rides and doubled odometer.
5. **Spark quota: §90.C7, A1, A2, A7.** Full re-download every 5 min, feed
   fan-out, 5 s group-ride writes, search per keystroke. Each one alone can
   exhaust the free tier with a handful of active users.
6. **§90.D2** sweep prefix check. Must land before any functions deploy.
7. **§90.D3, D6, D8 + A4/D9** group-ride member injection, email
   impersonation, the meaning of "Followers", the `users` list query. D8 is a
   product decision.

**Architecture verdict (2026-10-06):** the backbone fits the app. That backbone
is offline-first SQLite as the source of truth, an outbox with dead-letter,
pure tested calculators, and emulator-tested rules for a solo-built ride
tracker on Firebase's free tier, and it is the best-tested part of the
codebase. What's wrong is around it:
- **Under-engineered:** no I/O seams (hidden singleton repos, direct
  Firestore/DB calls), so the 1,168-line ride `StateNotifier` has zero tests.
  Read costs are an afterthought in a Spark-plan app. CI exists but gates nothing.
- **Over-engineered:** the entity/model/repository-interface ceremony. There are
  24 entities and 17 models, and the only repository interface is dead code.
  The docs process is also heavier than the code.

Top structural moves are in `DEBT_FIX_PLAN.md` §2: providers for
Firestore/Auth/DB/current uid, a pure ride state machine behind a thin
platform adapter, and grep ratchets in CI. Also treat Firestore reads as a
budget: incremental sync, bounded queries, one shared follow-set stream.

### 90.A Social / chat / forums / POI data layer (incl. commit a51b3f8 "Suggested for you")

Spark quota context: one cold Social open (rider following ~15 active riders)
is estimated at **~480–510 reads**, each `loadMore` ~400 more — i.e. roughly
80–100 Social opens/day exhausts the project-wide 50k-read quota. A.1, A.2, A.7
are the quota killers.

- **90.A1 — CRITICAL — feed fans out `limit(20)` per followed author, keeps 20.**
  `social/data/repositories/ride_share_repository.dart:217-234` (the §88.1 fix).
  30 follows → up to 600 reads per page, repeated on every `loadMore`,
  refresh and follow/unfollow (`ride_feed_provider.dart:96`). *Fix:* public posts
  back to chunked `whereIn` (30 authors/query); per-author queries only for
  `followers`/`mutual` with limit 3–5, or skip authors without restricted posts
  via a denormalized `hasRestrictedPosts` flag. **(verified 2026-10-06)**
- **90.A2 — CRITICAL — group-ride map writes every member's position every 5 s.**
  `group_ride_map_screen.dart:38` (`kGroupRideBroadcastInterval`), `:177-180`,
  `:269-283`; listener `group_ride_repository.dart:579-588`. 5 riders × 2 h ≈ 7,200
  writes (36 % of 20k/day) and ≈ 36,000 reads (72 % of 50k/day). Writes even when
  stationary. *Fix:* 15–30 s interval + skip if moved < ~25 m; consider one map
  field on the ride doc. **(verified 2026-10-06)**
- **90.A3 — HIGH — People-tab "Following" list never updates after follow/unfollow.**
  `social_screen.dart:69-77` awaits one-shot non-autoDispose `followingIdsProvider`
  (`follow_providers.dart:13-17`); nothing invalidates it (same class as §87.2).
  The suggestion card's `ref.invalidate(_followingProfilesProvider)`
  (`social_screen.dart:978-979`) is a no-op. `mutualIdsProvider` same. *Fix:* watch
  the live `followingUidsProvider` stream; delete or stream-ify the one-shots.
- **90.A4 — HIGH (needs rules-emulator confirmation) — `getRecentUsers` either fails
  silently or enumerates private profiles + emails.** `profile_repository.dart:270-279`
  (`users.orderBy('createdAt').limit(50/100)`, no `visibility` filter), used by
  suggestions and `all_people_screen.dart:18`; rule `firestore.rules:293-294`.
  Either permission-denied (suggestions vanish via `valueOrNull`) or every user
  doc incl. `email`/`emailLower` is listable. No rules test covers `users` list
  queries. *Fix:* emulator test; `where('visibility', isEqualTo: 'public')` +
  backfill; move email off the public profile doc.
- **90.A5 — HIGH — suggestions are unbounded and re-run on every tab switch.**
  `follow_providers.dart:42-71`: reads *all* follower + following edges, fetches
  every non-followed-back follower profile serially (UI shows 10), then the
  50-user query; `autoDispose` + `TabBarView` disposal re-runs it each visit.
  Constructs `ProfileRepository()` directly; doesn't exclude blocked users.
  *Fix:* cap to 10 candidates, bounded queries, `keepAlive` + TTL, block filter.
- **90.A6 — HIGH — per-row follow listeners never close.** `isFollowingProvider`
  (`follow_providers.dart:27-31`) is a non-autoDispose `StreamProvider.family`;
  All People alone leaves 100 permanent listeners. **(verified 2026-10-06)**
  *Fix:* derive from `followingUidsProvider.contains(uid)` — zero extra reads.
- **90.A7 — HIGH — AppBar search costs ~220 reads per keystroke, no debounce.**
  `social_screen.dart:186-188` runs in `buildSuggestions`; `searchForums` scans
  200 forums (`forum_repository.dart:211-222`) + 20 riders. "royal enfield" ≈
  2,800 reads. *Fix:* debounce in the delegate / search on submit; lower-cased
  prefix field + range query; cache forum list.
- **90.A8 — HIGH — unbounded lists.** `chat_repository.dart:26-35` (`watchMessages`),
  `forum_repository.dart:401-432` (`getPosts` + all child-model forums + 1 vote
  read/post), `ride_share_repository.dart:421-427` (`getComments`),
  `group_ride_repository.dart:619-628` (`watchVoiceNotes`). `forumPostsProvider`
  is non-autoDispose → stale all session. *Fix:* `limit(50)` + cursors
  (`limitToLast` for chat), autoDispose + pull-to-refresh.
- **90.A9 — MEDIUM — follow buttons fire-and-forget; notification spam.**
  `social_screen.dart:969-979`, `:1595-1608`; `user_profile_screen.dart:208-220`.
  Unawaited `follow()`, `notifyFollow` runs even if follow failed, each toggle
  writes a new notification, double taps duplicate. *Fix:* await → notify;
  deterministic id `follow_{fromUid}` with `set`; disable while in flight; show errors.
- **90.A10 — MEDIUM — follower/following counts never refresh.**
  `follow_providers.dart:33-39` non-autoDispose `FutureProvider.family`, never
  invalidated. *Fix:* autoDispose + invalidate both uids after follow/unfollow.
- **90.A11 — MEDIUM — blocking leaves follow edges, so a blocked follower still
  reads `followers`/`mutual` posts server-side** (because §88.1 made
  `rideVisibleTo` check the live graph). Blocker can't delete the other's edge;
  block handler (`user_profile_screen.dart:86-94`) has no try/catch. Distinct from
  §83.18. *Fix:* rule letting the followee delete `follows/{them}_{me}`, or
  `!exists(users/{author}/blocks/{viewer})` in `rideVisibleTo`; try/catch.
- **90.A12 — MEDIUM — account-switch and chat-list state bugs.**
  (a) `rideFeedNotifierProvider` (`ride_feed_provider.dart:91-104`, `:143-156`)
  doesn't watch `currentUserProvider`; A→B sign-in with both following nobody
  shows B A's held feed (incl. A's non-public rides). *Fix:* watch uid.
  (b) `chat_list_screen.dart:105-110` hides the whole conversation when the other
  profile read is permission-denied (private/mutual visibility). *Fix:* placeholder name.
  (c) `markMessagesAsRead` (`chat_repository.dart:138-157`) writes N updates per
  room open for an `isRead` nothing displays. *Fix:* drop or single `lastReadAt`.
- **90.A — LOW:** `placeDetailProvider`/`reviewsForPlaceProvider`
  (`places_provider.dart:79-90`) non-autoDispose listeners; `ForumRepository.createPost`
  bumps `postCount` in a separate non-transactional write (`forum_repository.dart:363-375`);
  `_RideCardState._submitComment` uses Auth `displayName` not profile `bestName`;
  `AllPeopleScreen` uses the wrong empty-state string, no pagination past 100,
  doesn't mark already-followed riders.

### 90.B Architecture, code quality, tests, build/CI, platform config

Measured 2026-10-06: `flutter analyze` **3 issues (fails)**, `flutter test`
**1357/1357 pass**, `flutter pub outdated` 146 blocked upgrades.

- **90.B1 — CRITICAL — CI on `main` has been red since 2026-09-30 and nothing gates it.**
  Run 36783259590 (commit `a51b3f8`) fails `flutter analyze`:
  `social_screen.dart:862` `prefer_const_constructors`, `:996`
  `unused_element_parameter`, `:1542` `use_key_in_widget_constructors`. Because
  analyze fails first, tests and the `as double` guard never ran on HEAD in CI.
  Direct push to `main` succeeded → branch protection is off. **(verified via
  `gh run list` 2026-10-06)** *Fix:* fix the 3 lints; require `flutter`, `rules`,
  `functions` checks on `main`.
- **90.B2 — HIGH — iOS voice notes can never get microphone permission.**
  `permission_handler_apple` compiles `PERMISSION_MICROPHONE 0` unless enabled via
  `GCC_PREPROCESSOR_DEFINITIONS`; `ios/Podfile:44-47` only sets `PROTOBUF_NANO=1`
  (and with `||=`, so it may not even apply if Flutter pre-populated the key).
  `Permission.microphone.request()` (`group_ride_map_screen.dart:452-460`) never
  returns granted on iOS. **(verified)** *Fix:* add `'PERMISSION_MICROPHONE=1'`
  (use `+=`/explicit array, not `||=`), `pod install`, device-check.
- **90.B3 — HIGH — iOS crashes when the camera is chosen.** `ios/Runner/Info.plist`
  has no `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`; camera is
  offered at `add_place_screen.dart:100` and `odometer_sync_sheet.dart:255`.
  iOS terminates the app on access without the key. **(verified)** Related LOW:
  `UIBackgroundModes` lacks `audio`, so push-to-talk can't record/play with the
  phone locked in a handlebar mount — product decision. *Fix:* add both strings
  (+ Bangla `InfoPlist.strings` if localized).
- **90.B4 — MEDIUM — update to §83.13: repositories are hidden singletons.**
  11 repos use `static final _instance` + `factory X() => _instance`
  (e.g. `follow_repository.dart:11-12`) — looks like construction, can't be faked.
  `XRepository()` called 62× outside `data/`; only 2 repository providers exist.
  DAOs constructed directly 20× in presentation (`ride_recording_provider.dart:213-214,
  955, 1149-1167`; `auto_tracking_provider.dart:208-257`); `DatabaseHelper.instance`
  90×, `FirebaseFirestore.instance` 23×, `FirebaseAuth.instance` 10×. Add the
  factory-singletons to `DEBT_FIX_PLAN.md` §2 step 3.
- **90.B5 — MEDIUM — layering is partly nominal.** 40/117 presentation files import
  `data/` (21 are screens/widgets); 7 import `cloud_firestore`/`firebase_auth`
  directly (incl. `record_screen.dart`, `group_ride_map_screen.dart`). Domain
  leaks: `live_session_entity.dart:1`, `privacy_zone_salt.dart:3` (cloud_firestore),
  `bike_entity.dart:2` (material), `privacy_zone_clipper.dart:1` (foundation).
  Inverted deps: 7 `core/` files import features (`sync_manager`, `outbox_service`,
  `badges`, `rider_stats`, `home_widget_service`, `bike_colors`, `app_router`);
  `ride`↔`social` presentation import each other; ~50 imports of
  `auth/presentation` just for the current user → move `currentUid` to `core`.
- **90.B6 — MEDIUM — update to §83.14: 62 bare `catch (_)` (was 53), 11 empty.**
  180 catches, only 5 typed; **zero non-fatal Crashlytics reports** (4 call sites,
  all fatal handlers in `main.dart:84-131`); ~42 catches only `debugPrint`, which
  is invisible in release. `analysis_options.yaml` adds nothing over
  `flutter_lints` 3.0.2 (6.0 current). *Fix:* `DEBT_FIX_PLAN.md` §1 + enable
  `unawaited_futures`, `discarded_futures`, `avoid_catches_without_on_clauses`
  with a count ratchet.
- **90.B7 — MEDIUM — god files keep growing.** 9 files > 800 lines = 10,194 lines
  (17 % of non-l10n code): `social_screen` 1,621 (21 classes, providers declared
  in-screen at :47/:61/:74), `group_ride_map_screen` 1,199, `onboarding_ui_mockups`
  1,175, `ride_summary_screen` 1,170, `ride_recording_provider` 1,168,
  `settings_screen` 1,065, `active_ride_screen` 1,045, `shared_ride_detail_screen`
  937, `group_ride_repository` 814. `cloud_repository.dart` 538 → 715 since §62.13.
- **90.B8 — MEDIUM — dead code (update to §62.13).** The app's only repository
  abstraction is unused (`domain/repositories/ride_repository.dart`,
  `ride_repository_impl.dart`, `ride_repository_provider.dart` — provider never
  imported). Unimported from `lib/`: `core/database/daos/user_profile_dao.dart`
  (test-only), `core/constants/motorcycle_quotes.dart`,
  `core/utils/extensions/datetime_extensions.dart`,
  `features/auth/domain/entities/user_entity.dart`,
  `social/presentation/feed_sort_l10n.dart` (test-only).
  `cloud_repository.dart:626-715` (`exportToJSON`/`exportToGPX`/`_generateGPX`)
  has no callers — live export is `ExportService`. Delete.
- **90.B9 — MEDIUM — test shape (update to §83.28).** 149 files / 1,357 tests;
  25 files `pumpWidget`; 1 screen test for 42 screens; 0 goldens.
  **`RideRecordingNotifier` has no direct tests** (`gpx_replay.dart:10` says it
  can't be constructed). `test/widget_test.dart` is `expect(true, isTrue)` —
  delete. `integration_test/ui_tour_test.dart` (827 lines) not in CI.
  `functions/` has zero tests though `account-deletion.ts` carries privacy duties.
- **90.B10 — MEDIUM — dependency staleness.** Riskiest: `google_sign_in` 6.3 → 7.2
  (Credential Manager rewrite; legacy path on Google's deprecation track);
  FlutterFire set must move together (`core` 3→4, `auth` 5→6, `firestore` 5→6,
  `crashlytics` 4→5, `analytics` 11→12, `app_check` 0.3→0.4); `flutter_riverpod`
  2.6→3.4 (14 `StateNotifier`s). Also `go_router` 13→18,
  `flutter_local_notifications` 17→22, `geolocator` 11→14, `permission_handler`
  11→13, `sensors_plus` 4→7, `flutter_map` 7→8, `share_plus` 10→13,
  `home_widget` 0.6→0.10. 57 resolvable within constraints today.
  *Order:* FlutterFire + google_sign_in (one PR) → permissions/geolocator/
  notifications → go_router/riverpod post-launch.
- **90.B11 — LOW — CI toolchain.** `checkout@v4`/`setup-node@v4`/`setup-java@v4`
  on deprecated Node 20 (setup-java@v4 itself deprecated); `ubuntu-latest` → Ubuntu
  26 on **2026-10-19**. *Fix:* actions → v5, pin `ubuntu-24.04` until verified.
  (Gradle 8.13 → 8.14 already tracked in `DEBT_FIX_PLAN.md` §8.)
- **90.B12 — LOW — Play policy declarations.** `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
  requested at `auto_tracking_service.dart:363` and `ride_recording_provider.dart:301`
  needs a Play acceptable-use justification; `ACCESS_BACKGROUND_LOCATION` needs the
  declaration + video. (`USE_FULL_SCREEN_INTENT` = §69.O8.) All declared Android
  permissions are used; none missing.
- **90.B13 — LOW — router.** 43 `GoRoute`s, 90 string-literal navigations, no route
  constants. Bottom nav uses plain `ShellRoute` (`app_router.dart:222`), so every
  tab switch rebuilds the screen and loses scroll/local state →
  `StatefulShellRoute.indexedStack`.
- **90.B14 — LOW — repo hygiene.** Tracked root clutter: ~~`sum_claude.md`,
  `sum_gemini.md`~~ (deleted 2026-10-06, see §92), `new_gravity.md`, `open55_handoff.md`, `setup-android.*`,
  ~~`ANTIGRAVITY_GRILL/`~~ (deleted 2026-10-06). Duplicate misspelled
  `DOCS/Handoff for agents and Todos/ANTIGRAVRITY_GRILL/`. Three issue logs
  (`issues_open`/`issues_fixed`/`issues_solved`; the last has dead
  `file:///…/dev/ThrottleIQ/…` links). 28 tracked ~6 MB PDFs in
  `DOCS/General/screenshots_ui/pdfs/` (~170 MB) → `.git` is 527 MB; consider LFS
  or removing. `throttleiq-release.keystore` sits at repo root (gitignored, safe
  from commit, easy to lose) → move under `secret/`. Generated
  `lib/l10n/app_localizations*.dart` tracked → diff noise on every regen.

### 90.C Ride pipeline, offline sync, persistence

Checked sound: migrations v1→v18 converge (fresh vs upgrade), all 14 SQLite
transactions use only `txn`, outbox serialization/dead-letter/backoff, point
buffer flush/re-queue, live polyline capped at 2000, estimator/detector windows
bounded, idempotent track uploads, `SyncManager` reentrancy guard.

- **90.C1 — HIGH — pause buffers every GPS/IMU event; resume replays them as live riding.**
  `ride_recording_provider.dart:820-823` calls `.pause()` on broadcast-stream
  subscriptions (geolocator_android 4.6.2 / apple 2.3.14 / sensors_plus are
  broadcast). A paused broadcast subscription buffers everything and native GPS
  + sensors keep running. On resume (`:874-884`) the backlog is fed to
  `_onPosition`/`_onSensor` after `status = active`; `_skipNextDistanceDelta`
  only drops the first. Pause → van the bike 20 km → resume = the 20 km is
  counted (defeats the §65/§78 van fix). ~144k IMU events buffered per paused
  hour, replayed in one main-isolate burst. **(verified 2026-10-06)**
  *Fix:* cancel + null the subscriptions on pause and recreate on resume (the
  cold path already does this).
- **90.C2 — HIGH — foregrounding the app truncates a live auto-detected ride.**
  `app.dart:109-111` → `_reconcileDetectedRides` on every `resumed` →
  `auto_ride_reconciler_service.dart:60` unconditionally
  `closeStaleRecordingDetections()` (`auto_detection_dao.dart:134-150` flips all
  `recording` → `pending`). Background `recordFix` then finds no current
  recording and drops every later fix; `_moving` stays true so no new detection
  for 5 min. Short remainder may be rejected outright. **(verified)**
  *Fix:* only close `recording` rows when the foreground service isn't running or
  the last fix is older than the stillness timeout.
- **90.C3 — HIGH — manual ride + concurrent auto-detection → duplicate ride, double odometer.**
  Nothing stops `AutoTrackingService` during a manual recording, and
  `auto_ride_reconciler.dart` `_reject` has no overlap check against existing
  `rides`. Result: second `is_auto` ride, `BikeDao.incrementStats` twice (wrong
  maintenance due-dates), double upload. *Fix:* reject/trim detections
  overlapping any ride's `start_time..end_time`; optionally skip
  `beginDetection` while `active_ride_id` marker is set.
- **90.C4 — MEDIUM — live-share teardown outbox key is per-user, not per-session.**
  `outbox_service.dart:287` id `live-teardown:$uid` + `ConflictAlgorithm.replace`;
  delivery (`:546-566`) nulls `livePointers/{uid}` unconditionally; teardown
  queued with `attemptNow:false`. (a) offline ride 1 then ride 2 → T1's
  revocation overwritten, `liveSessions/T1` stays publicly readable until its 24 h
  expiry; (b) ride 2 shared within the drain window → stale teardown clears the
  new pointer, `/r/{username}` dead for the rest of ride 2. **(key verified)**
  *Fix:* key `live-teardown:$uid:$token`; clear pointer only if its token matches.
- **90.C5 — MEDIUM — double-tap Resume on the cold path leaks subscriptions.**
  `ride_recording_provider.dart:845-872`: `coldStart` and the `paused` guard
  are evaluated before awaits; Resume button (`active_ride_screen.dart:597`) not
  disabled. Two taps → two location/sensor subscription sets, duplicate
  `ride_points`, and after Stop the leaked geolocator listener keeps GPS + the
  foreground notification alive until process death. *Fix:* set an in-flight
  flag synchronously; cancel existing subs in `_start*Stream`; disable button.
- **90.C6 — MEDIUM — restored ride rebuilds distance across pause gaps and idle jitter.**
  `ride_resume.dart:107-115` sums haversine over all persisted points — no
  pause-gap skip, no below-threshold zeroing. Kill after a pause+van reintroduces
  the van distance on the restore path. *Fix:* persist resume markers; mirror
  `_onPosition`'s rules in the rebuild.
- **90.C7 — MEDIUM — every sync cycle re-downloads all rides/bikes/maintenance.**
  Unfiltered `.get()` at `cloud_repository.dart:338`, `:405`, `:478`; triggered
  every 5 min (`sync_manager.dart:113-127`) and on every connectivity change
  with no debounce (`:85-93`). 500 rides ≈ 500 reads/cycle ≈ 144k/day while the
  process lives (the ride foreground service keeps it alive). **Biggest single
  Spark-quota risk alongside §90.A1/A2.** *Fix:* full pull once per sign-in,
  then `where('syncedAt', isGreaterThan: lastPull)`; 30 s debounce; skip
  downloads while recording.
- **90.C8 — LOW — `stopRide` clears the recovery marker before finalizing.**
  `ride_recording_provider.dart:949` `clearRecordingState` precedes `:952`
  `finalizeRide`; no try/finally. Kill/throw between → row stuck `active`,
  invisible to history and sync forever. **(verified)** *Fix:* finalize first,
  clear marker last, try/finally.
- **90.C9 — LOW — `startRide` failure leaves status stuck at `starting`**
  (`:346-381`, no try/catch) → Start blocked until restart.
- **90.C10 — LOW (dormant, crash detection off) — dismissed+discarded crash ride
  resurrects from cloud.** Crash path uploads (`:1095-1105`), `cancelRide`
  (`:914`) deletes locally only, `downloadRides` (`cloud_repository.dart:483`)
  re-inserts; rides have no tombstone. *Fix:* `deleted_rides` tombstone like
  `deleted_bikes`.
- **90.C11 — LOW — battery-optimization dialog on every start/cold resume**
  while background location is `whileInUse` (`:292-306`). Ask once, remember decline.
- **90.C12 — LOW — Doppler-speed fixes never sanity-check their distance.**
  `:593-602` adds `distDelta` unchanged when raw speed is plausible; a ≤25 m
  accuracy multipath jump is accepted in full. Distinct from §62.15. *Fix:* cap at
  `max(rawSpeed, prevSpeed) * dt * 1.5 + accuracy`.

### 90.D Security & backend (rules, functions, client ↔ rules)

Limits: rules read line by line; **emulator not run** (the session's permission
classifier denied starting it). The security reviewer couldn't read `functions/`;
the main agent checked `account-deletion.ts` directly for D7. Sound: no secrets
in git history (keystore/`secret/`/`secrets/` gitignored, never committed),
live-session tokens (32 chars, `Random.secure()`, get-only, fail-closed expiry),
`isAdmin()`, vote/comment counter binding, invite-accept clause (§24.6), chat
participant immutability, owner-only private subcollections, no `list` on
token/handle/pointer collections, live-viewer has no data-driven `innerHTML`,
analytics/Crashlytics carry no PII.

- **90.D1 — HIGH — any comment makes a shared ride undeletable; anyone can plant one.**
  `firestore.rules:695-698` — `rides/{id}/comments` has `read` + `create` only,
  so the delete hits deny-all. `deleteSharedRide`
  (`ride_share_repository.dart:447-465`) deletes comments first via `Future.wait`
  → throws → ride doc never deleted. Comment `create` checks only `userId`: no
  `rideVisibleTo`, no key allow-list, no size cap — a stranger can plant a comment
  on a followers/mutual ride they can't see and pin it on the feed forever.
  **(verified 2026-10-06)** *Fix:* `allow delete` for comment author or ride owner;
  gate create on `rideVisibleTo(get(parent))` + `hasOnly` + text length; rules test.
- **90.D2 — HIGH (latent until functions deploy) — account-deletion sweep destroys
  any `publicId` in the deleter's ledger.** `users/{uid}/cloudinaryAssets` create
  (`firestore.rules:383-386`) has no shape check; `destroyCloudinaryAssets`
  (`functions/src/account-deletion.ts:244-255`) destroys every ledger
  `publicId` with no ownership/prefix check. Public IDs are visible in every
  media URL → write rows naming a victim's avatar/voice notes, delete own account,
  victim's media is destroyed. **(verified 2026-10-06)** *Fix:* rule
  `publicId.matches('^[a-zA-Z_]+/' + uid + '/.*')` (folder convention in
  `cloudinary_upload_service.dart:44-45`) **and** the same prefix check in the
  sweep before `destroy`. Must land before the Blaze/functions deploy.
- **90.D3 — MEDIUM-HIGH — group-ride creator can add any rider to `memberIds`.**
  `firestore.rules:1127-1129` (clause 1) bounds only `creatorId`/`status`.
  Victim's app then shows "on a live group ride" (`group_ride_providers.dart:78-85`);
  opening it starts `_broadcastPosition` (`group_ride_map_screen.dart:176-179`)
  with no consent step → creator reads their live location. **(verified)**
  *Fix:* clause 1 requires `request.resource.data.memberIds.hasOnly(resource.data.memberIds)`
  (remove-only); adds go through the self-join clauses.
- **90.D4 — MEDIUM — kicked riders can rejoin an active ride without the code.**
  Clause 4 (`firestore.rules:1188-1198`) needs only active + not-member + cap;
  `removeMember` just `arrayRemove`s. Also: the comment equating join-code
  entropy with live tokens is wrong (6 chars/31 symbols ≈ 2^30 vs 32/62), and
  codes never expire. *Fix:* `bannedIds` written on kick + checked in clause 4.
- **90.D5 — MEDIUM — riders can't delete their own forum posts.**
  `forum_repository.dart:263-268` batches the delete with `postCount: increment(-1)`;
  `firestore.rules:759-764` allows −1 only for admin/creator/maintainer → whole
  batch fails. *Fix:* tie −1 to `docRemoved(.../posts/$(lastDeletedPostId))`.
- **90.D6 — MEDIUM — profile `email`/`emailLower` is client-chosen → impersonation.**
  `firestore.rules:315-321` validates only `usernameLower`/`publicStats`.
  `searchByEmail` (`profile_repository.dart:281-290`) feeds the chat picker, the
  group-ride friend picker and search → Mallory sets the victim's email + name +
  photo, receives their friends' group-ride invites and locations. §24.5 closed
  this for usernames only. *Fix:* pin to `request.auth.token.email.lower()`.
- **90.D7 — MEDIUM — the public `/r/{handle}` live link is created silently.**
  Every opt-in live share also writes `livePointers/{uid}.token`
  (`live_session_coordinator.dart:150-176`); `livePointers`/`usernames` are
  `get: if true` (`firestore.rules:1013-1014`, `1034-1035`). The app only ever
  shows `/live/{token}`, so the rider never learns that anyone with their @handle
  can follow them unauthenticated. *Fix:* write the pointer only behind an
  explicit, visible "public link" setting.
- **90.D8 — MEDIUM (product decision) — since §88.1, "Followers" = anyone who taps
  Follow, retroactively.** `rideVisibleTo` (`firestore.rules:25-26`) checks the
  live edge; edges are self-created with no approval (`:1051-1053`); profile
  `visibility` isn't consulted (bikes `followers` tier at `:75` too). A stranger
  following a `private` rider instantly sees every followers-only ride ever
  shared. Combined with §90.A11 (block keeps the edge). *Fix:* follow requests
  for non-public profiles, or `profileVisibleTo` inside `rideVisibleTo`; at
  minimum relabel to "Anyone who follows you".
- **90.D9 — MEDIUM — `users` list queries: privacy bypass or broken search.**
  Same root as §90.A4 — also covers `searchByUsername`/`searchByEmail`, and
  `follows` is listable unfiltered (`firestore.rules:1050`) → bulk uid/email
  harvest. One emulator test settles which branch is live. Fix as §90.A4.
- **90.D10 — LOW — spoofable identity/photo fields.** `userName`/`userPhotoUrl`
  unvalidated on comments (`:697`), posts (`:774-776`), replies (`:839`);
  `senderPhotoUrl` on voice notes; `users.photoUrl` unrestricted. Names like
  "ThrottleIQ Team", and attacker-hosted photo URLs leak every viewer's IP (the
  §33.4 beacon, closed only for notifications). *Fix:* the §33.4 URL allow-list +
  name length cap everywhere.
- **90.D11 — LOW — forum `followerCount`/`postCount` still forgeable**
  (`firestore.rules:752-760`), not bound to a `forum_follows` doc or a new post;
  the rule comment claims otherwise. `createPost` is two writes
  (`forum_repository.dart:363-375`). *Fix:* `existsAfter` binding; single transaction.
- **90.D12 — not reviewed:** `functions/` dependency/tooling risk, and the
  moderation, crash and ride-identity function logic. Needs a follow-up pass, plus
  the emulator run for D9.

### 90.E Docs sweep (2026-10-06) — done in this pass, leftovers

**Done:** corrected stale facts in `README.md` (version beta-v4, test count, analyze
state, 200–349 m privacy radius, CSV export, hold-to-start), `arch.md` (directory
tree, SensorValidator 70 m/s, heading blend, crash thresholds, cadence,
`ride_points` columns, tabs, route params, test DB helpers, schema v18),
`DOCS/README.md`, `needs_attention.md`, `BIGGG_JOBB.md`, `DEBT_FIX_PLAN.md`,
`SETUP.md` (CI does run, is red, not required), `auto_tracking_plan.md`,
`backend_options.md`, `functions/README.md` (account-deletion does touch
Cloudinary/authored content), `pubspec.yaml` dead doc paths, 8 Dart doc-comment
fixes for renamed symbols/dead paths, and 53 per-folder `README.md` file lists
under `app/lib` and `app/test`. Fixed 8 dead `Contributers` links.

**Left open:**
- `features.md:221` still says `PhotoCollage` (now `RideMediaCollage`). Left alone
  because the file had someone else's uncommitted edits.
- About 120 dead `file:///Users/blackbird/Everything/dev/ThrottleIQ/...` links in
  `issues_solved.md` and `ANTIGRAVRITY_GRILL/*.md`. They point at the repo's old
  path. Either bulk-rewrite them to relative paths or archive those files.
- Rules-suite size: `BIGGG_JOBB.md` says 114, a grep counts ~138 `test(`/`it(`,
  and HANDOFF says 119. Run the emulator suite and record the real number.
- README claims "20+ data points per second" and "auth tokens in encrypted
  SharedPreferences" are unverified. The "Flutter 3.3+" badge is actually the
  Dart SDK constraint.

---

## 91. Critique leftovers carried over when `ANTIGRAVITY_GRILL/` was deleted (2026-10-06)

The root `ANTIGRAVITY_GRILL/` folder (the 2026-09-20 critique `Claude_CRTITISIZE.md` and the
Social Redesign mock HTML/PDF) was deleted. Everything in it that was fixed and pushed was
dropped; the items below were never fixed and weren't already tracked in §83, so they live
here now. (§83 still holds the other open critique items: 83.12 to 83.14, 83.16, 83.18,
83.19, 83.22, 83.23, 83.26 to 83.28, 83.31. The original writeup is in git history:
`git show 4b1a1b2^:ANTIGRAVITY_GRILL/Claude_CRTITISIZE.md`.)

- **91.1 — LOW — `bikesVisibleTo(uid)` does a `get()` of the owner's profile per bike read**
  (`firestore.rules:102`). These are billed rules reads and count against the 10/20 access
  limits. Fix: denormalise the visibility onto the bike doc.
- **91.2 — LOW — `crashNotifications` create has no rate limit** (`firestore.rules:~679`).
  Any signed-in client can write unlimited `pending` docs for itself, each triggering a
  Cloud Function. App Check (§83.19) narrows this but doesn't bound volume.
- **91.3 — LOW — the cockpit alert flash can't be switched off.**
  `active_ride_screen.dart:~206-223` washes the live map with a translucent colour on
  brake / accel / overspeed / fatigue. Only the overspeed threshold is configurable. Add an
  off switch in settings.
- **91.4 — LOW — eager lists.** About 25 `ListView.builder`/`.separated` uses vs. many
  `SingleChildScrollView` + `Column` lists (rides list, forum threads, places list).
  Feed pagination hid the cost; convert the long lists to lazy builders.
- **91.5 — LOW — 7-slide English-heavy onboarding tour before the first ride** (21 callout
  pins). Consider cutting it to the Record tab's hold-to-start. Related: §83.26 and §83.23.
- **91.6 — DESIGN — Social Redesign mock deleted.** The §86 follow-ups (solo "riding now"
  cards, per-card location label) were designed against that mock. It's in git history:
  `git show 4b1a1b2:"ANTIGRAVITY_GRILL/new_task/ThrottleIQ Social Redesign – Main.html"`.

---

## 92. Not-yet-done items carried over from `sum_claude.md` / `sum_gemini.md` (2026-10-06)

Both 2026-09-08 project summaries were deleted (stale: 908 tests, v1.0.0-beta.2.2). Anything
they described as built is already in `features.md`. What follows is only what they listed as
**not done**. Both files are in git history (`git show 15b42f1:sum_claude.md`, `:sum_gemini.md`).
Items already tracked elsewhere are pointed to rather than repeated: engineering debt is in
`optimizerplan.md` (EKF = #21, configurable overspeed = #9, iOS force-swipe note = #8), the
Blaze/Cloud Functions block is in §83.16/§83.19 and `HANDOFF_Document.md`, and hazard pins are
in the `HANDOFF_Document.md` roadmap table.

### 92.A Engineering roadmap, none of it built

- **92.A1 — crash/sensor thresholds are theoretical.** 80 m/s² crash, -4.0/3.5 m/s² brake/accel,
  100 km/h overspeed were set from first principles. Validate against real beta telemetry across
  mounts (tank bag, handlebar, jacket pocket) before trusting them. Highest-value use of beta data.
- **92.A2 — lean-angle telemetry** (roll rate + lateral accel → lean, max lean, corner entry/exit
  asymmetry). Nothing in `app/lib` yet.
- **92.A3 — threshold presets** (Urban Commute / Highway Touring / Track Day) on top of
  `optimizerplan.md` #9.
- **92.A4 — on-device crash classifier** (TFLite/ONNX trained on real waveforms to tell crashes
  from potholes, speed bumps, railway crossings). Needs the corpus from 92.A1 first.
- **92.A5 — predictive maintenance** (regress wear on riding intensity: jerk, hard braking,
  stop-and-go time) instead of fixed km intervals.
- **92.A6 — real map matching** (Valhalla/GraphHopper offline) and a "curviness" route planner. The
  precision-7 geohash baselining is the stopgap.
- **92.A7 — BLE OBD-II / TPMS** for RPM, throttle, coolant temp, tyre pressure.
- **92.A8 — `ride_recording_provider.dart` is still a monolith** (1,308 lines now, down from 1,810).
  The planned split was `RideSessionController` / `GpsPositionHandler` / `CrashAlertCoordinator` /
  `LiveSessionManager` (`optimizerplan.md` #1).
- **92.A9 — no verification on real Android OEM skins** (Xiaomi/Samsung aggressive battery
  managers) for foreground-service survival. Matches §88.3's device-check gap.

### 92.B Go-to-market, nothing started (marketing; no code)

- **92.B1 — Phase 0 closed beta:** about 50 high-mileage riders from Facebook clubs (Yamaha Club BD,
  Pulsar BD, RE Touring Club). Pre-seed brand forums with real maintenance discussions. Validate
  Bangladesh payment gateways ahead of any monetisation.
- **92.B2 — Phase 1 Play Store launch (target 5,000 installs / 1,500 weekly actives, Dhaka +
  Chattogram):** founder-written launch posts in motorcycle groups, moto-vlogger early access
  (demo group map + push-to-talk on a highway run), and a **garage/parts-shop programme**: onboard
  about 100 independent shops to the Places directory free, with branded QR counter cards.
- **92.B3 — Phase 2 (target 25,000 installs, Sylhet/Khulna/Rajshahi):** lubricant-brand sponsored
  "first to the badge" mileage prizes (Motul, Shell Advance, Yamalube), iOS TestFlight and public
  rollout, campus parking-lot activations with SafeQR helmet stickers.
- **92.B4 — Phase 3 (100,000+ riders):** B2B with local manufacturers/distributors (Runner, Walton,
  ACI Motors/Yamaha, Uttara Motors/Bajaj).
- **92.B5 — marketing screenshots exist for only 2 of 7 colour families** (Carbon Mono, Editorial).
  Deliberate (§58); don't claim more in the gallery until the rest are shot.
- **92.B6 — Play Console internal-testing track had zero testers assigned** at the last check. UI-only
  step (Testers tab). Verify whether it was ever done.
- **92.B7 — claim guardrails for any copy:** no automatic SMS/email crash escalation (functions not
  deployed, Blaze), no App Store availability claim until it ships, and chat messages persist for the
  account's lifetime (as in the privacy policy).
- **92.B8 — "weekly riding digest"** (Sunday summary: distance, moving vs jam time, fuel-efficiency
  trend) was a proposed retention hook. A `notifChannelDigest` channel string exists, but I didn't
  confirm a digest is actually sent. Check before promising it.

### 92.C Monetisation ideas (none built; decision pending, nothing approved)

- **Free tier:** offline tracking, crash detection, 2 bikes, core maintenance, forums.
- **Pro (BDT 99–149/month or about 999/year):** lean analytics, route weather overlays, unlimited
  GPX/JSON cloud backup, and a **Digital Vehicle Passport** (verifiable PDF of service history for
  resale buyers).
- **B2B:** certified resale verification, lubricant/tyre sponsored service alerts (for example
  "brake pads due, 10% off at partner garages"), insurer partnerships on safe-riding scores, paid
  verified garage listings.
- Competitor price points quoted: Strava about $11.99/mo, Rever/Calimoto $39–59/yr, Detecht about $60/yr,
  hardware trackers $40–100 plus SIM.

### 92.D Launch copy drafts worth keeping (nothing here has been published)

- **Taglines:** "ThrottleIQ — Machine Memory for Motorcycles." / "Works when your signal doesn't.
  Remembers what your bike needs." / "Someone will know if you go down." / Bangla:
  "বাইকের হিসাব থাকুক ফোনেই — অফলাইনেও প্রস্তুত।" and "সে রাইডে, আপনি নিশ্চিন্তে।"
- **Play Store short description (78 chars):** "Track every ride: speed, routes, crash alerts, bike maintenance & rider feed."
- **Poster lines:** EN "YOUR BIKE NEVER FORGETS A KILOMETER." / "Track speed, maintenance, and safety
  offline. Free download."; BN "সিগন্যাল না থাকলেও, রাইড রেকর্ড হতে থাকে।" / "মেইনটেন্যান্স অ্যালার্ট ও ক্র্যাশ
  ডিটেকশন এখন আপনার ফোনেই।"
- **Bangla Facebook launch post** (4 ticks: 100% offline tracking, km-based service reminders, crash
  detection + live location, group ride + push-to-talk; closing "no ads, no hidden charges"). Full text:
  `git show 15b42f1:sum_gemini.md`, Channel A. **Update it before use:** it says crash detection
  sends automatic alerts, which isn't true while functions are undeployed (see 92.B7).

## 93. Auto-tracking daily summary + beta jam labels — follow-ups (2026-10-06, committed)

What shipped is described in `features.md` → "Changes from the auto-tracking / jam pass". Still open:

- **[needs-you] 93.1 DECIDED 2026-10-07 (yes) and implemented — see §95.9 / `features.md` §5.** Was: *Decision needed: forgotten rides and the bike odometer.* Detected trips no longer become
  ride rows, so they no longer add to a bike's distance or service-interval km. The "which bike?"
  confirmation also no longer fires for new detections. Should forgotten rides still count toward
  maintenance reminders?
- **[doable-now] 93.2 Fix storage grows without limit.** Fixes for `summarized` detections are kept forever
  (about 150 KB per heavy riding day). Add a retention policy at some point.
- **[needs-you] 93.3 Needs a device test:**
  - how quickly auto-tracking stands down after a manual Start;
  - whether the background service on Android can show `flutter_local_notifications`;
  - the 9pm digest replacing the fixed "Tap to see your day" message (the fixed text may show for
    up to about 60 s first);
  - iOS at 9pm, where the background handler may not be alive and opening the app is the fallback.
- **[doable-now] 93.4 Missing tests.** `DailyRideSummaryRepository.summaryFor` (the SQLite path) has no tests;
  only the pure calculators are covered.
- **[doable-now] 93.5 Old docs.** `auto_tracking_plan.md` and `HANDOFF_Document.md` still describe the old
  "promote each detection to a ride" flow.
- **[doable-now] 93.6 ✅ Firestore rules deployed (2026-10-06)**, including the `jamLabels` rule. The compiler printed a
  warning at `398:46` (`publicStatsValid(resource == null ? null : ...)`), which comes from older
  code, not this change.
- **[needs-you] 93.7 Bangla review.** The new BN strings (daily summary, jam labels) are machine-drafted and
  listed in `bn_pending_review.txt`.
- **[needs-you] 93.8 Old auto rides.** Auto rides saved before this change stay in history and are counted as
  recorded rides.

## 94. Maintenance audit findings (2026-10-06) — FIXED in code 2026-10-07, see `issues_fixed.md` §94

All five items were fixed by the maintenance redesign (§95). None of them has
been verified on a device yet; that check is §95.1.

## 95. Maintenance redesign (2026-10-07) — committed `238d12b`, not checked on a device

What shipped is in `features.md` §5. Analyze is clean and 1547/1547 tests pass.
Still open:

- **[needs-you] 95.1 Device test.** None of the following has been run on a phone yet:
  - setup → Log a visit → Undo → edit → delete (then reinstall: the deleted
    visit must stay gone);
  - notifications: due-soon/overdue after a ride, scheduled date reminders,
    paperwork, tap → page;
  - the home widget's new wording;
  - PDF share;
  - receipt photo after an app update (iOS container path change is handled by
    `BikeImageResolver`, untested here);
  - the 60-day strip at small widths;
  - Bangla layout.
- **[needs-you] 95.2 Schedule templates are mostly approximate.**
  - Only the Bajaj Pulsar 150 template was read off a manual, and that was the
    Indian BS-VI manual.
  - Hornet 160, FZ, R15/MT-15, Gixxer, Apache 160 and the three generic
    templates come from coupon schedules and owner reports. The UI labels them
    "Approximate".
  - Each needs checking against the BD-market manual from ACI Yamaha, BHL Honda,
    Uttara Bajaj, Rancon Suzuki and TVS.
  - Each template's `source` note is English-only.
- **[needs-you] 95.3 Free-service counts per BD distributor are unverified.** The templates
  carry Indian schedules.
- **[needs-you] 95.4 Adaptation factors are a heuristic**, not OEM figures:
  - stop-and-go 0.8/0.9 at 35%/20% idle;
  - hard braking 0.85 at ≥ 3 per 100 km;
  - dusty/wet roads 0.7 on the air filter and chain;
  - floor 0.7.

  Validate them with 2–3 mechanics. The rider can switch adaptation off.
- **[needs-you] 95.5 Receipt photos aren't backed up.** They are stored only in the app
  documents folder; the path syncs, the image doesn't. There is no receipt OCR
  either. Uploading private receipts needs a non-public store (Cloudinary
  presets here are unsigned/public).
- **[needs-you] 95.6 Quick-check issues are local only** (`precheck_issues`). Deliberate,
  since they're short-lived.
- **[needs-you] 95.7 Bangla review.** About 180 new strings (batch "maintenance redesign
  (§95)" in `bn_pending_review.txt`) are machine-drafted.
- **[needs-you] 95.8 Older app versions.**
  - A log written with visit columns can't be inserted by a pre-v20 build; its
    download skips that row (per-row try/catch), so the log is missing on an
    un-updated second device.
  - A custom tracked check (`service_type = custom:<id>`) shows as a plain
    "Custom" check in old builds.
- **[doable-now] 95.9 Detected-trip credits** go to the active bike, since a detection
  carries no bike. A rider who switches bikes without changing the active one
  credits the wrong bike. The credits table is local; the bike's
  `odometer_km`, which holds the total, does sync.
- **[needs-you] 95.10 Open product questions:**
  - Should Maintenance get a bottom-nav tab? Garage cards now show "next due".
  - Should snooze also support "100 km later"?
  - Should the hero hide when everything is unknown?
- **[doable-now] 95.12 Code review findings (2026-10-07).** A read-only review of the diff
  found these; the high and medium items were fixed the same day, with tests:
  - alerts were cancelled the moment they were shown (the schedule is now
    cancelled first);
  - an older build skipped v20 visit logs but moved its pull mark past them (the
    mark now stops before any failed row, plus a one-time full maintenance pull
    after upgrading);
  - editing a visit dropped items whose custom check was gone, and wiped
    per-item prices;
  - notification ids could collide (they are now allocated and remembered per
    item);
  - a tap from a killed app went nowhere, and an already-open page kept the old
    bike;
  - the restore could lose the cloud profile or paperwork (placeholder profiles
    aren't uploaded; paperwork merges by kind);
  - the due day itself counted as "overdue";
  - the upgrade fired a burst of overdue alerts (the first run is silent);
  - signed-out users kept scheduled alerts;
  - `ref.watch` was used after an await;
  - a paperwork date-picker assert;
  - PDF receipt paths weren't resolved;
  - deleting a visit had no confirmation.

  **Still open from the review:**
  - The new-bike baseline is derived from `odometer_km − credits`. An odometer
    sync or a reinstall (credits are local) can push "km at add" past 500, and
    never-logged checks then flip to "unknown". Fix: store the odometer reading
    at add time.
  - If the rider has no bike, a detection is marked summarised without its km
    being credited.
  - Receipt image files aren't deleted with their visit.
  - A page left open past midnight shows yesterday's day counts until something
    refreshes it.
  - The home-screen widget text and the alert body are English and km-only;
    alerts ignore the miles setting.
  - On a fresh install, paperwork added *before* the first sync restores still
    replaces the cloud paperwork list. Sync runs at sign-in, so the window is
    small.
- **[needs-you] 95.11 The order button is still a demo.** It is now gated to
  `BetaTesters.partOrdering`. It needs a parts partner before a real flow.
- **[doable-now] 95.13 CI ratchet failure — FIXED (2026-10-07), see `issues_fixed.md` §95.13.**

---

## 96. Budget-phone readiness for Bangladesh riders (surfaced 2026-10-07, not started)

The Play Console device count (12,312 phones, `minSdk 24`) already covers the
budget phones sold in Bangladesh, so installing isn't the problem. The risk is
whether the app keeps working on them once installed. Nothing below has been
tested on a real budget phone yet. A full screen-off ride on a 2–3 GB itel,
Tecno or Redmi would check all three.

- **96.1 OEM battery managers kill background services — HIGH.** Xiaomi
  MIUI/HyperOS, Tecno/Infinix/itel (HiOS/XOS) and Realme/Oppo (ColorOS) kill
  background services aggressively. That can silently stop auto-tracking and
  crash detection. Today the app only asks for the stock Android
  battery-optimization exemption
  (`ride_recording_provider.dart` `_prefsBatteryOptPrompted`,
  `auto_tracking_service.dart` `requestIgnoreBatteryOptimization`). There is no
  per-brand guidance. Onboarding should detect the manufacturer and send the
  rider to the right autostart / background-activity / battery settings for
  that brand (see dontkillmyapp.com for each brand's steps).
- **96.2 Phones with no gyroscope / weak accelerometer — MEDIUM.** Many budget
  phones have no gyroscope. The manifest already marks the accelerometer and
  gyroscope `required="false"`, so the app installs. Still to check: crash
  detection and lean-angle (`sensor_fusion_coordinator.dart`,
  `vehicle_state_estimator.dart`) degrade gracefully when there's no gyroscope
  stream. They should not crash, show 0° or fake lean, or fire false crash
  alerts. The UI should say clearly when lean angle isn't available on the
  phone.
- **96.3 Low RAM (1–3 GB) — MEDIUM.** The OS is more likely to kill the app
  mid-ride, and map screens can stutter. Check ride recovery after a process
  kill on a low-RAM device, and map/ride-screen performance there.

## 97. Places/Forums redesign — first iPhone debug run & audit findings (2026-10-07, branch `feature/places-forums-reimagine`)

Debug build on iPhone 15 (iOS 27). The app launched and ran without crashing. Follow-up audit identified the exact sources and fixes for each logged finding, plus feature/architecture flaws:

- **97.1 ListTile inside a coloured DecoratedBox — LOW.** Framework assertion: "ListTile background
  color or ink splashes may be invisible".
  - **Sources identified:**
    1. Primary: `auto_tracking_tile.dart:31-40` & `222-231` — `Container(decoration: BoxDecoration(color: context.palette.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.palette.border)))` wraps `SwitchListTile`. In dark mode, `surface` is `#14151F` (the exact hex in the assertion). `RecordScreen` loads this tile on app startup; Flutter's `ListTile._debugCheckBackgroundIsHidden` detects the colored `DecoratedBox` without an intervening `Material`, throwing the assertion because ink ripple splashes are occluded.
    2. Route screens: `route_detail_screen.dart:183` and `save_route_screen.dart:180` — both wrap `SwitchListTile` in a rounded `#14151F` `Container` decoration.
    3. Overflow menu: `places_list_screen.dart:156,164` — inside the AppBar's `PopupMenuButton<String>`, `PopupMenuItem`'s child is set to `ListTile`. `PopupMenuItem` already handles ink on a themed surface card, so nesting a `ListTile` inside it produces conflicting ink splashes.
  - **Fix:** In `auto_tracking_tile.dart`, `route_detail_screen.dart`, and `save_route_screen.dart`, replace `Container(decoration: ...)` with `Material(color: context.palette.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.palette.border)), clipBehavior: Clip.antiAlias, child: Column(...))`. In `places_list_screen.dart`, replace `ListTile` inside both `PopupMenuItem` widgets with a standard `Row(children: [Icon(...), SizedBox(width: 12), Expanded(child: Text(...))])`.
- **97.2 RenderFlex overflowed by 3.0 px on the bottom (×2) — LOW.**
  - **Source identified:**
    1. Map carousel (`places_map_view.dart:28,323`): `placesCarouselHeight = 196`. In `place_card.dart:66-192`, `PlaceCard(compact: true)` has Category icon row (40px) + SizedBox(8) + `PlaceRatingBadges` pill (~24px) + SizedBox(6) + Divider(1) + Action buttons row (`minimumSize: Size(0, 40)`) + Card padding (20px) + AppCard border (2px) + Highlight border when selected (`DecoratedBox`, 4px). On iOS (iPhone 15) with SF Pro system typography line heights and default button tap padding without `shrinkWrap`, the highlighted card measures exactly **199.0 px**. `199.0 px - 196.0 px = exactly 3.0 px overflow`. It logs `(×2)` because `PageView.builder` with `viewportFraction: 0.9` renders page 0 and pre-renders page 1 simultaneously.
    2. Category chip ribbon (`places_list_screen.dart:348`): sits in a fixed `height: 48` `SizedBox` with vertical padding `6`. With enlarged system accessibility fonts, the chip container can also exceed the 36 dp remaining height.
  - **Fix:** In `places_map_view.dart:28`, bump `placesCarouselHeight` from `196` to `208`. In `place_card.dart:23`, add `tapTargetSize: MaterialTapTargetSize.shrinkWrap` to `placeActionButtonStyle`. In `places_list_screen.dart:348`, bump ribbon height from `48` to `52`.
- **97.3 `Exception: Invalid image data` — LOW/MEDIUM.**
  - **Source identified:** `user_avatar.dart:20-34` uses `CircleAvatar(backgroundImage: hasPhoto ? CachedNetworkImageProvider(photoUrl!) : null, child: hasPhoto ? null : Text(...))` with NO `onBackgroundImageError` callback. When an avatar URL is invalid, 404s, or returns non-image HTML/corrupt bytes (common with seeded QA test users or broken URLs), `CachedNetworkImageProvider` fails during image decoding (`instantiateImageCodec`), and Flutter's default listener throws an uncaught decode exception into the framework zone. Because `UserAvatar` renders for every post in `ForumsPulseView`, every card in `_FeedTab`, and every rider in `_PeopleTab`, opening those views triggers bursts of 10+ unhandled exceptions. Additionally, `child: hasPhoto ? null : ...` leaves the avatar as a blank circle instead of displaying user initials.
  - **Fix:** Refactor `UserAvatar` to use `CachedNetworkImage` inside `ClipOval` with `placeholder: (_, __) => fallback` and `errorWidget: (_, __, ___) => fallback`, ensuring no unhandled decode exceptions escape and fallback initials are always shown. Also in `app_tile_layer.dart:120`, pass `errorImage: MemoryImage(Uint8List.fromList(_transparentPixelPng))` to `TileLayer` to catch any OSM rate-limit HTML responses.
- **97.4 Place photos uploaded in `AddPlaceScreen` are never displayed in `PlaceDetailScreen` — MEDIUM.**
  - **The Flaw:** `AddPlaceScreen:182-195` allows riders to upload place photos via Cloudinary, `PlaceEntity` and `PlaceModel` persist `photoUrls`, but `PlaceDetailScreen` has no photos gallery or header photo widget. Any photos submitted by riders are saved in the cloud but never shown to anyone.
  - **Fix:** Add a horizontal photo thumbnail row or hero image banner at the top of `PlaceDetailScreen` when `place.photoUrls.isNotEmpty`.
- **97.5 `SavedPlacesTab` eager list instantiation (§91.4) — LOW.**
  - **The Flaw:** `saved_places_tab.dart:69-91` renders saved places using an eager `ListView(children: [contributed, ...for (h in hits) PlaceCard(...)])`. When a rider accumulates 20+ saved bookmarks, all `PlaceCard` widgets and buttons are instantiated eagerly rather than lazily.
  - **Fix:** Convert `SavedPlacesTab` list to `ListView.builder` or `ListView.separated`.
- **97.6 Web crash hazard in `place_launch_actions.dart:94` — LOW.**
  - **The Flaw:** `place_launch_actions.dart:94` uses `Platform.isIOS` from `dart:io`. On Flutter Web, accessing `Platform` properties throws `UnsupportedOperation: Platform._operatingSystem`.
  - **Fix:** Import `package:flutter/foundation.dart` and use `defaultTargetPlatform == TargetPlatform.iOS`.
- **97.7 Inconsistent package imports in `forum_post_model.dart` — LOW.**
  - **The Flaw:** `forum_post_model.dart:2-3` uses package imports (`package:throttleiq/...`) while the rest of `features/forums/` uses relative imports (`../../../../core/...`, `../../domain/...`).
  - **Fix:** Switch to relative imports for codebase consistency.
- **97.8 Partial photo upload error handling in `forum_thread_screen.dart:326` — LOW.**
  - **The Flaw:** In `forum_thread_screen.dart:326`, `for (final path in _photoPaths) await repo.uploadPostPhoto(...)` executes in a loop. If upload 3 of 4 fails, earlier uploads remain in Cloudinary without a post pointing to them, and the error toast displays a generic Firestore error (`mapFirestoreError`) rather than informing the user that photo upload specifically failed.
  - **Fix:** Wrap photo uploads in a dedicated try-catch with a specific photo upload error message and non-fatal crash reporting.
- App Check debug-token exchange returns 403 `SERVICE_DISABLED`. This isn't from the redesign; see
  §62.12 / §83.19.

## 98. UI screenshot tour on a physical iPhone — not working yet (2026-10-07)

`app/integration_test/ui_tour_test.dart` now has a device mode (`--dart-define=TOUR_DEVICE=true`) that
captures each shot in-app to `Documents/tour/shots/` instead of using host `simctl`. It has not worked
on the iPhone 15 yet, so the screenshots in `DOCS/General/designs/live_UI_screenshots/` were captured
on the iPhone 17 simulator instead (see below). The simulator path is verified; the device path is not.

- **98.1 Test runner can't attach over wireless debugging — MEDIUM (tooling).** `flutter test -d <iPhone>`
  built and installed fine (about 170 s build), then failed with `WebSocketChannelException: Connection
  reset by peer` on the VM service. The phone was connected wirelessly. Retry over USB with the phone
  unlocked. `flutter run -t integration_test/ui_tour_test.dart` is not an alternative: it launches the
  normal app and never runs the test. The pull step is not written yet: copy the PNGs off the phone with
  `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier com.bft.throttleiq
  --source Documents/tour/shots`.
- **98.2 Firebase sign-in "Too many attempts" — MEDIUM, unconfirmed cause.** The device run log showed
  that error alongside the App Check 403 from §97. The later simulator run signed in fine as
  `rider@example.com`, so the lockout cleared; the cause was never pinned down.
- **98.3 Tour combos stale after the theme refactor — FIXED 2026-10-07.** `run_tour.sh` listed the old
  seven color names; it now uses `daily | sport | adventure` (12 combos). `live_UI_screenshots/` was
  recaptured as three looks (`daily_curvy_light`, `sport_boxy_dark`, `adventure_boxy_dark`), 55 screens
  each, replacing the old Carbon Mono / Trail Social folders. The tour captures 95 shots per look; scroll
  continuations, filled forms and tour slides 2-7 are left out to keep the repo small.

## 99. Realtime Database movement channel — open items (2026-10-07, commit `8f8f774`; checklist in `DOCS/websockets_todo.md`)

Design: `DOCS/For Devs and Contributors/architecture/realtime-database.md`.

- **99.1 Not live: no RTDB instance, no `RTDB_URL` in builds — HIGH (blocks the feature).** Steps: (1) Firebase console → Realtime Database → create it in `asia-southeast1`, locked mode. (2) `firebase deploy --only database`. (3) Add `--dart-define=RTDB_URL=<instance URL>` to the release build scripts. (4) Deploy hosting, so the viewer picks up `databaseURL` from `/__/firebase/init.json`. (5) Run `node scripts/verify_realtime.js --url=<URL>` against production. Note that `firebase.json` now has a `database` target, so a bare `firebase deploy` fails until step 1 is done.
- **99.2 Group-ride positions readable by anyone holding the ride id — MEDIUM (accepted for now).** RTDB rules can't read Firestore `memberIds`, so `/group_rides/{id}/locations` is readable by any signed-in user who knows the id (from the join code), not only members. Kicked riders are blocked through `banned/`. Fix: a Cloud Function that mirrors `memberIds` into RTDB, once functions can deploy.
- **99.3 RTDB `meta` claim is first-writer-wins — LOW.** A member who knew the id before the creator's claim landed could claim `meta`. The claim goes out in the same step as ride creation, and the app ignores the channel when `meta.creatorId` doesn't match Firestore's creator, so the worst case is falling back to Firestore. Rides created by older builds have no `meta` and stay on Firestore.
- **99.4 Orphaned `/live_shares` node if the app is killed mid-share — LOW.** The Firestore teardown goes through the outbox, but the RTDB node doesn't. It stays readable until its `expiresAt` (at most 24 h), and the viewer won't show it because it gates on the Firestore session. A share longer than 24 h stops getting RTDB reads; the viewer falls back to Firestore.
- **99.5 Not checked on a device — MEDIUM.** Run `app/integration_test/realtime_emulator_test.dart` against the emulators (instructions are in its header). Then check on two phones: a live share open in a browser, a group ride, and a chat.
- **99.6 Bangla strings need native review — LOW.** `groupRideRealtimeLive`, `groupRideRealtimeDelayed` and `chatTyping` are in `bn_pending_review.txt`.


## 100. E2E integration test can't start: Firebase never initialized — MEDIUM (tooling, found 2026-10-07)

`app/integration_test/e2e_test.dart` pumps `ThrottleIQApp` without calling `Firebase.initializeApp()`, and the test's own comment says so. On the iPhone simulator it fails at once with `[core/no-app] No Firebase App '[DEFAULT]'`, raised from `groupRideLifecycleProvider` building `rideRecordingProvider`. The test never reaches the Places/Saved/bottom-nav assertions. The same failure shows on a clean checkout of `ca1f3f6`, so it predates the §99 work. Fix: add a `setUpAll` that runs `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, as `main.dart` does.


## 101. Full-project audit (2026-10-07, read-only, 7 parallel passes) — PARTLY FIXED 2026-10-08, see per-item notes

IDs are `101.<area><n>`. "AUTO" = an agent can fix and verify it with analyze/test/rules tests, no founder input or device. Line numbers came from grep and partial reads, so confirm before editing. Items already tracked elsewhere were left out. Baseline at audit time: `flutter analyze` clean, `flutter test` 1758/1758.

### 101.S Security rules, functions, hosting, scripts, CI
- **101.S1 HIGH — place rating inflation** (`firestore.rules` ~1143-1160). The `ratingCount+1` update only checks the caller's review exists, not that it is the first. One user can repeat it. Fix: `existsAfter(review)` + `!exists(review)` in one batch, or move to a function. AUTO.  
  **Resolution:** FIXED (2026-10-08): rule now needs `!exists(review)` + `existsAfter(review)` + `getAfter(review).stars == delta`; `addReviewAndUpdatePlaceRating` runs review set + place update in one transaction. Tests: 7 new rules tests (replay, 2-step bump, no review, wrong delta, second review denied).
- **101.S2 HIGH (latent) — account-deletion anonymization fails silently.** `functions/src/account-deletion.ts` runs `collectionGroup("posts"|"replies"|"comments").where("userId","==",uid)`; `firestore.indexes.json` has `fieldOverrides: []`, so it throws `FAILED_PRECONDITION`, which is caught. Forum posts, replies and ride comments keep the rider's identity. Fix: add COLLECTION_GROUP overrides. AUTO to write, deploy needs CLI.  
  **Resolution:** PARTLY FIXED: the wrong INDEXES comment in `account-erasure.ts` corrected and a failed anonymize step is now recorded in the deletion marker. **Still open (founder/CLI):** add the three COLLECTION_GROUP `userId` fieldOverrides (posts, replies, comments) to `firestore.indexes.json` and `firebase deploy --only firestore:indexes`; until then those steps still fail. The emulator does not enforce indexes, so no test.
- **101.S3 MED — rules missing shape/size/dedupe checks:** usernames (any handle, no format, squattable), `users/{uid}/notifications` (anyone can write into anyone's inbox), ride `likes`/`votes` (no `rideVisibleTo`, extra fields), forum post/reply and chat message (no `is string`/`size()`, no `createdAt == request.time`, no key allow-list, client can preset `isToxic`), `liveSessions` (unbounded `expiresAt`, mutable `uid`), `crashNotifications` (no allow-list, string coords go into SMS/email URL, no per-ride id), `groupRides/members` and `groupRideJoinCodes` (non-members can write), `reports` (no caps, enum or dedupe), `roadSpeedSamples`, `chats.lastMessage`, `emergencyContacts`. AUTO (rules tests in `scripts/test/rules/`).  
  **Resolution:** PARTLY FIXED (2026-10-08): FIXED with rules tests: usernames (format `^[a-z0-9_]{3,20}$` + keys), ride likes (client create/update closed), ride/forum votes (`rideVisibleTo` + `hasOnly(['value'])`), forum post/reply (string/size caps, `createdAt == request.time`), chat message and `lastMessage` (allow-list, size, `createdAt`/`updatedAt == request.time`, `isRead` false), liveSessions (`expiresAt` <= +48h, `uid` immutable), crashNotifications (`hasOnly`, numeric lat/lng range), groupRideJoinCodes (`existsAfter` ride, creator + code match), reports (allow-list, caps, enum). NOT REAL: `users/{uid}/notifications` (writing into another inbox is the feature), `roadSpeedSamples` (already checked), crash per-ride id (already `rideId == documentId`). REAL-BUT-SKIP: username squatting (needs tie to `users/{uid}.usernameLower`), `groupRides/members` non-member write (needs a Cloud Function, same as S6 locations), `emergencyContacts` shape (owner-only, self-harm only).
- **101.S4 MED — `account-deletion.ts` misses** `chats` + `messages`, `groupRides` subcollections, RTDB `live_shares`/`group_rides`/`chat_presence`, `forum_follows`, `reports`, `groupRideJoinCodes`. No retry or completion marker. Apple 5.1.1(v) risk. AUTO for code and tests, deploy no.  
  **Resolution:** PARTLY FIXED (2026-10-08): `account-deletion` now removes `forum_follows` (and decrements `followerCount` on surviving forums), group-ride membership/`memberLocations`/invitations (ends rides the rider created), RTDB `live_shares`/`group_rides`/`chat_presence` nodes, and writes `accountDeletions/{uid}` completion marker with `failedSteps`. Tests: emulator tests in `functions/test` (not run in the final QA pass; run `npm run test:emulator` in `functions/`). REAL-BUT-SKIP: retry policy (every step catches its own error, so enabling retry changes nothing; marker is the signal), `chats`/`messages` deletion (open product decision, noted in the file header), `reports` (Trust & Safety evidence). NOT REAL: `groupRideJoinCodes` (holds no uid).
- **101.S5 MED — `crash-notifications.ts` not idempotent.** No status claim, so a retry re-sends alerts; escalation sends then updates without a transaction; outer catch hides failure from the scheduler; no `maxInstances`/`retry`. Fix before `DELIVERY_IMPLEMENTED` flips. AUTO.  
  **Resolution:** FIXED (2026-10-08) for idempotency, not retry: `crash-claim.ts` + transactional claim `pending -> processing` (5 min lease) before sending, and escalation claims `contacted -> escalating`; racing deliveries give one `notificationLog` row per contact. Tests: pure tests + emulator test. REAL-BUT-SKIP: `maxInstances`/`retry` on the triggers (retry is unsafe until the send path is proven idempotent on a device).
- **101.S6 MED — RTDB:** `chat_presence` lets anyone write fake "typing" to any uid pair (no chat check, no `onDisconnect`); `group_rides/.../locations/$uid` has no membership check (write twin of §99.2); `live_shares/$token` exposes `uid` to viewers. Partly AUTO.  
  **Resolution:** NOT FIXED, nothing safe to change (2026-10-08): `chat_presence` NOT REAL (write already needs `$uid_`/`_$uid` chat id and auth uid); `live_shares/$token` exposing `uid` NOT REAL (token holder already gets the uid from Firestore); `group_rides/.../locations/$uid` membership check is REAL-BUT-SKIP and needs a Cloud Function (members live in Firestore, RTDB rules cannot read them). Founder: decide whether to add that function.
- **101.S7 MED — hosting:** `firebase.json` has no CSP, `X-Content-Type-Options`, frame or referrer headers. `public/live-viewer.html` loads Leaflet from unpkg and Firebase from gstatic with no SRI while showing live location. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): `firebase.json` hosting headers `**`: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, CSP `frame-ancestors 'none'`, `Referrer-Policy: strict-origin-when-cross-origin`. Test: `scripts/test/hosting_repo_hygiene.test.js` (+ hosting emulator curl). REAL-BUT-SKIP: full CSP and SRI for unpkg/gstatic in `live-viewer.html` (a script-src CSP would break the Firebase compat loader; pin versions + SRI hashes needs a browser check). Not deployed.
- **101.S8 LOW — `public/install.html` and `install/index.html` are identical 675-line copies** with broken `../assets/icon-dark.svg` and `../index.html` links; the APK link repo (`blankframe-tech/ThrottleIQ`) should be checked. AUTO.  
  **Resolution:** FIXED (2026-10-08): `public/install.html` is now a meta-refresh redirect to `/install`; broken links fixed (`/icon-dark.svg` added, dead tour link removed, privacy link `/privacy.html`). Test: `hosting_repo_hygiene.test.js` checks every local href/src exists. APK repo link NOT REAL (`blankframe-tech/ThrottleIQ` is this repo's remote).
- **101.S9 MED — `scripts/deploy.sh:~127,135` runs `git add -A`, commits and pushes the current branch;** `--skip-qa` bypasses the gate. `qa_seed_catalog.js` and `verify_realtime.js` have no dry-run or project guard. `scripts/` pins `firebase-admin ^12`, functions use `^14`. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): `scripts/deploy.sh` aborts on untracked files and stages with `git add -u` instead of `git add -A` (tested in scratch repos; deploy.sh itself never run). NOT REAL: `--skip-qa` (documented, explicit opt-in), `qa_seed_catalog.js`/`verify_realtime.js` guards (pure module / read-only). REAL-BUT-SKIP: `firebase-admin ^12` vs functions `^14` (separate packages, bump needs a retest).
- **101.S10 MED — CI (`.github/workflows/ci.yml`):** no `permissions:` block, tags not SHA-pinned, `npm install` with no lockfile, unpinned `firebase-tools`, no `npm audit` or secret scan, runs on push and PR (duplicate runs), no `firebase.json`/index validation. AUTO except branch protection (KNOWN).  
  **Resolution:** PARTLY FIXED (2026-10-08): `ci.yml` has top-level `permissions: contents: read` and pins `firebase-tools@15`. Test: hosting hygiene test. ALREADY FIXED: firebase.json/rules validation (emulator jobs parse them). REAL-BUT-SKIP: SHA-pinning actions, lockfile (`scripts/.gitignore` ignores it on purpose), duplicate push+PR runs. HARMFUL-AS-SUGGESTED: blocking `npm audit` would fail CI immediately; use GitHub secret scanning (repo setting, founder).
- **101.S11 MED — `firestore.indexes.json` drift:** `liveSessions (userId, expiresAt)` vs field `uid`; dead `crashNotifications` COLLECTION_GROUP index; legacy `rides` indexes. Related to §84. AUTO.  
  **Resolution:** REAL-BUT-SKIP (2026-10-08): the stale `liveSessions (userId, expiresAt)`, dead `crashNotifications` COLLECTION_GROUP and legacy `rides` indexes are unused by any query; removing indexes is only safe together with an index deploy (founder, §84).
- **101.S12 LOW — contact email inconsistent:** `public/privacy.html` shows a personal Gmail, `install.html` uses `hello@blankframe.tech`. Founder decision.
- **101.S13 LOW — local plaintext secrets** in the repo tree (`secret/creds.txt`, `secrets/*.json` service account, `scripts/qa_seed_passwords.*.json`, `app/android/key.properties`, keystore). All gitignored and never in history (checked). Move outside the repo. Founder. Also confirm the `git log -S'BEGIN PRIVATE KEY'` hits (`d7ea7fe`, `f1d252d`, `1b1e5cf`, `a572868`) hold no real key; contents were not inspected.
- **101.S14 LOW — Firebase API keys** (Android, iOS, web) must be restricted by package/bundle/referrer in the GCP console. Founder. `storage.rules` is dormant (not in `firebase.json`).

### 101.A Auth, social, chat, forums
- **101.A1 HIGH — `deleteAccount` has no re-auth flow** (`settings_screen.dart:~694`, `auth_provider.dart:~180`). `requires-recent-login` shows as a raw error string, so deletion fails for any older session. AUTO.  
  **Resolution:** FIXED (2026-10-08): `AuthNotifier.reauthenticate` (password / Google) and a retry-once delete flow on `requires-recent-login`, with EN/BN strings. Tests: `test/features/auth/auth_notifier_test.dart`, l10n tests.
- **101.A2 HIGH — sign-out does not stop live share or group-ride broadcast** (`auth_provider.dart:~135`). RTDB leases and nodes can outlive the session. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): sign-out now revokes the live share via a `beforeSignOut` hook with a timeout. REAL-BUT-SKIP: group-ride broadcast (the RTDB lease is released by the map screen's dispose). Test: `auth_notifier_test.dart`.
- **101.A3 MED — unbounded or non-atomic client queries:** `forum_repository.dart:~640` (`_modelForumsUnder`), `:~446` (`forum_follows`), `group_ride_repository.dart:~660`, `ride_share_repository.dart:~484` (`deleteSharedRide` uses `Future.wait`, not batches). AUTO.  
  **Resolution:** NOT FIXED, by design (2026-10-08): NOT REAL for `_modelForumsUnder` and `group_ride_repository` (results are bounded by the catalog / active rides). HARMFUL-AS-SUGGESTED for `forum_follows` `.limit()` (would silently drop follows) and for batching `deleteSharedRide` (rules for likes/comments deletion need the ride to exist, so the order matters). The finish pass reverted the `.limit()` and WriteBatch changes.
- **101.A4 LOW — raw exceptions shown to users** (`report_bottom_sheet` `failedSubmitReport(e)`, settings sign-out has no try/catch). Hard-coded `Text('Social')` at `social_screen.dart:128`. `GestureDetector`s without semantics or 48dp targets in `social_feed_tab.dart` and `chat_room_screen.dart:270`. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): FIXED: `report_bottom_sheet` and delete-account errors no longer show raw exceptions (placeholder-free EN/BN strings), sign-out has try/catch, `social_screen` title uses `navSocialLabel`, chat own-bubble contrast + long-press report semantics, feed sort pills semantics (G8). Tests: `app_localizations_test.dart`, `chat_bubble_contrast_test.dart`, feed pill tests. REAL-BUT-SKIP: remaining GestureDetector semantics in `social_feed_tab` group-ride card and username link (tap action already exposed).
- **101.A5 MED — chat moderation is a six-word English keyword list; no block-on-report.** Product decision.

### 101.C Core, sync, database
- **101.C1 HIGH — no timeouts on any sync commit** (`cloud_repository.dart` `batch.commit()`, `sync_manager.dart:235-481`). On a captive portal or dead link `_isSyncing` stays true and all later syncs skip. AUTO.  
  **Resolution:** REAL-BUT-SKIP (2026-10-08): adding timeouts to Firestore `batch.commit()` is unsafe (a timeout does not cancel the write, so the retry can double-apply); the C2 try/finally fix means a stuck call no longer wedges later syncs once it settles. Needs a design (cancel token or idempotent batches).
- **101.C2 MED — `_isSyncing` stuck if `checkConnectivity()` throws** (`sync_manager.dart:248`, outside try/finally). AUTO.  
  **Resolution:** FIXED (2026-10-08): connectivity check moved inside the try so `finally` always clears `_isSyncing`. Test: `test/core/cloud/sync_manager_guard_test.dart`.
- **101.C3 MED — failed ride or bike inserts are lost for good:** the pull watermark advances past them; only maintenance has the `firstFailed` rewind. AUTO.  
  **Resolution:** FIXED (2026-10-08): `markShortOfFailures`/`earlierFailure` hold the pull watermark back for failed ride/bike inserts (rides of tombstoned bikes excepted). Tests: `incremental_pull_test.dart`.
- **101.C4 MED (design) — remote edits never reach a second device.** Downloads insert missing rows only. Needs a conflict policy. Founder.
- **101.C5 MED — `app.dart:146-175` runs on every auth emission,** re-calling `restoreInterruptedRide()` and `AutoTrackingService.start()` (re-prompts, §90.C11) with no catch. Gate on uid change. AUTO.  
  **Resolution:** FIXED (2026-10-08): `authSideEffect(prevUid, nextUid, isError)` gates the auth listener, so only real sign-in/out acts; restore/auto-tracking calls are caught. Test: `test/app_test.dart`.
- **101.C6 MED — `auto_tracking_service.dart:414 allowWakeLock: true`** holds a CPU wakelock all day. Needs battery test on a budget phone. Device.
- **101.C7 MED — `auto_tracking_service.dart:178,193` `_onFix` via `unawaited` with no try/catch;** SQLite errors lose fixes silently. AUTO.  
  **Resolution:** FIXED (2026-10-08): `_maybeBegin` and fixes go through `guardedFix` with try/catch and logging. Test: `auto_tracking_guard_test.dart`.
- **101.C8 MED — timezone lookup failure falls back to UTC** (`notification_service.dart:79-82`), so Bangladesh notifications fire 6 h off, unreported. Fall back to Asia/Dhaka and report. AUTO.  
  **Resolution:** FIXED (2026-10-08): `resolveLocalLocation` falls back to Etc/GMT by device offset, then Asia/Dhaka for +6h, then UTC, and logs. Test: `notification_tz_test.dart`.
- **101.C9 LOW (batch):** `scheduled.add(Duration(days:1))` ignores DST; outbox `next_attempt_at` stored as local string (use UTC, needs compat read); `retryDead` revive outside `_serialized` and `DateTime.parse` can throw the whole list; `HomeWidget.widgetClicked.listen` twice with no cancel; `getServiceStatusStream` no `onError` and every resume invalidates position/places; `app.dart:209-219` fallback calls `context.l10n` above `MaterialApp`; router treats auth loading/error as signed out, drops deep links when signed out, unencoded `bikeId`; `main.dart:84-100` error handlers installed after awaited init; `image_crop_screen.dart:109` leaks decoded `ui.Image`; `bug_report_service.dart` hard-codes version `1.0.0` and never purges reports; no `onDowngrade` in `database_helper.dart:99` (older build over v22 DB bricks); hard-coded English in gauge semantics, `home_widget_service.dart:72`, auto-tracking channel text, `firebase_error_mapper.dart:65`, `full_screen_route_map_screen.dart:355`. All AUTO (Bangla text needs review).  
  **Resolution:** PARTLY FIXED (2026-10-08): FIXED: DST-safe `nextInstanceOf`, single widget-click subscription with `onError`, `getServiceStatusStream` `onError`, localized fallback `AppInitErrorScreen`, image-crop decoded-image dispose (tests added for each). NOT REAL: `retryDead` race, `main.dart` handler ordering. REAL-BUT-SKIP: outbox UTC `next_attempt_at` (needs compat read), router auth-loading redirect, bug-report version string, remaining hard-coded English channel names. HARMFUL-AS-SUGGESTED: `onDowngrade` (sqflite would wipe or fail on a downgraded install).
- **101.C10 LOW (privacy) — ride start lat/lng is sent to Open-Meteo** (`weather_service.dart:46`). Confirm it is disclosed; coarsening to 2 decimals is AUTO. Disclosure is founder.

### 101.R Ride, routes, maintenance, garage, stats
- **101.R1 HIGH — editing a bike double-counts distance.** `add_edit_bike_screen.dart:59,165` prefills the baseline `odometer_km`, while the detail screen shows baseline + ridden km. Typing the dashboard reading adds tracked km again, so maintenance runs early. Clearing the field cannot null it (`copyWith ??`). AUTO.  
  **Resolution:** FIXED (2026-10-08, G7 finish pass): edit prefills the dashboard reading (baseline + ridden km) and converts back to a baseline on save; `clearOdometer` lets the field be nulled. Tests: `garage/add_edit_bike_screen_test.dart`, `garage/bike_entity_test.dart`.
- **101.R2 MED — no numeric validation:** bike form (odometer, year, cc) and `add_maintenance_log_screen.dart:273,530` accept `-5`, `Infinity`, `NaN`; no upper bound; no warning when a log odometer is below the previous one; `_loading`/`_saving` not reset on throw; `context.l10n` after `pop()`. AUTO.  
  **Resolution:** FIXED (2026-10-08, G7 finish pass): bike form (odometer, year, cc) and maintenance log validators reject negative/NaN/Infinity/over-range via `parseLocalizedNumber`; save errors reset `_saving` and show a localized message. Test: `maintenance/add_maintenance_log_validation_test.dart`. REAL-BUT-SKIP: below-previous-odometer warning.
- **101.R3 MED — `maintenance_forecast.dart:127-136,201` `latestLogFor` picks the highest odometer, not the latest date.** One typo log masks real services; after an odometer reset newer lower logs are ignored; `kmSince` clamps to 0 and never goes due. AUTO.  
  **Resolution:** REAL-BUT-SKIP (2026-10-08): `latestLogFor` picks the highest odometer on purpose (a typo log is a data problem; changing it needs a product rule for odometer resets).
- **101.R4 MED — Bangla digits and decimal commas fail `double.tryParse`** in every numeric field (`odometer_sync_sheet.dart`, `running_costs_sheet.dart`, `edit_maintenance_check_sheet.dart`, `maintenance_config_screen.dart`, `maintenance_setup_screen.dart`). Add one shared `parseLocalizedNumber`. AUTO.  
  **Resolution:** FIXED (2026-10-08): `core/utils/parse_localized_number.dart` (Bangla digits, grouping commas, decimal comma, non-finite rejection, min/max) wired into the maintenance sheets, config/setup screens, log screen and bike form. Test: `core/utils/parse_localized_number_test.dart`.
- **101.R5 MED — `fix_kinematics.dart:56-87`, `motion_calculator.dart:30`:** speed is clamped but acceleration and jerk still come from the raw speed, so a GPS spike triggers hard-brake alerts, `highJerkCount++` and a worse score. Tiny `deltaT` inflates jerk. AUTO.  
  **Resolution:** FIXED for accel/jerk (2026-10-08, G7 finish pass): `evaluateFix` recomputes acceleration and jerk from the clamped speeds, so a GPS spike no longer triggers hard-brake alerts or `highJerkCount`. Test: `calculators/fix_kinematics_test.dart`. The `deltaT` floor in `MotionCalculator` was reverted as out of plan (tiny-`deltaT` jerk inflation stays open, low value).
- **101.R6 MED — `navigation_progress.dart:185-195` `arrived` fires at the start of a loop route** (start within 40 m of end) and is not latched. AUTO.  
  **Resolution:** FIXED (2026-10-08): `arrived` needs progress along the route (>10%) and is latched via `previous.arrived`. Test: `navigation_progress_test.dart`.
- **101.R7 MED — `odometer_sync_sheet.dart:78-95`:** messenger used after `pop()`, no try/catch, baseline clamps to 0 when the entered reading is below tracked distance but the sheet says "synced". AUTO.  
  **Resolution:** FIXED (2026-10-08): `odometer_sync_sheet.dart` try/catch resets `_syncing`, no messenger after pop, `syncOdometer` returns the real odometer. Test: `maintenance/odometer_sync_sheet_test.dart`. The negative-baseline change was reverted as out of plan.
- **101.R8 MED — `maintenance_provider.dart:~155` `unawaited(outbox.enqueueMaintenanceLog(...))` has no handler.** AUTO.  
  **Resolution:** FIXED (2026-10-08, G7 finish pass): outbox enqueues in `maintenance_provider.dart` use `catchError` + `reportNonFatal`. Test: `maintenance/maintenance_outbox_failure_test.dart`.
- **101.R9 MED — tap targets under 48dp or no semantics:** `_UnitSegment` (~24dp), config edit pill (~26dp), `forecast_strip` (12x12 diamond), colour swatches, garage `minimumSize` 60x32, active-ride Talk button 40dp, all-rides sort chips 34dp, `VisualDensity.compact` in `record_screen.dart:217` and `maintenance_check_row.dart`. Extends §83.22. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): FIXED with semantics/48dp tests (`maintenance_a11y_test.dart`, `ride_sort_chips_semantics_test.dart`): `_UnitSegment` semantics, config edit pill 48dp, colour swatches semantics, all-rides sort chips semantics. NOT REAL: garage/active-ride/record Material button sizes (framework hit-test padding covers them). REAL-BUT-SKIP: `forecast_strip` diamond semantics, `_UnitSegment` visual growth to 48dp (layout change). Follow-up: swatch Auto tile reads 'Bike color' (needs a new EN/BN string).
- **101.R10 LOW (batch):** hard-coded 'Rider' and "km" in alerts and English `turnText`/`compassDirection`; wall-clock elapsed instead of `Stopwatch` and pause loses up to 1 s (`ride_recording_provider.dart:905,832`); no `isFinite` guard on `pos.speed`/`accuracy` (`:645`); all-time average speed is the unweighted mean of per-ride averages (`rider_stats.dart:77`); `addBike` forces the new bike active while the garage is loading (`garage_provider.dart:46-51`); add-custom dialog not scrollable and `forecast_strip` `left: x-40` can go negative; `ridePolylineProvider` reads all points per row. All AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): FIXED: NaN/Infinity guards on `pos.speed`/`accuracy`, pause elapsed no longer loses up to 1 s (`elapsed_at_pause.dart`), localized 'Rider' fallback, imperial alert text in `maintenance_alerts`, weighted all-time average speed in `rider_stats`, `addBike` reads the active bike from the DB, custom-interval dialog controllers/scroll, forecast-strip label clamp, polyline reads `getLatLngForRide`. Tests: `elapsed_at_pause_test`, `rider_stats_test`, `garage_provider_db_test`, `custom_check_dialog_test`, `forecast_strip_test`, `ride_point_dao_latlng_test`, `maintenance_alerts_test`. ALREADY FIXED: `turnText` (English kept on purpose for tests; UI uses l10n). REAL-BUT-SKIP: full `Stopwatch` migration of the recording clock (reverted as out of plan).

### 101.P Places, analytics, theme, i18n
- **101.P1 HIGH — white on lime.** `places_list_screen.dart:189-190` and `places_map_view.dart:301,372,381,417,461` use `Colors.white` on `palette.primary` (lime on Carbon, about 1.2:1). Use `AppTheme.primaryButtonForeground` or a luminance pick. AUTO.  
  **Resolution:** FIXED (2026-10-08): FABs, cluster text and pin icons use `primaryButtonForeground` / `markerIconColor` (>= 4.5:1 / 3:1). Tests: `places_hub_test.dart`, marker colour unit tests.
- **101.P2 HIGH — `textTertiary` fails WCAG AA in every palette** (light 2.5-3.3, dark 3.0-4.5), also `onInkMuted`, light `success`/`warning`, editorialLight `secondary`/`attention`. 11-12 px POI text uses it. The contrast test covers only the primary button. Darken tokens and extend the test. AUTO (final colours are a design call).  
  **Resolution:** REAL-BUT-SKIP (2026-10-08): darkening `textTertiary` and light `success`/`warning` changes the look of every screen; needs a design decision and a golden pass (founder).
- **101.P3 HIGH — `shared/widgets/app_tile_layer.dart:3,92` uses `dart:io`/`Platform.environment` at static init;** breaks on web. The hard-coded tile contact email needs confirmation. AUTO for the guard.  
  **Resolution:** NOT REAL (2026-10-08): `app/` has no `web/` target and `lib/` already has 33 other `dart:io` imports; the tile contact email is still worth confirming (founder).
- **101.P4 HIGH — analytics is on by default with no consent prompt,** and the native SDK collects before `init()` (no `firebase_analytics_collection_enabled=false` or `FIREBASE_ANALYTICS_COLLECTION_ENABLED=NO`). No PII is sent. Policy is a founder decision; the native default-off flags are AUTO.  
  **Resolution:** Founder decision (analytics consent). Not touched.
- **101.P5 MED — Overpass/Nominatim:** no User-Agent or timeout, `node` only (misses ways, no `out center`), English `displayName` fallback stored permanently in Firestore, no ODbL attribution; Nominatim no `Accept-Language`, no 1 req/s guard. AUTO (attribution wording founder).  
  **Resolution:** PARTLY FIXED (2026-10-08): Overpass now sends a User-Agent, connect/send/receive timeouts, and queries `nwr[...]` with `out center` (ways supported; ids stay `node/<id>`). Tests: `overpass_service_test.dart`. REAL-BUT-SKIP: English `displayName` fallback stored in Firestore, ODbL attribution on list/detail. NOT REAL: Nominatim (already has UA, timeouts, tap-only).
- **101.P6 MED:** `place_detail_screen.dart:173-179` `Image.network` with no loading or error placeholder and no `cacheWidth`; `currentPositionProvider` no `timeLimit`, cached forever; "within 5 km" label shown with no GPS fix; `searchPlacesByName` is case-sensitive, name only, no limit (check the `` sentinel is present); `getGeohashesForViewport` is a lossy 5x5 sample and looks unused. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): place banner `cacheWidth` + loading placeholder; `currentPositionProvider` has a 15 s `timeLimit` with last-known fallback. Tests: `place_detail_screen_test.dart`, `current_position_provider_test.dart`. NOT REAL: 'within 5 km' label (only shown after a fix). REAL-BUT-SKIP: case-sensitive `searchPlacesByName`, `getGeohashesForViewport` (no callers).
- **101.P7 LOW:** raw exception text in `couldNotOpenCamera(e)`; `primaryButtonForeground` for Retro hard-coded `0xFF1A1A1A`; `LocaleNotifier` has no try/catch on prefs; cluster key regroups at every whole zoom. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): `couldNotOpenCamera` no longer shows the raw exception (`reportNonFatal` instead; EN/BN). NOT REAL: Retro `primaryButtonForeground` (never reached), cluster regroup (intended). REAL-BUT-SKIP: `LocaleNotifier` prefs try/catch.
- **101.P8 INFO — l10n parity is clean:** EN and BN both 1,684 keys, no placeholder mismatches. `safeQrTitle` and `joinRideCodeHint` are identical in both and need a decision.

### 101.B Build, native, tests
- **101.B1 HIGH — `app/test/sync_manager_test.dart:9-152` is all empty stubs** (comment-only bodies, commented-out `expect`). CI shows coverage that asserts nothing. Replace with real tests (fake connectivity and repo) or delete. `mockito` may then be unused. AUTO.  
  **Resolution:** FIXED (2026-10-08): placebo `sync_manager_test.dart` deleted, replaced by `core/cloud/sync_manager_guard_test.dart` (real assertions).
- **101.B2 HIGH — no `PrivacyInfo.xcprivacy` in `app/ios/`** (Runner or widget extension). Apple requires required-reason API declarations. Founder (data types) plus Xcode target membership.
- **101.B3 HIGH — CI has no release build.** R8/proguard breakage only shows at release. Add `flutter build apk --release`. AUTO for Android; iOS needs a macOS runner and cost sign-off.  
  **Resolution:** REAL-BUT-SKIP (2026-10-08): a CI release build needs a signing story and adds minutes per push; the first attempt was reverted in the finish pass.
- **101.B4 MED — Play declarations** needed for `ACCESS_BACKGROUND_LOCATION`, `USE_FULL_SCREEN_INTENT` (restricted on Android 14), `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, and foreground-service types. Founder.
- **101.B5 MED — Android build:** `proguard-rules.pro` over-broad keeps (`java.util.**`, gms, firebase, `ChangeNotifier`) and a stale "minification is OFF" header; release signing silently empty when `key.properties` is missing; `targetSdk` follows Flutter, unpinned. Comment fix, signing error and pinning are AUTO; trimming keep rules needs a device run.  
  **Resolution:** PARTLY FIXED (2026-10-08): stale proguard header rewritten (minify ON since 2026-08-28); release builds now fail loudly when `key.properties` is missing (`-PallowUnsignedRelease=true` opts out; debug unaffected). REAL-BUT-SKIP: over-broad keep rules, `targetSdk` (follows Flutter; the downgrade to 35 was reverted).
- **101.B6 LOW — iOS:** `CFBundleDisplayName` is `Throttleiq`; check whether anything saves to the photo library (`NSPhotoLibraryAddUsageDescription`). AUTO.  
  **Resolution:** FIXED (2026-10-08): `CFBundleDisplayName` is `ThrottleIQ`; `NSPhotoLibraryAddUsageDescription` added (config only, no test).
- **101.B7 LOW — version `1.0.0-beta.4.3.0+24`** may be rejected as an App Store marketing version. Founder.
- **101.B8 MED — CI never runs `integration_test/`;** `ui_tour_test.dart` has no `expect`; no coverage step. 152 packages are held back by constraints (`geolocator ^11`, `flutter_local_notifications ^17`, `firebase_app_check ^0.3`, `google_sign_in ^6`, `flutter_lints ^3`). `analysis_options.yaml` has no strict modes. Coverage step, lints and low-risk bumps are AUTO; plugin bumps need a device.  
  **Resolution:** REAL-BUT-SKIP (2026-10-08): integration tests need a device, coverage has no consumer, held-back deps need a migration pass. HARMFUL-AS-SUGGESTED: strict-casts/inference/raw-types break the clean-analyze gate.

### 101.D Docs and repo hygiene
- **101.D1 HIGH (size) — about 709 MB tracked.** `DOCS/General/screenshots_ui/` holds ~170 MB of PDFs plus ~2,500 JPGs, with byte-identical "boxy" and "curvy" variants (134 duplicate-hash groups) and 50 files over 1 MB. Founder decision on LFS or external storage.
- **101.D2 stale docs:** todo F6 says the PRD is 51 lines (it is 324); PRD header says beta.4.2.0+23 and README says beta.4.1.0+22 (pubspec is beta.4.3.0+24); §83.19 says App Check is off (client activates it in `main.dart:34-36,78`; enforcement is still pending); `issues_open.md` has duplicate `## 79.`, FIXED stubs (§32, §64, §79, §82, §89) still in the open file, and a wrong "next free number". `issues_solved.md` and the `ANTIGRAVRITY_GRILL` folder (typo) are ambiguous. AUTO except renumbering.  
  **Resolution:** PARTLY FIXED (2026-10-08): README release version/tag, `needs_attention.md`, next free number (now §102), §83.19 App Check status, §64 heading, todo F6 re-scoped. NOT REAL: PRD version (matches the latest tag). REAL-BUT-SKIP: duplicate §79, ANTIGRAVRITY_GRILL folder/`issues_solved.md` (referenced from other docs). HARMFUL-AS-SUGGESTED: deleting FIXED pointer stubs (§32 carries a 'do not re-raise' instruction). ASD-STE100 check on the PRD not run.
- **101.D3 LOW — repo hygiene:** `SKILLS/SKILL*.md` are 5 copy-paste duplicates in a third skill location; duplicate `carbon-mono.png`; root `arch.md` and `new_gravity.md` should be folded in; `.gitignore` lacks `.claude/worktrees/`, `.claude/settings.local.json`, `.env*`, `*.jks`, `*.p12`, `google-services.json`. AUTO except the SKILL duplicates.  
  **Resolution:** PARTLY FIXED (2026-10-08): `.gitignore` gains `.claude/worktrees/`, `.env.*` (keeps `.env.example`), `*.p12` (test in hosting hygiene test). NOT REAL: `SKILLS/` duplicates (4 distinct skills), root `arch.md` (maintained). HARMFUL-AS-SUGGESTED: removing `carbon-mono.png` copy (website demo depends on it). REAL-BUT-SKIP: `new_gravity.md`. Note: `app/ios/Runner/GoogleService-Info.plist` is tracked and now matches an ignore rule.

---

## 102. Founder decisions of 2026-10-08 — BUILT in the working tree 2026-10-08 (not committed, not checked on a device)

> Built: archive flow with cleanup options, 90-day purge on app start, Garage tab rename, English-style Bangla
> dates. Details in `features.md` ("Changes from the bike-archive pass"). The paragraph below is the original
> decision. Still to check on a device: the share-sheet export, the purge, and the new Bangla strings (listed
> under `# batch: bike-archive` in `bn_pending_review.txt`).

Decided, no code written yet:

- **Deleting a bike archives it.** The delete dialog asks whether to also delete shared rides,
  calculated miles, service logs and photos (default: keep). After archiving, the rider is told the
  bike is permanently deleted after 3 months, with **Download a local copy** and **Delete now**.
  Needs an `archivedAt` field + migration (`bike_model`, `database_helper`). The 3-month purge runs
  on app start (Spark has no scheduled functions).
- **Profile tab is renamed "Garage"** (label, icon, EN/BN keys).
- **Bangla dates look like English dates** (`8 Oct 2026`) shown in the Bangla font — English month
  names, Western digits. Closes the §83.23 question.
- **Blocking (§83.18):** recommended, not yet confirmed: single-document rules only, document the
  feed-listing gap. **Cloudinary (§83.16):** recommended, not yet confirmed: dashboard lock-down
  only, no signing proxy. Both are in `DEBT_FIX_PLAN.md` §6/§7.
- **Pitch Slide 9 team details:** still waiting on the founder's names/roles.

**E2E:** `integration_test/e2e_test.dart` fails at launch with `[core/no-app] No Firebase App
'[DEFAULT]'` (via `groupRideLifecycleProvider`, `app.dart:209`) — the test never calls
`Firebase.initializeApp()`, so the Places/Saved/bottom-nav flow has not actually been exercised.

**GitHub security follow-ups (2026-10-08):** CI (`flutter`, `rules`, `functions`) is green on GitHub;
required-check branch protection is still to be set. Dependabot alerts #1 (`uuid`) and #2
(`@fastify/busboy`) are fixed locally in `functions/` (lockfile bump plus a `uuid` override in
`package.json`) but **not committed or pushed yet**. `.github/dependabot.yml` was invalid (empty
ecosystem) and is rewritten. CodeQL default setup fails for `java-kotlin` and `swift` (it cannot
autobuild a Flutter app): untick both in Settings → Code security. The template workflows
`swift.yml`, `android.yml`, `dart.yml` pulled from the remote will likely fail on this repo.

**Cloudinary preset lock-down — plan correction (2026-10-08):** do NOT lock a fixed folder on
`throttleiq_unsigned`. `CloudinaryUploadService` sends a per-upload `folder` (`avatars`,
`rideShares/$uid`, `<kind>/<uid>`) and the account-deletion sweep relies on the `<kind>/<uid>`
prefix. The one preset also serves the `image/upload` and `video/upload` (voice notes) endpoints,
so set: allowed formats for both (check whether iPhone photos arrive as HEIC), a single max file
size (~10 MB), overwrite off. The usage alert stays a console-only step. Applying it through the
Admin API is waiting on the numeric API key (`secret/.envclound.txt` holds only a 27-character
value that looks like the API secret).

**Cloudinary preset — current state (2026-10-08):** the `def` API key + `secret/.env.new` pair works
against the Admin API. `throttleiq_unsigned` already has `overwrite:false` and `use_filename:false`
but **no `allowed_formats` and no size limit**. Proposed `allowed_formats=jpg,jpeg,png,webp,heic,
heif,m4a,aac,mp3` (founder to apply via `PUT`, then verify one photo + one voice note upload; undo
by PUTting an empty `allowed_formats`). A size cap is probably account-level (console Settings →
Upload), unconfirmed. Usage alert is console-only.

**Cloudinary `allowed_formats` applied (2026-10-08):** `throttleiq_unsigned` now allows
`jpg,jpeg,png,webp,heic,heif,m4a,aac,mp3`. Verified with unsigned uploads: PNG accepted (image),
`.m4a` accepted (video resource, format `m4a`), `.txt` rejected ("Raw file format txt not allowed").
Two test assets sit in the `preset_test/` folder and can be deleted in the Media Library. Still open:
size cap (probably account-level) and the console usage alert; a real in-app photo + voice note
upload on a device has not been tried.

**§4 TTL attempt (2026-10-08):** creating the TTL policy on `liveSessions.expiresAt` in the Google
Cloud console fails with `403: Project throttleiqfb has billing disabled`. TTL needs Blaze, so it is
**blocked on Spark** like the other Blaze-only items. Fallbacks, not built yet: filter reads on
`expiresAt > now`, delete the rider's own expired `liveSessions` docs from the client, and clear old
string-timestamp docs by hand.

**CI cleanup (2026-10-08):** removed the GitHub starter workflows `android.yml`, `dart.yml` and
`swift.yml` (they failed on this Flutter repo and `ci.yml` already covers `flutter`, `rules`,
`functions`) and the `testtt.md` CI-trigger file. Not yet committed or pushed. `greetings.yml` and
`summary.yml` (AI issue summary) are kept but optional.

**E2E test status (2026-10-08, after the bike-archive pass):** `integration_test/e2e_test.dart` now
initialises Firebase in `setUpAll`, so the app launches and the test taps the Places tab. It then
**fails with `pumpAndSettle timed out`** (`e2e_test.dart:41`, the `pumpAndSettle()` right after the Places tap):
the Places hub keeps animating or loading and never settles on the simulator, so the Saved/Routes checks
are still never reached. Not caused by the archive/Garage/date changes as far as can be told (the tap
itself worked), but not proven either way. Likely fix: replace that `pumpAndSettle()` with a bounded
`pump(Duration)` loop or wait for `find.text('Saved')`.


---

## 102. Themes / analytics / badges / QR / tour pass — open follow-ups (2026-10-09)

**Status:** Code done in the working tree (not committed). `flutter analyze` clean, `flutter test` 2016/2016,
`functions` `tsc` build OK, `flutter build apk --debug` OK. Nothing deployed; nothing checked on a device;
`integration_test/e2e_test.dart` and `ui_tour_test.dart` not run (no simulator).

- **102.1 Badge rarity backend:** `throttleiqfb` is on the **Spark** plan, so Cloud Functions can't deploy
  (2026-10-09 deploy failed: Blaze required). Founder chose to stay on Spark; reworked to rules-guarded client
  counters on `stats/badges` (no functions). **Needs `firestore:rules` deploy** (also carries the fuelLogs rules). Also: the standalone `/usr/local/bin/firebase` binary's
  bundled npm 8 crashes in predeploy (`reading 'stdin'`); use `npx firebase-tools@15` instead. `totalRiders` counts all accounts (including
  riders with no rides), and clients can still self-award `earnedBadges` docs (existing rules gap), which skews counts.
- **102.2 (DONE 2026-10-09)** blankframe.tech (GitHub Pages, repo `blankframe-tech/landing-page`, commit `824920e`) now
  serves `/.well-known/assetlinks.json` (verified via Google's Digital Asset Links API), `/throttle-iq/install/`,
  and a root `404.html` that routes `/ThrottleIQ/install` and `/ThrottleIQ/u/<uid>` in any casing. QR links
  now use `www.blankframe.tech` (the bare domain 301s, which can't verify). Old notes: the site must serve `/.well-known/assetlinks.json`,
  `/.well-known/apple-app-site-association` (application/json, no redirect) and `/ThrottleIQ/u/*` (copy from
  `public/` or proxy to Firebase Hosting). Add Play App Signing SHA-256 to `assetlinks.json` if used. Then `firebase deploy --only hosting`.
  **iOS Universal Links are off (2026-10-09):** team `NJ4675FFUX` is a personal team, which Apple never allows
  Associated Domains, so the entitlement was removed from `Runner.entitlements` (it broke signing). iPhone camera
  scans open the web page, whose "Open in ThrottleIQ" button uses `throttleiq://u/<uid>`. Re-add on a paid team.
- **102.3 QR gaps:** no deferred deep link (after installing, the rider must re-scan); a well-formed uid for a
  non-existent rider still writes a harmless follow doc (rules make missing and private look the same); QR
  buttons only on `/profile`, not the Garage tab header; the saved QR PNG keeps the colors of first render.
- **102.4 Widgets:** theme-following widgets unverified on device; widgets don't follow the shape vibe.
  (Rounded button/DUE chip corners restored 2026-10-09, commit `1806399`.)
- **102.5 (DONE 2026-10-09)** Lean, g, elevation and fuel charts built (schema v26/v27). Remaining: lean/g are GPS
  estimates; legacy rides get elevation only; the bike odometer isn't advanced by a higher fill-up reading; fuel
  units (L, km/L) untranslated; no tour slide for fuel; `stats/badges` counters never decrement and can be
  inflated by throwaway accounts or self-awarded badges.
- **102.6 Tour:** card tour + "Show me" rather than real-widget coach marks; no floating banner on `/profile`.
  `.agents/skills/onboarding-guardian/SKILL.md` was updated to accept the v4 step list.
- **102.7 Bangla review — deferred to November 2026 (founder, 2026-10-09):** new keys for themes, analytics, badge rarity, follow-QR and tour v4 are machine-drafted;
  listed in `app/lib/l10n/bn_pending_review.txt`.
- **102.8 Diff noise:** a `dart format` run may have reflowed `all_rides_screen.dart` and `badge_grid.dart` beyond their real edits.
