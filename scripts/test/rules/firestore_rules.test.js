'use strict';

/**
 * Security-rules tests for the engagement-counter clauses in
 * `firestore.rules` — docs/Issues.md §24.7.
 *
 * These need the Firestore emulator, which needs a JVM. There is no `java` on
 * PATH on this machine (the `/usr/bin/java` stub is Apple's, and it fails), but
 * Android Studio ships a JBR — so the runner script points `JAVA_HOME` at it.
 * That is also why this file lives under `test/rules/` rather than `test/`:
 * `npm test`'s glob is `test/*.test.js`, deliberately non-recursive, so the
 * pure-function tests keep running with no emulator involved.
 *
 * Run with:  npm run test:rules   (from scripts/)
 *
 * What's actually being pinned down here is the fix's central claim: a counter
 * may only move when the doc it claims to count is created in the SAME commit.
 * The negative cases matter more than the positive one — a rule that allows
 * legitimate traffic but also allows the attack is the bug being fixed.
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
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  increment,
  runTransaction,
  writeBatch,
  Timestamp,
  serverTimestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const MALLORY = 'mallory-uid';
const STRANGER = 'stranger-uid';
const RIDE_ID = 'ride-1';
const FORUM_ID = 'forum-1';
const POST_ID = 'post-1';
const GROUP_RIDE_ID = 'group-ride-1';
const JOIN_CODE = 'AB12CD';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed with rules bypassed: these fixtures stand in for state that got there
  // legitimately, and seeding them through the rules would just be testing the
  // create rules a second time.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'rides', RIDE_ID), {
      userId: ALICE,
      audience: 'public',
      allowedUserIds: [],
      likes: 0,
      comments: 0,
      upvotes: 0,
      downvotes: 0,
      userName: 'Alice',
      userPhotoUrl: '',
    });
    await setDoc(doc(db, 'forums', FORUM_ID), { name: 'Test forum' });
    await setDoc(doc(db, 'forums', FORUM_ID, 'posts', POST_ID), {
      userId: ALICE,
      title: 'Test post',
      replyCount: 0,
      upvotes: 0,
      downvotes: 0,
    });
    // Alice is the creator and only joined member; Mallory is invited but
    // has not accepted — the shape voiceNotes' create rule needs to tell
    // "joined" from "merely invited" apart.
    await setDoc(doc(db, 'groupRides', GROUP_RIDE_ID), {
      creatorId: ALICE,
      creatorName: 'Alice',
      name: "Alice's group ride",
      startTime: new Date(),
      status: 'active',
      memberIds: [ALICE],
      invitedIds: [MALLORY],
      createdAt: new Date(),
      maxParticipants: 20,
      joinCode: JOIN_CODE,
    });
    await setDoc(doc(db, 'groupRideJoinCodes', JOIN_CODE), {
      groupRideId: GROUP_RIDE_ID,
      createdAt: new Date(),
    });
  });
});

/** A signed-in Firestore handle for `uid`. */
function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

// ---------------------------------------------------------------------------
// rides/{rideId}.comments — §24.7 residual
// ---------------------------------------------------------------------------

test('comment bump succeeds when the comment is created in the same transaction', async () => {
  const db = dbFor(MALLORY);
  const rideRef = doc(db, 'rides', RIDE_ID);
  const commentRef = doc(collection(rideRef, 'comments'));

  // Exactly the shape RideShareRepository.addComment() now writes.
  await assertSucceeds(
    runTransaction(db, async (tx) => {
      tx.set(commentRef, { userId: MALLORY, text: 'nice ride', rideId: RIDE_ID });
      tx.update(rideRef, { comments: increment(1), lastCommentId: commentRef.id });
    })
  );
});

test('comment bump alone, with no comment doc, is denied', async () => {
  // The actual §24.7 attack: loop this and the count goes anywhere.
  const db = dbFor(MALLORY);
  await assertFails(
    updateDoc(doc(db, 'rides', RIDE_ID), { comments: increment(1) })
  );
});

