'use strict';

/**
 * Vote docs carry the voter's `uid` (so account erasure can find them with a
 * collection-group query). `uid` is optional while build 29, which writes
 * `{value}` only, is still allowed; when present it must be the voter.
 * Own projectId, like the other suites.
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

const { doc, setDoc, runTransaction, increment } = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-vote-uid',
    firestore: { rules: RULES },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'rides/r1'), {
      userId: ALICE, audience: 'public', distanceKm: 10, durationSeconds: 1200,
      maxSpeedKmh: 60, comments: 0, upvotes: 0, downvotes: 0,
    });
    await setDoc(doc(f, 'forums/f1'), { followerCount: 0, postCount: 1 });
    await setDoc(doc(f, 'forums/f1/posts/p1'), { userId: ALICE, upvotes: 0, downvotes: 0, replyCount: 0 });
  });
});

/** A fresh upvote as RideShareRepository.vote / ForumRepository.votePost cast it, with `voteData` as the vote doc. */
function castVote(uid, parentPath, voteData) {
  const f = testEnv.authenticatedContext(uid).firestore();
  return runTransaction(f, async (tx) => {
    tx.set(doc(f, `${parentPath}/votes/${uid}`), voteData);
    tx.update(doc(f, parentPath), { upvotes: increment(1) });
  });
}

for (const [label, parentPath] of [['ride', 'rides/r1'], ['forum post', 'forums/f1/posts/p1']]) {
  test(`${label} vote with the voter's uid is allowed`, async () => {
    await assertSucceeds(castVote(BOB, parentPath, { value: 1, uid: BOB }));
  });

  test(`${label} vote without uid (build 29) is still allowed`, async () => {
    await assertSucceeds(castVote(BOB, parentPath, { value: 1 }));
  });

  test(`${label} vote naming someone else's uid is denied`, async () => {
    await assertFails(castVote(BOB, parentPath, { value: 1, uid: ALICE }));
  });

  test(`${label} vote with an extra key is denied`, async () => {
    await assertFails(castVote(BOB, parentPath, { value: 1, uid: BOB, note: 'x' }));
  });
}
