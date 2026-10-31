'use strict';

/**
 * reconcileRideIdentity (ride-identity.ts) against the Firestore emulator:
 * a spoofed byline is overwritten from the profile, the correcting write
 * does not loop, counter bumps cost nothing, and a ride without a profile
 * or userId is left alone.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const { db, rtdb, clearEmulators } = require('./setup');
const { reconcileRideIdentity } = require('../../lib/ride-identity');

const UID = 'rideIdentityUid0001';
const PHOTO = 'https://res.cloudinary.com/vjvcigkt/image/upload/v1/a.jpg';

/** Writes `after` over `before` and runs the trigger on that change. */
async function write(id, after) {
  const ref = db.doc(`rides/${id}`);
  const before = await ref.get();
  await ref.set(after);
  await reconcileRideIdentity.run({
    data: { before, after: await ref.get() },
    params: { rideId: id },
  });
  return (await ref.get()).data();
}

test.before(async () => {
  await clearEmulators();
  await db.doc(`users/${UID}`).set({ displayName: 'Real Rider', photoUrl: PHOTO });
});

test('a spoofed name and photo are overwritten from the profile', async () => {
  const ride = await write('r1', { userId: UID, userName: 'Someone Famous', userPhotoUrl: 'https://evil.example/x.png' });
  assert.equal(ride.userName, 'Real Rider');
  assert.equal(ride.userPhotoUrl, PHOTO);
});

test('the correcting write re-triggers once and stops (no loop)', async () => {
  const ref = db.doc('rides/r1');
  const snap = await ref.get();
  const before = snap.updateTime;
  // The trigger's own write, delivered back: nothing differs, nothing written.
  await reconcileRideIdentity.run({ data: { before: snap, after: snap }, params: { rideId: 'r1' } });
  assert.deepEqual((await ref.get()).updateTime, before);
});

test('a vote bump that leaves the byline alone costs no profile read or write', async () => {
  // Profile changes after the share; a counter-only write must not pull it in.
  await db.doc(`users/${UID}`).update({ displayName: 'Renamed' });
  const cur = (await db.doc('rides/r1').get()).data();
  const ride = await write('r1', { ...cur, upvotes: 1 });
  assert.equal(ride.userName, 'Real Rider');
  await db.doc(`users/${UID}`).update({ displayName: 'Real Rider' });
});

test('a profile without displayName falls back to the app name rule, not blank', async () => {
  await db.doc('users/nickOnly').set({ nickname: 'Nick', username: 'nick_r' });
  const ride = await write('r2', { userId: 'nickOnly', userName: 'x', userPhotoUrl: '' });
  assert.equal(ride.userName, 'Nick');
  assert.equal(ride.userPhotoUrl, '');
});

test('no profile doc, or no userId: the ride is left as written', async () => {
  const noProfile = await write('r3', { userId: 'ghostUid', userName: 'Ghost', userPhotoUrl: '' });
  assert.equal(noProfile.userName, 'Ghost');
  const noUid = await write('r4', { userName: 'Orphan', userPhotoUrl: '' });
  assert.equal(noUid.userName, 'Orphan');
});

test.after(async () => {
  await rtdb.app.delete();
});
