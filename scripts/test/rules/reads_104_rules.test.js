'use strict';

/**
 * issues §104.2 / §104.3 read-cost rules, both additive (build 29 never
 * touches them):
 *  - groupRides/{id}/positions/all: one doc with every rider's live position,
 *    polled by members instead of listening to memberLocations;
 *  - a rider may list their own vote docs across the `votes` collection group
 *    by full path, so the feed fetches a page's votes with one query.
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
  doc, setDoc, getDoc, getDocs, deleteDoc, writeBatch, query, where,
  collectionGroup, documentId, serverTimestamp, Timestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const CREATOR = 'creator-uid';
const MEMBER = 'member-uid';
const INVITEE = 'invitee-uid';
const STRANGER = 'stranger-uid';
const ALL = 'groupRides/g1/positions/all';

let testEnv;
const db = (uid) => testEnv.authenticatedContext(uid).firestore();
const pos = (lat = 23.8, lng = 90.4) => ({ lat, lng, timestamp: serverTimestamp() });
/** GroupRideRepository.updateMemberLocation(shared: true)'s write. */
const publish = (uid, data = pos()) => setDoc(doc(db(uid), ALL), { [uid]: data }, { merge: true });

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-reads-104',
    firestore: { rules: RULES },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    await setDoc(doc(f, 'groupRides/g1'), {
      creatorId: CREATOR, memberIds: [CREATOR, MEMBER], invitedIds: [INVITEE],
      status: 'active', maxParticipants: 20,
    });
    await setDoc(doc(f, 'rides/r1'), {
      userId: CREATOR, audience: 'public', upvotes: 1, downvotes: 0,
    });
    await setDoc(doc(f, 'rides/r1/votes/' + MEMBER), { value: 1 }); // build 29 shape
    await setDoc(doc(f, 'rides/r2/votes/' + MEMBER), { value: -1, uid: MEMBER });
    await setDoc(doc(f, 'rides/r2/votes/' + STRANGER), { value: 1, uid: STRANGER });
    await setDoc(doc(f, 'forums/f1/posts/p1/votes/' + MEMBER), { value: 1, uid: MEMBER });
  });
});

// -- §104.2 shared positions doc -------------------------------------------

test('a member and the creator publish their own key', async () => {
  await assertSucceeds(publish(MEMBER));
  await assertSucceeds(publish(CREATOR));
  await assertSucceeds(publish(MEMBER, pos(23.9, 90.5)));
});

test('the app\'s batched dual write (memberLocations + positions) passes', async () => {
  const f = db(MEMBER);
  const b = writeBatch(f);
  b.set(doc(f, `groupRides/g1/memberLocations/${MEMBER}`), { userId: MEMBER, ...pos() });
  b.set(doc(f, ALL), { [MEMBER]: pos() }, { merge: true });
  await assertSucceeds(b.commit());
});

test('nobody writes someone else\'s key', async () => {
  await assertSucceeds(publish(CREATOR));
  await assertFails(setDoc(doc(db(MEMBER), ALL), { [CREATOR]: pos(1, 1) }, { merge: true }));
  await assertFails(setDoc(doc(db(MEMBER), ALL), { [MEMBER]: pos() })); // overwrite drops CREATOR
});

test('an invitee or a stranger cannot publish', async () => {
  await assertFails(publish(INVITEE));
  await assertFails(publish(STRANGER));
});

test('a position must be {lat, lng, server timestamp} in range', async () => {
  await assertFails(publish(MEMBER, { ...pos(), speed: 9 }));
  await assertFails(publish(MEMBER, { lat: 23.8, lng: 90.4 }));
  await assertFails(publish(MEMBER, { lat: 23.8, lng: 90.4, timestamp: Timestamp.fromMillis(0) }));
  await assertFails(publish(MEMBER, pos(91, 90)));
  await assertFails(publish(MEMBER, { lat: '23.8', lng: 90.4, timestamp: serverTimestamp() }));
  await assertFails(publish(MEMBER, 'here'));
});

test('only the doc `all` exists', async () => {
  await assertFails(setDoc(doc(db(MEMBER), 'groupRides/g1/positions/other'), { [MEMBER]: pos() }));
});

test('before anyone published, a member\'s poll reads a missing doc', async () => {
  await assertSucceeds(getDoc(doc(db(MEMBER), ALL)));
});

test('members, the creator and invitees read it; strangers do not', async () => {
  await assertSucceeds(publish(MEMBER));
  for (const uid of [CREATOR, MEMBER, INVITEE]) await assertSucceeds(getDoc(doc(db(uid), ALL)));
  await assertFails(getDoc(doc(db(STRANGER), ALL)));
});

test('only the creator deletes it', async () => {
  await assertSucceeds(publish(MEMBER));
  await assertFails(deleteDoc(doc(db(MEMBER), ALL)));
  await assertSucceeds(deleteDoc(doc(db(CREATOR), ALL)));
});

// -- §104.3 own votes by collection-group query ----------------------------

const votesByPath = (uid, paths) =>
  getDocs(query(collectionGroup(db(uid), 'votes'), where(documentId(), 'in', paths)));

test('a rider lists their own votes by full path, legacy ones included', async () => {
  const s = await assertSucceeds(votesByPath(MEMBER, [
    `rides/r1/votes/${MEMBER}`, `rides/r2/votes/${MEMBER}`, `rides/r3/votes/${MEMBER}`,
  ]));
  const got = Object.fromEntries(s.docs.map((d) => [d.ref.parent.parent.id, d.data().value]));
  if (JSON.stringify(got) !== JSON.stringify({ r1: 1, r2: -1 })) {
    throw new Error(`unexpected votes ${JSON.stringify(got)}`);
  }
});

test('asking for anyone else\'s vote is denied', async () => {
  await assertFails(votesByPath(MEMBER, [`rides/r2/votes/${MEMBER}`, `rides/r2/votes/${STRANGER}`]));
});

test('an unfiltered or uid-filtered votes query is denied', async () => {
  await assertFails(getDocs(collectionGroup(db(MEMBER), 'votes')));
  await assertFails(getDocs(query(collectionGroup(db(MEMBER), 'votes'), where('uid', '==', MEMBER))));
});

test('the per-ride vote get still works (build 29 path)', async () => {
  await assertSucceeds(getDoc(doc(db(MEMBER), `rides/r1/votes/${MEMBER}`)));
});
