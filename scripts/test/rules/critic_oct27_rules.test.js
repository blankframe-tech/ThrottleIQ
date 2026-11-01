'use strict';

/**
 * Critique 2026-10-27 (DOCS/critic oct27.md), findings 1, 2, 3, 8, 9, 18.
 * Each attack is denied, and each write the app actually makes (same
 * transaction / batch shape as the repository code named in the test) still
 * passes. Own projectId, like the other suites.
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
  doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch,
  runTransaction, increment, serverTimestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid'; // ride owner / forum creator
const BOB = 'bob-uid'; // ordinary rider
const MALLORY = 'mallory-uid'; // attacker

const CLOUDINARY = 'https://res.cloudinary.com/vjvcigkt/image/upload/v1/rideShares/alice-uid/a.jpg';
const GOOGLE_AVATAR = 'https://lh3.googleusercontent.com/a/abc=s96-c';
const EVIL = 'https://evil.example/x.png';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-critic-oct27',
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
function shareData(overrides = {}) {
  return {
    id: 'r1', userId: ALICE, userName: 'Alice', userPhotoUrl: GOOGLE_AVATAR,
    bikeId: 'b1', bikeName: 'FZS', bikeType: '150cc', rideDate: new Date(),
    distanceKm: 10, durationSeconds: 1200, maxSpeedKmh: 60,
    polyline: [{ lat: 23.8, lng: 90.4 }, { lat: 23.81, lng: 90.41 }],
    mapSnapshotUrl: null, comments: 0, createdAt: new Date(), audience: 'public',
    allowedUserIds: [], routeId: null, photoUrls: [CLOUDINARY], photoUrl: CLOUDINARY,
    caption: 'Evening run', upvotes: 0, downvotes: 0,
    hardBrakeCount: 0, rapidAccelCount: 0, highJerkCount: 0,
    ...overrides,
  };
}

const RIDE = {
  userId: ALICE, audience: 'public', distanceKm: 10, durationSeconds: 1200,
  maxSpeedKmh: 60, comments: 0, upvotes: 0, downvotes: 0,
};

/**
 * castVote (app/lib/core/cloud/vote_batch.dart), verbatim shape: a plain read
 * of the previous vote, then a batch (issue #154). `stalePrevious` stands in
 * for an out-of-date cached read.
 */
async function appVote(f, parentPath, uid, value, stalePrevious) {
  const parent = doc(f, parentPath);
  const vote = doc(f, `${parentPath}/votes/${uid}`);
  const previous = stalePrevious !== undefined ? stalePrevious
    : ((await getDoc(vote)).data()?.value ?? null);
  const after = previous === value ? null : value;
  const up = (after === 1 ? 1 : 0) - (previous === 1 ? 1 : 0);
  const down = (after === -1 ? 1 : 0) - (previous === -1 ? 1 : 0);
  const batch = writeBatch(f);
  if (previous === value) batch.delete(vote);
  else batch.set(vote, { value, uid });
  batch.update(parent, {
    ...(up !== 0 && { upvotes: increment(up) }),
    ...(down !== 0 && { downvotes: increment(down) }),
  });
  return batch.commit();
}

// ── Finding 1: counters can't be pumped by create+bump then bare delete ─────

