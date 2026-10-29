'use strict';

/**
 * Access matrix, 2026-10-27 emulator round (judge.md): for each collection,
 * signed out vs owner vs another rider vs admin, plus the named risks:
 * email harvesting (profiles, follow graph), block gaps, and the Google
 * Maps-seeded places (`createdBy: 'system:gmaps-seed-dhaka'`).
 * Tests marked "KNOWN GAP" pin behaviour the rules can't close (see the
 * test), so a change to it shows up here. Own projectId, like the others.
 *
 * Run with:  npm run test:rules   (from scripts/)
 */

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc, collection, query, where, limit, getDoc, getDocs, setDoc, updateDoc,
  deleteDoc, writeBatch, runTransaction, getCountFromServer, Timestamp, increment,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const CAROL = 'carol-uid';
const DAVE = 'dave-uid';
const SEED_AUTHOR = 'system:gmaps-seed-dhaka';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-rules-matrix',
    firestore: { rules: RULES }, // host: FIRESTORE_EMULATOR_HOST (emulators:exec)
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

const db = (uid, claims) => testEnv.authenticatedContext(uid, claims).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

async function seed(docs) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    for (const [p, data] of Object.entries(docs)) await setDoc(doc(f, p), data);
  });
}

// ── Signed out ──────────────────────────────────────────────────────────────

test('signed out: every collection is closed except the four public lookups', async () => {
  await seed({
    [`users/${BOB}`]: { visibility: 'public', displayName: 'Bob' },
    [`users/${BOB}/rides/r1`]: { distanceKm: 1 },
    [`users/${BOB}/bikes/b1`]: { name: 'FZ' },
    'places/p1': { name: 'Fuel', createdBy: SEED_AUTHOR },
    'reviews/r1': { placeId: 'p1', userId: BOB, stars: 4 },
    'forums/f1': { followerCount: 0, postCount: 0 },
    'forums/f1/posts/p1': { userId: BOB, title: 't' },
    [`follows/${ALICE}_${BOB}`]: { followerUid: ALICE, followeeUid: BOB },
    'rides/s1': { userId: BOB, audience: 'public', distanceKm: 1, durationSeconds: 60, maxSpeedKmh: 60 },
    'emailLookup/h1': { uid: BOB },
    'stats/badges': { totalRiders: 1 },
    'groupRides/g1': { creatorId: BOB, memberIds: [BOB], status: 'active' },
    'usernames/bob': { uid: BOB },
    'handleLinks/k1': { uid: BOB, active: false },
    'config/app': { minBuild: 29 },
    'liveSessions/t1': { uid: BOB, shareable: true, expiresAt: Timestamp.fromMillis(Date.now() + 3600e3) },
  });
  const a = anon();
  for (const p of [`users/${BOB}`, `users/${BOB}/rides/r1`, `users/${BOB}/bikes/b1`,
    'places/p1', 'reviews/r1', 'forums/f1', 'forums/f1/posts/p1',
    `follows/${ALICE}_${BOB}`, 'rides/s1', 'emailLookup/h1', 'stats/badges',
    'groupRides/g1', 'anything/else']) {
    await assertFails(getDoc(doc(a, p)));
  }
  for (const c of ['users', 'places', 'follows', 'rides', 'usernames', 'handleLinks', 'liveSessions']) {
    await assertFails(getDocs(collection(a, c)));
  }
  await assertSucceeds(getDoc(doc(a, 'usernames/bob')));
  await assertSucceeds(getDoc(doc(a, 'handleLinks/k1')));
  await assertSucceeds(getDoc(doc(a, 'config/app')));
  await assertSucceeds(getDoc(doc(a, 'liveSessions/t1')));
});

