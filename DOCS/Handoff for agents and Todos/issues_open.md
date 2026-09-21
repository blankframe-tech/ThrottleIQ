# Issues: open

_Was `Issues.md` until 2026-09-19. Resolved sections moved to `issues_fixed.md`._
Every issue that's still unresolved, in its original numbered section.
Section numbers (`§N`) never change. When something here gets fixed, move
its section or subsection to `issues_fixed.md` and keep the number.

New issues go at the end of this file with the next free number: **§85**. (§78 sub-items run to 78.30; §83 to 83.31. Note §79 and §81 are each used twice, and §82 was taken before §83 — check BOTH this file and `issues_fixed.md` before claiming a number.)

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

## 74. Retro / Light: some cards render near-black on the light page (surfaced 2026-09-19)

Seen in the UI screenshot set (`DOCS/General/screenshots_ui/21_retro_curvy_light`
and `23_retro_boxy_light`). A few surfaces are near-black blocks on Retro's
light cream background, with low-contrast text inside:
- the "Your bikes" forum cards on Social → Forums
- the Places list rows
- My Places rows
- the forum post card

Other color modes in Light don't do this. It is probably a Retro-light palette token (a
`surfaceVariant`/`ink`-style color used as a card fill) rather than a
per-screen bug. It needs a design decision: intentional "ink block" styling,
or a token to lighten. Not changed.

## 78. Antigravity grill verification: still open (surfaced 2026-09-20)

The full verdicts and fix instructions are in
`ANTIGRAVRITY_GRILL/claude_sol.md`. Most §78 items were **fixed on 2026-09-20** and are
now on `main` (e351b6c), though not deployed and not device-tested. That work is written up in `issues_fixed.md` §78, which also
lists what still needs a device check.

What remains open:

- **78.1 Crash detection is built but switched off.**
  `SensorConstants.impactDetectorLiveEnabled = false`. Turning it on needs
  two things:
  - the founder's choice of alert delivery (`DOCS/needs_attention.md` b);
  - field rides plus a padded drop test to calibrate the thresholds
    (claude_sol §1.1.1 step 6).
- **78.12 Gyro heading sign and axis** (`vehicle_state_estimator.dart`).
  This needs a mounted phone to verify, so it wasn't attempted.
- **78.16 Tile provider not chosen.** The shared cached tile layer is in
  place. Release builds still hit `tile.openstreetmap.org` until `TILE_*`
  defines point at a provider.
- **78.18 The keystore has no backup** (founder action). CI now exists but
  hasn't run on GitHub, and there's no branch protection yet.
- **78.21 Route navigation doesn't record the ride.** Not attempted; it
  needs a design call on merging nav into the active-ride cockpit.
- **78.24 SafeQR has no "Print sticker"** (needs the `printing` package).
- **78.25 The pitch** (`iDEA_PITCH_SUBMISSION.md` Slide 9, lines
  36/76/107) still claims working crash detection and a team the repo
  history doesn't show. It waits on founder decision c. The in-app
  emergency-contacts copy is fixed.
- **New from the fix pass:**
  - **78.26** `HoldToStartButton` completes a hold if the press and
    release land in the same frame. The new `HoldToEndButton` guards
    against this.
  - **78.27** The chat-create rule now requires the fixed DM id. Builds
    from before the fix can't start new chats once the rules are deployed.
    Ship the app before the rules.
  - **78.28** New Bangla strings (emergency banner and acknowledgement,
    SafeQR share, moving/stopped) need a native-speaker review.
  - **78.29** The new "Sync issues" screen isn't localized. The
    immediate outbox attempt (`_attemptOne`) isn't scoped to the signed-in
    rider.
  - **78.30** Crash rides now show in history lists, but without a
    "crash" badge.

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
- This is on `throttleiqfb`, the same project real beta testers use, so
  the comments are visible to them.
