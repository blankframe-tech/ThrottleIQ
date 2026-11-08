'use strict';

/**
 * Shared docs every rider's device parses (shared rides, ride comments,
 * public profiles, forum posts) must have the field types the app's parsers
 * expect, so one malformed write can't make a shared list fail to load for
 * everyone. Each malformed write is denied; each write the app makes passes.
 * Also: a ride owner can no longer delete a comment on their ride without the
 * paired `comments` -1 (minBuild 35 deletes the ride first).
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
  doc, setDoc, updateDoc, deleteDoc, writeBatch, increment, serverTimestamp,
  Timestamp, deleteField,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid'; // ride owner
const BOB = 'bob-uid'; // commenter
const MALLORY = 'mallory-uid'; // attacker

const GOOGLE_AVATAR = 'https://lh3.googleusercontent.com/a/abc=s96-c';
const FAR_FUTURE = Timestamp.fromDate(new Date('2099-01-01T00:00:00Z'));

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-poison-pill',
    firestore: { rules: RULES },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

const db = (uid) => testEnv.authenticatedContext(uid).firestore();

async function seed(docs) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    for (const [p, data] of Object.entries(docs)) await setDoc(doc(f, p), data);
  });
}

/** RideShareModel.toFirestore() for a fresh share. */
function shareData(uid, overrides = {}) {
  return {
    id: 'r1', userId: uid, userName: 'Rider', userPhotoUrl: GOOGLE_AVATAR,
    bikeId: 'b1', bikeName: 'FZS', bikeType: '150cc', rideDate: new Date(),
    distanceKm: 10, durationSeconds: 1200, maxSpeedKmh: 60,
    polyline: [{ lat: 23.8, lng: 90.4 }, { lat: 23.81, lng: 90.41 }],
    mapSnapshotUrl: null, comments: 0, createdAt: new Date(), audience: 'public',
    allowedUserIds: [], routeId: null, photoUrls: [], photoUrl: null,
    caption: null, upvotes: 0, downvotes: 0,
    hardBrakeCount: 0, rapidAccelCount: 0, highJerkCount: 0,
    ...overrides,
  };
}

function withoutKey(obj, key) {
  const copy = { ...obj };
  delete copy[key];
  return copy;
}

const share = (uid, overrides) => setDoc(doc(db(uid), 'rides', 'r1'), shareData(uid, overrides));

// ── Shared rides ────────────────────────────────────────────────────────────

test('the app\'s own share (client createdAt, empty polyline too) passes', async () => {
  await assertSucceeds(share(ALICE));
  await testEnv.clearFirestore();
  await assertSucceeds(share(ALICE, { polyline: [], userPhotoUrl: '' }));
});

test('a share with no userName, or a non-string one, is denied; an empty one passes', async () => {
  await assertFails(setDoc(doc(db(MALLORY), 'rides', 'r1'), withoutKey(shareData(MALLORY), 'userName')));
  await assertFails(share(MALLORY, { userName: null }));
  await assertFails(share(MALLORY, { userName: 7 }));
  await assertFails(share(MALLORY, { userName: 'x'.repeat(101) }));
  // A Firebase displayName can be '' (the app sends it as is); it parses.
  await assertSucceeds(share(ALICE, { userName: '' }));
});

test('a share whose hard-cast string fields are missing or not strings is denied', async () => {
  for (const key of ['userPhotoUrl', 'bikeId', 'bikeName', 'bikeType']) {
    await assertFails(setDoc(doc(db(MALLORY), 'rides', 'r1'), withoutKey(shareData(MALLORY), key)));
    await assertFails(share(MALLORY, { [key]: null }));
    await assertFails(share(MALLORY, { [key]: 7 }));
  }
});

test('a share whose polyline holds non-points is denied', async () => {
  await assertFails(share(MALLORY, { polyline: ['x'] }));
  await assertFails(share(MALLORY, { polyline: [{ lat: 'a', lng: 90.4 }] }));
  await assertFails(share(MALLORY, { polyline: [{ lat: 23.8 }] }));
  await assertFails(share(MALLORY, { polyline: [{ lat: 23.8, lng: 90.4 }, 7] }));
});

