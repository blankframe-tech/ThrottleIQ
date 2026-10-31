'use strict';

/**
 * Docs that Cloud Functions write through the Admin SDK (which bypasses
 * these rules) against the client rules that read them afterwards: the
 * security sweep's "Not checked" item (security_sweep_2026-10-30.md).
 * Shapes are copied from functions/src/account-erasure.ts and
 * chat-moderation.ts. Also pins issues_open.md 109.10 (no block check on
 * group-ride invites).
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
  doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc, writeBatch,
  serverTimestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid'; // erased rider / group-ride creator
const BOB = 'bob-uid'; // the rider left behind
const MALLORY = 'mallory-uid'; // outsider
const DELETED = 'deleted-rider'; // account-erasure.ts DELETED_PARTICIPANT
const DELETED_NAME = 'Deleted rider'; // account-erasure.ts DELETED_RIDER

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-fn-shapes',
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

// ── Account erasure: a DM with the erased rider ─────────────────────────────

const DM = `${ALICE}_${BOB}`;

async function seedErasedChat() {
  await seed({
    [`chats/${DM}`]: {
      participants: [DELETED, BOB],
      updatedAt: new Date(),
      lastMessage: { senderId: DELETED, text: '', createdAt: new Date() },
    },
    [`chats/${DM}/messages/m1`]: { senderId: DELETED, text: '', createdAt: new Date(), isRead: false },
    [`chats/${DM}/messages/m2`]: { senderId: BOB, text: 'see you', createdAt: new Date(), isRead: false },
  });
}

test('erased chat: the remaining rider still reads the room and its history', async () => {
  await seedErasedChat();
  await assertSucceeds(getDoc(doc(db(BOB), 'chats', DM)));
  const msgs = await assertSucceeds(getDocs(collection(db(BOB), 'chats', DM, 'messages')));
  if (msgs.size !== 2) throw new Error(`expected 2 messages, got ${msgs.size}`);
});

test('erased chat: an outsider and the erased uid get nothing', async () => {
  await seedErasedChat();
  await assertFails(getDoc(doc(db(MALLORY), 'chats', DM)));
  await assertFails(getDocs(collection(db(MALLORY), 'chats', DM, 'messages')));
  // A new account can't reuse the old uid's seat: it is no longer listed.
  await assertFails(getDoc(doc(db(ALICE), 'chats', DM)));
  await assertFails(getDocs(collection(db(ALICE), 'chats', DM, 'messages')));
});

test("erased chat: nobody can put the erased rider's uid back into participants", async () => {
  await seedErasedChat();
  await assertFails(updateDoc(doc(db(BOB), 'chats', DM), { participants: [ALICE, BOB] }));
});

test('KNOWN GAP: the remaining rider can still send into a room with a deleted rider', async () => {
  // Nobody reads it (the deleted side has no account); costs writes only.
  // Rules would need `!(DELETED in participants)` on message create and the
  // chat update; pinned so a change here is a deliberate one.
  await seedErasedChat();
  const f = db(BOB);
  const batch = writeBatch(f);
  batch.set(doc(f, 'chats', DM, 'messages', 'm3'), {
    senderId: BOB, text: 'hello?', createdAt: serverTimestamp(), isRead: false,
  });
  batch.update(doc(f, 'chats', DM), {
    lastMessage: { senderId: BOB, text: 'hello?', createdAt: serverTimestamp() },
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
});

// ── Account erasure: detached forum posts, replies and ride comments ────────

const DETACHED = { userId: '', userName: DELETED_NAME, userPhotoUrl: '' };

async function seedDetachedContent() {
  await seed({
    'forums/f1': { name: 'Dhaka riders', createdBy: BOB, memberCount: 1 },
    'forums/f1/posts/p1': {
      forumId: 'f1', title: 'Chain slack?', body: 'how much', createdAt: new Date(),
      replyCount: 1, upvotes: 0, downvotes: 0, ...DETACHED,
    },
    'forums/f1/posts/p1/replies/r1': {
      postId: 'p1', forumId: 'f1', body: '25 mm', createdAt: new Date(), ...DETACHED,
    },
    'rides/ride1': { userId: BOB, audience: 'public', comments: 1, allowedUserIds: [] },
    'rides/ride1/comments/c1': {
      id: 'c1', rideId: 'ride1', text: 'nice', createdAt: new Date(), ...DETACHED,
    },
  });
}

test('detached posts, replies and comments stay readable', async () => {
  await seedDetachedContent();
  await assertSucceeds(getDoc(doc(db(MALLORY), 'forums/f1/posts/p1')));
  await assertSucceeds(getDoc(doc(db(MALLORY), 'forums/f1/posts/p1/replies/r1')));
  await assertSucceeds(getDoc(doc(db(MALLORY), 'rides/ride1/comments/c1')));
});

test('nobody can claim a detached post, reply or comment', async () => {
  await seedDetachedContent();
  for (const uid of [MALLORY, BOB]) {
    const f = db(uid);
    await assertFails(updateDoc(doc(f, 'forums/f1/posts/p1'), { userId: uid, title: 'mine' }));
    await assertFails(updateDoc(doc(f, 'forums/f1/posts/p1/replies/r1'), { userId: uid, body: 'mine' }));
    await assertFails(updateDoc(doc(f, 'rides/ride1/comments/c1'), { userId: uid, text: 'mine' }));
  }
  // An outsider can't delete it either ('' never equals a uid)...
  await assertFails(deleteDoc(doc(db(MALLORY), 'rides/ride1/comments/c1')));
});

// ── chat-moderation.ts: the automated report and the hidden message ─────────

test('the automated toxicity report is admin-only, even for the rider it names', async () => {
  const id = `auto_chat_${DM}_m1`;
  await seed({
    [`chats/${DM}`]: { participants: [ALICE, BOB], updatedAt: new Date() },
    [`reports/${id}`]: {
      reporterId: 'system', reportedId: ALICE, contentType: 'chat', contentId: 'm1',
      chatId: DM, contentPath: `chats/${DM}/messages/m1`, originalText: 'you idiot',
      reason: 'Automated toxicity detection', createdAt: new Date(), status: 'pending',
    },
  });
  for (const uid of [ALICE, BOB, MALLORY]) {
    await assertFails(getDoc(doc(db(uid), 'reports', id)));
    await assertFails(updateDoc(doc(db(uid), 'reports', id), { status: 'dismissed' }));
    await assertFails(deleteDoc(doc(db(uid), 'reports', id)));
  }
});

test('a moderation-hidden message is readable but neither side can restore it', async () => {
  await seed({
    [`chats/${DM}`]: { participants: [ALICE, BOB], updatedAt: new Date() },
    [`chats/${DM}/messages/m1`]: {
      senderId: ALICE, createdAt: new Date(), isRead: false, isToxic: true,
      text: '*** This message was hidden by automated moderation ***',
    },
  });
  await assertSucceeds(getDoc(doc(db(BOB), 'chats', DM, 'messages', 'm1')));
  for (const uid of [ALICE, BOB]) {
    await assertFails(updateDoc(doc(db(uid), 'chats', DM, 'messages', 'm1'), { text: 'you idiot' }));
    await assertFails(deleteDoc(doc(db(uid), 'chats', DM, 'messages', 'm1')));
  }
});

// ── issues_open.md 109.10: group-ride invites have no block check ───────────

test('KNOWN GAP 109.10: a creator can still invite a rider who blocked them', async () => {
  // The invite notification is refused by the notifications rule; the
  // invitedIds entry is not (it only gives the blocker read access to the
  // ride, and no app list query surfaces it). A fix needs a rule that checks
  // each added uid against blocks/, which rules can't loop over; pinned
  // until then.
  await seed({
    [`users/${BOB}/blocks/${ALICE}`]: { blockedAt: new Date() },
    'groupRides/g1': { creatorId: ALICE, memberIds: [ALICE], invitedIds: [], status: 'planned' },
  });
  await assertSucceeds(updateDoc(doc(db(ALICE), 'groupRides/g1'), { invitedIds: [BOB] }));
});

test('109.10 boundary: an invite still never adds the invitee as a member', async () => {
  await seed({
    [`users/${BOB}/blocks/${ALICE}`]: { blockedAt: new Date() },
    'groupRides/g1': { creatorId: ALICE, memberIds: [ALICE], invitedIds: [], status: 'planned' },
  });
  await assertFails(
    updateDoc(doc(db(ALICE), 'groupRides/g1'), { invitedIds: [BOB], memberIds: [ALICE, BOB] })
  );
});
