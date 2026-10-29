'use strict';

/**
 * deleteUserData (account-erasure.ts) against the Firestore + Database
 * emulators: issues §101.S4 (forum follows, group rides, RTDB, completion
 * marker), and everything public/privacy.html §9 promises (critique
 * 2026-10-14, B1): profile, rides and GPS tracks, emergency contacts, chats,
 * forum bylines, plus the B2 email lookup. §101.S2's collection-group
 * indexes cannot be checked here: the Firestore emulator does not enforce
 * indexes (they are in firestore.indexes.json `fieldOverrides`).
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');

const { db, rtdb, clearEmulators } = require('./setup');
const { deleteUserData, DELETED_RIDER, DELETED_PARTICIPANT } = require('../../lib/account-erasure');

const UID = 'deletedRiderUid000000000001';
const OTHER = 'otherRiderUid0000000000002';
const TOKEN = 'a'.repeat(40);
const OTHER_TOKEN = 'b'.repeat(40);
const CHAT_ID = [UID, OTHER].sort().join('_');
const EMAIL_HASH = 'c'.repeat(64);

const exists = async (path) => (await db.doc(path).get()).exists;
const rtdbVal = async (path) => (await rtdb.ref(path).get()).val();

async function seed() {
  const batch = db.batch();
  const set = (path, data) => batch.set(db.doc(path), data);

  set(`users/${UID}`, { username: 'GoneRider', displayName: 'Gone' });
  set('usernames/gonerider', { uid: UID });

  // What privacy.html §9 lists: owner-only subcollections under the profile.
  set(`users/${UID}/private/account`, { email: 'gone@example.com', emailLower: 'gone@example.com' });
  set(`emailLookup/${EMAIL_HASH}`, { uid: UID });
  set('emailLookup/' + 'd'.repeat(64), { uid: OTHER });
  set(`users/${UID}/rides/ride1`, { start_time: '2026-01-01T08:00:00.000', distance: 12000 });
  set(`users/${UID}/rides/ride1/track/0`, { index: 0, points: [23.8, 90.4, 1, 5, 0] });
  set(`users/${UID}/bikes/b1`, { name: 'FZ' });
  set(`users/${UID}/maintenance/m1`, { type: 'oil' });
  set(`users/${UID}/emergencyContacts/c1`, { name: 'Mum', phone: '+8801700000000' });
  set(`users/${UID}/notifications/n1`, { type: 'follow', fromUid: OTHER });
  set(`users/${UID}/blocks/${OTHER}`, { blockedAt: 1 });
  // A shared ride on the feed, and the rider's comment on someone else's.
  set('rides/shared1', { userId: UID, audience: 'public' });
  set('rides/shared1/comments/k1', { userId: OTHER, userName: 'Other', text: 'nice' });
  set('rides/othersRide', { userId: OTHER, audience: 'public' });
  set('rides/othersRide/comments/k2', { userId: UID, userName: 'Gone', userPhotoUrl: 'x', text: 'wow' });
  set(`follows/${UID}_${OTHER}`, { followerUid: UID, followeeUid: OTHER });
  set(`follows/${OTHER}_${UID}`, { followerUid: OTHER, followeeUid: UID });

  // Forum follows: one live forum the rider and someone else follow, and one
  // follow pointing at a forum that has since been deleted.
  set('forums/f1', { name: 'Dhaka riders', followerCount: 2 });
  set(`forum_follows/${UID}_f1`, { userId: UID, forumId: 'f1' });
  set(`forum_follows/${OTHER}_f1`, { userId: OTHER, forumId: 'f1' });
  set(`forum_follows/${UID}_gone`, { userId: UID, forumId: 'gone' });
  set('forums/f1/posts/p1', { userId: UID, userName: 'Gone', userPhotoUrl: 'x', body: 'hi' });
  set('forums/f1/posts/p2', { userId: OTHER, userName: 'Other', body: 'yo' });
  set('forums/f1/posts/p2/replies/q1', { userId: UID, userName: 'Gone', userPhotoUrl: 'x', body: 'me too' });

  // r1: someone else's ride the rider joined (with a legacy inline roster).
  set('groupRides/r1', {
    creatorId: OTHER,
    memberIds: [OTHER, UID],
    invitedIds: [],
    status: 'active',
    members: [
      { userId: OTHER, userName: 'Other' },
      { userId: UID, userName: 'Gone' },
    ],
  });
  set(`groupRides/r1/members/${UID}`, { userId: UID, userName: 'Gone' });
  set(`groupRides/r1/members/${OTHER}`, { userId: OTHER, userName: 'Other' });
  set(`groupRides/r1/memberLocations/${UID}`, { lat: 23.8, lng: 90.4 });
  set(`groupRides/r1/memberLocations/${OTHER}`, { lat: 23.7, lng: 90.3 });

  // r2: someone else's ride the rider is only invited to.
  set('groupRides/r2', {
    creatorId: OTHER,
    memberIds: [OTHER],
    invitedIds: [UID],
    status: 'planned',
  });
  set(`groupRides/r2/invitations/${UID}`, { status: 'pending' });

  // r3: a ride the rider created, with another rider in it.
  set('groupRides/r3', {
    creatorId: UID,
    memberIds: [UID, OTHER],
    invitedIds: [],
    status: 'active',
  });
  set(`groupRides/r3/members/${OTHER}`, { userId: OTHER });
  set(`groupRides/r3/memberLocations/${UID}`, { lat: 1, lng: 1 });
  set(`groupRides/r3/memberLocations/${OTHER}`, { lat: 2, lng: 2 });

  set(`liveSessions/${TOKEN}`, { uid: UID });
  set('crashEvents/ev-1', { ownerUid: UID, label: 'crash' });
  set(`livePointers/${UID}`, { token: TOKEN });
  set(`handleLinks/${'b'.repeat(64)}`, { uid: UID, token: null, lastLat: 23.7, lastLng: 90.4 });
  set(`chats/${CHAT_ID}`, {
    participants: [UID, OTHER].sort(),
    lastMessage: { senderId: UID, text: 'see you at 6', createdAt: 5 },
    updatedAt: 5,
    participantNames: { [UID]: 'Gone', [OTHER]: 'Other' },
    participantPhotos: { [UID]: 'x' },
  });
  set(`chats/${CHAT_ID}/messages/m1`, { senderId: UID, text: 'see you at 6', createdAt: 5 });
  set(`chats/${CHAT_ID}/messages/m2`, { senderId: OTHER, text: 'ok', createdAt: 4 });
  set(`chats/${OTHER}_zzz`, { participants: [OTHER, 'zzz'] });
  // A chat whose other side was deleted earlier: nobody is left after this.
  set('chats/orphan', { participants: [DELETED_PARTICIPANT, UID] });
  set('chats/orphan/messages/o1', { senderId: UID, text: 'anyone?' });
  // The moderation report holding a copy of one of the rider's messages.
  set('reports/auto_chat_1', { reportedId: UID, contentType: 'chat', originalText: 'you idiot', reporterId: 'system', status: 'actioned' });
  set('reports/other', { reportedId: OTHER, contentType: 'chat', originalText: 'hm' });
  // Rider reports with a snapshot (2026-10-21): against the rider, pending
  // (kept whole) and closed (uid anonymised, text kept until the retention
  // purge), and one by the rider (untouched).
  set('reports/against', { reporterId: OTHER, reportedId: UID, contentType: 'chat', status: 'pending', snapshot: { text: 'you idiot', senderId: UID, sentAt: 1 } });
  set('reports/againstClosed', { reporterId: OTHER, reportedId: UID, contentType: 'post', status: 'dismissed', snapshot: { title: 't', body: 'b', imageUrls: [], senderId: UID, sentAt: 3 } });
  set('reports/by', { reporterId: UID, reportedId: OTHER, contentType: 'chat', snapshot: { text: 'hm', senderId: OTHER, sentAt: 2 } });
  await batch.commit();

  await rtdb.ref().set({
    live_shares: {
      [TOKEN]: { uid: UID, expiresAt: Date.now() + 60000, location: { lat: 1, lng: 1, ts: 1, seq: 1 } },
      [OTHER_TOKEN]: { uid: OTHER, expiresAt: Date.now() + 60000 },
    },
    group_rides: {
      r1: {
        meta: { creatorId: OTHER },
        locations: {
          [UID]: { lat: 1, lng: 1, ts: 1, seq: 1 },
          [OTHER]: { lat: 2, lng: 2, ts: 1, seq: 1 },
        },
      },
      r3: {
        meta: { creatorId: UID },
        locations: { [OTHER]: { lat: 2, lng: 2, ts: 1, seq: 1 } },
      },
    },
    chat_presence: {
      [CHAT_ID]: {
        [UID]: { typing: true, ts: 1 },
        [OTHER]: { typing: false, ts: 1 },
      },
    },
  });
}

test('deleteUserData erases the rider everywhere and records a complete marker', async () => {
  await clearEmulators();
  await seed();

  const result = await deleteUserData(db, UID, { rtdb });
  assert.deepEqual(result, { failedSteps: [], rtdbSkipped: false });

  // Profile + username.
  assert.equal(await exists(`users/${UID}`), false);
  assert.equal(await exists('usernames/gonerider'), false);

  // Everything under the profile: rides and GPS track, emergency contacts
  // (other people's numbers), the private email doc, bikes, maintenance,
  // notifications, blocks.
  for (const path of [
    `users/${UID}/private/account`,
    `users/${UID}/rides/ride1`,
    `users/${UID}/rides/ride1/track/0`,
    `users/${UID}/bikes/b1`,
    `users/${UID}/maintenance/m1`,
    `users/${UID}/emergencyContacts/c1`,
    `users/${UID}/notifications/n1`,
    `users/${UID}/blocks/${OTHER}`,
  ]) {
    assert.equal(await exists(path), false, `${path} survived`);
  }

  // Email lookup: the rider's goes, another rider's stays.
  assert.equal(await exists(`emailLookup/${EMAIL_HASH}`), false);
  assert.equal(await exists('emailLookup/' + 'd'.repeat(64)), true);

  // Shared rides go with their comments; follow edges both ways go.
  assert.equal(await exists('rides/shared1'), false);
  assert.equal(await exists('rides/shared1/comments/k1'), false);
  assert.equal(await exists(`follows/${UID}_${OTHER}`), false);
  assert.equal(await exists(`follows/${OTHER}_${UID}`), false);

  // Chats (2026-10-21): the other rider keeps the DM; the rider's side is
  // anonymised and their text blanked. A chat with nobody left goes.
  const chat = (await db.doc(`chats/${CHAT_ID}`).get()).data();
  assert.deepEqual(chat.participants, [UID, OTHER].sort().map((p) => (p === UID ? DELETED_PARTICIPANT : p)));
  assert.deepEqual(chat.lastMessage, { senderId: DELETED_PARTICIPANT, text: '', createdAt: 5 });
  assert.equal(chat.updatedAt, 5, 'list order unchanged');
  assert.deepEqual(chat.participantNames, { [OTHER]: 'Other' });
  assert.deepEqual(chat.participantPhotos, {});
  assert.deepEqual((await db.doc(`chats/${CHAT_ID}/messages/m1`).get()).data(),
    { senderId: DELETED_PARTICIPANT, text: '', createdAt: 5 });
  assert.deepEqual((await db.doc(`chats/${CHAT_ID}/messages/m2`).get()).data(),
    { senderId: OTHER, text: 'ok', createdAt: 4 });
  assert.equal(JSON.stringify(chat).includes(UID), false, 'no uid left in the chat doc');
  // The survivor's inbox query still finds it.
  const inbox = await db.collection('chats').where('participants', 'array-contains', OTHER).get();
  assert.ok(inbox.docs.some((d) => d.id === CHAT_ID));
  assert.equal(await exists(`chats/${OTHER}_zzz`), true);
  assert.equal(await exists('chats/orphan'), false);
  assert.equal(await exists('chats/orphan/messages/o1'), false);
  const report = (await db.doc('reports/auto_chat_1').get()).data();
  assert.equal(report.reportedId, '');
  assert.equal(report.originalText, '');
  assert.equal((await db.doc('reports/other').get()).get('originalText'), 'hm');
  assert.deepEqual((await db.doc('reports/against').get()).data(), {
    reporterId: OTHER, reportedId: UID, contentType: 'chat', status: 'pending', reportedAccountDeleted: true,
    snapshot: { text: 'you idiot', senderId: UID, sentAt: 1 },
  });
  const closed = (await db.doc('reports/againstClosed').get()).data();
  assert.equal(closed.reportedId, '');
  assert.deepEqual(closed.snapshot, { title: 't', body: 'b', imageUrls: [], senderId: DELETED_PARTICIPANT, sentAt: 3 });
  assert.deepEqual((await db.doc('reports/by').get()).data(), { reporterId: UID, reportedId: OTHER, contentType: 'chat', snapshot: { text: 'hm', senderId: OTHER, sentAt: 2 } });

  // Forum follows: the rider's are gone, the other rider's stays, and the
  // live forum's count drops by exactly one. The deleted forum is not
  // recreated.
  assert.equal(await exists(`forum_follows/${UID}_f1`), false);
  assert.equal(await exists(`forum_follows/${UID}_gone`), false);
  assert.equal(await exists(`forum_follows/${OTHER}_f1`), true);
  assert.equal((await db.doc('forums/f1').get()).get('followerCount'), 1);
  assert.equal(await exists('forums/gone'), false);

  // Forum bylines: the post, the reply in someone else's thread, and the
  // comment on someone else's ride are anonymized, not deleted.
  const byline = async (path) => {
    const d = (await db.doc(path).get()).data();
    return { userId: d.userId, userName: d.userName, userPhotoUrl: d.userPhotoUrl, body: d.body ?? d.text };
  };
  const gone = { userId: '', userName: DELETED_RIDER, userPhotoUrl: '' };
  assert.deepEqual(await byline('forums/f1/posts/p1'), { ...gone, body: 'hi' });
  assert.deepEqual(await byline('forums/f1/posts/p2/replies/q1'), { ...gone, body: 'me too' });
  assert.deepEqual(await byline('rides/othersRide/comments/k2'), { ...gone, body: 'wow' });
  assert.equal((await db.doc('forums/f1/posts/p2').get()).get('userId'), OTHER);

  // r1: only the rider's rows and array entries are gone.
  const r1 = (await db.doc('groupRides/r1').get()).data();
  assert.deepEqual(r1.memberIds, [OTHER]);
  assert.deepEqual(r1.members, [{ userId: OTHER, userName: 'Other' }]);
  assert.equal(r1.status, 'active');
  assert.equal(await exists(`groupRides/r1/members/${UID}`), false);
  assert.equal(await exists(`groupRides/r1/memberLocations/${UID}`), false);
  assert.equal(await exists(`groupRides/r1/members/${OTHER}`), true);
  assert.equal(await exists(`groupRides/r1/memberLocations/${OTHER}`), true);

  // r2: the invitation is withdrawn.
  const r2 = (await db.doc('groupRides/r2').get()).data();
  assert.deepEqual(r2.invitedIds, []);
  assert.deepEqual(r2.memberIds, [OTHER]);
  assert.equal(await exists(`groupRides/r2/invitations/${UID}`), false);

  // r3: the rider's own ride is ended, NOT deleted; other riders' rows stay.
  const r3 = (await db.doc('groupRides/r3').get()).data();
  assert.equal(r3.status, 'completed');
  assert.ok(r3.endedAt, 'endedAt written');
  assert.equal(await exists(`groupRides/r3/memberLocations/${UID}`), false);
  assert.equal(await exists(`groupRides/r3/memberLocations/${OTHER}`), true);
  assert.equal(await exists(`groupRides/r3/members/${OTHER}`), true);

  // Live share docs.
  assert.equal(await exists(`liveSessions/${TOKEN}`), false);
  assert.equal(await exists('crashEvents/ev-1'), false);
  assert.equal(await exists(`livePointers/${UID}`), false);
  assert.equal(await exists(`handleLinks/${'b'.repeat(64)}`), false);

  // RTDB.
  assert.equal(await rtdbVal(`live_shares/${TOKEN}`), null);
  assert.notEqual(await rtdbVal(`live_shares/${OTHER_TOKEN}`), null);
  assert.equal(await rtdbVal(`group_rides/r1/locations/${UID}`), null);
  assert.notEqual(await rtdbVal(`group_rides/r1/locations/${OTHER}`), null);
  assert.notEqual(await rtdbVal('group_rides/r1/meta'), null);
  assert.equal(await rtdbVal('group_rides/r3'), null, 'ended ride channel removed');
  assert.equal(await rtdbVal(`chat_presence/${CHAT_ID}/${UID}`), null);
  assert.notEqual(await rtdbVal(`chat_presence/${CHAT_ID}/${OTHER}`), null);

  // Completion marker.
  const marker = (await db.doc(`accountDeletions/${UID}`).get()).data();
  assert.equal(marker.ok, true);
  assert.deepEqual(marker.failedSteps, []);
  assert.equal(marker.rtdbSkipped, false);
  assert.ok(marker.completedAt, 'completedAt written');
});

test('deleteUserData is safe to re-run', async () => {
  // Continues from the state the previous test left.
  const result = await deleteUserData(db, UID, { rtdb });
  assert.deepEqual(result.failedSteps, []);
  assert.equal((await db.doc('forums/f1').get()).get('followerCount'), 1);
  assert.equal((await db.doc(`chats/${CHAT_ID}/messages/m2`).get()).get('text'), 'ok');
});

test('a re-run after a partial chat anonymisation finishes it', async () => {
  await clearEmulators();
  // State left by a run that failed mid-chat: one of the rider's messages is
  // already anonymised, one is not, and participants (changed last) still
  // name the rider. The profile and its `username` are already gone, but the
  // username claim was not released.
  const batch = db.batch();
  const set = (path, data) => batch.set(db.doc(path), data);
  set('usernames/gonerider', { uid: UID });
  set('usernames/someoneelse', { uid: OTHER });
  set(`chats/${CHAT_ID}`, {
    participants: [UID, OTHER].sort(),
    lastMessage: { senderId: OTHER, text: 'still there?', createdAt: 9 },
    updatedAt: 9,
  });
  set(`chats/${CHAT_ID}/messages/m1`, { senderId: DELETED_PARTICIPANT, text: '', createdAt: 5 });
  set(`chats/${CHAT_ID}/messages/m2`, { senderId: UID, text: 'call me', createdAt: 6 });
  set(`chats/${CHAT_ID}/messages/m3`, { senderId: OTHER, text: 'still there?', createdAt: 9 });
  await batch.commit();

  for (let run = 0; run < 2; run++) {
    const result = await deleteUserData(db, UID, { rtdb });
    assert.deepEqual(result.failedSteps, [], `run ${run}`);
    const chat = (await db.doc(`chats/${CHAT_ID}`).get()).data();
    assert.deepEqual(chat.participants, [UID, OTHER].sort().map((p) => (p === UID ? DELETED_PARTICIPANT : p)));
    assert.deepEqual(chat.lastMessage, { senderId: OTHER, text: 'still there?', createdAt: 9 }, "the other rider's preview is kept");
    assert.deepEqual((await db.doc(`chats/${CHAT_ID}/messages/m1`).get()).data(), { senderId: DELETED_PARTICIPANT, text: '', createdAt: 5 });
    assert.deepEqual((await db.doc(`chats/${CHAT_ID}/messages/m2`).get()).data(), { senderId: DELETED_PARTICIPANT, text: '', createdAt: 6 });
    assert.deepEqual((await db.doc(`chats/${CHAT_ID}/messages/m3`).get()).data(), { senderId: OTHER, text: 'still there?', createdAt: 9 });
    assert.equal(await exists('usernames/gonerider'), false, 'claim released without the profile');
    assert.equal(await exists('usernames/someoneelse'), true);
  }
});

test('a partial erasure is recorded as failed steps, not just logged', async () => {
  await clearEmulators();
  // Media in the ledger, but no Cloudinary credentials configured.
  await db.doc(`users/${UID}/cloudinaryAssets/a1`).set({
    publicId: `avatars/${UID}/x`,
    resourceType: 'image',
  });

  const result = await deleteUserData(db, UID, { rtdb: null });
  assert.deepEqual(result, {
    failedSteps: ['cloudinary (no credentials)'],
    rtdbSkipped: true,
  });
  const marker = (await db.doc(`accountDeletions/${UID}`).get()).data();
  assert.equal(marker.ok, false);
  assert.deepEqual(marker.failedSteps, ['cloudinary (no credentials)']);
  assert.equal(marker.rtdbSkipped, true);
});

test('with credentials, owned media is destroyed by a signed call; foreign rows are skipped', async () => {
  await clearEmulators();
  await db.doc(`users/${UID}/cloudinaryAssets/a1`).set({ publicId: `avatars/${UID}/x`, resourceType: 'image' });
  await db.doc(`users/${UID}/cloudinaryAssets/a2`).set({ publicId: `voiceNotes/${UID}/v`, resourceType: 'video' });
  await db.doc(`users/${UID}/cloudinaryAssets/a3`).set({ publicId: `avatars/${OTHER}/victim`, resourceType: 'image' });

  // No call may leave the machine: fetch is stubbed for Cloudinary only.
  const calls = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    if (!String(url).startsWith('https://api.cloudinary.com/')) return realFetch(url, init);
    calls.push({ url: String(url), body: Object.fromEntries(init.body) });
    return { ok: true, json: async () => ({ result: 'ok' }) };
  };
  try {
    const result = await deleteUserData(db, UID, {
      rtdb: null,
      cloudinary: { cloud: 'demo-cloud', apiKey: 'k', apiSecret: 's' },
    });
    assert.deepEqual(result.failedSteps, []);
  } finally {
    globalThis.fetch = realFetch;
  }

  assert.deepEqual(calls.map((c) => c.url).sort(), [
    'https://api.cloudinary.com/v1_1/demo-cloud/image/destroy',
    'https://api.cloudinary.com/v1_1/demo-cloud/video/destroy',
  ]);
  const avatar = calls.find((c) => c.body.public_id === `avatars/${UID}/x`);
  const expected = createHash('sha1')
    .update(`public_id=avatars/${UID}/x&timestamp=${avatar.body.timestamp}s`)
    .digest('hex');
  assert.equal(avatar.body.signature, expected);
  assert.equal(avatar.body.api_key, 'k');
  assert.ok(!calls.some((c) => c.body.public_id.includes(OTHER)), 'foreign asset destroyed');
  assert.equal(await exists(`users/${UID}/cloudinaryAssets/a1`), false, 'ledger deleted with the profile');
});

// Security sweep 2026-10-30 C1: the Cloudinary sweep is the slowest step (one
// HTTP call per asset). A timeout in it must not leave the profile behind,
// and the ledger must outlive it so a retry can still find the media.
test('the profile goes before the Cloudinary sweep; the ledger after it', async () => {
  await clearEmulators();
  await db.doc(`users/${UID}`).set({ username: 'GoneRider' });
  await db.doc(`users/${UID}/emergencyContacts/c1`).set({ name: 'Mum', phone: '+8801700000000' });
  await db.doc(`users/${UID}/cloudinaryAssets/a1`).set({ publicId: `avatars/${UID}/x`, resourceType: 'image' });

  const seen = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    if (!String(url).startsWith('https://api.cloudinary.com/')) return realFetch(url, init);
    seen.push({
      profile: await exists(`users/${UID}`),
      contact: await exists(`users/${UID}/emergencyContacts/c1`),
      ledger: await exists(`users/${UID}/cloudinaryAssets/a1`),
    });
    return { ok: true, json: async () => ({ result: 'ok' }) };
  };
  try {
    const result = await deleteUserData(db, UID, {
      rtdb: null,
      cloudinary: { cloud: 'demo-cloud', apiKey: 'k', apiSecret: 's' },
    });
    assert.deepEqual(result.failedSteps, []);
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.deepEqual(seen, [{ profile: false, contact: false, ledger: true }]);
  assert.equal(await exists(`users/${UID}/cloudinaryAssets/a1`), false);
});

test('empty credentials (an unset secret) skip the sweep without throwing', async () => {
  await clearEmulators();
  await db.doc(`users/${UID}/cloudinaryAssets/a1`).set({ publicId: `avatars/${UID}/x`, resourceType: 'image' });
  const result = await deleteUserData(db, UID, {
    rtdb: null,
    cloudinary: { cloud: 'demo-cloud', apiKey: '', apiSecret: '' },
  });
  assert.deepEqual(result.failedSteps, ['cloudinary (no credentials)']);
  assert.equal(await exists(`users/${UID}`), false);
});

// Critique 2026-10-27 #16: the rider's identity in other riders' space. Each
// test seeds its own data and runs the erasure twice: a retry must not fail
// or apply anything twice.
async function seedAndEraseTwice(docs, check) {
  await clearEmulators();
  const batch = db.batch();
  for (const [path, data] of Object.entries(docs)) batch.set(db.doc(path), data);
  await batch.commit();
  for (let run = 0; run < 2; run++) {
    const result = await deleteUserData(db, UID, { rtdb: null });
    assert.deepEqual(result.failedSteps, [], `run ${run}`);
    await check();
  }
}

test('notifications the rider sent into other inboxes are deleted', async () => {
  await seedAndEraseTwice({
    [`users/${OTHER}/notifications/follow_${UID}`]: { type: 'follow', fromUid: UID, fromName: 'Gone', fromPhotoUrl: 'x' },
    [`users/${OTHER}/notifications/inv1`]: { type: 'groupRideInvite', fromUid: UID, fromName: 'Gone', groupRideId: 'r1' },
    [`users/${OTHER}/notifications/follow_third`]: { type: 'follow', fromUid: 'third', fromName: 'Third' },
  }, async () => {
    assert.equal(await exists(`users/${OTHER}/notifications/follow_${UID}`), false);
    assert.equal(await exists(`users/${OTHER}/notifications/inv1`), false);
    assert.equal(await exists(`users/${OTHER}/notifications/follow_third`), true);
  });
});

test("voice notes lose the rider's name, photo and clip, also on rides they left", async () => {
  const note = (senderId, senderName) => ({
    senderId, senderName, senderPhotoUrl: 'x', audioUrl: `https://res.cloudinary.com/vjvcigkt/video/upload/voiceNotes/${senderId}/v`, durationMs: 1000,
  });
  await seedAndEraseTwice({
    'groupRides/left': { creatorId: OTHER, memberIds: [OTHER], invitedIds: [], status: 'active' },
    'groupRides/left/voiceNotes/v1': note(UID, 'Gone'),
    'groupRides/left/voiceNotes/v2': note(OTHER, 'Other'),
  }, async () => {
    assert.deepEqual((await db.doc('groupRides/left/voiceNotes/v1').get()).data(), {
      senderId: DELETED_PARTICIPANT, senderName: DELETED_RIDER, senderPhotoUrl: '', audioUrl: '', durationMs: 1000,
    });
    assert.deepEqual((await db.doc('groupRides/left/voiceNotes/v2').get()).data(), note(OTHER, 'Other'));
  });
});

test("the rider's votes are deleted and the tallies drop to match", async () => {
  await seedAndEraseTwice({
    'rides/othersRide': { userId: OTHER, upvotes: 2, downvotes: 0 },
    // Current app writes `{value, uid}`; build 29 wrote `{value}` only (p2).
    [`rides/othersRide/votes/${UID}`]: { value: 1, uid: UID },
    [`rides/othersRide/votes/${OTHER}`]: { value: 1, uid: OTHER },
    'forums/f1/posts/p2': { userId: OTHER, upvotes: 0, downvotes: 1 },
    [`forums/f1/posts/p2/votes/${UID}`]: { value: -1 },
    // A vote left under a ride that has since been deleted.
    [`rides/gone/votes/${UID}`]: { value: 1 },
  }, async () => {
    assert.equal(await exists(`rides/othersRide/votes/${UID}`), false);
    assert.equal(await exists(`rides/othersRide/votes/${OTHER}`), true);
    assert.equal(await exists(`forums/f1/posts/p2/votes/${UID}`), false);
    assert.equal(await exists(`rides/gone/votes/${UID}`), false);
    assert.equal(await exists('rides/gone'), false, 'deleted parent not recreated');
    const ride = (await db.doc('rides/othersRide').get()).data();
    assert.deepEqual([ride.upvotes, ride.downvotes], [1, 0]);
    const post = (await db.doc('forums/f1/posts/p2').get()).data();
    assert.deepEqual([post.upvotes, post.downvotes], [0, 0]);
  });
});

test("the rider's place reviews are kept, detached, under an id without the uid", async () => {
  await seedAndEraseTwice({
    'places/pl1': { name: 'Pump', ratingSum: 9, ratingCount: 2 },
    [`reviews/${UID}_pl1`]: { placeId: 'pl1', userId: UID, stars: 4, text: 'good', flagged: false },
    [`reviews/${OTHER}_pl1`]: { placeId: 'pl1', userId: OTHER, stars: 5, text: 'great', flagged: false },
  }, async () => {
    assert.equal(await exists(`reviews/${UID}_pl1`), false);
    assert.equal(await exists(`reviews/${OTHER}_pl1`), true);
    const reviews = (await db.collection('reviews').where('placeId', '==', 'pl1').get()).docs;
    assert.equal(reviews.length, 2, 'moved once, not copied on the retry');
    const moved = reviews.find((d) => d.id !== `${OTHER}_pl1`);
    assert.ok(!moved.id.includes(UID));
    assert.deepEqual(moved.data(), { placeId: 'pl1', userId: '', stars: 4, text: 'good', flagged: false });
    const place = (await db.doc('places/pl1').get()).data();
    assert.deepEqual([place.ratingSum, place.ratingCount], [9, 2], 'rating aggregate still matches the reviews');
  });
});

test("a group ride the rider created loses their roster row and creator name", async () => {
  await seedAndEraseTwice({
    'groupRides/mine': {
      creatorId: UID, creatorName: 'Gone', memberIds: [UID, OTHER], invitedIds: [], status: 'active',
      members: [{ userId: UID, userName: 'Gone' }, { userId: OTHER, userName: 'Other' }],
    },
    [`groupRides/mine/members/${UID}`]: { userId: UID, userName: 'Gone', userPhotoUrl: 'x' },
    [`groupRides/mine/members/${OTHER}`]: { userId: OTHER, userName: 'Other' },
    [`groupRides/mine/memberLocations/${UID}`]: { lat: 1, lng: 1 },
  }, async () => {
    const ride = (await db.doc('groupRides/mine').get()).data();
    assert.equal(ride.creatorName, DELETED_RIDER);
    assert.equal(ride.status, 'completed');
    assert.deepEqual(ride.members, [{ userId: OTHER, userName: 'Other' }]);
    assert.equal(await exists(`groupRides/mine/members/${UID}`), false);
    assert.equal(await exists(`groupRides/mine/memberLocations/${UID}`), false);
    assert.equal(await exists(`groupRides/mine/members/${OTHER}`), true);
  });
});

test.after(async () => {
  await rtdb.app.delete();
});