test('signed out: no write lands anywhere', async () => {
  const a = anon();
  await assertFails(setDoc(doc(a, `users/${BOB}`), { displayName: 'x' }));
  await assertFails(setDoc(doc(a, 'places/p1'), { name: 'x', createdBy: SEED_AUTHOR }));
  await assertFails(setDoc(doc(a, `follows/x_${BOB}`), { followerUid: 'x', followeeUid: BOB }));
  await assertFails(setDoc(doc(a, 'reports/r1'), { reporterId: 'x', status: 'pending' }));
  await assertFails(setDoc(doc(a, 'usernames/abc'), { uid: 'x' }));
  await assertFails(setDoc(doc(a, 'config/app'), { minBuild: 0 }));
  await assertFails(setDoc(doc(a, 'crashNotifications/r1'), { uid: 'x', rideId: 'r1', status: 'pending' }));
});

// ── Owner vs another rider ──────────────────────────────────────────────────

const OWNER_ONLY = ['rides/r1', 'rides/r1/track/c1', 'rides/r1/jamLabels/l1',
  'maintenance/m1', 'emergencyContacts/e1', 'private/account', 'falseCrashPositives/x1'];

test('owner-only subcollections: the owner reads and writes, another rider does neither', async () => {
  const docs = {};
  for (const p of OWNER_ONLY) docs[`users/${BOB}/${p}`] = { v: 1 };
  await seed(docs);
  for (const p of OWNER_ONLY) {
    const ref = `users/${BOB}/${p}`;
    await assertSucceeds(getDoc(doc(db(BOB), ref)));
    await assertSucceeds(setDoc(doc(db(BOB), ref), { v: 2 }));
    await assertFails(getDoc(doc(db(ALICE), ref)));
    await assertFails(setDoc(doc(db(ALICE), ref), { v: 3 }));
    await assertFails(deleteDoc(doc(db(ALICE), ref)));
  }
});

test('read-only-to-owner subcollections stay closed to another rider', async () => {
  await seed({
    [`users/${BOB}/impactEvents/i1`]: { schema: 1 },
    [`users/${BOB}/cloudinaryAssets/a1`]: { publicId: `avatars/${BOB}/x` },
    [`users/${BOB}/earnedBadges/first_ride`]: { badgeId: 'first_ride' },
    [`users/${BOB}/notifications/n1`]: { fromUid: CAROL, type: 'follow' },
    [`users/${BOB}/blocks/${CAROL}`]: { blockedAt: 1 },
  });
  for (const p of ['impactEvents/i1', 'cloudinaryAssets/a1', 'earnedBadges/first_ride', 'notifications/n1']) {
    await assertSucceeds(getDoc(doc(db(BOB), `users/${BOB}/${p}`)));
    await assertFails(getDoc(doc(db(ALICE), `users/${BOB}/${p}`)));
  }
  // Nobody but the owner lists a block list, not even the blocked rider.
  await assertSucceeds(getDocs(collection(db(BOB), `users/${BOB}/blocks`)));
  await assertFails(getDocs(collection(db(ALICE), `users/${BOB}/blocks`)));
  await assertFails(getDocs(collection(db(CAROL), `users/${BOB}/blocks`)));
  // A rider can't write a block into someone else's list.
  await assertFails(setDoc(doc(db(ALICE), `users/${BOB}/blocks/${CAROL}`), { blockedAt: 1 }));
});

test('a profile is written only by its owner', async () => {
  await seed({ [`users/${BOB}`]: { visibility: 'public', displayName: 'Bob' } });
  await assertSucceeds(updateDoc(doc(db(BOB), `users/${BOB}`), { displayName: 'Bobby' }));
  await assertFails(updateDoc(doc(db(ALICE), `users/${BOB}`), { displayName: 'pwned' }));
  await assertFails(deleteDoc(doc(db(ALICE), `users/${BOB}`)));
});

// ── Email harvesting ────────────────────────────────────────────────────────

test('email: the owner-only account doc is closed to everyone else', async () => {
  await seed({ [`users/${BOB}/private/account`]: { email: 'bob@example.com', emailLower: 'bob@example.com' } });
  await assertFails(getDoc(doc(db(ALICE), `users/${BOB}/private/account`)));
  await assertFails(getDocs(collection(db(ALICE), `users/${BOB}/private`)));
});