test('comment bump naming a comment that already existed is denied', async () => {
  // The replay variant: post one real comment, then keep bumping while
  // pointing at it. `!exists(...)` in newDocBy() is what stops this.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(ctx.firestore(), 'rides', RIDE_ID, 'comments', 'existing-comment'),
      { userId: MALLORY, text: 'earlier' }
    );
  });

  const db = dbFor(MALLORY);
  await assertFails(
    updateDoc(doc(db, 'rides', RIDE_ID), {
      comments: increment(1),
      lastCommentId: 'existing-comment',
    })
  );
});

test('comment bump naming a nonexistent comment is denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(
    updateDoc(doc(db, 'rides', RIDE_ID), {
      comments: increment(1),
      lastCommentId: 'no-such-comment',
    })
  );
});

test('comment bump larger than +1 is denied even with a real comment', async () => {
  const db = dbFor(MALLORY);
  const rideRef = doc(db, 'rides', RIDE_ID);
  const commentRef = doc(collection(rideRef, 'comments'));

  await assertFails(
    runTransaction(db, async (tx) => {
      tx.set(commentRef, { userId: MALLORY, text: 'hi', rideId: RIDE_ID });
      tx.update(rideRef, { comments: increment(50), lastCommentId: commentRef.id });
    })
  );
});

test('comment bump cannot smuggle another field along with it', async () => {
  const db = dbFor(MALLORY);
  const rideRef = doc(db, 'rides', RIDE_ID);
  const commentRef = doc(collection(rideRef, 'comments'));

  await assertFails(
    runTransaction(db, async (tx) => {
      tx.set(commentRef, { userId: MALLORY, text: 'hi', rideId: RIDE_ID });
      tx.update(rideRef, {
        comments: increment(1),
        lastCommentId: commentRef.id,
        userName: 'Not Alice',
      });
    })
  );
});

test('a second bump reusing the first transaction id is denied', async () => {
  const db = dbFor(MALLORY);
  const rideRef = doc(db, 'rides', RIDE_ID);
  const commentRef = doc(collection(rideRef, 'comments'));

  await assertSucceeds(
    runTransaction(db, async (tx) => {
      tx.set(commentRef, { userId: MALLORY, text: 'hi', rideId: RIDE_ID });
      tx.update(rideRef, { comments: increment(1), lastCommentId: commentRef.id });
    })
  );

  // Same id, second time round: the comment now exists, so !exists() fails.
  await assertFails(
    updateDoc(rideRef, { comments: increment(1), lastCommentId: commentRef.id })
  );
});

// ---------------------------------------------------------------------------
// forums/{forumId}/posts/{postId}.replyCount — §24.7 residual
// ---------------------------------------------------------------------------

test('reply bump succeeds when the reply is created in the same transaction', async () => {
  const db = dbFor(MALLORY);
  const postRef = doc(db, 'forums', FORUM_ID, 'posts', POST_ID);
  const replyRef = doc(collection(postRef, 'replies'));

  await assertSucceeds(
    runTransaction(db, async (tx) => {
      tx.set(replyRef, { userId: MALLORY, body: 'agreed', postId: POST_ID, forumId: FORUM_ID });
      tx.update(postRef, { replyCount: increment(1), lastReplyId: replyRef.id });
    })
  );
});

test('reply bump alone, with no reply doc, is denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(
    updateDoc(doc(db, 'forums', FORUM_ID, 'posts', POST_ID), {
      replyCount: increment(1),
    })
  );
});

test('reply bump naming a pre-existing reply is denied', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(ctx.firestore(), 'forums', FORUM_ID, 'posts', POST_ID, 'replies', 'existing-reply'),
      { userId: MALLORY, body: 'earlier' }
    );
  });

  const db = dbFor(MALLORY);
  await assertFails(
    updateDoc(doc(db, 'forums', FORUM_ID, 'posts', POST_ID), {
      replyCount: increment(1),
      lastReplyId: 'existing-reply',
    })
  );
});

