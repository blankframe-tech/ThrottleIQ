'use strict';

/**
 * Security-rules tests for the client-maintained `stats/badges` counters
 * (Spark plan: no Cloud Functions). Every "succeeds" case is the batch the
 * app writes (app/lib/features/stats/data/badge_stats_counter.dart), so a
 * rule change that would break the real client fails here. Every "denied"
 * case is a way to move a counter without paying for it.
 *
 * Own projectId so `node --test` can run this file next to the others.
 *
 * Run with:  npm run test:rules   (from scripts/)
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  increment,
  serverTimestamp,
  Timestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-badgestats',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

/** Seeds docs with rules off. */
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

async function readStats() {
  let data;
  await seed(async (db) => {
    data = (await getDoc(doc(db, 'stats', 'badges'))).data();
  });
  return data;
}

const statsRef = (db) => doc(db, 'stats', 'badges');
const badgeRef = (db, uid, id) => doc(db, 'users', uid, 'earnedBadges', id);
const userRef = (db, uid) => doc(db, 'users', uid);

/** BadgeStatsBatches.badgeCount: mark the badge doc + owners.<id> +1. */
function countBadgeBatch(db, uid, id, { by = 1, isNew = true, statsId = id } = {}) {
  const b = writeBatch(db);
  b.set(
    badgeRef(db, uid, id),
    {
      badgeId: id,
      ...(isNew ? { earnedAt: serverTimestamp() } : {}),
      countedAt: serverTimestamp(),
    },
    { merge: true }
  );
  b.set(
    statsRef(db),
    {
      owners: { [statsId]: increment(by) },
      lastCountedBadge: statsId,
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  );
  return b;
}

/** BadgeStatsBatches.riderRegistration: flag the profile + totalRiders +1. */
function registerRiderBatch(db, uid, profileFields = {}) {
  const b = writeBatch(db);
  b.set(
    userRef(db, uid),
    { ...profileFields, badgeStatsCountedAt: serverTimestamp() },
    { merge: true }
  );
  b.set(
    statsRef(db),
    { totalRiders: increment(1), updatedAt: serverTimestamp() },
    { merge: true }
  );
  return b;
}

/** A profile as ProfileRepository.ensureProfile seeds it (no email). */
const PROFILE = {
  displayName: 'Alice',
  visibility: 'public',
  followerCount: 0,
  followingCount: 0,
};

// ---------------------------------------------------------------------------
// Reads
// ---------------------------------------------------------------------------

test('signed-in riders can read stats/badges; signed-out cannot', async () => {
  await seed((db) => setDoc(statsRef(db), { totalRiders: 3, owners: {} }));
  await assertSucceeds(getDoc(statsRef(dbFor(ALICE))));
  await assertFails(
    getDoc(statsRef(testEnv.unauthenticatedContext().firestore()))
  );
});

// ---------------------------------------------------------------------------
// Owners: a newly earned badge
// ---------------------------------------------------------------------------

test('a new catalog badge: create earnedBadges + owners +1 in one batch', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(countBadgeBatch(db, ALICE, 'km_100').commit());
  await assertSucceeds(countBadgeBatch(db, ALICE, 'first_ride').commit());
  const stats = await readStats();
  assert.equal(stats.owners.km_100, 1);
  assert.equal(stats.owners.first_ride, 1);
  // Bob's award stacks on Alice's.
  await assertSucceeds(countBadgeBatch(dbFor(BOB), BOB, 'km_100').commit());
  assert.equal((await readStats()).owners.km_100, 2);
});

test('owners +2 is rejected', async () => {
  const db = dbFor(ALICE);
  await assertFails(countBadgeBatch(db, ALICE, 'km_100', { by: 2 }).commit());
  await seed((db) =>
    setDoc(statsRef(db), { totalRiders: 5, owners: { km_100: 3 } })
  );
  await assertFails(countBadgeBatch(db, ALICE, 'km_100', { by: 2 }).commit());
});

test('owners +1 without the earnedBadges doc is rejected', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      statsRef(db),
      {
        owners: { km_100: increment(1) },
        lastCountedBadge: 'km_100',
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
  );
});

test("owners +1 riding on someone else's badge doc is rejected", async () => {
  // The bump checks the CALLER's earnedBadges doc, and Bob can't write
  // Alice's subcollection, so there's no doc he can pay with.
  await assertFails(countBadgeBatch(dbFor(BOB), ALICE, 'km_100').commit());
});