test('email: rider search lists only public profiles, 20 at a time', async () => {
  await seed({
    [`users/${BOB}`]: { visibility: 'public' },
    [`users/${CAROL}`]: { visibility: 'private' },
  });
  const users = collection(db(ALICE), 'users');
  await assertSucceeds(getDocs(query(users, where('visibility', '==', 'public'), limit(20))));
  await assertFails(getDocs(query(users, where('visibility', '==', 'public'), limit(21))));
  await assertFails(getDocs(query(users, where('visibility', '==', 'private'), limit(20))));
  await assertFails(getDocs(query(users, limit(20))));
  await assertFails(getDoc(doc(db(ALICE), `users/${CAROL}`)));
});

async function seedGraph() {
  // Bob public, Carol and Dave private. Edges: alice->bob, carol->bob,
  // bob->carol, dave->carol.
  await seed({
    [`users/${DAVE}`]: { visibility: 'private' },
    [`follows/${DAVE}_${CAROL}`]: { followerUid: DAVE, followeeUid: CAROL },
    [`users/${ALICE}`]: { visibility: 'public' },
    [`users/${BOB}`]: { visibility: 'public' },
    [`users/${CAROL}`]: { visibility: 'private' },
    [`follows/${ALICE}_${BOB}`]: { followerUid: ALICE, followeeUid: BOB },
    [`follows/${CAROL}_${BOB}`]: { followerUid: CAROL, followeeUid: BOB },
    [`follows/${BOB}_${CAROL}`]: { followerUid: BOB, followeeUid: CAROL },
  });
}

test('follow graph: an unfiltered list (bulk harvest of every uid and edge) is denied', async () => {
  await seedGraph();
  await assertFails(getDocs(collection(db(ALICE), 'follows')));
  await assertFails(getDocs(query(collection(db(ALICE), 'follows'), limit(20))));
});

test('follow graph: a public rider\'s followers and following stay readable (profile screen counts)', async () => {
  await seedGraph();
  const f = collection(db(ALICE), 'follows');
  await assertSucceeds(getDocs(query(f, where('followeeUid', '==', BOB))));
  await assertSucceeds(getDocs(query(f, where('followerUid', '==', BOB))));
  await assertSucceeds(getCountFromServer(query(f, where('followeeUid', '==', BOB))));
  // FollowRepository.getFollowersAmong: followee pinned to me, whereIn on followers.
  await assertSucceeds(getDocs(query(collection(db(BOB), 'follows'),
    where('followeeUid', '==', BOB), where('followerUid', 'in', [ALICE, CAROL]))));
});

test('follow graph: a private rider\'s lists are closed to strangers, open to them', async () => {
  await seedGraph();
  const f = collection(db(ALICE), 'follows');
  await assertFails(getDocs(query(f, where('followerUid', '==', CAROL))));
  await assertFails(getDocs(query(f, where('followeeUid', '==', CAROL))));
  await assertFails(getCountFromServer(query(f, where('followeeUid', '==', CAROL))));
  // An edge between two private riders; one with a public end is part of
  // that rider's public lists.
  await assertFails(getDoc(doc(db(ALICE), `follows/${DAVE}_${CAROL}`)));
  await assertSucceeds(getDoc(doc(db(ALICE), `follows/${BOB}_${CAROL}`)));
  const mine = collection(db(CAROL), 'follows');
  await assertSucceeds(getDocs(query(mine, where('followerUid', '==', CAROL))));
  await assertSucceeds(getDocs(query(mine, where('followeeUid', '==', CAROL))));
  // Either end can read the edge itself.
  await assertSucceeds(getDoc(doc(db(DAVE), `follows/${DAVE}_${CAROL}`)));
});

test('follow graph: your own missing edge reads as empty, two strangers\' missing edge is not an oracle', async () => {
  await seedGraph();
  const snap = await assertSucceeds(getDoc(doc(db(ALICE), `follows/${ALICE}_${CAROL}`)));
  assert(!snap.exists());
  // Missing (carol_x) and existing private edges are both denied to a third party.
  await assertFails(getDoc(doc(db(ALICE), `follows/${CAROL}_nobody`)));
  await assertFails(getDoc(doc(db(ALICE), `follows/${DAVE}_${CAROL}`)));
});

