'use strict';

/**
 * Security-rules tests for the Forums "Pit Wall" fields on
 * forums/{forumId}/posts/{postId}: post types, the attachment card, the
 * author-bike byline, and the solved / accepted-solution update
 * (ForumRepository.createPost / setPostSolution).
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

const { doc, setDoc, updateDoc, serverTimestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const MALLORY = 'mallory-uid';
const FORUM_ID = 'forum-1';
const HELP_POST = 'help-post';
const GENERAL_POST = 'general-post';
const REPLY_ID = 'reply-1';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-pitwall',
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
    await setDoc(doc(db, 'forums', FORUM_ID), { name: 'Test forum' });
    const base = { userId: ALICE, title: 't', body: 'b', replyCount: 1, upvotes: 0, downvotes: 0 };
    await setDoc(doc(db, 'forums', FORUM_ID, 'posts', HELP_POST), {
      ...base,
      postType: 'troubleshoot',
      isSolved: false,
    });
    await setDoc(doc(db, 'forums', FORUM_ID, 'posts', GENERAL_POST), base);
    await setDoc(doc(db, 'forums', FORUM_ID, 'posts', HELP_POST, 'replies', REPLY_ID), {
      userId: MALLORY,
      postId: HELP_POST,
      forumId: FORUM_ID,
      body: 'check the fuse',
    });
  });
});

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

/** Exactly the fields newForumPostFields() writes. */
function newPost(uid, extra = {}) {
  return {
    forumId: FORUM_ID,
    userId: uid,
    userName: 'Alice',
    userPhotoUrl: '',
    title: 'Clutch slipping',
    body: 'At 4000 rpm',
    replyCount: 0,
    upvotes: 0,
    downvotes: 0,
    postType: 'troubleshoot',
    isSolved: false,
    createdAt: serverTimestamp(),
    ...extra,
  };
}

// ---------------------------------------------------------------------------
// create
// ---------------------------------------------------------------------------

test('a typed post with a bike byline and a ride card can be created', async () => {
  await assertSucceeds(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'p1'), newPost(ALICE, {
      authorBike: 'Yamaha MT-15 (2023) · 12,400 km',
      attachment: { kind: 'ride', refId: 'ride-9', title: 'Ride on 3 Oct', subtitle: '42 km · 1h' },
    }))
  );
});

test('a pre-redesign post (no new fields) can still be created', async () => {
  const legacy = newPost(ALICE);
  delete legacy.postType;
  delete legacy.isSolved;
  await assertSucceeds(setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'p2'), legacy));
});

test('a post cannot be created already solved', async () => {
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'p3'), newPost(ALICE, { isSolved: true }))
  );
});

test('a post cannot be created with an accepted solution', async () => {
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'p4'),
      newPost(ALICE, { solutionReplyId: REPLY_ID }))
  );
});

test('an unknown post type is refused', async () => {
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'p5'), newPost(ALICE, { postType: 'spam' }))
  );
});

test('an oversized bike byline is refused', async () => {
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'p6'),
      newPost(ALICE, { authorBike: 'x'.repeat(81) }))
  );
});

test('a malformed attachment is refused', async () => {
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'p7'), newPost(ALICE, {
      attachment: { kind: 'ride', refId: 'r', title: 't', subtitle: 's', url: 'https://evil' },
    }))
  );
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'p8'), newPost(ALICE, {
      attachment: { kind: 'video', refId: 'r', title: 't', subtitle: 's' },
    }))
  );
});

const PHOTO = (uid, n = 1) =>
  `https://res.cloudinary.com/vjvcigkt/image/upload/v1712345/forumPhotos/${uid}/photo${n}.jpg`;

test('a post with up to four own-folder photos can be created', async () => {
  await assertSucceeds(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'ph1'),
      newPost(ALICE, { imageUrls: [PHOTO(ALICE)] }))
  );
  await assertSucceeds(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'ph2'),
      newPost(ALICE, { imageUrls: [1, 2, 3, 4].map((n) => PHOTO(ALICE, n)) }))
  );
});

test('post photos must be own-folder Cloudinary uploads, at most four', async () => {
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'ph3'),
      newPost(ALICE, { imageUrls: [1, 2, 3, 4, 5].map((n) => PHOTO(ALICE, n)) }))
  );
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'ph4'),
      newPost(ALICE, { imageUrls: ['https://evil.example.com/x.jpg'] }))
  );
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'ph5'),
      newPost(ALICE, { imageUrls: [PHOTO(MALLORY)] }))
  );
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'ph6'),
      newPost(ALICE, { imageUrls: [PHOTO(ALICE), 'https://evil.example.com/x.jpg'] }))
  );
  await assertFails(
    setDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', 'ph7'),
      newPost(ALICE, { imageUrls: 'not-a-list' }))
  );
});

// ---------------------------------------------------------------------------
// setPostSolution
// ---------------------------------------------------------------------------

test('the author can accept an existing reply as the solution', async () => {
  await assertSucceeds(
    updateDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', HELP_POST), {
      isSolved: true,
      solutionReplyId: REPLY_ID,
    })
  );
});

test('the author can mark solved with no accepted reply, then reopen', async () => {
  const ref = doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', HELP_POST);
  await assertSucceeds(updateDoc(ref, { isSolved: true, solutionReplyId: null }));
  await assertSucceeds(updateDoc(ref, { isSolved: false, solutionReplyId: null }));
});

test('someone else cannot mark a post solved', async () => {
  await assertFails(
    updateDoc(doc(dbFor(MALLORY), 'forums', FORUM_ID, 'posts', HELP_POST), {
      isSolved: true,
      solutionReplyId: REPLY_ID,
    })
  );
});

test('a reply that does not exist cannot be accepted', async () => {
  await assertFails(
    updateDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', HELP_POST), {
      isSolved: true,
      solutionReplyId: 'no-such-reply',
    })
  );
});

test('an accepted reply on an unsolved post is refused', async () => {
  await assertFails(
    updateDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', HELP_POST), {
      isSolved: false,
      solutionReplyId: REPLY_ID,
    })
  );
});

test('a non-troubleshoot post has no solved state', async () => {
  await assertFails(
    updateDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', GENERAL_POST), {
      isSolved: true,
      solutionReplyId: null,
    })
  );
});

test('the solution update cannot smuggle other fields', async () => {
  await assertFails(
    updateDoc(doc(dbFor(ALICE), 'forums', FORUM_ID, 'posts', HELP_POST), {
      isSolved: true,
      solutionReplyId: null,
      upvotes: 99,
    })
  );
});
