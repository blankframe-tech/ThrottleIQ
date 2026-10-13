'use strict';

/**
 * Security-rules tests for the issues §101 (group G1) tightenings in
 * `firestore.rules`.
 *
 * Every "succeeds" case below is the exact payload the shipped app writes
 * (repository named in the test), so a tightening that would break a real
 * client write fails here, not in production. Every "denied" case is the
 * hole the tightening closes. Own projectId so `node --test` can run this
 * file in parallel with the others.
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
  collection,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
  writeBatch,
  increment,
  Timestamp,
  serverTimestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const MALLORY = 'mallory-uid';
const PLACE_ID = 'place-1';
const DM_ID = `${ALICE}_${MALLORY}`; // sorted: 'alice-uid' < 'mallory-uid'
const LIVE_TOKEN = 'c'.repeat(32);
const HOUR = 60 * 60_000;

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-audit101',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'places', PLACE_ID), {
      name: 'Central Moto Works',
      createdBy: ALICE,
      verified: false,
      ratingSum: 0,
      ratingCount: 0,
    });
    // Alice's followers-only share; BOB follows her, MALLORY does not.
    await setDoc(doc(db, 'rides', 'r-followers'), {
      userId: ALICE,
      audience: 'followers',
      allowedUserIds: [],
      comments: 0,
      upvotes: 0,
      downvotes: 0,
    });
    await setDoc(doc(db, 'follows', `${BOB}_${ALICE}`), {
      followerId: BOB,
      followingId: ALICE,
    });
    await setDoc(doc(db, 'forums', 'f1'), { name: 'Test forum', postCount: 0 });
    await setDoc(doc(db, 'forums', 'f1', 'posts', 'p1'), {
      userId: ALICE, title: 't', body: 'b', replyCount: 0, upvotes: 0, downvotes: 0,
    });
    await setDoc(doc(db, 'chats', DM_ID), {
      participants: [ALICE, MALLORY],
      updatedAt: new Date(),
    });
    await setDoc(doc(db, 'liveSessions', LIVE_TOKEN), {
      uid: ALICE,
      rideId: 'ride-1',
      active: true,
      status: 'riding',
      shareable: true,
      expiresAt: Timestamp.fromMillis(Date.now() + 24 * HOUR),
      updatedAt: Timestamp.now(),
    });
  });
});

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

// ---------------------------------------------------------------------------
// §101.S1 — places rating bump must ship in the same commit as the review
// ---------------------------------------------------------------------------

/** ReviewModel.toFirestore's shape. */
function review(uid, stars) {
  return {
    placeId: PLACE_ID,
    userId: uid,
    stars,
    text: 'Solid mechanic',
    imageUrls: [],
    createdAt: Timestamp.now(),
    flagged: false,
  };
}

/** Exactly ReviewRepository.addReviewAndUpdatePlaceRating's transaction. */
function addReviewTx(db, uid, stars, { bump = stars } = {}) {
  const placeRef = doc(db, 'places', PLACE_ID);
  const reviewRef = doc(db, 'reviews', `${uid}_${PLACE_ID}`);
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(placeRef);
    const data = snap.data();
    tx.set(reviewRef, review(uid, stars));
    tx.update(placeRef, {
      ratingSum: data.ratingSum + bump,
      ratingCount: data.ratingCount + 1,
    });
  });
}

test('S1: review + rating bump in one transaction succeeds', async () => {
  await assertSucceeds(addReviewTx(dbFor(BOB), BOB, 4));
});

test('S1: the same thing as a write batch also succeeds', async () => {
  const db = dbFor(BOB);
  const batch = writeBatch(db);
  batch.set(doc(db, 'reviews', `${BOB}_${PLACE_ID}`), review(BOB, 3));
  batch.update(doc(db, 'places', PLACE_ID), { ratingSum: 3, ratingCount: 1 });
  await assertSucceeds(batch.commit());
});

test('S1: replaying the bump after the review already exists is denied', async () => {
  const db = dbFor(BOB);
  await assertSucceeds(addReviewTx(db, BOB, 5));
  // The replay the old rule allowed: the review exists and its stars match.
  await assertFails(
    updateDoc(doc(db, 'places', PLACE_ID), { ratingSum: 10, ratingCount: 2 })
  );
});