- Fabricated engagement on a founder post shouldn't be used as evidence of
  traction in the pitch or store listing. See §72 for the earlier
  marketing-overclaim pass.

---

## 80. Retired `likes`: 97 QA-seed rides still carry a dead `likes` number (2026-09-20)

**Code and the real data: DONE** — see `issues_fixed.md` §80.

**What's left:** a sweep of the feed found **no like documents anywhere**,
but 97 shared rides still carry a `likes` integer on the ride doc. All 97
are `qashare_*` QA seed rides whose counts were fabricated by
`seed_qa_test_riders.js`; that script no longer writes the field. Nothing
reads it, so this is cosmetic — clear it on the next reseed, or with a
`FieldValue.delete()` sweep.

`firestore.rules` still has its `likes` clauses (the create rule defaults
the field to 0, so it keeps passing). Drop them on the next rules pass.

---

## 82. User report: Places category chips (Fuel/Garage/etc.) fail with "Something went wrong, try again" — "All" works — FIXED (2026-09-20)

> Full writeup in `issues_fixed.md` §82.

---

## 83. Full-app critique pass (UI/UX, codebase, architecture, flow) — open parts (surfaced 2026-09-20, mostly fixed 2026-09-21)

**Most of this section is resolved — see `issues_fixed.md` §83** for the 20+
sub-items fixed on 2026-09-21 (safety claims, EventDetector, feed pagination,
account deletion, privacy salt, error states, comment rot). Full original
writeup: `ANTIGRAVITY_GRILL/Claude_CRTITISIZE.md`.

**Where the fixed work lives:** merged to `main` and pushed 2026-09-21
(`b32165e..49c6b0e`). Firestore **rules and indexes are deployed and
verified**; **functions are not** — still blocked on Blaze, which is why the
Cloudinary deletion sweep and the account-deletion anonymization in §83.15 do
not run yet. See `HANDOFF_Document.md` for the verification detail.

What is still open:

### 81.9 (part) — `AppColors` is a mutable static facade

The user-visible half is fixed: the app now follows the OS light/dark setting
(`AppBrightnessMode.system`). The underlying problem is not:

- **1,532** `AppColors.*` reads vs **10** `Theme.of(context)`, so ~99% of the
  app's colour decisions happen outside Flutter's element dependency graph.
- Nothing subscribes, so `app.dart` carries `key: ValueKey(appearance)` on
  `MaterialApp.router` — **changing the theme unmounts and remounts the whole
  app**, destroying every `State`: scroll offsets, map camera, half-typed
  forms, open sheets, `AnimationController`s.
- `const` is unusable at all 1,532 sites; static palette state leaks between
  widget tests; goldens are impractical across the 28 appearance combinations
  (7 colours × 2 brightnesses × 2 shapes), and there are 0 in the repo.

**Fix:** `ThemeExtension<AppPalette>` read via `Theme.of(context)`. Mechanical
but large, and it grows with every new call site. This is the single biggest
piece of debt left in the app.

### 81.12 — the active-ride screen rebuilds in full, once per second

`.select(` appears **3** times in the whole app; 4 sites watch the entire
21-field `RideRecordingState`. The 877-line `active_ride_screen` is one of
them, so it rebuilds completely on every elapsed tick and every GPS fix — with
the map, GPS at 1 Hz, IMU at 20-50 Hz and a foreground service all running.
That is battery and thermal cost in exactly the state where battery matters
most. The `polylineVersion` counter shows the author knew about selector
granularity; it just never reached the rest of the object.

### 81.13 — DI is inconsistent with the "clean architecture" claim

`RideRecordingNotifier` news up its DAOs, calculators and all four
coordinators as `final` fields; `maintenance_provider.dart:16` is a file-level
`final _dao = MaintenanceDao()`; `FirebaseFirestore.instance` is referenced
directly in 20 places and `FirebaseAuth.instance` in 9. `CrashCoordinator`
accepts an injected Firestore — so the pattern was known — and the notifier
that owns it calls the no-arg constructor anyway. **This is the same root
cause as 81.28:** nothing that touches I/O is injectable, so nothing that
touches I/O is tested.

