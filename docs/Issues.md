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

## 8. QA report

**Status:** Not started.

_No QA pass has been written up yet. When one is done (manual smoke test,
device walkthrough, or a scripted run), record findings here as dated
sub-sections — one per pass — rather than overwriting this placeholder._
