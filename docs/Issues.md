# Issues

_Last updated: 2026-08-29 (§35, §36, §37, §38, §40, §41, §42, §43, §44, §45, §46, §47, §48, §49, §50, §51, §52)_

Tracked problems found during review/QA that aren't simple TODOs (those live
in `HANDOFF_Document.md`'s "To do" section). One `##` section per issue.

---

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

## 13. QA report

**Status:** Not started.

_No QA pass has been written up yet. When one is done (manual smoke test,
device walkthrough, or a scripted run), record findings here as dated
sub-sections — one per pass — rather than overwriting this placeholder._

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
  before the claim actually exists. `scripts/set_admin_claim.js` (new) grants
  it, mirroring `reset_beta_data.js`'s safety posture (dry-run default,
  project-id guard, requires real `GOOGLE_APPLICATION_CREDENTIALS`) — this
  agent could not run it, since it needs this project's own service-account
  credentials. **Still to do:** run
  `FIREBASE_PROJECT_ID=throttleiqfb node scripts/set_admin_claim.js --email the.abraar.rar@gmail.com --yes-i-really-mean-it`,
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

**QA seed forum content (`scripts/seed_qa_test_riders.js`,
`scripts/qa_seed_catalog.js`) read as generic and inauthentic.** The 30
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
