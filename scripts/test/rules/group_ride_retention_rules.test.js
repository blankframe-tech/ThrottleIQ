'use strict';

/**
 * Group rides keep no one's location after they are done with it:
 *  - a rider may erase their own position (positions/all key,
 *    memberLocations doc) and voice notes, including after leaving;
 *  - the creator may erase every memberLocations doc when the ride ends;
 *  - a completed ride is final: no reopening, no new invites, and an
 *    invitation no longer reads (or joins) it.
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
  doc, setDoc, getDoc, getDocs, collection, deleteDoc, updateDoc, writeBatch,
  arrayRemove, arrayUnion, deleteField, serverTimestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const CREATOR = 'creator-uid';
const MEMBER = 'member-uid';
const OTHER = 'other-member-uid';
const INVITEE = 'invitee-uid';
const STRANGER = 'stranger-uid';
const RIDE = 'groupRides/g1';
const ALL = `${RIDE}/positions/all`;
const loc = (uid) => `${RIDE}/memberLocations/${uid}`;
const NOTE = `${RIDE}/voiceNotes/n1`;

let testEnv;
const db = (uid) => testEnv.authenticatedContext(uid).firestore();
const pos = () => ({ lat: 23.8, lng: 90.4, timestamp: serverTimestamp() });

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-gr-retention',
    firestore: { rules: RULES },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

async function seed(status) {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, RIDE), {
      creatorId: CREATOR, memberIds: [CREATOR, MEMBER, OTHER],
      invitedIds: [INVITEE], status, maxParticipants: 20,
    });
    await setDoc(doc(f, `${RIDE}/members/${MEMBER}`), { userId: MEMBER, status: 'joined' });
    await setDoc(doc(f, ALL), { [CREATOR]: pos(), [MEMBER]: pos(), [OTHER]: pos() });
    for (const uid of [CREATOR, MEMBER, OTHER]) {
      await setDoc(doc(f, loc(uid)), { userId: uid, ...pos() });
    }
    await setDoc(doc(f, NOTE), {
      senderId: MEMBER, senderName: 'M', audioUrl: 'https://res.cloudinary.com/vjvcigkt/a.m4a',
      durationMs: 2000, createdAt: serverTimestamp(),
    });
  });
}

/** GroupRideRepository.leaveGroupRide's transaction for a non-creator. */
function leave(uid) {
  const f = db(uid);
  const b = writeBatch(f);
  b.delete(doc(f, `${RIDE}/members/${uid}`));
  b.delete(doc(f, loc(uid)));
  b.update(doc(f, RIDE), { memberIds: arrayRemove(uid) });
  return b.commit();
}
const dropOwnKey = (uid) => updateDoc(doc(db(uid), ALL), { [uid]: deleteField() });

// -- erasing your own position and clips -------------------------------------

test('leaving deletes the rider\'s memberLocations doc in the same write', async () => {
  await seed('active');
  await assertSucceeds(leave(MEMBER));
});

test('after leaving, a rider removes their own positions key', async () => {
  await seed('active');
  await assertSucceeds(leave(MEMBER));
  await assertSucceeds(dropOwnKey(MEMBER));
  const left = (await getDoc(doc(db(OTHER), ALL))).data();
  if (MEMBER in left || !(OTHER in left)) throw new Error(JSON.stringify(Object.keys(left)));
});

test('a member removes their own key while still on the ride', async () => {
  await seed('active');
  await assertSucceeds(dropOwnKey(MEMBER));
});

test('nobody removes or edits someone else\'s key, and a leaver cannot publish', async () => {
  await seed('active');
  await assertFails(updateDoc(doc(db(MEMBER), ALL), { [OTHER]: deleteField() }));
  await assertFails(updateDoc(doc(db(STRANGER), ALL), { [OTHER]: deleteField() }));
  await assertFails(updateDoc(doc(db(MEMBER), ALL), { [MEMBER]: deleteField(), [OTHER]: deleteField() }));
  await assertSucceeds(leave(MEMBER));
  await assertFails(setDoc(doc(db(MEMBER), ALL), { [MEMBER]: pos() }, { merge: true }));
  await assertFails(setDoc(doc(db(MEMBER), loc(MEMBER)), { userId: MEMBER, ...pos() }));
});

test('the creator removes a kicked rider\'s key, but cannot edit or add one', async () => {
  await seed('active');
  await assertSucceeds(updateDoc(doc(db(CREATOR), ALL), { [MEMBER]: deleteField() }));
  await assertFails(updateDoc(doc(db(CREATOR), ALL), { [OTHER]: { lat: 1, lng: 1, timestamp: serverTimestamp() } }));
  await assertFails(updateDoc(doc(db(CREATOR), ALL), { [STRANGER]: pos() }));
});

