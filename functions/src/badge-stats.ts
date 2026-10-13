/**
 * BLAZE-PLAN ALTERNATIVE, NOT DEPLOYED. index.ts does not export this
 * module. On the Spark plan the app maintains `stats/badges` itself
 * (app/lib/features/stats/data/badge_stats_counter.dart), and
 * firestore.rules only accepts paired +1 writes for it. To switch to this
 * module after moving to Blaze: export it from index.ts, stop the client
 * counters (or the triggers below will count every badge a second time),
 * and run recomputeBadgeStatsDaily once by hand. Note the recount writes
 * no `lastCountedBadge`/markers, and the app no longer gates on
 * `recomputedAt`; it hides the figure below a minimum rider count instead.
 *
 * Aggregate badge ownership for the app's "X% of riders own this badge"
 * figure and the rarity tier derived from it.
 *
 * One doc, `stats/badges`:
 *
 *   {
 *     totalRiders: number,              // count of users/{uid} docs
 *     owners: { [badgeId]: number },    // riders with earnedBadges/{badgeId}
 *     updatedAt: Timestamp,             // last write of any kind
 *     recomputedAt: Timestamp,          // last full recount (scheduled)
 *   }
 *
 * Signed-in clients may read it; nobody but this code may write it
 * (firestore.rules, `match /stats/{docId}`).
 *
 * Kept current two ways:
 *  - Incrementally: create/delete triggers on `users/{uid}` and on
 *    `users/{uid}/earnedBadges/{badgeId}` bump the counts. Only create and
 *    delete fire, not update: the app's `earnMilestoneBadge` uses a plain
 *    `set`, so a re-sync of an existing badge is an update and must not
 *    count twice.
 *  - Daily full recount: Firestore triggers are at-least-once, so a retried
 *    event can double-count, and anything earned before this function was
 *    deployed was never counted at all. The recount overwrites the doc from
 *    the source collections, which corrects both. Run it once by hand after
 *    the first deploy (Cloud Scheduler → "Force run") to backfill. The app
 *    ignores the doc until `recomputedAt` exists, since increments alone
 *    (totalRiders counted from deploy, owners from every re-sync) give
 *    meaningless ratios.
 */

import {
  onDocumentCreated,
  onDocumentDeleted,
} from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';
import { getApps, initializeApp } from 'firebase-admin/app';
import {
  FieldPath,
  FieldValue,
  Firestore,
  QueryDocumentSnapshot,
  getFirestore,
} from 'firebase-admin/firestore';
import { isCountedBadgeId, tallyBadgeOwners } from './badge-catalog';

/** Lazily resolved, for the same module-order reason as ride-identity.ts. */
function firestore(): Firestore {
  if (getApps().length === 0) initializeApp();
  return getFirestore();
}

function statsDoc() {
  return firestore().collection('stats').doc('badges');
}

async function bumpRiders(delta: 1 | -1): Promise<void> {
  await statsDoc().set(
    {
      totalRiders: FieldValue.increment(delta),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function bumpOwners(badgeId: string, delta: 1 | -1): Promise<void> {
  // A nested map inside a merge set, rather than an `owners.<id>` field
  // path in update(): update() fails when the doc doesn't exist yet, and
  // the very first award may well precede the first recount.
  await statsDoc().set(
    {
      owners: { [badgeId]: FieldValue.increment(delta) },
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

export const onRiderCreatedCountBadgeStats = onDocumentCreated(
  'users/{uid}',
  async () => {
    await bumpRiders(1);
  }
);

export const onRiderDeletedCountBadgeStats = onDocumentDeleted(
  'users/{uid}',
  async () => {
    await bumpRiders(-1);
  }
);

export const onBadgeEarnedCountBadgeStats = onDocumentCreated(
  'users/{uid}/earnedBadges/{badgeId}',
  async (event) => {
    const { badgeId } = event.params;
    if (!isCountedBadgeId(badgeId)) return;
    await bumpOwners(badgeId, 1);
  }
);

export const onBadgeRemovedCountBadgeStats = onDocumentDeleted(
  'users/{uid}/earnedBadges/{badgeId}',
  async (event) => {
    const { badgeId } = event.params;
    if (!isCountedBadgeId(badgeId)) return;
    await bumpOwners(badgeId, -1);
  }
);

/** Page size for the earnedBadges scan. Each doc is read with no fields. */
const SCAN_PAGE = 2000;

/**
 * Every earnedBadges doc id under a `users/{uid}` parent, paged so the scan
 * never holds more than one page of snapshots at a time.
 */
async function* earnedBadgeIds(db: Firestore): AsyncGenerator<string> {
  let last: QueryDocumentSnapshot | undefined;
  for (;;) {
    let query = db
      .collectionGroup('earnedBadges')
      .orderBy(FieldPath.documentId())
      .select()
      .limit(SCAN_PAGE);
    if (last) query = query.startAfter(last);
    const page = await query.get();
    for (const doc of page.docs) {
      // Only the users/{uid}/earnedBadges shape counts; a same-named
      // collection anywhere else is not a rider's badge.
      if (doc.ref.parent.parent?.parent.id === 'users') yield doc.id;
    }
    if (page.size < SCAN_PAGE) return;
    last = page.docs[page.docs.length - 1];
  }
}

/** Full recount; overwrites `stats/badges`. Exported for the emulator. */
export async function recomputeBadgeStats(db: Firestore): Promise<void> {
  const ridersAgg = await db.collection('users').count().get();
  const ids: string[] = [];
  for await (const id of earnedBadgeIds(db)) ids.push(id);
  const owners = tallyBadgeOwners(ids);

  await db
    .collection('stats')
    .doc('badges')
    .set({
      totalRiders: ridersAgg.data().count,
      owners,
      updatedAt: FieldValue.serverTimestamp(),
      recomputedAt: FieldValue.serverTimestamp(),
    });
  logger.info('badge stats recomputed', {
    totalRiders: ridersAgg.data().count,
    earnedBadgeDocs: ids.length,
  });
}

export const recomputeBadgeStatsDaily = onSchedule(
  'every 24 hours',
  async () => {
    await recomputeBadgeStats(firestore());
  }
);