### 81.14 — 53 bare `catch (_)` blocks

11 with empty bodies. Many carry a justifying comment and several are
legitimate, but in a Crashlytics-instrumented app this is 53 failure modes
that will never reach the dashboard and will be reported as "it just didn't
work."

### 81.16 (part) — the Cloudinary preset is still an open upload endpoint

Deletion is fixed (§83.15). The upload path is not: cloud name + unsigned
preset are in the APK, so anyone can POST arbitrary image/video/audio to the
account with no auth, rate limit, size cap or moderation. Needs a signed
server-side upload proxy, which needs the Blaze plan. Group-ride push-to-talk
voice notes therefore still live at permanent public URLs.

### 81.18 — blocking is a client-side filter

`visibleFeedProvider` removes blocked riders *after* downloading them, so a
blocked user's content still reaches the victim's device on every refresh, and
nothing stops a blocked user reading the blocker's public content. Wants a
server-side edge, not a `.where()`.

### 81.19 (part) — App Check is not enabled

Crash notifications are idempotent now, but rules cannot bound request volume;
any signed-in client can still drive function invocations. App Check is the
control, and it is not set up on this project.

### 81.22 (part) — accessibility is a stopgap

27 icon-only buttons got tooltips and text scaling is clamped to 1.0-1.3×, but:
**0** `semanticLabel`s outside those, 5 `Semantics(` widgets in 259 files, and
the clamp exists *because* the layouts overflow above ~1.3× rather than
reflowing. The fixed-height cockpit rows, chips and stat tiles need to be made
scale-tolerant so the clamp can be raised or dropped. For an app read outdoors
in sunlight through gloves this is legibility work, not a minority feature.

### 81.23 (part) — localization is ~a quarter done, and the Bangla needs review

Fixed: the four cockpit safety alerts and the live-share sheet. Still
English-only: **the entire onboarding flow** (7 slides, 21 callouts — the
highest-stakes surface, where a Bangla-first rider decides if this app is for
them), the rest of the cockpit, ride summary, stats, garage, maintenance,
forums, chat and places. 20 of 259 files use `AppLocalizations`.
**The Bangla added on 2026-09-21 was written without a native speaker and
needs review**, same as §78.28.

### 81.25 — information architecture (decided: leave as-is for now)

The garage is not in the bottom nav — it is a section of the Profile tab, with
maintenance one level below that — while the POI directory gets a top-level
tab. `_nonTabShellRoutes` exists solely to stop `/home/maintenance`
highlighting the wrong tab. 30 of 42 routes are full-screen with no shell, and
"My places"/"My shared rides" hang off the garage header's user menu.
**Product decision 2026-09-20: leave the nav alone** — no relearning for
existing beta testers. Recorded here because the IA cost is real, not because
work is pending.

### 81.26 — `onboarding_ui_mockups.dart` is a 1,162-line hand-drawn copy of real screens

The fabricated readouts are fixed (§83.1), but the structural problem stands:
the third-largest file in the app is an illustration of screens it cannot stay
in sync with, shipping in the production binary. `integration_test/ui_tour_test.dart`
already exists and could supply real screenshots.

### 81.27 — no analytics of any kind

Zero `logEvent`. Defensible as a privacy stance (and stated as one in the
README), but it means nothing would ever have surfaced the empty "Following"
feed or the buried maintenance flow. A privacy-respecting app can still count
screen views.

### 81.28 — 43 screens, 1 screen test, 0 goldens

18 files `pumpWidget` at all. The 1,195 passing tests cover the pure
calculators exhaustively and the presentation layer essentially not at all —
which is where every UX defect in this section lived. Same root cause as
81.13.

### 81.31 — triage, not more critique

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

**Status:** Surfaced, not acted on. Found during the §83 rules/indexes deploy,
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