for (const [label, parentPath, parentData] of [
  ['ride', 'rides/r1', RIDE],
  ['forum post', 'forums/f1/posts/p1', { userId: ALICE, upvotes: 0, downvotes: 0, replyCount: 0 }],
]) {
  test(`F1 ${label} votes: a batch built on a stale previous vote is denied`, async () => {
    await seed({ 'forums/f1': { followerCount: 0, postCount: 1 }, [parentPath]: parentData });
    const f = db(BOB);
    await assertSucceeds(appVote(f, parentPath, BOB, 1));
    // The cache still says "no vote": a second +1 would double-count.
    await assertFails(appVote(f, parentPath, BOB, 1, null));
    // The cache says "upvoted" after it was cleared: a -1 would undercount.
    await assertSucceeds(appVote(f, parentPath, BOB, 1));
    await assertFails(appVote(f, parentPath, BOB, 1, 1));
  });

  test(`F1 ${label} votes: the app's vote / flip / toggle-off batch still works`, async () => {
    await seed({ 'forums/f1': { followerCount: 0, postCount: 1 }, [parentPath]: parentData });
    const f = db(BOB);
    await assertSucceeds(appVote(f, parentPath, BOB, 1));
    await assertSucceeds(appVote(f, parentPath, BOB, -1));
    await assertSucceeds(appVote(f, parentPath, BOB, -1));
  });

  test(`F1 ${label} votes: a bare vote delete (tally left up) is denied`, async () => {
    await seed({ 'forums/f1': { followerCount: 0, postCount: 1 }, [parentPath]: parentData });
    const f = db(MALLORY);
    await assertSucceeds(appVote(f, parentPath, MALLORY, 1));
    await assertFails(deleteDoc(doc(f, `${parentPath}/votes/${MALLORY}`)));
  });

  test(`F1 ${label} votes: a bare vote create or flip (tally untouched) is denied`, async () => {
    await seed({ 'forums/f1': { followerCount: 0, postCount: 1 }, [parentPath]: parentData });
    const f = db(MALLORY);
    await assertFails(setDoc(doc(f, `${parentPath}/votes/${MALLORY}`), { value: 1 }));
    await assertSucceeds(appVote(f, parentPath, MALLORY, 1));
    await assertFails(setDoc(doc(f, `${parentPath}/votes/${MALLORY}`), { value: -1 }));
  });
}

test('F1 ride comments: a commenter\'s bare delete is denied; with the -1 in the same commit it passes', async () => {
  await seed({ 'rides/r1': { ...RIDE, comments: 1 }, 'rides/r1/comments/c1': { userId: MALLORY, text: 'hi' } });
  const f = db(MALLORY);
  await assertFails(deleteDoc(doc(f, 'rides/r1/comments/c1')));
  const b = writeBatch(f);
  b.delete(doc(f, 'rides/r1/comments/c1'));
  b.update(doc(f, 'rides/r1'), { comments: increment(-1), lastCommentId: 'c1' });
  await assertSucceeds(b.commit());
});

test('F1 ride comments: a -1 naming a comment that is not deleted is denied', async () => {
  await seed({ 'rides/r1': { ...RIDE, comments: 1 }, 'rides/r1/comments/c1': { userId: BOB, text: 'hi' } });
  await assertFails(updateDoc(doc(db(MALLORY), 'rides/r1'), { comments: increment(-1), lastCommentId: 'c1' }));
});

test('F1 ride comments: addComment\'s transaction still works', async () => {
  await seed({ 'rides/r1': RIDE });
  const f = db(BOB);
  const ref = doc(f, 'rides/r1/comments/c1');
  await assertSucceeds(runTransaction(f, async (tx) => {
    tx.set(ref, {
      id: 'c1', rideId: 'r1', userId: BOB, userName: 'Bob', userPhotoUrl: '',
      text: 'nice', createdAt: serverTimestamp(), updatedAt: null,
    });
    tx.update(doc(f, 'rides/r1'), { comments: increment(1), lastCommentId: 'c1' });
  }));
});

test('B1 ride comments: a bare comment create (no comments +1) is denied', async () => {
  await seed({ 'rides/r1': RIDE });
  // Bare create, then the counted delete, would drive `comments` below zero.
  await assertFails(setDoc(doc(db(MALLORY), 'rides/r1/comments/c1'), {
    id: 'c1', rideId: 'r1', userId: MALLORY, userName: 'M', userPhotoUrl: '',
    text: 'spam', createdAt: serverTimestamp(), updatedAt: null,
  }));
});

test('F1 ride comments: deleteSharedRide (list, delete the ride, then its comments) works', async () => {
  await seed({
    'rides/r1': { ...RIDE, comments: 2 },
    'rides/r1/comments/c1': { userId: BOB, text: 'hi' },
    'rides/r1/comments/c2': { userId: ALICE, text: 'thanks' },
  });
  const f = db(ALICE);
  const comments = await getDocs(collection(f, 'rides/r1/comments'));
  await assertSucceeds(deleteDoc(doc(f, 'rides/r1')));
  await assertSucceeds(Promise.all(comments.docs.map((d) => deleteDoc(d.ref))));
});

