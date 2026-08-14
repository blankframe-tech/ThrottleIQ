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
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  increment,
  runTransaction,
  writeBatch,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const MALLORY = 'mallory-uid';
const RIDE_ID = 'ride-1';
const FORUM_ID = 'forum-1';
const POST_ID = 'post-1';

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