test('re-saving an already counted badge is rejected (no second +1)', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(countBadgeBatch(db, ALICE, 'km_100').commit());
  await assertFails(countBadgeBatch(db, ALICE, 'km_100').commit());
  await assertFails(
    countBadgeBatch(db, ALICE, 'km_100', { isNew: false }).commit()
  );
  assert.equal((await readStats()).owners.km_100, 1);
  // A plain re-sync that leaves countedAt alone is fine.
  await assertSucceeds(
    setDoc(
      badgeRef(db, ALICE, 'km_100'),
      { badgeId: 'km_100', earnedAt: serverTimestamp() },
      { merge: true }
    )
  );
});

test('a non-catalog id cannot be counted', async () => {
  const db = dbFor(ALICE);
  await assertFails(countBadgeBatch(db, ALICE, 'made_up_badge').commit());
  // Challenge badges may still be stored, just never counted.
  await assertSucceeds(
    setDoc(badgeRef(db, ALICE, 'monthly_500km'), {
      badgeId: 'monthly_500km',
      challengeId: 'c1',
      earnedAt: serverTimestamp(),
    })
  );
});

test('lastCountedBadge must name the key that moved', async () => {
  const db = dbFor(ALICE);
  // Pays with km_100's doc but bumps km_5000.
  const b = writeBatch(db);
  b.set(badgeRef(db, ALICE, 'km_100'), {
    badgeId: 'km_100',
    countedAt: serverTimestamp(),
  });
  b.set(
    statsRef(db),
    {
      owners: { km_5000: increment(1) },
      lastCountedBadge: 'km_100',
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  );
  await assertFails(b.commit());
});

test('two owners keys in one write are rejected', async () => {
  const db = dbFor(ALICE);
  const b = writeBatch(db);
  b.set(badgeRef(db, ALICE, 'km_100'), {
    badgeId: 'km_100',
    countedAt: serverTimestamp(),
  });
  b.set(
    statsRef(db),
    {
      owners: { km_100: increment(1), km_5000: increment(1) },
      lastCountedBadge: 'km_100',
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  );
  await assertFails(b.commit());
});

test('updatedAt must be the server time', async () => {
  const db = dbFor(ALICE);
  const b = writeBatch(db);
  b.set(badgeRef(db, ALICE, 'km_100'), {
    badgeId: 'km_100',
    countedAt: serverTimestamp(),
  });
  b.set(
    statsRef(db),
    {
      owners: { km_100: increment(1) },
      lastCountedBadge: 'km_100',
      updatedAt: Timestamp.fromMillis(0),
    },
    { merge: true }
  );
  await assertFails(b.commit());
});

// ---------------------------------------------------------------------------
// The earnedBadges side of the pairing
// ---------------------------------------------------------------------------

test('countedAt cannot be set without the matching owners +1', async () => {
  await assertFails(
    setDoc(badgeRef(dbFor(ALICE), ALICE, 'km_100'), {
      badgeId: 'km_100',
      countedAt: serverTimestamp(),
    })
  );
});

test('countedAt cannot be removed, and a counted badge cannot be deleted', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(countBadgeBatch(db, ALICE, 'km_100').commit());
  // Plain overwrite drops countedAt.
  await assertFails(
    setDoc(badgeRef(db, ALICE, 'km_100'), { badgeId: 'km_100' })
  );
  await assertFails(deleteDoc(badgeRef(db, ALICE, 'km_100')));
});

test('earnedBadges stays owner-only', async () => {
  await seed((db) =>
    setDoc(badgeRef(db, ALICE, 'km_100'), { badgeId: 'km_100' })
  );
  await assertSucceeds(getDoc(badgeRef(dbFor(ALICE), ALICE, 'km_100')));
  await assertFails(getDoc(badgeRef(dbFor(BOB), ALICE, 'km_100')));
  await assertFails(
    setDoc(badgeRef(dbFor(BOB), ALICE, 'km_500'), { badgeId: 'km_500' })
  );
});

test('badgeId field must match the doc id', async () => {
  await assertFails(
    setDoc(badgeRef(dbFor(ALICE), ALICE, 'km_100'), { badgeId: 'km_5000' })
  );
});

// ---------------------------------------------------------------------------
// totalRiders: sign-up and self-registration
// ---------------------------------------------------------------------------

test('sign-up: profile create + totalRiders +1 in one batch', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(
    registerRiderBatch(db, ALICE, {
      ...PROFILE,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }).commit()
  );
  assert.equal((await readStats()).totalRiders, 1);
});