test('a share pinned to the top of the feed by a future or non-timestamp createdAt is denied', async () => {
  await assertFails(share(MALLORY, { createdAt: FAR_FUTURE }));
  await assertFails(share(MALLORY, { createdAt: 'zzzz' }));
  await assertFails(setDoc(doc(db(MALLORY), 'rides', 'r1'), withoutKey(shareData(MALLORY), 'createdAt')));
});

test('a re-share passes; an edit cannot plant a bad field', async () => {
  await seed({ 'rides/r1': shareData(ALICE, { comments: 2 }) });
  const reshare = withoutKey(withoutKey(withoutKey(shareData(ALICE), 'comments'), 'upvotes'), 'downvotes');
  await assertSucceeds(setDoc(doc(db(ALICE), 'rides', 'r1'), reshare, { merge: true }));
  const ref = doc(db(ALICE), 'rides', 'r1');
  await assertFails(updateDoc(ref, { userName: null }));
  await assertFails(updateDoc(ref, { userName: deleteField() }));
  await assertFails(updateDoc(ref, { bikeName: 7 }));
  await assertFails(updateDoc(ref, { polyline: ['x'] }));
  await assertFails(updateDoc(ref, { createdAt: FAR_FUTURE }));
  // updateSharedRideBikeInfo still works.
  await assertSucceeds(updateDoc(ref, { bikeId: 'b2', bikeName: 'R15', bikeType: '155cc' }));
});

test('a share and re-share with a full 1,000-point polyline stay inside the rules limits', async () => {
  const polyline = Array.from({ length: 1000 }, (_, i) => ({ lat: 23.8 + i * 1e-4, lng: 90.4 }));
  await assertSucceeds(share(ALICE, { polyline }));
  const reshare = withoutKey(withoutKey(withoutKey(shareData(ALICE, { polyline }), 'comments'), 'upvotes'), 'downvotes');
  await assertSucceeds(setDoc(doc(db(ALICE), 'rides', 'r1'), reshare, { merge: true }));
  await assertSucceeds(updateDoc(doc(db(ALICE), 'rides', 'r1'), { caption: 'x' }));
});

test('a legacy share missing userName still takes an unrelated edit', async () => {
  await seed({ 'rides/r1': withoutKey(shareData(ALICE), 'userName') });
  await assertSucceeds(updateDoc(doc(db(ALICE), 'rides', 'r1'), { caption: 'Evening run' }));
});

// ── Ride comments ───────────────────────────────────────────────────────────

/** RideShareRepository.addComment: the comment and the ride's +1. */
function addComment(uid, commentId, overrides = {}) {
  const f = db(uid);
  const rideRef = doc(f, 'rides', 'r1');
  const data = {
    id: commentId, rideId: 'r1', userId: uid, userName: 'Bob', userPhotoUrl: '',
    text: 'nice', createdAt: serverTimestamp(), writtenAt: Timestamp.now(), updatedAt: null,
    ...overrides,
  };
  for (const [k, v] of Object.entries(data)) if (v === undefined) delete data[k];
  return writeBatch(f)
    .set(doc(rideRef, 'comments', commentId), data)
    .update(rideRef, { comments: increment(1), lastCommentId: commentId })
    .commit();
}

test('the app\'s comment passes; one with no or a non-string userName or avatar is denied', async () => {
  await seed({ 'rides/r1': shareData(ALICE) });
  await assertSucceeds(addComment(BOB, 'c1'));
  await assertFails(addComment(MALLORY, 'c2', { userName: undefined }));
  await assertFails(addComment(MALLORY, 'c3', { userName: 7 }));
  await assertFails(addComment(MALLORY, 'c4', { userPhotoUrl: null }));
  await assertFails(addComment(MALLORY, 'c5', { userPhotoUrl: undefined }));
});

