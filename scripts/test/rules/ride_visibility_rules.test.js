'use strict';

/**
 * Shared-ride `followers` / `mutual` visibility against the LIVE follow graph
 * (issues §88.1).
 *
 * Before §88.1 a followers/mutual share was visible only to the uids copied
 * into `allowedUserIds` when it was shared, so someone who followed the author
 * afterwards never saw the older posts. `rideVisibleTo()` now also checks the
 * `follows/{follower}_{followee}` edge docs directly. Those exists() paths are
 * built from `resource.data.userId`, which a list query can only satisfy when
 * it pins `userId ==` one author — so what matters most here is that the
 * per-author feed query is accepted while the unpinned / whereIn shapes are
 * rejected, and that a non-follower is denied on both get and list.
 *
 * Own projectId so `node --test` running the rules files in parallel can't
 * have another file's clearFirestore() wipe this one's fixtures.
 *
 * Run with:  npm run test:rules   (from scripts/)
 */

const test = require('node:test');
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
  getDocs,
  setDoc,
  deleteDoc,
  collection,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

// ALICE is the author. BOB follows her (one-way). DAVE and ALICE follow each
// other (mutual). CAROL follows nobody but was in a legacy share-time
// allowlist. EVE has no relationship at all.
const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const CAROL = 'carol-uid';
const DAVE = 'dave-uid';
const EVE = 'eve-uid';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-visibility',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

function ride(overrides) {
  return {
    userId: ALICE,
    userName: 'Alice',
    userPhotoUrl: '',
    distanceKm: 20,
    durationSeconds: 1800,
    maxSpeedKmh: 70,
    polyline: [],
    createdAt: Timestamp.fromDate(new Date('2026-09-01T10:00:00Z')),
    audience: 'public',
    allowedUserIds: [],
    comments: 0,
    upvotes: 0,
    downvotes: 0,
    ...overrides,
  };
}

function edge(follower, followee) {
  return {
    followerUid: follower,
    followeeUid: followee,
    createdAt: Timestamp.now(),
  };
}

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // Shared BEFORE anyone below followed — allowlists are empty, exactly
    // the §88.1 situation.
    await setDoc(doc(db, 'rides', 'r-followers'), ride({ audience: 'followers' }));
    await setDoc(doc(db, 'rides', 'r-mutual'), ride({ audience: 'mutual' }));
    // A pre-§88.1 share whose snapshot allowlist named CAROL.
    await setDoc(
      doc(db, 'rides', 'r-legacy'),
      ride({ audience: 'followers', allowedUserIds: [CAROL] })
    );
    // A pre-allowlist-era doc with no allowedUserIds field at all.
    const noField = ride({ audience: 'followers' });
    delete noField.allowedUserIds;
    await setDoc(doc(db, 'rides', 'r-nofield'), noField);
    await setDoc(doc(db, 'rides', 'r-followers', 'comments', 'c1'), {
      userId: ALICE,
      text: 'hi',
    });

    await setDoc(doc(db, 'follows', `${BOB}_${ALICE}`), edge(BOB, ALICE));
    await setDoc(doc(db, 'follows', `${DAVE}_${ALICE}`), edge(DAVE, ALICE));
    await setDoc(doc(db, 'follows', `${ALICE}_${DAVE}`), edge(ALICE, DAVE));
  });
});

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

/** The per-author query RideShareRepository.getFollowedAuthorRides issues. */
function perAuthorQuery(db, author, audiences) {
  return query(
    collection(db, 'rides'),
    where('userId', '==', author),
    audiences.length === 1
      ? where('audience', '==', audiences[0])
      : where('audience', 'in', audiences),
    orderBy('createdAt', 'desc'),
    limit(10)
  );
}

// --- get -------------------------------------------------------------------

test('a follower who followed AFTER the share can get a followers ride', async () => {
  await assertSucceeds(getDoc(doc(dbFor(BOB), 'rides', 'r-followers')));
});

test('a follower can get a followers ride that has no allowedUserIds field', async () => {
  await assertSucceeds(getDoc(doc(dbFor(BOB), 'rides', 'r-nofield')));
});

test('a non-follower cannot get a followers ride', async () => {
  await assertFails(getDoc(doc(dbFor(EVE), 'rides', 'r-followers')));
});

test('a one-way follower cannot get a mutual ride', async () => {
  await assertFails(getDoc(doc(dbFor(BOB), 'rides', 'r-mutual')));
});

test('a mutual follower can get a mutual ride', async () => {
  await assertSucceeds(getDoc(doc(dbFor(DAVE), 'rides', 'r-mutual')));
});