/** Seeds a reply by `uid` on the shared post, with replyCount already at 1. */
async function seedReply(uid, replyId) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'forums', FORUM_ID, 'posts', POST_ID, 'replies', replyId), {
      userId: uid,
      body: 'to be deleted',
    });
    await updateDoc(doc(db, 'forums', FORUM_ID, 'posts', POST_ID), { replyCount: 1 });
  });
}

test('a rider may delete their own reply on someone else\'s post', async () => {
  // §24.11 regression. The post belongs to ALICE, the reply to MALLORY. The
  // old -1 clause checked `resource.data.userId` — the POST's author — so this
  // whole batch was denied and riders could not delete their own replies.
  await seedReply(MALLORY, 'r1');

  const db = dbFor(MALLORY);
  const postRef = doc(db, 'forums', FORUM_ID, 'posts', POST_ID);
  const batch = writeBatch(db);
  batch.delete(doc(postRef, 'replies', 'r1'));
  batch.update(postRef, { replyCount: increment(-1), lastReplyId: 'r1' });
  await assertSucceeds(batch.commit());
});

test('a stranger cannot decrement replyCount without deleting a reply', async () => {
  await seedReply(ALICE, 'r1');

  const db = dbFor(MALLORY);
  await assertFails(
    updateDoc(doc(db, 'forums', FORUM_ID, 'posts', POST_ID), {
      replyCount: increment(-1),
      lastReplyId: 'r1',
    })
  );
});

test('a stranger cannot delete someone else\'s reply to drive the count down', async () => {
  await seedReply(ALICE, 'r1');

  const db = dbFor(MALLORY);
  const postRef = doc(db, 'forums', FORUM_ID, 'posts', POST_ID);
  const batch = writeBatch(db);
  batch.delete(doc(postRef, 'replies', 'r1'));
  batch.update(postRef, { replyCount: increment(-1), lastReplyId: 'r1' });
  // Denied by the reply's own delete rule, which fails the whole batch — this
  // is exactly the delegation docRemoved() relies on.
  await assertFails(batch.commit());
});

// ---------------------------------------------------------------------------
// isAdmin() must not blow up on a token with no email claims — §24.11
// ---------------------------------------------------------------------------

test('a forum creator can moderate even with no email_verified claim', async () => {
  // isAdmin() used to read request.auth.token.email_verified directly. On a
  // token without that claim (anonymous/phone sign-in, and every test token
  // here) that is an evaluation ERROR, not false — and because
  // canModerateForum() is `isAdmin() || (creator/maintainer check)`, the error
  // took the whole expression down before the branch that should have allowed
  // this. The `.get('email_verified', false)` form fixes it.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'forums', FORUM_ID), {
      createdBy: MALLORY,
    });
  });

  const db = dbFor(MALLORY);
  // ALICE's post, deleted by the forum's creator.
  await assertSucceeds(deleteDoc(doc(db, 'forums', FORUM_ID, 'posts', POST_ID)));
});

test('a non-moderator still cannot delete someone else\'s post', async () => {
  const db = dbFor(MALLORY);
  await assertFails(deleteDoc(doc(db, 'forums', FORUM_ID, 'posts', POST_ID)));
});

// ---------------------------------------------------------------------------
// Regression cover: the 2026-08-12 like/vote clauses must still behave.
// ---------------------------------------------------------------------------

test('like bump still succeeds alongside its own likes/{uid} doc', async () => {
  const db = dbFor(MALLORY);
  const rideRef = doc(db, 'rides', RIDE_ID);

  await assertSucceeds(
    runTransaction(db, async (tx) => {
      tx.set(doc(rideRef, 'likes', MALLORY), { likedAt: 1 });
      tx.update(rideRef, { likes: increment(1) });
    })
  );
});

