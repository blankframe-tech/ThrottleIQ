'use strict';

/**
 * Report evidence (owner decision 2026-10-21): a chat or post report may
 * carry `snapshot`, a copy of the reported message ({text, senderId,
 * sentAt}) or forum post ({title, body, imageUrls, senderId, sentAt}).
 * The payload is what ReportRepository.submitReport sends
 * (ReportModel.reportSnapshotOf). The rule must refuse a forged,
 * misattributed or outsider snapshot and keep it unreadable and uneditable
 * for riders.
 *
 * Run with:  npm run test:rules   (from scripts/)
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
  collection,
  getDoc,
  setDoc,
  updateDoc,
  deleteField,
  Timestamp,
  serverTimestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(path.join(__dirname, '..', '..', '..', 'firestore.rules'), 'utf8');

const ALICE = 'alice-uid';
const MALLORY = 'mallory-uid';
const OUTSIDER = 'zed-uid';
const DM_ID = `${ALICE}_${MALLORY}`;
const MSG_PATH = `chats/${DM_ID}/messages/m1`;
const SENT = Timestamp.fromMillis(Date.UTC(2026, 9, 20, 18, 30, 0, 123));
const REAL = { text: 'you idiot', senderId: MALLORY, sentAt: SENT };
const POST_PATH = 'forums/f1/posts/p1';
const IMG = 'https://res.cloudinary.com/vjvcigkt/image/upload/x.jpg';
const POST = { title: 'Cheap parts', body: 'scam link', imageUrls: [IMG], senderId: MALLORY, sentAt: SENT };

// Honours FIRESTORE_EMULATOR_HOST so the suite can run on a non-default port.
const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-report-snapshot',
    firestore: { rules: RULES, host, port: Number(port) },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'chats', DM_ID), { participants: [ALICE, MALLORY] });
    await setDoc(doc(db, MSG_PATH), { senderId: MALLORY, text: 'you idiot', createdAt: SENT, isRead: false });
    await setDoc(doc(db, POST_PATH), {
      forumId: 'f1', userId: MALLORY, userName: 'M', title: 'Cheap parts', body: 'scam link',
      imageUrls: [IMG], createdAt: SENT, replyCount: 0, upvotes: 0, downvotes: 0,
    });
    await setDoc(doc(db, 'forums/f1/posts/p2'), {
      forumId: 'f1', userId: MALLORY, title: 'No pics', body: 'b', createdAt: SENT,
    });
  });
});

const dbFor = (uid) => testEnv.authenticatedContext(uid).firestore();

/** ReportModel.toFirestore for a chat message report. */
function report(overrides = {}) {
  return {
    reporterId: ALICE,
    reportedId: MALLORY,
    contentType: 'chat',
    contentId: MSG_PATH,
    reason: 'Harassment or bullying',
    createdAt: serverTimestamp(),
    status: 'pending',
    snapshot: REAL,
    ...overrides,
  };
}

test('a participant files a chat report with the real message snapshot', async () => {
  await assertSucceeds(setDoc(doc(collection(dbFor(ALICE), 'reports')), report()));
  // Old builds send no snapshot; still accepted.
  const { snapshot, ...noSnapshot } = report();
  await assertSucceeds(setDoc(doc(collection(dbFor(ALICE), 'reports')), noSnapshot));
});

test('a forged, misattributed or partial snapshot is denied', async () => {
  const db = dbFor(ALICE);
  const add = (o) => setDoc(doc(collection(db, 'reports')), report(o));
  await assertFails(add({ snapshot: { ...REAL, text: 'I will kill you' } }));
  await assertFails(add({ snapshot: { ...REAL, senderId: ALICE }, reportedId: ALICE }));
  await assertFails(add({ snapshot: { ...REAL, sentAt: Timestamp.now() } }));
  await assertFails(add({ snapshot: { text: REAL.text, senderId: MALLORY } }));
  await assertFails(add({ snapshot: { ...REAL, extra: 1 } }));
  // Real snapshot, but blaming someone other than the sender.
  await assertFails(add({ reportedId: 'someone-else' }));
  // A message that doesn't exist, a non-chat report, a bare id.
  await assertFails(add({ contentId: `chats/${DM_ID}/messages/nope` }));
  await assertFails(add({ contentType: 'post', contentId: 'forums/f/posts/p' }));
  await assertFails(add({ contentType: 'ride', contentId: 'r1' }));
  await assertFails(add({ contentId: 'm1' }));
});

test('a rider outside the chat cannot snapshot (or probe) its messages', async () => {
  await assertFails(setDoc(doc(collection(dbFor(OUTSIDER), 'reports')), report({ reporterId: OUTSIDER })));
});

test('the snapshot outlives the message, and riders cannot read or change it', async () => {
  const alice = dbFor(ALICE);
  await assertSucceeds(setDoc(doc(alice, 'reports', 'r1'), report()));
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(MSG_PATH).delete();
  });
  await assertFails(getDoc(doc(alice, 'reports', 'r1')));
  await assertFails(getDoc(doc(dbFor(MALLORY), 'reports', 'r1')));
  await assertFails(updateDoc(doc(alice, 'reports', 'r1'), { 'snapshot.text': 'edited' }));
  await assertFails(updateDoc(doc(alice, 'reports', 'r1'), { snapshot: deleteField() }));
  const admin = testEnv.authenticatedContext('admin-uid', { admin: true }).firestore();
  const kept = await assertSucceeds(getDoc(doc(admin, 'reports', 'r1')));
  assert.equal(kept.data().snapshot.text, 'you idiot');
});

test('any signed-in rider files a post report with the real post snapshot', async () => {
  const db = dbFor(OUTSIDER);
  const add = (o) => setDoc(doc(collection(db, 'reports')), report({
    reporterId: OUTSIDER, contentType: 'post', contentId: POST_PATH, snapshot: POST, ...o,
  }));
  await assertSucceeds(add({}));
  // A post without images is copied with an empty list.
  await assertSucceeds(add({
    contentId: 'forums/f1/posts/p2',
    snapshot: { title: 'No pics', body: 'b', imageUrls: [], senderId: MALLORY, sentAt: SENT },
  }));
  await assertFails(add({ snapshot: { ...POST, body: 'I will find you' } }));
  await assertFails(add({ snapshot: { ...POST, imageUrls: [] } }));
  await assertFails(add({ snapshot: { ...POST, title: 'x' } }));
  await assertFails(add({ reportedId: ALICE }));
  await assertFails(add({ contentId: 'forums/f1/posts/nope' }));
  // A chat-shaped copy on a post, or a post path filed as chat.
  await assertFails(add({ snapshot: REAL }));
  await assertFails(add({ contentType: 'chat' }));
});