test('follow graph: blockUser\'s transaction (get both edges, block, drop both) still works', async () => {
  await seedGraph();
  const d = db(BOB);
  await assertSucceeds(runTransaction(d, async (txn) => {
    const theirs = await txn.get(doc(d, `follows/${CAROL}_${BOB}`));
    const mine = await txn.get(doc(d, `follows/${BOB}_${CAROL}`));
    txn.set(doc(d, `users/${BOB}/blocks/${CAROL}`), { blockedAt: 1 });
    if (theirs.exists()) txn.delete(theirs.ref);
    if (mine.exists()) txn.delete(mine.ref);
  }));
});

// ── Block gaps ──────────────────────────────────────────────────────────────

test('block: a legacy block that left both edges hides a mutual profile', async () => {
  await seed({
    [`users/${BOB}`]: { visibility: 'mutual' },
    [`follows/${ALICE}_${BOB}`]: { followerUid: ALICE, followeeUid: BOB },
    [`follows/${BOB}_${ALICE}`]: { followerUid: BOB, followeeUid: ALICE },
    [`follows/${CAROL}_${BOB}`]: { followerUid: CAROL, followeeUid: BOB },
    [`follows/${BOB}_${CAROL}`]: { followerUid: BOB, followeeUid: CAROL },
    [`users/${BOB}/blocks/${ALICE}`]: { blockedAt: 1 },
  });
  await assertFails(getDoc(doc(db(ALICE), `users/${BOB}`)));
  await assertSucceeds(getDoc(doc(db(CAROL), `users/${BOB}`)));
});

test('block: a legacy block that left the edge hides a followers-only garage', async () => {
  await seed({
    [`users/${BOB}`]: { visibility: 'public', bikesVisibility: 'followers' },
    [`users/${BOB}/bikes/b1`]: { name: 'FZ' },
    [`follows/${ALICE}_${BOB}`]: { followerUid: ALICE, followeeUid: BOB },
    [`follows/${CAROL}_${BOB}`]: { followerUid: CAROL, followeeUid: BOB },
    [`users/${BOB}/blocks/${ALICE}`]: { blockedAt: 1 },
  });
  await assertFails(getDocs(collection(db(ALICE), `users/${BOB}/bikes`)));
  await assertSucceeds(getDocs(collection(db(CAROL), `users/${BOB}/bikes`)));
});

test('KNOWN GAP (§83.18): a blocked rider still reads the blocker\'s public ride and public profile', async () => {
  // A block check on the public branch would make the public feed query
  // unprovable (see rideVisibleTo); the app filters these on the device.
  await seed({
    [`users/${BOB}`]: { visibility: 'public' },
    [`users/${BOB}/blocks/${ALICE}`]: { blockedAt: 1 },
    'rides/s1': { userId: BOB, audience: 'public', distanceKm: 1, durationSeconds: 60, maxSpeedKmh: 60 },
  });
  await assertSucceeds(getDoc(doc(db(ALICE), 'rides/s1')));
  await assertSucceeds(getDoc(doc(db(ALICE), `users/${BOB}`)));
});

// ── Google Maps-seeded places ───────────────────────────────────────────────

const SEEDED = {
  name: 'Padma Filling Station', category: 'fuel', latitude: 23.8, longitude: 90.4,
  geohash: 'wh0r1234', address: 'Road 1', phone: '+880100', hours: '24h',
  photoUrls: [], verified: false, createdBy: SEED_AUTHOR, ratingSum: 0, ratingCount: 0,
  googleRating: 0, googleRatingCount: 0, googlePlaceId: 'ChIJ_seed',
};