test('like bump without the likes/{uid} doc is still denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(updateDoc(doc(db, 'rides', RIDE_ID), { likes: increment(1) }));
});

test('vote bump still succeeds alongside its own votes/{uid} doc', async () => {
  const db = dbFor(MALLORY);
  const rideRef = doc(db, 'rides', RIDE_ID);

  await assertSucceeds(
    runTransaction(db, async (tx) => {
      tx.set(doc(rideRef, 'votes', MALLORY), { value: 1 });
      tx.update(rideRef, { upvotes: increment(1) });
    })
  );
});

test('vote bump without the votes/{uid} doc is still denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(updateDoc(doc(db, 'rides', RIDE_ID), { upvotes: increment(1) }));
});

// ---------------------------------------------------------------------------
// liveSessions/{token} — §33.2: the read rule must also honor expiresAt, not
// just shareable.
// ---------------------------------------------------------------------------

const LIVE_TOKEN = 'a'.repeat(32);

function seedLiveSession(overrides) {
  return testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'liveSessions', LIVE_TOKEN), {
      uid: ALICE,
      rideId: RIDE_ID,
      shareable: true,
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
      ...overrides,
    });
  });
}

test('an unauthenticated reader can read a shareable, unexpired live session', async () => {
  await seedLiveSession({});
  const db = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(db, 'liveSessions', LIVE_TOKEN)));
});

test('an expired live session is denied even though shareable is still true', async () => {
  // The exact §33.2 exploit: a link the app itself would call "expired,"
  // read straight off Firestore instead of through the 24h JS check.
  await seedLiveSession({ expiresAt: Timestamp.fromMillis(Date.now() - 60_000) });
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'liveSessions', LIVE_TOKEN)));
});

test('a live session with no expiresAt at all is denied (fails closed, like legacy shareable)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'liveSessions', LIVE_TOKEN), {
      uid: ALICE,
      rideId: RIDE_ID,
      shareable: true,
      // no expiresAt
    });
  });
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'liveSessions', LIVE_TOKEN)));
});

// ---------------------------------------------------------------------------
// users/{uid}/notifications/{id} — §33.4: type enum + fromPhotoUrl domain
// allowlist on create.
// ---------------------------------------------------------------------------

function notificationRef(db, ownerUid = ALICE) {
  return doc(collection(db, 'users', ownerUid, 'notifications'));
}

test('a valid follow notification (no photo) is allowed', async () => {
  const db = dbFor(MALLORY);
  await assertSucceeds(
    setDoc(notificationRef(db), {
      type: 'follow',
      fromUid: MALLORY,
      fromName: 'Mallory',
      fromPhotoUrl: null,
      read: false,
    })
  );
});

test('a valid follow notification with an allowlisted Cloudinary photo is allowed', async () => {
  const db = dbFor(MALLORY);
  await assertSucceeds(
    setDoc(notificationRef(db), {
      type: 'follow',
      fromUid: MALLORY,
      fromName: 'Mallory',
      fromPhotoUrl: 'https://res.cloudinary.com/vjvcigkt/image/upload/v1/avatars/mallory.jpg',
      read: false,
    })
  );
});

test('a valid groupRideInvite notification with a groupRideId is allowed', async () => {
  const db = dbFor(MALLORY);
  await assertSucceeds(
    setDoc(notificationRef(db), {
      type: 'groupRideInvite',
      fromUid: MALLORY,
      fromName: 'Mallory',
      fromPhotoUrl: '',
      groupRideId: 'ride-123',
      read: false,
    })
  );
});

test('a notification with an unknown type is denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(
    setDoc(notificationRef(db), {
      type: 'systemAlert',
      fromUid: MALLORY,
      fromName: 'Admin: verify your account',
      read: false,
    })
  );
});

test('a notification with a non-allowlisted fromPhotoUrl (the tracking-pixel vector) is denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(
    setDoc(notificationRef(db), {
      type: 'follow',
      fromUid: MALLORY,
      fromName: 'Mallory',
      fromPhotoUrl: 'https://attacker.example/pixel.png',
      read: false,
    })
  );
});

