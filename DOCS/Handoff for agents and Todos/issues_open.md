# Issues: open

_Was `Issues.md` until 2026-09-19. Resolved sections moved to `issues_fixed.md`._
Every issue that's still unresolved, in its original numbered section.
Section numbers (`§N`) never change. When something here gets fixed, move
its section or subsection to `issues_fixed.md` and keep the number.

New issues go at the end of this file with the next free number: **§72**.

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

---

## 13. QA report

**Status:** Not started.

_No QA pass has been written up yet. When one is done (manual smoke test,
device walkthrough, or a scripted run), record findings here as dated
sub-sections — one per pass — rather than overwriting this placeholder._

---

---

## 32. UI/UX critique of the current screen set — surfaced, not fixed (2026-08-17)

**Status:** Not started. Design/polish findings, not root-caused bugs — no
code changed. Full writeup with screenshot references in
`docs/uiux_critique.md`; summarized here per this file's convention of one
`##` per tracked problem.

Reviewed the 40-screen `screenshots/carbon_mono/` walkthrough end to end.
Most findings are subjective design critique (see the doc), but a few are
concrete defects worth tracking as real issues:

- **Paused-ride screen dims the stat card, not just the map**
  (`06_ride_paused.png`) — speed/distance/brake-accel numbers fade to
  near-illegible grey-on-black under the pause scrim, on the one screen
  meant to be glanced at mid-ride.
- **Places list FAB overlaps the last list row** (`23_places_nearby.png`) —
  "+ Add place" has no reserved bottom padding and sits on top of content.
- **Zero-review places render as `★ —`** (`23_places_nearby.png`) instead of
  "No ratings yet" — reads as a rendering bug, not an empty state.
- **Ride summary shows the riding score twice** (`08_ride_summary.png`) — a
  `100 / SMOOTH OP.` card and an adjacent `RIDING SCORE / Smooth op. / out of
  100` card duplicate the same value.
- **Maintenance status pill doesn't escalate before 0 km left**
  (`21_maintenance_service_checks.png`) — a part at ~13% of its interval
  remaining shows the same green "OK" as one at 99% remaining, which defeats
  the point of an early-warning indicator.
- **Emergency Contacts is exposed in Settings while explicitly non-functional**
  (`38_settings.png`) — copy states alerts "aren't live yet"; a safety
  feature presented as available but inert risks a false sense of security.

The rest (dead space on Home/`03_home_record.png`, busy live-ride map
styling, unlabeled chart axes, theme-picker list without live previews,
low-contrast secondary text, slide-to-start friction on the primary CTA) are
polish/opinion calls — see `docs/uiux_critique.md` for the full list and
reasoning. None of this has been triaged into actual work items yet.

