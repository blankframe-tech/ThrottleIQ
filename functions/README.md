# Functions Directory

Firebase Cloud Functions (TypeScript, compiled to `lib/` by `npm run build`).
`src/index.ts` re-exports every trigger. It's the only entry point
`firebase deploy --only functions` looks at.

## Triggers

| Export | Trigger | What it does |
|---|---|---|
| `onUserAccountDeleted` | Auth user deleted (v1) | Server-side cleanup after in-app account deletion: releases the username claim, then **recursively** deletes `users/{uid}` (with every subcollection), the rider's shared `rides`, `liveSessions`, `crashNotifications`, and `follows` edges in both directions. Doesn't touch content posted in other people's spaces or Cloudinary assets (issues_open.md §69.O2). |
| `reconcileRideIdentity` | `rides/{rideId}` write (v2) | Overwrites `userName`/`userPhotoUrl` from `users/{userId}` so a shared ride can't impersonate another rider. Writes only when a field differs, which stops it recursing. |
| `onMessageCreate` | `chats/{chatId}/messages/{id}` create (v2) | Whole-word keyword moderation: hides the text and files a `pending` report. The English keyword list is a known-weak placeholder (§62.5). |
| `onCrashNotification` | `crashNotifications/{id}` create (v2) | Reads the rider's `emergencyContacts` and "notifies" each one. **Mock:** nothing is sent. `notificationLog` entries say `status: 'mock_not_sent'`. |
| `escalateCrashAlert` | Scheduler every 15 min (v2) | Escalates `contacted` alerts older than 15 min. Also a mock. Needs the `crashNotifications (status, contactedAt)` collection-group index. |

## Build, test, deploy

```bash
npm install
npx tsc --noEmit        # typecheck
npm run build           # compile to lib/
firebase deploy --only functions   # from the repo root
```

There are no unit tests for the functions yet. `firestore.rules` has its
own emulator suite in `scripts/` (`npm run test:rules`).

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