test('backfill: an existing, uncounted rider registers exactly once', async () => {
  await seed(async (db) => {
    await setDoc(userRef(db, ALICE), PROFILE);
    await setDoc(statsRef(db), { totalRiders: 7, owners: { km_100: 2 } });
  });
  const db = dbFor(ALICE);
  await assertSucceeds(registerRiderBatch(db, ALICE).commit());
  assert.equal((await readStats()).totalRiders, 8);
  // Double self-registration.
  await assertFails(registerRiderBatch(db, ALICE).commit());
  assert.equal((await readStats()).totalRiders, 8);
});

test('backfill: a legacy uncounted badge doc is counted exactly once', async () => {
  await seed((db) =>
    setDoc(badgeRef(db, ALICE, 'night_1'), {
      badgeId: 'night_1',
      earnedAt: Timestamp.now(),
    })
  );
  const db = dbFor(ALICE);
  await assertSucceeds(
    countBadgeBatch(db, ALICE, 'night_1', { isNew: false }).commit()
  );
  await assertFails(
    countBadgeBatch(db, ALICE, 'night_1', { isNew: false }).commit()
  );
  assert.equal((await readStats()).owners.night_1, 1);
});

test('totalRiders +1 without the profile flag is rejected', async () => {
  await seed((db) => setDoc(userRef(db, ALICE), PROFILE));
  await assertFails(
    setDoc(
      statsRef(dbFor(ALICE)),
      { totalRiders: increment(1), updatedAt: serverTimestamp() },
      { merge: true }
    )
  );
});

test('totalRiders +2 is rejected', async () => {
  const db = dbFor(ALICE);
  const b = writeBatch(db);
  b.set(userRef(db, ALICE), { ...PROFILE, badgeStatsCountedAt: serverTimestamp() });
  b.set(
    statsRef(db),
    { totalRiders: increment(2), updatedAt: serverTimestamp() },
    { merge: true }
  );
  await assertFails(b.commit());
});

test('rider and badge counts cannot move in the same write', async () => {
  const db = dbFor(ALICE);
  const b = writeBatch(db);
  b.set(userRef(db, ALICE), { ...PROFILE, badgeStatsCountedAt: serverTimestamp() });
  b.set(badgeRef(db, ALICE, 'km_100'), {
    badgeId: 'km_100',
    countedAt: serverTimestamp(),
  });
  b.set(
    statsRef(db),
    {
      totalRiders: increment(1),
      owners: { km_100: increment(1) },
      lastCountedBadge: 'km_100',
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  );
  await assertFails(b.commit());
});

test('the profile flag is one-way and pins the profile doc', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(registerRiderBatch(db, ALICE, PROFILE).commit());
  // Removing the flag by overwrite.
  await assertFails(setDoc(userRef(db, ALICE), PROFILE));
  // Re-stamping it.
  await assertFails(
    updateDoc(userRef(db, ALICE), { badgeStatsCountedAt: serverTimestamp() })
  );
  // Delete-and-recreate to count again.
  await assertFails(deleteDoc(userRef(db, ALICE)));
  // Unrelated profile edits still work.
  await assertSucceeds(
    setDoc(userRef(db, ALICE), { nickname: 'Al' }, { merge: true })
  );
});

test('the profile flag cannot be set without the totalRiders +1', async () => {
  await assertFails(
    setDoc(userRef(dbFor(ALICE), ALICE), {
      ...PROFILE,
      badgeStatsCountedAt: serverTimestamp(),
    })
  );
});

test('an uncounted profile can still be deleted by its owner', async () => {
  await seed((db) => setDoc(userRef(db, ALICE), PROFILE));
  await assertSucceeds(deleteDoc(userRef(dbFor(ALICE), ALICE)));
});

// ---------------------------------------------------------------------------
// Everything else on stats/badges
// ---------------------------------------------------------------------------

test('clients cannot delete or overwrite stats/badges', async () => {
  await seed((db) =>
    setDoc(statsRef(db), { totalRiders: 40, owners: { km_100: 10 } })
  );
  const db = dbFor(ALICE);
  await assertFails(deleteDoc(statsRef(db)));
  await assertFails(
    setDoc(statsRef(db), {
      totalRiders: 1,
      owners: {},
      updatedAt: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(
      statsRef(db),
      { recomputedAt: serverTimestamp(), updatedAt: serverTimestamp() },
      { merge: true }
    )
  );
  await assertFails(
    setDoc(doc(db, 'stats', 'other'), { totalRiders: 1 })
  );
});