---

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
- Theming (`theme_style_provider.dart:179-183`) pushes appearance into
  mutable static facades (`AppColors`/`AppDimensions`/`AppTypography`,
  ~565 call sites per the codebase's own comment) and force-remounts the
  entire app subtree on every appearance change, destroying transient
  navigation/scroll state each time.
- `isAdmin` is hardcoded to one email client-side
  (`forum_permissions.dart:5,10-11`) and manually mirrored in
  `firestore.rules:87-91` — not currently spoofable, but the two can drift
  silently since nothing ties them together.
- `scripts/seed_police_checkposts.js`/`_v2.js`/`_v3.js` reimplement the
  same geohash-encoder/dry-run scaffolding three times (~500 lines) for
  what should be one shared module plus data files.

---

## 64. User report: chat/messaging shows `permission-denied` everywhere — stale/undeployed rules, same pattern as §47 — FIXED (2026-09-11) (open parts)

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

- **69.O1 🔴 Privacy policy contradicted the app on the microphone.**
  `public/privacy.html` §1 said "no microphone", but group-ride push-to-talk
  records audio (`RECORD_AUDIO`, `record` package), uploads it to
  Cloudinary and shares it with ride members. The page text is corrected in
  this pass (voice clips added to §1, §4 and §5), **but it isn't deployed**.
  The Play Data Safety answers need "Audio → Voice or sound recordings:
  collected, shared" too. `store_listing/data_safety_and_permissions.md`
  is updated to match. Voice-note Cloudinary URLs are public to anyone who
  has the URL.
- **69.O2 Account-deletion scope** (see 69.8): decide whether authored
  community content gets anonymized or deleted, and cover Cloudinary assets
  (ride photos, avatars, voice clips). None of those are deleted today.
- **69.O3 Crash alerts can't be cancelled server-side.** Once the countdown
  expires and a `crashNotifications` doc is written, "I'm OK" only resets
  local state. `firestore.rules` gives the client no update on that
  collection, so escalation would still fire. Delivery is a mock today, so
  this is latent, but it has to be solved before real SMS ships.
- **69.O4 Outbox has no poison-pill limit.** A write that rules reject
  (e.g. 69.1, or a share queued by user A and drained while user B is
  signed in) retries forever at the 30-min backoff cap. Consider discarding
  `permission-denied` after N attempts and surfacing it to the rider.
- **69.O5 Localization coverage.** 39 screens import no `AppLocalizations`
  at all, including login/register/onboarding, the active-ride screen,
  garage, maintenance, the whole social feed and forums. The EN/BN
  positioning only really holds for the screens that are localized.
- **69.O6 Cloud Functions runtime.** `firebase.json`/`package.json` pin
  Node 20, which Google has deprecated for Cloud Functions (decommission is
  scheduled for late Oct 2026). `firebase-functions` is `^4.8` (current
  major is 6+). Upgrade before the next functions deploy.
- **69.O7 `firebase_messaging` is declared but unused**, per the Data
  Safety doc. Remove it, or wire it up.
- **69.O8 `USE_FULL_SCREEN_INTENT`** (crash alert). Since Android 14, Play
  restricts full-screen intents to calling/alarm apps unless a declaration
  is approved. Needs a Play Console declaration or a fallback.
- **69.O9 Stale index:** `firestore.indexes.json` has
  `liveSessions(userId, expiresAt)`, but live sessions store the owner as
  `uid` and nothing queries that shape.
- **69.O10 `crash`-status rides never sync.** `_onCrashDetected` writes
  `status: 'crash'`, and `RideDao.getUnsynced` only uploads `completed`. A
  ride that's killed while in the crash state stays local-only.
- **69.O11 Corrupt-DB recovery deletes the DB outright**
  (`DatabaseHelper._initDb`). Unsynced rides are lost. Renaming the file to
  a `.corrupt` backup first would keep them recoverable.
- **69.O12 `SharedRideEntity.props` omits most fields**, including the new
  score counts, `distanceKm` and `polyline`. Equatable equality won't
  notice changes to them.
- **69.O13 Docs reorganization loose ends:** code comments still cite
  `docs/Issues.md §N` / `docs/planning/…` (now
  `DOCS/Handoff for agents and Todos/…`). `DOCS/For Devs and Contributers`
  is misspelled ("Contributors"). A few design assets deleted from
  `designs/` (logo concepts `logos1/*`, `logo_preview_demo.html`, the
  Facebook profile mockup, `docs/new/*` reference images) weren't carried
  into `DOCS/`. Presumably intentional; they're still in git history.
- **69.O15 Lockfiles are gitignored.** `.gitignore`'s `*.lock` excludes
  `app/pubspec.lock` and `app/ios/Podfile.lock`. For an app (not a
  library), both should be committed so every build resolves the same
  dependency versions.
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

- `firebase deploy --only firestore:rules` — 69.1, 69.2.
- `firebase deploy --only functions` — 69.8, 69.9, 69.10 (and
  `onUserAccountDeleted` itself has never been deployed, per its own doc
  comment). Consider doing 69.O6 first.
- `firebase deploy --only hosting` — 69.O1's privacy-page correction.