function riderPlace(overrides) {
  return {
    name: 'Central Moto Works', category: 'garage', latitude: 23.8, longitude: 90.36,
    geohash: 'wh0r1234', address: '', phone: null, hours: null, photoUrls: [],
    verified: false, createdBy: ALICE, createdAt: Timestamp.now(), ratingSum: 0,
    ratingCount: 0, googleRating: 0, googleRatingCount: 0, osmId: null,
    ...overrides,
  };
}

test('seeded places: any rider reads them; none can edit, verify, re-tag or delete one', async () => {
  await seed({ 'places/seed1': SEEDED });
  const d = db(ALICE);
  await assertSucceeds(getDoc(doc(d, 'places/seed1')));
  await assertFails(updateDoc(doc(d, 'places/seed1'), { name: 'Mine now' }));
  await assertFails(updateDoc(doc(d, 'places/seed1'), { verified: true }));
  await assertFails(updateDoc(doc(d, 'places/seed1'), { createdBy: ALICE }));
  await assertFails(updateDoc(doc(d, 'places/seed1'), { phone: '+880999' }));
  await assertFails(deleteDoc(doc(d, 'places/seed1')));
  // An admin client can't either: places are changed only by the Admin SDK scripts.
  await assertFails(updateDoc(doc(db('admin-uid', { admin: true }), 'places/seed1'), { verified: true }));
});

test('seeded places: a rider can\'t forge the import\'s tag or its googlePlaceId marker', async () => {
  const d = db(ALICE);
  await assertFails(setDoc(doc(d, 'places/fake1'), riderPlace({ createdBy: SEED_AUTHOR })));
  // revert_google_places.js treats any non-seeded place with googlePlaceId as
  // "enriched by the import" and would rewrite it.
  await assertFails(setDoc(doc(d, 'places/fake2'), riderPlace({ googlePlaceId: 'ChIJ_seed' })));
  await assertSucceeds(setDoc(doc(d, 'places/ok'), riderPlace({})));
});

test('places: no self-awarded Google rating, no off-host or someone else\'s photo, no oversize text', async () => {
  const d = db(ALICE);
  const own = `https://res.cloudinary.com/vjvcigkt/image/upload/v1/places/${ALICE}/a.jpg`;
  await assertFails(setDoc(doc(d, 'places/x1'), riderPlace({ googleRating: 4.9, googleRatingCount: 1200 })));
  await assertFails(setDoc(doc(d, 'places/x2'), riderPlace({ photoUrls: ['https://evil.example/pixel.gif'] })));
  await assertFails(setDoc(doc(d, 'places/x3'), riderPlace({
    photoUrls: [`https://res.cloudinary.com/vjvcigkt/image/upload/v1/places/${BOB}/b.jpg`] })));
  await assertFails(setDoc(doc(d, 'places/x4'), riderPlace({ photoUrls: [own, own] })));
  await assertFails(setDoc(doc(d, 'places/x5'), riderPlace({ name: 'x'.repeat(201) })));
  await assertFails(setDoc(doc(d, 'places/x6'), riderPlace({ address: 'x'.repeat(1001) })));
  await assertFails(setDoc(doc(d, 'places/x7'), riderPlace({ extra: 'payload' })));
  await assertSucceeds(setDoc(doc(d, 'places/ok1'), riderPlace({ photoUrls: [own] })));
  await assertSucceeds(setDoc(doc(d, 'places/ok2'), riderPlace({ phone: '+8801711', hours: 'Sa-Th 09:00-21:00' })));
  // An OSM import (PlaceRepository.addPlacesBatched) carries an osmId and tags.
  await assertSucceeds(setDoc(doc(d, 'places/osm_node_1'), riderPlace({ osmId: 'node/1', tags: ['open24h'] })));
});

function review(overrides) {
  return { placeId: 'seed1', userId: ALICE, stars: 4, text: 'Good', imageUrls: [],
    createdAt: Timestamp.now(), flagged: false, ...overrides };
}