test('after leaving, a rider deletes their own memberLocations doc', async () => {
  await seed('active');
  // The leave itself without the location delete (an older build).
  const f = db(MEMBER);
  const b = writeBatch(f);
  b.delete(doc(f, `${RIDE}/members/${MEMBER}`));
  b.update(doc(f, RIDE), { memberIds: arrayRemove(MEMBER) });
  await assertSucceeds(b.commit());
  await assertSucceeds(deleteDoc(doc(db(MEMBER), loc(MEMBER))));
});

test('only the rider or the creator deletes a memberLocations doc', async () => {
  await seed('active');
  await assertFails(deleteDoc(doc(db(OTHER), loc(MEMBER))));
  await assertFails(deleteDoc(doc(db(STRANGER), loc(MEMBER))));
  await assertSucceeds(deleteDoc(doc(db(CREATOR), loc(MEMBER))));
});

test('the sender deletes their own voice note, even after leaving; others cannot', async () => {
  await seed('active');
  await assertFails(deleteDoc(doc(db(OTHER), NOTE)));
  await assertFails(deleteDoc(doc(db(STRANGER), NOTE)));
  await assertSucceeds(leave(MEMBER));
  await assertSucceeds(deleteDoc(doc(db(MEMBER), NOTE)));
});

// -- ending a ride ------------------------------------------------------------

test('the creator ends the ride and erases every position (endGroupRide)', async () => {
  await seed('active');
  await assertSucceeds(updateDoc(doc(db(CREATOR), RIDE), { status: 'completed', endedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(doc(db(CREATOR), ALL)));
  const locs = await assertSucceeds(getDocs(collection(db(CREATOR), `${RIDE}/memberLocations`)));
  for (const d of locs.docs) await assertSucceeds(deleteDoc(d.ref));
});

// -- a completed ride is final ------------------------------------------------

test('no new invites once a ride is completed', async () => {
  await seed('completed');
  await assertFails(updateDoc(doc(db(CREATOR), RIDE), { invitedIds: arrayUnion(STRANGER) }));
  await assertFails(updateDoc(doc(db(CREATOR), RIDE), { invitedIds: [INVITEE, STRANGER] }));
});

test('a completed ride cannot be reopened', async () => {
  await seed('completed');
  await assertFails(updateDoc(doc(db(CREATOR), RIDE), { status: 'active' }));
  await assertFails(updateDoc(doc(db(CREATOR), RIDE), { status: 'planned' }));
  // Writes that keep it completed still work (e.g. a late endedAt).
  await assertSucceeds(updateDoc(doc(db(CREATOR), RIDE), { endedAt: serverTimestamp() }));
});

test('an invitation reads nothing once the ride is completed', async () => {
  await seed('completed');
  await assertFails(getDoc(doc(db(INVITEE), RIDE)));
  await assertFails(getDoc(doc(db(INVITEE), ALL)));
  await assertFails(getDoc(doc(db(INVITEE), loc(MEMBER))));
  await assertFails(getDoc(doc(db(INVITEE), NOTE)));
  await assertFails(getDoc(doc(db(INVITEE), `${RIDE}/members/${MEMBER}`)));
  // Members still read their own ride's history.
  await assertSucceeds(getDoc(doc(db(MEMBER), RIDE)));
});

test('an invitee cannot accept a completed ride, but may decline it', async () => {
  await seed('completed');
  await assertFails(updateDoc(doc(db(INVITEE), RIDE), {
    memberIds: arrayUnion(INVITEE), invitedIds: arrayRemove(INVITEE),
  }));
  await assertSucceeds(updateDoc(doc(db(INVITEE), RIDE), { invitedIds: arrayRemove(INVITEE) }));
});

test('on an active ride, inviting and invitee reads still work', async () => {
  await seed('active');
  await assertSucceeds(updateDoc(doc(db(CREATOR), RIDE), { invitedIds: arrayUnion(STRANGER) }));
  await assertSucceeds(getDoc(doc(db(INVITEE), ALL)));
  await assertSucceeds(getDoc(doc(db(INVITEE), loc(MEMBER))));
  await assertSucceeds(getDoc(doc(db(INVITEE), RIDE)));
  await assertSucceeds(updateDoc(doc(db(INVITEE), RIDE), {
    memberIds: arrayUnion(INVITEE), invitedIds: arrayRemove(INVITEE),
  }));
});
