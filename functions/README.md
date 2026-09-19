# Functions Directory

Firebase Cloud Functions (TypeScript, compiled to `lib/` by `npm run build`).
`src/index.ts` re-exports every trigger. It's the only entry point
`firebase deploy --only functions` looks at.

## Triggers

| Export | Trigger | What it does |
|---|---|---|
| `onUserAccountDeleted` | Auth user deleted (v1) | Server-side cleanup after in-app account deletion: releases the username claim, then **recursively** deletes `users/{uid}` (with every subcollection), the rider's shared `rides`, `liveSessions`, `crashNotifications`, and `follows` edges in both directions. Doesn't touch content posted in other people's spaces or Cloudinary assets (issues_open.md §69.O2). |
| `reconcileRideIdentity` | `rides/{rideId}` write | Overwrites `userName`/`userPhotoUrl` from `users/{userId}` so a shared ride can't impersonate another rider. Writes only when a field differs, which stops it recursing. |
| `onMessageCreate` | `chats/{chatId}/messages/{id}` create (v2) | Whole-word keyword moderation: hides the text and files a `pending` report. The English keyword list is a known-weak placeholder (§62.5). |
| `onCrashNotification` | `crashNotifications/{id}` create | Reads the rider's `emergencyContacts` and "notifies" each one. **Mock:** nothing is sent. `notificationLog` entries say `status: 'mock_not_sent'`. |
| `escalateCrashAlert` | Pub/Sub every 15 min | Escalates `contacted` alerts older than 15 min. Also a mock. Needs the `crashNotifications (status, contactedAt)` collection-group index. |

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

- **Runtime:** pinned to Node 20 (`package.json` `engines`,
  `firebase.json` `runtime`), which Google has deprecated for Cloud
  Functions. `firebase-functions` is on `^4.8`. Move to Node 22 and a current
  `firebase-functions` before the next deploy (issues_open.md §69.O6).
- **Not yet deployed:** as of 2026-09-19, `onUserAccountDeleted` and the
  §69 fixes exist only in source.
