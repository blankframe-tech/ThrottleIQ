'use strict';

/**
 * deleteUserData (account-erasure.ts) against the Firestore + Database
 * emulators: issues §101.S4 (forum follows, group rides, RTDB, completion
 * marker). §101.S2's collection-group index cannot be checked here: the
 * Firestore emulator does not enforce indexes.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const { db, rtdb, clearEmulators } = require('./setup');
const { deleteUserData, DELETED_RIDER } = require('../../lib/account-erasure');

const UID = 'deletedRiderUid000000000001';
const OTHER = 'otherRiderUid0000000000002';
const TOKEN = 'a'.repeat(40);
const OTHER_TOKEN = 'b'.repeat(40);
const CHAT_ID = [UID, OTHER].sort().join('_');

const exists = async (path) => (await db.doc(path).get()).exists;
const rtdbVal = async (path) => (await rtdb.ref(path).get()).val();

async function seed() {
  const batch = db.batch();
  const set = (path, data) => batch.set(db.doc(path), data);

  set(`users/${UID}`, { username: 'GoneRider', displayName: 'Gone' });
  set('usernames/gonerider', { uid: UID });

  // Forum follows: one live forum the rider and someone else follow, and one
  // follow pointing at a forum that has since been deleted.
  set('forums/f1', { name: 'Dhaka riders', followerCount: 2 });
  set(`forum_follows/${UID}_f1`, { userId: UID, forumId: 'f1' });
  set(`forum_follows/${OTHER}_f1`, { userId: OTHER, forumId: 'f1' });
  set(`forum_follows/${UID}_gone`, { userId: UID, forumId: 'gone' });
  set('forums/f1/posts/p1', { userId: UID, userName: 'Gone', userPhotoUrl: 'x', body: 'hi' });

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

test.before(async () => {
  delete process.env.CLOUDINARY_CLOUD_NAME;
  delete process.env.CLOUDINARY_API_KEY;
  delete process.env.CLOUDINARY_API_SECRET;
});

test('deleteUserData erases the rider everywhere and records a complete marker', async () => {
  await clearEmulators();
  await seed();

  const result = await deleteUserData(db, UID, { rtdb });
  assert.deepEqual(result, { failedSteps: [], rtdbSkipped: false });

  // Profile + username.
  assert.equal(await exists(`users/${UID}`), false);
  assert.equal(await exists('usernames/gonerider'), false);

  // Forum follows: the rider's are gone, the other rider's stays, and the
  // live forum's count drops by exactly one. The deleted forum is not
  // recreated.
  assert.equal(await exists(`forum_follows/${UID}_f1`), false);
  assert.equal(await exists(`forum_follows/${UID}_gone`), false);
  assert.equal(await exists(`forum_follows/${OTHER}_f1`), true);
  assert.equal((await db.doc('forums/f1').get()).get('followerCount'), 1);
  assert.equal(await exists('forums/gone'), false);

  // Forum post anonymized, not deleted.
  const post = (await db.doc('forums/f1/posts/p1').get()).data();
  assert.deepEqual(
    { userId: post.userId, userName: post.userName, userPhotoUrl: post.userPhotoUrl, body: post.body },
    { userId: '', userName: DELETED_RIDER, userPhotoUrl: '', body: 'hi' }
  );

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

test.after(async () => {
  await rtdb.app.delete();
});