test('S1: the old two-step flow (review first, bump second) now fails on the bump', async () => {
  const db = dbFor(BOB);
  await assertSucceeds(setDoc(doc(db, 'reviews', `${BOB}_${PLACE_ID}`), review(BOB, 4)));
  await assertFails(
    updateDoc(doc(db, 'places', PLACE_ID), { ratingSum: 4, ratingCount: 1 })
  );
});

test('S1: a bump with no review at all is denied', async () => {
  await assertFails(
    updateDoc(doc(dbFor(BOB), 'places', PLACE_ID), { ratingSum: 5, ratingCount: 1 })
  );
});

test("S1: a bump whose delta differs from the review's stars is denied", async () => {
  await assertFails(addReviewTx(dbFor(BOB), BOB, 1, { bump: 5 }));
});

test('S1: a second review by the same rider (same deterministic id) is denied', async () => {
  const db = dbFor(BOB);
  await assertSucceeds(addReviewTx(db, BOB, 4));
  await assertFails(addReviewTx(db, BOB, 5));
});

// ---------------------------------------------------------------------------
// §101.S3 — usernames handle format + {uid} only
// ---------------------------------------------------------------------------

test('S3 usernames: a valid handle claimed as {uid} succeeds', async () => {
  await assertSucceeds(setDoc(doc(dbFor(BOB), 'usernames', 'bob_rider_99'), { uid: BOB }));
});

test('S3 usernames: badly formatted handles are denied', async () => {
  const db = dbFor(BOB);
  for (const handle of ['Bob', 'bo', 'bob-rider', 'bob.rider', 'b'.repeat(21), 'bób']) {
    await assertFails(setDoc(doc(db, 'usernames', handle), { uid: BOB }));
  }
  // 20 is still allowed (the client's upper bound).
  await assertSucceeds(setDoc(doc(db, 'usernames', 'b'.repeat(20)), { uid: BOB }));
});

test('S3 usernames: extra keys are denied on create and update', async () => {
  const db = dbFor(BOB);
  await assertFails(setDoc(doc(db, 'usernames', 'bobby'), { uid: BOB, note: 'x' }));
  await assertSucceeds(setDoc(doc(db, 'usernames', 'bobby'), { uid: BOB }));
  await assertSucceeds(setDoc(doc(db, 'usernames', 'bobby'), { uid: BOB })); // re-claim (setUsername)
  await assertFails(setDoc(doc(db, 'usernames', 'bobby'), { uid: BOB, note: 'x' }));
});

// ---------------------------------------------------------------------------
// §101.S3 — ride likes closed, ride/forum votes visibility + shape
// ---------------------------------------------------------------------------

test('S3 likes: creating a like is denied even on a public-to-you ride', async () => {
  await assertFails(
    setDoc(doc(dbFor(BOB), 'rides', 'r-followers', 'likes', BOB), { likedAt: 1 })
  );
});

test('S3 likes: the owner can still list and sweep legacy likes', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'rides', 'r-followers', 'likes', BOB), { userId: BOB });
  });
  const db = dbFor(ALICE);
  const likes = await getDocs(collection(doc(db, 'rides', 'r-followers'), 'likes'));
  await assertSucceeds(Promise.all(likes.docs.map((d) => deleteDoc(d.ref))));
});

/** RideShareRepository.vote's fresh-vote transaction. */
function rideVoteTx(db, uid, voteDoc) {
  const rideRef = doc(db, 'rides', 'r-followers');
  return runTransaction(db, async (tx) => {
    await tx.get(doc(rideRef, 'votes', uid));
    tx.set(doc(rideRef, 'votes', uid), voteDoc);
    tx.update(rideRef, { upvotes: increment(1) });
  });
}

test('S3 votes: a follower can vote on a followers ride', async () => {
  await assertSucceeds(rideVoteTx(dbFor(BOB), BOB, { value: 1 }));
});

test('S3 votes: a follower can flip an existing ride vote (-1 to 1, an update)', async () => {
  // RideShareRepository.vote's flip branch: set over the existing vote doc
  // and move both tallies in the same transaction.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'rides', 'r-followers', 'votes', BOB), { value: -1 });
  });
  const db = dbFor(BOB);
  const rideRef = doc(db, 'rides', 'r-followers');
  await assertSucceeds(
    runTransaction(db, async (tx) => {
      await tx.get(doc(rideRef, 'votes', BOB));
      tx.set(doc(rideRef, 'votes', BOB), { value: 1 });
      tx.update(rideRef, { upvotes: increment(1), downvotes: increment(-1) });
    })
  );
});

