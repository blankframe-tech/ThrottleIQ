'use strict';

/**
 * onMessageCreate (chat-moderation.ts) against the Firestore emulator: a
 * toxic message files one admin report holding the original text, then is
 * hidden; innocent words that contain a keyword are left alone; a retried
 * trigger files no duplicate.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const { db, rtdb, clearEmulators } = require('./setup');
const { onMessageCreate } = require('../../lib/chat-moderation');

const CHAT = 'aliceUid_bobUid';

async function deliver(messageId, data) {
  const ref = db.doc(`chats/${CHAT}/messages/${messageId}`);
  await ref.set(data);
  const event = { data: await ref.get(), params: { chatId: CHAT, messageId } };
  await onMessageCreate.run(event);
  return { ref, event };
}

test.before(clearEmulators);

test('a toxic message is reported with its original text, then hidden', async () => {
  const { ref } = await deliver('m1', { senderId: 'aliceUid', text: 'You IDIOT', isRead: false });

  const report = await db.doc(`reports/auto_chat_${CHAT}_m1`).get();
  assert.ok(report.exists);
  assert.equal(report.get('originalText'), 'You IDIOT');
  assert.equal(report.get('reportedId'), 'aliceUid');
  assert.equal(report.get('chatId'), CHAT);
  assert.equal(report.get('contentPath'), `chats/${CHAT}/messages/m1`);
  assert.equal(report.get('status'), 'pending', 'automation never closes its own report');

  const msg = (await ref.get()).data();
  assert.equal(msg.isToxic, true);
  assert.notEqual(msg.text, 'You IDIOT');
});

test('words that merely contain a keyword are not hidden', async () => {
  for (const [id, text] of [['m2', 'whatever, dumbbell day'], ['m3', 'beef jerky after the ride']]) {
    const { ref } = await deliver(id, { senderId: 'bobUid', text, isRead: false });
    assert.equal((await ref.get()).get('isToxic'), undefined, text);
    assert.equal((await db.doc(`reports/auto_chat_${CHAT}_${id}`).get()).exists, false, text);
  }
});

test('a retried trigger rewrites the same report and keeps the original text', async () => {
  const { event } = await deliver('m4', { senderId: 'aliceUid', text: 'so stupid', isRead: false });
  // At-least-once delivery: the same event again, carrying the original snapshot.
  await onMessageCreate.run(event);
  const reports = await db.collection('reports').where('contentId', '==', 'm4').get();
  assert.equal(reports.size, 1);
  assert.equal(reports.docs[0].get('originalText'), 'so stupid');
});

test('a message without text is ignored, not crashed on', async () => {
  const { ref } = await deliver('m5', { senderId: 'aliceUid', isRead: false });
  assert.equal((await ref.get()).get('isToxic'), undefined);
});

test.after(async () => {
  await rtdb.app.delete();
});