test('F1 ride comments: build 29\'s deleteSharedRide order (comments first, then the ride) still works', async () => {
  await seed({
    'rides/r1': { ...RIDE, comments: 2 },
    'rides/r1/comments/c1': { userId: BOB, text: 'hi' },
    'rides/r1/comments/c2': { userId: ALICE, text: 'thanks' },
  });
  const f = db(ALICE);
  const comments = await getDocs(collection(f, 'rides/r1/comments'));
  await assertSucceeds(Promise.all(comments.docs.map((d) => deleteDoc(d.ref))));
  await assertSucceeds(deleteDoc(doc(f, 'rides/r1')));
});

test('F1 forum replies: addReply / deleteReply still work; bare create and bare delete are denied', async () => {
  await seed({ 'forums/f1': { followerCount: 0, postCount: 1 }, 'forums/f1/posts/p1': { userId: ALICE, replyCount: 0, upvotes: 0, downvotes: 0 } });
  const f = db(MALLORY);
  const post = doc(f, 'forums/f1/posts/p1');
  const reply = (id) => ({
    postId: 'p1', forumId: 'f1', userId: MALLORY, userName: 'M', userPhotoUrl: '',
    body: 'b', createdAt: serverTimestamp(),
  });
  await assertFails(setDoc(doc(f, 'forums/f1/posts/p1/replies/bare'), reply('bare')));
  await assertSucceeds(runTransaction(f, async (tx) => {
    tx.set(doc(f, 'forums/f1/posts/p1/replies/r1'), reply('r1'));
    tx.update(post, { replyCount: increment(1), lastReplyId: 'r1' });
  }));
  await assertFails(deleteDoc(doc(f, 'forums/f1/posts/p1/replies/r1')));
  const b = writeBatch(f);
  b.delete(doc(f, 'forums/f1/posts/p1/replies/r1'));
  b.update(post, { replyCount: increment(-1), lastReplyId: 'r1' });
  await assertSucceeds(b.commit());
});

test('F1 forum posts: createPost / deletePost still work; bare create and bare delete are denied', async () => {
  await seed({ 'forums/f1': { followerCount: 0, postCount: 0 } });
  const f = db(MALLORY);
  const forum = doc(f, 'forums/f1');
  const post = {
    forumId: 'f1', userId: MALLORY, userName: 'M', userPhotoUrl: '', title: 't',
    body: 'b', replyCount: 0, upvotes: 0, downvotes: 0, createdAt: serverTimestamp(),
  };
  await assertFails(setDoc(doc(f, 'forums/f1/posts/bare'), post));
  const c = writeBatch(f);
  c.set(doc(f, 'forums/f1/posts/p1'), post);
  c.update(forum, { postCount: increment(1), lastPostId: 'p1' });
  await assertSucceeds(c.commit());
  await assertFails(deleteDoc(doc(f, 'forums/f1/posts/p1')));
  const d = writeBatch(f);
  d.delete(doc(f, 'forums/f1/posts/p1'));
  d.update(forum, { postCount: increment(-1), lastPostId: 'p1' });
  await assertSucceeds(d.commit());
});

test('F1 forum posts: a moderator\'s deletePost batch on someone else\'s post still works', async () => {
  await seed({
    'forums/c-club': { followerCount: 0, postCount: 1, type: 'custom', createdBy: ALICE, maintainerIds: [ALICE] },
    'forums/c-club/posts/p1': { userId: BOB, title: 't', body: 'b' },
  });
  const f = db(ALICE);
  const b = writeBatch(f);
  b.delete(doc(f, 'forums/c-club/posts/p1'));
  b.update(doc(f, 'forums/c-club'), { postCount: increment(-1), lastPostId: 'p1' });
  await assertSucceeds(b.commit());
});

test('F1 forum follows: followForum / unfollowForum still work; bare follow and bare unfollow are denied', async () => {
  await seed({ 'forums/f1': { followerCount: 0, postCount: 0 } });
  const f = db(MALLORY);
  const follow = doc(f, `forum_follows/${MALLORY}_f1`);
  const forum = doc(f, 'forums/f1');
  const data = { userId: MALLORY, forumId: 'f1', createdAt: serverTimestamp() };
  await assertFails(setDoc(follow, data));
  // isFollowing / the transactions' get() of a follow that doesn't exist yet:
  // the rider's own reads as empty, someone else's is no existence oracle.
  await assertSucceeds(getDoc(follow));
  await assertFails(getDoc(doc(f, `forum_follows/${BOB}_f1`)));
  await assertSucceeds(runTransaction(f, async (tx) => {
    await tx.get(follow);
    tx.set(follow, data);
    tx.update(forum, { followerCount: increment(1) });
  }));
  await assertFails(deleteDoc(follow));
  await assertSucceeds(runTransaction(f, async (tx) => {
    await tx.get(follow);
    tx.delete(follow);
    tx.update(forum, { followerCount: increment(-1) });
  }));
});