test('S3 votes: flipping a ride vote with extra keys or a bad value is denied', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'rides', 'r-followers', 'votes', BOB), { value: -1 });
  });
  const voteRef = doc(dbFor(BOB), 'rides', 'r-followers', 'votes', BOB);
  await assertFails(setDoc(voteRef, { value: 1, junk: 'x' }));
  await assertFails(setDoc(voteRef, { value: 2 }));
});

test('S3 votes: a stranger cannot plant a vote doc on a followers ride', async () => {
  await assertFails(
    setDoc(doc(dbFor(MALLORY), 'rides', 'r-followers', 'votes', MALLORY), { value: 1 })
  );
});

test('S3 votes: extra keys on a ride vote are denied', async () => {
  await assertFails(
    setDoc(doc(dbFor(BOB), 'rides', 'r-followers', 'votes', BOB), { value: 1, junk: 'x' })
  );
});

test('S3 votes: a rider can delete their vote even after losing visibility', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'rides', 'r-followers', 'votes', MALLORY), { value: 1 });
  });
  await assertSucceeds(deleteDoc(doc(dbFor(MALLORY), 'rides', 'r-followers', 'votes', MALLORY)));
});

test('S3 votes: forum post votes accept exactly {value}', async () => {
  const db = dbFor(BOB);
  const voteRef = doc(db, 'forums', 'f1', 'posts', 'p1', 'votes', BOB);
  await assertFails(setDoc(voteRef, { value: 1, junk: 'x' }));
  await assertFails(setDoc(voteRef, { value: 2 }));
  await assertSucceeds(setDoc(voteRef, { value: -1 }));
  // Flip (-1 -> 1) is an update of the existing doc: same allow-list.
  await assertFails(setDoc(voteRef, { value: 1, junk: 'x' }));
  await assertFails(setDoc(voteRef, { value: 2 }));
  await assertSucceeds(setDoc(voteRef, { value: 1 }));
  await assertSucceeds(deleteDoc(voteRef));
});

// ---------------------------------------------------------------------------
// §101.S3 — forum post/reply title/body type + caps, server createdAt
// ---------------------------------------------------------------------------

function post(overrides = {}) {
  return {
    forumId: 'f1', userId: BOB, userName: 'Bob', userPhotoUrl: '',
    title: 'Chain slack', body: 'How tight?', createdAt: serverTimestamp(),
    replyCount: 0, upvotes: 0, downvotes: 0, postType: 'general', isSolved: false,
    ...overrides,
  };
}

test('S3 forum: a normal post succeeds, and a 300-char title / 20000-char body is the cap', async () => {
  const db = dbFor(BOB);
  await assertSucceeds(setDoc(doc(db, 'forums', 'f1', 'posts', 'a'), post()));
  await assertSucceeds(
    setDoc(doc(db, 'forums', 'f1', 'posts', 'b'), post({ title: 't'.repeat(300), body: 'b'.repeat(20000) }))
  );
});

test('S3 forum: oversize, empty or non-string title/body is denied', async () => {
  const db = dbFor(BOB);
  const ref = doc(db, 'forums', 'f1', 'posts', 'c');
  await assertFails(setDoc(ref, post({ title: 't'.repeat(301) })));
  await assertFails(setDoc(ref, post({ title: '' })));
  await assertFails(setDoc(ref, post({ title: 42 })));
  await assertFails(setDoc(ref, post({ body: 'b'.repeat(20001) })));
  await assertFails(setDoc(ref, post({ body: { nested: true } })));
});

test('S3 forum: a post stamped with a client clock is denied', async () => {
  await assertFails(
    setDoc(doc(dbFor(BOB), 'forums', 'f1', 'posts', 'd'), post({ createdAt: Timestamp.now() }))
  );
});

/** ForumRepository.addReply's transaction. */
function replyTx(db, overrides = {}) {
  const postRef = doc(db, 'forums', 'f1', 'posts', 'p1');
  const replyRef = doc(collection(postRef, 'replies'));
  return runTransaction(db, async (tx) => {
    tx.set(replyRef, {
      postId: 'p1', forumId: 'f1', userId: BOB, userName: 'Bob', userPhotoUrl: '',
      body: 'About 25mm', createdAt: serverTimestamp(), ...overrides,
    });
    tx.update(postRef, { replyCount: increment(1), lastReplyId: replyRef.id });
  });
}

test('S3 forum: a normal reply succeeds', async () => {
  await assertSucceeds(replyTx(dbFor(BOB)));
});