test('a groupRideInvite notification with no groupRideId is denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(
    setDoc(notificationRef(db), {
      type: 'groupRideInvite',
      fromUid: MALLORY,
      fromName: 'Mallory',
      fromPhotoUrl: '',
      read: false,
    })
  );
});

test('a notification spoofing fromUid as someone else is still denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(
    setDoc(notificationRef(db), {
      type: 'follow',
      fromUid: ALICE,
      fromName: 'Alice',
      fromPhotoUrl: null,
      read: false,
    })
  );
});

// ---------------------------------------------------------------------------
// crashNotifications/{id} — §33.18: create-only, no client update/delete.
// ---------------------------------------------------------------------------

test('a rider can create their own pending crash notification', async () => {
  const db = dbFor(MALLORY);
  await assertSucceeds(
    setDoc(doc(db, 'crashNotifications', 'crash-1'), {
      uid: MALLORY,
      rideId: RIDE_ID,
      status: 'pending',
    })
  );
});

test('a crash notification created with a non-pending status is denied', async () => {
  const db = dbFor(MALLORY);
  await assertFails(
    setDoc(doc(db, 'crashNotifications', 'crash-1'), {
      uid: MALLORY,
      rideId: RIDE_ID,
      status: 'acknowledged',
    })
  );
});

test('a rider cannot rewrite their own crash notification status after creation', async () => {
  // The exact §33.18 exploit: suppress the escalation by self-acknowledging.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'crashNotifications', 'crash-1'), {
      uid: MALLORY,
      rideId: RIDE_ID,
      status: 'pending',
    });
  });
  const db = dbFor(MALLORY);
  await assertFails(
    updateDoc(doc(db, 'crashNotifications', 'crash-1'), { status: 'acknowledged' })
  );
});

// ---------------------------------------------------------------------------
// groupRides/{id}/voiceNotes/{noteId} — push-to-talk clips, create+read only.
// ---------------------------------------------------------------------------

/** A syntactically valid voice-note payload, as GroupRideRepository writes it. */
function voiceNoteData(overrides = {}) {
  return {
    senderId: ALICE,
    senderName: 'Alice',
    senderPhotoUrl: '',
    audioUrl:
      'https://res.cloudinary.com/vjvcigkt/video/upload/v1/voiceNotes/clip.m4a',
    durationMs: 2000,
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

function voiceNotesCollection(db) {
  return collection(db, 'groupRides', GROUP_RIDE_ID, 'voiceNotes');
}

test('a joined member can send a voice note', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(
    setDoc(doc(voiceNotesCollection(db)), voiceNoteData())
  );
});

test('an invited-but-not-yet-joined rider cannot send a voice note', async () => {
  const db = dbFor(MALLORY);
  await assertFails(
    setDoc(
      doc(voiceNotesCollection(db)),
      voiceNoteData({ senderId: MALLORY, senderName: 'Mallory' })
    )
  );
});

test('a rider with no relationship to the ride cannot send a voice note', async () => {
  const db = dbFor(STRANGER);
  await assertFails(
    setDoc(
      doc(voiceNotesCollection(db)),
      voiceNoteData({ senderId: STRANGER, senderName: 'Stranger' })
    )
  );
});

test('sending a voice note as somebody else is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(doc(voiceNotesCollection(db)), voiceNoteData({ senderId: MALLORY }))
  );
});

test('a voice note with an extra field is denied (hasOnly)', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(voiceNotesCollection(db)),
      voiceNoteData({ note: 'not on the whitelist' })
    )
  );
});

test('a voice note pointing off Cloudinary is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(voiceNotesCollection(db)),
      voiceNoteData({ audioUrl: 'https://evil.example.com/clip.m4a' })
    )
  );
});

