'use strict';

/**
 * Group-ride notifications are tied to a real group ride: an invite only
 * from the ride's creator to a rider on its `invitedIds`, a "joined" only
 * from a member to the ride's creator, and the groupRideId shaped like a
 * document id (it becomes a route on the receiving phone).
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
  doc, collection, setDoc, addDoc, writeBatch, serverTimestamp, arrayUnion,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid'; // group ride creator
const BOB = 'bob-uid'; // invited rider
const CAROL = 'carol-uid'; // rider who is not part of the ride
const MALLORY = 'mallory-uid'; // attacker

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-notif-pin',
    firestore: { rules: RULES },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'groupRides', 'gr1'), {
      id: 'gr1', creatorId: ALICE, creatorName: 'Alice', name: 'Ride', status: 'active',
      memberIds: [ALICE], invitedIds: [BOB], maxParticipants: 3, joinCode: '',
    });
  });
});

const db = (uid) => testEnv.authenticatedContext(uid).firestore();

/** NotificationRepository.notifyGroupRideInvite / notifyGroupRideJoined. */
function notif(fromUid, type, groupRideId) {
  return {
    type, fromUid, fromName: 'Someone', fromPhotoUrl: null, groupRideId,
    createdAt: serverTimestamp(), read: false,
  };
}
const inbox = (asUid, toUid) => collection(db(asUid), 'users', toUid, 'notifications');

test('the creator can invite a rider on the ride\'s invitedIds', async () => {
  await assertSucceeds(addDoc(inbox(ALICE, BOB), notif(ALICE, 'groupRideInvite', 'gr1')));
});

test('an invite written in the same batch as the invitedIds update passes', async () => {
  const f = db(ALICE);
  const ref = doc(collection(f, 'users', CAROL, 'notifications'));
  await assertSucceeds(writeBatch(f)
    .update(doc(f, 'groupRides', 'gr1'), { invitedIds: arrayUnion(CAROL) })
    .set(ref, notif(ALICE, 'groupRideInvite', 'gr1'))
    .commit());
});

test('a stranger cannot flood an inbox with invites to rides that don\'t exist', async () => {
  for (let i = 0; i < 3; i++) {
    await assertFails(addDoc(inbox(MALLORY, BOB), notif(MALLORY, 'groupRideInvite', `fake${i}`)));
  }
});

test('an invite naming someone else\'s ride, or a rider not invited to it, is denied', async () => {
  await assertFails(addDoc(inbox(MALLORY, BOB), notif(MALLORY, 'groupRideInvite', 'gr1')));
  await assertFails(addDoc(inbox(ALICE, CAROL), notif(ALICE, 'groupRideInvite', 'gr1')));
});

test('a member can tell the creator they joined', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'groupRides', 'gr1'),
      { memberIds: [ALICE, BOB], invitedIds: [] }, { merge: true });
  });
  await assertSucceeds(addDoc(inbox(BOB, ALICE), notif(BOB, 'groupRideJoined', 'gr1')));
  // Not to anyone else, though.
  await assertFails(addDoc(inbox(BOB, CAROL), notif(BOB, 'groupRideJoined', 'gr1')));
});

test('a non-member cannot send a "joined" notification', async () => {
  await assertFails(addDoc(inbox(MALLORY, ALICE), notif(MALLORY, 'groupRideJoined', 'gr1')));
  await assertFails(addDoc(inbox(MALLORY, ALICE), notif(MALLORY, 'groupRideJoined', 'nope')));
});

test('a groupRideId that is not id-shaped is denied (it becomes an app route)', async () => {
  for (const id of ['../settings', 'x/../../profile/edit', 'gr1?start=1', 'gr1#x', '']) {
    await assertFails(addDoc(inbox(ALICE, BOB), notif(ALICE, 'groupRideInvite', id)));
  }
});
