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
const { deleteUserData, DELETED_RIDER } = require('../../lib/account-erasure');

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
  set(`livePointers/${UID}`, { token: TOKEN });
  set(`chats/${CHAT_ID}`, { participants: [UID, OTHER].sort() });
  set(`chats/${CHAT_ID}/messages/m1`, { senderId: UID, text: 'see you at 6' });
  set(`chats/${CHAT_ID}/messages/m2`, { senderId: OTHER, text: 'ok' });
  set(`chats/${OTHER}_zzz`, { participants: [OTHER, 'zzz'] });
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

  // Chats: the rider's DM and all its messages are gone; others' chats stay.
  assert.equal(await exists(`chats/${CHAT_ID}`), false);
  assert.equal(await exists(`chats/${CHAT_ID}/messages/m1`), false);
  assert.equal(await exists(`chats/${CHAT_ID}/messages/m2`), false);
  assert.equal(await exists(`chats/${OTHER}_zzz`), true);

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
  assert.equal(await exists(`livePointers/${UID}`), false);

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

test.after(async () => {
  await rtdb.app.delete();
});