test('a ride owner cannot bare-delete a comment on their ride (legacy clause gone)', async () => {
  await seed({
    'rides/r1': shareData(ALICE, { comments: 1, lastCommentId: 'c1' }),
    'rides/r1/comments/c1': { id: 'c1', rideId: 'r1', userId: BOB, userName: 'Bob', userPhotoUrl: '', text: 'hi' },
  });
  const f = db(ALICE);
  await assertFails(deleteDoc(doc(f, 'rides', 'r1', 'comments', 'c1')));
  // With the paired -1 it still works.
  await assertSucceeds(writeBatch(f)
    .delete(doc(f, 'rides', 'r1', 'comments', 'c1'))
    .update(doc(f, 'rides', 'r1'), { comments: increment(-1), lastCommentId: 'c1' })
    .commit());
});

test('comments of a deleted ride can still be swept up (deleteSharedRide)', async () => {
  await seed({
    'rides/r1': shareData(ALICE, { comments: 1 }),
    'rides/r1/comments/c1': { id: 'c1', rideId: 'r1', userId: BOB, userName: 'Bob', userPhotoUrl: '', text: 'hi' },
  });
  const f = db(ALICE);
  await assertSucceeds(deleteDoc(doc(f, 'rides', 'r1')));
  await assertSucceeds(deleteDoc(doc(f, 'rides', 'r1', 'comments', 'c1')));
});

// ── Public profiles ─────────────────────────────────────────────────────────

/** ProfileRepository.ensureProfile on a new account. */
function newProfile(overrides = {}) {
  return {
    displayName: 'Mallory', visibility: 'public', followerCount: 0, followingCount: 0,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...overrides,
  };
}

test('ensureProfile passes; a profile with a bad createdAt/updatedAt/bikesVisibility is denied', async () => {
  await assertSucceeds(setDoc(doc(db(ALICE), 'users', ALICE), newProfile(), { merge: true }));
  const ref = doc(db(MALLORY), 'users', MALLORY);
  await assertFails(setDoc(ref, newProfile({ createdAt: 'zzzz' })));
  await assertFails(setDoc(ref, newProfile({ createdAt: FAR_FUTURE.toMillis() })));
  await assertFails(setDoc(ref, newProfile({ updatedAt: 'zzzz' })));
  await assertFails(setDoc(ref, newProfile({ bikesVisibility: 7 })));
  await assertFails(setDoc(ref, newProfile({ bikesVisibility: 'everyone' })));
});

test('setBikesVisibility passes; an update cannot plant a bad type', async () => {
  await seed({ [`users/${ALICE}`]: { displayName: 'Alice', visibility: 'public', createdAt: Timestamp.now() } });
  const ref = doc(db(ALICE), 'users', ALICE);
  await assertSucceeds(setDoc(ref, { bikesVisibility: 'followers', updatedAt: serverTimestamp() }, { merge: true }));
  await assertFails(updateDoc(ref, { createdAt: 'zzzz' }));
  await assertFails(updateDoc(ref, { bikesVisibility: 7 }));
});

// ── Forum posts ─────────────────────────────────────────────────────────────

/** ForumRepository.createPost: the post and its forum's postCount bump. */
function createPost(uid, postId, overrides = {}) {
  const f = db(uid);
  const data = {
    forumId: 'general', userId: uid, userName: 'R', userPhotoUrl: '', title: 'Hello', body: 'World',
    replyCount: 0, upvotes: 0, downvotes: 0, postType: 'general', isSolved: false,
    createdAt: serverTimestamp(), ...overrides,
  };
  for (const [k, v] of Object.entries(data)) if (v === undefined) delete data[k];
  return writeBatch(f)
    .set(doc(f, 'forums', 'general', 'posts', postId), data)
    .update(doc(f, 'forums', 'general'), { postCount: increment(1), lastPostId: postId })
    .commit();
}

test('the app\'s post passes; a post whose forumId field is wrong is denied', async () => {
  await seed({ 'forums/general': { type: 'general', displayName: 'General', postCount: 0, followerCount: 0 } });
  await assertSucceeds(createPost(BOB, 'p1'));
  await assertFails(createPost(MALLORY, 'p2', { forumId: 7 }));
  await assertFails(createPost(MALLORY, 'p3', { forumId: 'maintenance' }));
  await assertFails(createPost(MALLORY, 'p4', { forumId: undefined }));
});