test('only the author following back is not enough for a mutual ride', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'follows', `${ALICE}_${EVE}`), edge(ALICE, EVE));
  });
  await assertFails(getDoc(doc(dbFor(EVE), 'rides', 'r-mutual')));
});

test('the legacy allowlist still grants a get to a non-follower it names', async () => {
  await assertSucceeds(getDoc(doc(dbFor(CAROL), 'rides', 'r-legacy')));
});

test('unfollowing revokes access to a followers ride', async () => {
  await deleteDoc(doc(dbFor(BOB), 'follows', `${BOB}_${ALICE}`));
  await assertFails(getDoc(doc(dbFor(BOB), 'rides', 'r-followers')));
});

test('a follower can read comments on a followers ride; a non-follower cannot', async () => {
  const path = ['rides', 'r-followers', 'comments'];
  await assertSucceeds(getDocs(collection(dbFor(BOB), ...path)));
  await assertFails(getDocs(collection(dbFor(EVE), ...path)));
});

// --- list ------------------------------------------------------------------

test('per-author followers query succeeds for a follower', async () => {
  const snap = await assertSucceeds(getDocs(perAuthorQuery(dbFor(BOB), ALICE, ['followers'])));
  // r-followers, r-legacy, r-nofield
  if (snap.size !== 3) throw new Error(`expected 3 rides, got ${snap.size}`);
});

test('per-author followers query is denied for a non-follower', async () => {
  await assertFails(getDocs(perAuthorQuery(dbFor(EVE), ALICE, ['followers'])));
});

test('per-author followers+mutual query succeeds for a mutual follower', async () => {
  const snap = await assertSucceeds(
    getDocs(perAuthorQuery(dbFor(DAVE), ALICE, ['followers', 'mutual']))
  );
  if (snap.size !== 4) throw new Error(`expected 4 rides, got ${snap.size}`);
});

test('per-author followers+mutual query is denied for a one-way follower', async () => {
  await assertFails(getDocs(perAuthorQuery(dbFor(BOB), ALICE, ['followers', 'mutual'])));
});

test('per-author mutual query is denied for a one-way follower', async () => {
  await assertFails(getDocs(perAuthorQuery(dbFor(BOB), ALICE, ['mutual'])));
});

test('a followers query with no author pin is denied', async () => {
  await assertFails(
    getDocs(
      query(
        collection(dbFor(BOB), 'rides'),
        where('audience', '==', 'followers'),
        orderBy('createdAt', 'desc')
      )
    )
  );
});

test('a followers whereIn query naming an author the rider does not follow is denied', async () => {
  await assertFails(
    getDocs(
      query(
        collection(dbFor(BOB), 'rides'),
        where('userId', 'in', [ALICE, DAVE]),
        where('audience', '==', 'followers'),
        orderBy('createdAt', 'desc')
      )
    )
  );
});

// Probe: whether the rules engine can prove exists() per whereIn value. The
// feed does not rely on this (it pins one author per query), so this only
// records the engine's behaviour.
test('PROBE whereIn over two followed authors', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'follows', `${BOB}_${DAVE}`), edge(BOB, DAVE));
    await setDoc(doc(db, 'rides', 'r-dave'), ride({ userId: DAVE, audience: 'followers' }));
  });
  const snap = await getDocs(
    query(
      collection(dbFor(BOB), 'rides'),
      where('userId', 'in', [ALICE, DAVE]),
      where('audience', '==', 'followers'),
      orderBy('createdAt', 'desc')
    )
  ).then((s) => `ok ${s.size}`, (e) => `denied ${e.code}`);
  console.log('PROBE-RESULT', snap);
});

test('the legacy allowlist feed query still works for old clients', async () => {
  const snap = await assertSucceeds(
    getDocs(
      query(
        collection(dbFor(CAROL), 'rides'),
        where('allowedUserIds', 'array-contains', CAROL),
        where('audience', 'in', ['followers', 'mutual']),
        orderBy('createdAt', 'desc')
      )
    )
  );
  if (snap.size !== 1) throw new Error(`expected 1 ride, got ${snap.size}`);
});

test('the author can still list their own rides of every audience', async () => {
  const snap = await assertSucceeds(
    getDocs(
      query(
        collection(dbFor(ALICE), 'rides'),
        where('userId', '==', ALICE),
        orderBy('createdAt', 'desc')
      )
    )
  );
  if (snap.size !== 4) throw new Error(`expected 4 rides, got ${snap.size}`);
});
