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

const {
  doc, setDoc, updateDoc, serverTimestamp, collectionGroup, getDocs, query, where,
  writeBatch, increment,
} = require('firebase/firestore');

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
    projectId: 'demo-throttleiq-rules-pitwall',
    firestore: { rules: RULES }, // host: FIRESTORE_EMULATOR_HOST (emulators:exec)
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
/** ForumRepository.createPost: the post and its postCount bump in one batch. */
function createPost(postId, data) {
  const db = dbFor(ALICE);
  const batch = writeBatch(db);
  batch.set(doc(db, 'forums', FORUM_ID, 'posts', postId), data);
  batch.update(doc(db, 'forums', FORUM_ID), { postCount: increment(1), lastPostId: postId });
  return batch.commit();
}

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
    createPost('p1', newPost(ALICE, {
      authorBike: 'Yamaha MT-15 (2023) · 12,400 km',
      attachment: { kind: 'ride', refId: 'ride-9', title: 'Ride on 3 Oct', subtitle: '42 km · 1h' },
    }))
  );
});

test('a pre-redesign post (no new fields) can still be created', async () => {
  const legacy = newPost(ALICE);
  delete legacy.postType;
  delete legacy.isSolved;
  await assertSucceeds(createPost('p2', legacy));
});

test('a post cannot be created already solved', async () => {
  await assertFails(
    createPost('p3', newPost(ALICE, { isSolved: true }))
  );
});

test('a post cannot be created with an accepted solution', async () => {
  await assertFails(
    createPost('p4',
      newPost(ALICE, { solutionReplyId: REPLY_ID }))
  );
});

test('an unknown post type is refused', async () => {
  await assertFails(
    createPost('p5', newPost(ALICE, { postType: 'spam' }))
  );
});

test('an oversized bike byline is refused', async () => {
  await assertFails(
    createPost('p6',
      newPost(ALICE, { authorBike: 'x'.repeat(81) }))
  );
});

test('a malformed attachment is refused', async () => {
  await assertFails(
    createPost('p7', newPost(ALICE, {
      attachment: { kind: 'ride', refId: 'r', title: 't', subtitle: 's', url: 'https://evil' },
    }))
  );
  await assertFails(
    createPost('p8', newPost(ALICE, {
      attachment: { kind: 'video', refId: 'r', title: 't', subtitle: 's' },
    }))
  );
});

const PHOTO = (uid, n = 1) =>
  `https://res.cloudinary.com/vjvcigkt/image/upload/v1712345/forumPhotos/${uid}/photo${n}.jpg`;

test('a post with up to four own-folder photos can be created', async () => {
  await assertSucceeds(
    createPost('ph1',
      newPost(ALICE, { imageUrls: [PHOTO(ALICE)] }))
  );
  await assertSucceeds(
    createPost('ph2',
      newPost(ALICE, { imageUrls: [1, 2, 3, 4].map((n) => PHOTO(ALICE, n)) }))
  );
});

test('post photos must be own-folder Cloudinary uploads, at most four', async () => {
  await assertFails(
    createPost('ph3',
      newPost(ALICE, { imageUrls: [1, 2, 3, 4, 5].map((n) => PHOTO(ALICE, n)) }))
  );
  await assertFails(
    createPost('ph4',
      newPost(ALICE, { imageUrls: ['https://evil.example.com/x.jpg'] }))
  );
  await assertFails(
    createPost('ph5',
      newPost(ALICE, { imageUrls: [PHOTO(MALLORY)] }))
  );
  await assertFails(
    createPost('ph6',
      newPost(ALICE, { imageUrls: [PHOTO(ALICE), 'https://evil.example.com/x.jpg'] }))
  );
  await assertFails(
    createPost('ph7',
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

// ---------------------------------------------------------------------------
// share to groups (alsoIn) and the All Riders collection-group read
// ---------------------------------------------------------------------------

test('a post can be shared to up to four more groups', async () => {
  await assertSucceeds(
    createPost('g1',
      newPost(ALICE, { alsoIn: ['a', 'b', 'c', 'd'] }))
  );
});

test('five more groups is one too many', async () => {
  await assertFails(
    createPost('g2',
      newPost(ALICE, { alsoIn: ['a', 'b', 'c', 'd', 'e'] }))
  );
});

test('alsoIn cannot name the home forum', async () => {
  await assertFails(
    createPost('g3',
      newPost(ALICE, { alsoIn: [FORUM_ID] }))
  );
});

test('alsoIn must be a list', async () => {
  await assertFails(
    createPost('g4',
      newPost(ALICE, { alsoIn: 'a' }))
  );
});

// Security sweep B6: each alsoIn entry is a forum-id-shaped string.
test('B6: alsoIn entries must be short forum ids', async () => {
  await assertFails(createPost('g5', newPost(ALICE, { alsoIn: ['x'.repeat(201)] })));
  await assertFails(createPost('g6', newPost(ALICE, { alsoIn: [{ blob: 'x'.repeat(5000) }] })));
  await assertFails(createPost('g7', newPost(ALICE, { alsoIn: ['a/b'] })));
  await assertSucceeds(createPost('g8', newPost(ALICE, { alsoIn: ['yamaha__r15', 'c-night_riders'] })));
});

test('signed-in riders can read every post across groups', async () => {
  await assertSucceeds(getDocs(collectionGroup(dbFor(ALICE), 'posts')));
  await assertSucceeds(getDocs(query(collectionGroup(dbFor(ALICE), 'posts'),
    where('alsoIn', 'array-contains-any', ['a']))));
});

test('signed-out visitors cannot read posts across groups', async () => {
  await assertFails(
    getDocs(collectionGroup(testEnv.unauthenticatedContext().firestore(), 'posts')));
});
