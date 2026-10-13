# Src Directory

Cloud Functions source. See `../README.md` for what each trigger does.

- `index.ts`: entry point. Re-exports every module below.
- `account-deletion.ts`: `onUserAccountDeleted`. Its body is
  `deleteUserData` in `account-erasure.ts` (not re-exported).
- `ride-identity.ts`: `reconcileRideIdentity`.
- `chat-moderation.ts`: `onMessageCreate`.
- `crash-notifications.ts`: `onCrashNotification`, `escalateCrashAlert`. Also
  calls `admin.initializeApp()`; the other modules resolve Firestore lazily
  so import order doesn't matter. The bodies live in `crash-core.ts` and the
  pure claim rules in `crash-claim.ts` (neither is re-exported).
