# scripts/

Operational scripts for the ThrottleIQ Firebase project (`throttleiqfb`). These
run against **live production data** from your machine. They are not part of the
Flutter app build and are not deployed with the Cloud Functions.

| Script | What it does | Reversible? |
|---|---|---|
| [`reset_beta_data.js`](#-reset_beta_datajs--read-this-first) | Wipes **all** rider data and Auth accounts | **No** |
| [`seed_dhaka_places.js`](#seed_dhaka_placesjs--seed-the-dhaka-places-directory) | Creates place documents for Dhaka's petrol pumps, garages and parts sellers, from OpenStreetMap | Yes — one query deletes the batch |

Both share the same safety posture: `--dry-run` is the default, `FIREBASE_PROJECT_ID`
must be `throttleiqfb`, and each one is idempotent so an interrupted run can just
be re-run. The [Setup](#setup) section below applies to both.

Unit tests for the pure logic in these scripts (no network, no Firestore):

```bash
cd scripts
npm test
```

## Security-rules tests

`test/rules/firestore_rules.test.js` exercises `firestore.rules` against the
Firestore emulator — the engagement-counter clauses (`docs/Issues.md` §24.7)
and the moderation helpers (§24.11). **Run this before any
`firebase deploy --only firestore:rules`.**

```bash
cd scripts
npm run test:rules
```

Two things worth knowing about how this is wired:

- **The emulator needs a JVM, and there is no `java` on PATH on this Mac** —
  `/usr/bin/java` is Apple's stub. The npm script points `JAVA_HOME` at Android
  Studio's bundled JBR (`/Applications/Android Studio.app/Contents/jbr/…`),
  the same runtime the `keytool` workaround in `HANDOFF_Document.md` uses. If
  Android Studio isn't installed, set `JAVA_HOME` to any JDK 17+ instead.
- **These tests live in `test/rules/`, not `test/`, on purpose.** `npm test`'s
  glob is `test/*.test.js` and is deliberately non-recursive, so the
  pure-function tests above stay fast and emulator-free.

The runner also passes `$npm_node_execpath` explicitly rather than saying
`node`: `firebase emulators:exec` runs its script with the Firebase standalone
binary shadowing `node` on PATH, which otherwise tries to resolve `--test` as a
module path and fails.

---

# ⚠️ `reset_beta_data.js` — READ THIS FIRST

**This script permanently and irreversibly destroys all ThrottleIQ user data.**

It deletes, for every rider without exception:

- every Firestore document in `users`, including each rider's ride summaries,
  **GPS trails**, bikes, maintenance logs, saved routes, emergency contacts,
  earned badges and notifications
- the entire shared-ride feed (`rides`) with its likes, votes and comments
- every forum, post, reply and vote (`forums`, `forum_follows`)
- the follow graph and every reserved @username (`follows`, `usernames`)
- all rider-contributed places and reviews (`places`, `reviews`)
- all live-share sessions and crash alerts (`liveSessions`, `crashNotifications`)
- `groupRides` and `challenges`
- **every Firebase Authentication account** — riders will not be able to sign in,
  and their accounts will not come back

**There is no undo. There is no soft delete. There is no export step.** Firestore
does not have a recycle bin. If you have not taken a backup, the data is gone the
moment the script commits.

If any of that is not exactly what you want, stop and do not run it.

---

## What it is for

Wiping the beta project so a fresh set of testers starts from an empty app —
no leftover forum posts, no half-finished accounts, no stale places.

## Before you run it

1. **Take a backup if there is any chance you'll want the data.** From a machine
   with `gcloud` authenticated:

   ```bash
   gcloud firestore export gs://<your-backup-bucket>/pre-beta-reset-$(date +%Y%m%d) \
     --project=throttleiqfb
   ```

   This needs a Cloud Storage bucket that already exists. If you do not have one,
   accept that the wipe is unrecoverable before continuing.

2. **Tell your testers.** Their accounts will be deleted; they will have to sign
   up again from scratch.

## Setup

### 1. Get a service-account key

The script authenticates as a service account, not as you. Get a key:

1. Open the [Firebase Console](https://console.firebase.google.com/) and select
   the **throttleiqfb** project.
2. Gear icon → **Project settings** → **Service accounts**.
3. Click **Generate new private key**, confirm, and save the downloaded JSON file
   somewhere outside this repository — for example `~/.secrets/throttleiqfb-admin.json`.

   The default "Firebase Admin SDK" service account already has the Firestore and
   Authentication permissions this script needs.

> **Treat that JSON file as a root password for the project.** Anyone holding it
> can read and destroy all rider data. Never commit it, never paste it into a
> chat or an issue, and delete the key from the Service accounts page once the
> reset is done.

Lock down the file permissions:

```bash
chmod 600 ~/.secrets/throttleiqfb-admin.json
```

### 2. Install dependencies

```bash
cd scripts
npm install
```

### 3. Set the environment

Both variables are required — the script refuses to run without the first, and
the Firebase Admin SDK cannot authenticate without the second.

```bash
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/throttleiqfb-admin.json"
export FIREBASE_PROJECT_ID="throttleiqfb"
```

`FIREBASE_PROJECT_ID` is a deliberate seatbelt: the script aborts if it is
missing or set to anything other than `throttleiqfb`, and aborts again if the
service-account key turns out to belong to a different project. It is there so
this can never be pointed at the wrong project by accident.

## Running it

### Step 1 — dry run (this is the default)

```bash
cd scripts
npm run reset:dry-run
```

or equivalently:

```bash
node reset_beta_data.js
```

Running the script with **no flags does a dry run**. It walks every collection,
prints how many documents each one holds (including nested subcollections) and
how many Auth accounts exist, and **writes nothing**.

Read that output carefully. It is your last honest look at what you are about to
destroy. Sanity-check the numbers against what you expect — if a count is wildly
higher or lower than you thought, find out why before continuing.

### Step 2 — the real thing

Only once the dry-run output looks right:

```bash
cd scripts
npm run reset:execute
```

or equivalently:

```bash
node reset_beta_data.js --yes-i-really-mean-it
```

Nothing is deleted without that flag. The script pauses for five seconds before
it starts, prints a running total as it goes, and finishes with a per-collection
summary.

### Step 3 — verify

Run the dry run again. Every count should read `0`.

```bash
npm run reset:dry-run
```

## Other flags

| Flag | Effect |
|---|---|
| `--dry-run` | Explicit form of the default. Counts only. |
| `--yes-i-really-mean-it` | Required for any deletion. |
| `--only=a,b,c` | Restrict to specific top-level collections. Use `auth` for Firebase Auth accounts. Useful for resuming a partial run, e.g. `--only=forums,rides`. |
| `--skip-auth` | Wipe Firestore but leave rider sign-ins intact. |
| `--help` | Usage summary and the list of known collections. |

## If it stops partway

Just run it again. The script is **idempotent and resumable**: each batch commits
independently, so an interruption (Ctrl-C, a network drop, a rate limit) only
means fewer documents remain for the next run to find. Documents already deleted
are simply not there the second time. A failure in one collection is logged and
the script moves on to the next, so one bad collection does not block the rest.

## Notes on the implementation

- Deletes are committed in batches of **400 operations** — Firestore's hard batch
  limit is 500, and the margin keeps each commit small enough to retry cheaply.
- Subcollections are discovered at runtime via `listCollections()` rather than
  hardcoded, so nothing is missed when a feature adds one.
- It enumerates with `listDocuments()` rather than a query, so "phantom"
  documents — ids that hold subcollections but no document of their own — are
  caught too. Missing those would leave orphaned subcollections behind that still
  turn up in collection-group queries.
- Two collection names are not what you would guess, and the script is written
  against the real ones: shared rides are the **top-level `rides`** collection
  (there is no `shared_rides`), and in-app notifications are
  **`users/{uid}/notifications`** (there is no top-level `notifications`).

## Syntax check

```bash
node --check reset_beta_data.js
```

or `npm run check`. This only parses the file; it does not connect to anything.

---

# `seed_dhaka_places.js` — seed the Dhaka places directory

Pre-populates the `places` collection with Dhaka's petrol pumps, motorcycle
garages and parts sellers, so a rider who opens **Places** in Dhaka sees a useful
directory on first launch instead of an empty list waiting for someone else to
contribute.

Unlike the reset script, this one only ever **creates** documents. It never
updates or deletes one, and every document it writes is tagged so the whole batch
can be found again (see [Undoing a seed](#undoing-a-seed)).

## Where the data comes from

[OpenStreetMap](https://www.openstreetmap.org/), queried through the public
[Overpass API](https://overpass-api.de/) — the same source the in-app **Import
nearby** button already uses
(`app/lib/features/poi_directory/data/services/overpass_service.dart`). The
difference is scope: the app asks for a radius around one rider's position and
attributes what it finds to that rider; this script asks for a bounding box over
the whole city once, and attributes what it finds to a system sentinel.

OSM data is ODbL-licensed. If place data ever becomes user-visible as a dataset
(an export, a public map page) rather than just pins in the app, that needs an
attribution line.

**Set expectations on coverage.** OSM's Dhaka data is uneven: chain petrol
stations are mapped well, small independent garages and roadside parts counters
much less so. A run in August 2026 returned **395 places — 256 fuel, 75 garages,
64 parts sellers**, of which 32 had no name in OSM at all. That is the largest
list freely available, not a complete census of the city.

The three OSM tags the app's importer understands (`amenity=fuel`,
`craft=motorcycle_repair`, `shop=motorcycle`) are queried with the same
precedence the app uses, so both importers agree on a category. The script also
queries two tags the app doesn't, because they close real gaps in Dhaka:
`shop=motorcycle_repair` (used interchangeably with the `craft` version by
Bangladeshi mappers) and `shop=motorcycle_parts` (the actual tag for a parts
counter — `shop=motorcycle` usually means a dealership). Seeding those is safe:
deduplication is by OSM id, so a node the app can't classify is one it will never
try to re-create.

It also queries ways and relations, not just nodes. Most of Dhaka's petrol
stations are mapped as building polygons rather than points, and a node-only
query — which is what the app does — silently misses every one of them.

## Setup

Same as the reset script: [a service-account key](#1-get-a-service-account-key),
`npm install`, and `FIREBASE_PROJECT_ID=throttleiqfb`.

One exception worth knowing: the fetch-only step below (`--out=`) needs **no
credentials at all**, because it stops before touching Firestore. You can pull and
review the data on any machine and only bring the service-account key out for the
write.

## Running it

### Step 1 — fetch and review the data (no credentials needed)

```bash
cd scripts
FIREBASE_PROJECT_ID=throttleiqfb npm run seed:dhaka:fetch
```

This queries Overpass, prints a per-category count, and writes every candidate to
`dhaka_places.json`. Nothing is sent to Firestore.

**Read that file.** It is a bulk import into production, and OSM is
crowd-sourced: expect a few closed stations, some duplicated entries, and the
unnamed ones that will land as literally "Fuel" or "Garage". Delete anything that
is junk — the file is a plain JSON array of candidates under a `places` key, so
editing it is just deleting objects.

### Step 2 — dry run

```bash
FIREBASE_PROJECT_ID=throttleiqfb node seed_dhaka_places.js --from=dhaka_places.json
```

Reports how many of those places are already in the directory and how many are
new, and prints a sample of the exact documents it would write. Writes nothing.

Or skip the review file entirely and dry-run straight against a live query:

```bash
FIREBASE_PROJECT_ID=throttleiqfb npm run seed:dhaka:dry-run
```

### Step 3 — write

```bash
FIREBASE_PROJECT_ID=throttleiqfb node seed_dhaka_places.js \
  --from=dhaka_places.json --yes-i-really-mean-it
```

Nothing is created without that flag. The script pauses five seconds first,
commits in batches of 400, and prints a running total.

For a cautious first pass, add `--limit=25` — it writes only the first 25 new
places, and re-running picks up where it left off.

### Step 4 — verify

Re-run the dry run. It should report every place as already present and **0 new**.
Then open the app in Dhaka (or with a simulated location there) and check the
Places list.

## Flags

| Flag | Effect |
|---|---|
| `--dry-run` | Explicit form of the default. Fetches and reports only. |
| `--yes-i-really-mean-it` | Required to create anything. |
| `--bbox=s,w,n,e` | Bounding box, as south,west,north,east. Defaults to Dhaka metro (`23.65,90.3,23.92,90.52`) — see the note below. |
| `--categories=a,b,c` | Restrict to some of `fuel`, `garage`, `parts`. |
| `--limit=N` | Create at most N new places this run. |
| `--out=FILE` | Write the fetched candidates to FILE as JSON and stop. Touches no Firestore, needs no credentials. |
| `--from=FILE` | Read candidates from FILE instead of querying Overpass. |
| `--unverified` | Create with `verified: false` — see below. |
| `--no-dedupe` | Skip the node-vs-way merge. |
| `--endpoint=URL` | Use an alternate Overpass mirror. |
| `--help` | Usage summary. |

## Two decisions baked in, and why

**Seeded places are created `verified: true`.** They come from a structured
dataset, not from an unverified rider submission, so they are not waiting on
moderation. This is deliberately different from what the app's own importer does:
`firestore.rules` forces any client-created place to `verified: false`, and the
Admin SDK bypasses rules. Pass `--unverified` if you would rather they queue for
review like anything else.

**`createdBy` is the sentinel `system:osm-seed-dhaka`, not a real uid.** "My
places" is a `createdBy == <uid>` query, so a real uid there would hand one rider
personal ownership of every pump in Dhaka. A colon can't appear in a Firebase
uid, so the sentinel can never collide with one.

## Picking the bounding box

The default covers Dhaka metro plus the fringes a rider actually leaves town
through: Uttara and the airport to the north, Keraniganj across the river, and
the near edges of Savar and Narayanganj. An administrative boundary filter would
be tidier on paper and would cut exactly those edges.

To seed another city, pass its box — for example Chattogram:

```bash
FIREBASE_PROJECT_ID=throttleiqfb node seed_dhaka_places.js \
  --bbox=22.28,91.72,22.42,91.88 --dry-run
```

(The sentinel in `createdBy` still says `dhaka`. If seeding other cities becomes
a routine thing, that constant should become a flag.)

## Undoing a seed

Every seeded document carries `createdBy: 'system:osm-seed-dhaka'`, so the batch
is one query away. There is no built-in delete flag — deleting places is a
destructive operation and belongs behind a deliberate action, not a flag on the
script that created them. From a Node REPL in `scripts/` with the environment
already set:

```js
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.applicationDefault(),
                      projectId: 'throttleiqfb' });
const db = admin.firestore();
const snap = await db.collection('places')
  .where('createdBy', '==', 'system:osm-seed-dhaka').get();
console.log(snap.size);                       // check this number first
const batch = db.batch();
snap.docs.forEach((d) => batch.delete(d.ref)); // ≤500 at a time
await batch.commit();
```

Rider-submitted places are untouched by that query, and so are any reviews
riders left on seeded places — those live in the separate `reviews` collection
and would be orphaned, not deleted.

## If it stops partway

Run it again. Every document carries its OSM id, and the script reads the existing
ids out of Firestore and skips them before writing — the same
`getExistingOsmIds` contract the in-app importer uses. An interrupted run just
leaves fewer places for the next run to create.

That same contract is what stops a rider's later **Import nearby** tap in Dhaka
from duplicating a seeded place: both sides key off `osmId`.

## Notes on the implementation

- The geohash is a **line-for-line port** of `GeohashUtil.encode`
  (`app/lib/core/utils/geohash_util.dart`) at the precision-9 default
  `GeohashUtils.encode` applies, rather than an npm geohash package. The two have
  to agree exactly: a seeded place whose geohash disagrees with what the client
  computes falls outside the prefix range `getPlacesByGeohash` queries, so it
  exists in Firestore and is invisible on the map, with nothing erroring. The
  port was checked against the Dart implementation over 4,004 points — 2,000
  random inside the Dhaka box, 2,000 random worldwide, plus the origin, both
  poles at the antimeridian and central Dhaka — with zero mismatches. Eight of
  those are pinned as fixtures in `test/seed_dhaka_places.test.js`.
- Documents are written field-for-field as `PlaceModel.toFirestore()` writes
  them, nullable fields included, so a seeded place and a rider-submitted one are
  the same shape and `PlaceModel.fromFirestore` needs no special case.
- Bangla names are kept in preference to `name:en`. In Dhaka the local-script
  name is the more useful label for a rider; `name:en` is only a fallback for an
  entry with no `name` at all.
- The node-vs-way merge collapses one real place mapped twice (typically a point
  inside its own building polygon), keyed on category + coordinates rounded to
  ~11 m + a normalised name. The node wins, because a hand-placed point is
  usually on the forecourt entrance rather than a building centroid.
- Overpass is a free, shared, rate-limited service. The script retries a 429 or
  504 three times with increasing backoff, identifies itself in a `User-Agent`,
  and is only ever run by hand.

## Syntax check and tests

```bash
npm run check   # parses both scripts, connects to nothing
npm test        # unit tests for the mapping, geohash and dedup logic
```