// Issue #155: followForum / unfollowForum are now a plain (maybe cached) read
// plus a batch, so a stale cache can build a batch on the wrong state. The
// rules pair the ±1 with the follow doc's create/delete, so those are refused.
test('#155 forum follows: the batch shape works; bare bumps and stale-cache double follow/unfollow are denied', async () => {
  await seed({ 'forums/f1': { followerCount: 3, postCount: 0 } });
  const f = db(MALLORY);
  const follow = doc(f, `forum_follows/${MALLORY}_f1`);
  const forum = doc(f, 'forums/f1');
  const data = { userId: MALLORY, forumId: 'f1', createdAt: serverTimestamp() };
  const batch = (...ops) => { const b = writeBatch(f); ops.forEach((op) => op(b)); return b.commit(); };
  const setFollow = (b) => b.set(follow, data);
  const delFollow = (b) => b.delete(follow);
  const bump = (n) => (b) => b.update(forum, { followerCount: increment(n) });

  // Bare counter bumps, with no follow doc moving.
  await assertFails(updateDoc(forum, { followerCount: increment(1) }));
  await assertFails(updateDoc(forum, { followerCount: increment(-1) }));
  // Someone else's follow doc can't carry my bump.
  await assertFails(batch((b) => b.set(doc(f, `forum_follows/${BOB}_f1`), { ...data, userId: BOB }), bump(1)));
  // Follow doc created but the count jumps by 2.
  await assertFails(batch(setFollow, bump(2)));

  await assertSucceeds(batch(setFollow, bump(1)));
  // Stale cache said "not following": a second follow batch is refused whole.
  await assertFails(batch(setFollow, bump(1)));
  await assertFails(updateDoc(forum, { followerCount: increment(1) }));

  await assertSucceeds(batch(delFollow, bump(-1)));
  // Stale cache said "following": a second unfollow batch is refused whole.
  await assertFails(batch(delFollow, bump(-1)));

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const snap = await getDoc(doc(ctx.firestore(), 'forums/f1'));
    assert.equal(snap.data().followerCount, 3);
  });
});

// ── Finding 2: no moderator rights on a pre-created bike/topic forum ────────

test('F2 forums: a bike forum created with createdBy or maintainerIds is denied', async () => {
  const f = db(MALLORY);
  const bike = { type: 'bikeModel', brand: 'Yamaha', model: 'R15', displayName: 'Yamaha R15', followerCount: 0, postCount: 0, createdAt: serverTimestamp() };
  await assertFails(setDoc(doc(f, 'forums/yamaha__r15'), { ...bike, createdBy: MALLORY }));
  await assertFails(setDoc(doc(f, 'forums/yamaha__r15'), { ...bike, maintainerIds: [MALLORY] }));
  await assertFails(setDoc(doc(f, 'forums/yamaha__r15'), { ...bike, type: 'custom', createdBy: MALLORY, maintainerIds: [MALLORY] }));
  await assertFails(setDoc(doc(f, 'forums/yamaha__r15'), { ...bike, junk: 1 }));
});