test('a voice note under the 800ms accidental-tap floor is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(doc(voiceNotesCollection(db)), voiceNoteData({ durationMs: 500 }))
  );
});

test('a voice note over the 60s ceiling is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(doc(voiceNotesCollection(db)), voiceNoteData({ durationMs: 90000 }))
  );
});

test('a voice note stamped with a client clock instead of serverTimestamp() is denied', async () => {
  // The spoof this file's other create-time checks all guard against: a
  // plain Date lets the sender claim any moment, including one that would
  // let a note jump ahead of ones that arrived first.
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(doc(voiceNotesCollection(db)), voiceNoteData({ createdAt: new Date() }))
  );
});

test('a sent voice note cannot be updated or deleted by anyone, including its sender', async () => {
  let noteRef;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    noteRef = doc(collection(ctx.firestore(), 'groupRides', GROUP_RIDE_ID, 'voiceNotes'));
    await setDoc(noteRef, voiceNoteData());
  });

  const db = dbFor(ALICE);
  await assertFails(updateDoc(doc(db, noteRef.path), { durationMs: 5000 }));
  await assertFails(deleteDoc(doc(db, noteRef.path)));
});

test('an invited-but-not-yet-joined rider can still read voice notes', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(collection(ctx.firestore(), 'groupRides', GROUP_RIDE_ID, 'voiceNotes')),
      voiceNoteData()
    );
  });
  const db = dbFor(MALLORY);
  const snap = await getDocs(voiceNotesCollection(db));
  assert.equal(snap.empty, false);
});

test('a rider with no relationship to the ride cannot read voice notes', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(collection(ctx.firestore(), 'groupRides', GROUP_RIDE_ID, 'voiceNotes')),
      voiceNoteData()
    );
  });
  const db = dbFor(STRANGER);
  await assertFails(getDocs(voiceNotesCollection(db)));
});

// ---------------------------------------------------------------------------
// roadSpeedSamples/{segmentId}/samples/{sampleId} — anonymous, no-owner,
// bounded-shape create-only pool (road-baseline feature, 2026-08-28).
// ---------------------------------------------------------------------------

const SEGMENT_ID = 'w7z3s';

/** A syntactically valid road-speed sample, as _publishSegmentBaselines writes it. */
function roadSpeedSampleData(overrides = {}) {
  return {
    speedKmh: 42.5,
    weekday: 3,
    hour: 14,
    weatherCode: 1,
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

function roadSpeedSamplesCollection(db, segmentId = SEGMENT_ID) {
  return collection(db, 'roadSpeedSamples', segmentId, 'samples');
}

test('any authenticated rider can contribute a valid sample', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(
    setDoc(doc(roadSpeedSamplesCollection(db)), roadSpeedSampleData())
  );
});

test('a sample with no weather (fetch failed) is still allowed', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(
    setDoc(
      doc(roadSpeedSamplesCollection(db)),
      roadSpeedSampleData({ weatherCode: null })
    )
  );
});

test('an unauthenticated writer cannot contribute a sample', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(
    setDoc(doc(roadSpeedSamplesCollection(db)), roadSpeedSampleData())
  );
});

test('an unauthenticated reader cannot read the pool either', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(collection(ctx.firestore(), 'roadSpeedSamples', SEGMENT_ID, 'samples')),
      roadSpeedSampleData()
    );
  });
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDocs(roadSpeedSamplesCollection(db)));
});

test('a signed-in rider can read the pool for a segment they never rode', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(collection(ctx.firestore(), 'roadSpeedSamples', SEGMENT_ID, 'samples')),
      roadSpeedSampleData()
    );
  });
  const db = dbFor(STRANGER);
  const snap = await getDocs(roadSpeedSamplesCollection(db));
  assert.equal(snap.empty, false);
});

test('a sample carrying a uid (identifying the rider) is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(roadSpeedSamplesCollection(db)),
      roadSpeedSampleData({ uid: ALICE })
    )
  );
});

