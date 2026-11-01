'use strict';

/**
 * Security-rules tests for the owner's notice board (issue #153):
 * forums/throttleiq_notice_board takes posts, replies and `alsoIn`
 * cross-posts only from the admin (`admin` custom claim).
 *
 * Needs the Firestore emulator — run with `npm run test:rules` from scripts/.
 */

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const { doc, setDoc, serverTimestamp, writeBatch, increment } = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ADMIN = 'owner-uid';
const RIDER = 'rider-uid';
const NOTICE = 'throttleiq_notice_board';
const OTHER = 'maintenance';
const NOTICE_POST = 'notice-1';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-rules-notice',
    firestore: { rules: RULES },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const id of [NOTICE, OTHER]) {
      await setDoc(doc(db, 'forums', id), { type: 'general', displayName: id, postCount: 0, followerCount: 0 });
    }
    await setDoc(doc(db, 'forums', NOTICE, 'posts', NOTICE_POST), {
      forumId: NOTICE, userId: ADMIN, title: 't', body: 'b', replyCount: 0, upvotes: 0, downvotes: 0,
    });
  });
});

const dbFor = (uid) =>
  testEnv.authenticatedContext(uid, uid === ADMIN ? { admin: true } : {}).firestore();

/** ForumRepository.createPost: the post and its home's postCount bump. */
function createPost(uid, forumId, postId, extra = {}) {
  const db = dbFor(uid);
  const batch = writeBatch(db);
  batch.set(doc(db, 'forums', forumId, 'posts', postId), {
    forumId, userId: uid, userName: 'R', userPhotoUrl: '', title: 'Hello', body: 'World',
    replyCount: 0, upvotes: 0, downvotes: 0, createdAt: serverTimestamp(), ...extra,
  });
  batch.update(doc(db, 'forums', forumId), { postCount: increment(1), lastPostId: postId });
  return batch.commit();
}

/** ForumRepository.addReply: the reply and the post's replyCount bump. */
function addReply(uid, replyId) {
  const db = dbFor(uid);
  const postRef = doc(db, 'forums', NOTICE, 'posts', NOTICE_POST);
  const batch = writeBatch(db);
  batch.set(doc(postRef, 'replies', replyId), {
    postId: NOTICE_POST, forumId: NOTICE, userId: uid, userName: 'R', userPhotoUrl: '',
    body: 'Nice', createdAt: serverTimestamp(),
  });
  batch.update(postRef, { replyCount: increment(1), lastReplyId: replyId });
  return batch.commit();
}

test('the admin can post a notice', async () => {
  await assertSucceeds(createPost(ADMIN, NOTICE, 'n2'));
});

test('a rider cannot post on the notice board', async () => {
  await assertFails(createPost(RIDER, NOTICE, 'n3'));
});

test('a rider can still post elsewhere', async () => {
  await assertSucceeds(createPost(RIDER, OTHER, 'o1'));
});

test('a rider cannot cross-post into the notice board', async () => {
  await assertFails(createPost(RIDER, OTHER, 'o2', { alsoIn: [NOTICE] }));
});

test('the admin can cross-post into the notice board', async () => {
  await assertSucceeds(createPost(ADMIN, OTHER, 'o3', { alsoIn: [NOTICE] }));
});

test('a rider cannot reply to a notice', async () => {
  await assertFails(addReply(RIDER, 'r1'));
});

test('the admin can reply to a notice', async () => {
  await assertSucceeds(addReply(ADMIN, 'r2'));
});
