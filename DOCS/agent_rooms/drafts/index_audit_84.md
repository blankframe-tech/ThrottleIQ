> DRAFT for owner review, 2026-10-22

# Audit of the four orphan-candidate indexes (issues §84)

Read-only. `firestore.indexes.json` is not changed. Architect to-do item 3
(`DOCS/agent_rooms/architect_todo.md`).

## Method

- Index definitions read from `firestore.indexes.json` (20 composite indexes,
  8 field overrides on 2026-10-22; §84's "12 → 16" count is from 2026-09-21).
- Grepped `app/lib`, `functions/src`, `scripts/` and `public/` (node_modules
  and `.tmp.driveupload` excluded; `scripts/test/` read but not counted as
  production queries) for every access to `liveSessions` and to collections
  with id `rides`, then for `where`/`orderBy` on the indexed fields.
- All four are `queryScope: COLLECTION`, so a `rides` index applies to any
  collection with id `rides`: the top-level shared-ride collection and the
  private `users/{uid}/rides` subcollection. Both were checked.
- Git history checked with `git log -S` / `-G` to find when each query
  shape last existed, since old builds on phones may still run it.

## 1. `liveSessions (userId ASC, expiresAt ASC)`

`firestore.indexes.json:179-192`.

Candidate queries:

| Where | Query | Can use this index? |
|---|---|---|
| `functions/src/account-erasure.ts:111` | `liveSessions.where("uid", "==", uid)` | No: field is `uid`, single equality, served by the automatic single-field index |
| `functions/src/account-erasure.ts:281` | same | No |
| `app/lib/features/ride/presentation/providers/helpers/live_session_coordinator.dart:256`, `:313`, `:361` | `.doc(token)` set / update / delete | No query |
| `app/lib/core/cloud/outbox_service.dart:653` | `.doc(token).update` | No query |
| `public/live-viewer.html:692` | `.doc(token).onSnapshot` | No query. The comment at `:585-586` notes a `where('uid')...where('active')` query was rejected because it needs a `list` grant |
| `scripts/loadtest/quota_sim.js:105-115` | `doc(...).set` / `listen` | No query |
| `scripts/oneoff/reset_beta_data.js:106` (collection list entry), `:298` | `listDocuments()` at :298 | No query |

Facts that settle it:

- The documents have no `userId` field. `LiveSessionEntity.toFirestore()`
  writes `uid` (`app/lib/features/ride/domain/entities/live_session_entity.dart:78`)
  and `expiresAt` (`:95`). An index on a field no document carries serves
  no query.
- `firestore.rules` grants `get` only on `liveSessions/{token}`, not `list`
  (`firestore.rules:781-793`), so a client cannot run a query on this
  collection at all.
- History: §69.O9 removed this index from the file and deployed indexes
  without `--force`, which left it live in the project
  (`issues_fixed.md:4702-4706`, `:4766-4771`). It was re-declared in
  `d3d16b15` (2026-09-21) so a `--force` deploy can't drop it silently. Also
  flagged as stale by audit §101.S11 (`issues_fixed.md:7291-7292`).
- TTL (§4): the planned TTL policy is on `liveSessions.expiresAt` alone and
  was refused on Spark (`403: billing disabled`, `issues_fixed.md:7454-7458`;
  `issues_open.md:17`). [PLACEHOLDER: confirm in Firebase docs that a TTL
  policy does not use or need a composite index. The agent believes it does
  not, but did not verify it from the repo.]

**Verdict: remove.** Strongest of the four.

## 2. `rides (allowedUserIds CONTAINS, createdAt DESC)`

`firestore.indexes.json:193-206`.

Candidate queries (every `allowedUserIds` query in the repo):

| Where | Query | Can use this index? |
|---|---|---|
| `app/lib/features/social/data/repositories/ride_share_repository.dart:299-303` (`getSharedToMe`) | `allowedUserIds arrayContains uid` + `audience in ['followers','mutual']` + `orderBy createdAt desc` | Needs the 3-field `(allowedUserIds, audience, createdAt)` index at `firestore.indexes.json:45-62`, which exists |
| `scripts/loadtest/quota_sim.js:237-238` | same shape | Same, 3-field index |

Facts:

- The 2-field shape (`allowedUserIds` + `createdAt`, no `audience`) existed
  only between `1a8a06d0` and `8d625bcc`, both 2026-07-23. `8d625bcc`
  ("getSharedToMe query under-constrained, causing permission-denied") added
  the `audience` filter because the rules refused the 2-field query. So even
  a phone still on a build from that window gets `permission-denied`, not
  results, from this index.
- The doc comment at `ride_share_repository.dart:279-287` explains why the
  query must carry `audience`: the rule is
  `audience in ['followers','mutual'] && uid in allowedUserIds`.
- Caveat: Firestore can sometimes serve a query by merging smaller indexes.
  The 3-field index satisfies `getSharedToMe` on its own, so removing the
  2-field one should not matter, but which index the planner picks today
  cannot be seen from the repo. [PLACEHOLDER: check index usage in the
  Firebase console (Query Insights or similar), if available on Spark.]

**Verdict: remove.**

## 3. `rides (isPrivate ASC, createdAt DESC)`

`firestore.indexes.json:207-220`.

Candidate queries: none. `isPrivate` appears nowhere in `app/lib`,
`functions/src` or `scripts/`; its only hit outside `DOCS/` is
`firestore.indexes.json:212`. The `users/{uid}/rides` queries
(`app/lib/core/cloud/cloud_repository.dart:66-69` `where('bike_id')`, and
`_sinceQuery` at `:556-562` `where('syncedAt', >)`) use other fields.

History:

- `34900552` (2026-07-12) added `.where('isPrivate', isEqualTo: false)
  .orderBy('createdAt', descending: true)`, the exact shape of this index,
  plus a `userId whereIn` + `isPrivate` + `createdAt` variant.
- `1a8a06d0` (2026-07-23) replaced `isPrivate` with `audience` everywhere in
  the app.
- So only builds from 2026-07-12 to 2026-07-23 run this query.
  `config/app.minBuild = 29` (`SECURITY.md`, step 2) blocks builds that
  contain the minBuild gate, but a build older than the gate itself never
  reads it. [PLACEHOLDER: which build first shipped the minBuild gate, and
  whether any tester still runs a build from before 2026-07-23.]

**Verdict: remove**, after the owner confirms no pre-2026-07-23 build is in
use. Even if one is, its feed already shows only rides that still carry an
`isPrivate` field.

## 4. `rides (public ASC, startTime DESC)`

`firestore.indexes.json:221-234`.

Candidate queries: none.

- No `where('public', ...)` on any collection in the current tree, and
  `git log --all -G "where\(['\"]public['\"]"` finds no commit on any branch
  that ever had one.
- `orderBy('startTime')` appears only on `groupRides`:
  `app/lib/features/social/data/repositories/group_ride_repository.dart:355`
  and `:370`. `groupRides` is a different collection id, so this index
  cannot serve them.
- `public` exists only as a value of `audience`
  (`ride_share_repository.dart:202`, `:237`).

**Verdict: remove.** Likely made by hand in the console or by a since-deleted
experiment; it never matched any code in the repo's history.

## Summary

| Index | Lines | Matching query in repo | Verdict |
|---|---|---|---|
| `liveSessions (userId, expiresAt)` | 179-192 | None; field is `uid`; no `list` grant | Remove |
| `rides (allowedUserIds, createdAt)` | 193-206 | None; live query uses the 3-field index | Remove |
| `rides (isPrivate, createdAt)` | 207-220 | None since 2026-07-23 | Remove after the old-build check |
| `rides (public, startTime)` | 221-234 | Never | Remove |

Out of scope, noticed in passing: `rides (userId ASC, startTime DESC)`
(`firestore.indexes.json:3-16`) is not one of the four, and no `rides` query
in the grepped paths orders by `startTime` either. Worth the same check
later.

## What the repo cannot show

- Queries run by hand in the Firebase console, from a laptop with the Admin
  SDK outside `scripts/`, or from BigQuery or export tooling.
- Whether all four are actually still live in the project, and in exactly
  this form. Needs `npx firebase-tools@15 firestore:indexes` output, diffed
  with the implicit `__name__` field stripped (`HANDOFF_Document.md:151`).
- Index usage statistics, if the console offers them on Spark.
- Which app builds riders still run (see §3 above).
- How the §4 TTL policy will interact with indexes once Blaze is on.
- Other branches' code (`mayabi`, `indriyo`): only `git log --all` was used,
  for the `public` check.

## Removal procedure (from §84, not done here)

1. Owner confirms the placeholders above.
2. Remove the entries from `firestore.indexes.json` and delete the same
   indexes in the console (Firestore, Indexes, Composite), in the same
   sitting. Removing from the file alone does not delete a live index:
   that is how the `liveSessions` one survived §69.O9.
3. Deploy only the index target:
   `npx firebase-tools@15 deploy --only firestore:indexes --project throttleiqfb`.
4. **Never run `firebase deploy --force`** to clear the "indexes not in your
   file" warning. A dropped index that something still uses breaks that
   query at once in production (`failed-precondition`, §82 in reverse).
5. Re-diff live against the file (strip `__name__`); both should show the
   same 16 indexes.
6. Run `scripts/check.sh` once for the file change, per `qa-gate.md`.