test('F2 forums: getOrCreateForum, getOrCreateGeneralForum and createCustomForum shapes pass', async () => {
  const f = db(BOB);
  await assertSucceeds(setDoc(doc(f, 'forums/yamaha__r15'), {
    type: 'bikeModel', brand: 'Yamaha', model: 'R15', displayName: 'Yamaha R15',
    followerCount: 0, postCount: 0, createdAt: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(doc(f, 'forums/maintenance'), {
    type: 'general', brand: '', model: null, topic: 'Maintenance', displayName: 'Maintenance',
    followerCount: 0, postCount: 0, createdAt: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(doc(f, 'forums/c-night-riders'), {
    type: 'custom', brand: '', model: null, topic: null, displayName: 'Night Riders',
    description: null, createdBy: BOB, maintainerIds: [BOB],
    followerCount: 0, postCount: 0, createdAt: serverTimestamp(),
  }));
});

// Security sweep B6: forum create text is capped.
test('B6 forums: oversized forum text on create is denied', async () => {
  const f = db(MALLORY);
  const custom = { type: 'custom', brand: '', model: null, topic: null, displayName: 'X', description: null,
    createdBy: MALLORY, maintainerIds: [MALLORY], followerCount: 0, postCount: 0, createdAt: serverTimestamp() };
  await assertFails(setDoc(doc(f, 'forums/c-x1'), { ...custom, displayName: 'x'.repeat(501) }));
  await assertFails(setDoc(doc(f, 'forums/c-x2'), { ...custom, description: 'x'.repeat(2001) }));
  await assertFails(setDoc(doc(f, 'forums/c-x3'), { ...custom, displayName: { blob: 1 } }));
  const bike = { type: 'bikeModel', brand: 'Yamaha', model: 'R15', displayName: 'Yamaha R15',
    followerCount: 0, postCount: 0, createdAt: serverTimestamp() };
  await assertFails(setDoc(doc(f, 'forums/b1'), { ...bike, brand: 'x'.repeat(201) }));
  await assertFails(setDoc(doc(f, 'forums/b2'), { ...bike, model: 'x'.repeat(201) }));
  await assertFails(setDoc(doc(f, 'forums/t1'), { ...bike, type: 'general', brand: '', model: null,
    topic: 'x'.repeat(201) }));
});

test('F2 forums: a c- forum must be custom and name the caller as creator', async () => {
  const f = db(MALLORY);
  const base = { brand: '', model: null, topic: null, displayName: 'X', description: null, followerCount: 0, postCount: 0, createdAt: serverTimestamp() };
  await assertFails(setDoc(doc(f, 'forums/c-x'), { ...base, type: 'custom', createdBy: BOB, maintainerIds: [BOB] }));
  await assertFails(setDoc(doc(f, 'forums/c-x'), { ...base, type: 'brand', createdBy: MALLORY, maintainerIds: [MALLORY] }));
});

// ── Finding 3: a blocked rider can't comment or vote on the blocker's rides ─

test('F3 blocks: a rider the owner blocked can\'t comment or vote on the owner\'s public ride', async () => {
  await seed({ 'rides/r1': RIDE, [`users/${ALICE}/blocks/${MALLORY}`]: { blockedAt: new Date() } });
  const f = db(MALLORY);
  await assertFails(runTransaction(f, async (tx) => {
    tx.set(doc(f, 'rides/r1/comments/c1'), {
      id: 'c1', rideId: 'r1', userId: MALLORY, userName: 'M', userPhotoUrl: '',
      text: 'hi', createdAt: serverTimestamp(), updatedAt: null,
    });
    tx.update(doc(f, 'rides/r1'), { comments: increment(1), lastCommentId: 'c1' });
  }));
  await assertFails(appVote(f, 'rides/r1', MALLORY, 1));
  // Someone not blocked still can.
  await assertSucceeds(appVote(db(BOB), 'rides/r1', BOB, 1));
});

// ── Finding 8: shared rides get the image-host allow-list and size caps ─────

test('F8 shared rides: the app\'s share payload passes', async () => {
  await assertSucceeds(setDoc(doc(db(ALICE), 'rides/r1'), shareData({ caption: 'x'.repeat(280) })));
});

test('F8 shared rides: an off-host photo, avatar or map snapshot is denied', async () => {
  const f = db(ALICE);
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ photoUrls: [CLOUDINARY, EVIL] })));
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ photoUrl: EVIL })));
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ userPhotoUrl: EVIL })));
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ mapSnapshotUrl: EVIL })));
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ photoUrls: [CLOUDINARY, CLOUDINARY, CLOUDINARY, CLOUDINARY] })));
});

test('F8 shared rides: oversize caption or name, a non-list polyline, or an extra key is denied', async () => {
  const f = db(ALICE);
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ caption: 'x'.repeat(2001) })));
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ userName: 'x'.repeat(101) })));
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ polyline: 'x'.repeat(1000) })));
  await assertFails(setDoc(doc(f, 'rides/r1'), shareData({ junk: 'x'.repeat(1000) })));
});

