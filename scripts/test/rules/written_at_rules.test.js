'use strict';

/**
 * Issue #157: ride comments, forum posts and forum replies may carry an
 * optional display-only `writtenAt` (phone time). It must be a timestamp if
 * present; any value of it, even a wildly wrong clock, never refuses the
 * write. Old builds (no `writtenAt`) still pass, and `createdAt` must still
 * be the server time. Same batch shapes as RideShareRepository.addComment,
 * ForumRepository.createPost and ForumRepository.addReply.
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
  doc, setDoc, writeBatch, increment, serverTimestamp, Timestamp,
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
    projectId: 'demo-throttleiq-written-at',
    firestore: { rules: RULES },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

async function seedParents() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'rides/r1'), {
      userId: ALICE, audience: 'public', distanceKm: 10, durationSeconds: 1200,
      maxSpeedKmh: 60, comments: 0, upvotes: 0, downvotes: 0,
    });
    await setDoc(doc(f, 'forums/f1'), { followerCount: 0, postCount: 0 });
    await setDoc(doc(f, 'forums/f1/posts/p0'), {
      userId: ALICE, replyCount: 0, upvotes: 0, downvotes: 0,
    });
  });
}

test.beforeEach(seedParents);

const db = (uid) => testEnv.authenticatedContext(uid).firestore();

// Each: write the doc plus its counter bump in one batch, like the app does.
const KINDS = {
  'ride comment': (f, extra) => {
    const b = writeBatch(f);
    b.set(doc(f, 'rides/r1/comments/c1'), {
      id: 'c1', rideId: 'r1', userId: BOB, userName: 'Bob', userPhotoUrl: '',
      text: 'nice', createdAt: serverTimestamp(), updatedAt: null, ...extra,
    });
    b.update(doc(f, 'rides/r1'), { comments: increment(1), lastCommentId: 'c1' });
    return b.commit();
  },
  'forum post': (f, extra) => {
    const b = writeBatch(f);
    b.set(doc(f, 'forums/f1/posts/p1'), {
      forumId: 'f1', userId: BOB, userName: 'Bob', userPhotoUrl: '', title: 't',
      body: 'b', replyCount: 0, upvotes: 0, downvotes: 0, postType: 'general',
      isSolved: false, createdAt: serverTimestamp(), ...extra,
    });
    b.update(doc(f, 'forums/f1'), { postCount: increment(1), lastPostId: 'p1' });
    return b.commit();
  },
  'forum reply': (f, extra) => {
    const b = writeBatch(f);
    b.set(doc(f, 'forums/f1/posts/p0/replies/r1'), {
      postId: 'p0', forumId: 'f1', userId: BOB, userName: 'Bob', userPhotoUrl: '',
      body: 'b', createdAt: serverTimestamp(), ...extra,
    });
    b.update(doc(f, 'forums/f1/posts/p0'), { replyCount: increment(1), lastReplyId: 'r1' });
    return b.commit();
  },
};

for (const [kind, write] of Object.entries(KINDS)) {
  test(`#157 ${kind}: an old build's write (no writtenAt) passes`, async () => {
    await assertSucceeds(write(db(BOB), {}));
  });

  test(`#157 ${kind}: writtenAt as the phone's Timestamp.now() passes`, async () => {
    await assertSucceeds(write(db(BOB), { writtenAt: Timestamp.now() }));
  });

  test(`#157 ${kind}: a wrong phone clock (far past or future writtenAt) still passes`, async () => {
    await assertSucceeds(write(db(BOB), { writtenAt: Timestamp.fromDate(new Date('2001-01-01')) }));
    await seedParents();
    await assertSucceeds(write(db(BOB), { writtenAt: Timestamp.fromDate(new Date('2099-01-01')) }));
  });

  test(`#157 ${kind}: a writtenAt that is not a timestamp is denied`, async () => {
    const f = db(BOB);
    await assertFails(write(f, { writtenAt: '2026-10-01T20:00:00Z' }));
    await assertFails(write(f, { writtenAt: 1759348800000 }));
    await assertFails(write(f, { writtenAt: null }));
    await assertFails(write(f, { writtenAt: { seconds: 1 } }));
  });

  test(`#157 ${kind}: writtenAt doesn't relax createdAt (must still be server time)`, async () => {
    await assertFails(write(db(BOB), {
      writtenAt: Timestamp.now(), createdAt: Timestamp.fromDate(new Date('2026-01-01')),
    }));
  });
}
