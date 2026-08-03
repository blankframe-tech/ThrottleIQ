# Issues

_Last updated: 2026-08-01_

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

## 10. Stop hook blocked every session end, unconditionally (2026-08-02)

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