test('F8 shared rides: an owner edit is checked the same way; a legacy off-host field doesn\'t block other edits', async () => {
  await seed({ 'rides/r1': { ...shareData(), photoUrls: [EVIL], photoUrl: EVIL } });
  const f = db(ALICE);
  // updateSharedRideBikeInfo leaves the legacy photos alone.
  await assertSucceeds(updateDoc(doc(f, 'rides/r1'), { bikeId: 'b2', bikeName: 'R15', bikeType: '155cc' }));
  // updateSharedRideContent: allow-listed photos pass, off-host ones don't.
  await assertSucceeds(updateDoc(doc(f, 'rides/r1'), { caption: 'new', photoUrls: [CLOUDINARY], photoUrl: CLOUDINARY }));
  await assertFails(updateDoc(doc(f, 'rides/r1'), { caption: 'new', photoUrls: [EVIL], photoUrl: EVIL }));
  await assertFails(updateDoc(doc(f, 'rides/r1'), { caption: 'x'.repeat(2001) }));
  // A re-share (shareRide's merge set on an existing doc) passes.
  const again = shareData();
  delete again.comments; delete again.upvotes; delete again.downvotes;
  await assertSucceeds(setDoc(doc(f, 'rides/r1'), again, { merge: true }));
});

// ── Finding 9: `username` must match the claimed `usernameLower` ────────────

test('F9 profiles: setUsername\'s transaction passes, mixed case included', async () => {
  await seed({ [`users/${BOB}`]: { visibility: 'public', displayName: 'Bob' } });
  const f = db(BOB);
  await assertSucceeds(runTransaction(f, async (tx) => {
    tx.set(doc(f, 'usernames/bob_rider'), { uid: BOB });
    tx.set(doc(f, `users/${BOB}`), { username: 'Bob_Rider', usernameLower: 'bob_rider', updatedAt: serverTimestamp() }, { merge: true });
  }));
});

test('F9 profiles: showing someone else\'s @handle under your own claim is denied', async () => {
  await seed({
    'usernames/mallory': { uid: MALLORY },
    [`users/${MALLORY}`]: { visibility: 'public', username: 'mallory', usernameLower: 'mallory' },
  });
  await assertFails(setDoc(doc(db(MALLORY), `users/${MALLORY}`), { username: 'the_abraar' }, { merge: true }));
});

test('F9 profiles: bio is capped; a legacy mismatched username doesn\'t block other edits', async () => {
  await seed({ [`users/${BOB}`]: { visibility: 'public', username: 'Legacy', usernameLower: 'other' } });
  const f = db(BOB);
  await assertSucceeds(setDoc(doc(f, `users/${BOB}`), { bio: 'x'.repeat(160), updatedAt: serverTimestamp() }, { merge: true }));
  await assertFails(setDoc(doc(f, `users/${BOB}`), { bio: 'x'.repeat(2001) }, { merge: true }));
});

// ── Finding 18: more than one crash alert per ride ──────────────────────────

function crash(uid, rideId) {
  return { uid, rideId, timestamp: new Date().toISOString(), lastLat: 23.8, lastLng: 90.4, status: 'pending' };
}

test('F18 crash alerts: a second crash on the same ride gets its own alert', async () => {
  const f = db(BOB);
  await assertSucceeds(setDoc(doc(f, 'crashNotifications/ride-1_1761550000000'), crash(BOB, 'ride-1')));
  await assertSucceeds(setDoc(doc(f, 'crashNotifications/ride-1_1761550600000'), crash(BOB, 'ride-1')));
  // Build 29's id (the bare rideId) still passes.
  await assertSucceeds(setDoc(doc(f, 'crashNotifications/ride-1'), crash(BOB, 'ride-1')));
});

test('F18 crash alerts: the id must still be the rideId plus a numeric suffix', async () => {
  const f = db(BOB);
  await assertFails(setDoc(doc(f, 'crashNotifications/ride-2_1761550000000'), crash(BOB, 'ride-1')));
  await assertFails(setDoc(doc(f, 'crashNotifications/ride-1_abc'), crash(BOB, 'ride-1')));
  await assertFails(setDoc(doc(f, 'crashNotifications/ride-1_'), crash(BOB, 'ride-1')));
  await assertFails(setDoc(doc(f, 'crashNotifications/ride-1x_123'), crash(BOB, 'ride-1')));
});
