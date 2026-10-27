# scripts/

Operational scripts for the ThrottleIQ Firebase project (`throttleiqfb`). These
run against **live production data** from your machine. They are not part of the
Flutter app build and are not deployed with the Cloud Functions.

| Script | What it does | Reversible? |
|---|---|---|
| [`reset_beta_data.js`](#-reset_beta_datajs--read-this-first) | Wipes **all** rider data and Auth accounts | **No** |
| [`seed_dhaka_places.js`](#seed_dhaka_placesjs--seed-the-dhaka-places-directory) | Creates place documents for Dhaka's petrol pumps, garages and parts sellers, from OpenStreetMap | Yes — one query deletes the batch |
| [`seed_ai_cameras.js`](#seed_ai_camerasjs--seed-dhaka-ai-traffic-enforcement-cameras) | Populates the `places` collection with Dhaka's 30+ DMP AI traffic enforcement cameras | Yes — one query deletes `createdBy == 'system:dmp-ai-camera-seed'` |
| [`seed_police_checkposts.js`](#seed_police_checkpostsjs--seed-frequent-police-checkposts) | Populates the `places` collection with Dhaka's 30 frequent police checkpost & citation hotspots | Yes — one query deletes `createdBy == 'system:dmp-checkpost-seed'` |
| [`seed_police_checkposts_v2.js`](#seed_police_checkposts_v2js--seed-additional-police-checkposts) | Populates the `places` collection with 25 additional DMP police checkposts across outer/corridor zones | Yes — one query deletes `createdBy == 'system:dmp-checkpost-seed-v2'` |
| [`seed_police_checkposts_v3.js`](#seed_police_checkposts_v3js--seed-crowdsourced-police-checkposts) | Populates the `places` collection with 35 crowdsourced checkposts from Facebook Traffic groups & Waze | Yes — one query deletes `createdBy == 'system:dmp-checkpost-seed-v3'` |
| [`import_google_places.js`](oneoff/import_google_places.js) | From an Apify Google Maps Scraper export: adds missing Dhaka fuel/garage/parts places, fills phone/hours/generic names on nearby existing ones, and sets every Google rating to 0 (§105). Facts only, no ratings stored. `--from=<export.json>` (the 2026-10-19 export: `~/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json`) | Creates and enrichments: yes, `revert_google_places.js`. Rating reset: no |
| [`revert_google_places.js`](#revert_google_placesjs--take-the-google-maps-import-back-out) | Undoes `import_google_places.js`: deletes the `system:gmaps-seed-dhaka` places nobody has touched since (`--seeded-only`), and with `--from=<export.json>` also clears the Google-derived fields on the 80 enriched ones. Dry run by default; `--apply --backup=<file>` writes | Yes: `--restore=<backup> --apply`. Ratings set to 0 by the import: no |
| [`seed_qa_test_riders.js`](#seed_qa_test_ridersjs--fabricate-qa-test-riders) | Creates fabricated QA/test rider accounts with Bangladesh-market bikes, backdated rides, and forum posts. **Run — 30 accounts are live as of 2026-08-27** | Yes — `cleanup_qa_test_riders.js` |
| [`cleanup_qa_test_riders.js`](#seed_qa_test_ridersjs--fabricate-qa-test-riders) | Removes everything `seed_qa_test_riders.js` created | **No** (but scoped only to tagged QA data) |
| [`migrate_emails_private.js`](#migrate_emails_privatejs--move-emails-off-public-profiles) | One-off B2 migration: copies each profile's `email` to `users/{uid}/private/account` and `emailLookup/{sha256}`, then strips it from the public doc. Takes `--service-account=<key.json>` instead of `FIREBASE_PROJECT_ID`; the key must be for `throttleiqfb` | Mostly — the copies keep the email; it is not put back on the public doc |
| [`backfill_users_visibility.js`](#backfill_users_visibilityjs--stamp-visibility-public-on-legacy-profiles) | One-off: sets `visibility: 'public'` on `users` docs that lack it, so legacy riders show up in search again. Takes a required `--project=<id>` | Yes — the field can be deleted again; single-doc reads already treated a missing field as public |
| [`crash_stats.js`](crash_stats.js) | Read-only: the honest crash-detection numbers (detected crashes, missed falls, recall, false questions, breakdowns) from the opt-in `crashEvents` | n/a — read-only |
| [`export_impact_events.js`](export_impact_events.js) | Read-only: every rider's `impactEvents` to CSV (riders as salted hashes), plus sensor windows with `--windows`, for calibration | n/a — read-only. **Keep the output off git** |
| [`monitoring/firestore-quota-alert.yaml`](#monitoringfirestore-quota-alertyaml--the-quota-email-alert) | Cloud Monitoring alert: emails the owner at 80% of a daily Firestore limit and when requests start being refused (§104) | Yes — `gcloud monitoring policies delete` |
| [`loadtest/quota_rehearsal.js`](#loadtestquota_rehearsaljs--rehearse-a-quota-outage) | Spends a **throwaway** Spark project's daily Firestore quota and records how the SDK reports it (§104). Refuses any project id without `quota-lab` | n/a — the lab project is deleted afterwards |

All share the same safety posture: `--dry-run` is the default, `FIREBASE_PROJECT_ID`
must be `throttleiqfb`, and each one is idempotent so an interrupted run can just
be re-run. The [Setup](#setup) section below applies to all of them.

Unit tests for the pure logic in these scripts (no network, no Firestore):

```bash
cd scripts
npm test
```

## Security-rules tests

`test/rules/firestore_rules.test.js` exercises `firestore.rules` against the
Firestore emulator — the engagement-counter clauses (`issues_fixed.md` §24.7)
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
  CI (`.github/workflows/ci.yml`) runs `npm run test:rules:ci` instead, the
  same command without the hardcoded `JAVA_HOME`; it installs a JDK with
  `actions/setup-java` first.
- **These tests live in `test/rules/`, not `test/`, on purpose.** `npm test`'s
  glob is `test/*.test.js` and is deliberately non-recursive, so the
  pure-function tests above stay fast and emulator-free.

The runner also passes `$npm_node_execpath` explicitly rather than saying
`node`: `firebase emulators:exec` runs its script with the Firebase standalone
binary shadowing `node` on PATH, which otherwise tries to resolve `--test` as a
module path and fails.

## Realtime Database tests

Contract and rationale: `DOCS/For Devs and Contributors/architecture/realtime-database.md`.

```bash
cd scripts
npm run test:rtdb        # Mac: JAVA_HOME -> Homebrew openjdk@21
npm run test:rtdb:ci     # same, JAVA_HOME from the environment (CI)
```

Runs, against the RTDB emulator (port 9000):

- `test/rtdb/rtdb_rules.test.js` — `database.rules.json`, which denies every
  read and write since 2026-10-14 (B9: RTDB is retired). Each test is a
  read or write the app or the live viewer used to make, now refused. The
  two-client delivery suite went with the per-path rules; both are in git
  history.
- `test/live_viewer_core.test.js` — the pure merge/staleness/seq logic in
  `public/live-viewer-core.js` (no emulator needed; also picked up by
  `npm test`).

## Firestore daily quota (§104)

`throttleiqfb` is on Spark. Once a daily limit is used up (50,000 reads,
20,000 writes or 20,000 deletes), Firestore refuses that kind of request for
every rider until the reset around midnight Pacific (13:00 Dhaka in summer,
14:00 in winter). The app then pauses its sync and shows a strip
(`app/lib/core/cloud/firestore_quota.dart`).

Both items below need the owner's Google account. The Play-publisher service
account that gcloud uses on this Mac can't read Cloud Monitoring.

```bash
gcloud auth login blankframe.technologies@gmail.com   # the owner; opens a browser
# Put the default account back afterwards:
gcloud config set account id-throttleiq-play-publisher@throttle-iq-gcc1.iam.gserviceaccount.com
OWNER=blankframe.technologies@gmail.com
```

### `monitoring/firestore-quota-alert.yaml` — the quota email alert

One policy, five conditions, each emailing the owner on its own: reads, writes
or deletes above 80% of the daily limit, and reads or writes "used up" (99%).
All use a rolling 24 h window. Refused requests never reach
`api/request_count`, so there is no "requests refused" condition
(`DOCS/Handoff for agents and Todos/load_test/quota-rehearsal-2026-10-21.md`). Emails arrive about 6-7
minutes after a threshold is crossed. **Live on `throttleiqfb` since
2026-10-21** (`alertPolicies/13055223357814148266`, channel
`notificationChannels/9574270854457855850`). Apply it once per project
(`PROJECT=throttleiqfb`):

```bash
TOKEN=$(gcloud auth print-access-token --account=$OWNER)
# 1. The email channel (once). Note the "name" it returns.
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "https://monitoring.googleapis.com/v3/projects/$PROJECT/notificationChannels" \
  -d '{"type":"email","displayName":"Owner email","labels":{"email_address":"blankframe.technologies@gmail.com"}}'
# 2. The policy.
gcloud monitoring policies create --project=$PROJECT --account=$OWNER \
  --policy-from-file=monitoring/firestore-quota-alert.yaml \
  --notification-channels=projects/$PROJECT/notificationChannels/<id>
```

To change it, edit the YAML, delete the old policy
(`gcloud monitoring policies list` / `policies delete`) and create it again.

### `loadtest/quota_rehearsal.js` — rehearse a quota outage

Spends a **throwaway** project's daily quota on purpose and prints, as markdown
tables, how the client SDK answers before and after: `count()` (the app's
probe), query and doc `get`, a listener, a plain `set`, a `set` behind a rules
`get()`, and a transaction. It refuses any project id that doesn't contain
`quota-lab`. Never run it against `throttleiqfb`: it would lock every rider out
until the reset.

```bash
LAB=throttleiq-quota-lab-$(date +%Y%m%d)
firebase projects:create $LAB
firebase firestore:databases:create "(default)" --location=asia-south1 --project=$LAB
firebase apps:create WEB quota-lab --project=$LAB
firebase apps:sdkconfig WEB --project=$LAB          # gives apiKey and appId
# Lab rules through a firebase.json outside the repo, so nothing can reach throttleiqfb:
LABDIR=$(mktemp -d) && cp loadtest/quota_lab.rules $LABDIR/firestore.rules
echo '{"firestore":{"rules":"firestore.rules"}}' > $LABDIR/firebase.json
(cd $LABDIR && firebase deploy --only firestore:rules --project=$LAB)
# Optional: the alert above with PROJECT=$LAB, to see the emails arrive.
npm run loadtest:rehearsal -- --project=$LAB --api-key=<apiKey> --app-id=<appId>
# Record the tables under "DOCS/Handoff for agents and Todos/load_test/", then:
gcloud projects delete $LAB --account=$OWNER   # can be undone for 30 days
```

---

# `migrate_emails_private.js` — move emails off public profiles

One-off, for B2 in `CrtiQue_Oct14.md`. Run it once, by hand, **after** the B2
`firestore.rules` are deployed (they stop any build from writing an email back
onto the public profile). New builds also migrate each rider on sign-in; this
covers riders who never open the app again.

```bash
cd scripts
node oneoff/migrate_emails_private.js --service-account=/path/outside/the/repo/key.json                         # dry run: counts only
node oneoff/migrate_emails_private.js --service-account=/path/outside/the/repo/key.json --yes-i-really-mean-it  # moves them
```

It prints counts and uids, never an address, warns if one email sits on two
profiles, and a second run reports 0. Unit tests: `npm test`
(`test/migrate_emails_private.test.js`).

---

# `backfill_users_visibility.js` — stamp `visibility: 'public'` on legacy profiles

One-off, for the A4/D9 rule that only lets a `users` list query return
`visibility == 'public'` docs. A profile written before `visibility` existed
drops out of search, suggestions and All People until its rider signs in
again; this covers riders who don't. Single-doc reads already treat a missing
field as public, so no rider's privacy changes.

```bash
cd scripts && npm install
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/throttleiqfb-admin.json"
node oneoff/backfill_users_visibility.js --project=throttleiqfb                         # dry run: count + first uids
node oneoff/backfill_users_visibility.js --project=throttleiqfb --yes-i-really-mean-it  # writes, after typing BACKFILL VISIBILITY
```

`--project` is required and must match the key's `project_id`. Missing and
`null` both count as "no visibility". Each write carries the doc's read time
as a precondition, so a rider who changes their own setting mid-run is skipped,
not overwritten; re-run to pick up anything skipped. A second run reports 0.
Tests: `npm test` (`test/backfill_users_visibility.test.js`) and
`npm run test:rules` (`test/rules/backfill_users_visibility.test.js`, emulator).

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
node oneoff/reset_beta_data.js
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
node oneoff/reset_beta_data.js --yes-i-really-mean-it
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
node --check oneoff/reset_beta_data.js
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
FIREBASE_PROJECT_ID=throttleiqfb node oneoff/seed_dhaka_places.js --from=dhaka_places.json
```

Reports how many of those places are already in the directory and how many are
new, and prints a sample of the exact documents it would write. Writes nothing.

Or skip the review file entirely and dry-run straight against a live query:

```bash
FIREBASE_PROJECT_ID=throttleiqfb npm run seed:dhaka:dry-run
```

### Step 3 — write

```bash
FIREBASE_PROJECT_ID=throttleiqfb node oneoff/seed_dhaka_places.js \
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
FIREBASE_PROJECT_ID=throttleiqfb node oneoff/seed_dhaka_places.js \
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
  computes falls outside the prefix range `getNearbyPlaces` queries, so it
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

---

# `seed_qa_test_riders.js` — fabricate QA test riders

Creates fabricated rider accounts so the Social feed, forums and garage
screens have realistic content to QA against instead of an empty beta app.

By default it creates **30** accounts, each with one bike from a 30-entry
Bangladesh-market catalog spanning commuter (Honda CB Shine 125, Bajaj CT 100,
...) to high-range (KTM RC 390, Kawasaki Z400, Royal Enfield Himalayan 411,
...), a handful of backdated rides, one or two of those rides shared to the
public Social feed, and two forum posts each (one in the bike's own model
forum, one in a general topic forum — Road Trips, Maintenance, Mileage Talk,
Mods & Accessories).

**Read this before running it for real:** this project has only one Firebase
project configured (`throttleiqfb` — see `.firebaserc`), the same one real
beta testers use. There is no separate staging environment. A real run writes
PUBLICLY VISIBLE content — shared rides and forum posts other testers will
see in the app — until you clean it up. If that's not what you want, don't
pass `--yes-i-really-mean-it`.

**Status: this has been run.** All 30 accounts are live in `throttleiqfb` as
of 2026-08-27 — see `HANDOFF_Document.md` for the exact counts and the two
real bugs that run surfaced (both fixed and re-verified against production
before/after: the `qaSeed` tag on bike/ride subdocs breaking device sync, and
`cleanup_qa_test_riders.js`'s original forum-post query needing a Firestore
index this project doesn't have). Run `cleanup_qa_test_riders.js` (dry-run
first) when QA is done with this batch — don't leave it live indefinitely.

## What makes a run safe to inspect first

Unlike the other two scripts, `--dry-run` here needs **no credentials at
all**: it generates every rider/bike/ride/post payload in memory and prints a
summary plus one full sample rider as JSON, without calling Firebase Auth or
Firestore. Read that output before you ever point it at real credentials.

```bash
cd scripts
node oneoff/seed_qa_test_riders.js               # dry run, no setup needed
node oneoff/seed_qa_test_riders.js --count=5     # smaller sample dry run
```

## Running it for real

Same [service-account setup](#1-get-a-service-account-key) as the other
scripts — or, if no service-account key is available, `gcloud auth
application-default login` as an account with Owner/Editor on the GCP
project works too (`GOOGLE_APPLICATION_CREDENTIALS` isn't needed in that
case; Firebase Admin SDK resolves the ADC file automatically). You'll also
likely need `gcloud auth application-default set-quota-project throttleiqfb`
once — Google requires a quota project on user ADC credentials, separately
from IAM permissions. **The GCP project owner is not necessarily the same
account as this app's own admin user** (`the.abraar.rar@gmail.com`, the
email hardcoded in `firestore.rules`/`forum_permissions.dart` for in-app
admin — that's an app-level concept, unrelated to Google Cloud IAM on the
underlying project); logging in as the wrong one fails with
`PERMISSION_DENIED` on both a Firestore read and `auth.listUsers()`.

```bash
cd scripts
FIREBASE_PROJECT_ID=throttleiqfb node oneoff/seed_qa_test_riders.js --yes-i-really-mean-it
```

Nothing is created without that flag, and it also requires typing the phrase
`SEED QA TEST RIDERS` at a prompt first (`--non-interactive` skips that for
scripted use). Each account:

- signs up with Firebase Auth at `<handle>@qa-seed.invalid` (`.invalid` is the
  IANA-reserved TLD for exactly this — RFC 2606 — so it can never collide with
  a real rider's email), its own randomly-generated password (issues_fixed.md
  §62.10 — no more shared hardcoded password; the passwords for accounts
  created by a real run are written to a local, gitignored
  `qa_seed_passwords.<timestamp>.json`, never printed to stdout/CI logs), and
  the custom claim `{ qaSeed: true }`
- gets a `users/{uid}` profile + claimed `usernames/{handle}`, one bike in
  `users/{uid}/bikes`, and 4-8 backdated rides in `users/{uid}/rides`
- shares 1-2 of those rides to the public `rides` feed
- posts twice into `forums/{forumId}/posts` (creating the bike-model forum if
  it doesn't exist yet)

Every Firestore document this creates carries `qaSeed: true` — **except** the
bike and per-user ride documents. Those two are written straight into the
same shape `CloudRepository.uploadBikes`/`uploadRides` use, because
`CloudRepository.downloadBikes`/`downloadRides` on a real device inserts a
Firestore bike/ride doc's fields directly into the local SQLite `bikes`/`rides`
tables by column name — an extra `qaSeed` key there would make that insert
throw (caught per-doc, but the bike/ride would then never sync down). Those
two subtrees are still found and removed by cleanup, since it walks
everything under a `users/{uid}` doc matched by the profile's own `qaSeed`
flag rather than needing the tag on every nested doc.

The bike catalog, topic list, and forum-slug logic live in
`qa_seed_catalog.js`, required by both this script and the cleanup script —
kept in one place because cleanup needs the *exact same* set of possible
forum ids the seed script could have written to (see that script's own
section below for why).

Re-running is safe: an email Firebase Auth already has (i.e. that rider was
already seeded) is logged as `SKIPPED`, not an abort.

## `cleanup_qa_test_riders.js` — remove the batch

Finds everything by the same two markers: `qaSeed: true` on Firestore
documents, and the `@qa-seed.invalid` email domain on Auth accounts. Deletes
the `users/{uid}` profile + its `bikes`/`rides` subtrees, the reserved
`usernames/{handle}` doc, the shared feed rides, the forum posts (decrementing
each forum's `postCount` by however many seeded posts it removes), and the
Auth accounts themselves.

**Forum posts are matched differently from everything else.** The obvious
approach — `collectionGroup('posts').where('qaSeed', '==', true)` — needs a
Firestore composite index that `throttleiqfb` doesn't have, and failed
outright with `FAILED_PRECONDITION` the first time this was run for real.
Instead this queries `forums/{forumId}/posts` directly for every forum id
`seed_qa_test_riders.js` could ever have written to
(`qa_seed_catalog.allSeedableForumIds()` — the full cross product of its bike
catalog and topic list, so it's guaranteed exhaustive) — a plain single-field
query under a known parent, which Firestore always auto-indexes.

It deliberately does **not** delete the forum documents themselves, even ones
the seed script had to create (tagged `qaSeedCreatedForum: true`) — a real
rider may have posted into one since seeding. An empty forum shell left
behind is harmless; deleting one a real rider is now using would not be.

```bash
cd scripts
FIREBASE_PROJECT_ID=throttleiqfb node oneoff/cleanup_qa_test_riders.js               # dry run
FIREBASE_PROJECT_ID=throttleiqfb node oneoff/cleanup_qa_test_riders.js --yes-i-really-mean-it
```

Requires the confirmation phrase `DELETE QA SEED DATA`, same as
`--yes-i-really-mean-it` on the other destructive script here. This is
irreversible, but scoped only to the tagged QA batch — it cannot touch real
rider data.

## Live roster (reseeded 2026-09-19)

The previous 2026-08-27 batch (mixed-gender names, English forum posts, a
catalog with KTM/Kawasaki/other >150cc entries) was deleted via
`cleanup_qa_test_riders.js --yes-i-really-mean-it` and replaced with a fresh
`seed_qa_test_riders.js --yes-i-really-mean-it` run against the then-current
script (all-male rider names, Banglish forum post copy, a bike catalog
restricted above 150cc to CFMoto/Royal Enfield only — §55/§69.13 in
`issues_fixed.md`). The table below is what's *actually in `throttleiqfb`
right now*, pulled from Firestore after the run — see
[Running it for real](#running-it-for-real) above for how to reproduce this
listing (`qa_seed_catalog.allSeedableForumIds()` plus a `qaSeed == true`
query per forum/user).

| Handle | Name | Bike | City |
|---|---|---|---|
| tanvir01 | Tanvir Ahmed | Honda CB Shine 125 | Dhaka |
| mizanur02 | Mizanur Rahman | Bajaj Discover 125 | Chattogram |
| rakibul03 | Rakibul Islam | TVS Metro Plus 100 | Sylhet |
| shafiqul04 | Shafiqul Islam | Hero Splendor Plus | Rajshahi |
| shakil05 | Shakil Hasan | Yamaha Saluto 125 | Cox's Bazar |
| golam06 | Golam Mostofa | Suzuki Hayate EP | Bogura |
| imran07 | Imran Hossain | Runner Turbo 100 | Cumilla |
| rashedul08 | Rashedul Karim | Lifan KP100 | Khulna |
| kamrul09 | Kamrul Hasan | Walton Fizor 125 | Rangpur |
| faisal10 | Faisal Ahmed | Bajaj CT 100 | Mymensingh |
| mahmudul11 | Mahmudul Hasan | Yamaha FZS-Fi V3 | Dhaka |
| zahidul12 | Zahidul Islam | Suzuki GSX-R150 | Chattogram |
| arif13 | Arif Hossain | Honda CB150R Streetfire | Sylhet |
| aminul14 | Aminul Haque | Bajaj Pulsar 150 | Rajshahi |
| nayeem15 | Nayeem Chowdhury | CF Moto SR 250 | Cox's Bazar |
| shamsul16 | Shamsul Alam | CF Moto SR 250 | Bogura |
| habibur17 | Habibur Rahman | CF Moto SR 300 | Cumilla |
| delwar18 | Delwar Hossain | CF Moto SR 300 | Khulna |
| rezaul19 | Rezaul Karim | CF Moto CF Light 230 Dual | Rangpur |
| nazmul20 | Nazmul Hasan | CF Moto CF Light 230 Dual | Mymensingh |
| sohel21 | Sohel Rana | Royal Enfield Classic 350 | Dhaka |
| iqbal22 | Iqbal Hossain | Royal Enfield Classic 350 | Chattogram |
| anisur23 | Anisur Rahman | Royal Enfield Bullet 350 | Sylhet |
| ashraful24 | Ashraful Islam | Royal Enfield Bullet 350 | Rajshahi |
| jubayer25 | Jubayer Ahmed | Royal Enfield Meteor 350 | Cox's Bazar |
| rafiqul26 | Rafiqul Islam | Royal Enfield Meteor 350 | Bogura |
| emon27 | Emon Khan | Royal Enfield Hunter 350 | Cumilla |
| monirul28 | Monirul Islam | Royal Enfield Hunter 350 | Khulna |
| riyad29 | Riyad Hossain | Royal Enfield Himalayan 411 | Rangpur |
| shariful30 | Shariful Islam | Royal Enfield Himalayan 411 | Mymensingh |

**Where their posts are** — 60 posts across 26 forums: one post per rider in
their own bike's model forum (21 distinct model forums — several riders now
share a forum, since the catalog only has 9 distinct bikes above 150cc:
CFMoto SR 250/SR 300/CF Light 230 Dual and Royal Enfield Classic 350/Bullet
350/Meteor 350/Hunter 350/Himalayan 411, 2 posts each), plus general topic
forums — **Road Trips** (4 posts), **Maintenance** (11), **Mileage Talk**
(9), **Mods & Accessories** (6).

## Syntax check

```bash
node --check oneoff/seed_qa_test_riders.js
node --check oneoff/cleanup_qa_test_riders.js
node --check oneoff/qa_seed_catalog.js
```

---

# `revert_google_places.js` — take the Google Maps import back out

Written 2026-10-21, **not run against production** (only against the emulator).
Undoes the 2026-10-19 import (`import_google_places.js`, issues_open.md §105).

**Which places.** Only docs the import wrote. Every place it created has
`createdBy == 'system:gmaps-seed-dhaka'` (717 on 2026-10-19, all
`verified: true`); `googlePlaceId` is written by nothing else, so a place with
another author that carries one is one of the 80 it enriched. No other verified
place is touched.

**Two modes; the owner picks one:**

- **B, `--seeded-only`:** deletes the seeded places. Needs no export.
- **A, `--from=<export>`:** B, plus puts the 80 enriched places back: removes
  `googlePlaceId` and clears each field that still equals the Google value in the
  export (`phone`/`hours` → `null`, `address` → `''`, a renamed place →
  `Fuel`/`Garage`/`Parts`). The import only filled empty fields and generic
  names, so that is the pre-import state, reconstructed from the export (there
  is **no pre-import snapshot**: Spark has no backups). A value that was already
  there and happens to equal Google's is cleared too: read the dry-run list.
  A after B is fine (A is a superset).

Both modes skip and list a seeded place changed since the import
(`updatedAt`/`updatedBy` set, or a rider review: `ratingCount > 0`); deleting it
would orphan the review. **Not undoable** either way: the 69 Google ratings set
to 0 stay 0. Saved places live in each phone's SQLite, so a rider who saved a
deleted place keeps a dead entry.

**The export** (needed for A only): `~/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json`
(Apify dataset `7tcKVfmd9vYe3nGnS`, 897 rows, Google Maps content: never commit
it). If the file is missing, download that dataset from Apify as JSON.

```bash
cd scripts
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/throttleiqfb-admin.json"
export FIREBASE_PROJECT_ID=throttleiqfb
EXPORT="$HOME/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json"
BACKUP="$HOME/.secrets/throttleiq/places-revert-$(date +%F-%H%M).json"

node oneoff/revert_google_places.js --seeded-only                 # B, dry run (reads only)
node oneoff/revert_google_places.js --from="$EXPORT"              # A, dry run (reads only)
node oneoff/revert_google_places.js --from="$EXPORT" --apply --backup="$BACKUP"   # writes (or --seeded-only)
node oneoff/revert_google_places.js --from="$EXPORT"              # again: 0 to delete, 0 to clear

node oneoff/revert_google_places.js --restore="$BACKUP"           # undo, dry run
node oneoff/revert_google_places.js --restore="$BACKUP" --apply   # undo
```

- Dry run is the default. `--apply` needs `--backup=<new file>`; it refuses an
  existing file. Before the first write the backup gets every deleted doc
  whole (timestamps kept) and the old value of every cleared field.
  `--restore` recreates the deleted docs (one that exists again is skipped) and
  writes the cleared fields back.
- Each write carries the doc's read time as a precondition (BulkWriter, like
  `backfill_users_visibility.js`), so a place a rider reviews mid-run is skipped,
  not deleted. Re-run to pick up skips. Outside the emulator the key's
  `project_id` must be `throttleiqfb`.
- Cost: one read per place (about 1,240) per run, one write per change.

**Tested** (2026-10-21): 6 unit tests in `test/revert_google_places.test.js`
(import then revert gives the pre-import places back, edited seeds skipped,
only Google-derived fields cleared, idempotent, `--seeded-only`, backup
round trip). Emulator round trip with the real 897-row export: 40 pre-import
places + the real import (767 created, 30 enriched) + one rider review; B
`--apply` deleted 766 and kept the reviewed one; A then cleared 30; all 40
pre-import places matched their pre-import data (6 ratings stay 0); re-runs had
nothing to do; restoring both backups gave back the post-import collection
exactly; a reused backup path and `--apply` without `--backup` were refused.
Not tested: a precondition skip (a review landing mid-run).