test('S3 forum: an empty, oversize, non-string or client-clock reply is denied', async () => {
  const db = dbFor(BOB);
  await assertFails(replyTx(db, { body: '' }));
  await assertFails(replyTx(db, { body: 'b'.repeat(20001) }));
  await assertFails(replyTx(db, { body: ['x'] }));
  await assertFails(replyTx(db, { createdAt: Timestamp.now() }));
});

// ---------------------------------------------------------------------------
// §101.S3 — chat messages + chats.lastMessage
// ---------------------------------------------------------------------------

/** Exactly ChatRepository.sendMessage's batch. */
function sendMessageBatch(db, { message = {}, last = {}, updatedAt = serverTimestamp() } = {}) {
  const chatRef = doc(db, 'chats', DM_ID);
  const msgRef = doc(collection(chatRef, 'messages'));
  const text = message.text ?? 'On my way';
  const batch = writeBatch(db);
  batch.set(msgRef, {
    senderId: ALICE, text, createdAt: serverTimestamp(), isRead: false, ...message,
  });
  batch.update(chatRef, {
    lastMessage: { senderId: ALICE, text, createdAt: serverTimestamp(), ...last },
    updatedAt,
  });
  return batch.commit();
}

test('S3 chat: the real sendMessage batch succeeds', async () => {
  await assertSucceeds(sendMessageBatch(dbFor(ALICE)));
});

test('S3 chat: presetting isToxic (or any extra key) on a message is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(sendMessageBatch(db, { message: { isToxic: false } }));
  await assertFails(
    setDoc(doc(db, 'chats', DM_ID, 'messages', 'm1'), {
      senderId: ALICE, text: 'hi', createdAt: serverTimestamp(), isRead: false, isToxic: false,
    })
  );
});

test('S3 chat: empty or 5001-character text is denied; 5000 is the cap', async () => {
  const db = dbFor(ALICE);
  const msg = (text) => setDoc(doc(collection(db, 'chats', DM_ID, 'messages')), {
    senderId: ALICE, text, createdAt: serverTimestamp(), isRead: false,
  });
  await assertFails(msg(''));
  await assertFails(msg('x'.repeat(5001)));
  await assertFails(msg(7));
  await assertSucceeds(msg('x'.repeat(5000)));
});

test('S3 chat: a client-clock createdAt or isRead:true on a message is denied', async () => {
  const db = dbFor(ALICE);
  const ref = doc(db, 'chats', DM_ID, 'messages', 'm2');
  await assertFails(setDoc(ref, { senderId: ALICE, text: 'hi', createdAt: Timestamp.now(), isRead: false }));
  await assertFails(setDoc(ref, { senderId: ALICE, text: 'hi', createdAt: serverTimestamp(), isRead: true }));
});

test('S3 chat: the existing block check still binds', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', MALLORY, 'blocks', ALICE), { blockedAt: new Date() });
  });
  await assertFails(sendMessageBatch(dbFor(ALICE)));
});

test('S3 chat: lastMessage with a spoofed senderId is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    updateDoc(doc(db, 'chats', DM_ID), {
      lastMessage: { senderId: MALLORY, text: 'I owe Alice money', createdAt: serverTimestamp() },
      updatedAt: serverTimestamp(),
    })
  );
});

test('S3 chat: oversize lastMessage text, extra keys or client clocks are denied', async () => {
  const db = dbFor(ALICE);
  const upd = (lastMessage, updatedAt = serverTimestamp()) =>
    updateDoc(doc(db, 'chats', DM_ID), { lastMessage, updatedAt });
  await assertFails(upd({ senderId: ALICE, text: 'x'.repeat(5001), createdAt: serverTimestamp() }));
  await assertFails(upd({ senderId: ALICE, text: 'hi', createdAt: serverTimestamp(), extra: 1 }));
  await assertFails(upd({ senderId: ALICE, text: 'hi', createdAt: Timestamp.now() }));
  await assertFails(upd({ senderId: ALICE, text: 'hi', createdAt: serverTimestamp() }, Timestamp.now()));
  await assertFails(upd('just a string'));
});

// ---------------------------------------------------------------------------
// §101.S3 — liveSessions uid pinned, expiresAt bounded
// ---------------------------------------------------------------------------

