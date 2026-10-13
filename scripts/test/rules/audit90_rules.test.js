'use strict';

/**
 * Rules changes from the §90 audit (issues_open.md §90.D1–D11, §90.A4/A11).
 *
 * One block per finding, each pairing the legitimate client write (the exact
 * shape the app sends) with the abuse the rule now refuses. Own projectId so
 * `node --test` can run this file in parallel with the others.
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
  updateDoc,
  deleteDoc,
  addDoc,
  collection,
  query,
  where,
  orderBy,
  limit,
  increment,
  runTransaction,
  writeBatch,
  Timestamp,
  serverTimestamp,
  deleteField,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

// ALICE authors rides, owns forum posts, creates the group ride.
// BOB follows ALICE. MALLORY is the attacker. EVE is unrelated.
const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const MALLORY = 'mallory-uid';
const EVE = 'eve-uid';

const GOOD_PHOTO = 'https://res.cloudinary.com/vjvcigkt/image/upload/v1/avatars/alice-uid/a.jpg';
const GOOGLE_PHOTO = 'https://lh3.googleusercontent.com/a/abc=s96-c';
const BEACON = 'https://attacker.example/pixel.gif';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-audit90',
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
  return { followerUid: follower, followeeUid: followee, createdAt: Timestamp.now() };
}

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rides', 'r-public'), ride({}));
    await setDoc(doc(db, 'rides', 'r-followers'), ride({ audience: 'followers' }));
    await setDoc(doc(db, 'follows', `${BOB}_${ALICE}`), edge(BOB, ALICE));
    await setDoc(doc(db, 'follows', `${MALLORY}_${ALICE}`), edge(MALLORY, ALICE));

    await setDoc(doc(db, 'users', ALICE), {
      displayName: 'Alice',
      visibility: 'public',
      usernameLower: 'alice',
      email: 'alice@example.com',
      emailLower: 'alice@example.com',
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'users', EVE), {
      displayName: 'Eve',
      visibility: 'private',
      usernameLower: 'eve',
      email: 'eve@example.com',
      emailLower: 'eve@example.com',
      createdAt: Timestamp.now(),
    });

    await setDoc(doc(db, 'forums', 'f1'), {
      displayName: 'Forum', followerCount: 0, postCount: 1,
    });
    await setDoc(doc(db, 'forums', 'f1', 'posts', 'p-alice'), {
      userId: ALICE, title: 't', body: 'b', replyCount: 0, upvotes: 0, downvotes: 0,
    });

    await setDoc(doc(db, 'groupRides', 'gr1'), {
      creatorId: ALICE,
      name: 'Ride',
      status: 'active',
      memberIds: [ALICE, BOB],
      invitedIds: [],
      maxParticipants: 20,
      createdAt: new Date(),
    });
  });
});

function dbFor(uid, token) {
  return testEnv.authenticatedContext(uid, token).firestore();
}

function commentData(uid, overrides = {}) {
  return {
    id: 'x',
    rideId: 'r-followers',
    userId: uid,
    userName: 'Bob',
    userPhotoUrl: '',
    text: 'nice ride',
    createdAt: serverTimestamp(),
    updatedAt: null,
    ...overrides,
  };
}

async function addCommentTx(db, uid, rideId, overrides = {}) {
  const rideRef = doc(db, 'rides', rideId);
  const commentRef = doc(collection(rideRef, 'comments'));
  return runTransaction(db, async (tx) => {
    tx.set(commentRef, commentData(uid, { id: commentRef.id, rideId, ...overrides }));
    tx.update(rideRef, { comments: increment(1), lastCommentId: commentRef.id });
  });
}

// ---------------------------------------------------------------------------
// §90.D1 — ride comments: create gate + delete
// ---------------------------------------------------------------------------

test('D1: a follower can comment on a followers-only ride (addComment shape)', async () => {
  await assertSucceeds(addCommentTx(dbFor(BOB), BOB, 'r-followers'));
});

test('D1: a stranger cannot plant a comment on a followers-only ride', async () => {
  const db = dbFor(EVE);
  await assertFails(
    setDoc(doc(db, 'rides', 'r-followers', 'comments', 'planted'),
      commentData(EVE))
  );
});

test('D1: a comment with an extra key is denied', async () => {
  await assertFails(addCommentTx(dbFor(BOB), BOB, 'r-followers', { pinned: true }));
});

test('D1: an empty or oversized comment is denied', async () => {
  await assertFails(addCommentTx(dbFor(BOB), BOB, 'r-followers', { text: '' }));
  await assertFails(addCommentTx(dbFor(BOB), BOB, 'r-followers', { text: 'x'.repeat(2001) }));
});

test('D1: a comment on a ride that does not exist is denied', async () => {
  const db = dbFor(BOB);
  await assertFails(
    setDoc(doc(db, 'rides', 'nope', 'comments', 'c'), commentData(BOB, { rideId: 'nope' }))
  );
});

async function seedComments() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rides', 'r-public', 'comments', 'c-bob'), { userId: BOB, text: 'hi' });
    await setDoc(doc(db, 'rides', 'r-public', 'comments', 'c-mallory'), { userId: MALLORY, text: 'hi' });
    await setDoc(doc(db, 'rides', 'r-public', 'likes', BOB), { userId: BOB });
  });
}

test('D1: the ride owner can delete anyone\'s comment, then the ride (deleteSharedRide)', async () => {
  await seedComments();
  const db = dbFor(ALICE);
  const rideRef = doc(db, 'rides', 'r-public');
  const comments = await getDocs(collection(rideRef, 'comments'));
  const likes = await getDocs(collection(rideRef, 'likes'));
  await assertSucceeds(Promise.all([
    ...comments.docs.map((d) => deleteDoc(d.ref)),
    ...likes.docs.map((d) => deleteDoc(d.ref)),
  ]));
  await assertSucceeds(deleteDoc(rideRef));
});

test('D1: a comment author can delete their own comment, not someone else\'s', async () => {
  await seedComments();
  const db = dbFor(BOB);
  await assertSucceeds(deleteDoc(doc(db, 'rides', 'r-public', 'comments', 'c-bob')));
  await assertFails(deleteDoc(doc(db, 'rides', 'r-public', 'comments', 'c-mallory')));
});

// ---------------------------------------------------------------------------
// §90.D2 — Cloudinary ledger prefix
// ---------------------------------------------------------------------------

function ledger(db, uid) {
  return collection(db, 'users', uid, 'cloudinaryAssets');
}

test('D2: a ledger row for an asset in the rider\'s own folder is allowed', async () => {
  const db = dbFor(MALLORY);
  for (const publicId of [
    `avatars/${MALLORY}/abc123`,
    `voiceNotes/${MALLORY}/gr1/clip`,
  ]) {
    await assertSucceeds(addDoc(ledger(db, MALLORY), {
      publicId, resourceType: 'image', folder: 'x', secureUrl: 'x', createdAt: serverTimestamp(),
    }));
  }
});

test('D2: a ledger row naming a victim\'s asset is denied', async () => {
  const db = dbFor(MALLORY);
  for (const publicId of [
    `avatars/${ALICE}/abc123`,
    `avatars/${MALLORY}`,
    `avatars/${MALLORY}/../${ALICE}/abc`,
    'clip',
    `voiceNotes/gr1/clip`,
  ]) {
    await assertFails(addDoc(ledger(db, MALLORY), { publicId, resourceType: 'image' }));
  }
});

test('D2: a ledger row with an unknown resourceType is denied', async () => {
  await assertFails(addDoc(ledger(dbFor(MALLORY), MALLORY), {
    publicId: `avatars/${MALLORY}/abc`, resourceType: 'image/upload/../x',
  }));
});

// ---------------------------------------------------------------------------
// §90.D3 / §90.D4 — group-ride roster
// ---------------------------------------------------------------------------

test('D3: the creator cannot add a rider to memberIds', async () => {
  const db = dbFor(ALICE);
  await assertFails(updateDoc(doc(db, 'groupRides', 'gr1'), { memberIds: [ALICE, BOB, EVE] }));
});

test('D3: the creator can still invite, heartbeat and end the ride', async () => {
  const db = dbFor(ALICE);
  const ref = doc(db, 'groupRides', 'gr1');
  await assertSucceeds(updateDoc(ref, { invitedIds: [EVE] }));
  await assertSucceeds(updateDoc(ref, { lastActiveAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(ref, { status: 'completed', endedAt: serverTimestamp() }));
});

test('D4: the creator kicks a rider (removeMember shape) and they cannot rejoin by code', async () => {
  const alice = dbFor(ALICE);
  await assertSucceeds(runTransaction(alice, async (tx) => {
    tx.delete(doc(alice, 'groupRides', 'gr1', 'members', BOB));
    tx.update(doc(alice, 'groupRides', 'gr1'), {
      memberIds: [ALICE], invitedIds: [], bannedIds: [BOB],
    });
  }));

  const bob = dbFor(BOB);
  await assertFails(updateDoc(doc(bob, 'groupRides', 'gr1'), { memberIds: [ALICE, BOB] }));
  await assertFails(setDoc(doc(bob, 'groupRides', 'gr1', 'members', BOB), {
    userId: BOB, status: 'joined',
  }));

  // Someone who wasn't kicked still can.
  const eve = dbFor(EVE);
  await assertSucceeds(updateDoc(doc(eve, 'groupRides', 'gr1'), { memberIds: [ALICE, EVE] }));
});

// ---------------------------------------------------------------------------
// §90.D5 / §90.D11 — forum counters
// ---------------------------------------------------------------------------

test('D5: a rider can delete their own post with the bound -1 (deletePost shape)', async () => {
  const db = dbFor(ALICE);
  const batch = writeBatch(db);
  batch.delete(doc(db, 'forums', 'f1', 'posts', 'p-alice'));
  batch.update(doc(db, 'forums', 'f1'), { postCount: increment(-1), lastPostId: 'p-alice' });
  await assertSucceeds(batch.commit());
});

test('D5: a bare postCount -1 is denied, even naming a real post', async () => {
  const db = dbFor(ALICE);
  await assertFails(updateDoc(doc(db, 'forums', 'f1'), { postCount: increment(-1) }));
  await assertFails(updateDoc(doc(db, 'forums', 'f1'), {
    postCount: increment(-1), lastPostId: 'p-alice',
  }));
});

test('D5: a stranger cannot delete someone else\'s post to drive the count down', async () => {
  const db = dbFor(MALLORY);
  const batch = writeBatch(db);
  batch.delete(doc(db, 'forums', 'f1', 'posts', 'p-alice'));
  batch.update(doc(db, 'forums', 'f1'), { postCount: increment(-1), lastPostId: 'p-alice' });
  await assertFails(batch.commit());
});

function postData(uid, overrides = {}) {
  return {
    forumId: 'f1', userId: uid, userName: 'Bob', userPhotoUrl: '',
    title: 'Title', body: 'Body', createdAt: serverTimestamp(),
    replyCount: 0, upvotes: 0, downvotes: 0,
    ...overrides,
  };
}

test('D11: createPost as one batch with the bound +1 succeeds', async () => {
  const db = dbFor(BOB);
  const postRef = doc(collection(db, 'forums', 'f1', 'posts'));
  const batch = writeBatch(db);
  batch.set(postRef, postData(BOB));
  batch.update(doc(db, 'forums', 'f1'), { postCount: increment(1), lastPostId: postRef.id });
  await assertSucceeds(batch.commit());
});

test('D11: a bare postCount +1, or one naming an existing post, is denied', async () => {
  const db = dbFor(BOB);
  await assertFails(updateDoc(doc(db, 'forums', 'f1'), { postCount: increment(1) }));
  await assertFails(updateDoc(doc(db, 'forums', 'f1'), {
    postCount: increment(1), lastPostId: 'p-alice',
  }));
});

test('D11: followForum / unfollowForum transactions still work', async () => {
  const db = dbFor(BOB);
  const followRef = doc(db, 'forum_follows', `${BOB}_f1`);
  const forumRef = doc(db, 'forums', 'f1');
  await assertSucceeds(runTransaction(db, async (tx) => {
    tx.set(followRef, { userId: BOB, forumId: 'f1', createdAt: serverTimestamp() });
    tx.update(forumRef, { followerCount: increment(1) });
  }));
  await assertSucceeds(runTransaction(db, async (tx) => {
    tx.delete(followRef);
    tx.update(forumRef, { followerCount: increment(-1) });
  }));
});

test('D11: a bare followerCount bump is denied in both directions', async () => {
  const db = dbFor(BOB);
  await assertFails(updateDoc(doc(db, 'forums', 'f1'), { followerCount: increment(1) }));
  await assertFails(updateDoc(doc(db, 'forums', 'f1'), { followerCount: increment(-1) }));
});

// ---------------------------------------------------------------------------
// §90.D6 — profile email pinned to the auth token
// ---------------------------------------------------------------------------

test('D6: ensureProfile writing the caller\'s own token email is allowed', async () => {
  const db = dbFor(BOB, { email: 'Bob@Example.com' });
  await assertSucceeds(setDoc(doc(db, 'users', BOB), {
    displayName: 'Bob',
    email: 'Bob@Example.com',
    emailLower: 'bob@example.com',
    visibility: 'public',
  }, { merge: true }));
});

test('D6: claiming somebody else\'s email is denied', async () => {
  const db = dbFor(MALLORY, { email: 'mallory@example.com' });
  await assertFails(setDoc(doc(db, 'users', MALLORY), {
    email: 'alice@example.com', emailLower: 'alice@example.com',
  }, { merge: true }));
  // A correct `email` with a forged `emailLower` (what search actually reads).
  await assertFails(setDoc(doc(db, 'users', MALLORY), {
    email: 'mallory@example.com', emailLower: 'alice@example.com',
  }, { merge: true }));
});

test('D6: a token with no email cannot set one at all', async () => {
  const db = dbFor(MALLORY);
  await assertFails(setDoc(doc(db, 'users', MALLORY), {
    emailLower: 'alice@example.com',
  }, { merge: true }));
});

test('D6: unrelated merge writes on a legacy doc still pass', async () => {
  const db = dbFor(ALICE, { email: 'different@example.com' });
  await assertSucceeds(setDoc(doc(db, 'users', ALICE), {
    visibility: 'mutual', updatedAt: serverTimestamp(),
  }, { merge: true }));
  // ...and dropping the email from the public doc is always allowed.
  await assertSucceeds(updateDoc(doc(db, 'users', ALICE), {
    email: deleteField(), emailLower: deleteField(),
  }));
});

// ---------------------------------------------------------------------------
// §90.D8 / §90.A11 — blocks and follow edges
// ---------------------------------------------------------------------------

async function aliceBlocksMallory() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', ALICE, 'blocks', MALLORY), {
      blockedAt: Timestamp.now(),
    });
  });
}

test('D8: a blocked follower can no longer read followers-only rides', async () => {
  // Before the block Mallory, as a follower, could.
  await assertSucceeds(getDoc(doc(dbFor(MALLORY), 'rides', 'r-followers')));
  await aliceBlocksMallory();
  const db = dbFor(MALLORY);
  await assertFails(getDoc(doc(db, 'rides', 'r-followers')));
  await assertFails(getDocs(query(
    collection(db, 'rides'),
    where('userId', '==', ALICE),
    where('audience', '==', 'followers'),
    orderBy('createdAt', 'desc'),
    limit(5),
  )));
  // An unblocked follower is unaffected, and the per-author query is still provable.
  await assertSucceeds(getDocs(query(
    collection(dbFor(BOB), 'rides'),
    where('userId', '==', ALICE),
    where('audience', '==', 'followers'),
    orderBy('createdAt', 'desc'),
    limit(5),
  )));
});

test('D8: the public feed query is unaffected by the block check', async () => {
  await aliceBlocksMallory();
  await assertSucceeds(getDocs(query(
    collection(dbFor(BOB), 'rides'),
    where('audience', '==', 'public'),
    orderBy('createdAt', 'desc'),
    limit(20),
  )));
});

test('D8: the block handler (block + drop both edges) runs as one transaction', async () => {
  const db = dbFor(ALICE);
  const theirs = doc(db, 'follows', `${MALLORY}_${ALICE}`);
  const mine = doc(db, 'follows', `${ALICE}_${MALLORY}`);
  await assertSucceeds(runTransaction(db, async (tx) => {
    const theirSnap = await tx.get(theirs);
    const mySnap = await tx.get(mine);
    tx.set(doc(db, 'users', ALICE, 'blocks', MALLORY), { blockedAt: serverTimestamp() });
    if (theirSnap.exists()) tx.delete(theirs);
    if (mySnap.exists()) tx.delete(mine);
  }));
});

test('D8: a third party cannot delete a follow edge between two others', async () => {
  await assertFails(deleteDoc(doc(dbFor(EVE), 'follows', `${BOB}_${ALICE}`)));
});

// ---------------------------------------------------------------------------
// §90.A4 / §90.D9 — users list queries
// ---------------------------------------------------------------------------

test('D9: an unfiltered users list (old getRecentUsers) is denied', async () => {
  await assertFails(getDocs(query(
    collection(dbFor(BOB), 'users'), orderBy('createdAt', 'desc'), limit(50),
  )));
});

test('D9: unfiltered username / email searches are denied', async () => {
  const db = dbFor(BOB);
  await assertFails(getDocs(query(collection(db, 'users'),
    where('usernameLower', '>=', 'e'), where('usernameLower', '<', 'e'), limit(20))));
  await assertFails(getDocs(query(collection(db, 'users'),
    where('emailLower', '==', 'eve@example.com'), limit(10))));
});

test('D9: public-only queries are allowed and never return a private profile', async () => {
  const db = dbFor(BOB);
  const recent = await assertSucceeds(getDocs(query(collection(db, 'users'),
    where('visibility', '==', 'public'), orderBy('createdAt', 'desc'), limit(50))));
  const ids = recent.docs.map((d) => d.id);
  if (!ids.includes(ALICE) || ids.includes(EVE)) throw new Error(`unexpected ${ids}`);

  const byName = await assertSucceeds(getDocs(query(collection(db, 'users'),
    where('visibility', '==', 'public'),
    where('usernameLower', '>=', 'e'), where('usernameLower', '<', 'e'), limit(20))));
  if (byName.size !== 0) throw new Error('private profile leaked through username search');

  const byEmail = await assertSucceeds(getDocs(query(collection(db, 'users'),
    where('visibility', '==', 'public'), where('emailLower', '==', 'eve@example.com'), limit(10))));
  if (byEmail.size !== 0) throw new Error('private profile leaked through email search');
});

test('D9: single-profile gets keep their visibility tiers', async () => {
  await assertSucceeds(getDoc(doc(dbFor(BOB), 'users', ALICE)));
  await assertFails(getDoc(doc(dbFor(BOB), 'users', EVE)));
});

// ---------------------------------------------------------------------------
// §90.D10 — names and photo URLs
// ---------------------------------------------------------------------------

test('D10: comments with a beacon photo or an oversized name are denied', async () => {
  await assertFails(addCommentTx(dbFor(BOB), BOB, 'r-followers', { userPhotoUrl: BEACON }));
  await assertFails(addCommentTx(dbFor(BOB), BOB, 'r-followers', { userName: 'x'.repeat(101) }));
  await assertSucceeds(addCommentTx(dbFor(BOB), BOB, 'r-followers', { userPhotoUrl: GOOGLE_PHOTO }));
});

test('D10: forum posts and replies with a beacon photo are denied', async () => {
  const db = dbFor(BOB);
  await assertFails(setDoc(doc(db, 'forums', 'f1', 'posts', 'p2'), postData(BOB, { userPhotoUrl: BEACON })));
  await assertFails(setDoc(doc(db, 'forums', 'f1', 'posts', 'p2'), postData(BOB, { extra: 1 })));

  const postRef = doc(db, 'forums', 'f1', 'posts', 'p-alice');
  const reply = (overrides) => {
    const replyRef = doc(collection(postRef, 'replies'));
    return runTransaction(db, async (tx) => {
      tx.set(replyRef, {
        postId: 'p-alice', forumId: 'f1', userId: BOB, userName: 'Bob',
        userPhotoUrl: GOOD_PHOTO, body: 'hi', createdAt: serverTimestamp(), ...overrides,
      });
      tx.update(postRef, { replyCount: increment(1), lastReplyId: replyRef.id });
    });
  };
  await assertSucceeds(reply({}));
  await assertFails(reply({ userPhotoUrl: BEACON }));
  await assertFails(reply({ userName: 'x'.repeat(101) }));
});

test('D10: voice notes with a beacon sender photo or a foreign Cloudinary audio URL are denied', async () => {
  const db = dbFor(BOB);
  const note = (overrides) => addDoc(collection(db, 'groupRides', 'gr1', 'voiceNotes'), {
    senderId: BOB, senderName: 'Bob', senderPhotoUrl: '',
    audioUrl: 'https://res.cloudinary.com/vjvcigkt/video/upload/v1/voiceNotes/bob-uid/gr1/clip.m4a',
    durationMs: 2000, createdAt: serverTimestamp(), ...overrides,
  });
  await assertSucceeds(note({}));
  await assertFails(note({ senderPhotoUrl: BEACON }));
  await assertFails(note({ senderName: '' }));
  await assertFails(note({ audioUrl: 'https://res.cloudinary.com/someoneelse/video/upload/x.m4a' }));
});

test('D10: a profile photoUrl must be allow-listed when it changes', async () => {
  const db = dbFor(ALICE, { email: 'alice@example.com' });
  await assertSucceeds(setDoc(doc(db, 'users', ALICE), { photoUrl: GOOD_PHOTO }, { merge: true }));
  await assertFails(setDoc(doc(db, 'users', ALICE), { photoUrl: BEACON }, { merge: true }));
  await assertFails(setDoc(doc(db, 'users', ALICE), { displayName: 'x'.repeat(101) }, { merge: true }));
});

test('D10: a legacy off-list photoUrl does not block unrelated profile writes', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'users', ALICE), { photoUrl: BEACON });
  });
  const db = dbFor(ALICE, { email: 'alice@example.com' });
  await assertSucceeds(setDoc(doc(db, 'users', ALICE), { bio: 'hi' }, { merge: true }));
});

// ---------------------------------------------------------------------------
// §90.A9 — deterministic follow notification (`follow_{fromUid}`), re-set on
// every re-follow
// ---------------------------------------------------------------------------

function followNotif(fromUid, overrides = {}) {
  return {
    type: 'follow', fromUid, fromName: 'Bob', fromPhotoUrl: null,
    createdAt: serverTimestamp(), read: false, ...overrides,
  };
}

test('A9: the follower can create, then re-set, their own follow notification', async () => {
  const db = dbFor(BOB);
  const ref = doc(db, 'users', ALICE, 'notifications', `follow_${BOB}`);
  await assertSucceeds(setDoc(ref, followNotif(BOB)));
  await assertSucceeds(setDoc(ref, followNotif(BOB)));
});

test('A9: a re-set cannot change shape, and nobody else can rewrite it', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', ALICE, 'notifications', `follow_${BOB}`),
      { type: 'follow', fromUid: BOB, fromName: 'Bob', read: true });
  });
  const bob = dbFor(BOB);
  const ref = doc(bob, 'users', ALICE, 'notifications', `follow_${BOB}`);
  await assertFails(setDoc(ref, followNotif(BOB, { fromPhotoUrl: BEACON })));
  await assertFails(setDoc(ref, followNotif(BOB, { type: 'groupRideInvite', groupRideId: 'gr1' })));
  // Mallory can't hijack Bob's row, nor update a non-follow id of her own.
  const mallory = dbFor(MALLORY);
  await assertFails(setDoc(doc(mallory, 'users', ALICE, 'notifications', `follow_${BOB}`),
    followNotif(MALLORY)));
  // The owner can still mark it read.
  await assertSucceeds(updateDoc(doc(dbFor(ALICE), 'users', ALICE, 'notifications', `follow_${BOB}`),
    { read: true }));
});