test('speedKmh above the plausibility ceiling is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(roadSpeedSamplesCollection(db)),
      roadSpeedSampleData({ speedKmh: 500 })
    )
  );
});

test('a negative speedKmh is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(roadSpeedSamplesCollection(db)),
      roadSpeedSampleData({ speedKmh: -1 })
    )
  );
});

test('weekday outside 1-7 is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(roadSpeedSamplesCollection(db)),
      roadSpeedSampleData({ weekday: 8 })
    )
  );
});

test('hour outside 0-23 is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(roadSpeedSamplesCollection(db)),
      roadSpeedSampleData({ hour: 24 })
    )
  );
});

test('a non-integer weatherCode is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(roadSpeedSamplesCollection(db)),
      roadSpeedSampleData({ weatherCode: 'sunny' })
    )
  );
});

test('a sample stamped with a client clock instead of serverTimestamp() is denied', async () => {
  const db = dbFor(ALICE);
  await assertFails(
    setDoc(
      doc(roadSpeedSamplesCollection(db)),
      roadSpeedSampleData({ createdAt: new Date() })
    )
  );
});

test('a sample can never be updated or deleted, even by its own contributor', async () => {
  let sampleRef;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    sampleRef = doc(
      collection(ctx.firestore(), 'roadSpeedSamples', SEGMENT_ID, 'samples')
    );
    await setDoc(sampleRef, roadSpeedSampleData());
  });

  const db = dbFor(ALICE);
  await assertFails(updateDoc(doc(db, sampleRef.path), { speedKmh: 999 }));
  await assertFails(deleteDoc(doc(db, sampleRef.path)));
});

// ---------------------------------------------------------------------------
// groupRideJoinCodes/{code} + the code-join door on groupRides — a stranger
// joining an active ride via a shared 6-character code instead of an invite
// (GroupRideRepository.joinByCode).
// ---------------------------------------------------------------------------

test('any signed-in rider can resolve a known join code', async () => {
  const db = dbFor(STRANGER);
  const snap = await getDoc(doc(db, 'groupRideJoinCodes', JOIN_CODE));
  assert.equal(snap.exists(), true);
  assert.equal(snap.data().groupRideId, GROUP_RIDE_ID);
});

test('join codes cannot be listed/enumerated', async () => {
  const db = dbFor(STRANGER);
  await assertFails(getDocs(collection(db, 'groupRideJoinCodes')));
});

test('a signed-in rider can create a well-shaped join code mapping', async () => {
  const db = dbFor(STRANGER);
  await assertSucceeds(
    setDoc(doc(db, 'groupRideJoinCodes', 'ZZ99ZZ'), {
      groupRideId: 'some-other-ride',
      createdAt: serverTimestamp(),
    })
  );
});

test('a join code mapping with an extra field is denied', async () => {
  const db = dbFor(STRANGER);
  await assertFails(
    setDoc(doc(db, 'groupRideJoinCodes', 'ZZ99ZZ'), {
      groupRideId: 'some-other-ride',
      createdAt: serverTimestamp(),
      extra: 'nope',
    })
  );
});

test('a join code mapping stamped with a client clock is denied', async () => {
  const db = dbFor(STRANGER);
  await assertFails(
    setDoc(doc(db, 'groupRideJoinCodes', 'ZZ99ZZ'), {
      groupRideId: 'some-other-ride',
      createdAt: new Date(),
    })
  );
});

test('an existing join code mapping cannot be overwritten or deleted', async () => {
  const db = dbFor(STRANGER);
  await assertFails(
    setDoc(doc(db, 'groupRideJoinCodes', JOIN_CODE), {
      groupRideId: 'hijacked-ride',
      createdAt: serverTimestamp(),
    })
  );
  await assertFails(deleteDoc(doc(db, 'groupRideJoinCodes', JOIN_CODE)));
});

