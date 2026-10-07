# Functions Directory

Firebase Cloud Functions (TypeScript, compiled to `lib/` by `npm run build`).
`src/index.ts` re-exports every trigger. It's the only entry point
`firebase deploy --only functions` looks at.

## Triggers

| Export | Trigger | What it does |
|---|---|---|
| `onUserAccountDeleted` | Auth user deleted (v1) | Server-side cleanup after in-app account deletion: releases the username claim and `livePointers/{uid}`, then **recursively** deletes the rider's shared `rides`, `liveSessions`, `crashNotifications`, and `follows` edges in both directions. Content in other people's spaces (forum posts/replies, ride comments, place reviews, contributed places) is **anonymized**, not deleted (§83.15). Destroys the rider's Cloudinary uploads from the `users/{uid}/cloudinaryAssets` ledger, then recursively deletes `users/{uid}`. Also (§101.S4) deletes the rider's `forum_follows` (decrementing each forum's `followerCount`), removes them from other riders' `groupRides` (roster row, invitation, `memberLocations`, `memberIds`/`invitedIds`), ends (does not delete) group rides they created, and removes their RTDB `live_shares/{token}`, `group_rides/{id}/locations/{uid}` and `chat_presence/{chat}/{uid}` nodes. Writes `accountDeletions/{uid}` `{completedAt, failedSteps, ok, rtdbSkipped}` so a partial erasure is recorded. The forum post/reply/ride comment anonymization needs three COLLECTION_GROUP `userId` field overrides in `firestore.indexes.json`, deployed (§101.S2); until then those steps show up in `failedSteps`. Body: `src/account-erasure.ts`. Still not covered: chat messages. |
| `reconcileRideIdentity` | `rides/{rideId}` write (v2) | Overwrites `userName`/`userPhotoUrl` from `users/{userId}` so a shared ride can't impersonate another rider. Writes only when a field differs, which stops it recursing. |
| `onMessageCreate` | `chats/{chatId}/messages/{id}` create (v2) | Whole-word keyword moderation: hides the text and files a `pending` report. The English keyword list is a known-weak placeholder (§62.5). |
| `onCrashNotification` | `crashNotifications/{id}` create (v2) | Claims the doc (`pending` -> `processing`, 5-minute lease) so a duplicate event can't re-send (§101.S5), then reads the rider's `emergencyContacts` and "notifies" each one. **Mock:** nothing is sent. `notificationLog` entries say `status: 'mock_not_sent'`. Body: `src/crash-core.ts`. |
| `escalateCrashAlert` | Scheduler every 15 min (v2) | Escalates `contacted` alerts older than 15 min, claiming each (`contacted` -> `escalating`) so overlapping runs can't double-send, and retaking `escalating` claims past the lease. Throws if any escalation fails, so the scheduler records the failure (§101.S5). Also a mock. Needs the `crashNotifications (status, contactedAt)` composite index. |

## Build, test, deploy

```bash
npm install
npx tsc --noEmit        # typecheck
npm run build           # compile to lib/
firebase deploy --only functions   # from the repo root
```

```bash
npm test                # build + pure helper tests (test/*.test.js), no emulator; CI runs this
npm run test:emulator   # build + test/emulator/*.test.js against the Firestore + Database
                        # emulators (ports 8080/9000), under the demo-throttleiq project
```

The emulator suite covers account deletion (`deleteUserData`) and crash-alert
idempotency. It needs Java (on macOS: `JAVA_HOME=/opt/homebrew/opt/openjdk@21`).
The Firestore emulator does not enforce indexes, so a missing index (§101.S2)
won't show up there. `firestore.rules` has its own emulator suite in
`scripts/` (`npm run test:rules`).

## Known issues

- **Runtime:** Node 22 (`package.json` `engines`, `firebase.json`
  `runtime`), `firebase-functions` 7 and `firebase-admin` 14 (issues_open.md
  §69.O6). The Firestore and scheduler triggers use the v2 API;
  `onUserAccountDeleted` stays on `firebase-functions/v1` because v2 has no
  after-the-fact auth delete trigger. If any v1 function of the same name was
  ever deployed, delete it before deploying its v2 replacement (Firebase
  won't upgrade a function from 1st to 2nd gen in place).
- **Not yet deployed:** as of 2026-09-19, `onUserAccountDeleted` and the
  §69 fixes exist only in source.