/** LiveSessionEntity.toFirestore + the coordinator's server updatedAt. */
function liveSession(uid, overrides = {}) {
  return {
    uid,
    rideId: 'ride-2',
    active: true,
    status: 'riding',
    shareable: true,
    lastLat: 23.8,
    lastLng: 90.4,
    expiresAt: Timestamp.fromMillis(Date.now() + 24 * HOUR),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

test('S3 live: publishing a session with now+24h succeeds (create and re-publish)', async () => {
  const db = dbFor(BOB);
  const ref = doc(db, 'liveSessions', 'd'.repeat(32));
  await assertSucceeds(setDoc(ref, liveSession(BOB)));
  await assertSucceeds(setDoc(ref, liveSession(BOB)));
});

test('S3 live: expiresAt 30 days out is denied on create and update', async () => {
  const far = Timestamp.fromMillis(Date.now() + 30 * 24 * HOUR);
  await assertFails(
    setDoc(doc(dbFor(BOB), 'liveSessions', 'e'.repeat(32)), liveSession(BOB, { expiresAt: far }))
  );
  await assertFails(updateDoc(doc(dbFor(ALICE), 'liveSessions', LIVE_TOKEN), { expiresAt: far }));
});

test('S3 live: the owner cannot hand the session to another uid', async () => {
  await assertFails(updateDoc(doc(dbFor(ALICE), 'liveSessions', LIVE_TOKEN), { uid: MALLORY }));
  await assertFails(
    setDoc(doc(dbFor(BOB), 'liveSessions', 'f'.repeat(32)), liveSession(MALLORY))
  );
});

test('S3 live: status / shareable updates still succeed', async () => {
  const db = dbFor(ALICE);
  const ref = doc(db, 'liveSessions', LIVE_TOKEN);
  await assertSucceeds(updateDoc(ref, { status: 'paused', active: true, updatedAt: serverTimestamp() }));
  await assertSucceeds(
    updateDoc(ref, { status: 'completed', active: false, shareable: false, updatedAt: serverTimestamp() })
  );
});

// ---------------------------------------------------------------------------
// §101.S3 — crashNotifications shape (safety-critical: real payloads MUST pass)
// ---------------------------------------------------------------------------

/** Exactly CrashCoordinator's write. */
function crash(uid, rideId, overrides = {}) {
  return {
    uid,
    rideId,
    timestamp: new Date().toISOString(),
    lastLat: 23.8103,
    lastLng: 90.4125,
    status: 'pending',
    ...overrides,
  };
}

test('S3 crash: the client payload with real coordinates succeeds', async () => {
  await assertSucceeds(setDoc(doc(dbFor(BOB), 'crashNotifications', 'cr1'), crash(BOB, 'cr1')));
});

test('S3 crash: the client payload with null coordinates (no GPS fix) succeeds', async () => {
  await assertSucceeds(
    setDoc(doc(dbFor(BOB), 'crashNotifications', 'cr2'), crash(BOB, 'cr2', { lastLat: null, lastLng: null }))
  );
});

test('S3 crash: integer coordinates (Dart double that happens to be whole) succeed', async () => {
  await assertSucceeds(
    setDoc(doc(dbFor(BOB), 'crashNotifications', 'cr3'), crash(BOB, 'cr3', { lastLat: 23, lastLng: 90 }))
  );
});

test('S3 crash: string or out-of-range coordinates are denied', async () => {
  const db = dbFor(BOB);
  const ref = doc(db, 'crashNotifications', 'cr4');
  await assertFails(setDoc(ref, crash(BOB, 'cr4', { lastLat: '23.8"><script>' })));
  await assertFails(setDoc(ref, crash(BOB, 'cr4', { lastLng: '90.4' })));
  await assertFails(setDoc(ref, crash(BOB, 'cr4', { lastLat: 91 })));
  await assertFails(setDoc(ref, crash(BOB, 'cr4', { lastLng: -181 })));
});

test('S3 crash: extra keys or a non-string timestamp are denied', async () => {
  const db = dbFor(BOB);
  const ref = doc(db, 'crashNotifications', 'cr5');
  await assertFails(setDoc(ref, crash(BOB, 'cr5', { contactPhone: '+8801700000000' })));
  await assertFails(setDoc(ref, crash(BOB, 'cr5', { timestamp: Timestamp.now() })));
});

// ---------------------------------------------------------------------------
// §101.S3 — groupRideJoinCodes tied to the ride created in the same batch
// ---------------------------------------------------------------------------

/** GroupRideModel.toFirestore's fields that matter to the rules. */
function groupRide(creatorId, joinCode, invitedIds = []) {
  return {
    creatorId,
    creatorName: 'Bob',
    name: "Bob's ride",
    startTime: new Date(),
    status: 'planned',
    memberIds: [creatorId],
    invitedIds,
    createdAt: new Date(),
    maxParticipants: 20,
    joinCode,
    lastActiveAt: new Date(),
  };
}

/** GroupRideMemberModel.toDocument for a roster row. */
function rosterRow(userId, userName, status) {
  return {
    userId, userName, userPhotoUrl: '', joinedAt: new Date(), status,
    currentLat: null, currentLng: null, lastLocationUpdate: null,
  };
}

test('S3 join codes: the real createGroupRide batch succeeds (with invitees)', async () => {
  // GroupRideRepository.createGroupRide: ride + creator row + one `pending`
  // row per invitee + the join code, all in one batch.
  const db = dbFor(BOB);
  const rideRef = doc(collection(db, 'groupRides'));
  const batch = writeBatch(db);
  batch.set(rideRef, groupRide(BOB, 'QX7K2M', [ALICE, MALLORY]));
  batch.set(doc(rideRef, 'members', BOB), rosterRow(BOB, 'Bob', 'joined'));
  batch.set(doc(rideRef, 'members', ALICE), rosterRow(ALICE, 'Alice', 'pending'));
  batch.set(doc(rideRef, 'members', MALLORY), rosterRow(MALLORY, 'Mallory', 'pending'));
  batch.set(doc(db, 'groupRideJoinCodes', 'QX7K2M'), {
    groupRideId: rideRef.id,
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
});

test("S3 join codes: a code pointing at someone else's ride is denied", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'groupRides', 'gr-alice'), groupRide(ALICE, 'AL1CE9'));
  });
  await assertFails(
    setDoc(doc(dbFor(MALLORY), 'groupRideJoinCodes', 'AL1CE9'), {
      groupRideId: 'gr-alice',
      createdAt: serverTimestamp(),
    })
  );
});

