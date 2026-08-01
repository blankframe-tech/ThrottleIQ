# scripts/

Operational scripts for the ThrottleIQ Firebase project (`throttleiqfb`). These
run against **live production data** from your machine. They are not part of the
Flutter app build and are not deployed with the Cloud Functions.

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