test('seeded places: a rider reviews one once, with the rating bump in the same commit', async () => {
  await seed({ 'places/seed1': SEEDED });
  const d = db(ALICE);
  const b = writeBatch(d);
  b.set(doc(d, `reviews/${ALICE}_seed1`), review({}));
  b.update(doc(d, 'places/seed1'), { ratingSum: 4, ratingCount: 1 });
  await assertSucceeds(b.commit());
  const again = writeBatch(d);
  again.set(doc(d, `reviews/${ALICE}_seed1`), review({ stars: 5 }));
  again.update(doc(d, 'places/seed1'), { ratingSum: 9, ratingCount: 2 });
  await assertFails(again.commit());
});

test('reviews: own id and uid only, whole stars, capped text, no extra keys or image URLs', async () => {
  const d = db(ALICE);
  await assertFails(setDoc(doc(d, `reviews/${BOB}_seed1`), review({ userId: BOB })));
  await assertFails(setDoc(doc(d, `reviews/${ALICE}_seed1`), review({ stars: 4.5 })));
  await assertFails(setDoc(doc(d, `reviews/${ALICE}_seed1`), review({ stars: 6 })));
  await assertFails(setDoc(doc(d, `reviews/${ALICE}_seed1`), review({ text: 'x'.repeat(5001) })));
  await assertFails(setDoc(doc(d, `reviews/${ALICE}_seed1`), review({ imageUrls: ['https://evil.example/p.gif'] })));
  await assertFails(setDoc(doc(d, `reviews/${ALICE}_seed1`), review({ flagged: true })));
  await assertFails(setDoc(doc(d, `reviews/${ALICE}_seed1`), review({ extra: 1 })));
  await assertSucceeds(setDoc(doc(d, `reviews/${ALICE}_seed1`), review({})));
});

// ── Admin paths ─────────────────────────────────────────────────────────────

test('admin: only the claim reads and closes reports, not the owner email (§110.4)', async () => {
  await seed({ 'reports/r1': { reporterId: BOB, reportedId: CAROL, status: 'pending' } });
  const claim = db('admin-uid', { admin: true });
  const email = db('owner-uid', { email: 'the.abraar.rar@gmail.com', email_verified: true });
  await assertSucceeds(getDoc(doc(claim, 'reports/r1')));
  await assertSucceeds(getDocs(collection(claim, 'reports')));
  await assertSucceeds(updateDoc(doc(claim, 'reports/r1'), { status: 'actioned' }));
  await assertFails(getDoc(doc(email, 'reports/r1')));
  await assertFails(updateDoc(doc(email, 'reports/r1'), { status: 'dismissed' }));
  await assertFails(getDoc(doc(db(BOB), 'reports/r1')));
  await assertFails(getDocs(collection(db(BOB), 'reports')));
  await assertFails(updateDoc(doc(db(BOB), 'reports/r1'), { status: 'dismissed' }));
});

test('admin: may delete any forum post; a rider only their own', async () => {
  await seed({
    'forums/f1': { followerCount: 0, postCount: 2 },
    'forums/f1/posts/p1': { userId: BOB, title: 't', body: 'b' },
    'forums/f1/posts/p2': { userId: CAROL, title: 't', body: 'b' },
  });
  // ForumRepository.deletePost's batch (critique 2026-10-27 #1).
  const del = (f, id) => {
    const b = writeBatch(f);
    b.delete(doc(f, `forums/f1/posts/${id}`));
    b.update(doc(f, 'forums/f1'), { postCount: increment(-1), lastPostId: id });
    return b.commit();
  };
  await assertFails(del(db(ALICE), 'p1'));
  await assertSucceeds(del(db(BOB), 'p1'));
  await assertSucceeds(del(db('admin-uid', { admin: true }), 'p2'));
});

test('admin: config and stats are not client-writable, even for the admin', async () => {
  await seed({ 'config/app': { minBuild: 29 } });
  const admin = db('admin-uid', { admin: true });
  await assertFails(setDoc(doc(admin, 'config/app'), { minBuild: 0 }));
  await assertFails(setDoc(doc(admin, 'stats/badges'), { totalRiders: 1e6 }));
  await assertFails(deleteDoc(doc(admin, 'stats/badges')));
});
