# Issues: fixed

_Split out of `Issues.md` on 2026-09-19._ Every resolved issue, in its
original numbered section: a bug found and fixed, a feature shipped, or a
report investigated and closed. Section numbers (`§N`) never change, so a
`docs/Issues.md §N` citation in code or an older doc means §N here or in
`issues_open.md`.

Where only part of a section is resolved, the still-open parts are in
`issues_open.md` under the same number, and a note here points to them.

---

## Lane G: contributor-issue bugs (GitHub #57, #59, #41, #40, #42) — FIXED (2026-10-29, branch `lane/g-bugs`)

- **#57 / §101.R5 Jerk spiked on GPS fixes milliseconds apart (`448bc8e6`).** `MotionCalculator` only guarded `deltaT <= 0`. It now skips acceleration and jerk under the same 0.1 s floor `evaluateFix` uses; distance is still reported. *Test:* `app/test/calculators/motion_calculator_test.dart`.
- **#59 / §95.12 Maintenance day counts went stale past midnight (`fdbeebdf`).** New `maintenanceTodayProvider` holds today's date; the forecast provider and `MaintenanceScreen` watch it, and the screen moves it on with a midnight timer and on app resume. Clock injectable. *Test:* `app/test/features/maintenance/maintenance_screen_test.dart`.
- **#41 / §95.12 Deleting a visit left its receipt photo on disk (`167ed9f6`).** `MaintenanceDao.delete` and `deleteWithTombstone` delete the receipt file once no remaining log references it (a visit's items share one receipt); remote URLs and missing files are skipped. *Test:* `app/test/features/maintenance/maintenance_visits_db_test.dart` (temp dir).
- **#40 / §101.R2 No warning for an odometer below an earlier log (`77d457e7`).** `odometerBelowEarlierLog` (`service_visit.dart`) drives non-blocking helper text under the odometer field of `AddMaintenanceLogScreen`; saving still works (odometers get replaced). New key EN + BN, BN queued in `bn_pending_review.txt`. *Test:* `service_visit_test.dart`, `maintenance_screen_test.dart`.
- **#42 / §101.P2 White text on dark `danger` was ~3:1.** New `AppTheme.dangerForeground` (dark: `surface`, light: white, unchanged) is Material's `onError`; the notification badge count and the report submit button (label and spinner) use `colorScheme.onError`. Danger-filled snackbars are still open (§101.P2). *Test:* `palette_contrast_test.dart` checks the pair in both themes.

---

## 120. CI was red on `main`: two `deploy.sh` staging tests failed — FIXED (2026-10-29)

`5cb5879a` changed the staging step in `scripts/deploy.sh` from `git add -u` to `git add app/pubspec.yaml`, but `scripts/test/hosting_repo_hygiene.test.js` still looked for `git add -u`, so two tests failed with `staging block not found` and the `rules` CI job was red on every push and PR (#26 was merged with `--admin` for this reason). *Fix:* `stagingBlock()` now ends at the `git add app/pubspec.yaml` block and the scratch repo uses `app/pubspec.yaml`; `deploy.sh` unchanged. Added a test that the block aborts when a tracked file other than `app/pubspec.yaml` is dirty. *Test:* `npm test` in `scripts/`: 96/96 pass. GitHub issue #27.

---

## 119. Play Console flagged the deprecated SafetyNet SDK — FIXED (2026-10-28, uncommitted)

Play Console SDK note (8 Oct, on build 21; every later build too): `play-services-safetynet:18.0.0` is deprecated. *Cause:* `firebase_app_check` 0.3.2+10 always bundled `firebase-appcheck-safetynet:16.1.2`, even though the app only ever used Play Integrity (`lib/main.dart`). *Fix:* moved every Firebase plugin up exactly one major version, to the `firebase_core` 4.x / Android BoM 34 line, which drops SafetyNet: core 4.15.2, auth 6.7.1, cloud_firestore 6.10.2, crashlytics 5.4.1, database 12.6.1, analytics 12.6.1, app_check 0.4.9, and dev deps fake_cloud_firestore 4.4.0 (4.1.1 can't compile against cloud_firestore 6.10's generic `WriteBatch.update`) and firebase_core_platform_interface ^8.0.0. *Trap:* keep the dev pin on platform interface 8.x. With `^7`, pub picks mid-line releases (e.g. cloud_firestore 6.7.0, auth 6.5.5) that extend `FirebasePlugin`, a class that only exists in platform interface 8.x even though their pubspecs allow 7.1.0. `flutter analyze` stays clean, but every test fails to compile. `google_sign_in` stays on 6.x. `_activateAppCheck` moves to the new `providerAndroid` / `providerApple` provider classes (same providers as before). We skipped the 5.x line (iOS SDK 13, minSdk 24) on purpose. Not yet checked on a device: sign-in, App Check token, Firestore sync, and a crash report on a real build. The Play note clears once a build with this change is uploaded.

---

## 118. A GPS position jump at ride start showed as a 133 km/h max — FIXED (2026-10-28)

Reported by the owner: ride `ddca6271…` (28 Oct, 3.40 km, iPhone) showed a 133 km/h max. *Cause:* at ride start the phone repeated a cached position (two idle fixes 9 s apart, identical coordinates); the first fresh fix landed 50.6 m away 1.368 s later with no Doppler speed. `evaluateFix` derived 37.0 m/s = 133.2 km/h, under the 252 km/h ceiling and inside the 25 m accuracy gate, and skipped the 1.2 g acceleration limit because the previous speed was 0 (`prev.speedMs > 0` exemption, since §90). The same jump added ~50 m and, before IMU calibration, one rapid accel, one hard brake and three high-jerk events from the GPS path. *Fix:* in `fix_kinematics.dart`, a derived (non-Doppler) speed the bike can't reach from the previous fix at 1.2 g is a position jump: no speed, no distance, flagged `clamped` so the next fix measures from the new position and is let through (two agreeing fixes are motion, so a fast rider without Doppler loses one fix, not the ride). Doppler fixes are unchanged. *Test:* `test/calculators/fix_kinematics_test.dart` replays the ride's real points, plus the next-fix and pull-away cases. *Data:* the owner's ride was corrected on the phone (max 33.1 km/h, 3,346 m, avg 14.1 km/h, hard brakes 1, rapid accel 0, high jerk 0) and marked for re-upload; backup of the pre-fix DB kept outside the repo. Other riders' past rides are not recomputed. Ships in +34.

---

## 117. SafeQR medical info was wiped by every reinstall — FIXED (2026-10-28)

Reported by the owner. *Cause:* `medical_info_provider.dart` kept the card in SharedPreferences only (deliberate, to keep medical data off the server), and the manifest has `android:allowBackup="false"`, so an uninstall deleted it on both platforms. *Fix (owner chose cloud sync):* the card lives in `users/{uid}/private/medical` (already owner-only in `firestore.rules`; account erasure already deletes `users/{uid}` recursively, so no rules or functions change). A pre-sync local copy is moved up once and then removed from prefs; an existing cloud copy wins; offline with no cache shows the local copy and keeps it for the next launch. `SafeQrScreen` fills its fields when the read lands, unless the rider has started typing. The in-app disclaimer (`safeQrLocalOnlyDisclaimer`, EN + BN, BN queued in `bn_pending_review.txt`) and `public/privacy.html` (new SafeQR row, effective 28 Oct 2026) now say it is stored in the rider's account; `data_safety_review.DRAFT.md` now marks Health info as collected. *Test:* `app/test/features/profile/medical_info_provider_test.dart` (round trip, one-time copy-up, cloud wins, no uid). Not checked on a device with a real reinstall. Ships in the +33 AAB.

---

## 116. Windows clones lose a file, so PRs delete it — FIXED (2026-10-28, uncommitted)

PR #26 (outside contributor, Windows) deleted `DOCS/General/CRASH TESTING/...minutes:seconds after the crash.jpeg`: Windows can't check out a `:` filename, so git sees it as deleted. Renamed to `minutes-seconds` (only bad path in the repo, nothing linked it). `scripts/check.sh` now has `guard: Windows-safe paths`, which fails on `<>:"|?*\`, trailing dot/space and reserved names (`CON`, `NUL`, …) in tracked files, so CI blocks a repeat. PR #26 still needs the deletion dropped (rebase), the BOM on `PRD.md` line 1 removed, and open item 3's first sentence cut before merge.

## 115. Critique of 2026-10-27 — FIXED (2026-10-27)

Write-up: `DOCS/critic oct27.md`. Four lanes merged into `main` (`c3f9072c`, `5cb5879a`, `00e63e5a`, `7822003a`). Leftovers are in `issues_open.md` §115.
- **Rules (#1, #2, #3, #8, #9, #18; `7822003a`, tests `scripts/test/rules/critic_oct27_rules.test.js`):** vote, comment, reply, post and forum-follow writes and deletes must move their parent counter in the same commit; bike/topic forums can't carry `createdBy`/`maintainerIds` (only `c-` custom ones) and accept only the app's keys; a blocked rider can't vote or comment on the blocker's rides; shared rides accept only `RideShareModel` keys with allow-listed photo URLs and caps; `username` must match `usernameLower`, `bio` capped; crash alerts use `{rideId}_{epochMs}` (bare rideId still accepted for build 29). Found on the way: following a forum always failed (the read of the not-yet-existing `forum_follows` doc was denied); fixed. `deleteSharedRide` now deletes the ride first, then its comments. Edit Profile bio capped at 160.
- **Data path (#4, #5, #6, #7, #12, #15; `00e63e5a`):** `rideWindows` treats only the active ride as open-ended and `downloadRides` skips unfinished rides; remote ride/bike deletes list children from the server only; sync after `stopRide` and on resume (`SyncManager.syncOnResume`, 30 s throttle); Edit Bike writes only the edited columns; restored rides keep their safety-event counts (`ride_event_counts` pref); a bike with a missing photo file clears its local path instead of re-uploading every cycle.
- **App and tooling (#3 client, #11, #13, #14, #17, #20; `5cb5879a`):** blocked riders' comments, replies and posts are hidden; forum vote hydration skips 0/0 posts; the People tab's following list stays cached 10 min; Discover returns 20 routes; `deploy.sh` commits only `app/pubspec.yaml` and tags `HEAD`; dead place/route methods, a fake test, `scripts/publish_release.sh`, `collection` and `cupertino_icons` removed.
- **Account erasure (#16; `c3f9072c`):** also deletes notifications the rider sent, votes (with counter decrement), anonymises voice notes, moves reviews to new ids, and clears `creatorName` and `members/{uid}` on rides they created. Two new collection-group index overrides (`notifications.fromUid`, `voiceNotes.senderId`). Not deployed (Spark).
- **Follow-ups (2026-10-28):** shared-ride and public-route polylines thinned to ≤ 1,000 points after the privacy clip (`23d7e7cb`); vote docs carry `uid`, rules `voteDocValid`, `votes.uid` index, backfill `scripts/oneoff/backfill_vote_uid.js`, erasure queries by `uid` (`7a3b2add`); `GarageNotifier.syncOdometer` baselines against the stored row, not the cached list (`c4243606`); `fake_cloud_firestore` dev dependency and tests for remote deletes, public routes, crash-alert ids, the ride-comment block filter and the sync after `stopRide` (`cfb77b1f`, `2cc689c4`).

## 1. API leak — GitHub secret-scanning alert (Firebase Web API key)

**Status:** Resolved / false positive — recommendation given, not yet marked closed on GitHub.

GitHub's secret scanning flagged the Firebase Web API key in
`public/live-viewer.html` (introduced via commit `b3b149a`):

```
public/live-viewer.html
    const FALLBACK_CONFIG = {
      apiKey: "AIzaSyAP16m8JzeIisHX1Wb0ImLGAu7AAHM4b-I",
      authDomain: "throttleiqfb.firebaseapp.com",
      projectId: "throttleiqfb",
      storageBucket: "throttleiqfb.firebasestorage.app",
      ...
    };
```

### Can this API key be used to do anything harmful?

Realistically, not much beyond what the app already lets any visitor do —
but there are a couple of real, low-severity risks worth knowing about.

**What it can't do:**
- It can't bypass Firestore rules or Storage rules. Firestore is
  owner-gated per collection (rides, bikes, maintenance, etc., with the
  audience-based sharing logic), and Storage (`storage.rules`) is
  auth-gated with owner-only writes. The key alone doesn't grant a token;
  someone would still need a valid signed-in `request.auth.uid` to
  read/write anything, and even then they're bound by the same rules
  every real user is.
- It can't read other users' private data. Public rides, public profile
  fields, and forums are already meant to be visible to any authenticated
  user by design — that's not a new exposure.

**What it realistically enables:**
- Someone could hit the Firebase Auth REST API directly with this key to
  script things the app's UI already allows anyone to do — sign up fake
  accounts, or trigger password-reset/email-verification emails to
  arbitrary addresses. That's more of a spam/cost nuisance (email quota,
  "denial of wallet" on usage-based billing) than a data breach.
- If any *other* Google Cloud APIs (Maps, Places, etc.) are enabled and
  left unrestricted on this same key in Google Cloud Console, those could
  be quota-abused too. This is the one thing worth checking directly in
  the console (APIs & Services → Credentials → this key → "API
  restrictions") — it isn't visible from the repo.

### Why this isn't a real leak

Firebase Web API keys are meant to be public — they identify the project
when making client-side calls, they don't grant privileged access on
their own. The exact same key is already visible to anyone viewing the
page source of the live `https://throttleiqfb.web.app/live/...` page
(Firebase Hosting serves it client-side), so committing it to the repo
didn't newly expose anything. Firebase's own docs explicitly call this
key non-secret; the actual access control is the Firestore/Storage
Security Rules.

### Recommendation

- Don't rotate the key — that risks breaking the live app for no real
  security gain.
- Do check the key's API restrictions in Google Cloud Console to confirm
  it's scoped to Firebase/Identity services only.
- Close the GitHub secret-scanning alert once confirmed (mark as "used in
  tests" / "false positive" or revoked-as-appropriate per your review).

---

---

## 2. Maintenance page highlighted the wrong bottom-nav tab

**Status:** Fixed 2026-08-01 (commit `221bb57`).

Reported as: _"the maintenance page from garage, when selected, shows that
I'm on record page in bottom but opens the maintenance page correctly."_

**Root cause:** `AppShell._tabs` in `app/lib/shared/widgets/app_shell.dart`
listed only the five tab paths. `/home/maintenance` is a shell route but
not a tab, so `indexWhere` returned `-1` and the code fell through to a
hardcoded `2` — the Record tab. The screen itself was routed correctly all
along; only the highlight was wrong.

**Fix:** the location→tab mapping is now an explicit, pure
`shellTabIndexForLocation(String)`, with a `_nonTabShellRoutes` map sending
`/home/maintenance` to Garage (where it's reached from). Matching is
segment-aware, so a future `/home/recordings` can't steal the Record tab.
Covered by `app/test/shared/app_shell_test.dart`.

**Watch for:** any *new* `/home/*` shell route that isn't its own tab needs
an entry in `_nonTabShellRoutes`, or it will silently inherit the same
wrong-highlight behaviour. The Record fallback exists only to guarantee
`BottomNavigationBar` a valid index.

---

---

## 3. Live-share sessions were world-listable (privacy hole)

**Status:** Fixed and deployed 2026-08-01. **Assume exposure occurred** —
see below.

`firestore.rules` granted `allow read: if true` on `liveSessions/{token}`.
The intent was "anyone holding the share link can view that ride." But in
Firestore, **`read` means `get` + `list`** — so any client, without
signing in at all, could enumerate the entire `liveSessions` collection and
read every rider's live GPS position, speed, battery level and uid. The
32-character token protected nothing against a collection listing; it only
made individual documents hard to guess, which is irrelevant once you can
list them.

**Fix:** the rule is now `allow get: if true` — `list` is not granted, so a
caller must already know the exact document id. Every real caller does a
keyed `.doc(token)` lookup (`public/live-viewer.html:378`,
`ride_recording_provider.dart:1032`), so no legitimate flow was using
`list` and nothing broke.

**Exposure assessment:** the project is pre-launch with only the owner's
own accounts, so real-world exposure is almost certainly nil. But the hole
was live on a public Firebase project for an unknown period, and live
location is the most sensitive data this app holds. Treat any live-share
session created before 2026-08-01 as potentially having been readable.

**The general lesson, worth remembering when writing future rules:** never
write `allow read` when you mean "anyone with the link." `read` grants
enumeration. Use `allow get` for link-shared documents, and grant `list`
only where a client is genuinely meant to browse a collection.

---

---

## 4. Live-session expiry could never have been reaped by a TTL policy

**Status:** Fixed 2026-08-01 (app-side); the TTL policy itself still needs
to be applied — see `HANDOFF_Document.md`.

The handoff doc has long carried a to-do to add a Firestore TTL policy on
`liveSessions.expiresAt` so expired share links auto-delete. That policy
would have silently done nothing: **Firestore TTL only acts on a real
`Timestamp` field**, and `LiveSessionEntity.toFirestore()` wrote
`expiresAt` (and `updatedAt`) with `toIso8601String()` — plain strings.
Documents with a non-Timestamp TTL field are ignored and never deleted, so
the policy would have appeared configured while reaping nothing, forever.

**Fix:** both fields are now written as `Timestamp.fromDate(...)`. Reads
accept either shape, so sessions written by an older build still parse and
a rider mid-ride during the upgrade doesn't get a broken link.
`public/live-viewer.html` was fixed too — it did `new Date(session.expiresAt)`,
which yields an Invalid Date for a Timestamp object and would have been
silently swallowed by the existing `isNaN` guard, meaning expired links
would have stopped expiring in the viewer.

**Still to do:** existing docs keep their string values, so they will never
be reaped even after the policy is applied. Either backfill them or accept
that the pre-fix rows linger. The `gcloud` command to apply the policy is
in `HANDOFF_Document.md`.

---

---

## 5. Missing Firestore composite indexes (Discover + Rider forums)

**Status:** Fixed and deployed 2026-08-01.

Two new queries shipped without the composite indexes they require, so
both surfaces rendered a red `failed-precondition` error dump instead of
content:

| Query | Index needed |
|---|---|
| `getPublicRoutes()` — `collectionGroup('routes').where('isPublic').orderBy('timesRidden')` | `routes`, **COLLECTION_GROUP** scope, `isPublic ASC, timesRidden DESC` |
| `getCustomForums()` — `forums.where('type').orderBy('createdAt')` | `forums`, COLLECTION scope, `type ASC, createdAt DESC` |

Both are now in `firestore.indexes.json` and deployed.

**Why the tests didn't catch it:** a missing index is a *runtime* failure
from real Firestore. Nothing in the unit suite talks to Firestore, so
`flutter analyze` and 402 green tests said nothing about it. Only running
the app did.

**Rule for next time:** any Firestore query combining a `where` on one
field with an `orderBy` on another needs a composite index, and a
`collectionGroup` query needs one scoped `COLLECTION_GROUP` specifically —
a same-named `COLLECTION`-scoped index will NOT satisfy it. Add the index
in the same commit as the query, and check `firestore.indexes.json`
whenever a repository gains a filtered+sorted read.

---

---

## 6. Routes screen was unreachable and inescapable

**Status:** Fixed 2026-08-01.

Two independent UX defects in the new Routes feature, both found by
looking at the running app rather than the code:

1. **No way in.** The only entry point was an icon-only `IconButton` in
   the Places app bar with a `tooltip`. Tooltips require hover and never
   appear on touch, so the entire feature was invisible — a reviewer
   looking straight at the Places tab could not find it. Replaced with a
   labelled row at the top of the Places body: "Routes — roads worth
   riding, yours and other riders'".
2. **No way out.** `RoutesListScreen` (and `RouteDetailScreen`) relied on
   `AppBar`'s automatic back button, which Flutter only renders when the
   Navigator has something to pop. Reached by deep link or a cold launch
   straight to `/routes`, there was no back affordance at all. Both now
   set an explicit `leading` that pops when `context.canPop()` and
   otherwise `go`es to the tab the screen belongs under.

**Watch for:** the same pattern in any future full-screen route. Relying
on the automatic leading is fine only if the screen can *never* be the
first route on the stack — which deep links make hard to guarantee.

---

---

## 7. Deleting a bike deadlocked and silently did nothing

**Status:** Fixed 2026-08-01 (commit `72159c0`). Reported by the project
owner as _"I can't delete a bike from the app"_.

**Root cause — a deadlock, not a logic error.** `BikeDao.delete` opened a
transaction and then called `RideDao.deleteForBike()` and
`MaintenanceDao.deleteForBike()` from *inside* it. Each of those fetches
`DatabaseHelper.instance.database` — the **outer** connection — and
`RideDao` opens a second transaction on it. sqflite serializes access per
connection, so the inner call blocked waiting for the outer transaction to
commit, while the outer transaction waited for the inner call to return.
Neither could proceed. The delete never completed **and never threw**.

Compounding it, `bike_detail_screen` called `deleteBike()` without
`await` and navigated away regardless — so the rider was returned to a
garage that still contained the bike, with no error anywhere.

**Fix:** `BikeDao.delete` now runs every statement on `txn` itself, and
the screen awaits the call and shows failures in a SnackBar.

**The rule this establishes:** _never call another DAO's method from
inside a `db.transaction(...)` block._ Those methods reach for the shared
connection and will deadlock. Do the work on `txn` directly, even if it
means duplicating a couple of `delete` statements. `BikeDao.delete`
carries a comment saying so.

**Why no test caught it:** the DAO "tests" under `test/database/` never
touched a database — they asserted on plain maps. Fixed as part of this:
`sqflite_common_ffi` is now a dev dependency and
`test/database/bike_dao_delete_test.dart` runs 8 cases against a real
in-memory SQLite, including the deadlock case, the cascade to
rides/ride_points/maintenance_logs, isolation of other bikes, unknown
ids, and idempotency. `DatabaseHelper` gained two `@visibleForTesting`
hooks to point the singleton at a test database.

⚠️ **If that file ever hangs**, the cause is almost certainly this bug
reintroduced. The deadlock blocks below the level Dart's `@Timeout` can
interrupt, so a regression shows up as a *stuck run*, not a red failure —
verified by deliberately reintroducing the old implementation.

---

---

## 8. "The logo doesn't switch with the theme" — it did; it just wasn't on screen

**Status:** Resolved 2026-08-01. Not a defect in the swap logic.

Reported by the project owner. `AppLogo` watches `themeStyleProvider` and
picks `throttleiq-icon-dark.svg` / `-light.svg` correctly — confirmed by
four widget tests in `app/test/shared/app_logo_test.dart`, including the
`const AppLogo(...)` case (const canonicalizes the *widget*, not the
*element*, so it still rebuilds on a provider change — this is the thing
everyone assumes is the bug, so it's pinned by a test).

**The real problem:** `AppLogo` was only used on the splash and login
screens, which a signed-in rider never sees. Toggling appearance in
Settings appeared to do nothing to the logo because there was no logo
rendered anywhere to change.

**Fix:** the mark now renders under the Appearance control in Settings,
captioned with which variant is active. Verified visually in both themes.

**Methodology note worth keeping.** While investigating, editing the
simulator's preferences plist directly appeared to show the theme *not*
restoring on launch — which looked like a second, worse bug. It was an
artefact: `cfprefsd` had the plist cached and served the app a stale
value, silently discarding the edit. Writing through
`xcrun simctl spawn <device> defaults write <bundle> flutter.theme_style
-string editorial` worked, and persistence restored correctly. **Never
edit a simulator app's plist directly to set up a test** — go through
`defaults`, or you will chase a bug that isn't there.

---

---

## 9. Bangla would have been served to every unmatched locale (caught pre-ship)

**Status:** Never shipped — caught while wiring localization, 2026-08-02.
Recorded because the trap is easy to walk back into.

`flutter gen-l10n` emits `AppLocalizations.supportedLocales` **sorted
alphabetically by ARB filename**, so with `app_bn.arb` and `app_en.arb`
the generated list is `[Locale('bn'), Locale('en')]` — Bangla first.

Flutter's `basicLocaleListResolution` falls back to
`supportedLocales.first` when the device locale matches nothing. So
wiring `MaterialApp` straight to the generated list would have served
**Bangla to every French, Hindi, Arabic and Spanish phone** — silently,
and only on devices nobody here owns.

**Avoided by** passing an explicit en-first literal in `app.dart`:
`supportedLocales: const [Locale('en'), Locale('bn')]`. Two tests lock it
in — one asserts English is first, one asserts `Locale('fr')` resolves to
English.

⚠️ **Do not "simplify"** `app.dart` to use
`AppLocalizations.supportedLocales`. It looks like obvious cleanup and
reintroduces the bug. The tests will fail if you try; that's their job.
The same hazard applies to any future locale whose code sorts before
`en` (`ar`, `bn`, `de`…).

---

---

## 10. Group-ride roster was rewritable by any accepting invitee

**Status:** Fixed and deployed 2026-08-02.

The roster was an **array of maps** on the ride document. Firestore rules
**cannot project a field out of an array of maps** — there is no way to
express "you may change only the element whose `userId` is yours" — so
the accept clause could only bound the array's *size*. A genuinely
invited rider accepting could, in the same write, rewrite every other
member's display name. They could never grant themselves anything or add
anyone (the flat `memberIds`/`invitedIds` arrays were correctly bounded);
the exposure was roster vandalism, not privilege escalation.

**Fix:** members moved to `groupRides/{id}/members/{uid}` — one document
per rider. The rule is then exactly expressible, in the same shape
`memberLocations/{uid}` already used: the `{uid}` wildcard is pinned to
`request.auth.uid` on write. The parent `allow update` clauses no longer
mention `members` at all, and `allow create` now refuses an inline
`members` key so the invariant is unforgeable rather than conventional.

**The general lesson:** if a rules constraint needs to be *per-element*,
the data has to be per-document. An array of maps is a rules dead end —
reach for a subcollection before writing one.

**Backwards compatibility:** reads merge the legacy inline array with the
subcollection, subcollection winning, so pre-existing rides still render.
Writes are a clean break. One accepted rough edge, **legacy rides only**:
a non-creator who leaves keeps their stale inline entry, because the
tightened rules correctly forbid them rewriting that array. The creator
kicking them does clean it. Pre-launch, so no migration was written — if
you want zero legacy surface, delete existing `groupRides` documents
before the beta starts; nothing else references them.

⚠️ **The rules themselves are reasoned, not executed.** There is no
emulator/rules-test harness in this repo, so the claim that an accepting
invitee is still permitted (they remain in `invitedIds` at write time,
since rules evaluate against committed state, not the pending
transaction) has not been run. **Do one manual invite → accept → leave
pass against the emulator or a second account before the beta.**

---

---

## 11. "The app crashes randomly" — nested array in the GPS trail upload

**Status:** Fixed 2026-08-03 (commit `1fca84e`). Reported by the project
owner as random crashes on iPhone, twice in one day.

**Root cause, confirmed from the crash report rather than inferred.**
`~/Library/Logs/DiagnosticReports/Runner-2026-08-01-174714.ips`:

```
EXC_CRASH (SIGABRT)
  ...
  FirebaseFirestoreInternal  ThrowInvalidArgument<>(char const*)
  FirebaseFirestoreInternal  -[FSTUserDataReader parseData:context:]
```

**Firestore does not support nested arrays** — an array may not contain
another array. `chunkTrack()` returned `List<List<num>>` (a list of
5-element point lists) and `uploadRideTrack` wrote it as the `points`
field, so every trail upload handed the native SDK a shape it refuses.

Two things made it lethal rather than merely broken:

1. The rejection is an **Objective-C exception, not a Dart one**. The
   `try`/`catch` wrapped around the call in `SyncManager` caught nothing.
   The process aborted.
2. It fires from SyncManager's **background timer** after a ride syncs —
   nothing the rider did, hence "random".

Timeline confirms it: the trail-sync commit landed 2026-08-01 **17:14**;
the crash is stamped **17:47**, the first sync after a ride with that code
in place.

**Fix:** each chunk is now a **flat** array of numbers, `fieldsPerPoint`
(5) per point, strided on read via `decodeChunk`. The original reason for
a positional encoding — avoiding repeated map keys against the 1 MiB
document limit — still holds; only the nesting is gone. No migration was
needed, because the write always threw and no track document was ever
persisted.

### Two lessons worth carrying

**Dart-only round-trip tests cannot validate a Firestore schema.** The
codec had 13 passing tests. They round-tripped Dart → Dart and never
touched Firestore, so they cheerfully certified a shape the database
rejects. Same blind spot as §7's DAO deadlock, which passed map-shaped
"tests" that never opened SQLite. **If a payload crosses a boundary, the
test has to cross it too** — or at minimum assert the boundary's rules
(the regression test here asserts every chunk element is a `num` and
never a `List`).

**`try`/`catch` around a plugin call is not a safety net.** Native
exceptions from Firebase/platform channels bypass Dart error handling
entirely and abort the process. Defensive `catch` blocks around
`batch.set()` give a false sense of protection; the only real defence is
not constructing an invalid payload.

### If it recurs

Crash reports do **not** sync to the Mac automatically. Either open Xcode
→ Window → Devices and Simulators → *View Device Logs*, or on the phone
Settings → Privacy & Security → Analytics & Improvements → Analytics
Data, and look for `ThrottleIQ-*.ips` / `Runner-*.ips`. The faulting
thread's top frames name the culprit directly.

---

---

## 12. Deleted bikes came back on the next sync

**Status:** Fixed 2026-08-04 (commit `c92bfb8`).

Reported twice, as what looked like two problems: _"when I delete a bike
I can still choose it on the ride page and I'm still in its forum"_ and
_"it removes it from the garage temporarily but when I reopen the app the
deleted bike appears again."_ **One bug.** The bike never actually left.

**Root cause.** `GarageNotifier.deleteBike` called `BikeDao.delete`, which
removed the **local** row only. The Firestore document survived, and
`CloudRepository.downloadBikes` re-adds *"anything missing locally"* —
which is precisely what a deleted bike looks like. The next sync
faithfully recreated it. Nothing downstream was broken: the bike picker
and the garage-forum resolution were correctly reflecting data that said
the bike still existed.

**Why a tombstone and not just a remote delete.** Deleting the Firestore
doc alone still loses the deletion whenever the rider is offline at the
moment they tap delete — the local row goes, the remote delete fails, and
the next sync brings it back. So:

- schema 7 → 8 adds `deleted_bikes(id, deleted_at, synced)`
- `BikeDao.delete` writes the tombstone **in the same transaction** as the
  delete, so the two can never disagree
- `downloadBikes` consults it and skips those ids
- `CloudRepository.deleteBikeRemote` removes the bike doc **and its
  rides** — otherwise `downloadRides` resurrects rides orphaned to a bike
  that no longer exists
- `SyncManager` pushes pending deletions **before** uploads and downloads,
  so a single cycle settles a deletion instead of fighting itself; a
  failure leaves the tombstone unsynced for the next attempt
- tombstone rows are **kept** after syncing, never removed: a second
  device that still has the bike would otherwise reintroduce it

**The general lesson.** This codebase's sync is "pull anything missing
locally." Under that rule, **a local delete is indistinguishable from a
record that hasn't synced yet** — so any entity that can be deleted needs
a tombstone, not just a delete. Rides, maintenance logs and routes have
the same shape and have **not** been audited for this; if a delete there
ever looks flaky, this is the first thing to check.

Covered by 5 new real-SQLite tests (13 total in
`test/database/bike_dao_delete_test.dart`).

---

## 13. QA report — empty placeholder, retired (2026-10-22)

`issues_open.md` §13 was a "QA report: not started" placeholder that never got a
write-up. QA passes got their own numbers instead (§46, §90, §101). Moved here on
2026-10-22 so the number stays taken.

---

## 13a. Stop hook blocked every session end, unconditionally (2026-08-02)

**Status:** Fixed.

`.claude/settings.json`'s `Stop` hook piped the hook's stdin JSON through
`jq -r '.stop_hook_active // false'` to decide whether to allow the turn to
end. `jq` isn't installed / on `PATH` on this machine, so the pipeline
silently failed, `active` was always empty, and the hook took the `else`
branch and returned `{"decision":"block", ...}` on **every** Stop event —
including the re-invocation where `stop_hook_active` is `true` and the hook
is supposed to stand down. In practice this meant the same "update the
docs" reason fired every single time a turn tried to end, regardless of
whether anything doc-worthy had changed, until the harness's own
`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` override kicked in.

**Fix:** rewrote the check to use `grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'`
against the raw stdin instead of `jq`, so it has no external-binary
dependency. Verified against `true`/`false`/spaced JSON input.

---

---

## 14. `usernames` was world-listable, same bug class as §3 (2026-08-04)

**Status:** Fixed and **deployed 2026-08-04**, verified against the live
project: an unauthenticated `list` of `usernames` now returns
403 PERMISSION_DENIED, while a keyed `get` of a nonexistent handle returns
404 NOT_FOUND (i.e. permitted, just absent). `livePointers` and
`liveSessions` also refuse `list`.

Found while building the permanent per-rider share link
(`/r/{username}` — see `HANDOFF_Document.md`). `firestore.rules` granted
`allow read: if request.auth != null` on `usernames/{handle}`. Same mistake
as §3: **`read` = `get` + `list`**, so any signed-in rider could enumerate
the entire `usernames` collection and pull every handle→uid pair — not as
sensitive as live GPS, but still a full username→identity map handed out
for free. Every real caller (`ProfileRepository`, the new
`public/live-viewer.html` handle resolution) does a keyed `.doc(handle)`
lookup, so nothing legitimately needed `list`.

**Fix:** `allow get: if true` — no `list`, and no auth requirement either,
because the permanent share link is opened by people who never sign in
(that's the whole point of a link). This also **enabled** the new feature
rather than just closing a hole: with the old `request.auth != null` gate,
the public live-viewer page — which never calls `firebase.auth()` — would
have gotten permission-denied on every single `/r/{username}` visit.

Added a matching rule for the new `livePointers/{uid}` collection (the
other half of the permanent link — see `HANDOFF_Document.md`), keyed by uid
rather than username so the rule is a plain path match:
`allow get: if true`, write gated on `request.auth.uid == uid`.

**The general lesson, restated from §3:** every new capability-style
collection (readable via a link/handle, not by browsing) needs `allow get`,
never `allow read`, from the moment it's written — not as a follow-up
audit. This is the second time the same class of rule shipped wrong; worth
a second pair of eyes on any future `firestore.rules` diff before it goes
out.

---

---

## 15. Widget tests can't tap anything under the default M3 splash (2026-08-11)

**Status:** Worked around per-test. Not an app defect — the app itself is
fine on device — but it will stop the next person who writes a widget test
that taps a Material control, and the error names a shader rather than the
tap, so it does not read as "your test needs a theme override."

Found while widget-testing the new skin picker
(`test/features/profile/skin_dropdown_test.dart`). `tester.tap()` on a
dropdown menu item threw before the tap was delivered:

```
Exception: Asset 'shaders/ink_sparkle.frag' manifest could not be decoded:
INVALID_ARGUMENT: Unsupported runtime stages format version. Expected 2, got 1.
```

Material 3's default splash is `InkSparkle`, which compiles a fragment
shader; the shader bundle in this Flutter install (3.44.9) is a version the
test engine won't decode. Any tap that starts an ink splash hits it.

**Workaround:** give the test's `MaterialApp` a theme with a non-shader
splash — `ThemeData(splashFactory: InkRipple.splashFactory)`. Cheap, local
to the test, and doesn't change what's being asserted.

**Related trap in the same area:** you cannot pump a real screen's
`ThemeData` in a test at all. `AppTheme.build()` calls `google_fonts`,
which tries to fetch IBM Plex over the network and throws in the test
harness. Tests that need app-like chrome have to hand-roll the pieces they
care about (see the same file's `InputDecorationTheme`). Bundling the fonts
as assets instead of fetching them would fix this and the Bengali-glyph
fallback noted in `Features.md` §8 at the same time.

**Also worth knowing:** `SettingsScreen` can't be pumped at all —
`EmergencyContactsNotifier` reaches `FirebaseFirestore.instance` in a field
initializer, so constructing it without a live Firebase app throws, and
`overrideWith` can't dodge it (the override must still return an
`EmergencyContactsNotifier`). That's why the skin picker lives in
`features/profile/presentation/widgets/skin_dropdown.dart` rather than as a
private widget inside the screen. Any future settings control worth testing
should be extracted the same way, or the notifier should take its
`FirebaseFirestore` as a constructor argument.

---

---

## 16. Skin dropdown under accessibility text scaling — investigated, NOT a defect (2026-08-11)

**Status:** Closed, no code change. Filed as a suspected clipping bug during
the 2026-08-11 device run, then **measured and found to be wrong.** Kept
rather than deleted because the two testing lessons underneath it are real.

**What prompted it:** the live `MediaQuery` on the test iPhone reports
**`textScaler: 1.1176x` and `boldText: true`** — the owner's phone has
accessibility text scaling on. That part is true and worth internalising:
the 1.0x every widget test runs at is not the configuration that ships.

**The claim, and why it was wrong.** Each row of the skin picker is two
lines (name over blurb), and `DropdownButton.itemHeight` defaults to
`kMinInteractiveDimension` (48 px) — which reads like a hard clamp that
would clip the second line at large text sizes. Measured pitch between
adjacent rows, with and without `itemHeight: null`:

| text scale | content height | row pitch | exception |
|---|---|---|---|
| 1.0x | 25 px | 48 px | none |
| 1.1176x (this device) | 28 px | 48 px | none |
| 2.0x | 50 px | 50 px | none |
| 3.0x | 75 px | 75 px | none |

Rows already grow: pitch is `max(48, content)`. **`itemHeight: null` is a
no-op here** — identical numbers with and without it — and had the default
actually been a clamp, setting it null would have dropped rows to 25 px at
1.0x, *below* the 48 dp minimum touch target. The "fix" was a regression
waiting to happen, applied on an assumption about Flutter internals rather
than a measurement. It was written, measured, and reverted.

**Lesson 1 — `MediaQuery` does not reach an overlay route.** The first
version of the scaling test wrapped the subject in
`MediaQuery(textScaler: 2.0)` under `home`. A dropdown menu opens as its
**own route above `home`**, so it inherits MediaQuery from the Navigator
and rendered completely unscaled: content measured 25 px at every "scale"
from 1.0 to 3.0. The test passed identically with and without the fix,
because it was measuring nothing. **Scale with
`tester.platformDispatcher.textScaleFactorTestValue` instead** — it applies
above the Navigator, so overlay routes get it too. This applies to any test
of a dialog, menu, bottom sheet, or popup.

**Lesson 2 — a test that passes before the fix is not a test.** The only
reason this was caught is that the fix was reverted and the test re-run to
watch it fail. It didn't. Any test written to cover a specific defect
should be run against the unfixed code once; if it passes, it is
decorative. The regression guard now in
`test/features/profile/skin_dropdown_test.dart` asserts the real property
(pitch covers content, and never drops below 48 dp) and was checked against
both configurations.

---

---

## 17. "I can't switch bikes" — the picker navigated to Garage instead (2026-08-11)

**Status:** Fixed 2026-08-11. Reported by the owner from the device build,
not caught by any test — there were no Record-screen tests at all.

The active-bike card on Record was an `EditorialCard` with
`onTap: () => context.go('/home/garage')` and a **"Change"** label on the
right. Tapping it left the screen. Switching bikes therefore meant: leave
Record → find the bike in Garage → set it active → navigate back. The label
was the tell — it said "Change", and what it did was *navigate*.

Worth separating the two mistakes, because only one of them is about
navigation:

1. **Wrong destination for the decision.** Garage is where you *manage*
   bikes. Choosing which one you're about to ride is a Record-screen
   decision, and it shouldn't move you off the screen you're about to start
   the ride from.
2. **The affordance lied.** A control labelled with a verb should perform
   that verb. "Change" that navigates is the same class of bug as a "Save"
   button that opens a settings page.

**Fix:** the card is now a dropdown
(`features/ride/presentation/widgets/bike_picker_card.dart`) — see
`Features.md` §2 for the behaviour, including the deliberate single-bike
case (no dropdown affordance when there is nothing to pick).

**Why there was no test to catch it:** `RecordScreen` reads
`FirebaseAuth.instance` in `initState`, so it cannot be pumped in a widget
test — the same trap as `SettingsScreen` in §15, and the second time it has
hidden a real defect. The picker was extracted to its own widget to make it
testable, and now has four tests. **This is now a pattern worth acting on
rather than working around each time:** screens that touch
`FirebaseAuth.instance` or `FirebaseFirestore.instance` directly in
`initState`/field initializers are untestable by construction, and every
interactive control inside one is unguarded. Either inject those
dependencies or keep extracting the controls.

**The regression test was checked against the bug.** Per §16's lesson, the
navigate-away behaviour was re-introduced and the test watched to fail
before being trusted. It asserts both halves: `setActiveBike` is called
with the chosen id, **and** no `MaterialPageRoute` is pushed. (Note when
writing similar tests: `MaterialApp` pushes its own `/` home route at
startup, so a `NavigatorObserver` list must be cleared after the initial
pump or the assertion trivially fails.)

---

---

## 18. Quitting the app mid-ride silently ended the ride (2026-08-11)

**Status:** Fixed 2026-08-11. Reported by the owner. Not caught by any test
— the recovery path had no test at all, and the behaviour it implemented
was wrong by design rather than by accident, so a test written against it
would have locked the bug in.

`RideRecordingNotifier.recoverCrashRide` ran once on startup for a signed-in
user. If `active_ride_id` was still set in SharedPreferences — i.e. the
previous run never reached `stopRide()` — it recomputed the ride's totals
from the stored GPS fixes, called `finalizeRide`, and filed it in history.

That is the correct behaviour for the case it was named after (a process
killed by OS jetsam or an OEM battery manager) and the wrong behaviour for
the case that actually happens most: **the rider swiping the app out of the
recents switcher.** Stop for fuel, swipe the app away, come back — and the
ride is over. Start again and you have two half-rides that can't be
rejoined, with no warning that closing the app would do that.

**The two cases are indistinguishable from inside the app.** There is no
flag that separates "the OS killed us" from "the user swiped us away";
both simply leave the pref set. So the fix isn't to detect which happened
— it's to stop deciding on the rider's behalf either way.

**Fix:** `restoreInterruptedRide` replaces it. The session is rebuilt into
`RecordingStatus.paused` — distance, top speed, moving time, route and ride
clock intact — and the rider chooses: resume, end and save, or discard
(§20). A banner says "Ride kept from last time" so a paused ride nobody
paused doesn't read as a new bug. See `Features.md` §2.

**Three things fell out of the fix that are worth knowing:**

1. **Elapsed time had to become a persisted value.** Everything else about
   a session is derivable from the fixes on disk; elapsed is not, because a
   ride that spent forty minutes parked spans far more wall-clock than it
   recorded. It is now snapshotted to `ride_elapsed_s` every 10 s, forced
   on pause and on the app leaving the foreground. The 10 s throttle is
   deliberate — losing up to ten seconds of ride clock to a kill is nil
   next to writing prefs 3,600 times an hour.
2. **A latent distance bug became a real one.** `MotionCalculator` measures
   from the last fix to the current one, and nothing ever suppressed that
   across a pause. Pause at the top of a pass, van the bike down, resume,
   and the ride gained the entire van journey as one straight line. This
   was always wrong, but a pause was bounded by the app staying alive; a
   pause that now survives a restart makes the gap unbounded. Fixed with
   `_skipNextDistanceDelta`, consumed by the first fix after any resume.
3. **Event counts cannot be restored.** Hard-brake / rapid-accel /
   high-jerk come from `EventDetector`'s thresholds over a continuous
   sample stream; thinned, already-persisted points can't reproduce them.
   They restart at 0 on a resumed ride. Documented, not guessed at.

A ride that *was* already finalized (crash detection closed it out, or
`stopRide` wrote the row but died before clearing prefs) is deliberately
**not** offered back — it is in history, and resuming it would duplicate it.

---

---

## 19. A killed ride left the permanent share link resolving to it (2026-08-11)

**Status:** Fixed 2026-08-11. Found while writing §18, not reported. Same
bug class as §3 and §14 — a live-share artifact outliving the intent to
share — but reached by a different route.

`stopRide` is careful about this: it marks the `liveSessions` doc completed
and clears `livePointers/{uid}` so `/r/{username}` stops resolving (see the
comments there and §14 for why the pointer is cleared rather than left
dangling with `active: false`).

**A ride that ends by process death runs none of that.** The in-memory
`_currentLiveSessionToken` dies with the process, so on the next launch the
app cannot even name the session doc to close it — while
`livePointers/{uid}`, which is keyed by uid and needs no token, is very
much still there and still pointing at it. Anyone holding the rider's
permanent link stayed parked on the last position from before the app died.

Before §18 this was bounded, if accidentally: `recoverCrashRide` finalized
the ride immediately at launch, and while it never touched the pointer
either, the next ride would overwrite it. Restoring to *paused* removes
even that accidental bound — the stale pointer would now persist for as
long as the paused ride sits there unresolved.

**Fix:** `restoreInterruptedRide` clears the pointer as part of the
restore. The rider is demonstrably not riding right now — the app was dead
— and resuming mints a fresh token and re-points it. The orphaned
`liveSessions` doc is left to its 24 h `expiresAt`; with the pointer gone
there is no path to walk to it.

**Worth noting for the next person:** every teardown path for a ride has to
clear the pointer, and there are now four (`stopRide`, `cancelRide`,
`restoreInterruptedRide`, and the TTL). That is exactly the shape of thing
that gets missed when a fifth is added.

---

---

## 20. No way to throw away a ride you didn't mean to record (2026-08-11)

**Status:** Fixed 2026-08-11 (feature gap, reported by the owner).

Ending a ride always saved it. A ride started by accident, or one the app
recovered that isn't worth keeping (§18), had no exit that didn't leave a
row in history — the rider had to save it and then delete it from the Rides
tab, if they realized they could.

**Fix:** `cancelRide()` — tears down the streams, ends the live session and
clears the pointer (§19), drops the buffered points rather than flushing
them, and deletes the local row. `RideDao.delete` removes the ride's
`ride_points` in the same transaction, and a ride that never reached
`status = 'completed'` is invisible to every query **and** to the sync
layer, so nothing about a discarded ride ever left the device. That is why
the row is deleted rather than marked cancelled: there is no cloud copy to
chase.

**On the UI weighting**, since it's the reason this isn't a third button:
end-and-save is what almost every ride wants, and a destructive action with
no undo shouldn't be the same size and shape as the control beside it that
keeps everything. It's a text button under the pause/end pair, and its
dialog names what is lost (the actual distance and duration) rather than
asking a generic "are you sure?".

---

---

## 21. Every `AppTheme.build` in a test failed an unrelated test (2026-08-11)

**Status:** Fixed 2026-08-11. Pre-existing in the then-uncommitted
`app_theme_style_test.dart`; found while adding Retro's assertions to it.

The app ships **no font assets** — `google_fonts` resolves IBM Plex at
runtime over the network. `flutter_test` installs an `HttpClient` that
fails every request, so that fetch can never succeed in a test. Worse,
`google_fonts` reports the failure on a future nobody awaits, so the error
surfaced asynchronously, *after* the calling test had already completed,
and was attributed to whichever test happened to be running when it landed:

```
This test failed after it had already completed.
```

So the symptom appeared on a test that did nothing wrong, while the test
that actually called `AppTheme.build` passed. Two tests failed for one
cause, neither of them where the cause was.

**Fix:** `GoogleFonts.config.allowRuntimeFetching = false` in `setUpAll`
(making the failure deterministic — a missing-asset throw rather than a
network error), plus a `themeFor(style)` helper that runs the build inside
`runZonedGuarded` and swallows *only* that complaint, rethrowing anything
else. These tests assert colors and shapes; the fallback face they render
in is irrelevant to every one of them.

**The general point:** any future widget test that builds a real
`ThemeData` will hit this. If a test starts failing "after it had already
completed" with no obvious cause, check for an unawaited `google_fonts`
future before looking anywhere else.

---

---

## 22. Widget tests hang — not fail — on real file I/O (2026-08-11)

**Status:** Worked around 2026-08-11 by design change. Found while building
the bike-photo cropper. Third entry in this file's growing "the test harness
lies to you" set, after §15 (M3 splash swallows taps) and §21 (google_fonts
fails an unrelated test).

The first attempt at testing `ImageCropScreen` pumped the real widget with a
real image file. It never completed — `flutter test` sat until it was killed.

**Cause.** `flutter_test` drives widget code inside a fake-async zone. Timers
are faked, and futures that depend on the *real* event loop turning — file
reads, `decodeImageFromList`, anything crossing into platform code — never
complete. The screen's `initState` kicks off a decode, the decode never
finishes, so the loading spinner spins forever and `pumpAndSettle` waits on
an animation that will never stop.

**Why this one is nastier than §15 or §21.** Those *fail*, with a message.
This **hangs**, which is indistinguishable from a slow test suite until you
notice it's been minutes. There is no error, no stack, and nothing pointing
at the cause. `tester.runAsync` exists for this, but it cannot be combined
with `pumpAndSettle`, so the workaround devolves into hand-pumping frames
around real delays — brittle, and it only papers over the real problem.

**Fix — a design change, not a test trick.** The pixel pipeline was pulled
out of the widget into `core/utils/image_crop_io.dart` as
`writeCroppedImage(...)`, with an injectable `outputDirectory` so a test can
hand it a temp dir instead of hitting `path_provider`. It is now covered by
10 ordinary `test()` cases (no widget binding, no fake async), including
four-colour quadrant fixtures that assert *which region* was cut rather than
only its dimensions.

**The rule this generalises to, and it is worth applying beyond the
cropper:** a `State` method that awaits file I/O, image decoding, or a
platform channel is untestable by construction — and it fails silently, by
hanging. Push that work into a plain function with its dependencies
injectable, and leave the widget as the gesture surface. Note that this is
the same underlying lesson as §17's ("screens that touch
`FirebaseAuth.instance` in `initState` are untestable by construction, and
every control inside them is unguarded") — different dependency, identical
shape. Two independent instances now; treat it as the house rule rather than
a case-by-case workaround.

---

---

## 23. `flutter analyze` reports ~6,150 errors that aren't in this project (2026-08-12)

**Status:** **FIXED 2026-08-12** (same day it was found) — `build/**` is now
excluded in `app/analysis_options.yaml`. Kept written up because the symptom
looks catastrophic and will recur in any Flutter project that adopts iOS
SwiftPM without this exclusion.

Running `flutter analyze` from `app/` printed **6,163 errors**. None of
them were in `lib/` or `test/`. Every one came from
`app/build/ios/SourcePackages/checkouts/flutterfire/**` — the FlutterFire
sources Swift Package Manager checked out under `build/` when the iOS
SwiftPM migration landed (commit `8c298c1`, 2026-08-11).

The errors themselves are the expected consequence of a package existing
twice in one analysis context: the checkout's own
`firebase_auth_platform_interface` and the pub-cache copy are separate
libraries with identically-named classes, so every override across them
reads as invalid —

```
error • 'MethodChannelFirebaseAuth.authStateChanges' … isn't a valid
override of 'FirebaseAuthPlatform.authStateChanges'
  (where UserPlatform is defined in .../build/ios/SourcePackages/…)
  (where UserPlatform is defined in ~/.pub-cache/hosted/pub.dev/…)
```

**Why it mattered more than the noise suggests.** `flutter analyze` is the
project's cheapest correctness gate, and both its exit code and its output
were useless by default — a real error in `lib/` was one line among six
thousand. Anyone who ran it, saw the count, and didn't check *where* the
errors were would reasonably conclude the tree was broken.

**The fix:**

```yaml
# app/analysis_options.yaml
analyzer:
  exclude:
    - build/**
```

`build/` is generated output and has no business being analyzed. Verified
nothing generated-and-committed is hidden by this: the l10n output lives in
`lib/l10n/`, which is still analyzed. Result:

| | before | after |
|---|---|---|
| issues | 6,782 | 121 |
| errors | 6,163 | **0** |
| runtime | 8.8s | 2.9s |

The rejected alternative was `flutter clean` before every analyze run —
effective, but it throws away the whole build cache to fix a lint run, and the
checkout comes straight back on the next iOS build.

**The filter that stood in for the fix**, still worth knowing when analyzing a
tree that predates it, or any other project with this shape:

```bash
flutter analyze 2>&1 | grep -E '• (lib|test)/' | grep 'error •'
```

Empty output means clean. That is how the 2026-08-12 shape work was verified
before the exclusion landed — it found exactly the 8 real `const` breakages
and nothing else, which is also the evidence the exclusion isn't hiding
anything: the error count was already 0 by that measure.

Note this is **not** the same thing as the ~121 remaining `info`/`warning`
lints in `lib/` and `test/` (unused locals, `prefer_const_constructors`,
`withOpacity` deprecations, `subtype_of_sealed_class` from Firestore mocks).
Those are real, in-project, and predate this — worth a cleanup pass, but they
were never load-bearing noise the way this was.

---

---

## 24. Security audit — 8 open findings, 2 of them launch-blocking (2026-08-12)

**Status:** **ALL 8 FINDINGS FIXED IN CODE; THE 2026-08-12 RULES WERE DEPLOYED
2026-08-14. A SECOND, NARROWER RULES DEPLOY IS NOW PENDING AND MUST NOT GO OUT
BEFORE THE NEXT APP BUILD — see the ordering note below.** Originally found by
a read-only audit of `firestore.rules`,
`storage.rules`, `functions/`, `public/live-viewer.html`, the Flutter client
and the Android/ops config, with no code changed at audit time. A follow-up
pass the same day fixed all 8 — §24.1–§24.9 below now each carry their own
**Status** line with what actually changed and file/line references into the
fix, in the same place the original finding is recorded, so the exploit and
the fix read together.

**✅ The 2026-08-12 rules are live.** `firebase deploy --only firestore:rules`
was run against `throttleiqfb` on 2026-08-14 and reported
`released rules firestore.rules to cloud.firestore`. That covers §24.1, §24.4,
§24.5, §24.6, §24.9's admin-claim change, and §24.7's like/vote half — those
are all now enforced for live riders.

**✅ The second rules deploy is done too — 2026-08-14, after the 19-test
emulator suite passed.** This covered §24.7's residual (comment/reply counter
inflation) and §24.11's two fixes. `npm run test:rules` from `scripts/` was run
immediately before, and is the check to repeat before any future rules deploy —
there is now a real emulator-backed suite (§24.11), so a rules edit no longer
has to go out blind.

**⚠️ The client half of that fix has NOT reached any device yet, and the two
must match.** The deployed rule requires the counter bump to carry a
`lastCommentId`/`lastReplyId` naming a doc created in the same transaction, and
**only the new client sends those fields**. So on any install still running an
older build:

- posting a comment on a ride fails,
- posting a reply in a forum fails,
- deleting your own reply fails.

Closing that window, device by device: **Abraar's iPhone got the iOS release
build on 2026-08-14** (`flutter run --release` from `1a735f5`), so it is fine.
The **Android APK exists but has not been installed anywhere**, and any other
device is still broken until updated. This was a deliberate, informed call
rather than an oversight — the deploy was requested with the ordering
understood — but it does mean *install the new build before commenting from a
phone*.

Until step 3, the residual documented in §24.7 stays open in production — which
is the status quo, not a regression.

**🔶 Cloud Functions still cannot deploy at all** — `firebase deploy` fails
with *"project throttleiqfb must be on the Blaze (pay-as-you-go) plan"*,
because `artifactregistry.googleapis.com` can't be enabled on Spark. This
blocks §24.8's crash-notification PII fix and §24.9's new
`reconcileRideIdentity` trigger from ever running, no matter how correct the
code is. Upgrading the project at
<https://console.firebase.google.com/project/throttleiqfb/usage/details> is the
only way through. See §24.10 for the build problems found and fixed underneath
this one.

This breaks the one-`##`-per-issue convention on purpose: these came out of a
single pass, they share context, and splitting them across §24–§31 would bury
the two that matter. Sub-sections are numbered §24.1 … §24.9 so they can be
cited individually.

**These two were the ones to fix before beta testers are invited.** §24.1 and
§24.2 composed into "any stranger can watch any rider move in real time," and
both are now fixed — see their sections below for exactly what changed.

### 24.1 Live location is readable by anonymous strangers, given only a @handle — CRITICAL

**Status: FIXED 2026-08-12** (rules deployed 2026-08-14).
`_startLiveSessionPublishing()` no longer runs from `startRide()`/
`resumeRide()` at all — it only runs via the new `enableLiveSharing()`
(`ride_recording_provider.dart`), triggered by the rider tapping "Share live
location" (`active_ride_screen.dart`'s `_shareLiveLocation`). That tap IS the
opt-in now; the icon shows filled/outlined depending on whether sharing is
actually on. `_liveShareEnabled` resets to `false` at the start of every new
ride and on every teardown path (`stopRide`/`cancelRide`), and a cold-started
resume after a process death does NOT automatically resume publishing — fail
closed, the rider has to re-tap. `LiveSessionEntity` gained a `shareable`
field, `true` on every doc this app writes (since publishing now only ever
follows the opt-in), and `firestore.rules`' `liveSessions/{token}` `get` rule
requires `shareable == true` — a rules-level backstop, not just client
gating, so even a future regression that reintroduced always-on publishing
still can't be read by a stranger without the rule also regressing.

Three collections are readable with **no authentication at all**, and they
chain into each other:

```
usernames/{handle}   → { uid }    firestore.rules:565   allow get: if true
livePointers/{uid}   → { token }  firestore.rules:586   allow get: if true
liveSessions/{token} → live GPS   firestore.rules:201   allow get: if true
```

Each of those three grants was deliberate and is defended in a comment — the
permanent `/r/{username}` link has to resolve for a visitor who does not have
the app and is not signed in (§14, §3). The grants are not the bug. **The bug
is the premise underneath them.** `firestore.rules:574-584` argues the chain is
safe because a rider only appears in `livePointers` "because the rider
published a shareable live session in the first place."

That is not what the client does. `_startLiveSessionPublishing()` is called
unconditionally from `startRide()`
(`ride_recording_provider.dart:415`, and again on resume at `:825`). There is
no opt-in flag, no share toggle, no consent gate anywhere on the path — every
ride publishes `liveSessions/{token}` and points `livePointers/{uid}` at it,
whether or not the rider ever taps "share live location".

So the real exposure is: **for every rider, on every ride, an unauthenticated
attacker who guesses the handle gets live lat/lng, speed, battery and crash
status, polled in real time.** Handles are `[a-z0-9_]{3,20}` and are
auto-derived from the email local part (`suggestUsernameBase`,
`profile_repository.dart:128-137`), so a wordlist of first names hits a large
share of the userbase. Anonymous Firestore `get`s are not rate-limited.

Worth being blunt about what this is: a stalking primitive, on an app whose
README sells privacy-zone protection as a feature.

**Fix:** gate `_publishLiveSession` / `_publishLivePointer` behind an explicit
per-ride share opt-in, *and* require an explicit `shareable: true` field on the
session doc before `get` is granted — client-side gating alone leaves every
already-written session readable.

### 24.2 Live-share tokens come from a non-cryptographic PRNG — HIGH

**Status: FIXED 2026-08-12** (ships with the next app build — a pure client
fix, no rule involved, so no deploy applies to it). One-word
change in `_createLiveSessionToken()`: `Random()` → `Random.secure()`.

`ride_recording_provider.dart:1245-1252`:

```dart
final rnd = Random();   // dart:math — NOT Random.secure()
final token = String.fromCharCodes(
  Iterable.generate(32, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
);
```

`liveSessions` is a pure capability model — "the link is the permission"
(`firestore.rules:184-201`). The token **is** the entire access control, and it
comes out of Dart's default `Random`: a seeded 64-bit LCG initialised from the
clock. An attacker who knows roughly when a ride started can brute-force the
seed and derive the token exactly; the nominal 62³² keyspace never comes into
it. And because nothing sweeps expired sessions (§4 — `expiresAt` is honoured
only client-side, in `live-viewer.html`), a recovered token keeps returning the
last known position indefinitely.

**Fix:** `Random.secure()`. One word, and it is the difference between ~190
bits of entropy and ~64 bits of guessable clock state.

### 24.3 Publishing a saved route leaks the rider's home address — HIGH

**Status: FIXED 2026-08-12.** Implemented the "at minimum in `setPublic`"
alternative rather than clipping in `saveRoute` — a private route (the
default, "Only you can see this route") keeps its real endpoints, since
nothing but the owner can ever read it; `RouteRepository.setPublic()` now
reads the stored polyline, runs `PrivacyZoneClipper.clipPolyline` on it, and
overwrites the stored trail in the same write that flips `isPublic: true`.
The clip is permanent — setting a route back to private does not restore the
un-clipped trail, the same one-way posture `RideShareRepository.shareRide`
already has for shared rides. A short/near-home route can clip to nothing;
that's the safe outcome, matching `shareRide`'s existing behavior, not an
error.

Ride *sharing* clips privacy zones — `ride_share_repository.dart:66` runs
`PrivacyZoneClipper.clipPolyline`, stripping ~200 m off each end. Route
*publishing* does not.

`save_route_screen.dart:88-99` passes `_polyline` — the raw trail read straight
out of the local `ride_points` table — into `RouteRepository.saveRoute`, which
stores it verbatim (`route_repository.dart:17-42`). Flipping the "Public"
switch then exposes it to **every** authenticated rider through the
collection-group rule at `firestore.rules:292-294`.

The switch's own subtitle says only "Any rider can find and ride this route."
It does not say "starting from your driveway." Two code paths, the same GPS
trail, opposite privacy postures — that inconsistency is the whole finding.

**Fix:** run `PrivacyZoneClipper.clipPolyline` in `saveRoute` (or at minimum in
`setPublic`).

### 24.4 Forum-moderator takeover via unconstrained forum creation — HIGH

**Status: FIXED 2026-08-12** (rules deployed 2026-08-14). The
`createdBy`/`maintainerIds` ownership constraint in the `forums/{forumId}`
`create` rule now applies to every write, not only `type == 'custom'`:
either field, if present at all, must equal the caller / `[caller]`; both
may still be omitted entirely (required for `getOrCreateForum`'s
auto-created bike/topic forums, which never set them). Verified against
`forum_repository.dart`'s three create paths: `getOrCreateForum` and
`getOrCreateGeneralForum` never set either field, `createCustomForum` always
sets both to the caller's own uid — so the tightened rule changes nothing
for any real caller, only for a client trying to set them to something else.

`firestore.rules:314-319`:

```
allow create: if request.auth != null &&
  request.resource.data.followerCount == 0 &&
  request.resource.data.postCount == 0 &&
  (request.resource.data.get('type', '') != 'custom' || (
    request.resource.data.createdBy == request.auth.uid &&
    request.resource.data.maintainerIds == [request.auth.uid]));
```

The `createdBy` / `maintainerIds` constraint fires **only when
`type == 'custom'`**. For any other type those fields are unconstrained.

Forum ids are deterministic slugs — `bikeForumSlug('yamaha', model: 'r15')` →
`yamaha__r15`, `generalForumSlug('Maintenance')` → `maintenance`
(`forum_repository.dart:46,80`). An attacker enumerates popular brand/model
slugs that don't exist yet and pre-creates them with `type: 'bikeModel'` and
`maintainerIds: ['<attacker-uid>']`. `canModerateForum()`
(`firestore.rules:81-86`) reads exactly those fields, so the attacker now holds
permanent delete rights over every post and reply any rider ever makes in that
forum, plus the ability to drive `postCount` down. They can also stamp
`createdBy` with an innocent third party's uid.

**Fix:** apply the ownership constraint to all types, or require
`!('maintainerIds' in request.resource.data)` for non-custom forums.

### 24.5 @username impersonation — the profile doc bypasses the reservation — MEDIUM

**Status: FIXED 2026-08-12** (rules deployed 2026-08-14). The
`users/{uid}` write rule now rejects a `usernameLower` value it can't verify:
a write is allowed if `usernameLower` isn't in the resulting document, is
unchanged from what's already stored, OR a matching `usernames/{handle}` doc
claims that exact handle for the caller's own uid. That last check uses
`existsAfter()`/`getAfter()` rather than `exists()`/`get()` — `setUsername()`
claims the handle and writes the profile doc's `usernameLower` in the SAME
transaction, and a plain `exists()` only sees state as of the transaction's
*start*, before either write lands, which would have rejected every
legitimate call. `existsAfter()` sees the post-commit state, which is exactly
what's needed to check two documents written together for consistency.
Residual: this validates `usernameLower` only, not the cosmetic `username`
display field, since the client sources those two from different places
(`usernameLower` always from `setUsername`'s transaction; `username`'s exact
case/`@`-prefix form varies by caller) and pinning both exactly risked
breaking a legitimate write this pass couldn't fully enumerate. A spoofed
`username` alone (without a matching `usernameLower`) would not surface the
attacker in a search for the victim's handle, since `searchByUsername`
queries `usernameLower`.

`firestore.rules:105` is a bare `allow write: if request.auth.uid == uid;` with
**no field validation at all**.

`setUsername` (`profile_repository.dart:91-120`) takes real care to claim
`usernames/{handle}` in a transaction so handles are globally unique. But rider
search reads `users.usernameLower` directly, not the reservation collection
(`profile_repository.dart:257-259`). Nothing stops a client writing
`{'usernameLower': 'victimhandle', 'username': '@victimhandle'}` straight into
its own profile doc and skipping the transaction entirely. The impersonator
then appears in search for that handle, with a copied display name and avatar —
and search is exactly the flow used to pick who to follow and who to invite to
a group ride.

The same hole lets `publicStats` (`profile_repository.dart:160-180`) be set to
arbitrary distance / ride-count / badge values.

**Fix:** validate the write shape — reject `usernameLower` changes unless a
matching `usernames/{handle}` doc with `uid == request.auth.uid` exists.

### 24.6 A group-ride invitee can add arbitrary strangers to the ride — MEDIUM

**Status: FIXED 2026-08-12** (rules deployed 2026-08-14). The
"invitee accepts" clause now pins `invitedIds`' new value to exactly the old
list with the caller removed, via the same `hasOnly`/`concat` set-equality
idiom the `memberIds` half of the same clause already used (rather than the
unconfirmed `List.removeAll()` method, to stay on syntax already proven to
parse elsewhere in this file): new ⊆ old (nobody added) AND old ⊆ new + 
{caller} (nobody else removed). An accepting invitee can no longer inject
strangers into `invitedIds` (who'd otherwise immediately satisfy
`inGroupRide()` and gain read on every member's live position) or delete
other pending invitees in the same write.

`firestore.rules:659-666`, the "invitee accepts" clause, bounds `memberIds`
precisely but places **no constraint on the contents of `invitedIds`** beyond
requiring the caller remove themselves:

```
request.resource.data.diff(resource.data).affectedKeys().hasOnly(['memberIds', 'invitedIds']) &&
!(request.auth.uid in request.resource.data.get('invitedIds', [])) && ...
```

So an accepting invitee can rewrite `invitedIds` to any list of uids in the
same write. Everyone they add satisfies `inGroupRide()` and immediately gains
read on `groupRides/{id}/memberLocations/{uid}`
(`firestore.rules:739-742`) — **every member's live position**. They can also
delete other pending invitees.

This is the same bug class as §10, which was fixed by moving the roster out of
an array and into documents. It survived in the *invite* array, which that fix
didn't touch.

**Fix:** require `invitedIds` to be the old list minus exactly the caller.

### 24.7 Unbounded like / vote inflation — MEDIUM

**Status: FULLY FIXED AND DEPLOYED — like/vote half 2026-08-12, comment/reply
half 2026-08-14, both released to `throttleiqfb` on 2026-08-14. Note the
client half has not reached any device yet; see §24's top note for what that
breaks in the meantime.**
`rides/{rideId}`'s `likes` and `upvotes`/`downvotes` bumps, and
`forums/{forumId}/posts/{postId}`'s `upvotes`/`downvotes` bump, are now tied
to the SAME transaction creating/deleting the per-user doc they represent
(`likes/{uid}` or `votes/{uid}`), via two new helper functions
(`likeBumpValid`, `voteBumpValid`) using `existsAfter()`/`getAfter()` —
verified against the actual client: `RideShareRepository.toggleLike`/`.vote`
and `ForumRepository.votePost` already write the counter bump and the
per-user doc in one `runTransaction()` call each, so nothing in the app had
to change, only the rule. A client that bumps a counter alone, without the
paired subcollection write, or that loops the same bump repeatedly, now
fails this check (the "before" state has already changed after the first
successful call).

**Residual now CLOSED and deployed 2026-08-14** (the client half still has to
reach devices — see §24's top note). `rides/{rideId}.comments` and
`forums/{forumId}/posts/{postId}.replyCount` were the two counters left
untied, because `RideShareRepository.addComment()` and
`ForumRepository.addReply()` each wrote the counter bump as a SEPARATE call
from the comment/reply doc, giving `existsAfter()` no single commit to
inspect. Both are now `runTransaction()` calls that write the doc and the
bump together.

Tying the rule to them needed one extra step that likes/votes didn't: a
like/vote doc is keyed by the caller's uid, so the rule can reconstruct its
path, but a comment/reply gets an auto-generated id the rule cannot guess.
So the bump now carries that id — `lastCommentId` on the ride,
`lastReplyId` on the post — and a new `newDocBy()` helper requires that the
named doc (a) did not exist at the transaction's start, (b) exists after it,
and (c) has `userId == request.auth.uid`. Check (a) is what blocks a replay
that points the bump at a comment already sitting there; check (c) stops a
bump riding on someone else's concurrently-created comment.

The `replyCount` −1 path (deleteReply) is deliberately left untied to a
specific doc: it stays gated on author-or-moderator as before, and the §24.7
concern is inflation, not deflation — a delete batch carries no new id to
check anyway.

**Verified against the emulator.** `scripts/test/rules/firestore_rules.test.js`
covers this directly: the bump succeeds in its real transactional shape, and
is denied when sent alone, when it names a comment that already existed (the
replay), when it names a nonexistent comment, when it tries to move the count
by more than 1, when it smuggles another field along, and when the same id is
reused a second time. See §24.11 — writing those tests immediately caught two
further bugs.

The `places/{placeId}` rating-replay limitation this section's original
writeup cross-referenced remains exactly as documented at that rule (still
honestly flagged, still not fully closed, for the reasons given there).

The counter-bump rules (`firestore.rules:253-263` for rides, `:364-368` for
forum posts) let any viewer move each tally by ±1, but nothing ties the bump to
the `votes/{userId}` doc — the two writes aren't atomic and the rule never
checks the vote doc. A client loops the +1 update and drives any post to an
arbitrary score.

The in-rule comment claims "a voter can only ever nudge each tally by one."
True per request; there is no cap on requests. Same shape as the honestly
documented `places` rating-replay limitation at `firestore.rules:480-494`,
which is also still live.

### 24.8 Emergency contacts' phone numbers and emails go to Cloud Logging — MEDIUM

**Status: FIXED 2026-08-12.** `crash-notifications.ts` no longer logs
`contact.phone`, `contact.email`, the rendered SMS/email bodies (which
embedded the crash's GPS coordinates), or the contact's name — the one
`console.log` line that fires now names only the contact's Firestore doc id
and the ride id. `notificationLog` documents dropped `phone`/`email`/
`contactName` too, keeping `contactId` only (already sufficient to look the
contact back up if ever needed) — the same PII no longer lands at rest
either, not just out of logs. The SMS/email message content is still built
(a real Twilio/SendGrid call will need exactly that), it's just never
logged or persisted anymore.

Also fixed in the same pass, found while verifying this would actually
deploy: `functions/` had no `index.ts` and no `main` field in `package.json`
at all — `crash-notifications.ts`'s exports were never re-exported from
anywhere `firebase deploy --only functions` would look, so **nothing in this
directory could have deployed as written**, regardless of this fix. Added
`functions/src/index.ts` (re-exports everything) and
`"main": "lib/index.js"` in `package.json`. Compiles clean
(`tsc --noEmit`, verified in this session).

**Noted alongside, unchanged and NOT something a code fix can close:** the
entire crash-alert path is still a mock — `sendContactNotification` and
`scheduleEscalation` only log an attempt, nobody is actually contacted after
a detected crash. That needs real Twilio/SendGrid accounts and API keys,
which only the project owner can set up (see `HANDOFF_Document.md`'s "Soon"
section). Fixed what code alone could fix here: the Settings screen's
emergency-contacts description no longer claims contacts ARE notified —
"Notified if a crash is detected and you don't respond within 60 seconds."
was flatly false and is now "Logged if a crash is detected and you don't
respond within 60 seconds. Automatic SMS/email alerts aren't live yet." in
both `app_en.arb` and `app_bn.arb` (and their generated
`app_localizations_*.dart`, hand-edited to match since no Flutter SDK was
available in this session to run `flutter gen-l10n` — worth a real regen
next time the l10n toolchain is available, to confirm nothing else in that
generation step was missed).

`functions/src/crash-notifications.ts:119-120`:

```ts
console.log(`[MOCK] Sending SMS to ${contact.phone}: ${smsMessage}`);
console.log(`[MOCK] Sending email to ${contact.email}: ${emailSubject}`);
```

Third-party PII — contacts never consented to this app, and the SMS body also
carries the crash GPS coordinates — lands in Cloud Logging, retained by default
and visible to anyone with project Viewer. `sendContactNotification` also
persists `phone`/`email` into `users/{uid}/notificationLog`; that one is at
least unreachable from clients, since no rule matches the path.

**Noted alongside, and arguably the bigger problem:** the entire crash-alert
path is a mock. `sendContactNotification` and `scheduleEscalation` only log.
**Nobody is actually contacted after a detected crash.** That is already
tracked as a deploy task in `HANDOFF_Document.md` ("Soon → Cloud Functions"),
but it is worth stating in safety terms rather than deployment terms.

### 24.9 Lower-severity items

- **Android auto-backup left at default — FIXED 2026-08-12.**
  `AndroidManifest.xml`'s `<application>` tag now sets
  `android:allowBackup="false"`. That alone fully disables both Android's
  automatic cloud backup and `adb backup` extraction — no
  `dataExtractionRules`/`fullBackupContent` needed on top, since those only
  matter for fine-tuning what gets backed up when backup is otherwise on.
- **Cloudinary unsigned preset is client-extractable — NEEDS YOUR ACTION,
  not a code fix.** `cloudinary_upload_service.dart:29-30` hardcodes cloud
  name `vjvcigkt` and preset `throttleiq_unsigned`; that this is
  APK-extractable is expected for an unsigned preset, not itself a bug.
  What needs checking lives in the Cloudinary dashboard (Settings → Upload
  → Upload presets), which this agent has no login for: confirm the preset
  restricts resource type and file size and has moderation enabled, so a
  pulled preset can't be used for quota exhaustion or hosting arbitrary/
  illegal content. Tracked in `HANDOFF_Document.md`'s key-facts table too.
- **Email enumeration — NOT FIXED, left as-is on purpose.** `searchByEmail`
  (`profile_repository.dart:268-274`) still lets any authed rider confirm
  whether an arbitrary email is registered and pull the full profile —
  intentional per `firestore.rules:88-98` (find-by-email is an explicit
  product ask), unchanged by this pass. It's noted here because it's what
  makes §24.1's handles guessable in the first place — but §24.1's own fix
  (real opt-in + `shareable: true` gate) means a guessed/enumerated handle no
  longer resolves to a live position unless that specific rider chose to
  share that specific ride, which is the actual mitigation for the
  combination, not a change to email enumeration itself.
- **Attacker-controlled `userName` / `userPhotoUrl` on shared rides — FIXED
  IN CODE 2026-08-14, BLOCKED ON THE BLAZE UPGRADE TO ACTUALLY RUN.** The
  recommended fix from the previous pass (below) was implemented:
  `functions/src/ride-identity.ts` adds a `reconcileRideIdentity` trigger
  (`onWrite` on `rides/{rideId}`) that overwrites `userName`/`userPhotoUrl`
  from the authoritative `users/{uid}` profile doc. It writes back only when
  a field actually differs, which is what stops it recursing on its own
  correction; it no-ops on deletes, on rides with no usable `userId`, and on
  authors with no profile doc yet (leaving client values rather than blanking
  a legitimate rider's name). **It cannot deploy until the project is on
  Blaze** — see §24's top note — so in production this remains open exactly
  as described below. The residual trade-off is unchanged from the original
  recommendation: a spoofed name is visible in the feed for the brief window
  between the client's write and the trigger firing. Closing that window
  entirely would mean dropping the denormalized fields and joining against
  `users/{uid}` at read time.

  The original finding and the reasoning for not doing this in rules:
  `rides` create still pins only `userId`
  (`firestore.rules:235`); the denormalized display name/avatar on a feed
  card are still free-form. Investigated a rules-level fix (validate against
  `request.auth.token.name`/`.picture`, the ID token claims Firebase Auth
  sets from the same `displayName`/`photoURL` the client already reads) but
  didn't ship it: the four call sites that populate these fields
  (`ride_share_screen.dart`, `social_screen.dart`, `notifications_screen.dart`,
  `group_ride_map_screen.dart`) don't all source them the same way — some
  read `FirebaseAuth`'s `user.displayName`/`.photoURL` directly, `Profile
  Repository`'s own `displayName`/`photoUrl` fields (settable separately via
  `updateProfile`) can legitimately differ from those, and one call site
  passes empty strings outright. Getting a rule exactly right across all four
  without a way to test it end-to-end risked silently breaking legitimate ride
  sharing, which is a worse outcome than leaving a cosmetic (`userId` itself
  is still correctly pinned, so this is a feed-card impersonation, not an
  account-level one) impersonation vector open one more pass. That reasoning
  still holds — the trigger sidesteps the client-trust problem entirely,
  without needing a rule to reconcile four different call sites' conventions.
- **Admin check is an email-string comparison — FIXED 2026-08-12 (with a
  manual step still needed).** `isAdmin()` in `firestore.rules` now checks
  the `admin` custom claim (`request.auth.token.admin`) first, falling back
  to the email comparison only if that claim isn't set — so nothing broke
  before the claim actually exists. `scripts/oneoff/set_admin_claim.js` (new) grants
  it, mirroring `reset_beta_data.js`'s safety posture (dry-run default,
  project-id guard, requires real `GOOGLE_APPLICATION_CREDENTIALS`) — this
  agent could not run it, since it needs this project's own service-account
  credentials. **Still to do:** run
  `FIREBASE_PROJECT_ID=throttleiqfb node scripts/oneoff/set_admin_claim.js --email the.abraar.rar@gmail.com --yes-i-really-mean-it`,
  then sign out/in on that account to refresh its ID token. The email
  fallback in `firestore.rules` can be deleted once that's confirmed working.

### 24.10 `functions/` could not have been built or deployed — FIXED 2026-08-14 (deploy still blocked on Blaze)

Found while trying to verify §24.8's and §24.9's function code actually
compiles. §24.8 had already caught that there was no `index.ts` entry point;
underneath that were two more problems, either of which would have failed a
deploy on its own:

- **`typescript` was never a dependency.** `package.json` declared
  `"build": "tsc"` but listed no `typescript` (and no `@types/node`) in
  `devDependencies`, and `functions/node_modules` did not exist at all. `npm
  run build` could only ever have failed. Both are now declared and installed,
  and `functions/package-lock.json` is committed alongside them.
- **`firebase.json` had no `predeploy` hook for functions.** Without it,
  `firebase deploy --only functions` ships whatever is in `functions/lib/`
  rather than building first — and `lib/` did not exist, while
  `package.json`'s `"main"` points at `lib/index.js`. Added the standard
  `npm --prefix "$RESOURCE_DIR" run build`. `functions/lib/` is now gitignored,
  since `functions/src/` is the source of truth.

Verified: `npm run build` produces `lib/crash-notifications.js`, `lib/index.js`
and `lib/ride-identity.js`, and `tsc --noEmit` is clean.

**Still blocked:** none of this can reach production until the project is on
the Blaze plan (see §24's top note). `firebase deploy` fails at
`artifactregistry.googleapis.com` enablement, which Spark does not permit.

Note also `firebase.json` sets `"runtime": "nodejs_20"`, with an underscore;
the conventional spelling is `nodejs20`. Left alone rather than changed blind —
the deploy that failed had already parsed the config and moved on to API
enablement, so it is at worst ignored, and there is no way to confirm the fix
here while deploys are blocked. Worth checking on the first successful deploy.

### 24.11 Two bugs the new rules test harness immediately caught — FIXED 2026-08-14

§24.7's writeup said the new clauses were "not verified against an emulator"
because there was no Java runtime. That turned out to be wrong in a useful way:
there IS a JVM on this machine, inside Android Studio's bundled JBR —
`HANDOFF_Document.md`'s own `keytool` note (added 2026-08-11) points at it.
Pointing `JAVA_HOME` there runs the Firestore emulator fine.

So there is now a real rules test suite: `scripts/test/rules/firestore_rules.test.js`,
19 tests, run with `npm run test:rules` from `scripts/`. It lives under
`test/rules/` rather than `test/` on purpose — `npm test`'s glob is
`test/*.test.js`, deliberately non-recursive, so the pure-function tests keep
running with no emulator involved.

Writing the tests found two bugs within minutes, both of which had been
deployed live on 2026-08-14:

- **A rider could not delete their own reply on someone else's post — live
  breakage, not just a security gap.** The `replyCount` −1 clause read
  `resource.data.userId == request.auth.uid || canModerateForum(forumId)`, but
  in that clause `resource` is the POST, so it checked the POST's author. Any
  rider deleting their own reply on a post they didn't write had the entire
  batch denied. Fixed by tying the −1 to the reply doc actually being deleted
  in the same batch (new `docRemoved()` helper, mirroring `newDocBy()`), and
  delegating *who may delete* to the reply's own `allow delete` rule — which
  runs in the same batch, so an unauthorized deleter never reaches the
  decrement either. `ForumRepository.deleteReply()` now sends `lastReplyId`
  alongside the decrement.
- **`isAdmin()` threw an evaluation error on any token without an
  `email_verified` claim.** It read `request.auth.token.email_verified`
  directly; on a token lacking the claim that is an ERROR, not `false`. Since
  `canModerateForum()` is `isAdmin() || (creator/maintainer check)`, the error
  took down the whole expression *before* the branch that should have allowed
  the write — so a legitimate forum creator or maintainer signing in by any
  non-email method could not moderate. Fixed with the
  `.get('email_verified', false)` / `.get('email', '')` form. The regression
  test asserts a forum creator can moderate on a token with no email claims.

Both fixes are in the same undeployed batch as §24.7's, and inherit the same
ordering constraint (see §24's top note): `deleteReply`'s `lastReplyId` is a
new client field, so the rules must not go out ahead of the app build.

### What the audit found clean

Worth recording so the next pass doesn't re-derive it:

- `public/live-viewer.html` uses `textContent` for all remote data and
  validates the handle against `HANDLE_RE` before using it as a document id —
  no XSS. The only `innerHTML` write is a constant install-CTA string.
- All SQLite access uses parameterised `whereArgs`. No string-interpolated SQL
  outside schema DDL.
- Signing secrets are correctly excluded: `throttleiq-release.keystore` and
  `app/android/key.properties` are gitignored (`.gitignore:82-86`) and appear
  nowhere in git history.
- `reset_beta_data.js` has a genuinely careful safety posture (dry-run default,
  project-id guard checked twice, idempotent).
- No `badCertificateCallback` / `HttpOverrides`, no cleartext endpoints.

---

## 25. Ending or sharing a ride was impossible offline — awaiting a Firestore write never returns (2026-08-14)

**Status: FIXED 2026-08-14.** Reported from real use: *"I can't share rides or
end when offline."*

### Why it happened

A Firestore write issued with no connection does **not** fail. The SDK accepts
it into its own local mutation queue and the returned `Future` stays unresolved
until a server acknowledges it — which, offline, is never. So this shape:

```dart
try {
  await _firestore.collection('livePointers').doc(uid).set({...});
} catch (e) {
  print('Failed to clear live pointer: $e');   // never runs
}
```

...does not degrade gracefully. It hangs, forever, and the `catch` that looks
like it's handling the offline case handles nothing. Every one of these writes
was already wrapped in `try`/`catch` and commented as "best effort", which is
exactly why the bug survived review: the code reads as if it tolerates failure,
and the failure mode it doesn't tolerate is *not failing*.

`stopRide()` hit this on `_clearLivePointer()`, which runs for **every** rider
with a uid — not just those who shared their location. Everything after it (the
local `finalizeRide`, the bike odometer bump, the summary screen) was
unreachable, so ending a ride offline did nothing at all. `shareRide()` hit the
same wall on its `docRef.set(...)`, leaving the composer spinning.

Three more instances of the same shape were found while fixing it, none of them
reported yet but all of them live:

- `restoreInterruptedRide()` awaited `_clearLivePointer()` — so recovering a
  ride the app died during stalled offline, which is precisely when a rider is
  likely to be out of coverage.
- `dismissCrashAlert()` awaited a `falseCrashPositives` telemetry write
  **before** setting the ride back to active. Dismissing a false crash alarm in
  a dead spot left the ride stuck in the crash state.
- `_handleCrashNotification()` awaited the `crashNotifications` write that
  triggers the alert Cloud Function.

### The fix

Two layers, because the two cases want different things:

1. **A durable outbox** (`core/cloud/outbox_service.dart`, `outbox` table added
   in DB **v10**) for operations the rider explicitly asked for and must not
   lose: sharing a ride, and the end-of-ride live-share teardown. The intent is
   written to SQLite *before* any network attempt, so it survives being killed;
   `SyncManager` drains it on every connectivity change, on login and on its
   5-minute timer, ahead of the bulk ride/bike sync. Entries back off
   exponentially (30s → 30min cap) and are keyed by ride/uid so re-queuing
   supersedes rather than double-posting.
2. **A bounded `_bestEffortWrite()`** for genuinely optional telemetry (crash
   samples, live-session status pings). Same `try`/`catch`, now with a
   `.timeout()` so "best effort" actually means it. Note the timeout does not
   cancel anything — the Firestore SDK still delivers the write when signal
   returns. We only stop waiting.

Photo uploads needed one extra turn: Cloudinary mints a *new* asset per call, so
a retry that re-uploaded would orphan the first copy and burn quota. The queued
share therefore carries local file paths, and each URL is folded back into the
row's payload as it lands, so a retry resumes after the uploads instead of
redoing them.

The share composer now says **"Saved — we'll post it when you're back online"**
rather than reporting a failure, because it isn't one.

### What is verified, and what isn't

Verified: 20 new tests (`test/core/cloud/outbox_test.dart`,
`test/database/outbox_migration_test.dart`) covering queue durability,
supersede-on-requeue, ordering, backoff bounds, corrupt-payload tolerance, and
the **v9 → v10 migration on the real upgrade ladder** rather than through
`_onCreate`. That last one matters: a broken migration sends `_initDb` into its
corrupt-file rescue, which deletes the database and every stored ride with it.

**Not verified: actual offline behaviour on a device.** The delivery paths need
a real Firestore, and the failure being fixed is a *timing* property of the
network SDK. Someone should fly-mode a phone and confirm end-ride, share, and
resume all complete promptly, then re-enable data and confirm the queue drains.

---

## 26. A ride killed in its first seconds was deleted, not resumed (2026-08-14)

**Status: FIXED 2026-08-14.** Same report as §25: *"when I'm riding and
accidentally close the app, the data is lost."*

Ride resume already existed and is genuinely thorough —
`RideRecordingNotifier.restoreInterruptedRide()` rebuilds distance, top speed,
moving time, route and ride clock from the persisted fixes and hands the rider
a *paused* session to resume, end, or discard (see `ride_resume.dart`). The
trigger is sound too: `restoreInterruptedRide()` runs off the `authStateProvider`
listener in `app.dart`, and since that listener is what first creates the
provider, the loading → signed-in transition cannot be missed.

What was actually losing data was the write cadence underneath it:

- **GPS fixes were batched 5-at-a-time (or every 3s).** Until the first flush
  they existed only in memory. And `restoreInterruptedRide()` *deletes* any ride
  with fewer than 2 stored points, on the reasonable grounds that no distance is
  derivable from one. So an app killed in the opening seconds didn't lose a
  little tail — it lost the entire ride, deliberately. Fixed with an early-ride
  window (`_earlyRideFlushUntil = 8`): every fix is written through until the
  ride has 8 persisted points, then normal batching resumes so a long ride
  isn't doing an SQLite write per fix. A restored ride re-enters that window,
  since a ride the app already died during is the one to be careful with.
- **`_flushPointBuffer()` was fire-and-forget.** It never awaited the insert, so
  a failure vanished silently and `stopRide()`/`pauseRide()` could finalize a
  ride before its last fixes were committed. It now awaits, and on a failed
  insert puts the batch back at the front of the buffer so the next flush
  retries rather than leaving a hole in the trace.

**Still a documented limitation, unchanged:** event counts (hard-brake /
rapid-accel / high-jerk) and the fitted accelerometer axis are in-memory only
and restart at 0 on a resume. They can't be honestly reconstructed from thinned
points — see `ride_resume.dart`'s class doc.

**Not verified on a device.** The fix is a durability property of process death,
which the test suite can't stage. Worth confirming by hand: start a ride, force-
kill the app after ~5 seconds, reopen, and check the ride comes back rather than
vanishing.

---

## 27. `AndroidManifest.xml` declares a foreground service class that doesn't exist (2026-08-15)

**Status: FIXED 2026-08-15** — found while assessing background auto-tracking,
removed the same day. The `<service>` block is gone, replaced by a comment
explaining where background GPS actually comes from so the next person doesn't
re-add it. Verified against the shipped artifact rather than the source: the
`app-release.aab`'s merged bundle manifest declares 18 services, none of them
this one, and geolocator's `com.baseflow.geolocator.GeolocatorLocationService`
is present as expected.

`AndroidManifest.xml:63-66` declares:

```xml
<service
    android:name="com.bft.throttleiq.LocationForegroundService"
    android:exported="false"
    android:foregroundServiceType="location" />
```

There is no such class. `android/app/src/main/kotlin/com/bft/throttleiq/` contains
only `MainActivity.kt`, `WidgetKeys.kt` and the three widget providers — nothing
named `LocationForegroundService`, in Kotlin or Java, anywhere in the repo.

**Why it hasn't crashed anything:** nothing starts it. Background location
during a ride is actually handled by **geolocator's own** foreground service,
configured via `ForegroundNotificationConfig` in
`ride_recording_provider.dart:508`. The declaration is dead config. If anything
ever *did* call `startService` on it, that's an immediate
`ClassNotFoundException`.

**Why it still matters, and why it's worth fixing before the Play submission:**
it is a `foregroundServiceType="location"` declaration, and together with
`ACCESS_BACKGROUND_LOCATION` it is part of what Google reviews under the
Background Location Access declaration (see `HANDOFF_Document.md`'s Play Store
note). Declaring a location foreground service the app does not implement is
exactly the kind of mismatch that draws a rejection or a "please explain" round
trip, and it costs nothing to remove.

**Fix:** delete the `<service>` block, unless a real
`LocationForegroundService` is about to be written — see the auto-tracking plan
in `HANDOFF_Document.md`, where a purpose-built one is Step 3. Removing it does
not affect current behaviour; geolocator's service is untouched by it.

---

---

## 28. Downloaded rides don't reach the UI until the app is restarted (2026-08-17)

**Status: Fixed.** Surfaced by running the app on the iOS simulator, signed
into the same account as the project owner's phone: the phone reported 43
rides / 119 km, the simulator showed 20 rides / 26 km and appeared never to
catch up.

**It was not a sync gap.** An earlier pass of this writeup blamed
`uploadRides`' all-or-nothing batch and asked for a Firestore doc count to
confirm. Dumping the simulator's actual sqflite file settled it instead, and
the answer was the opposite of the guess:

```
sqlite3 .../Documents/throttleiq.db \
  "SELECT count(*), round(sum(distance_m)/1000,1) FROM rides WHERE status='completed';"
42|119.0
```

The rows were **already on the device**. Meanwhile the running app rendered
25.72 km / 20 rides / "14d last ride", with both charts ending 2 Aug. And:

```
  "... AND created_at <= '2026-08-03';"   →   20|25.72
```

The on-screen figures were exactly a **chronological prefix** of the local
table. That is the tell: `downloadRides` iterates `snap.docs`, which Firestore
returns in document-id order, and ids are random UUIDs — so *no* failure
inside that loop can produce a clean date-ordered subset. Nothing was missing
and nothing was failing. The UI was showing a pre-download snapshot of a table
that had since been filled in.

**Root cause (`sync_manager.dart:125-128`):** `_performSync` discarded
`downloadRides`' return value and invalidated exactly one provider, only when
*bikes* were pulled:

```dart
final pulledBikes = await _cloudRepository.downloadBikes(uid);
await _cloudRepository.downloadMaintenance(uid);
await _cloudRepository.downloadRides(uid);      // return value dropped
if (pulledBikes) _ref?.invalidate(garageProvider);
```

`riderStatsProvider` watches `currentUserProvider` and `garageProvider` and
nothing else, so it re-read the rides table only as a side effect of a bike
being pulled down. On this simulator all 5 bikes were already local, so
`pulledBikes` was `false` — the one case where the invalidate is needed is the
one case it didn't fire. The stat strip, the rides list and the badge counts
all kept serving the value computed during startup, before that cycle's
download finished, and only a full app restart cleared it. On a device that
happened to pull a bike in the same cycle the bug is invisible, which is why
this survived the earlier download-sync work.

**Why it read as a sync bug:** every symptom of a stale provider and a stalled
upload is identical from the outside — a second device showing fewer rides
than the phone, indefinitely, with no error anywhere. The distinguishing
evidence isn't in the code at all, it's the *shape* of the subset: date-ordered
means presentation, id-ordered or random means transport. Worth reaching for
the on-device database before theorising next time; on the simulator it's a
plain file at
`~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Data/Application/<APP>/Documents/throttleiq.db`
and `sqlite3` answers in seconds what static reading could not.

**Fixed:**

- `sync_manager.dart` now keeps `downloadRides`' return value and invalidates
  `riderStatsProvider` and `rideHistoryProvider` when it's true. Deliberately
  keyed off the download's own result rather than `pulledBikes`.
- `sync_manager.dart` fetches unsynced rides via `RideDao.getUnsynced()`
  instead of querying `synced = 0` directly. The direct query skipped the
  DAO's `status = 'completed'` filter, so in-progress and abandoned rides were
  uploaded too — six zero-distance `active` rows had already reached Firestore
  and been pulled back down onto the simulator. They never affected the totals
  (the stats query filters on `completed`) but they are junk in the cloud, and
  a ride still being recorded could sync a half-written row.
- `uploadRides` keeps the single batch as its fast path but now falls back to
  per-ride writes when the batch throws, logging the offending ride id and
  Firestore's reason. The batch hazard described in the earlier writeup was
  never what happened here, but it is real and cheap to close: `firestore.rules`
  grants the owner blanket write on `users/{uid}/rides` and every column in the
  table is a scalar, so a rejection is unlikely — not impossible.
- `downloadBikes` / `downloadRides` / `downloadMaintenance` wrap each insert
  in its own try/catch. `rides.bike_id` is a FOREIGN KEY and
  `database_helper.dart:68` sets `PRAGMA foreign_keys = ON`, so a ride whose
  bike was skipped by the tombstone check *would* have aborted the loop and
  silently dropped every doc behind it.
- `print('Sync error: $e')` → `debugPrint` with a `[SyncManager]` tag and a
  stack trace. The bare print with no stack is a large part of why this took a
  database dump to diagnose.

**Separately:** the same session found the simulator's main "Places" tab
empty. That looks environmental, not a data bug — `nearbyPlacesProvider`
(`places_provider.dart:54-63`) depends on a real device GPS fix within 25 km
(`currentPositionProvider`), and a simulator has no location until one is set
via *Simulator → Features → Location*. "My places" (self-added, reached from
the garage menu) reads Firestore directly by uid with no location dependency
and should already match across devices — worth a separate look only if it's
*also* empty after confirming the account matches.

---

## 29. The auto-tracking working tree didn't compile — four separate breaks, none caught by `flutter analyze` alone (2026-08-17)

**Status: Fixed.** The previous session's auto-tracking feature work (see
`auto_tracking_plan.md`) and the §28 sync fix landed in the working tree
uncommitted and unbuilt — its own writeup said the Flutter SDK wasn't
reachable from that sandbox, so nothing past `flutter analyze` had run. This
session had a real `flutter` on `PATH` and used it: `flutter analyze` alone
showed 0 errors, but `flutter build ios --simulator` and `flutter build apk
--debug` each failed on their first try, on things a Dart-only check cannot
see.

**1. `pubspec.yaml` had dropped `url_launcher`** while
`place_detail_screen.dart` still imports it for the Directions/Call actions
(`launchUrl`, `LaunchMode`). `flutter analyze` didn't catch it because pub's
lockfile still had the package cached from before the removal; `pub get`
would have failed loudly the moment someone ran it clean. Restored the
dependency.

**2. `notification_service.dart`'s `zonedSchedule` call was missing
`uiLocalNotificationDateInterpretation`**, a required named parameter on
`flutter_local_notifications` 17.2.4 (confirmed by reading the installed
package source directly, not assumed from a version number). Added it.

**3. The v11 migration's new columns weren't idempotent.** Every other step
in `_onUpgrade`'s ladder uses `CREATE TABLE IF NOT EXISTS`, specifically so a
re-run is survivable rather than a crash — the test suite has its own case
enforcing that invariant (`outbox_migration_test.dart`, "the upgrade is
idempotent if it runs twice"). The new `is_auto`/`bike_confidence` columns
used a bare `ALTER TABLE ADD COLUMN`, which has no `IF NOT EXISTS` in SQLite
and threw `duplicate column name` the moment that test exercised it. Added
`_addColumnIfMissing()` (checks `PRAGMA table_info` first) and routed both
columns through it.

**4. Two Android-only Gradle failures**, invisible from the Dart side
entirely:
- `flutter_background_geolocation`'s transitive `android-permissions`
  library declares its own `android:label`, colliding with the app's during
  manifest merge. Fixed with `xmlns:tools` + `tools:replace="android:label"`
  on `<application>`.
- Two plugins resolved different `androidx.work` versions
  (`work-runtime:2.8.1` vs `work-runtime-ktx:2.7.1`), which `checkDebugDuplicateClasses`
  rejects outright. Forced both to `2.8.1` via `resolutionStrategy` in the
  root `build.gradle.kts`.

**Verified after all four fixes:** `flutter pub get`, `flutter analyze` (0
errors), `flutter test` (797/797), `flutter build ios --simulator`,
`flutter build apk --debug`, and a live `flutter run` on the iOS simulator —
which also gave §28's fix its first runtime confirmation: the stat strip
reads **42 rides / 119 km**, matching the sqlite dump in §28 rather than the
stale 20/25.72 prefix.

**Why this matters beyond this one tree:** `flutter analyze` is a Dart-only
static check. It cannot see a lockfile masking a removed pub dependency, a
plugin's required-parameter change across a version bump, a SQL statement
that only fails on a second execution, or anything in `android/` at all.
"Analyze is clean" and "it builds" are different claims — when a change
touches native config, plugin versions, or a migration ladder, a real
`flutter build`/`flutter test` pass is the only thing that actually checks it.

---

## 30. `Runner.xcodeproj` had no `DEVELOPMENT_TEAM` anywhere — device release builds failed outright, and the widget App Group silently had no members (2026-08-17)

**Status: Fixed.** Surfaced trying to build a release for a physical device
(Abraar's iPhone, cabled) for the first time since §29 added the
`ThrottleIQWidget` target and its App Group entitlement. `flutter build ios
--release` failed with `Signing for "Runner" requires a development team`.
Simulator builds never need one, which is exactly why this had gone
unnoticed through every earlier `flutter build ios --simulator` check this
session.

Forcing it with `xcodebuild ... -allowProvisioningUpdates` (the CLI
equivalent of Xcode's automatic-signing "just fix it" button) failed
differently: `No Account for Team "29BPVM86G5"`. That team ID was read off
the local codesigning identity's display name
(`Apple Development: abraar.rar@icloud.com (29BPVM86G5)`) and looked like a
team ID, but Xcode had no account for it — the real team, found in Xcode's
own `IDEProvisioningTeamByIdentifier` preference, is `NJ4675FFUX` ("Abrar
Masud Nafiz (Personal Team)").

**The part that would have shipped silently broken:** cached provisioning
profiles for both `com.bft.throttleiq` and `com.bft.throttleiq.ThrottleIQWidget`
already existed on disk (`~/Library/Developer/Xcode/UserData/Provisioning
Profiles/`), generated before the App Group entitlement existed — their
`com.apple.security.application-groups` entitlement was an **empty array**.
Nothing about a build using those stale profiles would have failed or
warned; the widgets would have installed, appeared in the picker, and shown
their placeholder text forever, exactly the failure mode §29's iOS README
warns about, just with no error to point at it.

**Fixed:** set `DEVELOPMENT_TEAM = NJ4675FFUX` on all three targets (Runner,
ThrottleIQWidget, RunnerTests), all three configurations, via the same
`xcodeproj` Ruby-gem scripting used in §29. With the team set,
`-allowProvisioningUpdates` regenerated both App IDs' provisioning profiles
for real — confirmed the new `ThrottleIQWidget` profile carries
`com.apple.security.application-groups: [group.com.bft.throttleiq]`, where
the stale one had none.

**Verified:** `xcodebuild -workspace Runner.xcworkspace -scheme Runner
-configuration Release -destination 'generic/platform=iOS'
-allowProvisioningUpdates build` succeeds; the resulting `Runner.app`
installed via `xcrun devicectl device install app` and launched via
`xcrun devicectl device process launch` on Abraar's iPhone, confirmed
running (non-zero PID in `devicectl device info processes`). This is the
first time the widget App Group has been exercised on real signing rather
than the simulator's no-team `<dict/>` entitlements — see §29's caveat about
`codesign -d --entitlements` showing empty on a team-less build.

**Caveat this "Verified" note doesn't cover (as originally written):** only
process launch was confirmed above — nobody actually long-pressed the home
screen and added a widget from the picker after the fix. Reported same day:
the widget still wasn't offered in the **+** gallery on Abraar's phone.

**Resolved same day, a few hours later.** Cause was exactly guess (1) above:
`xcrun devicectl device info apps` showed the phone was still running
**build 3** (`beta-v3`, from Aug 15) — installed before this section's fix
even existed, not after it. Nothing had reinstalled since. Fix: `xcrun
devicectl device uninstall app com.bft.throttleiq`, then a fresh `flutter
build ios --release` from current `main` and a clean `devicectl install`.
Confirmed this time with more than a process check: `codesign -d
--entitlements` on the freshly built `.app` and its `.appex` both show the
real `group.com.bft.throttleiq` entitlement (not the stale empty one), and
`devicectl device info processes` lists **`ThrottleIQWidget.appex`'s own
process running** alongside `Runner` — WidgetKit only spins up the extension
process to snapshot it for the gallery, so that's the extension being live
and discoverable, not just the host app. No iOS UI-automation tool exists to
literally tap "long-press → + → search" on a physical device, so the very
last visual step is still the account owner's to eyeball, but every
technical precondition for it now checks out.

---

## 31. Android home-screen widgets, verified end-to-end on an emulator for the first time (2026-08-17)

**Status: Verified working.** Unlike iOS, an Android emulator (`Pixel_10_Pro`
AVD) is fully drivable headlessly via `adb`, so this got a real visual check
rather than just a package-manager/entitlement inspection. `adb shell
dumpsys package com.bft.throttleiq` confirmed all four `AppWidgetProvider`s
registered (`StartRideWidgetProvider`, `RideStatsWidgetProvider`,
`MaintenanceWidgetProvider`, `AutoTrackingWidgetProvider`). Then, via `adb
shell input` long-press + tap sequences plus `adb exec-out screencap`
screenshots read back frame-by-frame: opened the launcher's Widgets sheet,
browsed to **ThrottleIQ → 4 widgets**, and expanded it — Start Ride and
Auto-Track render their real carbon-mono preview art, and **Ride Stats shows
the `—` / no-data placeholder correctly** rather than a blank box, matching
`ios/ThrottleIQWidget/README.md`'s data-contract requirement (that file
documents the iOS side of the same four widgets; the Android providers share
the same `ti_*` `SharedPreferences` keys via `WidgetKeys.kt`). Did not drag a
widget onto the home screen itself (the launcher's drag gesture is fragile
over `adb input swipe` and the picker rendering real, non-placeholder-broken
previews is equivalent proof) — everything short of that one drag gesture
was directly observed, not inferred from logs.

---

---

## 33. Bug & vulnerability sweep — 5 parallel reviews, 18 findings, 16 fixed same session, 2 deferred (2026-08-23)

**Status: 16/18 FIXED, code + rules + admin script, same session as the
review.** The remaining 2 (§33.5, and half of §33.6) are documented as
deferred with why — see their sections. Read-only review first (five
independent passes — Firestore/Storage rules + Cloud Functions + admin
scripts; auth + cloud-sync; social sharing/live-viewer/location-privacy;
external API integrations + uploads; ride-tracking domain calculators +
local DB), then every fixable finding fixed and verified in the same pass.
Findings below, ranked by severity, numbered §33.1+ so they can be cited
individually. Two were launch-blocking in the same way §24.1/§24.2 were —
both now fixed.

Verification: `flutter analyze` clean (same pre-existing style-only noise
as before §33, no new errors), `flutter test` **809/809** (was 804 — added
`app/test/database/ride_dao_sync_and_finalize_test.dart`, 5 tests, real
in-memory SQLite, covering §33.1/§33.3), `npm run test:rules` **32/32** (was
19 — added 13 tests in `scripts/test/rules/firestore_rules.test.js` covering
§33.2/§33.4/§33.18), `node --check` clean on both edited scripts. Nothing
here has been run against a real device or a live Firebase project — same
caveat as every other rules/Functions change in this file; deploy still
needs `firebase deploy --only firestore:rules` (and eventually `storage`)
before any of the rules fixes protect a real rider.

> Still open from this section: 33.5. That part is in `issues_open.md` under §33. The rest of 33.6 is obsolete (end of this section).

### 33.1 Signing out doesn't clear local data — next user on a shared device can upload the previous rider's data to their own account — CRITICAL

**Status: FIXED.** `RideDao.getUnsynced()` now takes a `userId` and filters
`WHERE user_id = ?` (`ride_dao.dart`); `SyncManager._performSync` passes the
current `uid` into it and added the same filter to the bikes query and a
`bikes` JOIN to the maintenance-logs query (`maintenance_logs` has no
`user_id` column of its own), so a sync can only ever upload rows owned by
whoever is currently signed in. `AuthNotifier.signOut()` also now calls
`GoogleSignIn().signOut()` (see §33.10) but deliberately does NOT wipe the
local DB — that would destroy exactly the offline durability the outbox/
local-first design exists for on every ordinary sign-out; a different
rider's still-unsynced rows are simply left alone until that rider signs
back in on this device. `MaintenanceDao.getUnsynced()` — the same unscoped
shape, but with zero call sites — was deleted outright rather than fixed,
since nothing used it. New regression tests:
`app/test/database/ride_dao_sync_and_finalize_test.dart`.

`AuthNotifier.signOut()` (`app/lib/features/auth/presentation/providers/auth_provider.dart:112-115`)
only calls `_auth.signOut()` — it never touches the local SQLite DB. The
"unsynced" queries never filter by `user_id`, despite the column existing:
`RideDao.getUnsynced()` (`ride_dao.dart:47-49`) and the bike/maintenance
queries in `SyncManager._performSync` (`sync_manager.dart:160-171`) just grab
every `synced = 0` row and hand it to `CloudRepository.uploadRides/
uploadBikes/uploadMaintenance`, which write to `users/{uid}/...` for
whichever `uid` is *currently* signed in (`cloud_repository.dart:69,109,127`).

Concrete scenario: Rider A records offline on a shared/demo device, signs out
before connectivity returns; Rider B signs in; B's next sync cycle uploads
A's still-unsynced rides/bikes/maintenance logs — full GPS tracks included —
into `users/{B}/...`. A real confidentiality break, reachable through normal
app use, no exploit tooling needed. Fix: scope every "unsynced" query by
`user_id = currentUser.uid`, and have `signOut()` purge or uid-tag local rows
before the next sync.

### 33.2 Live-location share links never expire server-side — CRITICAL

**Status: FIXED** (rules changed, NOT yet deployed — see §33's verification
note). `firestore.rules`' `liveSessions/{token}` `allow get` now also
requires `resource.data.get('expiresAt', request.time) > request.time` —
same fail-closed default pattern as the existing `shareable` check, so a
legacy doc with no `expiresAt` at all reads as already-expired rather than
as open. New tests in `firestore_rules.test.js`: an unexpired shareable
session is readable unauthenticated; an expired one is denied even with
`shareable: true`; a session with no `expiresAt` field is denied.

`firestore.rules:341` — `allow get: if resource.data.get('shareable', false)
== true;` — never checks `expiresAt`. The 24h expiry in
`public/live-viewer.html:612-624` is enforced only in client-side JS; the
file's own comment admits "nothing sweeps expired docs." Anyone who ever
received a `/live/{token}` link can hit the Firestore REST API directly with
that token forever and keep reading the rider's live lat/lng, speed, and
status long after the app claims the link "expired." For a location-sharing
feature on a motorcycle app this is a stalking/safety exposure, not a
data-hygiene nitpick.

### 33.3 Crash detection is silently broken — `RideDao.finalizeRide` always forces status to `'completed'` — HIGH

**Status: FIXED.** `finalizeRide` now spreads `data` OVER a `'status':
'completed'` default (`{'status': 'completed', ...data, 'synced': 0}`)
instead of after it, so a caller-supplied status wins while the normal
end-of-ride call (which passes none) still defaults correctly. New
regression tests in `ride_dao_sync_and_finalize_test.dart` cover all three
real call sites' shapes: no status passed (defaults to completed), `'crash'`
passed (persists), `'active'` passed after a crash (persists).

`ride_dao.dart:37-45`:
```dart
Future<void> finalizeRide(String id, Map<String, dynamic> data) async {
  await db.update('rides', {...data, 'status': 'completed', 'synced': 0}, ...);
}
```
The map-literal spread means the trailing `'status': 'completed'` always wins
over whatever `data['status']` was. `_onCrashDetected()` writes
`{'status': 'crash'}` and `dismissCrashAlert()` writes `{'status': 'active'}`
(both in `ride_recording_provider.dart`) — both get silently overwritten to
`'completed'`. A crashed, still-recording ride gets marked "completed"
mid-ride (shows up that way in history/feed, and `restoreInterruptedRide()`
won't offer to recover it if the app dies before the rider actually stops); a
false-positive crash dismissal leaves the DB permanently "completed" while
recording continues. `status: 'crash'` is never actually persisted anywhere
today.

### 33.4 Any signed-in user can inject spoofed notifications into another user's feed — HIGH

**Status: FIXED** (rules changed, NOT yet deployed). The `notifications`
create rule now restricts `type` to `['follow', 'groupRideInvite']` (the
only two `NotificationType` values the app writes), requires `fromName` to
be a non-empty string ≤100 chars, and — the concrete tracking-pixel vector —
requires `fromPhotoUrl` (when present and non-empty) to match a domain
allowlist: this project's own Cloudinary cloud name or Google's account-
picture host. A `groupRideInvite` must also carry a non-empty
`groupRideId`. Deliberately NOT fixed: matching `fromName` against the
sender's real profile, which would mean replicating
`UserProfileEntity.bestName`'s nickname → displayName → @username fallback
chain inside a rule — fragile to keep in lockstep, and risks silently
breaking real follow/invite notifications if it drifts from the client. A
spoofed display *name* (not a URL the victim's device fetches automatically)
is treated as a residual, lower-severity risk, same tier as any other
free-text social content this app carries. Seven new tests in
`firestore_rules.test.js` cover valid follow/invite shapes, the unknown-type
rejection, the non-allowlisted-photo rejection, the missing-groupRideId
rejection, and that `fromUid` still can't be spoofed.

`firestore.rules:302-306` only checks `request.resource.data.fromUid ==
request.auth.uid` — the target `{uid}` path segment (whose subcollection is
being written to) is unconstrained, and `fromName`/`fromPhotoUrl`/`type` are
all client-controlled with no validation. `notifications_screen.dart` renders
`fromName` verbatim and feeds `fromPhotoUrl` into `UserAvatar`, which fetches
it unconditionally. Any signed-in attacker can flood an arbitrary victim's
notifications with spoofed sender text, or use `fromPhotoUrl` as a "victim
just opened the app" tracking beacon. Fix: require `fromName`/`fromPhotoUrl`
to match `get(/databases/$(database)/documents/users/$(request.auth.uid))`,
and restrict `type` to a known enum.

### 33.7 Dead `PrivacyZone.clipPrivacyZones` fails open — latent landmine — MEDIUM

**Status: FIXED — deleted.** Zero call sites (confirmed via grep before
deleting), so rather than patch a fail-open landmine nobody was tripping
over yet, `app/lib/core/utils/privacy_zone.dart` was removed outright.
`PrivacyZoneClipper` (`privacy_zone_clipper.dart`) is the one actually wired
into sharing and already fails closed — nothing else to point future code
at now.

`app/lib/core/utils/privacy_zone.dart:60-62` returns the **full, unredacted
polyline** (home location included) when a ride is too short to clip 200m
from both ends. The class actually wired into sharing,
`privacy_zone_clipper.dart`'s `PrivacyZoneClipper`, fails *closed* in the same
situation (`return []`). `PrivacyZone.clipPrivacyZones` has zero call sites
today (confirmed via grep) — not currently exploitable — but it's a trap for
the next feature (export, thumbnail, PDF report) that reaches for "the
privacy clipper" and picks this class instead.

### 33.8 `EventDetector` jerk-spike gating bug inflates false-positive crash detection — MEDIUM

**Status: FIXED.** `_peakJerkInWindow` now only updates while
`_highAccelStart != null` (a spike window is actually open) — a jerk
reading before any accel spike no longer counts toward it. Verified against
the existing `crash_detector_test.dart` suite (all 8 cases, including "DOES
fire on crash," still pass — that scenario's jerk sample arrives on the same
call as a continuing accel window, so it's unaffected).

`event_detector.dart:88-94` updates `_peakJerkInWindow` on every call with a
high jerk reading regardless of whether an accel-spike window
(`_highAccelStart`) is actually active. A jerk spike seconds before an
unrelated high-accel event can still count as "in window," inflating
false-positive crash detections (which trigger the 60s countdown and
emergency-contact escalation).

### 33.9 `DatabaseHelper._initDb` nukes the entire local DB on any exception, not just the one migration bug it was meant for — MEDIUM

**Status: FIXED.** `_initDb`'s catch now checks the exception message
against a list of substrings SQLite actually uses for an unopenable/
corrupt database file (`"file is not a database"`, `"database disk image is
malformed"`, etc.) via a new `_looksCorrupt()` helper, and only deletes+
rebuilds when one matches; anything else (disk full, locked file, a
momentary I/O error) now rethrows instead of destroying local data.

`database_helper.dart:45-55` — the catch is unscoped: a transient disk-full or
locked-file error during `onUpgrade` triggers the same delete-and-rebuild as
genuine corruption, destroying all local ride/bike/maintenance data.

### 33.10 Google session isn't cleared on sign-out — MEDIUM

**Status: FIXED.** `AuthNotifier.signOut()` now also calls
`GoogleSignIn().signOut()` (wrapped in a try/catch, since a rider who never
signed in via Google will have nothing to sign out of).

`auth_provider.dart:112-115` never calls `GoogleSignIn().signOut()`/
`disconnect()`. Compounds §33.1's shared-device scenario: after "signing
out," a later `signInWithGoogle()` on the same device can silently
reauthenticate the previous Google account rather than showing a picker.

### 33.11 Unbounded image decode before resize — local DoS via crafted image — MEDIUM

**Status: FIXED.** Both files now probe header-declared dimensions first via
`img.findDecoderForData(bytes).startDecode(bytes)` — which parses
width/height without decoding pixel data — and reject anything over 50
megapixels (~200MB worst-case decoded, comfortably above any real phone
camera's default JPEG output) before ever calling the full decode.
`image_compression_utils.dart` gained a shared `_safeDecodeImage()` helper
used by all three of its decode call sites; `image_crop_io.dart`'s
`writeCroppedImage` does the same check inline.

`image_compression_utils.dart:18` and `image_crop_io.dart:30` call
`img.decodeImage(imageBytes)` fully before any dimension check. An image with
large declared pixel dimensions decodes to gigabytes of raw bitmap before
`copyResize` ever runs, which can OOM-crash the app. Reachable from any
picked/shared image (gallery, camera roll).

### 33.12 `searchPlacesByName` prefix search breaks for Bengali/non-ASCII text — MEDIUM

**Status: FIXED.** The upper bound is now `query + ''` — the standard
Firestore prefix-query sentinel, a private-use codepoint above any realistic
character in any script — instead of `query + 'z'`.

`place_repository.dart:203-212` bounds the range query with `isLessThan: query
+ 'z'`, which only works if every possible continuation character sorts below
`'z'` (U+007A). This app ships Bengali localization (`app_bn.arb`); Bengali
script (U+0980–U+09FF) sorts above `'z'`, so searching a real non-degenerate
Bengali prefix against a longer stored name returns nothing. Standard fix is
a high-codepoint sentinel like `''`.

### 33.13 `reset_beta_data.js`'s project guard is illusory — MEDIUM (operational risk)

**Status: FIXED.** `--yes-i-really-mean-it` now also requires typing
`DELETE ALL BETA DATA` verbatim at an interactive prompt
(`confirmRealDelete()`) before the 5-second countdown even starts — a guard
that can't be satisfied by a copy-pasted command or an env var, unlike the
project-id check. A new `--non-interactive` flag skips the prompt
deliberately, for legitimate scripted/CI use. Smoke-tested: a wrong typed
answer aborts before any Firestore call is made; `--non-interactive` skips
the prompt without hanging.

It refuses to run unless `FIREBASE_PROJECT_ID=throttleiqfb` — but per
`.firebaserc` that's the *only* project configured; there's no staging/prod
split. The guard protects against pointing at the wrong project among
several, but does nothing to stop an irreversible full wipe once this project
is serving real user traffic.

### 33.14 Stale, weaker draft rules file committed alongside the real rules — LOW (informational)

**Status: FIXED — deleted.** `app/firestore_rules_poi_directory.txt` is
gone; the comment in `firestore.rules` that referenced it (explaining why
there's no nested `places/{placeId}/reviews` block) now notes it was
deleted per this entry instead of pointing at a file that no longer exists.

`app/firestore_rules_poi_directory.txt` is a full standalone `firestore.rules`
draft, not referenced by `firebase.json` (which correctly points at the real
`firestore.rules`), but materially weaker: its `places` update rule allows any
owner/admin to set arbitrary `ratingSum`/`ratingCount` with no ±1-delta
binding. Inert today, but a live attack blueprint if ever deployed by
mistake (manual `firebase deploy` against the wrong path, a future
`firebase.json` edit). Recommend deleting it now that its content is fully
superseded.

### 33.15 No size/content-type constraints on storage uploads — LOW

**Status: FIXED** (rules changed; see §33.6 for why `storage.rules` isn't
actually deployed yet). Both `avatars/{filename}` and
`rideShares/{uid}/{filename}` writes now require `request.resource.size`
under 5MB/10MB respectively and `request.resource.contentType.matches
('image/.*')`.

`storage.rules`'s `avatars/{filename}` and `rideShares/{uid}/{filename}` gate
only on filename/uid ownership — no `request.resource.size` or `contentType`
check. A user can repeatedly overwrite their own slot with an arbitrarily
large file — a storage/bandwidth cost-griefing vector against the project.

### 33.16 Overpass QL query has no guard against non-finite values — LOW

**Status: FIXED.** `fetchNearby` now returns `const []` immediately if
`latitude`/`longitude`/`radiusMeters` aren't all finite, before building the
query string, and the Dio call is now wrapped in `try`/`on DioException`
returning `const []` — matching `NominatimService`'s existing defensive
pattern for this free, rate-limited public API.

`overpass_service.dart:49-60` splices `radius`/`latitude`/`longitude` directly
into the query text. Not classic injection (always `double`-typed today), but
`double.nan`/`double.infinity` (e.g. a corrupted last-known-location) renders
as `"NaN"`/`"Infinity"` into the query body, and unlike `NominatimService`
there's no try/catch around the call — it surfaces as an unhandled
`DioException`.

### 33.17 Firebase auth error mapper leaks raw exception text to the UI — LOW

**Status: FIXED.** The fallback now returns a generic `'Something went
wrong. Please try again.'` instead of `error.toString()`.

`firebase_error_mapper.dart:34`'s fallback `return error.toString();` puts
raw, non-`FirebaseAuthException` error text (can include internal
exception/type details) directly into a user-facing `SnackBar`.

### 33.18 `crashNotifications` write rule lets a rider freely rewrite their own doc's `status` post-creation — LOW

**Status: FIXED** (rules changed, NOT yet deployed). Split `allow write`
into `allow create` (bounded to `uid == auth.uid` and `status == 'pending'`,
the exact shape `ride_recording_provider.dart` writes) and `allow read`, with
NO update/delete grant at all — confirmed via grep that the client only ever
`.add()`s this doc once and never updates it; every real status transition
(`'contacted'`, `'escalated'`, ...) happens server-side via the Admin SDK in
`functions/src/crash-notifications.ts`, which isn't subject to these rules
regardless. Three new tests in `firestore_rules.test.js`: a valid pending
create succeeds, a create with a non-pending status is denied, and a rider
can no longer update their own doc's status after creation.

`firestore.rules:349-352`'s `allow write` has no further constraint after
creation, which could let a rider suppress the (currently mocked) 15-minute
escalation once real SMS/email delivery ships.

### Also worth noting: rules test coverage gap

**Status: PARTIALLY CLOSED.** §33.2's and §33.4's and §33.18's own fixes each
came with new emulator tests (13 total — see §33's verification note), so
`liveSessions`'/`notifications`'/`crashNotifications`' newly-changed clauses
are now covered. `groupRides` invite/member logic, `emergencyContacts`, and
storage rules still have no emulator coverage — that gap is unchanged by
this session and remains open.

`scripts/test/rules/firestore_rules.test.js` has no coverage at all for
`liveSessions`, `groupRides` invite/member logic, `emergencyContacts`, or
storage rules — exactly the areas with the most complex hand-reasoned boolean
logic, and where §33.2 and §33.6 live. Everything else in scope — the rest of
`firestore.rules`, Cloud Functions (`functions/src/*.ts`), and the admin
scripts (`set_admin_claim.js`, `seed_dhaka_places.js`) — came back clean:
properly gated, no hardcoded secrets, no SQL/NoSQL injection anywhere in the
DAOs, and `public/live-viewer.html` uses `textContent` (not `innerHTML`) for
all session-derived data.

### 33.6 (rest). Storage rules audience mirroring — OBSOLETE (2026-10-22, moved from `issues_open.md`)

The open half of 33.6 (mirror the ride's `audience` in `storage.rules` via
`firestore.get()`, with an emulator test) no longer applies: `storage.rules` was deleted
in `f58bd8e1` (2026-10-14/15). `firebase.json` never deployed Storage and the app has no
`firebase_storage` dependency; photos and voice notes go through Cloudinary
(`issues_open.md` §33.5). §62.11 was the same item.

---

---

## 34. `beta-v1` Android APK reported as a "signing error" that won't open on some devices — reported, not yet confirmed (2026-08-27)

A tester reported the `beta-v1` GitHub release APK shows a signing error and
won't open on some Android devices. No physical device or `adb` was available
in this environment to reproduce it directly, so this is a diagnosis from
static verification of the actual release artifact, not a confirmed root
cause — see "What would confirm this" below before treating it as closed.

**The release artifact itself checks out clean.** Downloaded the real
`app-release.apk` from the `beta-v1` GitHub release and verified it with
`apksigner` and `aapt` (both from the Android SDK build-tools; needed
Android Studio's bundled JBR for `apksigner` — no system `java`, same
`JAVA_HOME` workaround `scripts/README.md` already documents for the rules
emulator):

- **Signature verifies**, APK Signature Scheme v2, one signer.
- **Certificate matches the canonical release keystore exactly** — compared
  the APK's embedded signer cert against `keytool -list -v -keystore
  throttleiq-release.keystore` on this machine: SHA-1
  `85:42:B8:AD:19:1E:6B:74:FC:85:27:4F:48:9D:BC:CE:4B:00:2F:10` on both
  sides. So this release was built with the right key, not an accidental
  different/regenerated one.
- `minSdkVersion` **24** (Android 7.0+), `targetSdkVersion` 36, package
  `com.bft.throttleiq`, `versionCode` 1 — all as expected from
  `app/android/app/build.gradle.kts`.
- No v1 (JAR) signature is embedded, only v2 — **this is expected, not a
  bug**: AGP 8.11.1 (`app/android/settings.gradle.kts`) skips v1 signing
  automatically once `minSdkVersion` is 24+, since v1 only exists for
  devices below Android 7.0, which this app doesn't support anyway.
- File size (86,977,541 bytes) matches the ~87.0MB `HANDOFF_Document.md`
  recorded when this APK was built — not corrupted or truncated by the
  GitHub upload.

**Working hypothesis: a signature mismatch against an already-installed
build on the affected devices**, not a defect in this release. Android
refuses to install an APK over an existing app with the same package name
(`com.bft.throttleiq`) if the certificates don't match — the platform's own
tamper protection, and exactly what a user would describe as a "signing
error." The most likely source of a mismatched prior install is a **debug
build** (`flutter run`/`flutter install`, signed with Android's default
debug keystore — a different certificate from `throttleiq-release.keystore`)
still present on a test device from earlier development, or one of the
deleted `beta-v1`/`beta-v2`/`beta-v3` tag iterations mentioned in the
current release's own notes, if any of those were ever built with a
different signing setup. This would explain "some devices, not all": only
devices carrying a prior differently-signed install are affected: a device
that never had ThrottleIQ on it should install this APK cleanly.

**What would confirm this** (not yet done — needs a physical affected
device):
- Uninstall any existing ThrottleIQ install on an affected device
  (Settings → Apps → ThrottleIQ → Uninstall), then install the release APK
  again. If that fixes it, the diagnosis is confirmed.
- Or, with the device on `adb`: `adb install -r app-release.apk` — a
  signature mismatch fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`
  specifically, which is unambiguous versus a generic parse/corruption
  error.
- The exact on-screen error text from an affected device would also narrow
  this down — "signing error" is the tester's paraphrase, not necessarily
  the literal OS message.

**Not yet done, worth doing regardless of root cause:** add a line to the
GitHub release notes telling testers to uninstall any prior ThrottleIQ build
before installing this one — cheap, and correct regardless of whether the
hypothesis above is confirmed.

---

---

## 35. Root cause found for the Android "licensing error" crash: `flutter_background_geolocation`'s license key was never filled in — FIXED DIFFERENTLY, see §50 (2026-08-27)

Supersedes §34's hypothesis for the specific symptom reported this session:
**install succeeds, app then shows a licensing error and crashes on every
launch, on every tested device other than the developer's own.** That
install-then-crash shape doesn't match §34 (a certificate mismatch blocks
*installation* itself with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, it doesn't
let the app install and then crash) — §34 may still be a real, separate
issue for testers who see the error before install completes.

**Confirmed cause:** `android/app/src/main/AndroidManifest.xml`'s
`com.transistorsoft.locationmanager.license` meta-data still holds the
literal placeholder `PASTE_LICENCE_KEY_BEFORE_RELEASE` — never replaced with
a real key. This was already flagged in the manifest's own comment and in
`auto_tracking_service.dart`'s doc comment as "REQUIRED FOR RELEASE BUILDS
... a hard gate before shipping," but the key was never purchased/pasted in.
`AutoTrackingService.instance.configure()` runs unconditionally on every app
launch (`main.dart:55`, regardless of whether the rider has opted into
auto-tracking), so an invalid license on a release-signed build hits this
path for every install, every launch — matching "every other Android phone."

**Fix as originally scoped (not done — would have required a purchase):**
buy a license key at https://shop.transistorsoft.com for application id
`com.bft.throttleiq` (per-app-id, not per-developer, one-time), paste it
into the manifest's `android:value`, then rebuild, re-sign
(`apksigner`-verify against `throttleiq-release.keystore` as in §34), and
re-upload the `beta-v1` release asset.

**What actually happened, 2026-08-28: see §50.** Rather than buy the key,
the plugin was replaced with a free stand-in — a product decision to stay
free-tier for roughly three months, not a change to the diagnosis above.
`flutter build apk --release` now succeeds with no licence gate at all. The
paid-plugin path above still works if ever revisited; the old implementation
is archived at `docs/archives/flutter_background_geolocation-2026-08-28/`.

---

---

## 36. Ride summary screen always closed to the record screen, even when opened from a rides list — FIXED (2026-08-27)

`ride_summary_screen.dart` (route `/ride/summary/:rideId`) is reached two
different ways: `active_ride_screen.dart` `go`'s there right after finishing
a recording (replacing the nav stack — nothing to go back to but the record
screen), but `all_rides_screen.dart`, `stats_screen.dart`, and
`bike_detail_screen.dart` all `push` it on top of a rides list to view a
past ride's details. The close (✕) button and "Save & Done" button both
hardcoded `context.go('/home/record')`, so closing a ride opened from a list
incorrectly landed on the recording screen instead of back on that list.

**Fix:** both buttons now call a `_dismiss` helper that checks
`context.canPop()` — pops back to the previous screen when there is one
(the list-opened case), falls back to `/home/record` only when there truly
is nothing to pop to (the post-recording case). `flutter analyze` clean on
the changed file; no existing test file covered this screen's navigation.

---

---

## 37. Error-message and permission-awareness pass: record screen, auto-tracking, Social/Forums — FIXED, one new feature not yet verified on device (2026-08-27)

Reported directly by the project owner as four related complaints about how
the app fails: unclear GPS errors on Record, no way to schedule auto-tracking
active hours, auto-tracking's permission state not being trusted, and raw
Firestore errors leaking into Social/Forums. All four addressed in one pass.

**37.1 — Record screen's blocked-recording message could go unseen.**
`ride_recording_provider.dart`'s GPS-off/permission-denied message rendered
only in an `EditorialCard` at the bottom of the scrollable content, below the
hero/stat-strip/"ride with friends" cards — easy to end up below the fold, so
a rider who slid the start bar and had it silently snap back with no visible
explanation is exactly what was reported as "behaves weirdly." Fixed:
- Added `RecordingBlockKind` (`locationServicesOff` / `permissionDenied` /
  `none`) alongside `RideRecordingState.error`, set by
  `_recordingBlockedReason()` (`ride_recording_provider.dart`).
- `record_screen.dart` now also shows a SnackBar the instant a start attempt
  is blocked (`_showBlockedSnackBar`, called from both `_SlideToStartButton`
  and `_HoldToStartControl`), with a one-tap action — "TURN ON" opens
  `Geolocator.openLocationSettings()`, "SETTINGS" opens
  `Geolocator.openAppSettings()` — so the fix is never more than one tap from
  the failure. The existing card also gained the same action button.

**37.2 — Auto-tracking's Settings toggle trusted a stale flag.**
`AutoTrackingNotifier.build()` (`auto_tracking_provider.dart`) used to just
read the persisted `SharedPreferences` bool and show that as the switch
state — it never re-checked whether "Always" location permission was still
actually granted. A rider who revoked it from OS Settings would keep seeing
the switch as ON with no indication the feature had silently stopped
working. Fixed: `build()` now re-verifies `Geolocator.isLocationServiceEnabled()`
+ `checkPermission() == always` every time it runs, flips the stored flag
(and stops the plugin) the moment they no longer match, and
`app.dart`'s `didChangeAppLifecycleState` now calls
`ref.invalidate(autoTrackingEnabledProvider)` on resume — so coming back
from OS Settings after granting or revoking the permission updates the
switch immediately, not only after the next manual toggle.

**37.3 — New feature: daily active-hours window for auto-tracking.**
Product ask: "let me toggle *when* day-long tracking is active," not just
on/off. `flutter_background_geolocation` already has first-class support for
this (`Config.schedule` + `startSchedule()`/`stopSchedule()` — a native,
cron-like scheduler that keeps working across app kills and reboots without
Dart code needing to run to flip anything), so this uses that rather than a
hand-rolled Dart-side time check. New in `auto_tracking_service.dart`:
`isScheduleEnabled`/`setScheduleEnabled`/`getScheduleWindow`/
`setScheduleWindow` (SharedPreferences-backed, minutes-since-midnight,
default 7am–10pm), `_scheduleCronOrNull()` builds the `'1-7 HH:MM-HH:MM'`
cron string, `configure()` passes it into `Config.schedule`, `start()`
chooses `startSchedule()` over plain `start()` when a window is set, `stop()`
now also calls `stopSchedule()` (per the plugin's own docs: plain `.stop()`
does not halt a running scheduler), and a new `applyScheduleChange()` pushes
an edited window to an already-running tracker via `setConfig()` without
tearing down and re-registering the plugin's event listeners.

New `AutoTrackingScheduleTile` (`auto_tracking_tile.dart`), shown under the
existing tile in Settings only while auto-tracking is on, with a switch and
two time pickers ("From" / "Until"); rejects `start >= end` since this
single-window model doesn't support a range that wraps past midnight.
Deliberately **not localized**, unlike the rest of this screen — adding a
real, reviewed Bangla translation for a brand-new feature was out of scope
here; tracked as a gap, not silently skipped.

⚠️ **Not yet verified on a physical device.** `flutter analyze` (0 issues on
every changed file) and the full `flutter test` suite (826/826) both pass,
but nothing here has been exercised against the real native plugin — in
particular whether `startSchedule()`/`setConfig()` behave exactly as
documented, and whether the scheduler actually starts/stops GPS at the
configured times on-device. Same "built, not yet verified" caveat this repo
already applies elsewhere (see §35's own unresolved beta-tester report on
this same plugin) — test on a real phone before trusting this for a rider's
actual battery/tracking expectations.

**37.4 — Raw Firestore errors surfacing verbatim in Social and Forums.**
`social_screen.dart`, `forums_home_screen.dart` (×2), and
`forum_thread_screen.dart` each had a `.when(error: (e, _) => Text('$e'))`
branch, so offline Firestore reads showed the SDK's own retry-policy message
— `"[cloud_firestore/unavailable] The service is currently unavailable...
may be corrected by retrying with a backoff..."` — directly to the rider,
exactly as reported. Fixed with two new pieces:
- `mapFirestoreError()` (`core/utils/firebase_error_mapper.dart`) — switches
  on `FirebaseException.code` (`unavailable`, `deadline-exceeded`,
  `permission-denied`, `not-found`, `resource-exhausted`) plus a
  network-substring fallback, returning a plain customer-facing sentence
  ("You're offline. Check your internet connection and try again.", etc.)
  instead of ever surfacing `error.toString()`.
- `ErrorView` (`shared/widgets/error_view.dart`) — the reusable
  offline/error widget this codebase didn't previously have (confirmed by
  search — every screen was hand-rolling its own ad hoc error `Text`). Shows
  the mapped message with a wifi-off or generic icon and, when given
  `onRetry`, a "Try again" button. All four call sites now pass
  `onRetry: () => ref.invalidate(<the underlying provider>)`.

---

---

## 38. No crash reporting is wired into the app at all — no visibility into production crashes (2026-08-27)

**Status: FIXED (2026-08-28).** Added `firebase_crashlytics` (`app/pubspec.yaml`,
resolved `4.1.3` against the existing `firebase_core ^3.1.0`). `main.dart` now
wires all three error surfaces Flutter has to Crashlytics: `FlutterError.onError`
(widget build/layout/paint errors), `PlatformDispatcher.instance.onError`
(errors outside Flutter's own error zone), and a `runZonedGuarded` handler
around `main()` (everything else, e.g. a bare async gap). Collection is gated
off in debug builds (`setCrashlyticsCollectionEnabled(!kDebugMode)`) so local
iteration doesn't pollute the dashboard — only real installs report.

Native side: added the `com.google.firebase.crashlytics` Gradle plugin
(`android/build.gradle.kts` project-level, applied in `android/app/build.gradle.kts`)
— verified with `./gradlew :app:tasks --all`, which now lists
`injectCrashlyticsMappingFileId{Debug,Profile,Release}`. iOS needs no manual
wiring; the `firebase_crashlytics` podspec injects its own dSYM-upload build
phase on `pod install`. Both `google-services.json` and
`GoogleService-Info.plist` already exist in the repo, so no new Firebase
console config is needed for crashes to start showing up in the Crashlytics
dashboard once the app is (re)installed.

Also updated `store_listing/data_safety_and_permissions.md` and
`public/privacy.html`, both of which previously stated flatly that no
crash-reporting SDK was bundled — that claim is no longer true and would have
been a Play Data Safety misdeclaration and a privacy-policy inaccuracy had it
shipped as-is. Added a "Crash logs" diagnostics row to the Data Safety
answers and a crash-diagnostics row + corrected "what the app does not
collect" bullet in the privacy policy.

**Not verified this session:** an actual on-device crash reaching the
Firebase console — no Flutter build/run was done against a real device or
simulator, only `flutter pub get`, `flutter analyze`, and a Gradle
configuration pass. Worth a real `FirebaseCrashlytics.instance.crash()` test
call (temporarily, from a debug button) before relying on this for the
organic-launch decision described below.

Surfaced answering a launch-readiness/marketing question, not while working a
ticket — confirmed by reading `app/pubspec.yaml`, not assumed.
`store_listing/data_safety_and_permissions.md` already notes the *absence* of
`firebase_analytics`/`firebase_crashlytics` as a reason not to over-declare on
the Play Data Safety form, but nothing flags it as a gap to close before
real users arrive. It is one: today, if an installed build crashes on a
user's phone, nothing tells you it happened — no Crashlytics, no Sentry, no
equivalent. The only crash signal that has ever reached this project is a
tester manually reporting one in words (§34).

**Matters most for the sequencing question this was raised in:** the plan
discussed was organic users first, Facebook ads later, once the app is
stable. Without a crash reporter, "once it's stable" can't be measured —
there's no dashboard, no crash-free-sessions rate, nothing but word of mouth
from whichever testers happen to say something. Add one (Firebase Crashlytics
is the natural fit given the app is already on Firebase) before the organic
push, not after — otherwise the bug-finding phase produces no evidence trail
to decide when it's over.

---

---

## 40. Default appearance changed to Calming/Curvy/Light for every new install/account — FIXED (2026-08-27)

Requested directly by the project owner. `AppAppearance.defaultAppearance`
(`theme_style_provider.dart`) was Carbon Mono/Boxy/Dark since the
Vibe/Brightness/Color split — now Calming/Curvy/Light. This is the single
source both a fresh install and a brand-new account resolve to (no persisted
`SharedPreferences` keys yet), and also what any *individual* un-set axis
falls back to for a returning rider who only ever changed the other two —
see `AppearanceNotifier._loadPersisted`.

A rider who already picked an appearance in Settings is unaffected — this
only changes what nobody-touched-Settings resolves to. Six existing tests
across three files (`app_theme_style_test.dart`,
`theme_style_provider_test.dart`, `appearance_picker_test.dart`,
`app_logo_test.dart`) hard-coded the old default (either as the literal
expected value, or as a "no-op" transition target that stopped being a
no-op) and needed updating alongside the change — `flutter analyze` clean,
826/826 tests pass.

---

---

## 41. `record` package's 5.x line doesn't compile for release — blocked the Beta V1 Android build (2026-08-27)

Surfaced while cutting the Beta V1 release requested by the project owner.
`pubspec.yaml`'s `record: ^5.1.2` (added for the group-ride push-to-talk
voice notes feature, same session as `Issues.md`'s neighboring entries)
resolved to `record 5.2.1` + `record_linux 0.7.2` +
`record_platform_interface 1.6.0` — a combination pub's version solver
accepts (satisfies every semver constraint) but that does not actually
compile: `record_linux 0.7.2` is missing `startStream` and has a stale
`hasPermission` signature that `record_platform_interface 1.6.0` requires.
`flutter build apk --release` failed at the Dart kernel-compile step, before
any Android-specific step ran — this would have failed for **any** platform
target, not just Android; it happened to surface here because Beta V1 was
the first release build cut since these dependencies were added.

`flutter pub upgrade record_linux` reported "No dependencies changed" —
0.7.2 is the newest `record_linux` release compatible with `record`'s `^5.x`
constraint, so this isn't a stale lockfile; it's a genuine unfixed pairing
in the 5.x line. `flutter pub outdated` showed `record 7.1.1` as the next
release where `record`/`record_linux`/`record_platform_interface` were
bumped together and actually match.

**Fixed:** bumped to `record: ^7.1.1`. The `AudioRecorder`/`RecordConfig`/
`AudioEncoder` surface `group_ride_map_screen.dart` uses was unaffected by
the major version jump — `flutter analyze` clean, `flutter build apk
--release` succeeded (90.0MB), 826/826 tests still pass.

---

---

## 42. Anonymous per-road speed baseline + outlier insight — built, unit/rules-tested, `firestore.rules` NOT yet deployed (2026-08-28)

The road-baseline feature proposed in `HANDOFF_Document.md`'s backlog (added
2026-08-27) — save a ride's speed per rough road segment, pool it
anonymously across riders, and flag a ride privately to its own rider when
it was a real outlier for that segment (the "everyone does 30-50, one guy
does 80" case). Built end to end this session; see `Features.md` §2 for the
user-facing description. Three deliberate v1 simplifications, each swapping
a blocked/paid dependency for a free or already-available one:

- **Segment = geohash cell** (`domain/calculators/segment_speed_aggregator.dart`,
  precision 7, ~150m), not true map-matching — no roads-API vendor/key
  decision needed. Reuses `core/utils/geohash_util.dart`, already in the
  codebase for POI directory.
- **Weather = Open-Meteo's forecast endpoint** (`core/services/weather_service.dart`),
  free and keyless, `past_days` param rather than the archive/reanalysis
  endpoint (which has a multi-day ingestion lag and would have no data for a
  ride that just finished).
- **Aggregation = a bounded client-side Firestore read** (`CloudRepository.
  fetchRoadSpeedSamples`, capped at 200 docs), not a Cloud Function — avoids
  the Blaze-plan blocker that's already tracked for crash-alert delivery.

**Privacy shape, not an afterthought:** pooled samples
(`roadSpeedSamples/{segmentId}/samples`) carry no uid, no rideId, and no
exact coordinates — only the coarse cell id, speed, weekday, hour, and
weather code, enforced field-by-field in `firestore.rules` (`hasOnly` +
type/range checks, mirroring the `groupRides/voiceNotes` bounded
create-only pattern). The outlier comparison itself is shown only to the
rider it's about, on their own ride summary — never posted, shared, or used
to identify anyone. `public/privacy.html` §2 and §4 (Open-Meteo row) were
updated in the same session, before any of this shipped, not after.

**Verified:**
- `domain/calculators/segment_speed_aggregator.dart` and `speed_baseline.dart`
  — pure, unit-tested (`test/calculators/segment_speed_aggregator_test.dart`,
  `speed_baseline_test.dart`), including the exact "30-50 baseline, 80 spike"
  scenario from the original request.
- `firestore.rules`' new `roadSpeedSamples` block — 13 new emulator-backed
  tests in `scripts/test/rules/firestore_rules.test.js` (bounded shape,
  no-owner create, deny update/delete, unauthenticated denied both ways),
  full suite **57/57 green** via `npm run test:rules`.
- `flutter analyze`: 0 errors. `flutter test`: **847/847 green**.

**NOT yet verified — real gaps, not hedging:**
- ✅ **`firestore.rules` deployed 2026-08-28** (`firebase deploy --only
  firestore:rules --project throttleiqfb`) — the `roadSpeedSamples` rules,
  and the join-by-code rules from the same batch, are now live. What's
  still open below is real-device verification, not the deploy step.
- `WeatherService` has never made a real HTTP call in this environment (no
  live network access here) — its Open-Meteo request/response parsing is
  reasoned through and defensively coded (best-effort, times out, returns
  null on any shape mismatch) but not exercised against the live API.
  `weatherCode` being consistently null on real samples for a while would be
  the symptom if the endpoint or response shape has drifted.
- No real ride has gone through `stopRide()` → `_publishSegmentBaselines()`
  → a real Firestore write on a device.
- **At launch, this will visibly do almost nothing for a long time** — the
  outlier card needs `minSamples = 5` prior samples on the exact same
  geohash cell to ever fire, and the pool starts empty. Expected, not a bug;
  it fills in as ride volume grows.
- No opt-out toggle yet — noted honestly in the privacy policy rather than
  silently omitted.

---

## 43. OS app icon (iOS/legacy Android) looked like "a circle inside a squircle" with illegible arc text — FIXED (2026-08-28)

User feedback after installing a release build on a physical iPhone: the
home-screen icon (`assets/images/app_icon.svg`, the flat rounded-square
source `flutter_launcher_icons` uses for iOS and legacy Android) drew a
circular ring *inside* its own rounded-square (squircle) background —
reading as two competing shapes — with the "THROTTLE IQ" wordmark arced in
tiny text around that inner circle, illegible at real icon sizes.

Redesigned per the user's direction: the inner ring is now a squircle
concentric with the icon's own corner radius (`rx=98` inset inside the
`rx=112` background) instead of a circle, and the wordmark is stacked
instead of arced — "THROTTLE" large across the top, the twin-wheel crest
mark centered in the middle (stroke width doubled, 16 vs the old 8, for a
bolder mark at a glance), "IQ" large across the bottom. Regenerated
`app_icon.png` from the new SVG via `rsvg-convert` and re-ran
`flutter_launcher_icons` to propagate it to every iOS `AppIcon.appiconset`
size and the Android legacy/default mipmaps, then did a full
`flutter run --release` reinstall on the connected iPhone to confirm the
new icon actually shows on a fresh install (icon changes don't show up on a
hot restart of an already-installed app).

**Deliberately left alone:** `app_icon_adaptive_fg.svg` (Android 8+
adaptive-icon foreground) keeps its circular ring — that file has no
squircle background of its own to clash with; its content is inset to
Android's circular safe zone specifically so it survives whatever mask
shape (circle/squircle/rounded-square/teardrop) a given launcher theme
applies, per the existing comment in `pubspec.yaml`. The in-app splash/
sign-in mark (`assets/icons/throttleiq-icon-dark.svg`, `AppLogo` widget) was
also left untouched — it's a bare circular mark with no squircle behind it
in-app, so the same "two competing shapes" complaint doesn't apply there;
its own arc-text may be worth a legibility pass later but that wasn't what
was reported this session.

---

## 44. OS app icon's inner squircle border floated inset from the icon's real edge instead of touching it — FIXED (2026-08-28)

Follow-up to §43: the redesigned squircle border (`rect x="34" y="34" ... rx="98"`)
was concentric with the background's corner radius but still sat well inside
it, leaving a bare dark margin between the drawn border and the icon's
actual outer edge — so the "frame" read as floating rather than bounding the
icon.

Fix: inset the rect by only half its stroke width (`x="5" y="5" rx="107"`,
stroke-width still 10) so the outer edge of the stroke lands exactly on the
icon's own edge instead of ~30px inside it. Regenerated `app_icon.png` from
the SVG via `rsvg-convert` and re-ran `flutter_launcher_icons` to propagate
to every iOS `AppIcon.appiconset` size and the Android legacy/default
mipmaps. ⚠️ **Not yet verified with a fresh install on a physical device**
(unlike §43, this pass only confirmed the change by rendering the PNGs, not
by reinstalling on a phone).

`app_icon_adaptive_fg.svg` (Android 8+ adaptive foreground) again left
alone — no change requested there, and it has no squircle background to
border in the first place.

---

---

## 45. Bike photo silently vanishes after a rebuild/reinstall — FIXED (2026-08-28)

Reported from real use: after every rebuild, a bike's photo in Garage was
gone (back to the generic icon tile), even though nothing had been changed
about that bike.

**Root cause:** `add_edit_bike_screen.dart`'s `_pickImage()` offers the crop
step but doesn't force it — cancelling out of the cropper keeps the photo as
picked rather than discarding the whole selection, which is intentional (see
§ in `features.md` on cropping). But the fallback used the *raw*
`image_picker` result verbatim: `_imagePath = cropped ?? xfile.path`.
`xfile.path` lives in `ImagePicker`'s own cache directory inside the app's
sandbox container — not `getApplicationDocumentsDirectory()` — which is not
guaranteed stable across app rebuilds/reinstalls (a fresh debug build gets a
new sandbox container UUID) or even in-place OS cache cleanup. The DB kept
the old path; `BikePhoto`'s `errorBuilder` then silently swapped in the
fallback icon once the file was gone, with no error surfaced anywhere.

The crop pipeline itself (`image_crop_io.dart`'s `writeCroppedImage`) already
wrote to the documents directory correctly — only the "skip crop" path had
the unsafe fallback.

**Fix:** added `persistPickedImage()` (`core/utils/image_crop_io.dart`),
which copies a source file into the same durable documents-directory
location `writeCroppedImage` uses, without touching pixels. `_pickImage()`
now calls this on the picker's raw path whenever the crop step is
skipped/cancelled, instead of storing that path directly.

Existing bikes whose `imagePath` was already saved before this fix (i.e.
already pointing at a since-reclaimed cache file) are not auto-repaired —
they still fall back to the generic icon until the rider re-attaches a
photo, same as any other stale-path case `BikePhoto` already handles.

✅ **Verified end-to-end on the iOS Simulator** (2026-08-28, via `idb` UI
automation): picked a photo, skipped crop (the exact bug path), saved —
confirmed via the app's sqlite file that `bikes.image_path` pointed at
`Documents/bike_<timestamp>.jpg`, not the `tmp/image_picker_...jpg` the
picker itself wrote. Deleted that tmp file outright (simulating the OS/
rebuild reclaiming it) and force-quit + relaunched the app: the photo still
rendered, since the durable copy in `Documents/` was untouched. Also
reconfirmed the Record-screen tint only appears once a bike has a real
photo (§ note in `features.md`) — no tint with no photo, a colored wash once
one exists.

---

---

## 46. Full-app QA sweep (2026-08-28): Export JSON/GPX, forum post deletion, and GPS-speed fallback — full report published

Ran a tab-by-tab, button-by-button walkthrough of the whole app (iOS
Simulator + physical device, accessibility-driven UI automation, a real
2.2 km ride recorded end to end) rather than a code read. Three confirmed
defects, filed individually below (§47–§49), plus two lower-severity forum
UX gaps and one low-severity loading-state gap, all fixed §54.

Full report, including a "confirmed working" list (join-by-code, invite
flow, pause/resume/discard, place reviews, empty states, badges, the
appearance system, auto-detect permission handling) and explicit coverage
notes (Group ride, Routes, Maintenance, SafeQR, Emergency Contacts, Android
— not reached this pass): published as an Artifact, "ThrottleIQ
Diagnostics".

**Residual side effect of this sweep:** one test forum post ("QA test
post") is stuck, undeletable through the app, in the live "Suzuki Gixxer"
bike forum under the throwaway test account used for this sweep — see §47.
This is real production data (the account and forum are real, not a
sandbox); it needs the §47 rules fix (then delete normally) or a manual
Firestore-console removal.

---

## 47. Deleting your own forum post fails with `permission-denied` — NOT a rules-file bug; rules were just stale/undeployed (2026-08-29)

Found during the §46 sweep. Created a post as the signed-in account on that
account's own bike forum, then tried to delete it as the same author.
Blocked outright:

```
Could not delete: [cloud_firestore/permission-denied] The caller does not
have permission to execute the specified operation.
```

The delete button, confirmation dialog ("Delete post? This removes the post
and its replies from the forum. It cannot be undone."), and optimistic UI
all behave correctly — the write itself is rejected server-side.

**Root-caused, not a code bug.** `firestore.rules`' post-delete rule
(`allow delete: if request.auth != null && (resource.data.userId ==
request.auth.uid || canModerateForum(forumId));`, added 2026-08-01) already
allows this — `||` short-circuits, so the author path never touches
`canModerateForum`'s `get()` at all. There was also no test pinning the
plain "author deletes their own post" path down (only "moderator deletes
someone else's" and "stranger denied" were covered), so a stale/undeployed
copy of this rule in production could sit unnoticed indefinitely — exactly
the pattern already seen in §29/§35/§37/§42 of rules lagging behind what's
committed locally.

**Fixed this session:**
- Added `scripts/test/rules/firestore_rules.test.js`'s `'a rider can delete
  their own post'` test — `npm run test:rules`: 73/73 green, confirming the
  rule text in this repo is correct.
- Ran `firebase deploy --only firestore:rules --project throttleiqfb`
  (user-approved, since it pushes straight to the production project). CLI
  output: `firestore: latest version of firestore.rules already up to date,
  skipping upload... firestore: released rules firestore.rules to
  cloud.firestore`. That phrasing means this file's content was already
  sitting in Firebase's ruleset storage from an earlier upload, but this
  deploy is what actually made it the **released** (live-serving) ruleset —
  i.e. exactly the "correct rules uploaded, never released/active" gap the
  §29/§35/§37/§42 pattern predicts. The stray "QA test post" left in the
  Suzuki Gixxer bike forum (see §46) should now be deletable normally
  through the app.

---

## 48. Export JSON / Export GPX silently do nothing on iOS — FIXED (2026-08-29)

Found during the §46 sweep. Tapping either export button on the Ride
Summary screen produces no visible effect whatsoever — no share sheet, no
error, no snackbar. The device log shows an uncaught exception on every tap:

```
flutter: PlatformException(error, sharePositionOrigin: argument must be set,
  {{0, 0}, {0, 0}} must be non-zero and within coordinate space of source view: {{0, 0}, {402, 874}}, null, null)
#2  MethodChannelShare.shareXFiles (package:share_plus_platform_interface/method_channel/method_channel_share.dart:112:20)
```

**Root cause:** `ride_summary_screen.dart:632` — `await
Share.shareXFiles([XFile(file.path)], subject: ...)` — never passes
`sharePositionOrigin`. This iOS version enforces a non-zero anchor rect for
the share popover's presentation, even on iPhone. The fix already existed
elsewhere in the same file's own feature area: `active_ride_screen.dart:190
–193` computes and passes `sharePositionOrigin: origin` correctly for the
"share live location" button.

**Fixed:** gave each export button its own `GlobalKey`
(`_exportJsonButtonKey`, `_exportGpxButtonKey`), and `_exportRide()` now
computes the button's on-screen `Rect` from whichever key was tapped and
passes it as `sharePositionOrigin`, mirroring `active_ride_screen.dart`'s
`_shareButtonKey` exactly. `flutter analyze` clean, `flutter test` 862/862
(no iOS-toolchain on-device re-verification this session).

---

## 49. Recorded rides can save with avg/max speed and moving-time all zero — no fallback when `Position.speed` is unreliable — FIXED (needs on-device verification) (2026-08-29)

Found during the §46 sweep's end-to-end recorded ride (2.2 km, simulated
GPS movement via `xcrun simctl location start`). The live speedometer on
the Active Ride screen stayed at `0 km/h` for the entire ride, while
distance (→ 2.2 km) and the live average speed (→ 52 km/h) updated
correctly from the same GPS stream. Once saved, it got worse: the Ride
Summary and Rides tab both show `avg 0`, `max 0`, `moving 00:00`, `in jam
02:11` — the whole ride reads as 100% stationary — and it propagates into
the badge system ("Top speed, 0 of 3 earned").

**Root cause:** `ride_recording_provider.dart:737` — `final speedMs =
pos.speed < 0 ? 0.0 : pos.speed;` — reads the device's raw `Position.speed`
field verbatim, with **no fallback** to a distance/time-derived speed when
that field is zero or unreliable. `active_ride_screen.dart:328, 459–467`
display it as-is. Distance and the live avg-speed readout are computed
independently from GPS coordinate deltas (`motion_calculator.dart:19–41`,
haversine-based), which is why only the speed-dependent numbers broke.

**Fixed:** `_onPosition` now computes a haversine distance/time-derived
speed (`derivedSpeedMs = distDelta / deltaT`, the same calculation
`motion_calculator.dart` was already doing for distance) alongside the raw
`Position.speed` reading. When the raw field is below
`SensorConstants.unreliableSpeedFallbackThresholdMs` (reuses the existing
`movingSpeedThresholdMs` = 1.0 m/s cutoff) but the derived speed is at or
above it, the derived value is used instead for that fix — feeding
`_maxSpeed`, `_speedSum`, moving-time accounting, `periodType`, the fusion
estimator, and the persisted point alike. Acceleration/jerk still derive
from the raw field, unchanged — this bug was only ever about the
speed-shaped numbers, not the sensor-fusion path. `flutter test`: 862/862.

**Still open:** Xcode Simulator location playback is known not to populate
a realistic `CLLocation.speed`, so the exact zero-speed condition this was
built against may be simulator-specific — but unreliable/zero GPS speed
fields are a known real-world condition on some Android GPS chipsets too,
so the fallback is worth having regardless. **Next step unchanged: record
one short real ride on a physical device** to confirm avg/max speed come
out sane (and non-suspiciously-derived) end to end.

---

---

## 50. §35's Android licensing crash fixed by replacing the paid plugin, not buying the key — auto-tracking now runs on a free stack (2026-08-28)

§35 root-caused the Android release-build "licensing error" crash to
`flutter_background_geolocation`'s never-purchased licence key
(`AndroidManifest.xml`'s `com.transistorsoft.locationmanager.license` still
held the literal placeholder). The fix recorded there was "buy a key". The
product decision made this session was different: **stay on the free tier
for roughly the next three months** rather than spend on the licence
pre-revenue, and replace the plugin instead.

**What changed.** `auto_tracking_service.dart` was rewritten around two free
(MIT) packages in place of the one paid one:

- `flutter_activity_recognition` (`ActivityRecognitionClient` on Android,
  `CMMotionActivityManager` on iOS) for the "are they moving" signal —
  `IN_VEHICLE` and `ON_BICYCLE` are both treated as ride-shaped, since both
  classifiers routinely mistake a motorcycle for a bicycle at low speed.
- `flutter_foreground_task` for a persistent Android foreground service
  (survives the app being swiped from recents, `autoRunOnBoot: true` for
  reboot survival) that keeps that signal alive, replacing the plugin's own
  bundled foreground service + headless dispatcher.
- `geolocator` (already a dependency, used for in-ride recording) supplies
  the actual GPS fixes once vehicle motion is seen — no second, nested
  foreground-service request; the task handler's own service already
  satisfies Android's "app has an active foreground service" requirement for
  background location.

The two isolate-side handlers the old plugin needed (a UI-isolate listener
and a separate headless-isolate entry point, kept in sync by hand) collapse
into **one** here: `flutter_foreground_task`'s task handler is the single
place events are processed regardless of whether the app's UI is open,
which is a real simplification, not just a swap.

**What was removed.** The plugin itself (`pubspec.yaml`), its licence
meta-data (`AndroidManifest.xml`), its Gradle repo/dependency-forcing block
(`android/build.gradle.kts` — this alone made `flutter build apk` fail
outright with `Project with path ':flutter_background_geolocation' could
not be found` once the pubspec dependency was gone, until removed), and its
iOS `BGTaskSchedulerPermittedIdentifiers` (`Info.plist`), replaced with the
new plugins' equivalents. `ios/Runner/AppDelegate.swift` gained the plugin
registrant callback `flutter_foreground_task`'s background BGTaskScheduler
refresh needs to see this app's other plugins (geolocator, sqflite,
shared_preferences) — without it, those calls would throw
`MissingPluginException` the one time in ~15 minutes iOS actually runs the
background task.

**What was kept as-is.** `AutoDetectionDao`, the `auto_detections`/
`auto_fixes` schema, and `AutoRideReconcilerService` — both the old and new
implementations write through the same DAO, so nothing downstream of
detection changed.

**Verified this session:** `flutter analyze` clean, `flutter test` 862/862
(unchanged from before this session — no test covered `auto_tracking_service.dart`
directly), `flutter build apk --debug` and, critically, **`flutter build apk
--release` — the exact build that used to crash on launch — now build clean
with no licence gate at all**.

**Not verified — no physical device available this session:**
- Whether `flutter_activity_recognition`'s stream actually keeps delivering
  once `flutter_foreground_task`'s service isolate is the only thing alive
  (app UI closed or swiped away). The build compiling and the API being
  correctly wired is not the same as this being observed to fire on a real
  ride.
- The schedule-window gating's cross-isolate `SharedPreferences.reload()`
  read (`_AutoTrackingTaskHandler._withinScheduleWindow`) — reasoned through
  carefully (this is exactly what `reload()` exists for) but never run.
- Android OEM battery-killer resistance without Transistorsoft's tuned
  handling — only the generic `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` prompt.
- iOS end to end — Info.plist/AppDelegate changes are compile-checked only
  (no iOS toolchain run in this session); see the "Known gap" note in
  `auto_tracking_service.dart` for the force-quit limitation that's expected
  by design, not a bug to chase.

**Update, same day — iOS launch verified on a physical device.**
`flutter build ios --release` → `xcrun devicectl device install app` →
`devicectl device process launch` on Abraar's iPhone (iOS 27.0): the app
installed and launched cleanly, and the process stayed up 15+ seconds past
`main.dart`'s Firebase/notification/`AutoTrackingService.instance.configure()`
init — no crash on startup, which is the concrete thing the
`AppDelegate.swift` (`flutter_foreground_task` plugin-registrant callback)
and `Info.plist` changes could have broken. **Still not verified**: actually
toggling auto-tracking on-device (permission prompts, the foreground task
starting) and anything visual (icon, bike-color picker) — no screenshot
tooling exists for a physical iOS device in this environment, and a release
build has no VM Service to query the widget tree either (see
`HANDOFF_Document.md`'s operational notes). That needs a human looking at
the screen.

**Archived, not deleted:** the paid-plugin implementation and every
platform-config line it needed live at
`docs/archives/flutter_background_geolocation-2026-08-28/`, with restore
instructions — see `HANDOFF_Document.md`'s Feature Backlog (under
"Automatic ride tracking") for the pros/cons table that should drive whether
it's ever worth reviving.

---

---

## 51. Android R8/ProGuard minification re-enabled — the never-verified release-launch crash from `build.gradle.kts`'s disable comment is now checked on an emulator (2026-08-28)

`app/android/app/build.gradle.kts` had `isMinifyEnabled = false` /
`isShrinkResources = false` since 2026-07-31, disabled to unblock a release
build after R8 crashed the app on launch on a real device — a crash that was
never root-caused with an actual stack trace, per that commit's own comment.
`proguard-rules.pro` at the time only had keep rules for
Firebase/Firestore/Play Core/SQLite/Riverpod plus a partial second batch
(geolocator, google_sign_in, image_picker, permission_handler,
flutter_local_notifications) added later without re-enabling minification.

**Audited every plugin in `pubspec.yaml` with native Android code against
that ruleset.** Found real gaps: the existing broad
`-keep class io.flutter.plugins.** { *; }` rule's own comment claimed it
covered `sensors_plus`/`battery_plus`/`device_info_plus`/`package_info_plus`,
but none of those actually live under that package — they're
`dev.fluttercommunity.plus.*`, which had no rule at all. Also missing
entirely: `flutter_activity_recognition` and `flutter_foreground_task`
(`com.pravera.*` — the auto-tracking stack from §50, added after the original
partial ruleset), `record` (`com.llfbandit.record.*`), `just_audio` +
`audio_session` (`com.ryanheise.*`), `home_widget` (`es.antonborri.home_widget.*`),
`vibration` (`com.benjaminabel.vibration.*`), `flutter_timezone`
(`net.wolverinebeach.flutter_timezone.*`), and `sqflite`'s plugin binding
itself (`com.tekartik.sqflite.*` — distinct from the `org.sqlite.*` native-lib
rule already present). None of these plugins ship their own consumer
ProGuard rules, so the app's `proguard-rules.pro` was the only thing that
could have kept them.

**Fix:** added keep rules for every namespace above, re-enabled
`isMinifyEnabled` / `isShrinkResources`, corrected the stale comment.

**Verified this session (Pixel_10_Pro emulator, no physical Android device
available):**
- `flutter build apk --release` and `flutter build appbundle --release` both
  build clean with the fuller ruleset (mapping.txt is now produced at
  `build/app/outputs/mapping/release/mapping.txt` — this is also what
  resolves Play Console's "no deobfuscation file" warning on the next
  upload).
- Installed the release APK fresh (had to `adb uninstall` first — a
  version-code mismatch with whatever debug/profile build was already on the
  emulator). App reaches the login screen (first frame) with no crash.
- Tapped "Continue with Google": `google_sign_in`'s native call correctly
  handed off to `com.google.android.gms`'s `MinuteMaidActivity` (confirmed
  via `dumpsys window`), and the app process stayed alive throughout with no
  `FATAL EXCEPTION` / `ClassNotFoundException` / `NoClassDefFoundError` in
  logcat — this is the plugin whose reflection-heavy native bridging was the
  likeliest single cause of the original crash, per the disable comment.

**Not verified — needs a physical device and/or a logged-in test account,
neither available this session:**
- Real hardware, full stop. The original crash was device-specific; emulator
  clean does not guarantee real-hardware clean.
- Any flow past login: ride recording (`geolocator`'s foreground service),
  auto-tracking (`flutter_activity_recognition` + `flutter_foreground_task`,
  §50), push-to-talk voice notes (`record`/`just_audio`/`audio_session`),
  and the four home-screen widgets (`home_widget` + the app's own
  `*WidgetProvider` classes) — none of these were exercised, since reaching
  them needs a real account and creating one would write to the production
  Firebase project.

Before the next Play Console upload: re-run at least the login + one ride
flow on a real Android device. If a release-only crash resurfaces, check
`adb logcat` for the exact missing class first — that's the one piece of
evidence the original disable never had.

---

---

## 52. App icon swapped from the crest badge to the "Speed Gauge" mark (2026-08-29)

Replaced `assets/images/app_icon.png` and `app_icon_adaptive_fg.png` — the
squircle-border crest from §43/§44 — with the "Speed Gauge" artwork the user
picked after reviewing two candidates (a stock `Icons.two_wheeler` glyph, a
speed-gauge graphic, and a flat motorcycle silhouette) side by side across
icon shapes/sizes in a design-preview Artifact.

**Source:** `designs/logos1/Screenshot 2026-08-28 at 8.15.27 PM.png`
(1148×1140, fully opaque, blue→green→orange arc with a glowing white needle
on a near-black ground).

**Processing (Pillow, no vector source exists for this mark — it's a
screenshot, not a redraw):**
- Center-cropped to 1140×1140, resized to 1024×1024 → `app_icon.png` (full
  bleed; this is what iOS and legacy/Play-Store-listing Android use, since
  those apply their own OS-level mask to an edge-to-edge square).
- Same artwork scaled to 66.6% and centered on a transparent 1024×1024
  canvas → `app_icon_adaptive_fg.png`, so the ring stays inside Android's
  adaptive-icon safe zone regardless of which mask shape (circle/squircle/
  rounded-square) an OEM launcher applies — matches the inset convention
  the old crest icon already used.
- Sampled the artwork's own border color (≈`#131317`, not pure black) and
  set `adaptive_icon_background` to that in `pubspec.yaml`, so it's
  invisible where it peeks out past the inset foreground, instead of
  doubling two slightly-different darks.
- Regenerated both platforms with `dart run flutter_launcher_icons`
  (Android mipmaps + `drawable-*/ic_launcher_foreground.png` +
  `colors.xml`'s `ic_launcher_background`; iOS `AppIcon.appiconset`).

**Verified this session (Pixel_10_Pro emulator):** installed the rebuilt
release APK fresh, launched with no crash (same R8-minified build path as
§51 — nothing code-level changed here, only assets), then backgrounded to
the home screen and screenshotted it: the gauge icon renders correctly in
the hotseat, circle-masked by the launcher theme, fully legible at real
launcher size.

**Not touched, and now stale:** `assets/images/app_icon.svg` /
`app_icon_adaptive_fg.svg` (the crest's vector source — kept as historical
reference, no longer what `flutter_launcher_icons` reads from), and every
marketing asset built from the crest — `designs/social/facebook/profile.html`
(explicitly comments that it scales up "app_icon.svg's 512 mark") and the
logo line in `docs/pitch_and_marketing_materials.md`. None of these were in
scope for this change; whoever next touches marketing assets should know
they no longer match the real app icon.

**Not verified:** real hardware (same caveat as §51 — this session only has
emulator access), and the in-app sign-in/splash mark
(`assets/icons/throttleiq-icon-dark.svg`, rendered by `AppLogo` per
`app_logo.dart`) is a **separate, deliberately untouched** asset — it's the
in-app brand mark, not the OS app icon, and this change didn't touch it.

---

---

## 53. Play Console internal testing track inactive — release never rolled out (2026-08-29)

Testers added to the "First Class" internal-testing list (and invited via
the opt-in link) reported the join link telling them they weren't invited,
even though they were on the list and signed in with the invited email.

**Cause (Play Console, not app code):** the internal testing track itself
was showing **Inactive**, and the only release under it —
`1 (1.0.0-beta.1)`, uploaded 2026-08-28 — was sitting as an **Untitled
release / Draft, Not reviewed**. It was never actually rolled out, only
uploaded. Being on the tester email list only makes someone *eligible* to
opt in; with no active rollout on the track, there's nothing for the
opt-in link to grant access to, so testers see a generic "make sure you're
invited" message regardless of list membership.

**Fix:** opened the draft release, clicked through **Review release**,
resolved the blocking requirements Play flagged, then **Start rollout to
Internal testing**. Confirmed resolved same day — release `1 (1.0.0-beta.1)`
now shows **Active** under Internal testing (uploaded 2026-08-28 8:39 PM).
Testers still need to re-open the opt-in link and then open the Play Store
app itself to download; allow a few minutes to propagate.

**Not app code** — no source changed this session; noting this here so the
release-publish step isn't mistaken for already done next time internal
testers are invited.

---

---

## 54. §46's three lower-severity forum UX gaps — FIXED (2026-08-29)

The compose-flow and discovery gaps §46 flagged but didn't break out into
their own sections.

**New forum posts didn't appear until you left and re-entered the thread.**
Root cause was subtler than "doesn't invalidate" — it did invalidate
(`ref.invalidate(forumPostsProvider(forumId))` after a successful post), but
`ForumRepository.createPost` stamps `createdAt: FieldValue.serverTimestamp()`,
which reads back as `null` on the client until the server acks it, and
`getPosts`'s query does `orderBy('createdAt')` — Firestore excludes any doc
whose order-by field is still null from that query. The invalidate's
refetch reliably raced that ack and silently omitted the post the rider
just made; only a *later* fetch (after the timestamp resolved) picked it
up, which read as "needs a manual back-and-forward." **Fixed** by having
`_NewPostSheetState._submit()` insert the new post directly into
`forumPostsNotifierProvider` (a new `ForumPostsNotifier.addPost`, prepending
locally) instead of relying on a refetch — the same optimistic-update shape
`vote()` already used. The stale `ref.invalidate(forumPostsProvider(...))`
call is gone from `_showNewPostSheet`.

**Submitting an empty or title-only post gave zero feedback.** `_submit()`
used to just `return` on blank fields with no visible sign anything
happened. **Fixed:** blank title/body now sets `_titleError`/`_bodyError`,
surfaced as `TextField.decoration.errorText` ("Title is required" / "Say
something before posting"), cleared as soon as the rider types in that
field.

**Brand forums showed a blank body with no spinner while resolving.** Not
actually the thread screen's `postsAsync.when(loading: ...)` — that already
had a spinner. The real gap was one step earlier: `forums_home_screen.dart`
tapping a brand/topic discovery row (`_openBrandForum`/`_openGeneralForum`)
awaits `ForumRepository().getOrCreateForum(...)`, a Firestore transaction
that can take a few seconds on first open, and the only feedback during
that wait was the row going inert (`enabled: !_resolving`) — no spinner,
which is what read as "broken." **Fixed:** `_resolving` (a bool) became
`_resolvingEntry` (the specific brand/topic in flight), and the tapped
`_DiscoverRow` now swaps its trailing chevron for a small
`CircularProgressIndicator` for exactly that entry (the search box's own
search button does the same when it's the one in flight).

**Verification:** `flutter analyze` clean (no new issues in any touched
file), `flutter test` 862/862. Not re-verified on-device/simulator this
session — no iOS toolchain run.

---

---

## 55. Forums read as fabricated, and a bug-fix ask surfaced a real forum-grouping gap (2026-08-29)

Two asks in one session, both about the forums feeling less like a real
Bangladeshi riding community and more like generated filler.

**"Continue with Google" had no equivalent on Register.** Not actually a
bug in the sign-in path — `AuthNotifier.signInWithGoogle()` calls
`_auth.signInWithCredential(credential)`, and Firebase creates the account
transparently the first time it sees a given Google credential, so an
unregistered rider tapping "Continue with Google" on Login was never
actually failing. The real gap was that `register_screen.dart` had no
Google option at all, so there was no explicit "sign up with Google" path.
**Fixed:** added the same "Continue with Google" button (→
`signInWithGoogle()`) to the register screen.

**QA seed forum content (`scripts/oneoff/seed_qa_test_riders.js`,
`scripts/oneoff/qa_seed_catalog.js`) read as generic and inauthentic.** The 30
fabricated QA/test riders' forum posts were formal English templates, the
30 rider names were a roughly 50/50 male/female mix, and the bike catalog
above 150cc included brands (KTM, Kawasaki, most Japanese 150-400cc
sportbikes) that are grey-import rarities in this market rather than what
this crowd actually discusses. **Changed:** all 30 rider names are now
male; forum post templates are now Banglish (mixed Bengali/English, casual
tone) instead of formal English; the catalog above 150cc is now CFMoto (SR
250, SR 300, CF Light 230 Dual) and Royal Enfield only, ≤150cc unchanged
(domestic commuter/mid-range brands).

**Fixing the FZS UX ask surfaced a real (non-QA) forum-grouping gap.** While
fixing the above, verifying it also surfaced that the *production* forum
logic had no concept of model-family grouping: a real rider's "Yamaha FZS
v2" and another's "Yamaha FZS-Fi V3" would resolve to two different forums
(`yamaha__fzs_v2` vs. `yamaha__fzs-fi_v3`) even though they're the same
popular bike, fragmenting the one forum a rider on this model would
actually want into several near-empty ones. **Fixed in the real app, not
just the seed script:** `core/utils/slugify.dart`'s new
`normalizeModelFamily()` collapses any Yamaha FZ-S/FZS variant to `FZS`
before slugifying, applied inside `bikeForumSlug` so both the forum id and
(via `ForumRepository.getOrCreateForum`) the stored `model`/`displayName`
agree. Hard-coded to this one model on purpose — a one-off convergence
rule for a specific popular bike, not a general versioning scheme every
brand needs. Unit-tested (`test/core/utils/slugify_test.dart`); mirrored in
`qa_seed_catalog.js`'s JS port so `cleanup_qa_test_riders.js`'s exhaustive
forum-id set stays exhaustive.

**Not yet done — needs an explicit go-ahead, not run this session:** per
`scripts/README.md`'s "Live roster" section, 30 QA accounts matching the
*old* names/bikes/post copy are already live in the production
`throttleiqfb` project (seeded 2026-08-27), visible to real beta testers.
Editing the seed script doesn't retroactively change what's already
posted — that needs `cleanup_qa_test_riders.js` (deletes the 30 live
accounts, irreversible) followed by a fresh `seed_qa_test_riders.js
--yes-i-really-mean-it` (writes new public content to the same live
project). Both are live, publicly-visible, and one is destructive, so this
was deliberately left for an explicit decision rather than run
automatically. `scripts/README.md`'s roster table is flagged stale until
that reseed happens.

**Verification:** `flutter analyze` clean on all touched Dart files,
`flutter test test/core/utils/slugify_test.dart test/features/forums/`
57/57 green. `node -c` syntax-checked both touched JS files and dry-ran
`seed_qa_test_riders.js` to confirm the catalog/name/post-copy changes and
confirm `allSeedableForumIds()` still collapses the FZS entries onto one
slug. No production data touched.

---

---

## 56. Release `1.0.0-beta.1+3` shipped — Play Console, GitHub, and a real-device iOS run (2026-08-29)

Ships everything from §55 plus the earlier §47–§54 fixes that were sitting
committed-but-unpublished. Full pipeline, all verified against the live
services, not just a local build:

- **Committed and pushed** the session's pending work (`9d21674`) and a
  version bump (`2f44dd0`, `1.0.0-beta.1+2` → `+3` — Play requires a
  strictly increasing versionCode per upload).
- **Android**: `flutter build appbundle --release` (78.3MB AAB) and
  `flutter build apk --release` (79.4MB APK), both from `2f44dd0`.
- **Play Console internal track**: uploaded and committed via the raw
  Android Publisher API (service account `throttleiq-play-publisher`,
  `secrets/throttle-iq-gcc1-b9771877b5d4.json`) — `edits` → `bundles.upload`
  → `tracks.update` → `edits:commit`. Verified live: versionCode 3, status
  `completed`.
  - **Two new gotchas found the hard way, added to the "Reuse note" in
    `HANDOFF_Document.md`:** the media-upload call needs an `/upload/` path
    segment the other Android Publisher calls don't use — hitting the plain
    path gets the raw AAB binary parsed as JSON (`400 Invalid JSON payload
    received... PK...`, the zip magic number, is the tell). And
    a failed upload attempt appears to invalidate its `editId` — retrying
    the same edit after a failure came back `400 This Edit has been
    deleted`; the fix was starting a fresh `edits` call rather than reusing
    the one from the failed attempt.
  - Also hit a zsh footgun unrelated to the API: `"$EDIT_ID:commit"` in an
    unbraced double-quoted string gets parsed as zsh's `:c` history-style
    parameter modifier (command-path resolution), silently mangling the
    URL to `.../edits/00869378264864888875ommit` (a 404, not an auth or API
    error, so it's a chase-your-tail-worthy failure mode). `"${EDIT_ID}:commit"`
    with explicit braces fixes it.
- **GitHub release**: moved the `beta-v1` tag forward (force) to `2f44dd0`
  and pushed it, per this project's established convention of reusing one
  tag/release across the beta rather than cutting a new one each time —
  appended a new dated section to the existing release notes body (matching
  the "**Updated `<date>`** — same tag, moved forward..." pattern already
  in every prior update), retitled to `v1.0.0-beta.1+3`, and re-uploaded
  the APK asset (`--clobber`).
- **iOS**: `flutter run --release -d <device-id>` on a connected physical
  iPhone (Abraar's iPhone) — automatic signing under team `NJ4675FFUX`,
  Xcode build succeeded (70.7s), installed and launched (7.3s), confirmed
  attached and running with no crash output.

**Not done this session, deliberately:** adding testers to the internal
track's tester list (Play Console UI-only, see "Blocker" in
`HANDOFF_Document.md`) and the QA-rider reseed flagged in §55 — neither was
part of this release ask.

---

---

## 57. Public landing page's primary CTA led to a dead end, and its badge/stats had drifted stale (2026-09-05)

A marketing-focused session auditing `website_demo/index.html` (the actual
deployed landing page) found the hero's primary button — labelled "Get the
app on GitHub" — linked to the bare repo root
(`https://github.com/blankframe-tech/ThrottleIQ`), not a download. A visitor
clicking the one button styled as the primary call-to-action landed on
source code, the same dead-end pattern already identified and fixed on
`public/live-viewer.html`'s install CTA (see that file's `APP_LINKS`/
`installCtaHtml()` comments) — this page just hadn't received the same fix.

**Fixed:** the hero CTA now points at
`https://github.com/blankframe-tech/ThrottleIQ/releases/latest` and reads
"⬇ Download the Android beta", matching the copy/pattern already
established on the live-viewer page. The secondary "View the source" /
footer GitHub links were left pointing at the repo root — those are
correctly labelled as source links, not install links.

**Also found stale on the same page:** the hero badge read "Live beta
v2.0.0-beta.5" — a version string that doesn't match either the old
(`1.0.0-beta.1.x`) or current (`1.0.0-beta.2.2+7`, tag `beta-v2.2`)
versioning scheme; it's a leftover from before the version line was reset
2026-08-01 (`HANDOFF_Document.md`'s "Versioning history" section) that was
never updated after. Also claimed "iOS & Android" availability, which
overstates iOS distribution (device-run only, no TestFlight/App Store yet).
The test-count stat read "363 automated tests", well under the actual
verified count of 862 Flutter tests green (`HANDOFF_Document.md`, §56).
**Fixed:** badge now reads "Pre-launch beta · Android APK, iOS by request";
stat corrected to 862.

**`README.md`'s status blockquote had the same drift:** still cited the
retired `beta-v1` tag and `1.0.0-beta.1+1`. **Fixed:** synced to
`beta-v2.2` / `1.0.0-beta.2.2+7`, and the `HANDOFF_Document.md` link
corrected to its actual current path (`docs/planning/HANDOFF_Document.md`,
it had moved during an earlier doc-restructure and the README link was
never updated to match).

**Not app behavior** — no Dart/backend code touched; this is public-facing
marketing copy accuracy only. Full campaign work from the same session
(Bangla store listing draft, outreach templates, launch calendar, tracking
log, press fact sheet) lives in `docs/marketing/marketing_lead_notes/`,
not duplicated here.

**Correction, same session:** `website_demo/` was checked against
`firebase.json` (Hosting's `public` dir is `public/`, not `website_demo/`)
and against `.github/` (no workflow) and the repo's branches (no
`gh-pages`, no `CNAME`) — **this page has no deploy target at all today.**
It's a local demo/mockup, not a currently-live public landing page, so the
fix above is correct to have made but doesn't have a real-world effect
until someone actually deploys it somewhere. Flagged in
`NEEDS_YOUR_ATTENTION.md` rather than left implicit.

---

---

## 58. `website_demo/ui.html` undersold the real Appearance system (2026-09-05)

Same marketing-copy audit as §57. `website_demo/ui.html`'s hero read "Two
themes, one app" and only named Carbon Mono / Editorial. Checked against
`app/lib/core/theme/app_theme_style.dart`: the app actually exposes **7**
selectable color families (`AppColorMode`: `carbonMono`, `editorial`,
`nocturne`, `trailSocial`, `calming`, `retro`, `analystBlue`), each with an
independent shape axis (`AppShapeVibe`: `boxy`/`curvy`, in
`app_shape_profile.dart`) and independent dark/light brightness — a real,
already-shipped personalization system well beyond what the page claimed.

**Fixed:** hero copy now reads "One app, seven looks," names all seven
families, and states the shape/brightness axes — while still only showing
Carbon Mono and Editorial in the gallery below, since those are the only
two with rendered screenshots today. Also corrected the page's meta
description to match.

**Also noted, not applied:** `store_listing/store_listing.md` doesn't
mention this system at all — flagged inline in that file as a listing
opportunity blocked on screenshots per family
(`docs/marketing/marketing_lead_notes/screenshot_shot_list.md`), not added
as a bullet yet since a claim with no supporting screenshot is weaker than
one that ships with proof.

**Not app behavior** — copy-only, no Dart/backend touched.

---

---

## 59. `public/privacy.html` never disclosed direct messages as a data category (2026-09-05)

Same audit pass. While checking that the privacy policy actually backs up
a trust-FAQ claim being drafted for outreach ("the data table has the
specifics"), found it said nothing about direct messages at all, even
though `app/lib/features/chat/` (`chat_entity.dart`'s `MessageEntity`) is a
real, live one-to-one chat feature and `firestore.rules`' `/chats/{chatId}`
and its `/messages` subcollection have been storing message text since
that feature shipped. This is a genuine disclosure gap, not a cosmetic one.

**Verified before drafting a fix, not assumed:**
- Rules (`firestore.rules` around `match /chats/{chatId}`) restrict
  read/write to the two participants only — never public.
- Chats are strictly one-to-one (`participants.size() == 2` enforced on
  create).
- No delete or hide capability exists anywhere in
  `app/lib/features/chat/` today (`grep`-confirmed) — messages persist for
  the life of the account, same as everything else this policy already
  says has no automatic expiry.

**Fixed:** added a "Direct messages" row to the data table, added "direct
messages" to the Cloud Firestore services row's enumerated contents list,
and bumped the effective date to 2026-09-05 per the page's own stated
convention ("this page changes with it and the effective date at the
top... changes too").

**Not deployed.** `public/` is Firebase Hosting's real `public` dir (unlike
`website_demo/`, see §57) — this change needs an explicit
`firebase deploy --only hosting` to actually go live, and since it's a
legal document, that's flagged for a human read-through first in
`docs/marketing/marketing_lead_notes/NEEDS_YOUR_ATTENTION.md` rather than
deployed autonomously.

---

---

## 60. Doc-map and cross-reference links broken by the 2026-08-28 restructure, repo-wide (2026-09-05)

Noticed while linking to `docs/planning/HANDOFF_Document.md` etc. from
this session's marketing work that plenty of *existing* links still used
the pre-restructure flat `docs/` paths. Ran a full repo-wide markdown-link
scan (every `.md` under `docs/`, `store_listing/`, and root `README.md`)
to find the actual extent rather than fixing only the ones noticed by eye.

**Found and fixed:**
- `docs/README.md` (the doc map itself) — every link except `../README.md`
  was broken: `HANDOFF_Document.md`, `Issues.md`, `features.md`,
  `SETUP.md`, `assumptions.md`, `auto_tracking_plan.md`,
  `backend_options.md`, and all four marketing docs needed their `planning/`
  `guides/` `architecture/` `marketing/` prefixes restored. Also added a
  row for the new `marketing/marketing_lead_notes/` folder.
- Root `README.md`'s "Documentation" section (5 links) and the ASCII
  architecture diagram's two path-referencing lines, which needed
  re-flowing back to the diagram's 59-char box width after the corrected
  paths made them overflow.
- `docs/marketing/business_critique.md` and
  `docs/marketing/pitch_and_marketing_materials.md` — stale bare-path
  citations in prose (17 and 7 respectively).
- `store_listing/store_listing.md` and `store_listing/app_content_remaining.md`
  — same pattern, 2 each.
- A link written relative to its own directory in
  `pitch_and_marketing_materials.md` got double-prefixed by the first pass
  of this fix (`docs/marketing/docs/marketing/marketing.md`) — caught by
  the same scan and corrected.

**Not touched:** `docs/optimizerplan.md`'s file references use
`file:///f:/BlankFrameTechnologies/...` absolute Windows paths from a
different machine's checkout — a different, pre-existing problem, and
that doc's own header suggests it may already be superseded (its listed
items match commit `e45bdb3`'s "complete optimizer items"). Left alone
rather than guessed at.

**Verified:** re-ran the same repo-wide scan after all fixes — 0 broken
internal links remain across `docs/`, `store_listing/`, and `README.md`.

**Not app behavior** — every fix in this entry is a documentation link,
no Dart/backend code touched.

---

---

## 61. User report: "Continue with Google" fails and login screen shows the old logo (2026-09-05) — FIXED

Both symptoms turned out to be exactly the two gaps §51 and §52 had already
flagged as unverified.

**Old logo on "Welcome back" — FIXED by removal, not replacement.** User
asked for no logo at all on this screen rather than waiting on a redrawn
Speed Gauge SVG. Removed the `AppLogo` widget and its now-unused import
from `_ThrottleHeader` in `login_screen.dart` — the header is now just the
"Welcome back" title + subtitle. `splash_screen.dart` still uses `AppLogo`
(old crest mark) and was intentionally left untouched — out of scope for
this report, which was specifically about the login screen.

**"Continue with Google" not working — FIXED, root cause was a missing
Firebase SHA-1, not a code defect.** Confirmed via `keytool` that the
release keystore's SHA-1
(`85:42:B8:AD:19:1E:6B:74:FC:85:27:4F:48:9D:BC:CE:4B:00:2F:10`) *was*
already registered — ruling out §51's release-build hypothesis — but the
**local debug keystore's** SHA-1
(`DB:4C:88:76:40:B9:96:27:2D:CE:13:2E:A9:92:77:E6:D2:05:F4:1A`, from
`~/.android/debug.keystore`) was not registered anywhere on the Firebase
Android app (`1:603325098273:android:94694220f44cbf63fcf660`). Any debug
build (i.e. ordinary `flutter run`, which is how this was almost certainly
being tested) hit Google's `ApiException: 10` (`DEVELOPER_ERROR`) the
instant the button was tapped. `auth_provider.dart`'s `signInWithGoogle()`
needed no changes.

**Fix applied (with user confirmation before touching the live Firebase
project):** registered the debug SHA-1 via
`firebase apps:android:sha:create` against the `throttleiqfb` project, then
added the corresponding new `oauth_client` entry to the local (gitignored)
`app/android/app/google-services.json` so a fresh local build's copy
matches Firebase's records too. No app code changed for this half of the
fix — it was purely a Firebase-project config gap.

**Verified:** `firebase apps:android:sha:list` shows 3 registered SHA-1s
post-fix (the two pre-existing ones plus the new debug one); the local
`google-services.json` is valid JSON and both `com.bft.throttleiq` and
`com.throttleiq.throttleiq` client blocks were preserved intact.

**Not done / still open:** real-device verification of both fixes (this
session has no physical device or emulator attached), and the splash
screen's old-crest `AppLogo` — still there, still stale per §52, just not
part of this report's scope.

---

---

## 62. Full-repo bug/vulnerability/architecture sweep — 4 parallel reviews, 26 findings, most fixed same session (2026-09-10)

**Status: FIXED or MITIGATED for §62.1 through §62.10, plus 2 more bugs
(§62.14, §62.15) surfaced and fixed during the fix pass itself.** Several of
§62.1-§62.10 are marked PARTIALLY FIXED rather than FIXED where full closure
would have required a riskier change (a Cloud Function doing server-side
badge/stat aggregation, rerouting the crash-alert write through the outbox,
a local-DB schema migration) that this pass judged unsafe to make blind
without a live device/project to verify against — each such item says
exactly what was mitigated vs. what's still open, and why. §62.11 stays
deferred exactly as it already was pre-audit (its own comment already
explains why). §62.12-§62.13 are architecture notes, not single fixes; not
attempted this session (real App Check/rate-limiting and the
God-repository/theming/duplicated-rules refactors are bigger, higher-risk
changes than a bug-fix pass — see each note for why).

Four independent read-only passes first — (1) `firestore.rules` +
`storage.rules` + `functions/src/*`, (2) `app/lib/core/**`, (3)
`app/lib/features/**`, (4) `scripts/`/`public/`/deploy config — then every
fixable finding fixed in four parallel follow-up passes over non-overlapping
files, plus the rules changes made directly (highest blast-radius file, kept
under direct control) with new emulator tests. Verification, run after every
change landed: `flutter analyze` clean (0 new issues — same ~99 pre-existing
info-level lints as before this session); `flutter test` **1020/1020**
passing (app/); `npm run test:rules` **94/94** passing (was 80 — added 14
covering §62.1/§62.2/§62.4/§62.5); `npm test` (scripts/) **33/33** passing;
`cd functions && npm run build` clean. Nothing here has been deployed —
`firebase deploy --only firestore:rules,functions` is still required before
any of the rules/Functions fixes protect a real rider, same caveat as every
other rules change in this file.

> Still open from this section: 62.12 and part of 62.13. Those parts are in `issues_open.md` under §62. 62.11 is obsolete (end of this section).

### 62.1 Shared-ride documents are fully client-writable after the anti-fraud counter checks pass — leaderboard/social-proof forgery — CRITICAL

**Status: FIXED.** Added `rideStatsPlausible()` (distance/duration/speed
bounds + the average-speed floor, matching `SensorConstants` generously) and
required it, plus zeroed engagement counters and a recognized `audience`,
on both `create` and the owner's `update` branch; the owner branch also now
requires likes/comments/upvotes/downvotes stay unchanged (those move only
through the bump-validated branch). Applied the same `status`-enum
tightening to the group-ride creator branch, deliberately NOT locking
`memberIds`/`invitedIds` there too (the creator legitimately writes both —
kicking a member, `inviteUsers`' arrayUnion — and there's no leaderboard
fraud vector on group rides, so a fuller lockdown was judged not worth the
risk of breaking those flows blind). New tests:
`scripts/test/rules/firestore_rules.test.js` (share with plausible stats
succeeds; fabricated 9999 km/h denied; pre-loaded fake upvotes denied; owner
can't inflate stats/upvotes via update; owner CAN edit a caption without
touching stats).

`firestore.rules:447-451` only pins `userId` immutable on `update`; every
other field (`distanceKm`, `maxSpeedKmh`, `avgSpeedKmh`, `likes`,
`upvotes`, `downvotes`, `comments`, `audience`, `allowedUserIds`) is
unconstrained for the ride's own owner. The elaborate `likeBumpValid`/
`voteBumpValid` machinery (rules:94-158,471-487) only constrains *other*
users reacting to a ride — it does nothing to stop the author.
`RideShareRepository.shareRide`
(`app/lib/features/social/data/repositories/ride_share_repository.dart:43-118`)
writes these fields straight from caller-supplied values, and the only
sanity/ceiling checks (`SensorConstants.maxPlausibleSpeedMs`) live in the
app's own UI code path (`ride_share_screen.dart:132-134`), not in rules.
Anyone signed in (modified APK, or a script with a valid ID token) can
write `maxSpeedKmh: 9999`/fabricated `distanceKm`/inflated `upvotes`
directly to their own `rides/{id}` doc and it becomes canonical truth in
the social feed and leaderboards. Same architectural flaw, lower blast
radius, on group rides: the creator-update clause at `firestore.rules:913-917`
is equally unbounded. **Fix:** add field-level `request.resource.data`
validation (type + plausible-range checks) to the shared-ride and
group-ride update/create rules, mirroring the existing bump-validation
pattern used for likes/votes.

### 62.2 Public profile stats and earned badges are entirely client-authored — CRITICAL

**Status: PARTIALLY FIXED / MITIGATED — full closure deferred.** Added
`publicStatsValid()`: `totalDistanceKm`/`totalRides` can now only move up
(never erase a real total) and are capped at generous absolute ceilings
(500,000 km / 100,000 rides) no real rider could plausibly reach;
`badgeIds` must remain a superset of what was already earned (no un-earning)
and is capped at 200 entries. This stops the concrete forgery this was
written against (an instant six-figure fake total, or every badge in the
catalog with zero rides) without requiring a per-write delta cap — which
would have been unsafe here, since `updatePublicStats` recomputes the
rider's FULL lifetime total from local data on every ride finalize (not an
incremental delta), so a small-delta bound would false-reject a legitimate
large recompute (e.g. after a reinstall restores years of ride history). It
deliberately does NOT re-derive totals from the rides subcollection
server-side, which is what would close the gap completely — that needs the
badge-criteria logic in `core/utils/badges.dart` ported to a Cloud Function
and verified end-to-end against a live project, which this pass couldn't do
safely without deploy/device access. Left as an open follow-up. `earnedBadges/{uid}`
was left unchanged: its own comment already establishes it's not currently
read by anything user-facing (the profile screen reads `publicStats.badgeIds`,
not this subcollection — confirmed via grep) — it's "groundwork for future
partner-discount lookup," so locking it down now was judged lower priority
than the field that's actually displayed. New tests:
`firestore_rules.test.js` (absurd distance denied; plausible first snapshot
succeeds; stats can't go backwards or drop a badge).

`firestore.rules:226-231` lets a signed-in owner write any field on their
own `users/{uid}` doc except `usernameLower`, so `publicStats.totalDistanceKm`/
`totalRides`/`badgeIds` (written by
`ProfileRepository.updatePublicStats`,
`app/lib/features/profile/data/repositories/profile_repository.dart:167-181`)
are never validated server-side. Separately, `earnedBadges/{uid}` is
`allow read, write: if request.auth.uid == uid` with no condition check
(`firestore.rules:292-294`), and
`ChallengeRepository.earnBadge`/`earnMilestoneBadge`
(`app/lib/features/social/data/repositories/challenge_repository.dart:109-155`)
let the client stamp any badge ID for itself. A rider can self-grant every
milestone badge and set any lifetime-distance total shown on their public
profile without ever riding. **Fix:** move badge-earning and public-stat
aggregation into a Cloud Function trigger off verified ride writes, and
lock both fields to `write: if false` for direct client writes.

### 62.3 Crash-alert pipeline is broken end-to-end — client never retries, server escalation can't run — CRITICAL (safety feature)

**Status: PARTIALLY FIXED.** The server-side half is fixed: added the
missing `crashNotifications` composite index (`status` ASC, `contactedAt`
ASC, COLLECTION_GROUP scope) to `firestore.indexes.json`, so
`escalateCrashAlert` can actually run instead of throwing
`FAILED_PRECONDITION` on every invocation — confirmed `functions/src/index.ts`
already wires up all three function modules correctly (the "nothing had a
wired entry point" concern didn't apply to the current code). The
client-side half — routing `CrashCoordinator.dispatchEmergencyNotification`
through the outbox for guaranteed delivery instead of a one-shot best-effort
write — was NOT attempted this session: it touches the live crash-recording
path with no device available to verify against, so it's left as a
follow-up rather than risking the actual safety feature on an unverified
change. This index fix still needs `firebase deploy --only
firestore:indexes` before it does anything in production.

Two independent bugs combine into total failure of the one feature meant
to matter most in a real emergency. Client side:
`CrashCoordinator.dispatchEmergencyNotification`
(`app/lib/features/ride/presentation/providers/helpers/crash_coordinator.dart:80-99`)
is a single best-effort Firestore `add()` guarded only by a
timeout+`debugPrint` (lines 101-110) — unlike ordinary ride data, which
goes through the durable `outbox_service.dart` retry queue, this write is
simply dropped on failure or if offline at the moment the crash countdown
expires (`ride_recording_provider.dart:940`). Server side, even when the
notification doc is created,
`functions/src/crash-notifications.ts:184-189`'s `escalateCrashAlert`
query (`collectionGroup('crashNotifications').where('status','==','contacted').where('contactedAt','<=',...)`)
has no matching composite index in `firestore.indexes.json`, so it throws
`FAILED_PRECONDITION` on every scheduled run — the follow-up escalation
for an unconfirmed contact silently never fires today. **Fix:** route the
crash notification write through the outbox for guaranteed delivery, and
add the missing composite index (then verify the function actually runs
via a manual trigger, since `functions/src/index.ts`'s own comment notes
nothing in `functions/` had a wired entry point until recently).

### 62.4 Chat participants and messages are fully rewritable by any participant — IDOR — CRITICAL

**Status: FIXED.** Chat-doc `update` is now restricted to exactly
`lastMessage`/`updatedAt` (`participants` is immutable as a side effect of
the allow-list, not a separate check). Message `update` is now restricted to
exactly `isRead: true` by a participant who is NOT the sender — closing both
the "rewrite another rider's message text/senderId" hole and the "flip
`isToxic` back to false, undoing the moderation hide" hole in one rule,
since `chat-moderation.ts`'s own write goes through the Admin SDK and
bypasses rules entirely, so it's unaffected. New tests:
`firestore_rules.test.js` (can't add a third party via update; CAN update
lastMessage/updatedAt; recipient can mark read but not rewrite text; sender
can't mark their own toxic-hidden message read).

`firestore.rules:1184-1207`: `allow update: if auth.uid in
resource.data.participants` has no field-level restriction, so either
party to a chat can rewrite `participants` itself — silently adding a
third uid to a 1:1 DM and granting a stranger full read access to the
whole conversation history without the other party's consent — or rewrite
any message's `text`/`senderId`, or flip a moderation-hidden `isToxic`
message back to visible, undoing `chat-moderation.ts`'s auto-hide. **Fix:**
restrict `participants` to immutable after create, and restrict message
updates to a narrow allow-list (e.g. `isToxic`/`reportedBy` only, never
`text`/`senderId`).

### 62.5 Chat toxicity filter is a 6-word English substring list — false sense of safety — HIGH

**Status: PARTIALLY FIXED.** The dishonest-status half is fixed: the
auto-filed report now starts `status: 'pending'` instead of `'actioned'`, so
it correctly waits for real admin review instead of claiming to already be
resolved (with a comment on `TOXIC_KEYWORDS` flagging it as a known-weak
placeholder). The keyword list itself is unchanged — replacing substring
matching with real NLP moderation (Bangla/Banglish-aware) is a real feature
project, not a bug fix, and out of scope here. The `reports/{reportId}`
create-validation half is fixed under §62 too: it now requires
`reporterId`/`reportedId`/`contentType`/`reason` to be well-shaped and
`status` to start `'pending'`, closing the "fabricate a pre-actioned report"
hole this finding also flagged. New tests: `firestore_rules.test.js`
(fabricated pre-actioned report denied; well-formed pending report
succeeds).

`functions/src/chat-moderation.ts:7-14,26`:
`TOXIC_KEYWORDS = ["idiot","stupid","jerk","dumb","hate","ugly"]` matched
via `.includes()`. Catches nothing in Bangla/Banglish (the app's actual
user base), nothing with trivial evasion (spacing/leetspeak), and
false-positives on innocuous text ("I hate potholes"). It auto-files a
`reports` doc already stamped `status: 'actioned'` even though nothing was
verified, so downstream tooling trusts unreviewed content as resolved.
Compounding this, `reports/{reportId}` create validation
(`firestore.rules:1176-1181`) only checks `reporterId` — any client can
also fabricate a pre-`'actioned'` report against an arbitrary target, and
there's no rate limit on report creation (spam/false-report flooding).

### 62.6 Sync layer: one bad row blocks an entire batch for bikes/maintenance (but not rides) — HIGH

**Status: FIXED.** `uploadBikes`/`uploadMaintenance` now try the batch first
and, on any failure, fall back to per-item writes (each wrapped in its own
try/catch, logged and skipped on rejection rather than aborting the rest) —
same shape `uploadRides` already used. Verified via `flutter analyze` +
`flutter test` (no dedicated new test added: this codebase's existing
convention, per `outbox_test.dart`'s own doc comment, deliberately excludes
Firestore-dependent delivery logic from unit tests in favor of
emulator/manual passes, and no mock-Firestore convention exists here to
extend for this).

`app/lib/core/cloud/cloud_repository.dart:120-165` (`uploadBikes`) and
`:168-183` (`uploadMaintenance`) have no per-item retry fallback after a
batch failure, unlike `uploadRides` (`:77-114`), which explicitly exists
to stop one bad row from sinking the whole batch (comment at :70-76). If
Firestore rejects any single bike/log in a batch, `batch.commit()` throws
uncaught and *no* item in that batch — including otherwise-valid ones —
gets marked synced, every cycle. **Fix:** apply the same per-item retry
pattern already used for rides.

### 62.7 Outbox race: concurrent `_attemptOne` and `drain()` can double-upload photos and lose a URL — HIGH

**Status: FIXED.** Replaced the `_draining` boolean (which only protected
`drain()` from itself) with a `Future`-chain mutex (`_serialized`) that both
`drain()` and `_attemptOne` now go through, so the two can never run
concurrently regardless of which one a caller triggers. Each link in the
chain swallows its own error so one failed attempt doesn't wedge the queue
for the next caller, while the real error still propagates to whoever
awaited that specific attempt. Verified via `flutter test
test/core/cloud/`.

`app/lib/core/cloud/outbox_service.dart:224-247`'s `_attemptOne` (called
synchronously from `enqueueShareRide`/`enqueueLiveSessionTeardown`/
`enqueueMaintenanceLog`) is not guarded by the `_draining` reentrancy flag
that protects `drain()`. If a rider taps "share ride" the instant a
timer/connectivity-triggered `drain()` is already running, both can call
`_deliverShareRide` (`:286-359`) on the same outbox entry concurrently:
both see `uploaded.length < localPaths.length`, both re-upload the same
photo to Cloudinary, and race on `_dao.updatePayload` (`:309-314`) —
last write wins, so one photo URL can be silently lost. **Fix:** guard
`_attemptOne` with the same reentrancy check, or key it per-entry-id.

### 62.8 Duplicated max-speed invariant enforcement, no shared ceiling outside one code path — HIGH

**Status: FIXED.** Extracted one shared implementation,
`RideSpeedInvariant` (new file, `app/lib/core/utils/ride_speed_invariant.dart`):
`reconcile()` floors max speed up to average and clamps it to a ceiling
derived from `SensorConstants.maxPlausibleSpeedMs` (no second magic
number); `reconcileFromDistance()` is the distance/duration convenience
wrapper. All four call sites now delegate to it — `RideEntity.maxSpeedKmh`
(refactored, output verified mathematically unchanged), `RideShareModel`'s
constructor and `fromFirestore` (the latter's own third reimplementation
was deleted outright, not just fixed, since the constructor already
reconciles), and `SharedRideEntity.maxSpeedKmh`. New test file:
`app/test/core/utils/ride_speed_invariant_test.dart` (8 cases: normal,
floor, ceiling, zero-duration). The related GPS-plausibility duplication
between `ride_recording_provider.dart` and `auto_ride_reconciler.dart` was
investigated but deliberately NOT consolidated — it turned out the two had
already drifted (see §62.14, a new, more specific bug found and fixed while
investigating this one), and touching either file's live/replay motion
logic further without a device to verify against was judged too risky for
this pass.

The "max speed ≥ avg speed" floor is independently re-implemented in three
places — `RideShareModel`'s constructor (`ride_share_model.dart:76-80`),
`SharedRideEntity.maxSpeedKmh` (`shared_ride_entity.dart:132-138`), and an
inline lambda in `RideShareModel.fromFirestore` (`:148-154`) — but *none*
of them apply the upper-bound clamp
(`SensorConstants.maxPlausibleSpeedMs`) that `RideEntity.maxSpeedKmh` does
(`ride_entity.dart:66-75`). This is exactly the class of bug commit
`0d94b70` ("restore maxSpeed in shared rides, enforce speed invariants")
already had to fix once, now fixed in three duplicate spots instead of
one shared function — it can silently regress in any one of them, and
combines with §62.1 (no server-side ceiling either) to leave GPS-jump
speeds essentially unbounded on the way to the social feed. Related:
`ride_recording_provider.dart:490-527` and
`auto_ride_reconciler.dart:150-213` independently re-implement the same
physical-acceleration GPS-plausibility bound with slightly different
shapes — a tuning fix to one is easy to miss in the other.

### 62.9 `deleteUserData` wipes unscoped tables on shared devices — MEDIUM

**Status: PARTIALLY FIXED.** `outbox` is fixed properly: every entry's JSON
payload already carries the owning uid (`userId` or `uid`, depending on
`OutboxKind`), so rows are now attributed and deleted by parsing that
payload — no schema change needed. `deleted_bikes`/`auto_fixes`/
`auto_detections` turned out to have NO owner column anywhere in their
schema or their writers (a real schema gap, not just a missing `WHERE`) —
properly fixing those needs a migration plus backfilling every writer,
including the background auto-detection isolate, which this pass couldn't
verify end-to-end without a device. Rather than guess at a migration, this
pass stops unconditionally wiping those three tables (the previous
behavior); the new worst case is the deleted account's own rows lingering
locally in those three tables (a cleanliness gap, not a confidentiality
one — never exposed to anyone but whoever's signed into the device), which
is strictly safer than the old behavior of silently deleting another signed-in
rider's live queue. Full fix (the schema migration) left as a follow-up.
New test: `app/test/database/delete_user_data_test.dart` (3 cases).

`app/lib/core/database/database_helper.dart:489-515` deletes
`deleted_bikes`, `outbox`, `auto_fixes`, and `auto_detections` entirely,
with no `WHERE user_id = ?` filter, while `rides`/`bikes`/`user_profiles`
are correctly scoped. On a shared device with a second signed-in account,
deleting account A wipes account B's pending outbox writes (in-flight ride
shares/maintenance syncs), bike-deletion tombstones, and any in-progress
auto-tracking detection for account B. Same family of bug as §33.1,
different tables.

### 62.10 Operational: weak/shared credentials and unencrypted keys on disk — MEDIUM

**Status: FIXED (the fixable parts).** `create_review_account.js` no longer
hardcodes `Test@123` — it generates a random 20-char password (once, for a
new account) unless one is explicitly supplied, and no longer silently
resets an existing account's password on re-run. `seed_qa_test_riders.js`
now generates a unique random password per rider instead of one shared
`QaSeed!2026` constant, and writes them to a local `0o600`,
gitignore-covered file (`scripts/qa_seed_passwords.<timestamp>.json`)
instead of printing them to stdout/CI logs. `update_places_google_ratings.js`
now hard-fails if `FIREBASE_PROJECT_ID` is unset, matching every sibling
script, instead of silently defaulting to the live project. `node --check`
clean on all edited files; `npm test` (scripts/) 33/33 passing, no test
needed updating (none hardcoded the old defaults). The unencrypted
`secret/creds.txt`/`secrets/*.json` files on disk are a local-machine
hygiene matter (password manager / keychain), not something a code fix
addresses — left as a standing recommendation, not a task this session
could "fix." `seed_police_checkposts.js`/`_v2`/`_v3` dedup remains
out of scope (§62.13).

Not a repo leak (all covered by `.gitignore`, confirmed untracked via
`git ls-files`), but real operational risk: `scripts/oneoff/create_review_account.js:65-66,246-249`
hardcodes `rider.admin@example.com` / `Test@123` for a permanent,
never-cleaned-up Play Store review account in the **live production**
project; `seed_qa_test_riders.js` uses one shared password (`QaSeed!2026`)
across up to 30 real, publicly-visible production accounts, and prints it
to stdout/CI logs on every run; `secret/creds.txt` and
`secrets/throttle-iq-gcc1-*.json` (a live GCP service-account key) sit
unencrypted on disk with no password-manager/keychain protection. Also,
`scripts/update_places_google_ratings.js:168` silently falls back to the
live `throttleiqfb` project ID if `FIREBASE_PROJECT_ID` is unset, unlike
every sibling script, which hard-fails — the weakest production-write
guard of any script in the directory.

### 62.14 Three smaller fixes made during the same pass (not separately numbered in the original standalone report's Issues.md summary, but present in the full report delivered to the user as findings #13/#14 and an architecture note)

**Status: ALL FIXED.**

- `app/lib/core/cloud/sync_manager.dart` (~lines 112,141): `_auth.currentUser`
  was null-checked once at entry, then force-unwrapped (`!`) after two more
  `await`s (connectivity check, `_outbox.drain()`). A sign-out in that window
  threw into the generic catch and was recorded as a sync *failure*
  (triggering backoff) instead of "skip silently, signed out." Now a
  mid-sync sign-out is detected and the sync cleanly returns to idle instead.
- `app/lib/core/database/daos/ride_dao.dart` (~line 109): the unawaited
  self-heal `db.update(...)` fired from inside read methods had no error
  handling — a transient sqflite error during the heal write vanished
  silently. Now has a `.catchError` that logs via `debugPrint` instead of
  dropping the error, without making the read path await the heal (that
  would change its performance characteristics, which wasn't the bug).
- `app/lib/core/cloud/outbox_service.dart`: the dead `OutboxService.instance`
  static singleton (separate from the Riverpod-provided instance used
  everywhere) turned out to have one real call site after all — a
  `SyncManager` optional-parameter default — not zero as the original note
  assumed. Fixed properly: the default now constructs a fresh `OutboxService()`
  instead of sharing the dead singleton, and the singleton itself was deleted,
  closing what would otherwise have been a silent second never-drained queue
  if that default path were ever actually exercised.

Verified via `flutter analyze` (clean) and `flutter test test/database/
test/core/cloud/` (100/100, including 3 new tests for the `deleteUserData`
fix in §62.9).

### 62.15 GPS-jump distance inflation in the auto-ride reconciler (found and fixed while fixing §62.8) — MEDIUM

**Status: FIXED.** While consolidating the duplicated max-speed logic for
§62.8, comparing `ride_recording_provider.dart`'s and
`auto_ride_reconciler.dart`'s GPS-plausibility branches surfaced a real,
separate bug: the live recorder zeroes `distDelta`/`accel`/`jerk` when a
sample is rejected as physically implausible
(`ride_recording_provider.dart`'s equivalent branch), but
`auto_ride_reconciler.dart`'s matching branch only zeroed `speedMs` — the
rejected sample's fabricated position-derived distance was still being
added to the ride total (`distanceM += distDelta` ran unconditionally
afterward). A single isolated GPS glitch on an auto-detected ride could
therefore inflate its recorded distance by however far the glitch jumped,
in a way a live-recorded ride cannot. Fixed by mirroring the live recorder's
behavior exactly: `distDelta`/`accel`/`jerk` are now zeroed in that branch
too. New test:
`app/test/calculators/auto_ride_reconciler_test.dart` ("a trailing
implausible GPS jump with no raw speed signal does not inflate distance") —
confirmed failing before the fix (distance inflated by the full ~5.5 km
synthetic jump) and passing after.

**Known remaining gap, not fixed:** this only closes the case where the
glitched fix itself is fully rejected (no raw speed signal AND implausible
derived speed). A single isolated GPS outlier also corrupts the position
`lastPoint` that the *next* fix measures its own distance from, and if that
next fix's own raw/reported speed happens to look plausible on its own
terms, its distance-from-a-corrupted-reference-point is still trusted in
both files today. Actually fixing that needs the motion-fusion logic in
both files to track a separate "last known-good position" from "last raw
fix," which is a real design change to code that runs on live GPS streams
in both the live-recording and auto-detection paths — too risky to make
blind in this pass without a device to verify against. Left as a follow-up;
the synthetic reproduction is in the test file above if picked up later.

### Verified non-issues (worth recording so they aren't re-flagged)

No SQL injection (all DAO queries are parameter-bound), no hardcoded
Firebase/API secrets in Dart or JS source, no XSS in any `public/`/
`website_demo/` HTML (the one `innerHTML` use in `live-viewer.html:820`
only renders hardcoded constants), no `child_process` usage anywhere in
`scripts/`, no unguarded `BuildContext`-after-`await` in the screens
sampled, `AuthNotifier.signOut` correctly signs out of both Firebase and
Google, and the account-switch data-leak class of bug from §33.1 is
already closed for rides/bikes/maintenance (just not for the four tables
in §62.9). The `public/live-viewer.html` Firebase Web API key is the
already-documented §1 non-issue, re-confirmed.

### 62.11 / 62.13 (part). Closed 2026-10-22 (moved from `issues_open.md`)

- **62.11 Storage rules ignore the ride's audience — OBSOLETE.** `storage.rules` was
  deleted in `f58bd8e1`; see §33.6 (rest).
- **62.13, two of the five architecture notes are done:** the counter-bump checks are
  one `voteBumpValid` helper (`firestore.rules:316`; `likeBumpValid` went with likes,
  §80), and the duplicate GPX/JSON export in `cloud_repository.dart` is gone
  (`app/lib/core/cloud/export_service.dart` is the only one). The other three stay in
  `issues_open.md` §62.13.

---

---

## 64. User report: chat/messaging shows `permission-denied` everywhere — stale/undeployed rules, same pattern as §47 — FIXED (2026-09-11)

User reported "the messaging thing" shows errors on the app. Narrowed via
follow-up: tapping the message icon from the Social screen (pushes to
`/chats`, `ChatListScreen` → `userChatsProvider` → `watchUserChats`) shows a
permission error immediately; searching for a rider in "New message" works
(reads `users`), but selecting any search result to start a chat
(`getOrCreateChat` → `chats` collection query + `.add()`) also shows a
permission error. Both symptoms are on the `chats` collection specifically.

**Root-caused, not a code bug — same pattern as §47/§29/§35/§37/§42.**
Reviewed `app/lib/features/chat/data/repositories/chat_repository.dart`
against `firestore.rules`' `match /chats/{chatId}` block line-by-line: every
read/write the client makes (`watchUserChats`'s `arrayContains` query,
`getOrCreateChat`'s existing-chat query and `.add()`, `sendMessage`'s batch,
`markMessagesAsRead`'s `isRead`-only update) matches the current rules file
exactly, including the stricter §62.4 IDOR-fix update rules. No logic bug
found in either the rules or the client code. The chat feature's Firestore
rules were added in `75b7b19` ("Feat: Add Trust & Safety... Chat
Messaging") and modified again in `9f6aaf8` (§62.4) — and this repo has no
CI that deploys `firestore.rules` on merge; it's a manual
`firebase deploy --only firestore:rules` step. If the live ruleset predates
either of those commits, every `/chats/**` operation falls through to the
catch-all `match /{document=**} { allow read, write: if false; }` at the
bottom of the rules file, which produces exactly this symptom (denied on
list, denied on create, nothing chat-specific in the client at fault).

**Fixed this session (user-approved, since it pushes straight to the
production project):** ran
`firebase deploy --only firestore:rules --project throttleiqfb`. CLI
output: `cloud.firestore: rules file firestore.rules compiled
successfully... firestore: released rules firestore.rules to
cloud.firestore` (one pre-existing, harmless compiler warning at rules line
288 — a null/map type hint inside `publicStatsValid`'s ternary — did not
block the deploy). This also released the §62/§62.4 chat-IDOR and §62.1/
§62.2 ride/profile-stat-forgery rule fixes, which per §62/§63's own notes
were verified but never deployed either — so this single deploy closes
that backlog too.

**Still needed: on-device re-verification** (not done this session — no
device/emulator access): Social → message icon → chat list loads; New
message → search → select a rider → chat opens and a message sends.

Requested explicitly as a second pass after §62, targeting areas the first
sweep hadn't reached: native platform config (`app/android`, `app/ios`),
CI, dependency versions, the Cloudinary upload service, the remaining
Dart feature modules (auth beyond a shallow pass, forums, poi_directory,
routes, stats), the three "god widget" screens flagged but not read in
depth, and a dedicated deep-dive on the safety-critical motion-fusion/
crash-detection calculators. Two genuine, verified bugs were found and
fixed; one (Cloudinary) is a real risk with no safe code-only fix available
this session. Everything else checked came back clean or already covered.

Verification after the fixes below: `flutter analyze` clean (still the same
~99 pre-existing info-level lints), `flutter test` **1021/1021** (was
1020 — added 1 new crash-detector regression test, confirmed to fail
against the pre-fix code via `git stash`), `cd functions && npm run build`
clean. Not deployed.

> Still open from this section: 63.3. Those parts are in `issues_open.md` under §64.

### 63.1 Account deletion silently destroys all user data even when the Firebase Auth deletion step fails, with a false "success" outcome — CRITICAL

**Status: FIXED.** `AuthNotifier.deleteAccount()`
(`app/lib/features/auth/presentation/providers/auth_provider.dart`) used to
run, in order: delete the Firestore profile + username claim → wipe the
local SQLite DB → `await user.delete()` (Firebase Auth) → sign out of
Google — all wrapped in `state = await AsyncValue.guard(...)`, which
captures a thrown error into `state` but does **not** rethrow it. Firebase
Auth's `user.delete()` commonly throws `requires-recent-login` (any session
older than ~5 minutes — i.e. almost any real "open Settings and tap Delete
Account" flow), and since that failure was never rethrown, the caller
(`settings_screen.dart`'s `try { await ...deleteAccount(); context.go(...)
} catch (e) {...}`) never saw an exception — the Firestore profile and every
local ride/bike/maintenance record were already permanently gone, but the
UI reported success and navigated to login with the Auth account (and its
credentials) still fully intact, so signing back in silently recreated a
blank profile as if nothing had happened. A real, common-path, irreversible
data-loss bug in the App-Store-mandated account-deletion flow.

Fixed by reordering so `user.delete()` runs FIRST — a failure there now
touches nothing else — and by making `deleteAccount()` actually rethrow the
captured error (`Error.throwWithStackTrace`) so callers' existing
try/catch blocks work as they always assumed. This reordering has a
structural consequence: once `user.delete()` succeeds the client is no
longer authenticated as that uid, and `firestore.rules` requires exactly
that to delete `users/{uid}`/`usernames/{handle}` — so the client can no
longer reliably clean those up itself afterward. That cleanup moved
server-side: new `functions/src/account-deletion.ts`'s
`onUserAccountDeleted` (a v1 `functions.auth.user().onDelete()` trigger,
chosen over a v2 blocking `identity` function specifically because it needs
no Identity Platform upgrade) runs with Admin SDK privileges whenever an
Auth account is actually deleted, regardless of the client's own
connectivity/timing. `ProfileRepository.deleteUserAccount()` (the old
client-side version of this cleanup) was deleted outright as dead code once
its only call site was removed.

**Not yet deployed** — until `firebase deploy --only functions` is run, a
successful account deletion leaves the Firestore profile/username claim
orphaned (a real but much lesser regression than the CRITICAL bug this
fixes: the rider's own data is gone either way once they've confirmed
deletion, and an orphaned doc is a cleanup gap, not a false "it's all gone"
that turned out to only be half true). No automated regression test was
added: `AuthNotifier`'s constructor eagerly instantiates `ProfileRepository()`,
which touches `FirebaseFirestore.instance` and requires
`Firebase.initializeApp()` — this repo has no Firebase-test-app
bootstrapping convention anywhere (confirmed via repo-wide search), so
unit-testing anything on this notifier needs that infrastructure built
first. Verified instead via careful manual tracing of the new ordering
against `firestore.rules`' actual permission model, plus `flutter analyze`.

**Deploy attempted 2026-09-11, blocked — needs your action:** `firebase
deploy --only functions:onUserAccountDeleted` fails with "Your project
throttleiqfb must be on the Blaze (pay-as-you-go) plan to complete this
command" — Cloud Functions require Blaze even for a trigger that will cost
effectively nothing at this project's volume (fires once per account
deletion). Upgrade at
https://console.firebase.google.com/project/throttleiqfb/usage/details,
then `firebase deploy --only functions:onUserAccountDeleted` deploys just
this trigger without touching the four other already-live functions. (Also
hit, and worked around by temporarily dropping `predeploy` from
`firebase.json` for the deploy attempt itself, then restoring it — unrelated
to the Blaze block: the Firebase CLI's bundled npm throws `Cannot read
properties of undefined (reading 'stdin')` on its predeploy hook in this
environment, even though `npm run build` run directly succeeds cleanly. If
deploying again from a shell where that CLI bug reproduces, either drop
`predeploy` for the one deploy and restore it after, or run `npm run build`
in `functions/` first and pass `--only functions:onUserAccountDeleted`
against the already-built `lib/`.)

### 63.2 Crash detector drops the jerk signal from the exact sample that opens its crash-accel window — false negative on a realistic single-impact crash — HIGH (safety-critical)

**Status: FIXED.** `EventDetector.detect()`
(`app/lib/features/ride/domain/calculators/event_detector.dart`) ran its
jerk-tracking block BEFORE its accel-spike block in the same call. Jerk is
acceleration's derivative, so a real impact's jerk peak coincides with —
not follows — its accel peak; but on the one sample where accel first
crosses the crash threshold, `_highAccelStart` was still `null` when that
same sample's jerk value was checked moments earlier in the code, so its
contribution to `_peakJerkInWindow` was silently discarded even though the
accel-spike block set `_highAccelStart` moments later in the very same
call. A single-sample impact — accel and jerk spiking together, then
settling as the bike tumbles — is arguably the *more* realistic crash
signature than two separate spikes on two separate samples, and it could
fail to register as a crash at all. Verified by hand-tracing
`detect(accel: 90, jerk: 12, ...)` then `detect(accel: -85, jerk: -8,
speedMs: 0.5)` — accel spike, jerk spike, and speed collapsing from normal
to near-zero in one sample interval (textbook crash) — never returning
`RideAlert.crash`.

Fixed by reordering the two blocks (accel-spike detection now runs first),
which preserves the existing anti-false-positive invariant from §33.8 (a
jerk spike from a call chronologically before any accel spike is still
correctly excluded — only the ordering *within* the one call that opens the
window changed) while closing the false-negative gap. New test:
`app/test/calculators/crash_detector_test.dart` ("DOES fire when accel and
jerk spike in the SAME sample") — confirmed to fail against the pre-fix
ordering via `git stash` (only this one test failed; all others were
unaffected, confirming the fix doesn't disturb the two- sample case) and
pass after.

---

## 65. User report: app feels "clunky and slow to respond" during ride sharing and pause/resume — MOSTLY FIXED (2026-09-17)

User reported general sluggishness specifically around sharing a live ride
and pausing/resuming recording. Started as a read-only audit (via a
research subagent plus direct verification of every claim against the
live code); §65.1–§65.5 and the newly-found §65.0 were then fixed in the
same session. §65.6 is flagged but not fixed. File:line references below
are relative to `app/`, as originally written; some line numbers have
shifted slightly now that the fixes are in.

Verification: `flutter analyze` clean (same ~99 pre-existing info-level
lints as §64), `flutter test` **1021/1021** (no new tests added — none of
these fixes had unit-testable seams without deeper refactoring; verified
by reasoning through the change plus analyze+full-suite-green, not by a
regression test).

> Nothing from this section is still open: 65.6 was closed as a non-issue (end of this section).

### 65.0 Live-shared position was frozen from the moment sharing was turned on — CRITICAL, found while fixing §65.1/§65.2, FIXED

Not part of the original audit — found while implementing the §65.1/§65.2
fixes below, verifying by hand how `LiveSessionCoordinator`'s periodic
timer actually re-published a position.

`LiveSessionCoordinator.enableLiveSharing()` (`live_session_coordinator.dart`,
old lines 47-85) started its own 10-second `Timer.periodic` whose `onTick`
closure was built from that method's own **parameters**
(`uid`/`rideId`/`lastLat`/`lastLng`/`currentSpeedMs`/`crashDetected`/`status`)
— plain values captured once, at the instant the rider first tapped the
share button. Every subsequent tick for the rest of the ride republished
that exact same snapshot. `_onPosition` (the per-GPS-fix hot path in
`ride_recording_provider.dart`) never calls into the live coordinator at
all, so nothing else kept it fresh either. Net effect: anyone following a
rider's live-share link saw them planted at one point on the map for the
entire ride, silently, with no error surfaced anywhere — this is a
correctness bug, not just a slowness one, and a considerably worse "clunky
ride sharing" experience than the loading-feedback issue in §65.1. The one
path that happened to work correctly was the cold-start branch of
`resumeRide()` (`ride_recording_provider.dart:735-746` at audit time),
which built its own periodic closure reading `state`/`_lastPoint` live —
this only ran after an app-kill-and-relaunch mid-ride, so it masked the bug
in exactly the scenario someone doing a quick device check after a
force-close would hit, while every ordinary "tap share and keep riding"
case stayed broken.

**Fixed:** `LiveSessionCoordinator.enableLiveSharing()` no longer starts
its own timer — it only publishes the first snapshot and returns. Starting
the periodic timer is now the caller's job via
`startPeriodicPublishing({required onTick})`, and `RideRecordingNotifier`
has a single `_startLiveSessionTimer()` helper (used by
`enableLiveSharing()`, `resumeRide()`'s cold-start branch, and the
warm-resume branch — see §65.2) whose `onTick` closure reads `state` and
`_lastPoint` fresh on every call, matching the pattern the cold-start
branch already used correctly. `LiveSessionCoordinator.publishLiveSession`
itself was untouched — it already read whatever was passed to it, the
bug was purely in what got closed over for the *periodic* calls.

### 65.1 Live-share button gives zero feedback and can sit dead for up to ~16s — HIGH, likely primary cause, FIXED

`active_ride_screen.dart:437` wires the share icon directly to
`onPressed: _shareLiveLocation` with no loading indicator and no disabling
of the button. `_shareLiveLocation` (`active_ride_screen.dart:198-215`)
awaits `RideRecordingNotifier.enableLiveSharing()`
(`ride_recording_provider.dart:662-675`), which awaits
`LiveSessionCoordinator.enableLiveSharing()`
(`live_session_coordinator.dart:48-85`) — that method runs **two
sequential** Firestore writes (the session doc, then the `livePointers`
doc), each independently wrapped in an 8-second timeout
(`kOutboxAttemptTimeout` in `outbox_service.dart:42`, used at
`live_session_coordinator.dart:131` and `:152`). On a weak connection —
this app's whole market is Bangladesh riders, where that's the common
case, not the edge case — a single tap can appear completely frozen for up
to ~16 seconds. Worse: `_liveShareEnabled` flips `true` synchronously on
the very first tap (`live_session_coordinator.dart:61`), but
`_currentLiveSessionToken` isn't set until the network call resolves
(`:109`) — so a rider who re-taps during that window, thinking the first
tap didn't register, gets `null` back immediately and nothing visibly
happens, reinforcing the "unresponsive" impression.

**Fixed:** `active_ride_screen.dart` now has a `_sharingLive` bool that
disables the button and swaps its icon for a `CircularProgressIndicator`
for the duration of `_shareLiveLocation()`, so a slow tap reads as
"working" instead of "broken", and a re-tap while in flight is a no-op
instead of racing. Separately, `LiveSessionCoordinator.publishLiveSession`
now fires the session-doc write and (on first share) the `livePointers`
write via `Future.wait` instead of one after the other, roughly halving
the worst-case wait on that first tap (two independent 8s-timeout writes
running concurrently instead of sequentially).

### 65.2 Pausing a live-shared ride doesn't stop the live-share heartbeat — MEDIUM, FIXED

`RideRecordingNotifier.pauseRide()` (`ride_recording_provider.dart:677-687`)
pauses the GPS and sensor subscriptions but never touches
`_liveCoordinator`. `LiveSessionCoordinator`'s 10-second
`Timer.periodic` (`live_session_coordinator.dart:89`) keeps firing
Firestore `.set()` calls with the last (stale) coordinates for as long as
the ride stays paused — only stopped when the ride is stopped or
cancelled (`_tearDownLiveShare`). Pure wasted battery/network work
competing with whatever else is happening on a paused screen, and
plausibly contributes to "feels busy" during a pause.

**Fixed:** `LiveSessionCoordinator` gained `pausePeriodicPublishing()`
(cancels the timer without clearing the token/enabled flag, unlike
`reset()`/`tearDownLiveShare()`). `pauseRide()` now calls it — plus fires
one best-effort (`unawaited`) publish reflecting the paused status, so a
live viewer sees "paused" instead of the feed just going quiet — and both
branches of `resumeRide()` (cold-start and warm) now restart the timer via
the same `_startLiveSessionTimer()` helper introduced for §65.0.

### 65.3 Post-ride "Share" does a synchronous full-route JSON encode on the UI thread — MEDIUM, FIXED

`OutboxDao.enqueue` (`app/lib/core/database/daos/outbox_dao.dart:75`) calls
`jsonEncode(payload)` inline on the calling isolate — not via `compute()`.
This is invoked the instant the rider taps "Share" in
`ride_share_screen.dart:123` → `OutboxService.enqueueShareRide`
(`outbox_service.dart:144-193`), whose payload includes the ride's entire
flattened polyline (`outbox_service.dart:181-183`). For a long ride
(thousands of GPS points) this is a plausible visible hitch at the exact
moment Share is tapped. (Photo uploads in the same flow are already
handled well — sequential per-photo with an 8s timeout each and a proper
`_sharing` spinner state in `ride_share_screen.dart:111,157-159` — the
JSON encode is the one un-mitigated piece.)

**Fixed:** `OutboxDao.enqueue`/`updatePayload` now encode the payload via
`compute(_encodeOutboxPayload, payload)` (a top-level function, required
by `compute`) instead of calling `jsonEncode` inline, moving the work off
the UI isolate for every outbox write, not just shares.

### 65.4 Social/feed screens do 2×N sequential Firestore round-trips — MEDIUM (adjacent), FIXED

`RideShareRepository._hydrate` (`ride_share_repository.dart:188-206`)
fetches a like-doc and a vote-doc per ride via two separate `Future.wait`
batches that run one after the other rather than concurrently. Called from
`getPublicRides`, `getSharedToMe`, and `getMyRides` — a 20-ride feed does
40 extra reads across two serial waves before anything renders. Not
sharing/pause-resume itself, but it's the screen a rider lands on right
after sharing, so it compounds the "everything near sharing is slow"
perception.

**Fixed:** `_hydrate` now starts both `Future.wait` batches (likes, votes)
before awaiting either, so they run concurrently instead of one after the
other — same number of reads, roughly half the added latency.

### 65.5 Sequential (non-batched) delete loops — LOW, FIXED

`RideShareRepository.deleteSharedRide` (`ride_share_repository.dart:354-371`)
and `GroupRideRepository.deleteGroupRide` (`group_ride_repository.dart:667-681`)
each `await` one document delete at a time instead of using a `WriteBatch`
or parallelizing. Unsharing a popular ride, or leaving a busy group ride,
stalls proportional to comment/like/member count.

**Fixed:** both now fetch their subcollection(s) concurrently (`Future.wait`
on the `.get()` calls) and then fire every `.delete()` at once via a single
`Future.wait`, instead of one `await` per document. Not converted to a
Firestore `WriteBatch` — these can exceed 500 writes in principle
(unlikely at this app's scale, but not impossible for the group-ride case
with `memberLocations`+`invitations`+`members`+`voiceNotes` combined), and
parallel deletes have no such limit.

### 65.6 Cold-resume freeze on a long interrupted ride — closed as a non-issue (2026-09-19; moved from `issues_open.md` 2026-10-22)

`RideRecordingNotifier.restoreInterruptedRide` rebuilds aggregates
(`ride_resume.dart`'s `rebuildRideAggregates`, two linear passes) and replays the
polyline (`_appendToPolyline`, decimated to a 2000-point cap) on the main isolate at
launch. Benchmarked 2026-09-19 against 36,000 synthetic fixes, a 4-hour ride at this
app's `distanceFilter: 3`: **~10 ms** on dev hardware (aggregates ~8 ms, polyline
~1.5 ms). A phone 3–5× slower stays under a visible frame drop, and a `compute()`
isolate would spend more on spawning and serialising than it saves. No change.

Ruled out in the same audit, so they aren't re-checked: the cockpit map
(`const _RouteMap()`) skips the per-tick rebuild; `sensor_fusion_coordinator.dart`
throttles UI pushes to 5 Hz against 20 Hz sampling; `ride_persistence_coordinator.dart`
batches SQLite writes; the polyline outbox payload already uses the flat-array format.

---

## 66. `bugs/a ride/` screenshot report — maxSpeed 0.0 with nonzero avg speed — ALREADY FIXED

A user-submitted bug report (two screenshots, no text, dropped in
`bugs/a ride/` on 2026-09-09 at 11:23 local capture time / 12:23 file
mtime) shows a shared ride detail screen: Max Speed 0.0 km/h next to Avg
Speed 15.0 km/h, Distance 4.0 km, Duration 15:56 — an impossible
combination (max can't be below average for a non-degenerate ride).

**Already fixed by `0d94b70`** ("fix(social): restore maxSpeed in shared
rides, enforce speed invariants, and fix UI wrapping"), committed
2026-09-09 at 12:34 — 11 minutes after the screenshot was captured, almost
certainly the fix this exact report triggered. `RideSpeedInvariant.reconcile`
(`app/lib/core/utils/ride_speed_invariant.dart`) now floors max speed up to
average when it's missing/implausibly low, and all four call sites
(`RideEntity`, `SharedRideEntity`, `RideShareModel` constructor +
`fromFirestore`) route through it per §62.8. Verified 2026-09-19: all 32
tests in `ride_speed_invariant_test.dart`,
`shared_ride_speed_invariant_test.dart`, and `outbox_test.dart` pass.
**No further action needed.**

---

## 67. "End Ride" felt frozen on a slow connection — MEDIUM, FIXED

User report (2026-09-19): tapping "End Ride" on beta-2.8 could hang for
several seconds before returning to the summary/share screen, felt like
"a lot of processing." Root cause was not processing at all: `stopRide()`
(`ride_recording_provider.dart:798`) awaits `_tearDownLiveShare()`, which
called `LiveSessionCoordinator.tearDownLiveShare` →
`OutboxService.enqueueLiveSessionTeardown(..., attemptNow: true)` (the
default) → `_attemptOne`, a real Firestore write with an 8s timeout,
serialized behind `_queue` (so it can also wait behind any other in-flight
outbox operation, e.g. a still-uploading share photo). Every single "End
Ride" tap blocked the UI on up to 8+ seconds of network I/O on a bad
connection — exactly the class of bug the outbox pattern exists to avoid,
but this one call sat on the synchronous path anyway. The same blocking
call also sat in `cancelRide()` and `restoreInterruptedRide()` (the latter
delaying the "we kept your ride" recovery banner at app launch).

**Fixed:** `LiveSessionCoordinator.tearDownLiveShare`
(`live_session_coordinator.dart:192`) now calls `enqueueLiveSessionTeardown`
with `attemptNow: false`. The local, near-instant durable SQLite enqueue
(already off-isolate-encoded per §65.3) still happens before the method
returns — so nothing is lost if the app is killed a moment later — but the
network confirmation wait is gone from all three call sites at once.
[SyncManager]'s periodic drain delivers the teardown in the background,
same as every other outbox entry. Verified: `flutter analyze` clean on the
changed files, `outbox_test.dart`'s 18 tests (which exercise
`enqueueLiveSessionTeardown`) still pass.

Distinct from §65.6 (the cold-*resume*-at-launch freeze, confirmed a
non-issue by benchmark): this is the everyday End Ride tap, and the delay
was real network latency, not CPU work — an isolate/`compute()` fix
wouldn't have touched it.

---

## 68. Shared rides didn't carry a riding score — feature, shipped

User ask (2026-09-19): "why not show me done and later calc" (→ §67
above) plus "can we share a bit more telemetry, riding score... gamified
so users feel fun when they share." `computeRidingScore()`
(`core/utils/riding_score.dart`) already existed and drove the private
per-ride summary screen, but `SharedRideEntity`/`RideShareModel` never
carried the three event counts (`hardBrakeCount`/`rapidAccelCount`/
`highJerkCount`) it needs — a shared ride had no score to show at all.

**Shipped**, per user's chosen direction (simple tier-colored badge, event
counts included as the score's inputs but not separately exposed):

- `core/utils/riding_score.dart`: added `RidingScoreTier` enum +
  `ridingScoreTier(int score)` — the pure threshold logic factored out so
  it has one home instead of being reimplemented per screen (the private
  summary screen's inline `score >= 80 ? ... : score >= 60 ...` was
  refactored to call this too).
- `SharedRideEntity`/`RideShareModel`: added nullable `hardBrakeCount`/
  `rapidAccelCount`/`highJerkCount` and a `ridingScore` getter that's null
  unless all three are present — deliberately not defaulted to 0, since a
  ride shared before this existed has no honest score and would otherwise
  show a false 100/"Smooth op." Threaded through
  `RideShareRepository.shareRide` → `OutboxService.enqueueShareRide` →
  `_deliverShareRide` → Firestore, and populated from `RideEntity`'s
  existing counts at the one call site, `ride_share_screen.dart`'s
  `_share()`.
- `firestore.rules`: added `ridingScoreCountsPlausible` (folded into
  `rideStatsPlausible`, same backstop pattern as §62.1/§62.8) — each count,
  where present, must be a non-negative integer no larger than the ride's
  `durationSeconds`, closing the obvious forgery (claim negative counts,
  always show a perfect score). **Not verified against the emulator** — no
  Java runtime available in this session to run
  `scripts/test/rules/firestore_rules.test.js`; syntax was reviewed by hand
  against the existing `rideStatsPlausible` pattern it extends, but treat
  this as unverified until that suite runs.
- UI: a tier-colored badge (score + "Smooth op."/"Steady"/"Aggressive" +
  icon) on both the social feed card (`social_screen.dart`'s
  `_RidingScoreChip`) and the shared-ride detail screen
  (`shared_ride_detail_screen.dart`'s `_RidingScoreBadge`), hidden entirely
  on rides shared before this existed rather than showing a misleading
  default.

Verified: `flutter analyze` clean, full `flutter test` suite (1029 tests)
passes, including new coverage in `riding_score_test.dart`,
`shared_ride_entity_test.dart`, and `ride_share_model_test.dart` for the
null-until-all-three-present behavior and the Firestore round-trip.

---

## 69. Full-repo critique pass — 12 fixed, 16 open (2026-09-19)

A read-through of the whole repo (Flutter app, Cloud Functions,
`firestore.rules`, hosted pages, platform config, docs). Baseline before
any change: `flutter analyze` 0 errors / 0 warnings / 97 infos,
`flutter test` 1032/1032, `functions` `tsc --noEmit` clean. After: analyze
**No issues found** (0 infos), `flutter test` 1032/1032, `tsc` clean,
rules emulator suite **98/98** (`npm run test:rules` in `scripts/`, 4 new
tests). **Nothing here is deployed yet** — see "Deploy needed" at the end.

> Still open from this section: Open, Deploy. Those parts are in `issues_open.md` under §69.

### 69.1 FIXED — HIGH — §68's riding-score rule rejected shares with null counts

`ridingScoreCountsPlausible` used `data.get('hardBrakeCount', 0)`. `get`
only falls back to the default when the key is **absent**, but
`RideShareModel.toMap()` always writes the three keys, as explicit `null`
when unknown. Any outbox share queued before §68 shipped (payload has no
counts) would reach Firestore with `hardBrakeCount: null`, fail
`null is int`, and get permission-denied. That ride would then retry
forever (see 69.O4). §68 flagged this rule as never run against the
emulator. Fix: a `scoreCountPlausible(count, durationSeconds)` helper that
accepts `null` explicitly. New emulator tests cover null counts
(allowed), plausible counts (allowed) and negative counts (denied).

### 69.2 FIXED — HIGH — deleting a group ride with any voice note failed half-way

`GroupRideRepository.deleteGroupRide()` deletes every
`memberLocations`/`invitations`/`members`/`voiceNotes` doc, then the ride.
The rules had `allow update, delete: if false` on `voiceNotes`, so one clip
was enough to make the whole `Future.wait` throw permission-denied. By then
the other deletes had already landed, so the ride doc survived with no
members. Fix: the ride creator may delete voice notes. Update stays `false`.
The existing emulator test that asserted "nobody, including the creator,
can delete" was encoding the bug. It's now split into "nobody can update"
and "only the creator can delete".

### 69.3 FIXED — HIGH — Stop during a crash countdown still sent an emergency alert

`stopRide()` never disposed the `CrashCoordinator` (`cancelRide()` did).
Tapping Stop while the 60 s crash countdown was running left the timer
ticking, and ~60 s later it dispatched a `crashNotifications` doc for a
ride the rider had just ended by hand. The lock-screen crash alert also
stayed up. Fix: `stopRide()` now disposes the coordinator and cancels the
alert, the same as `cancelRide()`.

### 69.4 FIXED — MEDIUM — `stopRide()` flushed the point buffer in the wrong order

`_persistenceCoordinator.dispose()` (which fires an **unawaited** flush
that empties the buffer synchronously) ran before the awaited
`flushPointBuffer()`. So the awaited flush always found an empty buffer and
waited on nothing. If the unawaited insert failed, the last fixes went back
into a buffer nobody reads again. Fix: await the flush, then dispose.

### 69.5 FIXED — MEDIUM — SyncManager could wedge itself off for the whole session

`_outbox.drain()` ran **outside** the `try/finally` that resets
`_isSyncing`. Any throw from it (e.g. the outbox table failing to open)
escaped with `_isSyncing == true`, and every later `_performSync()`
returned immediately until the app restarted. Fix: drain moved inside the
`try`.

### 69.6 FIXED — MEDIUM — two concurrent sync passes

`_isSyncing` was only set **after** `await checkConnectivity()`. Two
triggers landing together (`startAutoSync()` plus the connectivity
listener's initial event) both passed the guard and ran two full
upload/download passes in parallel. Fix: claim `_isSyncing` before the
first `await`, and release it on the offline early-return.

### 69.7 FIXED — LOW — ethernet/VPN counted as offline

Connectivity was "mobile or wifi". A result of only `vpn`/`ethernet`/
`other` meant no sync ever ran and every attempt counted as a failure
(backoff up to 30 min). Fix: any result other than `none` counts.

### 69.8 FIXED — HIGH (privacy) — account deletion left the rider's cloud data behind

`onUserAccountDeleted` called `users/{uid}.delete()`. Deleting a Firestore
document **does not delete its subcollections**, so cloud ride history,
GPS tracks, bikes, maintenance, emergency contacts (third-party PII),
badges, notifications and blocks all stayed, orphaned. Shared rides
(`rides` where `userId == uid`), live sessions, crash notifications and
follow edges were never touched either. Fix: `recursiveDelete` on
`users/{uid}` plus each owned top-level doc, each step isolated so one
failure doesn't strand the rest. **Still open:** content authored in other
people's spaces (forum posts/replies, place reviews, comments on others'
rides, group-ride membership, chats). That needs a product call on
anonymizing vs. deleting (69.O2).

### 69.9 FIXED — MEDIUM — chat moderation hid innocent messages

`TOXIC_KEYWORDS.some(w => text.includes(w))` is a substring match:
"whatever" contains "hate", "dumbbell" contains "dumb", "beef jerky"
contains "jerk". All of these were rewritten to "*** hidden ***" and filed
as reports. Fix: whole-word `\b…\b` regexes. The list itself is still the
known-weak placeholder from §62.5.

### 69.10 FIXED — LOW — crash-alert log said `sent` for a mock

`notificationLog` entries were written with `status: 'sent'` even though
delivery is a MOCK (§24.8), so anyone reading the log would take it as proof
a contact was reached. Now `status: 'mock_not_sent'`. Nothing in the app or
rules reads this collection. Also: `CrashNotification.status` gained the
`'escalated'` value the escalation job already writes, and the location
check no longer treats a `0` coordinate as missing.

### 69.11 FIXED — LOW — riding-score badge/chip hard-coded English

§68's `_RidingScoreBadge`/`_RidingScoreChip` used literal `'Smooth op.'`/
`'Steady'`/`'Aggressive'`/`'Riding Score'`, even though
`scoreSmoothLabel`/`scoreSteadyLabel`/`scoreAggressiveLabel`/
`ridingScoreLabel` already exist in both ARBs. They now use
`AppLocalizations`.

### 69.12 FIXED — hygiene

- `dart fix --apply`: 87 mechanical lint fixes across 44 files (mostly
  `const` in tests, redundant `sqflite` imports).
- `print` → `debugPrint` in `export_service.dart`,
  `image_compression_utils.dart`, `main.dart`.
- Deprecated `Switch.activeColor` → `activeTrackColor`, and the report
  sheet's `RadioListTile.groupValue/onChanged` → `RadioGroup`.
- `flutter_cache_manager` declared explicitly (`^3.4.2`). It's imported
  directly by `add_edit_bike_screen.dart` but was only a transitive
  dependency of `cached_network_image`.
- `DatabaseHelper.schemaVersion` is now one constant. `14` was hard-coded
  twice (open + test schema builder) and could drift at the next migration.

### 69.13 FIXED (2026-09-19) — six of §69's Open items closed

Follow-up pass over `issues_open.md`'s §69 Open list, picking off the
items that were plain code/config fixes rather than product decisions or
device verification:

- **69.O7** `firebase_messaging` was declared in `pubspec.yaml` but never
  imported anywhere in `app/lib/` — confirmed by grep, then by `flutter pub
  get` reporting it (plus its two platform-interface packages) as "no
  longer being depended on" after removal. Also dropped the matching
  `<service android:name="com.google.firebase.messaging.FirebaseMessagingService">`
  block from `AndroidManifest.xml`, which was declaring a service for a
  dependency that no longer exists. Updated the two docs that referenced
  it (`store_listing/data_safety_and_permissions.md`,
  `architecture/assumptions.md` Assumption 17) to say it was removed rather
  than "declared but unused"/"wired".
- **69.O9** Removed the dead `liveSessions(userId, expiresAt)` composite
  index from `firestore.indexes.json`. Confirmed by grep that every
  `liveSessions` access in `app/lib/` is a keyed `.doc(token)` `get`/`set`
  (`outbox_service.dart`, `live_session_coordinator.dart`) — nothing does a
  `where`/`orderBy` query against the collection, and the field is `uid`,
  not `userId`, so the index was both unused and wrong.
- **69.O11** `DatabaseHelper._initDb`'s corruption handler now renames the
  unopenable file to `<path>.corrupt-<epoch-ms>` instead of calling
  `deleteDatabase`, before rebuilding a fresh db and continuing. An
  unsynced rider's rides/bikes/maintenance logs are now recoverable by hand
  after a corruption event instead of gone the instant it's detected.
  (Falls back to the old `deleteDatabase` only if the file has already
  disappeared by the time the handler runs.)
- **69.O12** `SharedRideEntity.props` gained `distanceKm`,
  `durationSeconds`, `polyline`, `audience`, `likes`, `comments`,
  `hardBrakeCount`, `rapidAccelCount`, and `highJerkCount` — previously
  Equatable equality only looked at `id`/`userId`/`rideDate`/`createdAt`/
  `isLikedByCurrentUser`/`upvotes`/`downvotes`/`myVote`/`caption`/
  `photoUrls`, so a change to any of the newly-added fields (including the
  riding-score counts §68/§69.1 just added) was invisible to `==` and to
  any Riverpod/widget code that rebuilds on entity inequality.
- **69.O13 (partial)** The ~34 code comments across `app/lib/` and
  `app/test/` citing `docs/Issues.md §N` / `docs/planning/Issues.md §N`
  now point at `DOCS/Handoff for agents and Todos/issues_open.md or
  issues_fixed.md §N` (mechanical find-and-replace; which of the two files
  a given `§N` is actually in still has to be found by searching, same as
  before — see this file's and `issues_open.md`'s own header note). The
  `DOCS/For Devs and Contributers` typo is fixed too: renamed to `DOCS/For
  Devs and Contributors` (`git mv`) and every reference to the old spelling
  updated (`README.md`, `DOCS/README.md`,
  `store_listing/store_listing.md`, `marketing/business_critique.md`,
  `marketing/marketing_lead_notes/NEEDS_YOUR_ATTENTION.md`,
  `issues_open.md`). **Not touched:** `docs/pitch.md`/
  `marketing/pitch_and_marketing_materials.md` — off-limits by standing
  instruction unless asked, so its one stale reference to the old folder
  name was left as-is; and the missing-design-assets half of 69.O13, which
  is a product call ("presumably intentional"), stays open in
  `issues_open.md`.
- **69.O15** `.gitignore`'s blanket `*.lock` now carries `!app/pubspec.lock`
  and `!app/ios/Podfile.lock` negations. Both files exist on disk and are
  now untracked-but-trackable (confirmed via `git status`); this pass
  didn't `git add`/commit them, since committing is a repo-state decision
  the user should make explicitly, not something to slip in as a side
  effect of an unignore.

Verified: `flutter pub get` (confirms the dependency removal), `flutter
analyze` (No issues found), `flutter test` (1035/1035 — new figure vs.
§69's 1032/1032 baseline includes tests added since, not from this pass),
`npm run test:rules` (98/98, unaffected — no `firestore.rules` changes
here, only `firestore.indexes.json`), and `python3 -m json.tool` on
`firestore.indexes.json`. Not yet re-verified on a device (nothing here
touches a runtime path a widget/rules test wouldn't already cover, except
the corrupt-DB rename, which needs an actual corrupted db file to trigger
on a real install to be certain of).

### 69.14 DEPLOYED (2026-09-19) — §69's rules/hosting deploys shipped; functions still Blaze-blocked

With user go-ahead, deployed the three pending §69 targets in the
documented order:

- `firebase deploy --only firestore:rules` — released. `firebase.json`'s
  compile step reported the same pre-existing `[W] 313:46` warning noted
  since §69 itself (unrelated `publicStatsValid`/`usernameLower` logic).
- `firebase deploy --only firestore:indexes` — released, including this
  session's 69.O9 removal of the dead `liveSessions(userId, expiresAt)`
  index. (Not part of the original §69 "Deploy needed" list, but bundled in
  since it's the same `firestore.indexes.json` file and a strictly
  risk-reducing change — the index was confirmed unused.) The deploy noted
  4 indexes live on the project that aren't in this repo's
  `firestore.indexes.json` — left alone; deleting them needs `--force` and
  wasn't asked for.
- `firebase deploy --only hosting` — released. Confirmed live: `curl
  https://throttleiqfb.web.app/privacy.html` shows the corrected
  microphone/voice-clip disclosure.
- `firebase deploy --only functions` — **failed**: `Your project
  throttleiqfb must be on the Blaze (pay-as-you-go) plan to complete this
  command`. This is the same Spark-plan blocker documented since §24/§33.5
  under "Soon" in `HANDOFF_Document.md` — not a new problem, and not
  something fixable from this session (it's a billing-plan decision on the
  project owner's account). The account-deletion trigger (§69.8), the
  moderation false-positive fix (§69.9), and the mock-status-log fix
  (§69.10) all remain undeployed.

**Environment note, worth keeping:** the standalone `firebase` CLI's
bundled npm (`firepit`'s vendored npm@8.19.4/node@20.18.2, invoked via a
custom `--script-shell` wrapper for the functions `predeploy` hook) threw
`TypeError: Cannot read properties of undefined (reading 'stdin')` when run
from this harness's non-interactive shell, before ever reaching the Blaze
check — reproducible, unrelated to this project's code (`npm run build`
via the system npm/node works fine and was used to verify the TypeScript
compiles cleanly). Worked around by temporarily removing `firebase.json`'s
functions `predeploy` hook (the build was already done and verified by
hand), deploying, then restoring the hook — which is how the real Blaze
error above was reached. If this recurs, that's the thing to work around,
not a project regression.

### 69.15 DONE (2026-09-19) — QA test riders reseeded

Closed the "Reseed the QA test riders" to-do (open since §55, 2026-08-29):
with user go-ahead, ran `cleanup_qa_test_riders.js --yes-i-really-mean-it
--non-interactive` (removed 237 user docs, 30 usernames, 42 shared rides,
60 forum posts, 30 Auth accounts — the stale 2026-08-27 batch) then
`seed_qa_test_riders.js --yes-i-really-mean-it --non-interactive` against
the current script (30 created, 0 skipped, 0 failed). `--non-interactive`
was needed because both scripts' typed-confirmation prompt expects a real
terminal; ADC (`gcloud auth application-default login`, already configured
per `HANDOFF_Document.md`'s operational notes) supplied credentials without
needing `GOOGLE_APPLICATION_CREDENTIALS` set explicitly.

`scripts/README.md`'s "Live roster" table is regenerated from a live
Firestore read of the new batch (handle/name/bike/city per rider,
forum-post distribution), not recomputed from the script's source — ground
truth over inference. New account passwords landed in a fresh
`scripts/qa_seed_passwords.<timestamp>.json`, gitignored and not committed.

### 69 (rest). Open-list items closed 2026-10-22

Moved from `issues_open.md` §69 after a check against `main` (`3ebbd21d`).

- **69.O1 Microphone in the privacy policy:** the page is fixed and deployed (above).
  The Play Console Data safety answer for audio is part of owner item #4; public
  voice-note URLs are `issues_open.md` §33.5.
- **69.O2 Account-deletion scope:** decided and built. `onUserAccountDeleted`
  (`functions/src/account-erasure.ts`) keeps authored community content under a
  deleted-rider byline, anonymises the rider's chats (`84dd97d6`) and sweeps their
  Cloudinary assets. It runs once Cloud Functions can deploy (Blaze, owner items #3
  and #31).
- **69.O4, 69.O10:** fixed on `fix/grill-78` (§78.A–§78.C).
- **69.O5 Localization coverage:** done by the localization pass (§83.23 (rest)).
- **69.O6 Cloud Functions runtime:** done. `functions/package.json` pins Node 22 and
  `firebase-functions` ^7.4.0; `firebase.json` sets `nodejs_22`.
- **69.O8 `USE_FULL_SCREEN_INTENT`:** decided 2026-10-21 (owner item #8): keep it and
  file its Play declaration with the first submission (owner item #4).
- **69.O13 Design assets not carried into `DOCS/`:** dropped on purpose; they stay in
  git history.
- **69.O16 `docs/` vs `DOCS/` casing:** resolved in the 2026-09-19 reorg commit
  (`git rm -r --cached docs && git add DOCS`). This disk has `core.ignorecase=true`;
  watch for it on any case-only rename.
- **Deploy:** the rules and Hosting deploys were done 2026-09-19. The functions deploy
  stays open in `issues_open.md` §69.

---

## 70. User report: "Sign up" crashed with `GoException: no routes for location: /auth/register` — FIXED (2026-09-19)

**Status:** Fixed.

Tapping "Sign up" on the login screen (`login_screen.dart:136`,
`context.go('/auth/register')`) threw a `GoException`. Root cause: no
`GoRoute` for `/auth/register` was ever registered in
`app_router.dart` — only `/auth/login` and `/auth/onboarding` exist under
`/auth`. `RegisterScreen` (`register_screen.dart`) exists and links back to
`/auth/login`, but was never wired into the router at all.

Fix: imported `RegisterScreen` and added
`GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen())`
in `app_router.dart`, alongside the `/auth/login` and `/auth/onboarding`
entries. `computeAuthRedirect`'s existing `loc.startsWith('/auth')` check
already covers the new path generically (an authenticated user landing on
`/auth/register` gets redirected to `/home/record`, same as `/auth/login`)
— no redirect-logic changes needed.

Added a regression test in `app_router_test.dart` covering
`computeAuthRedirect` for `/auth/register` (signed-out stays put, signed-in
gets bounced to `/home/record`, same as `/auth/login`). `flutter analyze`
clean. Not yet verified by tapping through on a running app/device.

---

## 71. Feature: "Reset Service Log" — bulk mark-as-serviced for maintenance items (2026-09-19)

**Status:** Shipped.

Added a way to reset multiple tracked maintenance checks at once instead of
logging each one individually. New `restart_alt` icon button on the
Maintenance screen's action bar (`maintenance_screen.dart`, next to "Sync
Odo"/"Customize"/"Log") opens `ResetMaintenanceLogSheet`
(`presentation/widgets/reset_maintenance_log_sheet.dart`), a checklist of
every tracked check (icon, current OK/Due soon/Overdue status, km since last
service) with "Select All"/"Clear" and per-item checkboxes — tick some or
all, confirm via an `AlertDialog`, and each ticked item resets its interval
countdown.

**Design decision (asked the user explicitly, since the two options have
very different data-safety properties):** "reset" logs a fresh
`MaintenanceEntity` dated now at the bike's current odometer for each
ticked `ServiceType` — the same insert+outbox path `addLog` already uses —
rather than deleting prior log history. This was the deliberate choice: the
codebase has no delete-sync/tombstone mechanism for maintenance logs (unlike
bikes, which have a `deleted_bikes` table), so a delete-based "reset" would
have had already-synced logs silently reappear after the next
`downloadMaintenance()` pass. That gap still exists and would need new
plumbing (outbox delete kind + Firestore delete + local exclusion list,
mirroring the bikes pattern) if a true history-wipe is ever wanted.

New `MaintenanceNotifier.resetItems(serviceTypes, {required odometerKm})` in
`maintenance_provider.dart` batches the inserts and outbox enqueues, then
invalidates state once.

Verified: `flutter analyze` clean on all touched files, new
`maintenance_provider_test.dart` coverage (`resetItems` group: resets ticked
types while preserving prior history, no-op on empty selection). Not yet
manually tried in a running app.

---

## 72. Marketing-asset audit: two overclaims caught and fixed before any ad ran (2026-09-19)

Surfaced while building install-driving marketing assets (`DOCS/General/posters/`,
`DOCS/General/posters/social/`) — nothing shipped to users, but both would
have overclaimed to a public ad/poster audience had they gone out as-is.

**72.1 — Safety Check-In screenshot implied live crash-contact delivery.**
The real app screenshot used in two social-ad creatives
(`social-05-family-parent`, `social-06-family-spouse`, cropped from
`DOCS/General/website_demo/assets/ui/{carbon-mono,editorial-bw}.png`) carries
its own on-screen copy: *"Looked like a hard stop. We'll gently check in
with your emergency contacts if we don't hear from you"* plus a "Notify
contacts now" link — with no caveat that delivery isn't live. Same
underlying gap as §69.O3/§33 (crash-alert SMS/email is mock end-to-end,
blocked on Blaze billing) and the same risk already flagged for Settings in
§32 (which at least says "aren't live yet" — this screen didn't). The
surrounding ad copy was already written to stay opt-in-only, but the
screenshot's own text didn't match.

**Fix:** masked the paragraph and the "Notify contacts now" line out of both
cropped screenshot PNGs in `DOCS/General/posters/social/screenshots/`
(background-color rectangles, precisely bounded so the "Everything okay?"
title, checkmark, progress bar and primary button are untouched), then
regenerated both creatives. Re-running `crop_screenshots.py` from the
source sheets will undo this masking — the fix lives in the derived
`screenshots/*.png` files, not the source UI sheets — so a future re-crop
needs the same redaction reapplied (or the in-app copy fixed to add the
same "aren't live yet" caveat Settings has, which would make this
unnecessary).

**72.2 — Street-poster footer claimed iOS availability that doesn't exist.**
Every v1 poster (`posters.py`'s shared `qr_block()`, all 24 posters) and
both original v3 posters (`posters_v3.py`'s `footer()`) printed "iOS +
ANDROID" — but per `HANDOFF_Document.md`, no App Store listing or
TestFlight build exists yet. Only the newer social-ad creatives
(`social.py`) had already been written with the honest "ANDROID NOW · iOS
শীঘ্রই" framing.

**Fix:** `posters.py` line 25 now reads "ANDROID NOW · iOS SOON";
`posters_v3.py`'s footer now reads "FREE · OFFLINE-FIRST · ANDROID NOW ·
iOS শীঘ্রই" (matching `social.py`'s wording, font size dropped 15→14 to
match its proven-safe width). All 24 v1 posters and all 6 v3 posters
regenerated (svg/print/web) via the existing `.venv` cairosvg pipeline; v2
was unaffected (its `qr_corner()` never had this text).

Verified: all regenerated SVGs are well-formed, spot-checked PNGs show no
text overflow and no visible mask seams. No git commands run — the poster
directories are still mid-reorg and untracked, left for the user to stage.

## 73. Two screens that failed to render, found by the automated UI screenshot tour — FIXED (2026-09-19)

Both surfaced while building the 28-combination screenshot set
(`DOCS/General/screenshots_ui/`, tour in `app/integration_test/ui_tour_test.dart`).
Both were in committed code and hit real users, not just the tour.

**73.1 — Ride summary map threw "Cannot modify unmodifiable map".**
`ride_summary_screen.dart`'s `TileLayer` passed
`NetworkTileProvider(headers: const {...})`. flutter_map writes its own
`User-Agent` entry into that map, so the `const` map threw on first build and
the map section rendered as an error box (a red screen in debug). **Fix:**
dropped the `const` (with a comment saying why).

**73.2 — Place detail rendered blank for any place with a phone number.**
The Directions/Call row puts the Call `OutlinedButton` in a `Row` without
`Expanded`, and the theme's `OutlinedButton` `minimumSize` is
`Size.fromHeight(...)`, which means infinite width. Layout failed ("BoxConstraints forces an
infinite width") and the whole detail list below the app bar came out empty.
**Fix:** the Call button now sets its own
`minimumSize: Size(0, AppDimensions.controlHeight)`. Other buttons were left
alone. Any other theme-styled button placed in a `Row` without
`Expanded` would hit the same trap.

---

## 75. Feature: "Change bike" correction for the most recently finished ride (2026-09-19)

**Status:** Shipped.

Requested: a way to fix a wrong bike pick after ending a ride, for the case
where the rider forgot to switch the active bike before starting. Scoped
deliberately to **only the single most recently completed ride** — not any
ride in history — since an older ride's bike may already be the basis for
distance-based maintenance reminders someone has acted on, and a
general "edit any past ride's bike" control would invite silently rewriting
stats far from where the mis-tap happened.

New `ChangeBikeControl` (`presentation/widgets/change_bike_control.dart`) on
the ride summary screen (`ride_summary_screen.dart`) shows a "Logged to
{bike} · CHANGE" row, visible only when: the rider has 2+ bikes, this ride's
id matches the new `latestCompletedRideIdProvider` (backed by
`RideDao.getMostRecentCompletedId()`, `ORDER BY start_time DESC LIMIT 1`
scoped to `status = 'completed'`), and `BikeConfirmationCard` (the existing
prompt for an unconfirmed auto-detected ride) isn't already showing for the
same ride — the two controls are never both visible at once. Tapping it
opens the same bottom-sheet bike picker pattern as `BikePickerCard`
(`bike_picker_card.dart`'s `BikeRow`).

**No new persistence path** — reused `RideAttribution.confirm()`
(`auto_tracking_provider.dart`), previously reachable only from
`BikeConfirmationCard`'s auto-detected-ride flow. It already moves
per-bike distance/ride-count stats via `BikeDao.moveRideStats()` and sets
`bike_confidence: confirmed` + `synced: 0` via
`RideDao.confirmBikeAttribution()`, so the corrected bike reaches Firestore
on the next normal sync pass with no Firestore-specific update call needed.

`confirm()` now also invalidates `rideDetailProvider(ride.id)`,
`riderStatsProvider`, and `rideHistoryProvider` for both the old and new
bike id — previously it only invalidated `garageProvider` and
`unconfirmedAutoRidesProvider`, so the ride summary screen and stats
wouldn't reflect a correction until the next unrelated refetch. This also
improves the pre-existing `BikeConfirmationCard` flow, which shares the same
method.

Localized (`loggedToBikeLabel`, `changeBikeSheetTitle` — English + Bengali).

Verified: `flutter analyze` clean (whole project), `flutter test` 1038/1038
including new `RideDao.getMostRecentCompletedId` coverage
(`test/database/ride_dao_sync_and_finalize_test.dart`) and the ARB parity
test. Not yet manually tried in a running app.

---

## 76. Fix: "Change bike" didn't update an already-shared social post (2026-09-19)

**Status:** Shipped.

Reported the same day §75 shipped: correcting a ride's bike via the new
`ChangeBikeControl` left an already-shared social post showing the old
bike forever.

**Cause:** `RideShareRepository.shareRide()` denormalizes `bikeId`/
`bikeName`/`bikeType` onto the Firestore `rides/{rideId}` doc once, at
share time, resolved from whatever bike was in the garage when the rider
tapped Share (`ride_share_screen.dart`'s `_share()`). It is a snapshot, not
a live reference to the ride's bike. `RideAttribution.confirm()` — the
method behind both `ChangeBikeControl` and the pre-existing
`BikeConfirmationCard` — only ever touched the local SQLite `rides` row and
per-bike stats; nothing re-invoked the share path, and no update/resync
method for an existing share existed at all.

**Fix:** new `RideShareRepository.updateSharedRideBikeInfo(rideId, {bikeId,
bikeName, bikeType})` patches just those three fields on the shared doc via
`.update()`. `RideAttribution.confirm()` now calls it (fire-and-forget,
`unawaited`) after the local correction succeeds, looking up the new
bike's `displayName`/`cc` via `BikeDao().getById()` +
`BikeModel.fromMap()`. `update()` throwing `not-found` (the ride was never
shared — the common case) is treated as a normal no-op, not an error;
any other failure is caught and logged, never surfaced to the rider or
allowed to undo the local fix that already happened. No `firestore.rules`
change needed — the existing owner-update rule already allows a partial
field patch that leaves stats/audience/engagement counters untouched.

Verified: `flutter analyze` clean (whole project), `flutter test`
1038/1038. No dedicated test added for the Firestore call itself — this
codebase doesn't unit-test `RideShareRepository` (no fake-Firestore
harness; only DAOs get real in-memory SQLite coverage). Not yet manually
verified against a real shared post.

---

## 77. Feature: private ride summary restyled to match the social ride-detail screen, plus new telemetry (2026-09-20)

**Status:** Shipped, not yet visually verified on a device (build device
went `unavailable` mid-session — see "Not yet verified" below).

Requested directly: the private ride summary screen (reached after ending
a ride, or from any past ride in history) looked plainer than the social
shared-ride-detail screen, and should be restyled to match — "but with
more details and telemetry download and all extra features you can think
of."

**Shared widgets extracted** (so both screens draw from one implementation
instead of two copies drifting apart):
- `shared/widgets/metric_card.dart` (`MetricCard`) — the icon+accent-color
  stat tile, pulled out of the social screen's private `_MetricCard`.
- `shared/widgets/riding_score_badge.dart` (`RidingScoreBadge`) — the
  gamified tier-colored score badge, pulled out of `_RidingScoreBadge`.
- `shared/widgets/full_screen_route_map_screen.dart`
  (`FullScreenRouteMapScreen`) — the full-screen interactive route
  explorer (pinch-zoom, tap-to-inspect waypoints, save-route action),
  generalized off `SharedRideEntity` to plain primitives
  (`polyline`/`title`/`subtitle`/stats + an `onSaveRoute(BuildContext)`
  callback) so a private ride can push the same explorer with its own
  save-route behavior. `shared_ride_detail_screen.dart` now imports all
  three instead of defining its own; its own copies (~550 lines) were
  deleted. `ride_line_chart.dart` gained an optional `xLabels` override so
  its existing sparkline (until now only used for "stat over time across
  rides") can also plot "value over one ride's route" without pretending
  the x-axis is dates.

**Ride summary screen (`ride_summary_screen.dart`) changes:**
- The 4-stat row, jam-time row, and hard-brake/rapid-accel/high-jerk row
  are now icon+color `MetricCard` tiles instead of plain `StatCell`s in a
  divided row — matching the social screen's per-metric color coding
  (distance=secondary, duration=success, avg=warning, max=primary, etc.).
- The riding score is now the shared `RidingScoreBadge` (tier-colored,
  icon, big number) instead of a flat black number tile + separate label
  card.
- New **Riding Pace** card (min'sec"/km — same formula the social screen
  already used, now also shown privately).
- The route map is now **interactive** (pinch/zoom/pan, was
  `InteractiveFlag.none`) with a "tap map to expand" hint, and a FAB stack
  (zoom in/out, recenter, fullscreen, save-as-route) — while keeping this
  screen's own superior feature, the speed-banded polyline coloring, rather
  than reverting to the social screen's flat line.
- New **Route GPS Details** card (track-point count, start/end
  coordinates, "Explore Full Route on Map").
- **Save as Route** is now reachable directly from ride summary (map FAB
  and the Route GPS Details card's full-screen map) via the existing
  `/routes/save/:rideId` form — previously only reachable via the separate
  share flow.
- New **Speed Profile** mini chart (speed-over-route, `RideLineChart`,
  downsampled to 60 points via a new generic `core/utils/downsample.dart`,
  factored out of the polyline-only `downsamplePolyline`).
- New **Elevation Gain/Loss + Elevation Profile** section — entirely new
  surfaced data: `ride_points.altitude_m` has been recorded since early on
  but was never shown anywhere. New pure calculator
  `domain/calculators/elevation_profile.dart` (`elevationGainLoss`,
  smooths raw altitude with a moving-average window before summing deltas,
  the same "don't trust raw deltas" principle `jam_time.dart`/
  `speed_baseline.dart` already apply) returns null — hiding the whole
  section — when altitude is mostly missing, too short a sample, or
  variation is within noise floor, rather than showing a fabricated
  number. Most existing rides on phones with no barometer will show
  nothing here, honestly.
- New **CSV telemetry export** (`ExportService.exportRideToCSV`) alongside
  the existing JSON/GPX — every raw per-point column the recorder captured
  (speed, acceleration, jerk, altitude, heading, GPS accuracy, cornering
  flag, period type), for a rider who wants to drop a ride into a
  spreadsheet rather than just replay its route. The export row grew from
  2 buttons to a `Wrap` of 3 under a new "Telemetry" section label.
- Fully localized (English + Bengali) — new ARB keys for every new label;
  the pace/GPS-coordinate/chart values themselves stay numeric like the
  rest of the screen's existing duration formatting.

**No change to the social screen's behavior or appearance** — it now reads
from the shared widgets but renders identically; `shared_ride_detail_screen_test.dart`
(unchanged assertions, just re-pointed to import `FullScreenRouteMapScreen`
from its new location) still passes.

Verified: `flutter analyze` clean (whole project), `flutter test`
1048/1048 (new coverage: `test/core/utils/downsample_test.dart`,
`test/calculators/elevation_profile_test.dart`; the CSV export itself has
no dedicated test, consistent with `exportRideToJSON`/`exportRideToGPX`
never having had one either). **Not yet verified on a device** — the
connected iPhone (`Abraar's iPhone`) went `unavailable`
(`xcrun devicectl list devices`) partway through this session, after the
last successful build/install/launch (§75's device check). Re-run
`flutter build ios --release -d <device>` + `xcrun devicectl device
install/launch` once it reconnects, and tap through a real ride summary
before calling this visually done.

---

## 78. Antigravity grill fixes, branch `fix/grill-78` (2026-09-20)

These are fixes for the code-doable items in `issues_open.md` §78 and three
from §69 (O4, O6, O10). Six parallel agents did the work, one per area
(parts A–F below). All six parts were merged into `fix/grill-78`, which was
then fast-forwarded into **`main` and pushed (e351b6c, 2026-09-20)**. That
push also carried the 39 older `master` commits that had never reached
`main`. **Nothing is deployed**, and none of it has run on a device. What's
still open stays in `issues_open.md` §78.

**Before the next `firestore.rules` deploy:** ship an app build from this
code first. The new chat-create rule rejects chats from older builds
(§78.27). CI has never run on GitHub; this push is its first run.

**Verified on the combined branch:**
- `flutter analyze` is clean.
- `flutter test` passes 1174/1174 (baseline 1048).
- The rules emulator passes 112/112 (baseline 98).
- `functions` builds with `npm run build`.

**Schema:** `DatabaseHelper.schemaVersion` is now 16.
- v15 (part B): `rides.track_synced`, `bikes.archived`,
  `auto_detections.user_id`.
- v16 (part C): `outbox.status`, `outbox.permanent_failures`.
- Both steps are gated on `newVersion`, so partial-schema migration tests
  stop where they should.

### 78.A Crash and sensor pipeline (commit 5882f59)
- **78.1:** new `ImpactDetector`
  (`features/ride/domain/calculators/impact_detector.dart`).
  - Input: raw `UserAccelerometerEvent` samples, taken before the
    low-pass filter.
  - Spike: ≥ 39 m/s² (provisional), or 3 samples in a row at the ride's
    highest reading (for phones whose sensor clips).
  - Confirmation: a GPS stop within 5 s, then 3 s of stillness or the
    phone tipping more than 45°.
  - **Live wiring is off:** `SensorConstants.impactDetectorLiveEnabled =
    false`. It stays off until the founder chooses how alerts are sent
    (`DOCS/Handoff for agents and Todos/needs_attention.md` b) and the field and drop tests in
    claude_sol §1.1.1 step 6 pass.
  - The GPS-accel crash branch is off the live path
    (`detect(detectCrash: false)`).
- **78.2:** the jerk peak uses `math.max`.
- **78.3 / 78.13:** hard-brake and rapid-accel counts have one owner
  (GPS before axis calibration, IMU after). Counting uses hysteresis
  (trigger −4, re-arm −2), and the cooldown refreshes on every counted
  event. Brake, accel and overspeed alerts expire after 5 s. The IMU
  raises no events before calibration.
- **78.11:** GPS gaps between 3 s and 60 s credit moving time from
  distance ÷ average speed (`movingMsForGap`). `resumeRide` resets the
  last fix time, so the paused interval isn't counted as moving.
- **69.O10 (stats half):** the pure function `buildFinalRideStats` is
  shared by `stopRide` and the crash finalize. The crash finalize now
  writes full stats and starts an upload. That upload includes crash rides
  only once the `getUnsynced` change from part B lands.

Verified: `flutter analyze` clean, `flutter test` 1086/1086 (38 new).
**Not verified:**
- No test drives the full `RideRecordingNotifier`. The pipeline test stops
  at `SensorFusionCoordinator`.
- Every impact threshold is uncalibrated.
- The hysteresis and the 5 s alert expiry haven't been felt on a real
  ride.

### 78.B Local database and sync (commit c2d75e1)
- **69.O10 (sync half):** `RideDao.getUnsynced` and the history lists
  include `status = 'crash'`. The lists don't show a "crash" badge yet.
- **78.5:** new `rides.track_synced` column. `SyncManager.syncPendingTracks`
  retries a trail until its upload succeeds. `finalizeRide` resets the
  flag. Existing rides re-upload their trail once, which is safe because
  chunks are keyed by index. `track_synced` is stripped from the Firestore
  payload so older app versions don't break.
- **78.4:** `RideTrackLoader.load` reads local points, else downloads them
  from the cloud. The summary, share, save-route and export screens use it.
  The summary map shows "Fetching route…" and "Route not available"
  states.
- **78.9:** `auto_detections.user_id` is stamped from the uid saved with
  `FlutterForegroundTask.saveData`. It is set before auto-tracking starts
  and removed on sign-out. The reconciler is scoped to the owner.
  - Unowned legacy rows older than 7 days are discarded.
  - Newer unowned rows are claimed only if no other rider's rides or bikes
    are on the device.
- **78.6 + claude_sol §1.3.3:** bikes are archived, not deleted.
  - The garage and all pickers hide archived bikes. Stats and ride lists
    still include their rides.
  - A collapsible "Archived bikes" section offers Unarchive.
  - Deleting a bike together with its rides is still possible, but the
    rider has to type the bike's name first.
  - The remote delete runs in chunks of ≤400 and deletes each ride's
    `track` subcollection.

### 78.C Live links and outbox (commit b90e05f)
- **78.7:** ending a ride now sets `shareable:false` and uses a
  server-timestamp `updatedAt`. The teardown also clears
  `livePointers/{uid}` when the session doc is already gone.
  - The owner can delete the doc (`allow delete` rule).
  - The live-share button on the active ride screen opens "Share link
    again" and "Stop sharing now".
  - A new rules test file, `live_sessions_rules.test.js`, has 4 tests.
- **69.O4:**
  - `drain()` only replays entries owned by the signed-in rider.
  - Permanent Firestore errors mark an entry `dead` after 3 failures, and
    any entry is marked dead after 20 attempts.
  - A new Settings → "Sync issues" screen (`/sync-issues`) lists dead
    entries with Retry and Discard. The tile appears only when there are
    dead entries. Its strings aren't localized yet.
  - `_attemptOne`, the immediate attempt right after enqueue, is not
    scoped to the signed-in rider.

### 78.D Social, chat, places (commits 3f20621, a78fd9c)
- **78.8:** `PrivacyZoneClipper` clips by straight-line radius (200–349 m,
  stable per rider via `seedForUid`). Only the leading and trailing runs
  are trimmed.
- **claude_sol §1.6.1:** `core/utils/geo_math.dart` replaces all six
  haversine copies. The `motion_calculator.dart` copy was swapped in a
  follow-up commit.
- **78.15:** `core/utils/num_cast.dart` (`asDouble`) replaces every raw
  `] as double` cast. CI now blocks new ones.
- **78.14:** DM ids are fixed (`dmId`): the two uids sorted and joined.
  - Chats are created in a transaction, with a one-time fallback to find
    an existing chat with an old random id.
  - The rules require that id on create. **Builds from before this
    change can't start new chats once the rules are deployed.** Chats
    that already exist still work.
- **Chat UX:**
  - `profileProvider` is now autoDispose.
  - The chat list hides blocked riders.
  - When either rider has blocked the other, a "You can't message this
    rider" banner replaces the input. A narrow new rule lets a blocked
    rider read the one block doc naming them.
  - A failed send restores the typed text and offers Retry.
- **claude_sol §3.5.2:** the profile screen now tells apart a private
  profile, being offline, and other load errors, with Retry where it
  helps.
- **78.17:** the nearby-places query uses geohash ranges.
  `GeohashUtil.coverCircle` picks the precision: 25 km uses precision 4
  with at most 12 cells. There is a new composite index on (`category`,
  `geohash`), not deployed.
- **78.10:** the voice queue awaits `_voicePlayer.stop()` in `finally`.
- **claude_sol §2.3.3:** the OSM import writes in batches of 400 with
  `osm_…` doc ids.

### 78.E UI and copy (commit cecdd04)
- **78.19:** the Calming Light primary is now `#537D5C` (4.71:1 on
  white). `palette_contrast_test.dart` checks all 14 palette and
  appearance combinations. Only Calming Light was failing.
- **78.20:** the pause dimming now covers only the map.
- **claude_sol §3.1.1:** the end-ride dialog is replaced by
  `EndRideSheet`. It has a 72 dp hold-to-end button (1.2 s), a 56 dp share
  row, and a 56 dp "Keep riding" button.
- **claude_sol §3.1.2:** the cockpit text has a minimum size (labels 14,
  values 20) through `AppTypography.cockpitLabel`/`cockpitValue`.
- **78.22:** Directions asks "Record & go" or "Just directions", with a
  "Don't ask again" option.
- **78.23:** Add Place won't save without a picked location.
- **78.24:** SafeQR can share its QR code as a PNG. Print sticker is not
  done (the `printing` package isn't a dependency). The share screen's
  close button now pops back instead of jumping to the Record tab.
- **78.25 (in-app part):** a warning banner on Emergency Contacts, plus a
  one-time acknowledgement when the first contact is added. It's in EN and
  BN, and **the Bangla needs a native-speaker review**.
- **Maintenance:** the Maintenance screen gets a back button, and bike
  detail gets a "Service & maintenance" card. Adding a bike pops back with
  a "Set service intervals" SnackBar action. The configure screen pops when
  it's the first-time setup.
- **Smaller items:**
  - Tour banner colors come from the theme, with a 48 dp close button.
  - Notification bell on the Social and Record screens.
  - "Browse routes →" button.
  - 48 dp maintenance button on the garage card.
  - Avg moving speed plus moving/stopped time replace pace on the ride
    summary.
- **Found, not fixed:** `HoldToStartButton` has the same same-frame
  press/release flaw that the new button fixes.

### 78.F Infrastructure (commit 992a0ba)
- **78.18 (CI part):** `.github/workflows/ci.yml` has three jobs.
  - `flutter`: Flutter 3.44.9, analyze, test, and the blocking cast
    guard.
  - `rules`: JDK 21 plus `npm run test:rules:ci`.
  - `functions`: build.
  - It hasn't run on GitHub yet.
- **78.16:** `shared/widgets/app_tile_layer.dart` is used at all 8 map
  sites.
  - The URL, key and attribution come from `--dart-define TILE_*`, and
    default to OSM.
  - The User-Agent now names the app and a contact.
  - Tiles are cached on disk for 30 days (`flutter_map_cache` 2.1,
    `dio_cache_interceptor` 4, `http_cache_file_store` 2).
  - **Release builds without the `TILE_*` defines still hit OSM directly.**
    A tile provider has to be picked (`DOCS/Handoff for agents and Todos/needs_attention.md`).
- **69.O6:** `functions` now runs on Node 22 with `firebase-functions` 7
  and `firebase-admin` 14.
  - Three functions moved to v2. `onUserAccountDeleted` stays on the v1
    API.
  - Not deployed (Blaze). Any 1st-gen copies of the migrated functions
    must be deleted before the first deploy.

### Not verified on a device (whole §78 batch)
- Crash detector thresholds (part A), plus the hysteresis and the alert
  expiry.
- Downloading a trail on a fresh install, and the background isolate
  reading the saved uid.
- Voice queue with 3 clips.
- The chat create transaction against live Firestore.
- The end-ride sheet's feel.
- Cockpit fonts on 360 dp phones.
- SafeQR PNG sharing.
- All the new sheets, banners and dialogs.

### 78 (rest). Open-list items closed 2026-10-22

Moved from `issues_open.md` §78 after a check against `main` (`3ebbd21d`).

- **78.16 Tile provider:** chosen. Release builds use Thunderforest: `scripts/deploy.sh:139-145`
  takes `TILE_*` from the environment or the git-ignored `secret/tiles.env` (`2f892e35`).
  `public/privacy.html`'s map-tiles row still says OSM; owner item #2 covers that edit.
- **78.18 CI:** `.github/workflows/ci.yml` runs on GitHub and is green. `main_ruleset`
  still requires no status checks: owner item #16.
- **78.25 The pitch:** `DOCS/Handoffs for Non Coding Agents/marketing/iDEA_PITCH_SUBMISSION.md`
  now says crash detection is off and alert delivery isn't built (lines 7, 38, 54-55), and
  `gov-pitch/` was deleted in the 2026-10-22 DOCS restructure. The team slide is part of
  owner item #22.
- **78.27 Chat-create rule vs old builds — OBSOLETE.** The rule went live with the
  2026-09-21 rules deploy, so the "ship the app before the rules" order no longer
  applies. Builds from before the fixed DM id can't start new chats.
- **78.28 Bangla review** of the fix-pass strings waits with the rest in `issues_open.md`
  §83.23 (owner item #12).

## 79. Places screen: "Browse routes →" button clashes visually with its neighbors — FIXED (2026-09-20)

Surfaced by a user question ("why does the routes button look like a
clusterfuck") and fixed same session. `places_list_screen.dart:126-134`.
Two separate problems:

- **Inconsistency bug:** the button hardcoded
  `OutlinedButton.styleFrom(minimumSize: const Size(0, 48))` instead of
  inheriting the theme default (`Size.fromHeight(AppDimensions.controlHeight)`,
  52dp boxy / 54dp curvy per `app_theme.dart:190-206`) — it was the only
  button in the app shorter than the theme and not skin-aware. **Fix:**
  dropped the `style:` override entirely; it now inherits the theme like
  every other `OutlinedButton` does.
- **Design collision:** the button was deliberately shrink-wrapped +
  left-aligned (`Align(alignment: Alignment.centerLeft)`) to read as
  distinct from the category-chip row above it (comment citing
  `claude_sol.md §3.2.5` — navigation, not a filter). But it sat right under
  those pill-shaped, small, non-mono chips with only 8dp of padding, so the
  "this is different" intent read as "these don't match." **Fix:** removed
  the `Align`/custom `minimumSize` so it's now a normal full-width
  `OutlinedButton.icon` (matches the app's other themed buttons), and bumped
  the top padding above it from `8` to `AppDimensions.paddingMd` (16) for
  clearer separation from the chip row.

`flutter analyze` on the file: no issues. Not yet verified on a device/simulator screenshot.

---

## 80. `likes` retired: votes are the only engagement model (2026-09-20)

Found while seeding §79: 14 likes were written to a post and never showed
up in the app, though the comments did.

**Why:** two engagement models were live at once. The feed
(`social_screen.dart`) and the ride detail screen show
`upvotes`/`downvotes` backed by `votes/{uid}`. The like count was rendered
in exactly one place, the My Shared Rides card
(`my_shared_rides_screen.dart:113`), so a like was invisible to everyone
but the rider who left it — and every feed load still paid an extra
per-ride read to hydrate `isLikedByCurrentUser`.

**Fixed (commit d7a915b):** `likes` and `isLikedByCurrentUser` are removed
from `SharedRideEntity`, `RideShareModel`, `RideShareRepository`
(including `toggleLike` and the like half of `_hydrate`) and
`RideFeedNotifier`. The heart is gone from the My Shared Rides card. The
share-delete path still sweeps legacy `likes` subcollection docs, so
deleting a ride leaves nothing behind. Two ride-share tests were
re-pointed from `likes` to `upvotes`/`comments`.

`firestore.rules` is untouched and still passes: its create clause reads
`request.resource.data.get('likes', 0) == 0`, which holds now that the
client never writes the field. The rules' `likes` clauses can be dropped
on the next rules pass.

Verified: `flutter analyze` clean, `flutter test` 1174/1174.

**Live data migrated (2026-09-20).** On the §79 post
(`5a905c0a-…`), each of the 14 `likes/{uid}` docs became
`votes/{uid} = {value: 1}`: 1 upvote → **15** (14 seeded + 1 real), like
docs deleted, `likes` field removed. A full sweep of the `rides`
collection found **no like documents on any other ride**.
`seed_qa_test_riders.js` no longer writes a `likes` count (33 script tests
still pass). What remains is cosmetic — see `issues_open.md` §80.

---

## 81. Active ride screen: RECORDING / PAUSED status pill removed (2026-09-20)

**Change (owner request, not a bug):** the `_StatusPill` widget at the top-left
of `active_ride_screen.dart` (red dot + "RECORDING", amber dot + "PAUSED") is
deleted, along with its use in the header row. The elapsed timer and the
live-share icon remain, right-aligned via the existing `Spacer`.

**Side effect to know about:** the pill was the only text label for the
paused state in the header. Paused is still shown by the glowing Resume
button and the dark scrim over the map (`if (isPaused)`), but a rider glancing at the header no
longer sees a word saying so.

Verified: `dart analyze` clean on the file. `flutter test` not re-run; no test
referenced the pill. Not checked on a device.

---

## 82. Places category chips (Fuel/Garage/etc.) fail with "Something went wrong, try again" — "All" works (2026-09-20)

**User report:** on the Places screen, selecting "All" showed results, but
tapping any specific category chip (Fuel, Garage, ...) failed with the
generic "Something went wrong, try again." error.

**Root cause:** the category-filtered nearby-places query needs a
Firestore composite index on `(category ASC, geohash ASC)`
(`app/lib/features/poi_directory/data/repositories/place_repository.dart`,
`_fetchGeohashRange`). That index was added to `firestore.indexes.json`
(lines 77-90) in commit `3f20621` (2026-09-20, "fix(geo): radius privacy
clipper, shared haversine, num casts, geohash nearby query") but was
**never deployed** to the live `throttleiqfb` project — already flagged
as "not deployed" in §78.17 below.

- Tapping "All" (`_selectedCategory = null`) skips the `category`
  equality filter entirely, so only the existing geohash-range query
  runs — no missing index needed, works fine.
- Tapping any specific chip adds
  `.where('category', isEqualTo: category.name)` alongside the geohash
  range filter, which requires the composite index. Firestore throws
  `FirebaseException(code: 'failed-precondition')`.
- `app/lib/core/utils/firebase_error_mapper.dart` (`mapFirestoreError`)
  had no case for `failed-precondition`, so it fell through to the
  generic "Something went wrong loading this. Please try again."
  message, masking the real cause.
- Same failure pattern as the crash-alert escalation index (§~3774) and
  the Discover/Rider-forums indexes (§178): index defined in the JSON
  file, never pushed live.

**Fix:**
1. Ran `firebase deploy --only firestore:indexes --project throttleiqfb`
   — the pending `(category, geohash)` composite index on `places` is
   now deployed (confirmed via `firebase firestore:indexes`). Index
   builds are async; allow it a few minutes to finish for large
   collections.
2. Added a `'failed-precondition'` branch to `mapFirestoreError`
   (`app/lib/core/utils/firebase_error_mapper.dart`) returning "This
   isn't ready yet. Please try again in a few minutes." so a future
   missing/building index is recognizable instead of showing the same
   generic message as every other error.

Verified: `flutter test test/core/utils/firebase_error_mapper_test.dart`
— 11/11 passed.

---

## 83. Full-app critique pass — fixed parts (2026-09-21)

Surfaced 2026-09-20 (writeup: `ANTIGRAVITY_GRILL/Claude_CRTITISIZE.md`), fixed
the next day. **Still-open sub-items keep their numbers in `issues_open.md` §83.**

Verification for the whole pass: `flutter analyze` clean, `flutter test`
**1195/1195** (was 1174 — 21 new tests), rules emulator **113/113** (was 112),
`npm run build` in `functions/` clean.

### Safety claims (81.1-81.4)

- **81.1 — the disabled crash detector is no longer advertised.** Removed or
  corrected every claim that the app detects crashes: `README.md`'s Safety
  section now opens with an explicit "**NOT live**" warning and splits
  shipped-vs-switched-off; `arch.md`'s opening paragraph carries the same
  warning; the onboarding tour's "Crash Shield" pointer and "Instant crash
  detection" bullet are gone (`onboarding_manifest.dart`), replaced with
  features that exist, and `kOnboardingManifestVersion` bumped 2 → 3 so
  existing riders are re-shown the corrected tour.
  - **Also found and removed while there:** the tour advertised a **lean-angle
    gauge** and a **"SHIELD: ARMED"** badge and **"10Hz GPS"**, none of which
    exist — lean angle is a HANDOFF Part 2 *backlog* item, the app has no
    shield, and GPS runs at ~1 Hz behind a 5 m filter. All three were drawn in
    `onboarding_ui_mockups.dart`, a hand-made illustration of a real screen
    with nothing to catch the drift. Corrected to what the cockpit actually
    shows, with a comment saying so.
- **81.2 — the crash function no longer claims contacts were reached.** A
  `DELIVERY_IMPLEMENTED` constant now gates the status: while delivery is a
  mock the notification settles at `mock_not_sent`, not `contacted`, and
  `escalateCrashAlert` deliberately does not sweep it (re-running a mock
  reaches nobody).
  - **Latent bug found and fixed in the same file:** contacts were read with
    `doc.data()`, but the client never writes an `id` *field* — the id is the
    document id. So `contact.id` was `undefined`, the Admin SDK rejects an
    undefined field value, and the `notificationLog` write threw and took the
    whole handler down. **The crash-notification function would have failed on
    its first real invocation.** Never hit because crash detection is off and
    the function has never been deployed.
- **81.3 — dead escalation stub removed.** `scheduleEscalation()` was called
  but its body was a `console.log` and a `// TODO`; the real sweep is the
  separate `onSchedule`. Deleted. The sweep's silent `.limit(10)` is now
  `ESCALATION_BATCH = 100`, ordered oldest-first, and logs a warning when it
  saturates instead of truncating an emergency path in silence.
- **81.4 — the alert addresses the rider by name.** It interpolated the raw
  Firebase uid ("your emergency contact 8f2c…e41 may have crashed"). Added
  `lookUpRiderName`, falling back to "a ThrottleIQ rider", never to the uid.

### EventDetector (81.5-81.8)

- **81.5 — the 2-second speed buffer is no longer crash state.**
  `_resetCrashState()` cleared `_recentSpeeds`, so an *unrelated* accel-spike
  window expiring threw away the speed history the speed-drop leg needs,
  blinding the detector for up to 2 s right after any >8 g blip. It now clears
  only the window; `reset()` still drops the buffer, since that's a new ride.
- **81.6 — a slide now counts as a speed drop.** The check required
  `newest.speedMs < 1.0` — a dead stop within the same 2 s window, measured by
  lagging GPS speed — so a highside that kept sliding produced no crash. A
  proportional collapse (≥50% of entry speed) now also qualifies. **Still
  uncalibrated**, and labelled as such alongside `impactThreshold`.
- **81.7 — overspeed is edge-triggered.** It was a bare `>` test firing on
  every fix above the limit; one interleaved hard brake re-armed the UI's
  dedupe and the cockpit strobed amber over the live map at speed. Now one
  alert per excursion, with a 1.5 m/s (~5.4 km/h) re-arm band.
- **81.8 — fatigue is a reminder, not a permanent state.** It re-fired on the
  10-second alert TTL forever once past 90 minutes, with no dismiss and no
  snooze. Now repeats on a 15-minute interval.
- New coverage: `test/calculators/event_detector_alerts_test.dart` (8 tests).

### Architecture (81.9-81.11)

- **81.9 — the app can follow the OS light/dark setting.** There was no
  `ThemeMode.system` anywhere. Added `AppBrightnessMode {light, dark, system}`;
  `system` resolves against the platform and keeps tracking it via
  `didChangePlatformBrightness`. Settings now shows three segments, matching
  the Language row. `brightnessMode` is optional at construction — an explicit
  `brightness` implies the matching mode, so no existing call site changed.
  - **NOT fixed:** the underlying `AppColors` static-facade problem (1,532
    static reads vs 10 `Theme.of`) and the full-app remount it forces. Still
    open in `issues_open.md` §83.9.
- **81.10 — `copyWith`'s error semantics are documented and safe.** `error`
  and `blockKind` were the only two of twenty-one fields that cleared by
  default, and the neighbouring comment asserted the opposite ("means 'keep',
  like every field here"). Added an explicit `keepError` flag, corrected the
  comment, and passed `keepError: true` from the 1-second elapsed timer, which
  would otherwise have wiped any error set mid-ride within a second.
  Covered by `test/features/ride/ride_recording_state_test.dart`.
- **81.11 — navigation is no longer a build side-effect.** `RecordScreen.build`
  scheduled `context.go()` in an `addPostFrameCallback`, re-queuing on every
  unrelated rebuild. Replaced with `ref.listen` on a `.select`ed status plus a
  one-shot mount check for the already-recording case.

### Data, privacy, backend (81.15-81.19)

- **81.15 — account deletion deletes.** Two halves:
  - *Cloudinary:* uploads now write a ledger row at
    `users/{uid}/cloudinaryAssets/{id}` (public_id + resource type), and the
    deletion trigger destroys each asset with a signed `destroy` call (Node's
    `crypto` + global `fetch`, no new dependency). **Gated on
    `CLOUDINARY_CLOUD_NAME`/`_API_KEY`/`_API_SECRET` in the environment** —
    with none configured it logs a warning naming the count that was *not*
    deleted and leaves the ledger intact so the sweep can run retroactively.
    Not silent success.
  - *Authored content:* forum posts/replies, ride comments, place reviews and
    contributed places are **anonymized, not deleted** (product decision,
    2026-09-20) — identity fields cleared, byline becomes "Deleted rider",
    body kept, so threads don't grow holes and POIs others depend on don't
    vanish. Chunked at 400 writes per batch.
- **81.17 — the privacy-zone jitter is actually secret.** The radius was
  `FNV-1a(uid) % 150`, and `userId` is plaintext on every shared ride in a
  source-available repo, so `radiusFor(seedForUid(ride.userId))` recovered it
  exactly — which makes triangulating a rider's home *easier* than a fixed
  radius. Replaced with `PrivacyZoneSalt`: a random value in an owner-only
  `users/{uid}/private/privacy` document, created on first share, cached per
  process, falling back to the base 200 m clip if Firestore is unreachable.
  `seedForUid` is now `@visibleForTesting` with a "do not use this" doc.
- **81.19 — crash notifications are idempotent.** The client used `.add()`
  (auto-id), so every retry created another document and another function
  invocation. Now keyed by `rideId`, with a rule requiring the document id to
  equal the `rideId` field. **This is idempotency, not an abuse bound** — a
  client can invent an id and match `rideId` to it; rules cannot limit request
  volume. App Check is the real control and is still not enabled (open).
  Requiring the ride to exist was considered and rejected: recording is
  offline-first, so a crash can fire before the ride ever reaches Firestore.

### Feed and UI (81.20-81.24)

- **81.20 — the feed paginates, and "Following" works.** It was three
  `limit: 20` queries merged client-side with no cursor anywhere: ~60 posts,
  ever. And `FeedSort.following` filtered *client-side* over that truncated
  public page, so a rider following 30 active people could see an **empty**
  Following feed. Now:
  - `getPublicRides`/`getSharedToMe`/`getMyRides` take a `before` cursor.
  - New `getRidesByAuthors` queries rides *by* the followed uids (chunked at
    `whereIn`'s 30-value cap) as its own feed source, with a new composite
    index `rides (userId, audience, createdAt)`.
  - `rideFeedProvider` (a `FutureProvider`) and the separate optimistic-state
    notifier are replaced by one paginating `RideFeedNotifier`/`FeedState`,
    with infinite scroll, a paging footer (spinner / retry / "You're all caught
    up"), and pull-to-refresh. A paging error no longer replaces the feed the
    rider is reading.
  - `_hydrate`'s N+1 is cut: the four overlapping sources now fetch with
    `hydrateVotes: false` and the merged, de-duplicated page is hydrated once.
    (One read per ride remains; going below that needs a `uid` field on vote
    docs plus a backfill — still open.)
  - Covered by `test/features/social/ride_feed_pagination_test.dart`.
- **81.21 — error states are human.** 15 screens rendered failures as a raw
  `Text('$e')` in red with no retry — including the offline-first app showing
  `[cloud_firestore/unavailable] …` as the whole Stats tab. All now use the
  **already-existing** `ErrorView` (friendly mapping + retry), which forums,
  chat and social had adopted and nobody else had. `group_ride_map_screen`'s
  `_ErrorState` now takes `mapFirestoreError(e)` instead of `'$e'`.
- **81.22 — partial.** Added `tooltip:` to 27 icon-only `IconButton`s (the
  screen-reader label for a bare icon), and an app-wide text-scale clamp of
  1.0–1.3× in `app.dart` so the OS text-size setting enlarges type without
  overflowing the fixed-height cockpit rows. **A clamp is a stopgap, not
  accessibility support** — the layouts still need to be made scale-tolerant.
  Still open.
- **81.23 — partial.** The four cockpit safety alerts ("Ease on the brakes",
  "Smooth on the throttle", "Watch your speed", "Time for a break") and the
  live-share sheet are now localized — an English-only *safety alert* in a
  Bangladesh-first app was the wrong thing to leave last. **The new Bangla
  strings need native-speaker review, like §78.28.** Onboarding and the rest
  of the cockpit are still English-only; still open.

### Tests and docs (81.29, 81.30)

- **81.29 — ticket references normalised.** 81 dead or ambiguous references
  removed from `app/lib` and `functions/src`, plus **28 more found in
  `firestore.rules`** (which the first sweep missed): 42 comments literally
  reading `"issues_open.md or issues_fixed.md §N"`, 30 pointing at
  `claude_sol` (deleted in `fc11e99`), the rest at `docs/Issues.md` (renamed
  2026-09-19). All now read `issues §N` or `grill §N`, defined once in a new
  **"Ticket references in source comments"** table in `DOCS/README.md`, which
  also says: do not write a file path into a new code comment.
- **81.30 — `features.md`'s nav order corrected** to match `app_shell.dart`.
- **Bonus (`new_gravity.md` §2): tests no longer hit OpenStreetMap.** A
  `flutter test` run emitted a wall of `ClientException … tile.openstreetmap.org`
  — the test branch used `NetworkTileProvider`, which really does fetch. Now a
  `_BlankTileProvider` serving a 1×1 transparent PNG with zero network calls
  (verified: 0 occurrences in a full run). It still carries the app's
  User-Agent so the tile-policy header test stays meaningful.

### 83 (rest). Open-list items closed 2026-10-22

Moved from `issues_open.md` §83 after a check against `main` (`3ebbd21d`).

- **83.16 (part) Cloudinary upload preset:** same finding as §33.5, tracked there.
- **83.19 (part) App Check enforcement:** client activation is done (above). Console
  registration and enforcement are owner items #17 and #32; `issues_open.md` §62.12
  tracks it with rate limiting.
- **83.23, three leftovers done:** logic-layer messages reach the UI as codes and are
  localized there (`74ea4d03`, see "83.23 (part)" below); dates read "8 Oct 2026" in
  Bangla too, English months with Western digits, by decision (`2f892e35`); the
  onboarding mockup chrome went with the mockups (83.26).
- **83.23 guidance, kept so nobody "fixes" it:** deliberately English are units (`km`,
  `km/h`, `mi`, `°C`, `g`), brand/model names and hint examples, forum topic/brand
  lookup lists, and every string that is data other people read (report reasons,
  `Unknown Bike`, audience values, the SafeQR payload, SQL). Foreground-service and
  notification text is a snapshot taken at ride start or send time
  (`resolveL10n`/`savedL10n`), not reactive to a mid-ride language change.
- **83.25 Information architecture:** decided 2026-09-20, leave the nav alone so beta
  testers don't relearn it. No work pending. (`2f892e35` later renamed the Profile tab
  to Garage.)
- **83.26 `onboarding_ui_mockups.dart`:** deleted in `a8983e7c`.
- **83.27 Analytics:** built (screen views and a fixed funnel, no ad SDK) and disclosed
  in `public/privacy.html` (:260, :367) and
  `DOCS/General/Files for Stores/store_listing/data_safety_and_permissions.md:95`. The
  owner kept the disclosed opt-out on 2026-10-22 (owner item #14). The Play Console
  form itself is part of owner item #4.
- **83.31 Triage:** superseded. `needs_attention.md` and the owner page rank open
  work, and the §32 safety finding it cited is closed (§32 (rest)).

## 74. Retro / Light: cards render near-black with unreadable text — FIXED (2026-09-21)

Surfaced 2026-09-19 in the UI screenshot set: "Your bikes" forum cards, Places
rows, My Places rows and the forum post card were solid near-black blocks on
Retro's cream page, their titles invisible.

**The 2026-09-21 diagnosis ("a palette token used as a card fill") was wrong.**
It was a paint-order bug in `AppCard`. Retro is the only palette with
`hasHardShadow`, and a blur-less `BoxShadow` paints a *solid offset copy of the
whole card*. `AppCard` supplied its fill from a `Material` **behind** the
`Container` that carried the shadow, so the shadow copy was painted over the
white fill and under the text — a block of the border colour (`#1A1A1A` on
Retro Light, cream on Retro Dark). Title text is `textPrimary`, also `#1A1A1A`,
hence invisible. No other mode sets a hard shadow, which is why no other mode
did it. `StatCard` already had the fill in the same decoration, so it was fine.

Fix: the fill now lives in the same `BoxDecoration` as the shadow (paint order
is shadow, fill, border), with a transparent `Material` on top so `InkWell`
still splashes. `test/shared/widgets/app_card_test.dart` pins it. No palette
token was changed.

## 83.9 (rest). Static token facades removed — the app no longer remounts on a theme change (2026-09-21, branch `appcolors`)

Fixes the half of §83.9 that was left open when `AppBrightnessMode.system`
landed. **Scope was three facades, not one** — `AppColors`, `AppDimensions`
(shape) and `AppTypography` (~1,940 call sites in 86 files); migrating only
colours would not have let the remount go.

- `AppColorPalette` and `AppShapeProfile` are now `ThemeExtension`s themselves
  (with `copyWith` and `lerp`) — no wrapper classes to keep in sync.
  `AppTheme.build(appearance)` resolves both and registers them on
  `ThemeData.extensions`.
- Read with `context.palette.x` / `context.shape.x`
  (`core/theme/app_theme_context.dart`). A tree with no extensions registered —
  a bare `MaterialApp` in a widget test — falls back to the default appearance
  rather than throwing.
- `AppColors` is **deleted**. `AppDimensions` keeps only the skin-independent
  spacing constants. `AppTypography` lost its static mode; `display()`,
  `cockpitLabel()` and `cockpitValue()` now take a `BuildContext`, and Retro's
  monospace face is a `monoDisplay` flag on the palette. The top-level
  `display(context, size)` helper follows.
- `AppearanceNotifier._applyTokens()` and every `apply()` are gone, and
  **`key: ValueKey(appearance)` is deleted from `app.dart`** — the acceptance
  test. `test/core/theme/app_theme_context_test.dart` asserts a live widget is
  re-themed with the **same `State` object and `initState` run once**, for a
  colour, a shape and a brightness change.
- Dialog / bottom-sheet / date-picker `builder:` closures (17 of them) now read
  their **own** builder context, not the caller's. A route outlives its caller,
  and looking a token up through a deactivated element asserts. The old
  statics never had this failure mode, so a blind search-and-replace would have
  introduced it.
- `MaterialApp.themeAnimationDuration` is `Duration.zero`. Tokens on the theme
  mean a 200 ms theme tween would rebuild every dependent widget on every frame
  of it, across the whole navigator stack. The palette `lerp` exists (it is
  part of the `ThemeExtension` contract and is tested) if that is ever wanted.
- Verification: `flutter analyze` zero, `flutter test` **1206** passing (was
  1195; +11 — the acceptance test, extension `copyWith`/`lerp`/registration
  tests, and the four `AppCard` tests from §74), rules 113 unchanged, `functions/` untouched.

**Not done here:** `const` is not re-enabled at the migrated sites (the reads
are `context` lookups, so they cannot be const anyway); goldens are now
*possible* but there are still 0.

## 32. UI/UX critique — the concrete defects (2026-09-21, branch `job3-ux`)

The founder scoped this to five concrete defects. **Four were already fixed by
earlier work**; the list (written 2026-08-17) was stale on them. Verified against
the code and against current-build screenshots, not assumed:

| Item | Status |
|---|---|
| Paused-ride scrim dims the stat card | Already fixed — §78.20 (dim sits directly above the map only) |
| Places FAB overlaps the last row | Already fixed — the list has `paddingXl + 56` (88 px) bottom padding vs the FAB's 56 + 16 px |
| Ride summary shows the score twice | Already fixed — the §77 restyle left a single `RidingScoreBadge` (checked in a tour screenshot) |
| Maintenance pill never escalates | Already fixed — "due soon" fires at 80% of the interval used (last 150 km for ≤1000 km intervals), so 13% remaining is amber. **Now pinned by `reminder_escalation_test.dart`**, which did not exist. |
| `★ —` on zero-review places | **Really broken — fixed.** Official points (police, cameras) show no rating row; unrated places say "No ratings yet". |

Also localized the two literal pill labels found on the way (`'Overdue'`, `'OK'`).
The one item on the original list left open was Emergency Contacts being exposed
in Settings while inert; closed 2026-10-22, below.

### 32 (rest). Emergency Contacts in Settings — closed (2026-10-22, moved from `issues_open.md`)

Settings still lists Emergency Contacts, but no longer reads as protection: a
warning-coloured banner above the list says "ThrottleIQ does not yet alert these
contacts automatically." (`app/lib/features/profile/presentation/screens/settings_screen.dart:262-288`,
`cecdd049`, grill §3.6.3). The contacts are also used today: the first one goes on the
SafeQR sticker (`safe_qr_screen.dart:169-172`). Crash alerts stay off (§78.1).

The taste calls on the original list (slide-to-start friction, "In jam", chart axes,
theme-picker previews, a low-contrast pass) are deliberately not being done. Don't
re-raise them as bugs.

## 78.30 Crash badge in ride history (2026-09-21, branch `job3-ux`)

`AllRidesRow` now leads with a **"Suspected crash"** pill and a danger-coloured
border when `ride.status == RideStatus.crash` (the value the recorder writes and
the history queries already include). History is the only surface where crash data
is visible at all while `SensorConstants.impactDetectorLiveEnabled` is off.
`test/features/stats/all_rides_row_crash_badge_test.dart`. **Caveat:** the *live*
recorder writes `crash`, but the auto-tracking reconciler only `debugPrint`s
`crashSuspected` and saves the ride as `completed` — so an auto-detected ride with a
replayed crash signal is still *not* flagged in history. Not changed here (it would
mean deciding what a replayed, hours-old crash signal should do to a ride record).

## 83.23 (rest). Localization — done on branch `i18n` (2026-09-21)

Was: 21 of 260 files localized. Now: **88 of 265** use `AppLocalizations` (the rest
are data/domain/plumbing), **1,229 ARB keys** (was 165), EN + BN.

How it was done (so the next agent can extend it): a string extractor that tokenizes
Dart (comments, `${}` interpolation, adjacent-literal concatenation, call/arg
context), per-batch decisions with the Bangla drafted alongside, and an applier that
edits the source, strips every enclosing `const`, adds the import, and validates that
each Bangla string carries the same placeholders. The tooling lived in the session
scratchpad and is not committed; the *result* is what matters.

- `context.l10n.key` (`core/i18n/l10n_context.dart`) for widgets; `resolveL10n()` /
  `savedL10n()` (`l10n_lookup.dart`) for code with no context (foreground-service
  notification, `NotificationService`).
- **Data is never localized.** Strings stored in Firestore or read by other people —
  report reasons, `Unknown Bike`, audience values, the SafeQR payload — stay stable
  English; only their *displayed* labels go through l10n.
- Domain enums keep their English `label`/`description` (persisted by name); the
  presentation layer localizes by stable id or kind: maintenance catalogue
  (`service_type_l10n.dart`), badges (`badge_l10n.dart`, 10 families / 37 rungs),
  place categories, ride sort chips, turn banners (`turn_instruction_l10n.dart`),
  greetings and taglines (`greetings_l10n.dart`, picked in `initState` and resolved
  in `build`, so a live language switch re-words without re-rolling).
- Error mappers (`mapFirestoreError` etc.) now take `AppLocalizations`.
- Plurals are proper ICU (`{count, plural, …}`), not `{s}` hacks.
- Bangla uses Western digits (a test enforces it; `numeric_locale.dart`).
- Onboarding manifest became `onboardingSlides(l10n)` + `kOnboardingSlideCount`
  (`initState` cannot read localizations).
- 12 widget-test files needed localization delegates on their `MaterialApp`.
- **1,064 Bangla keys await native review** — `app/lib/l10n/bn_pending_review.txt`.
- What is deliberately not translated, and the English-only logic-layer messages that
  remain, are listed in `issues_open.md` §83.23.

## 78.26 / 78.29 (parts). Hold-to-start same-frame release; immediate outbox attempt scoped to the rider (2026-09-21, branch `job3-ux`)

- **78.26:** `HoldToStartButton._release` only reversed the ring when `value > 0`, so a
  press and release in the *same frame* (value still 0, controller already running
  forward) let the hold complete and start a ride. Now unconditional, as
  `HoldToEndButton` already was. Regression test added and confirmed failing first.
- **78.29 (part):** `OutboxService._attemptOne` skipped the owner check `drain()` has
  (§69.O4): on a shared phone, account A's queued write could be attempted immediately
  under B's credentials. It now returns `deferred` and leaves the row queued. Tests
  added (failing first). The "Sync issues" screen half of 78.29 was localized in the
  i18n pass.

## 83.19 / 83.27. App Check and privacy-respecting analytics (2026-09-21, branch `job4-infra`)

**App Check (§83.19) — code done, enforcement is a console action.**
`firebase_app_check` is activated at startup (Play Integrity / App Attest with
DeviceCheck fallback; debug provider in debug), non-fatally. It is **inert until you
switch enforcement on in the Firebase console** — and that must wait until a release
containing this code is what riders run, or every older build is locked out (same rule
as §78.27). Debug builds print a debug token that has to be registered in the console.
iOS App Attest also needs its entitlement added to the Runner in Xcode (not done here;
without it iOS falls back to DeviceCheck). iOS-simulator and Android debug builds
verified; behaviour on a real device is unverified.

**Analytics (§83.27) — code and documents done, two founder actions remain.**
`core/analytics/analytics_service.dart`: screen views (route *patterns*, never ids) plus
a **closed list** of seven funnel events with at most one coarse parameter; off in debug;
rider opt-out in Settings → Privacy & Safety (persisted); ad ID, ad personalisation, ad
storage and ad user data disabled in the manifest/Info.plist and via consent calls.
No user id, name, email, location or ride figure can be sent — there is no code path
for it, and 8 tests pin that. Same commit updated `public/privacy.html` (the "no
behavioural analytics" bullet is gone; Firebase Analytics and App Check rows added;
effective date 21 Sep 2026) and `DOCS/General/Files for Stores/store_listing/data_safety_and_permissions.md`.
**Founder actions:** (1) update the Play Console Data Safety form ("App interactions:
collected, optional, not shared"); (2) **deploy hosting only with the release** that
ships this — the policy now describes analytics the currently-live app does not do.

## 78.24 SafeQR "Print sticker" (2026-09-21, branch `job4-infra`)

Settings → SafeQR now has **Print sticker** (next to Share image): it opens the system
print dialog with an A4 sheet of six stickers, each the QR at a fixed **50 mm** with an
"EMERGENCY MEDICAL INFO" heading and a scan hint, to cut out for a helmet or bike — a
sticker works with no phone and no unlock. `printing` (approved) plus a direct `pdf`
dependency; adding them bumped three transitive packages within their majors
(`image` 4.8→4.10, `xml` 6→7, `dbus` 0.7.14→0.7.15). Full suite, analyzer, and iOS +
Android debug builds re-run clean afterwards.
- **Bangla:** the PDF built-in faces have no Bengali glyphs (Helvetica warns and would
  print blanks), so the bundled Noto Sans Bengali is the base face for everything.
  `test/features/profile/safe_qr_sticker_test.dart` builds the real PDF in both languages.
- **Not verified:** that it *scans* off real paper, or how the dialog looks on a device.
  The QR content is unchanged (`safe_qr_payload.dart`); this only prints it.


---

## 78.21 Route navigation records the ride (2026-09-21, branch `job4-infra`)

The app's two core loops now compose. Following a saved route starts (or attaches to)
a real recording, so a rider can no longer spend two hours on a route and end up with
nothing in their history.

**What was wrong.** `RouteNavigationScreen` owned its *own*
`Geolocator.getPositionStream`, its own permission/services checks, its own wakelock
and its own progress maths — none of it known to `RideRecordingNotifier`, which owns
GPS, sensors, the foreground service, persistence, live-share and crash coordination.
Two GPS subscriptions, and no ride.

**The shape now** (the plan in `issues_open.md` §78.21, built as approved):

- `features/routes/domain/navigation_progress.dart` — the progress/off-route/ETA/
  turn-advance maths, extracted out of the screen and made pure. 15 tests
  (`test/features/routes/navigation_progress_test.dart`); it had none before.
- `features/routes/presentation/providers/navigation_session_provider.dart` —
  `NavigationSessionState` (route + manoeuvres + progress). It owns **no** GPS: it
  `ref.listen`s to `rideRecordingProvider`, selected down to
  `(currentPosition, currentSpeedMs, status)` so it recomputes at fix cadence rather
  than at accelerometer cadence. Dependency direction is one-way — routes knows about
  the recorder, the recorder knows nothing about routes, which keeps navigation out of
  the core loop. 10 tests.
- `RideRecordingNotifier.startRide(routeId:, routeName:)`, plus `route_id`/`route_name`
  on `RideEntity` and **schema v17**. The name is denormalized beside the id because a
  discovered route lives under another rider's uid, a route can be renamed or deleted
  afterwards, and history reads this in list views. 5 migration/round-trip tests,
  plus 5 on the sync payload. 35 new tests in all; the suite goes 1242 → 1277.
- `NavigationBanner`, drawn over the cockpit: turn + distance-to-turn, remaining + ETA,
  the off-route warning, and a close button that drops guidance while the ride keeps
  recording. The three top banners (guidance, alert, "we kept your ride") became one
  column instead of three widgets all claiming `top + 72`.
- The followed route is drawn under the ride's own trail on the cockpit map, dimmer —
  the route is the plan, the trail is what happened, and when they diverge the rider
  needs to see which is which.
- `RouteNavigationScreen` is now a pre-flight: route, length, manoeuvre count, first
  instruction, and one button — "Start ride & guide me", or "Guide me on this ride"
  when a ride is already running.
- Ride history shows a **Followed &lt;route&gt;** pill.

**Two bugs found while extracting the maths**, both pre-existing:

1. **The turn pointer could jam.** Advancing required passing within 30 m of each
   turn's point, so a corner taken in the far lane — or a fix 40 m wide of a trail
   recorded by a phone in a pocket — meant the banner pointed at that turn for the rest
   of the ride. A manoeuvre whose point lies *behind* the rider along the line is now
   treated as done however widely it was passed.
2. **`'in 320 m'` was hardcoded English** in the old banner. Localized, with 13 new
   keys (Bangla machine-drafted, batch `route-navigation` in `bn_pending_review.txt`).

**Sync.** `route_id`/`route_name` are only sent to Firestore when a ride actually
followed a route, so an ordinary ride's document is byte-identical to before — the rule
`bikePayload` already applies to `archived`. `downloadRides` now filters cloud fields to
the columns the local schema actually has, which closes that hazard class rather than
the instance: every column added to `rides` since has needed its own bespoke guard.

**Not verified:** anything that needs a phone on a bike. The maths is unit-tested and
the cockpit builds, but nobody has ridden a route with this. The full suite, the
analyzer and an Android debug build are clean. What was left is below.

### 78.21 leftovers (moved from `issues_open.md` 2026-10-22)

- **Nobody has ridden it.** The GPX replay harness (part 2, below) covers the session.
  `Geolocator`, the permission prompts, the foreground service, the wakelock and
  persistence are built inline by `RideRecordingNotifier` and can't be substituted
  (§83.13), so a real ride is the only check on them and on battery and heat. That ride
  is in the device-check follow-up at the top of `issues_open.md` (owner item #5).
- **Known limits, deliberate:** a ride restored at launch keeps its `route_id` but not
  its guidance, because the navigation session is in memory; the rider re-opens the
  route to get the banner back (the alternative is fetching a route during launch
  recovery). Navigating without recording is no longer possible; a rider who only
  wants the line on screen gets a ride to discard. Watch beta feedback for both.
- **Pre-v17 installs, accepted:** a ride that followed a route won't download onto a
  build from before 2026-09-21 (schema v17). Those builds predate the forced-update gate
  (`aaf4ef3a`, 2026-10-14), so nothing can push them; it fades as testers update.
- **`timesRidden`** counts since 2026-09-21 (§85).

---

## 79 / 80. QA-seed engagement cleared from production (2026-09-21)

`scripts/oneoff/cleanup_qa_engagement.js` was **applied to `throttleiqfb`** — the step §79 had
been waiting on since 2026-09-20, when the agent session that wrote the script was
blocked by its environment from running the live write.

    FIREBASE_PROJECT_ID=throttleiqfb node oneoff/cleanup_qa_engagement.js \
        --yes-i-really-mean-it --non-interactive

`--non-interactive` is what the earlier session was missing: the typed-confirmation
prompt has no TTY to read from in an agent shell, so the run died at the gate rather
than at the write.

| | before | after |
|---|---|---|
| shared rides scanned | 98 | 98 |
| QA-seed comments | 3 (all on the real ride `5a905c0a-…`) | 0 |
| QA-seed likes | 0 | 0 |
| `qashare_*` rides carrying the dead `likes` field | 47 | 0 |

The comments tally on `5a905c0a-…` went 3 → 0. A second dry run reports nothing left to
do, which is the documented verification. No fabricated engagement remains on a real
rider's post.

### The original §79 finding (moved from `issues_open.md` 2026-10-22)

On 2026-09-20, on request, 14 likes and 3 comments were written by hand onto the
founder's public shared ride `5a905c0a-a468-46a0-823c-b43ae3573c82` ("Saturday state of
mind") from 14 of the 30 `qaSeed` rider accounts, with the post's tallies set to match.
Every document carried `qaSeed: true`. The gap: `cleanup_qa_test_riders.js` deletes
seeded users, usernames, shared rides and forum posts, but not likes or comments a
seeded account left on someone else's post. `scripts/oneoff/cleanup_qa_engagement.js`
closed it (above). Fabricated engagement on a founder post must never be used as
traction evidence in the pitch or the store listing (§72).

---

## 78.21 (part 2). GPX replay harness — riding a route without a bike (2026-09-21)

`issues_open.md` §78.21 named "a phone on a bike, **or** a GPX-replaying
simulator" as the two ways to check route guidance. The second one now exists.

- `test/features/routes/gpx_replay.dart` reads `<trkpt>` out of any GPX and
  replays it through `NavigationSessionNotifier` — the same code the cockpit
  drives. Helpers for a detour, for decimated fixes, and for riding a constant
  offset off the line. Regex rather than an XML library on purpose: `xml` is
  only a transitive dependency here.
- `navigation_replay_test.dart` (15 tests) covers a full ride: turns fire in
  order and never step back, every manoeuvre gets displayed, remaining
  distance falls monotonically, the ETA is withdrawn on arrival, no off-route
  warning from jitter alone, a detour raises and clears it, corners taken 45 m
  wide still advance, one fix in twenty still catches up, pausing freezes
  guidance, and ending mid-route can't be revived by a late fix.
- The fixture (`fixtures/dhaka_zigzag.gpx`, 208 points) is **synthetic and
  says so in its own metadata** — deterministic, four legs at ~30 km/h with
  3 m of jitter. A real exported ride dropped in beside it reads the same way.

**What replay still cannot reach:** `Geolocator`, permissions, the foreground
service, the wakelock and persistence are constructed inline by
`RideRecordingNotifier` and can't be substituted (§83.13). A real ride remains
the only check on those, and on battery and thermal behaviour.

Two assertions written for this failed honestly and were worth the trip: the
`start` instruction is consumed by the very first fix (it belongs to the
pre-flight screen, which is where it is shown), and a detour pushed off the
*second* leg silently re-crossed the *first* — off-route is a distance to the
whole line, not to one segment.

---

## 83.23 (part). The localization leftovers that needed no reviewer (2026-09-21)

Four of the five §83.23 remainders. The fifth — English month names in dates —
still needs a founder decision and is untouched.

- **Onboarding mockup chrome.** The mock map's chips were `'All'`,
  `'⛽ Fuel'`, `'🔧 Workshops'`, `'☕ Cafes'` — English in every language, and
  naming two categories the app doesn't have. Now the real, already-localized
  `PlaceCategory` labels with that enum's own emoji, so the illustration drifts
  less from the screen it illustrates (§83.26). `'RIDES'` in the stat row was
  the last literal in the file; it now matches its `KM RIDDEN` / `SAFETY SCORE`
  neighbours.
- **Group-ride join failures.** `GroupRideJoinException` carries a
  `GroupRideJoinFailure` kind; the join sheet switches on it. The English text
  stays as a diagnostic on the exception, exactly like `recordingErrorText`.
- **Friend-picker bounds.** `validateGroupSelection` returned an English
  sentence for the UI to show verbatim; it now returns
  `({GroupSelectionProblem problem, int shortBy})` and the picker does the
  wording. Two "too few" strings rather than one pluralized placeholder — the
  minimum is 1, and "Pick at least 1 riders" is what one string would produce.
  Its unit tests asserted on that English wording, which is precisely why it
  could never be translated; they now assert on the problem and the shortfall.
- **Username errors.** `edit_profile_screen` and `onboarding_screen` showed
  `UsernameTakenException.toString()` / `InvalidUsernameException.toString()`.
  Both now localize; `thatUsernameTakenTry` already existed, `usernameRuleError`
  is new.
- **`PlaceEntity.reviewsSummarySubtitle`.** Its counts branch is two numbers
  and two brand names and needs no translation; only the "No reviews yet"
  branch did. New `hasAnyReviews` getter, and both screens fall back to the
  existing `noReviewsYet` key.

8 new keys, Bangla machine-drafted, batch `logic-layer messages` in
`bn_pending_review.txt`.

---

## 85. `timesRidden` now counts (2026-09-21)

`RouteRepository.incrementTimesRidden` existed from the start and was never
called from anywhere, so every route read "ridden 1×" forever — the 1 that
`saveRoute` writes. `ActiveRideScreen._stopRide` now calls it, and
`_cancelRide` deliberately does not: a discarded ride is one that did not
happen, and counting abandoned attempts would be the same dead number in a new
disguise. On completion rather than on start, for the same reason.

No rules change needed — `users/{uid}/routes/{id}` is already owner-only write,
so following a *discovered* route fails and is swallowed. The data model is the
ownership check; there is no branch for it in the code.

Best-effort and not outboxed, which is a deliberate trade recorded in the
method's doc comment.

---

## 80 (rest). The dead `likes` clauses are out of `firestore.rules` (2026-09-21)

Written and tested, and **DEPLOYED to `throttleiqfb` on 2026-09-21 (evening)** with
`firebase deploy --only firestore:rules` after the four gates were re-run (114 rules tests).
The only rules diff since the previous deploy was this change. The compiler's `[W] 306:46`
null-type warning that printed is the benign one from §62 (see HANDOFF), not new.

Removed: the `likes` tally guards on shared-ride create and owner-update, the
±1 bump branch, and the now-unused `likeBumpValid` helper. Three tests replace
the two that asserted a like bump *succeeds* — the tally can no longer move by
any path.

**`match /likes/{userId}` stays**, with the reason written into the rules file:
`RideShareRepository.deleteSharedRide` still *lists* that subcollection to
sweep up legacy documents, and a list against a path with no matching rule is
denied even when it would return nothing. Removing it would turn every
share-delete into permission-denied. It can go one release after the app stops
sweeping, in that order — §78.27's lesson.

**Consequence, now live:** a build that can still *like* a ride fails at that write.
`beta-v3.0.2` was released after the like button was retired (d7a915b), so this is
installs older than that only.

114 rules tests passing, was 113.

---

## 83.12 (part). The cockpit stopped rebuilding in full (2026-09-21)

`ActiveRideScreen.build` watched the whole 21-field `RideRecordingState`, so
all ~880 lines of it rebuilt on every accelerometer sample, every GPS fix and
every clock tick — with the map, the foreground service and a 20-50 Hz IMU
already running. Battery and thermal cost in exactly the state where battery
matters most.

The outer build now selects three fields — `status`, `activeAlert`,
`restoredFromPreviousSession` — which are the only ones that change the screen's
*shape*, plus a one-line watch on whether live sharing is on (it flips at most
twice a ride). Everything that genuinely moves fast was pulled into its own
widget selecting only its own fields:

- `_SpeedPanel` — speed, distance, moving time, elapsed, confidence and the
  G-force bar. An accelerometer sample now repaints a panel, not a cockpit.
- `_RideClock` — one field, one `Text`, once a second.
- `_CrashOverlayGate` — the countdown ticks once a second while it's up, and
  nothing else should repaint for that.

`.select(` app-wide goes from 3 to 11. Behaviour is unchanged — the alert
flash, the idle redirect and the end/discard flows all still route through the
same code. **Not measured on a device**; the argument here is structural, and
the profiling that would prove it needs the hardware.

---

## 83.28 (part). The navigation banner has widget tests (2026-09-21)

6 `testWidgets` on `NavigationBanner` — the new surface, so it starts with
coverage rather than joining the 43-screens-1-test pile. It renders to exactly
`Size.zero` when nothing is being followed (the cockpit hosts it
unconditionally), shows the manoeuvre and remaining/ETA, raises and drops the
off-route warning, says the ride is *still recording* on arrival, and closes
guidance without ending the ride.


---

## 86. Social redesign left half-wired with fake data — FIXED (2026-09-27); deploy and iOS run closed (moved from `issues_open.md` 2026-10-22)

An uncommitted first pass at the Rides/People/Forums mock (`ANTIGRAVITY_GRILL/new_task`,
deleted, §91.6) had disconnected the AppBar search, left the People tab a bare
`Center(child: Text('People'))`, and hardcoded the mock's sample text ("Rafi's Squad",
"Nadia Rahman", "Chittagong Hill Tracts") into the "Riding Now" strip and every feed
card's location pill. Scratch `clean_up*.py`/`fix_social.py`/`rewrite_social_screen.py`
scripts and `tmp_*`/`.bak` files sat in the repo root.

**Fixed:** search is a `SearchDelegate` off the AppBar icon; People has real rider
search and a real Following list; "Riding Now" reads
`GroupRideRepository.watchActiveGroupRidesForUser()` and hides itself when the rider has
no active group ride; the location pill was removed rather than faked. The
`groupRides` `list` rule was extended for that query (119/119 emulator tests) and went
live with the 2026-10-06 rules deploy (§93.6). Scratch files deleted. Detail in
features.md §7.

**iOS release run on the founder's iPhone (2026-09-28 to 2026-10-05).** Three blockers,
cleared in order:
- "no XCFramework found" pointing at the repo's pre-move path: 10 stale
  `~/Library/Developer/Xcode/DerivedData/Runner-*` caches carried the old absolute
  path. Fixed by deleting them and `app/build/ios/SourcePackages` and letting Xcode
  re-resolve. A machine cache issue, no source change.
- No Apple ID in Xcode, so codesigning failed. Signed in 2026-09-28.
- First launch refused ("invalid code signature … not explicitly trusted by the user").
  Fixed on the phone: Settings → General → VPN & Device Management → Trust. The app
  launched in release mode on 2026-10-05.

Carry forward: `flutter run --release` still fails at its own install step even though
the Xcode build succeeds. Let the build finish, then
`xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app` and
`xcrun devicectl device process launch --device <udid> com.bft.throttleiq`. The profile
is a free personal team (`Apple Development: abraar.rar@icloud.com`, team
`NJ4675FFUX`); free profiles expire after 7 days (this one on 2026-10-12) and need a
re-sign. The paid Apple Developer Program is owner item #21.

Two follow-ups (solo "riding now" cards, a per-card location label) stay open in
`issues_open.md` §86.

---

## 87. Founder-reported social bugs — FIXED in code (2026-10-01), not yet verified on a device

The fixes are uncommitted in the open55 pass. `flutter analyze` is clean and all 1347 tests pass.

- **87.1: "Riding Now" showed finished group rides.**
  - **Cause:** ending a ride from the ride screen never ended the group ride. `endGroupRide` had no callers, and the Riding Now query filtered only on `status == 'active'`, with no time limit.
  - **Fix:** a new `groupRideLifecycleProvider`, watched in `app.dart`, ends or leaves your group rides when your recording stops. Rides you created also get a `lastActiveAt` heartbeat every 5 minutes, and `endedAt` is written when a ride ends.
  - **Fallback:** a new `group_ride_liveness.dart` treats a ride as live only if its status is active and it has had activity in the last 4 hours (`kGroupRideInactiveCutoff`). Stale rides are hidden, and a stale ride you created is closed out when you see it.
  - **Side fix:** `GroupRideEntity.copyWith` was silently dropping `joinCode`.
- **87.2: followed riders' posts were missing.** There were three causes:
  - The first page read the follow list with `.valueOrNull` before it had loaded, so it fetched no followed authors.
  - `followingUidsProvider` was a one-shot future that never refreshed on follow/unfollow. It's now a live stream (`FollowRepository.watchFollowing`), and the feed reloads when the followed set changes.
  - The next page started from the oldest ride across all sources, which skipped posts from the other sources. A new pure function (`domain/feed_page_merge.dart`) fixes the page boundary.
  - **Still open, by design:** a post shared to `followers` or `mutual` stores its allowed viewers when it's shared, so someone who follows the author later never sees it. Fixing that needs a rules/data-model redesign.
- **87.3: push-to-talk wasn't reachable from ride start.** The ride screen had no link to the group ride, and the creator's start flow used `go`, so there was no back stack.
  - **Ride screen:** new "Group talk" button (`_GroupRideTalkPill`).
  - **Group map:** new "Ride stats" button back to the ride screen, and auto-start now shows the location disclosure first.
  - **Record screen:** new "Open push-to-talk" banner.
- **Rules/indexes:** unchanged. Nothing to deploy.
- **To check on a device:** ending a ride clears the card for all members; the existing zombie cards disappear; the talk ⇄ stats buttons work in both directions; a newly followed rider's posts appear without a restart.

## 88. Follow-ups left by the open55 pass — FIXED in code (2026-10-01)

- **88.1: "Followers/mutual rides hidden from new followers."**
  - **Cause:** The query for followed authors' rides relied on `allowedUserIds array-contains me`, which was only populated when the ride was shared. New followers were excluded.
  - **Fix:** Switched `RideShareRepository.getRidesByAuthors` to issue one query per author. Because the query pins `userId == author`, `firestore.rules` can statically prove the `exists()` checks against the live `follows` graph during validation. `RideFeedNotifier` now queries `getFollowersAmong` to know which authors follow the rider back, enabling it to safely query for `mutual` posts without hitting permission denials.
  - **Rules:** `rideVisibleTo` updated to check the live `follows` graph (via `exists()`), while retaining the `allowedUserIds` fallback for old clients.

### 88.2–88.4 (moved from `issues_open.md` 2026-10-22)

- **88.2** Fixed in code, not device-checked: each bike's maintenance settings (tracked checks with typical cost, fuel price, mileage) back up via the outbox to the owner-only `users/{uid}/private/maintenanceSettings_{bikeId}` and restore on a reinstall or a new device, filling empty tables only. See `app/lib/core/cloud/maintenance_settings_sync.dart`.
- **88.3** The device check of the open55 changes (the §87 checklist, the maintenance layout and ride-cost card, the collage visuals, the SQLite v17→18 upgrade on a real install) moved to the device-check follow-up at the top of `issues_open.md` (owner item #5).
- **88.4** The open55 Bangla strings wait with the rest of the Bangla review in `issues_open.md` §83.23 (owner item #12).

---

## 89. No JDK on the machine — Android release builds (APK/AAB) could not run — FIXED (2026-10-05)

_Moved from `issues_open.md` on 2026-10-22. The Gradle 8.14 warning below is still open there, under "Follow-ups on fixed issues"._

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

## 90. Full-codebase audit fixes — FIXED in code (2026-10-06, commit `6264d72`), not verified on a device

The findings as logged are at the end of this section (moved from `issues_open.md`
on 2026-10-22); the still-open items are in `issues_open.md` §90. Checks at the end of the pass: `flutter analyze`
0 issues, `flutter test` 1450/1450, rules emulator 177/177, `functions`
`npm test` 5/5.

**90.A social data layer**
- **A1:** feed queries are now public `whereIn` chunks (≤30 authors) plus
  per-author followers/mutual queries (limit 5), merged per source. A source that
  is exhausted is skipped on `loadMore`. New `domain/feed_source_plan.dart`.
- **A2:** `domain/utilities/group_ride_broadcast_gate.dart` sends every 20 s, or
  when moved ≥ 25 m, with a 2 min heartbeat. `kGroupRideStaleAfter` is 30 s → 160 s.
- **A3, A6, A10:**
  - The live `followingUidsProvider` drives Following, mutual ids and `isFollowingProvider`.
  - The one-shot `followingIdsProvider` is deleted.
  - Count providers are autoDispose and invalidated after follow/unfollow.
- **A5:** suggestions are bounded: 30 edges, 10 profiles, 20 recent users, cap 10.
  They are kept alive for 10 min, filter out blocked riders, and use
  `profileRepositoryProvider`.
- **A7:** search waits 400 ms after the last keystroke, and the forum list is cached
  for 10 min (`filterForumsByName`).
- **A8:**
  - Chat shows the newest 50 messages, with "Load older messages".
  - Forum posts are paged 25 per forum with a cursor and "Load more".
  - Comments are limited to 30, with a cursor.
  - Voice notes show the newest 20.
- **A9:** shared `widgets/follow_button.dart` plus `FollowController`:
  - the follow is awaited before the notification is sent;
  - the notification id is `follow_{fromUid}`;
  - the button is disabled while the follow is in flight, and errors show.
- **A12:**
  - The feed notifier watches the uid.
  - The chat list shows a "Rider" placeholder when a profile can't be read.
  - `markMessagesAsRead` is removed (its rule is removed too).
- **A-LOW:**
  - Place and review providers are autoDispose.
  - Comments use the profile `bestName`.
  - All People has its own empty-state string, pages with a `createdBefore` cursor,
    filters out blocked riders and marks riders you already follow.
- **B7 (part):** `social_screen.dart` is split into `part` files `social_search`,
  `social_feed_tab` and `social_people_tab`.

**90.B architecture / CI / platform**
- **B1:** the 3 lints in `social_screen.dart` are fixed. In CI, `flutter test` now
  runs even if analyze fails.
- **B2:** the Podfile appends `PERMISSION_MICROPHONE=1` (it no longer uses `||=`).
- **B3:** `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are in
  Info.plist.
- **B6 (start):** new `core/utils/error_reporter.dart` `reportNonFatal` reports
  Crashlytics non-fatals. The CI ratchet allows at most 71 bare `catch (_)`.
- **B8 (part):** dead `exportToJSON`/`exportToGPX`/`_generateGPX` are removed from
  `cloud_repository.dart`.
- **B9 (part):**
  - `functions/` has tests (`functions/test/pure.test.js`, Node test runner), run in CI.
  - The ride-recording decision logic is pulled into tested units
    (`ride_lifecycle.dart`, `fix_kinematics.dart`, `auto_detection_policy.dart`).
- **B11:** actions moved to v5, and the runner is pinned to `ubuntu-24.04`.

**90.C ride pipeline / sync**
- **C1:** pause cancels the GPS/IMU subscriptions, and resume recreates them
  (`RecordingSubscriptions`).
- **C2:** the foreground reconcile closes a `recording` detection only if the
  service is down or its last fix is more than 10 min old.
- **C3:**
  - Detections are trimmed to the longest stretch that doesn't overlap an existing
    ride, or discarded with `overlaps_ride`.
  - `beginDetection` is skipped while the manual-ride marker is set
    (`RidePrefsKeys`).
- **C4:** the teardown outbox id is now `live-teardown:$uid:$token`, and the
  pointer is cleared in a transaction only if the token matches.
- **C5:** a `TransitionLatch` refuses a second start/pause/resume tap.
  `transitionPending` disables the button while one is running.
- **C6:** **schema v19** adds `ride_points.segment_start`; the resume rebuild skips
  pause gaps and idle jitter.
- **C7:** sync is incremental.
  - Per-rider `syncedAt` watermarks (`pull_watermark.dart`), with a full pull on
    first sign-in or an empty local DB.
  - 30 s connectivity debounce.
  - No downloads while recording.
  - The maintenance-log upload now sets `syncedAt`.
- **C8:** stop finalizes first and clears the marker in `finally`.
- **C9:** a start failure rolls back and shows `recordingStartFailed`.
- **C10:** `deleted_rides` tombstones stop a discarded ride coming back from the cloud.
- **C11:** the battery-optimization prompt is shown once (`battery_optimization_prompted`).
- **C12:** shared `evaluateFix` caps Doppler distance at
  `max(raw, prev) * dt * 1.5 + accuracy`.

**90.D security / backend**
- **D1:**
  - Comments can be deleted by their author or the ride owner.
  - Creating a comment requires `rideVisibleTo`, a key allow-list, text of 1–2000
    characters and `createdAt == request.time`.
- **D2:** the ledger `publicId` must match `^[A-Za-z_]+/<uid>/`. The sweep checks
  `isOwnedPublicId` (`functions/src/cloudinary-ownership.ts`) before destroying.
  Voice notes now upload to `voiceNotes/<uid>/<rideId>`.
- **D3, D4:**
  - The creator can only shrink `memberIds`.
  - A kick adds the rider to `bannedIds`, and the join clause checks it.
  - New `GroupRideJoinFailure.removed` and `joinRideRemoved` string.
- **D5, D11:**
  - `postCount` changes are bound to the post being created or deleted in the
    same commit, via `lastPostId`.
  - `followerCount` changes are bound to the caller's own `forum_follows` doc.
  - `createPost` is a single batch.
- **D6:** `email`/`emailLower` must equal the auth token's email when changed.
- **D7:** decision: `livePointers/{uid}` is written only when the new
  "Public link (/r/@handle)" setting is on (off by default,
  `public_live_link_setting.dart`).
- **D8:**
  - Decision: added a block check to `rideVisibleTo`, on the followers/mutual
    branches only.
  - The followee can delete follow edges that point at them.
    `ProfileRepository.blockUser` is transactional and removes both edges.
  - The audience label now reads "Anyone who follows you".
  - Follow requests were not built.
- **A4/D9:**
  - The emulator confirmed that unfiltered `users` list queries returned private
    profiles with their emails. `list` now requires `visibility == 'public'`.
  - The client queries filter on it.
  - `ensureProfile` backfills the field on sign-in.
  - 3 indexes added.
- **D10:** `photoUrlAllowed` / `nameValid` are applied to comments, posts, replies,
  voice notes and `users`. Voice-note audio must be on our Cloudinary cloud.
- **D12:**
  - `ride-identity` uses `bestName` and skips reconciling when no identity field
    changed.
  - `crash-notifications` marks alerts with no contacts as `no_contacts`; its index
    is fixed.
  - `chat-moderation` reports keep the original text and use a fixed id.

**90.E docs:** `features.md` PhotoCollage → `RideMediaCollage`. About 114
`file:///…/dev/ThrottleIQ/` links in `issues_solved.md` and `ANTIGRAVRITY_GRILL/`
now use relative paths. The README sensor/token/badge claims are corrected, and
the rules count is now measured at 177.

### 90 (record). Accepted decisions and the findings as logged — moved from `issues_open.md` (2026-10-22)

The open remainder, re-checked on 2026-10-22, is in `issues_open.md` §90.

- **Accepted / partial:**
  - D9: the `follows` list stays unconstrained. Every client query filters on
    one side, and the list exposes uids only, not emails.
  - D6: profile emails spoofed before this fix aren't cleaned up.
  - D8: no follow requests. The "Followers" label is kept in the edit-profile
    garage control because the longer text doesn't fit there.
  - A8: one vote read per visible forum post remains.
- Paused rides block auto-detection until the rider resumes or ends them. This
  is deliberate.

**Findings as logged on 2026-10-06.** Line numbers and counts are from that day; the fixes are
listed above.

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

#### 90.A Social / chat / forums / POI data layer (incl. commit a51b3f8 "Suggested for you")

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

#### 90.B Architecture, code quality, tests, build/CI, platform config

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

#### 90.C Ride pipeline, offline sync, persistence

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

#### 90.D Security & backend (rules, functions, client ↔ rules)

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

#### 90.E Docs sweep (2026-10-06) — done in this pass, leftovers

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

## 92. Carried-over summary items: go-to-market, monetisation, launch copy — moved out (2026-10-22)

Moved from `issues_open.md` §92 (old 92.B–92.D). These are not code issues. The plans and the
copy live in `DOCS/Handoffs for Non Coding Agents/marketing/` (`marketing.md` Phases 0–2,
`pitch_and_marketing_materials.md`, `iDEA_PITCH_SUBMISSION.md`). Status on 2026-10-22: 92.B5 is
obsolete (the app has had two themes since `24024501`); 92.B6 (Play testers) is part of the Play
item in `needs_attention.md`; the crash-alert guardrail in 92.B7 still holds (crash detection runs
in shadow mode and sends no alert); for 92.B8, a daily 9pm ride summary exists (§93), a weekly
digest does not. The engineering ideas (92.A) stay in `issues_open.md` §92.

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

## 93. Auto-tracking daily summary + beta jam labels — follow-ups FIXED (2026-10-07), moved 2026-10-22

Verified 2026-10-22. The device checks (93.3) stay in `issues_open.md` §93; the Bangla review
(93.7) is part of the Bangla review in `needs_attention.md`.

- **[needs-you] 93.1 DECIDED 2026-10-07 (yes) and implemented — see §95.9 / `features.md` §5.** Was: *Decision needed: forgotten rides and the bike odometer.* Detected trips no longer become
  ride rows, so they no longer add to a bike's distance or service-interval km. The "which bike?"
  confirmation also no longer fires for new detections. Should forgotten rides still count toward
  maintenance reminders?
  - Built in `detected_odometer_credit.dart` (§95.9 covers which bike gets the km).
- **[doable-now] 93.2 Fix storage grows without limit.** Fixes for `summarized` detections are kept forever
  (about 150 KB per heavy riding day). Add a retention policy at some point.
  - **FIXED** in `85146dba` (2026-10-07): `AutoDetectionDao.purgeOldSummarizedFixes` drops the
    fixes of summarized detections after 14 days, once a day (`auto_tracking_service.dart:366`).
- **[doable-now] 93.4 Missing tests.** `DailyRideSummaryRepository.summaryFor` (the SQLite path) has no tests;
  only the pure calculators are covered.
  - **FIXED** in `85146dba`: `app/test/database/daily_ride_summary_repository_test.dart`.
- **[doable-now] 93.5 Old docs.** `auto_tracking_plan.md` and `HANDOFF_Document.md` still describe the old
  "promote each detection to a ride" flow.
  - **FIXED:** `DOCS/For Devs and Contributors/architecture/auto_tracking_plan.md` describes
    summarizing instead of promoting, and the 14-day purge.
- **[doable-now] 93.6 ✅ Firestore rules deployed (2026-10-06)**, including the `jamLabels` rule. The compiler printed a
  warning at `398:46` (`publicStatsValid(resource == null ? null : ...)`), which comes from older
  code, not this change.
- **[needs-you] 93.8 Old auto rides.** Auto rides saved before this change stay in history and are counted as
  recorded rides.
  - Accepted: no migration planned.

## 94. Maintenance audit findings — FIXED in code (2026-10-07), not verified on a device

Logged 2026-10-06 while drafting the maintenance redesign proposal. All five
were fixed by that redesign (`issues_open.md` §95, `features.md` §5).

- **94.1 Home widget ignored the rider's settings.** It now headlines
  `nextServiceDue(forecast)`, built from the same `forecastChecks` as the page
  (the rider's intervals, enabled checks, km-or-time).
  - The `SensorConstants` maintenance table, `computeNextService` and
    `kWidgetReminderTypes` are deleted.
  - Time-driven items are worded in days.
- **94.2 Deleted logs came back.** Deletes now go through
  `MaintenanceDao.deleteWithTombstone`, which:
  - writes a row to `deleted_maintenance_logs` and drops any queued outbox
    upload, in one transaction;
  - lets `SyncManager` delete the Firestore doc;
  - makes `downloadMaintenance` skip tombstoned ids;
  - makes the outbox discard a delivery for a log deleted before it ran.
- **94.3 Never-logged checks counted from 0 km.** They now count from:
  1. the last log;
  2. else the rider's "last done" baseline;
  3. else the day the bike was added, only if it had ≤ 500 km then.

  Otherwise they are "unknown" with a Set-last-done action, never overdue.
- **94.4 Fake odometer scan.** Removed. The photo is kept as a reference and
  the rider types the reading.
- **94.5 Stale docs.** These now describe the current code:
  - `features.md` §5 (rewritten);
  - the `sensor_constants.dart` comment;
  - the `HANDOFF_Document.md` "local only" note.

---

## 95. Maintenance redesign — closed parts (moved from `issues_open.md` 2026-10-22)

The open parts stay in `issues_open.md` §95. Of the review's "still open" list, "alerts ignore the
miles setting" was fixed by §101.R10 (`maintenance_alerts.dart:100`).

- **[needs-you] 95.6 Quick-check issues are local only** (`precheck_issues`). Deliberate,
  since they're short-lived.
  - Accepted: deliberate.
- **[needs-you] 95.8 Older app versions.**
  - A log written with visit columns can't be inserted by a pre-v20 build; its
    download skips that row (per-row try/catch), so the log is missing on an
    un-updated second device.
  - A custom tracked check (`service_type = custom:<id>`) shows as a plain
    "Custom" check in old builds.
  - **OBSOLETE** (2026-10-22): the forced-update gate (`app_update_gate.dart`, Firestore
    `config/app.minBuild = 29`) blocks every build older than 29; v20 visit logs arrived with
    build 22 (`238d12b`).
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

---

## 95.13 CI red: bare-`catch (_)` ratchet at 80 (max 71) — FIXED (2026-10-07)

The maintenance redesign (`238d12b`) added 9 bare `catch (_)`, so the `flutter`
job failed from that commit on (`beta-v4.1` included; the AAB was unaffected).
All 11 bare catches under `features/maintenance/` now call `reportNonFatal`
(first real callers of it), except `MaintenanceAlerts._inTests`, which catches
`UnsupportedError` (no `dart:io` Platform on web). Repo count 80 → 68; the CI
ratchet is lowered to 68. Analyze clean, 1547/1547 tests pass. Not run on a
device.

---

## 96. Places hub redesign — DONE in code (2026-10-07), not verified on a device

The Places tab was a vertical text list. It is now a map-first hub (features.md §6).

- **96.1 Search & filters.** Added `PlacesQuery` and `applyPlacesQuery` (`domain/places_query.dart`, pure)
  and `PlacesQueryNotifier` (debounced text; radius is persisted). Search is client-side over one
  radius fetch, so a chip or a keystroke costs no reads. The 7-chip `Wrap` is now a horizontal ribbon
  with counts.
- **96.2 Radius.** The hard-coded 25 km is now a choice of 5/15/25/50 km.
  `nearbyPlacesProvider` is a family keyed by radius (it used to be keyed by category) and fetches
  all categories at once.
- **96.3 Ratings.** The `dualRatingDisplay` "x + y" string is removed. Ratings now show as labelled
  badges, plus `isRiderApproved` (≥ 4.5 from ≥ 5 riders).
- **96.4 Map.** `PlacesMapView` has clustered category pins, a radius ring, locate-me and a synced
  carousel. Clustering is a grid in `domain/marker_clustering.dart`; no new dependency.
- **96.5 Tabs.** Places | Routes | Saved replace the "Browse routes" button. `RoutesBrowser` was
  extracted from `RoutesListScreen` so the Routes tab can embed it. Saved places use SQLite (schema
  **v21**, `saved_places`, `SavedPlaceDao`); `deleteUserData` wipes them for the deleted user.
- **96.6 Highway Radar.** Cameras and checkposts moved out of the chips into
  `computeHighwayRadar` and its banner.
- **96.7 OSM import.** Moved out of the AppBar into the empty state and the overflow menu, with an
  explanation.
- **96.8 Rider tags.** Added `PlaceTag` (place doc field `tags`) and tag chips in the add-place
  form. The `places` create rule allows at most 12 unique tags, tested in
  `scripts/test/rules/places_rules.test.js`.
- **96.9 GPS-off bug.** With GPS off, `currentPositionProvider` threw "Location is turned off".
  `isLocationServicesError` never matched that message, so the screen showed the generic error card
  and no "Turn on location" button. It now throws a typed `PlaceLocationException`, and each case
  gets its own fix button.
- **96.10 Shared launchers.** The Directions/Call launch code (and the record-this-ride sheet) moved
  from the detail screen to `widgets/place_launch_actions.dart`, so every card uses it. The bare
  `catch (_)` count is unchanged (68).

Tests: places query, radar, clustering, tags/badges, saved-places DB and migration, the notifier,
and widget tests of the hub (list, map, radar, search, save, empty/GPS/offline states, 360 dp in
en and bn). `flutter analyze` is clean; 1609/1609 tests pass; 183/183 rules tests pass.

## 97. Forums: no photos on posts; brand paddocks said "0 riders" — FIXED (2026-10-07)

Reported by the founder after the first iPhone run of the Pit Wall redesign.

- **97.1 No way to add a picture to a forum post.** The composer now takes up to 4 photos (camera or
  gallery). They upload to Cloudinary `forumPhotos/<uid>/` and are written as `imageUrls`. Thread,
  Pulse and detail views render them, with the full-screen gallery on tap. `firestore.rules`
  `forumImagesValid` caps the list at 4 and requires each URL to be in the author's own folder. The
  account-deletion sweep already covers `<kind>/<uid>/` folders. Tests: `forum_post_model_test.dart`
  (parse/cap/write) and 2 new rules tests in `forum_pitwall_rules.test.js`.
- **97.2 Brand paddocks showed "0 riders" on every brand.** The card read `followerCount` off the
  brand forum doc only. Riders follow and post in the **model** forums ("Yamaha MT-15"), which the
  brand thread merges in, so the brand doc stayed at 0 while the Yamaha thread was busy. Now
  `aggregateBrandPaddockStats` sums riders and posts over the brand doc plus every model forum with
  that brand (case-insensitive). The read is one capped `brand whereIn` query with lower/upper-case
  variants, kept 10 min. Tests: `brand_paddock_stats_test.dart` and the updated
  `forums_hubs_view_test.dart`. Known limit: a rider who follows two forums of one brand counts twice.


### 97 (Places/Forums iPhone run, 2026-10-07). Audit findings 97.1–97.8 — FIXED (2026-10-07, `b600f103`, `13face57`), moved 2026-10-22

The other §97 (`issues_open.md` had two). Verified in code on 2026-10-22: `auto_tracking_tile.dart`,
`route_detail_screen.dart` and `save_route_screen.dart` put a `Material` between the decoration and
the `SwitchListTile`; the `places_list_screen.dart` menu items use a `Row`;
`placesCarouselHeight = 208` and `placeActionButtonStyle` uses `shrinkWrap`; `UserAvatar` uses
`CachedNetworkImage` with an `errorWidget`, and the tile layer has an `errorImage`;
`PlaceDetailScreen` shows `place.photoUrls`; `SavedPlacesTab` is a `ListView.builder`;
`place_launch_actions.dart` uses `defaultTargetPlatform`; `forum_post_model.dart` uses relative
imports; forum photo uploads show their own error (`forumPhotoUploadFailed`). The App Check 403
stays tracked in `issues_open.md` §62.12 / §83.19.

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

## 98. UI screenshot tour on a physical iPhone — OBSOLETE (2026-10-15, `a758b57b`)

`a758b57b` deleted the 28-theme UI tour (`app/integration_test/ui_tour_test.dart`, `run_tour.sh`)
and its PDF generator, so the device mode below no longer exists. What is left of its screenshots
is in `DOCS/old/ui_stuff/`. Moved from `issues_open.md` on 2026-10-22.

`app/integration_test/ui_tour_test.dart` now has a device mode (`--dart-define=TOUR_DEVICE=true`) that
captures each shot in-app to `Documents/tour/shots/` instead of using host `simctl`. It has not worked
on the iPhone 15 yet, so the screenshots in `DOCS/old/ui_stuff/` were captured
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

## 99. Realtime Database movement channel — OBSOLETE (2026-10-14, `4cb96a8f`, `8872feff`)

The RTDB channel was retired. `8872feff` makes `database.rules.json` deny every read and write
and deletes `scripts/verify_realtime.js`; `4cb96a8f` removes the group-ride RTDB client (parked on
branch `park/rtdb-group-ride`). Live share and chat typing keep RTDB code paths that run only when
a build sets `RTDB_URL`, and release builds don't. The go-live checklist `websockets_todo.md` was
retired on 2026-10-22. Moved from `issues_open.md` on 2026-10-22.

Design: `DOCS/For Devs and Contributors/architecture/realtime-database.md`.

- **99.1 Not live: no RTDB instance, no `RTDB_URL` in builds — HIGH (blocks the feature).** Steps: (1) Firebase console → Realtime Database → create it in `asia-southeast1`, locked mode. (2) `firebase deploy --only database`. (3) Add `--dart-define=RTDB_URL=<instance URL>` to the release build scripts. (4) Deploy hosting, so the viewer picks up `databaseURL` from `/__/firebase/init.json`. (5) Run `node scripts/verify_realtime.js --url=<URL>` against production. Note that `firebase.json` now has a `database` target, so a bare `firebase deploy` fails until step 1 is done.
- **99.2 Group-ride positions readable by anyone holding the ride id — MEDIUM (accepted for now).** RTDB rules can't read Firestore `memberIds`, so `/group_rides/{id}/locations` is readable by any signed-in user who knows the id (from the join code), not only members. Kicked riders are blocked through `banned/`. Fix: a Cloud Function that mirrors `memberIds` into RTDB, once functions can deploy.
- **99.3 RTDB `meta` claim is first-writer-wins — LOW.** A member who knew the id before the creator's claim landed could claim `meta`. The claim goes out in the same step as ride creation, and the app ignores the channel when `meta.creatorId` doesn't match Firestore's creator, so the worst case is falling back to Firestore. Rides created by older builds have no `meta` and stay on Firestore.
- **99.4 Orphaned `/live_shares` node if the app is killed mid-share — LOW.** The Firestore teardown goes through the outbox, but the RTDB node doesn't. It stays readable until its `expiresAt` (at most 24 h), and the viewer won't show it because it gates on the Firestore session. A share longer than 24 h stops getting RTDB reads; the viewer falls back to Firestore.
- **99.5 Not checked on a device — MEDIUM.** Run `app/integration_test/realtime_emulator_test.dart` against the emulators (instructions are in its header). Then check on two phones: a live share open in a browser, a group ride, and a chat.
- **99.6 Bangla strings need native review — LOW.** `groupRideRealtimeLive`, `groupRideRealtimeDelayed` and `chatTyping` are in `bn_pending_review.txt`.

## 100. E2E integration test couldn't start: Firebase never initialized — FIXED (2026-10-08, `2f892e35`)

`e2e_test.dart` now runs `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
in `setUpAll` (`2f892e35`). The later E2E failures were a `pumpAndSettle` timeout (§102) and §106;
E2E passed 4/4 on 2026-10-21 (§106). Moved from `issues_open.md` on 2026-10-22.

`app/integration_test/e2e_test.dart` pumps `ThrottleIQApp` without calling `Firebase.initializeApp()`, and the test's own comment says so. On the iPhone simulator it fails at once with `[core/no-app] No Firebase App '[DEFAULT]'`, raised from `groupRideLifecycleProvider` building `rideRecordingProvider`. The test never reaches the Places/Saved/bottom-nav assertions. The same failure shows on a clean checkout of `ca1f3f6`, so it predates the §99 work. Fix: add a `setUpAll` that runs `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, as `main.dart` does.

## 101. Full-project audit — verified items FIXED in code (2026-10-08), not verified on a device

Pointer section. Each audit item was re-verified before work (verdicts and one-line reasons are
under each item's **Resolution** line in "101 (record)" below). Only `real-fix` items were
implemented; `not-real`, `already-fixed`, `real-but-skip` and `harmful-as-suggested` items were
deliberately left alone, so do not redo them. Nothing was deployed.

- **Rules (G1):** places rating bump needs a first review in the same transaction (S1); usernames,
  ride likes/votes, forum post/reply, chat message and `lastMessage`, liveSessions, crashNotifications,
  groupRideJoinCodes and reports got shape, size and `request.time` checks (S3). Tests in
  `scripts/test/rules/`.
- **Functions (G3):** account deletion now covers forum follows, group-ride membership, RTDB nodes
  and writes a completion marker; crash notifications use a transactional claim (S4, S5). S2 index
  overrides still need `firestore.indexes.json` + a deploy.
- **Hosting/scripts/CI (G4):** security headers, install page dedupe and links, `deploy.sh` no longer
  `git add -A`, CI read-only permissions and `firebase-tools@15`, `.gitignore` additions.
- **Client (G5, G6, G7, G8, G9):** delete-account re-auth and friendly errors, sign-out live-share
  revoke; sync guard, pull watermark, auth side-effect gating, timezone fallback, DST; localized number
  parsing, loop-route arrival, odometer sheet, elapsed `Stopwatch`; places contrast, Overpass UA/timeouts/ways,
  a11y semantics; placebo sync test replaced, proguard header, release-signing guard, iOS Info.plist.
- **Docs (G10):** README/needs_attention version, next free number, §83.19 status, §64 heading, F6.
- **G7 finish pass:** bike edit odometer conversion (R1), numeric validation (R2), shared
  `parse_localized_number.dart` (R4), clamped-speed accel/jerk (R5), outbox `catchError` (R8), and
  most of R10, each with tests. R3 and the `deltaT`/`Stopwatch` changes stay skipped.
- **Still open from §101:** the S2 index deploy (S6 `group_rides` location membership is obsolete
  since RTDB denies all, `8872feff`); the full open remainder, re-checked 2026-10-22, is in
  `issues_open.md` §101.

### 101 (record). Every audit item with its resolution — moved from `issues_open.md` (2026-10-22)

The open remainder, re-checked on 2026-10-22, is in `issues_open.md` §101. Changes after
2026-10-08: B2 fixed in `5c2db5bf`; the S2 overrides added in `d1205d53` (deploy pending); S12
fixed in `0c0de47b`; S4's chats question decided and built in `84dd97d6`; C4 fixed on 2026-10-14
(noted on the item); S6 and the group-ride part of A2 obsolete since `4cb96a8f`/`8872feff`.

IDs are `101.<area><n>`. "AUTO" = an agent can fix and verify it with analyze/test/rules tests, no founder input or device. Line numbers came from grep and partial reads, so confirm before editing. Items already tracked elsewhere were left out. Baseline at audit time: `flutter analyze` clean, `flutter test` 1758/1758.

#### 101.S Security rules, functions, hosting, scripts, CI
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

#### 101.A Auth, social, chat, forums
- **101.A1 HIGH — `deleteAccount` has no re-auth flow** (`settings_screen.dart:~694`, `auth_provider.dart:~180`). `requires-recent-login` shows as a raw error string, so deletion fails for any older session. AUTO.  
  **Resolution:** FIXED (2026-10-08): `AuthNotifier.reauthenticate` (password / Google) and a retry-once delete flow on `requires-recent-login`, with EN/BN strings. Tests: `test/features/auth/auth_notifier_test.dart`, l10n tests.
- **101.A2 HIGH — sign-out does not stop live share or group-ride broadcast** (`auth_provider.dart:~135`). RTDB leases and nodes can outlive the session. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): sign-out now revokes the live share via a `beforeSignOut` hook with a timeout. REAL-BUT-SKIP: group-ride broadcast (the RTDB lease is released by the map screen's dispose). Test: `auth_notifier_test.dart`.
- **101.A3 MED — unbounded or non-atomic client queries:** `forum_repository.dart:~640` (`_modelForumsUnder`), `:~446` (`forum_follows`), `group_ride_repository.dart:~660`, `ride_share_repository.dart:~484` (`deleteSharedRide` uses `Future.wait`, not batches). AUTO.  
  **Resolution:** NOT FIXED, by design (2026-10-08): NOT REAL for `_modelForumsUnder` and `group_ride_repository` (results are bounded by the catalog / active rides). HARMFUL-AS-SUGGESTED for `forum_follows` `.limit()` (would silently drop follows) and for batching `deleteSharedRide` (rules for likes/comments deletion need the ride to exist, so the order matters). The finish pass reverted the `.limit()` and WriteBatch changes.
- **101.A4 LOW — raw exceptions shown to users** (`report_bottom_sheet` `failedSubmitReport(e)`, settings sign-out has no try/catch). Hard-coded `Text('Social')` at `social_screen.dart:128`. `GestureDetector`s without semantics or 48dp targets in `social_feed_tab.dart` and `chat_room_screen.dart:270`. AUTO.  
  **Resolution:** PARTLY FIXED (2026-10-08): FIXED: `report_bottom_sheet` and delete-account errors no longer show raw exceptions (placeholder-free EN/BN strings), sign-out has try/catch, `social_screen` title uses `navSocialLabel`, chat own-bubble contrast + long-press report semantics, feed sort pills semantics (G8). Tests: `app_localizations_test.dart`, `chat_bubble_contrast_test.dart`, feed pill tests. REAL-BUT-SKIP: remaining GestureDetector semantics in `social_feed_tab` group-ride card and username link (tap action already exposed).
- **101.A5 MED — chat moderation is a six-word English keyword list; no block-on-report.** Product decision.

#### 101.C Core, sync, database
- **101.C1 HIGH — no timeouts on any sync commit** (`cloud_repository.dart` `batch.commit()`, `sync_manager.dart:235-481`). On a captive portal or dead link `_isSyncing` stays true and all later syncs skip. AUTO.  
  **Resolution:** REAL-BUT-SKIP (2026-10-08): adding timeouts to Firestore `batch.commit()` is unsafe (a timeout does not cancel the write, so the retry can double-apply); the C2 try/finally fix means a stuck call no longer wedges later syncs once it settles. Needs a design (cancel token or idempotent batches).
- **101.C2 MED — `_isSyncing` stuck if `checkConnectivity()` throws** (`sync_manager.dart:248`, outside try/finally). AUTO.  
  **Resolution:** FIXED (2026-10-08): connectivity check moved inside the try so `finally` always clears `_isSyncing`. Test: `test/core/cloud/sync_manager_guard_test.dart`.
- **101.C3 MED — failed ride or bike inserts are lost for good:** the pull watermark advances past them; only maintenance has the `firstFailed` rewind. AUTO.  
  **Resolution:** FIXED (2026-10-08): `markShortOfFailures`/`earlierFailure` hold the pull watermark back for failed ride/bike inserts (rides of tombstoned bikes excepted). Tests: `incremental_pull_test.dart`.
- **101.C4 MED (design) — remote edits never reach a second device.** Downloads insert missing rows only. Needs a conflict policy. Founder.  
  **Resolution:** FIXED (2026-10-14, branch `fix/oct14-tiq-sync`): founder decided last-writer-wins. Schema v28 `updated_at` on rides, bikes and maintenance logs (fuel logs already had it); a newer cloud copy replaces a synced local row on download, and uploads are read-then-write transactions that never overwrite a newer copy. Docs from pre-v28 builds count as oldest. Deletions stay with the tombstones. See `arch.md` §5. Tests: `last_writer_wins_test.dart`, `sync_stamps_migration_v28_test.dart`.
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

#### 101.R Ride, routes, maintenance, garage, stats
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

#### 101.P Places, analytics, theme, i18n
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

#### 101.B Build, native, tests
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

#### 101.D Docs and repo hygiene
- **101.D1 HIGH (size) — about 709 MB tracked.** `DOCS/General/screenshots_ui/` holds ~170 MB of PDFs plus ~2,500 JPGs, with byte-identical "boxy" and "curvy" variants (134 duplicate-hash groups) and 50 files over 1 MB. Founder decision on LFS or external storage.
- **101.D2 stale docs:** todo F6 says the PRD is 51 lines (it is 324); PRD header says beta.4.2.0+23 and README says beta.4.1.0+22 (pubspec is beta.4.3.0+24); §83.19 says App Check is off (client activates it in `main.dart:34-36,78`; enforcement is still pending); `issues_open.md` has duplicate `## 79.`, FIXED stubs (§32, §64, §79, §82, §89) still in the open file, and a wrong "next free number". `issues_solved.md` and the `ANTIGRAVRITY_GRILL` folder (typo) are ambiguous. AUTO except renumbering.  
  **Resolution:** PARTLY FIXED (2026-10-08): README release version/tag, `needs_attention.md`, next free number (now §102), §83.19 App Check status, §64 heading, todo F6 re-scoped. NOT REAL: PRD version (matches the latest tag). REAL-BUT-SKIP: duplicate §79, ANTIGRAVRITY_GRILL folder/`issues_solved.md` (referenced from other docs). HARMFUL-AS-SUGGESTED: deleting FIXED pointer stubs (§32 carries a 'do not re-raise' instruction). ASD-STE100 check on the PRD not run.
- **101.D3 LOW — repo hygiene:** `SKILLS/SKILL*.md` are 5 copy-paste duplicates in a third skill location; duplicate `carbon-mono.png`; root `arch.md` and `new_gravity.md` should be folded in; `.gitignore` lacks `.claude/worktrees/`, `.claude/settings.local.json`, `.env*`, `*.jks`, `*.p12`, `google-services.json`. AUTO except the SKILL duplicates.  
  **Resolution:** PARTLY FIXED (2026-10-08): `.gitignore` gains `.claude/worktrees/`, `.env.*` (keeps `.env.example`), `*.p12` (test in hosting hygiene test). NOT REAL: `SKILLS/` duplicates (4 distinct skills), root `arch.md` (maintained). HARMFUL-AS-SUGGESTED: removing `carbon-mono.png` copy (website demo depends on it). REAL-BUT-SKIP: `new_gravity.md`. Note: `app/ios/Runner/GoogleService-Info.plist` is tracked and now matches an ignore rule.

## 102. Founder decisions of 2026-10-08 — BUILT and committed (`2f892e35`), moved 2026-10-22

The first of the two §102 sections in `issues_open.md`. Verified 2026-10-22: `2f892e35` ("archive
bikes with 90-day purge, Garage tab, English-style dates; CI and deps cleanup") committed the
decisions, the `setUpAll` Firebase init in `e2e_test.dart`, and the removal of the `android.yml`,
`dart.yml` and `swift.yml` starter workflows. The E2E `pumpAndSettle` timeout described at the
end no longer blocks: E2E passed 4/4 on 2026-10-21 (§106). What stays open (expired
`liveSessions` cleanup, device checks, founder items) is in `issues_open.md` §102. Paths below
are as they were on 2026-10-08.

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

## 102. Themes / analytics / badges / QR / tour pass — closed parts (2026-10-09), moved 2026-10-22

From the second §102 in `issues_open.md`. The open items (102.1, the Universal Links part of
102.2, 102.3–102.6) stay there.

- **102.2 (DONE 2026-10-09)** blankframe.tech (GitHub Pages, repo `blankframe-tech/landing-page`, commit `824920e`) now
  serves `/.well-known/assetlinks.json` (verified via Google's Digital Asset Links API), `/throttle-iq/install/`,
  and a root `404.html` that routes `/ThrottleIQ/install` and `/ThrottleIQ/u/<uid>` in any casing. QR links
  now use `www.blankframe.tech` (the bare domain 301s, which can't verify). Old notes: the site must serve `/.well-known/assetlinks.json`,
  `/.well-known/apple-app-site-association` (application/json, no redirect) and `/ThrottleIQ/u/*` (copy from
  `public/` or proxy to Firebase Hosting). Add Play App Signing SHA-256 to `assetlinks.json` if used. Then `firebase deploy --only hosting`.
  **iOS Universal Links are off (2026-10-09):** team `NJ4675FFUX` is a personal team, which Apple never allows
  Associated Domains, so the entitlement was removed from `Runner.entitlements` (it broke signing). iPhone camera
  scans open the web page, whose "Open in ThrottleIQ" button uses `throttleiq://u/<uid>`. Re-add on a paid team.
- **102.8 Diff noise:** a `dart format` run may have reflowed `all_rides_screen.dart` and `badge_grid.dart` beyond their real edits.
  - **OBSOLETE** (2026-10-22): that pass was committed long ago.

## 103. Shared-ride card / owner actions follow-ups — done parts (2026-10-15), moved 2026-10-22

- **103.1 Push blocked:** ✅ resolved 2026-10-15. `1349db5` reverted the format-only churn; gate green, pushed to `origin/main`.
- **103.4 E2E:** `integration_test/e2e_test.dart` not run (no simulator). It covers the Places full map, the Social card/owner menu, history Delete ride and the cockpit placement pill, all on `1349db5`.
  - **DONE:** E2E passed 4/4 on an iPhone 17 simulator on 2026-10-21 (§106).

## 104. Spark quota load test — the built outage mode (2026-10-21), moved 2026-10-22

From `issues_open.md` §104.6. Branch `feat/quota-outage` was merged to `main` in `c751968e` on
2026-10-22; it is not in a release yet. The cases it doesn't cover stay in `issues_open.md`
§104.6.

- **104.6 Outage mode (2026-10-21, branch `feat/quota-outage`):** what happens when a limit does run out.
  - **Built:**
    - `FirestoreQuota` plus a `count()` probe in `SyncManager` (1 read, at most every 15 min) pause sync and the outbox, then resume on the first answer after the reset.
    - `OverQuotaBar` and the reworded `errTooManyRequests` tell riders.
    - The owner gets an email from the Cloud Monitoring policy `scripts/monitoring/firestore-quota-alert.yaml`.
  - **Before the pause:** the outbox retired an entry after 20 attempts (about 7.5 h), shorter than a quota day. Every retry also stacked another copy of the same write in the SDK queue.
  - **Rehearsed 2026-10-21** on a throwaway Spark project (`DOCS/Handoff for agents and Todos/load_test/quota-rehearsal-2026-10-21.md`):
    - `count()` and transactions answer `resource-exhausted` once reads run out.
    - Gets and listeners kept being served 8 min past the limit (100,169 reads counted on a 50,000 day).
    - Writes past the limit are queued or accepted, never rejected.
    - Writes behind a rules `get()` keep working.
  - **Alerting:**
    - Alerting works on Spark. The production policy is live: `alertPolicies/13055223357814148266`, 5 conditions, emailing blankframe.technologies@gmail.com.
    - Refused requests never show in `api/request_count`, so "used up" is 99% of reads or writes.
  - **Screen writes fixed 2026-10-22 (branch `fix/reads-104`):** `ackOrQueued` (`core/cloud/write_ack.dart`) waits at most `kOutboxAttemptTimeout` (8 s) for the ack, then treats the write as queued; other errors still throw. It wraps the plain writes behind 31 UI call sites, in the repositories (chat send; forum post create/delete, maintainers, solution; place add/import; report; profile ensure/update/visibility/unblock; badge counters; shared-ride edit/delete; route save/public/delete; group-ride create/invite/location/heartbeat/voice note/invite and location cleanup; group-ride notifications) and in `emergency_contacts_provider.dart`. `addPlace` now uses `doc()` + `set()` so it can return the id unacked; the ride checkpoint (`ride_actions_menu.dart`, not awaited) passes `untilAcked: true`, so a late refusal still shows `checkpointSaveFailed`. `recordEarnedBadge` stays unwrapped (background sync; a late refusal would skip its `permission-denied` fallback and lose the earnedBadges doc). `ensureProfile` still writes the plain profile when the registration batch isn't acked. Invite pings in `ride_mode_selector.dart` now go in parallel. Limit: a refusal that arrives after the 8 s is not shown (the screen already said saved). The `SyncManager` writes and the 20 transaction-based actions are unchanged (still open in `issues_open.md` §104.6). Test: `app/test/core/cloud/write_ack_test.dart`. Not checked on a device or in a real outage.
- **104.2 Group-ride reads, mitigated 2026-10-22 (branch `fix/reads-104`):** `groupRideBroadcastInterval(n)` (`group_ride_broadcast_gate.dart`) spaces publishes 2 s per rider, between 20 s and 40 s; `group_ride_map_screen.dart` restarts its timer when the number of `memberLocations` docs changes the interval. Reads per minute now grow with N up to 20 riders (the ride cap): a 20-rider ride uses about 630 reads/min instead of 1,260, so about 80 min of a 50k day instead of 40. `kGroupRideStaleAfter` went from 160 s to 200 s (heartbeat + two 40 s ticks). The 25 m move gate is unchanged (at riding speed every tick moves more than 25 m). `scripts/loadtest/quota_sim.js` still models a fixed 20 s tick. The real fix is still open (`issues_open.md` §104.2). Test: `app/test/features/social/group_ride_broadcast_gate_test.dart`. Not checked on a device.
- **104.3 Feed vote hydration, partly fixed 2026-10-22 (branch `fix/reads-104`):** `RideShareRepository.hydrateWith` skips the vote `get()` for rides whose `upvotes` and `downvotes` are both 0 (`vote()` bumps a tally in the same transaction that writes the vote doc, so nobody has voted on them). A page of 20 unvoted rides now costs 0 vote reads instead of 40; a voted ride still costs 2 (still open in `issues_open.md` §104.3). Limit: a vote doc written outside the app without a tally bump (rules allow it) won't show as the rider's own vote. Test: `app/test/features/social/ride_vote_hydration_test.dart`.
- **Stale note:** §90.C7 (full re-download every 5 min) no longer holds. Pulls are incremental (`cloud_repository.dart:549`), and an idle cycle costs 4 reads.

## 104.1 Nearby places refetched every 5 km during a ride — FIXED (2026-10-22), not in a release

Was: `live_ride_places_provider.dart` read every place within 25 km from Firestore at ride
start and after each 5 km (about 1,000-1,200 reads per fetch after the §105 import).
- **Now:** `RidePlacesCache` (`app/lib/features/poi_directory/data/ride_places_cache.dart`)
  keeps the places on the device (`ride_places_cache.json` in app support). A refresh pulls
  `updatedAt > lastPull` across `places` (one read when nothing changed), then reads a
  geohash cell whole only when it is new to the phone or older than 3 days. The ride shows
  10 km around the rider, refreshed every 5 km, and shows cached places at once and offline.
- **`updatedAt`:** `PlaceModel.toFirestore` writes `FieldValue.serverTimestamp()`;
  `firestore.rules` refuses any other value on create (optional, so older builds still add
  places). The watermark is always a server `updatedAt`, never the phone clock (the first
  one is the phone clock minus a day).
- **Limits (shortcut, in code):** deletions, the §105 revert, and places added by admin
  scripts or by builds without `updatedAt` reach a phone only on its 3-day cell re-read.
  Rating bumps don't touch `updatedAt`, so cached ratings can be stale; the ride map doesn't
  show them and place detail streams the doc.
- **Tests:** `app/test/features/poi_directory/data/ride_places_cache_test.dart`,
  `scripts/test/rules/places_rules.test.js` (server time allowed, backdated refused).
- **Not done:** `scripts/loadtest/quota_sim.js` still models the old 25 km query.

## 105. Google ratings on Places had no traceable source — FIXED (2026-10-19, branch `data/apify-dhaka-places`), moved 2026-10-22

The founder chose to drop the Google rating (105.1). Whether the 717 seeded places stay in
production is still the founder's call; `scripts/oneoff/revert_google_places.js` takes them down.
105.2 is obsolete: 105.4 found that the public groups don't report checkposts. 105.3 is done.
Paths are updated to the 2026-10-22 DOCS layout (`DOCS/old/apify/`).

- **105.1 MEDIUM — the "G ★ x (n Google)" figures come from a hand-written table.** `scripts/update_places_google_ratings.js` writes ratings from the hard-coded `KNOWN_GOOGLE_RATINGS` name map (for example `'trust filling station': { rating: 4.3, reviews: 1420 }`), matched by place name, not location. Unmatched places get 0.0. Nobody has confirmed the values were copied from Google Maps. If they weren't, the app shows made-up numbers labelled as Google's, and a name match can attach one branch's rating to another branch. *Fix options:* (a) remove the Google rating from the cards; (b) take real values from the Places API (paid, the terms allow display); (c) collect them once with Apify `compass/crawler-google-places` (about $0.004 per place, matched by coordinates). Option (c) breaks Google's terms on scraping and storing Maps content if the ratings are displayed, so use it only to find missing businesses (name, location, phone, hours). Founder decision needed.
  - **Update 2026-10-19 (branch `data/apify-dhaka-places`):** the founder chose to **drop** the Google rating. Done: `place_detail_screen.dart` hides the Google column when `!hasGoogleRating` (it used to say "★ 0 (Not on Google)"); the list badges already hid it. `update_places_google_ratings.js` (and its test) removed. Replaced by `scripts/oneoff/import_google_places.js` (dry run by default, 6 unit tests): it sets every Google rating to 0, enriches existing places within 60 m (phone, hours, generic name, address), and creates the rest as `createdBy: 'system:gmaps-seed-dhaka'` keyed by `googlePlaceId`. Dry run against production on 2026-10-19: 521 existing places, 69 ratings to reset, 80 places to enrich (5 renamed), 717 new (71 fuel, 394 garage, 252 parts). **Written to production 2026-10-19 with founder approval** (866 writes). A second dry run reports 0 left to do. `places` went from 521 to 1,238 docs. **Read-cost impact:** §104.1 (nearby places refetched every 5 km, reading every place within 25 km) now costs about 2.4× as many reads per fetch in Dhaka, so it hits the Spark read quota sooner. Fix §104.1 before launch. The Apify Google Maps run finished (897 Dhaka places, dataset `7tcKVfmd9vYe3nGnS`) and was downloaded on 2026-10-19 (kept outside the repo). Nothing has been written to Firestore. Not checked on a device.
  - **Pointer (2026-10-21):** the export behind the import is `~/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json` (a copy also sits in the gitignored `DOCS/old/apify/2026-10-19_gmaps-dhaka-places/items.json`). To take the import down, use `scripts/oneoff/revert_google_places.js` (dry run by default; how to run: `scripts/README.md`, revert section). Not run against production.
  - **Update 2026-10-22 (branch `fix/reads-104`):** `import_google_places.js` now creates places with `verified: false` (it wrote `true`; judge.md next step 2). Code only: the 717 docs already in production still say `verified: true`. Clearing that needs a founder-approved production write (or the revert script).
- **105.2 Idea, not built:** the Apify Facebook Groups Scraper could replace the manual collection behind `seed_police_checkposts_v3.js` (Traffic Alert BD, BikeBD), with a person reviewing the output before seeding. Public groups only. Never store scraped names or posts in Firestore.
- **105.3 Apify run status (2026-10-19):** the traffic-group scrape finished (300 posts from Dhaka Traffic Alert `groups/1711912042372401` and DHAKA News & Traffic Alert `groups/874833945893042`, dataset `hhA8ylkEkcMoV07Mf`). The largest group, Traffic Alert BD (450k members), is private and cannot be scraped. The search for bike maintenance and suggestion groups was aborted because the Apify account reached its monthly usage limit, so the forum-topic research (then `DOCS/old/apify/`, now `DOCS/old/apify/`) is blocked until the limit resets on 2026-11-18 ($5.13 of the free $5 used) or the plan is upgraded.
  - **Update 2026-10-21: done.** Limit raised to $10. Scraped 375 posts (Freewheelers `groups/fcb.zone`, BikeBD `groups/bikebdofficial`, Motorcycle Valley), cost $2.65. BD Biker Club, Gixxer Riders BD and Royal Enfield BD returned nothing (private or wrong URL). Topics and ideas: `DOCS/old/apify/2026-10-21_fb_bike_groups.md`. Raw data for every Apify run, plus lessons: `DOCS/old/apify/` (gitignored except `README.md`).
- **105.4 Checkpost scrape result (2026-10-19): not worth a monthly run.** Of the 300 posts (2026-08-25 to 2026-10-18), 1 reported police enforcement: on 2026-10-15, police at every junction in Uttara's sectors were booking riders going the wrong way. That is a one-off crackdown, not a fixed checkpost, so nothing was seeded. These public groups post news, blockades and complaints; checkpost reports would be in the private Traffic Alert BD group, which cannot be scraped. Drop the monthly-run idea unless a public group that reports checkposts turns up.

## 106. The E2E test failed on `main` (2026-10-21) — FIXED (`4b914c10`), moved 2026-10-22

`feat/quota-outage` was merged into `main` on 2026-10-22 (`c751968e`), so it has the fix too.

- **Symptom:** `flutter drive … integration_test/e2e_test.dart` on an iOS simulator fails 3 to 6 s in. `Bad state: Tried to read a provider from a ProviderContainer that was already disposed`, thrown from `RideRecordingNotifier.dispose()` (`ride_recording_provider.dart:1592`).
- **Already on `main`:** the base commit `d92f694e`, run on its own with no other changes, fails the same way. The `feat/quota-outage` branch fails identically and doesn't touch this code.
- **Cause:** `_liveCoordinator` is a `late final` that calls `_ref.read(realtimeServicesProvider)` on first use (`:304-305`). If nothing used it while the notifier was alive, `dispose()` creates it after the container is gone, and Riverpod throws.
- **Fix:** keep the coordinator in a nullable field created on first use, and in `dispose()` call `_liveCoordinatorOrNull?.dispose()`.
- **Resolution:** another session applied this fix on `main` in `4b914c10`, with the unit test `ride_recording_dispose_test.dart`; E2E on `main` then passed 4/4 (`judge.md`, 2026-10-21). `feat/quota-outage` gets it when it merges. With `4b914c10` applied on top of that branch, E2E also passes 4/4 (iPhone 17 simulator, iOS 27.0, 2026-10-21).

## 109. Leftovers from the retired 2026-10-14/15 critiques — partly resolved

- **109.3 N10: GPX and JSON exports write local time with no offset — FIXED (2026-10-22).** `ride_summary_screen.dart` passed `ride.startTime.toIso8601String()` and `ride.endTime?.toIso8601String()` (local time without UTC offset or 'Z') to `ExportService`, and `ExportService.generateGPX` output `<time>$startTime</time>`. Since track points are recorded in UTC, third-party services like Strava showed rides skewed by the local timezone offset (e.g. 6 hours off for Dhaka UTC+6).
  - *Fix:* In `ride_summary_screen.dart:1265-1266`, converted `ride.startTime.toUtc().toIso8601String()` and `ride.endTime?.toUtc().toIso8601String()` at the export boundary so both JSON and GPX receive ISO-8601 UTC strings ending with `Z`. In `ExportService.generateGPX`, normalized `startTime` and trackpoint timestamps via `DateTime.tryParse(...).toUtc().toIso8601String()`, ensuring all emitted GPX `<time>` tags are always UTC.
  - *Tests:* `app/test/core/cloud/export_service_test.dart` (4 unit tests covering local-to-UTC conversion, UTC preservation, point timestamp UTC formatting, bounds and distance).

## 110. Leftovers from the HANDOFF to-do and unverified lists — partly resolved

- **110.3 Gradle wrapper is 8.13 — FIXED (2026-10-22).** Upgraded `distributionUrl` in `app/android/gradle/wrapper/gradle-wrapper.properties` to `gradle-8.14-all.zip`. Verified with Gradle 8.14 runtime (`./gradlew --version`) and `./gradlew tasks --dry-run` successfully.

## 110.5 Data-safety notes missed impact records and the crash research copy — FIXED (2026-10-22)

`throttleiq_data_safety.csv` now ticks App activity → Other actions (impact records:
collected, required, App functionality + Analytics) and Location → Approximate location (the
research copy's map cell: collected, optional opt-in, Analytics).
`data_safety_and_permissions.md` has a "Crash detection records" section with the reasoning
and two founder calls (Health info? User IDs?). Owner still fills the Play form.

## 78.1 (part). `crashEvents.createdAt` was exact to the millisecond — FIXED (2026-10-22), not in a release

The opt-in research copy (`crashEventCloudPayload`, `app/lib/core/cloud/impact_event_payload.dart`)
uploaded the row's `created_at` to the millisecond next to `ownerUid`, a re-identification
handle (architect_todo #8, owner_works_now #18). It is now floored to the UTC hour
(`2026-10-14T15:29:30.000Z` → `2026-10-14T15:00:00.000Z`); an unparseable value is dropped.
`ownerUid` stays (account erasure, `functions/src/account-erasure.ts`, queries by it).
Checked first: `firestore.rules` `crashEventValid` only wants an optional string ≤ 40 chars,
no function reads `crashEvents.createdAt`, the doc id (the row id) is the dedupe key, and
local SQLite (`impact_events.created_at`, used for upload order) and the private
`users/{uid}/impactEvents` copy keep full precision. Already-uploaded docs keep their exact
value until the row is re-synced (relabel or consent change). Tests:
`app/test/cloud/impact_event_payload_test.dart` (floor, on the hour, 59:59.999, year end,
a `+06:00` offset, unparseable).

## 2026-10-15 — Cockpit overlap and phone placement

- **"I'm in a jam" (beta) covered the speed panel** on the ride screen: the button sat in the bottom
  controls, which outgrew the speed panel's fixed `bottom: 160`. It now renders above the panel
  (`active_ride_screen.dart`). Button added in `238d12b`; overlap surfaced with the beta jam labelling.
- **Phone placement moved into the ride:** it was clipped on the Record screen, so it is now a pill at
  the top-left of the cockpit (`phone_placement_selector.dart`), switchable mid-ride. Read at impact
  time only; ride analytics do not yet record placement changes.
- **§103.1 push blocked** (open-file section §103): `1349db5` reverted the format-only churn from `686bc73`; gate green and pushed. §103.2–103.5 stay open.

## Cloud Functions audit, architect to-do #5 (2026-10-22) — FIXED (lane C, `lane/c-functions`)

Functions are still undeployed; these were found by reading the code and are covered by the emulator suite (`npm run test:emulator`, 15/15).

- **Report-evidence purge loaded every matching report into memory.** `purgeOldReportSnapshots` ran two unbounded `.get()` calls and built one in-memory map. *Fix:* both queries now page 400 docs at a time with `startAfter` and one batch per page (`pagedUpdate` in `report-retention.ts`). A closed report about a deleted rider gets its anonymisation in the same write as the evidence purge.
- **Neither purge had a time budget.** Both already paged (the track purge did), but a large backlog ran into the 540 s scheduler timeout and failed the whole run. *Fix:* `purgeOldTrackChunks` and `purgeOldReportSnapshots` take a `deadline`, defaulting to now + `PURGE_BUDGET_MS` (480 s). They stop cleanly at the deadline and the next daily run continues.
- **A re-run of account erasure could leave the username claim behind forever.** The claim was found through the profile's `username`. If the release failed but the profile delete succeeded, a re-run could no longer find the handle. A stale handle on the profile could also delete someone else's claim. *Fix:* `deleteUserData` releases every `usernames/*` doc whose `uid` is the rider's.
- **Chat moderation could destroy the evidence it meant to keep.** `onMessageCreate` overwrote the message text before writing the report holding the original. A failed report write (or a retry, which no longer sees toxic text) lost the text. *Fix:* the report is written first and the message hidden after.
- *Tests:* `test/emulator/account-deletion.test.js` has a re-run test that starts from a half-anonymised chat: one message done, one not, participants still holding the uid, profile gone, claim still present. Both runs must end in the same correct state. `report-retention.test.js` covers paging past 400 docs and the deadline. `track-retention.test.js` covers the deadline.
- *Verified, no change needed:* `anonymizeChat` is idempotent. The rider's messages are blanked first, and `participants` (how a re-run finds the chat) changes last, in a transaction with the `lastMessage` and legacy name/photo cleanup. The chat id is kept, and a chat with nobody left is recursively deleted.

## 114. Brand/model suggestions couldn't be scrolled or tapped — FIXED (2026-10-25)

In onboarding's first-bike step (and on Add/Edit Bike), the Brand and Model suggestion
list (`BrandModelAutocompleteField`, a thin wrapper on Flutter's `Autocomplete`) showed up
but couldn't be scrolled, and tapping an option did nothing, so riders had to type.
*Cause:* the app-wide `KeyboardDismissWrapper` drops focus on any pointer-down outside the
focused field's bounds. The suggestion list sits in the overlay, outside the field, and
`RawAutocomplete` hides it as soon as the field loses focus, so the list was gone before the
tap or drag finished. *Fix:* the wrapper hit-tests the touch and leaves focus alone when it
lands in a `TextFieldTapRegion` (Autocomplete options, selection handles)
(`app/lib/shared/widgets/keyboard_dismiss_wrapper.dart`). Any other outside tap still closes
the keyboard. *Test:* `app/test/shared/widgets/keyboard_dismiss_wrapper_test.dart` picks an
option with the finger going down and up in separate frames. It fails without the fix.
`tester.tap()` sends both in one frame and so missed the bug. Not checked on a device yet.

## 113. Google sign-in fails on Play Store installs (2026-10-25) — FIXED 2026-10-25

Reported by the owner on a Play install (alpha track, build 30, `1.0.0-beta.4.8.0`). Sideloaded and `flutter run` builds are not affected.

- **Cause:** Play App Signing re-signs the app with Google's key, and that key's fingerprint is not registered on the Firebase Android app (`1:603325098273:android:94694220f44cbf63fcf660`), so Google rejects the sign-in. Firebase has only the upload key (`8542b8ad…`), the debug key (`db4c8876…`) and an unidentified `901e472b…`.
- **Play signing key** (read from build 30's Play-generated universal APK with `apksigner verify --max-sdk-version 36 --print-certs`; JDK 21 can't parse the PQC v3.2 signer): SHA-1 `6016d8cbc69b07e8dc3c03397763ae0c6defbf07`, SHA-256 `cf1e8bab278265ccdd230303ae612ba95190a6d04ca85c19b8585e459060543d`.
- **Fixed (console only, no rebuild):** both hashes registered with `firebase apps:android:sha:create <appId> <hash> --project throttleiqfb`; Firebase created the matching Android OAuth client. The local `app/android/app/google-services.json` (gitignored) got the refreshed `com.bft.throttleiq` block. Not yet re-tested on the Play install.
- **Rule:** if the Play signing key ever changes (key upgrade), register its fingerprint again. Find it in Play Console → App integrity → App signing.