test('S3 join codes: a code for a missing ride, or one not matching the ride\'s joinCode, is denied', async () => {
  const db = dbFor(BOB);
  await assertFails(
    setDoc(doc(db, 'groupRideJoinCodes', 'NOPE01'), { groupRideId: 'ghost', createdAt: serverTimestamp() })
  );
  const rideRef = doc(collection(db, 'groupRides'));
  const batch = writeBatch(db);
  batch.set(rideRef, groupRide(BOB, 'REAL01'));
  batch.set(doc(db, 'groupRideJoinCodes', 'SQUAT1'), {
    groupRideId: rideRef.id,
    createdAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});

// ---------------------------------------------------------------------------
// §101.S3 — reports shape
// ---------------------------------------------------------------------------

/** ReportModel.toFirestore. */
function report(overrides = {}) {
  return {
    reporterId: BOB,
    reportedId: MALLORY,
    contentType: 'chat',
    contentId: DM_ID,
    reason: 'Harassment or bullying',
    createdAt: serverTimestamp(),
    status: 'pending',
    ...overrides,
  };
}

test('S3 reports: a real report succeeds, with or without details, for every contentType', async () => {
  const db = dbFor(BOB);
  for (const contentType of ['post', 'chat', 'ride', 'user']) {
    await assertSucceeds(setDoc(doc(collection(db, 'reports')), report({ contentType })));
  }
  await assertSucceeds(
    setDoc(doc(collection(db, 'reports')), report({ additionalDetails: 'Kept messaging after I said stop' }))
  );
});

test('S3 reports: unknown contentType, extra keys, oversize fields or a client clock are denied', async () => {
  const db = dbFor(BOB);
  const ref = () => doc(collection(db, 'reports'));
  await assertFails(setDoc(ref(), report({ contentType: 'forum_reply' })));
  await assertFails(setDoc(ref(), report({ priority: 'urgent' })));
  await assertFails(setDoc(ref(), report({ additionalDetails: 'x'.repeat(2001) })));
  await assertFails(setDoc(ref(), report({ additionalDetails: 12 })));
  await assertFails(setDoc(ref(), report({ reason: 'x'.repeat(101) })));
  await assertFails(setDoc(ref(), report({ contentId: 'x'.repeat(201) })));
  await assertFails(setDoc(ref(), report({ reportedId: 'x'.repeat(129) })));
  await assertFails(setDoc(ref(), report({ createdAt: Timestamp.now() })));
});