test('a rider with no relationship to an ACTIVE ride can still get() it by id', async () => {
  // This is what lets the "confirm join" screen preview a ride resolved from
  // a join code, before the rider has any membership relationship to it.
  const db = dbFor(STRANGER);
  await assertSucceeds(getDoc(doc(db, 'groupRides', GROUP_RIDE_ID)));
});

test('a stranger cannot get() a ride that is not active', async () => {
  const PLANNED_RIDE_ID = 'group-ride-planned';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'groupRides', PLANNED_RIDE_ID), {
      creatorId: ALICE,
      creatorName: 'Alice',
      name: "Alice's planned ride",
      startTime: new Date(),
      status: 'planned',
      memberIds: [ALICE],
      invitedIds: [],
      createdAt: new Date(),
      maxParticipants: 20,
    });
  });
  const db = dbFor(STRANGER);
  await assertFails(getDoc(doc(db, 'groupRides', PLANNED_RIDE_ID)));
});

test('a stranger can join an active ride by adding exactly themselves to memberIds', async () => {
  const db = dbFor(STRANGER);
  await assertSucceeds(
    updateDoc(doc(db, 'groupRides', GROUP_RIDE_ID), {
      memberIds: [ALICE, STRANGER],
    })
  );
});

test('joining cannot add anyone other than the caller', async () => {
  const db = dbFor(STRANGER);
  await assertFails(
    updateDoc(doc(db, 'groupRides', GROUP_RIDE_ID), {
      memberIds: [ALICE, STRANGER, MALLORY],
    })
  );
});

test('joining cannot touch any field besides memberIds', async () => {
  const db = dbFor(STRANGER);
  await assertFails(
    updateDoc(doc(db, 'groupRides', GROUP_RIDE_ID), {
      memberIds: [ALICE, STRANGER],
      name: 'Renamed by a stranger',
    })
  );
});

test('joining a non-active ride via the code door is denied', async () => {
  const ENDED_RIDE_ID = 'group-ride-ended';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'groupRides', ENDED_RIDE_ID), {
      creatorId: ALICE,
      creatorName: 'Alice',
      name: "Alice's ended ride",
      startTime: new Date(),
      status: 'completed',
      memberIds: [ALICE],
      invitedIds: [],
      createdAt: new Date(),
      maxParticipants: 20,
    });
  });
  const db = dbFor(STRANGER);
  await assertFails(
    updateDoc(doc(db, 'groupRides', ENDED_RIDE_ID), {
      memberIds: [ALICE, STRANGER],
    })
  );
});

test('joining a full ride via the code door is denied', async () => {
  const FULL_RIDE_ID = 'group-ride-full';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'groupRides', FULL_RIDE_ID), {
      creatorId: ALICE,
      creatorName: 'Alice',
      name: "Alice's full ride",
      startTime: new Date(),
      status: 'active',
      memberIds: [ALICE],
      invitedIds: [],
      createdAt: new Date(),
      maxParticipants: 1,
    });
  });
  const db = dbFor(STRANGER);
  await assertFails(
    updateDoc(doc(db, 'groupRides', FULL_RIDE_ID), {
      memberIds: [ALICE, STRANGER],
    })
  );
});

test('a stranger can write their own roster row while joining an active ride', async () => {
  const db = dbFor(STRANGER);
  await assertSucceeds(
    setDoc(doc(db, 'groupRides', GROUP_RIDE_ID, 'members', STRANGER), {
      userId: STRANGER,
      userName: 'Stranger',
      userPhotoUrl: '',
      joinedAt: new Date(),
      status: 'joined',
    })
  );
});

test('a stranger cannot write someone else\'s roster row via the code door', async () => {
  const db = dbFor(STRANGER);
  await assertFails(
    setDoc(doc(db, 'groupRides', GROUP_RIDE_ID, 'members', MALLORY), {
      userId: MALLORY,
      userName: 'Mallory',
      userPhotoUrl: '',
      joinedAt: new Date(),
      status: 'joined',
    })
  );
});
