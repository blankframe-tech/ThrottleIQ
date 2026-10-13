'use strict';

/**
 * Security-rules tests for database.rules.json (Realtime Database).
 *
 * Contract: DOCS/For Devs and Contributors/architecture/realtime-database.md.
 * One block per path — live_shares, group_rides, chat_presence — each pairing
 * the exact write the app sends with the abuse the rules refuse.
 *
 * Own projectId (= RTDB namespace in the emulator) so `node --test` can run
 * this file in parallel with rtdb_delivery.test.js without one file's
 * clearDatabase() wiping the other's fixtures.
 *
 * Run with:  npm run test:rtdb   (from scripts/)
 */

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'database.rules.json'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const MALLORY = 'mallory-uid';

const TOKEN = 'a'.repeat(32);
const RIDE = 'ride-1';
const DM = `${ALICE}_${BOB}`; // sorted: 'alice-uid' < 'bob-uid'

const SERVER_TS = { '.sv': 'timestamp' };

function location(seq = 0, extra = {}) {
  return { lat: 23.81, lng: 90.41, ts: SERVER_TS, seq, speedMs: 8.3, headingDeg: 271, accuracyM: 6, ...extra };
}

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rtdb-rules-test',
    database: { rules: RULES, host: '127.0.0.1', port: 9000 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearDatabase();
});

const db = (uid) =>
  uid ? testEnv.authenticatedContext(uid).database() : testEnv.unauthenticatedContext().database();

async function seed(pathName, value) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.database().ref(pathName).set(value);
  });
}

function liveShare(uid = ALICE, expiresAt = Date.now() + 60 * 60_000) {
  return { uid, expiresAt, location: { lat: 23.8, lng: 90.4, ts: Date.now(), seq: 0 } };
}

// ---------------------------------------------------------------------------
// /live_shares/{token}
// ---------------------------------------------------------------------------

test('live_shares: owner creates the node with a location', async () => {
  await assertSucceeds(
    db(ALICE).ref(`live_shares/${TOKEN}`).set({
      uid: ALICE,
      expiresAt: Date.now() + 24 * 60 * 60_000,
      location: location(0),
    })
  );
});

test('live_shares: owner updates only the location child (the 1 Hz write)', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  await assertSucceeds(db(ALICE).ref(`live_shares/${TOKEN}/location`).set(location(1)));
});

test('live_shares: owner removes the node (stop sharing / ride end)', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  await assertSucceeds(db(ALICE).ref(`live_shares/${TOKEN}`).remove());
});

test('live_shares: creating a node in someone else\'s name is refused', async () => {
  await assertFails(
    db(MALLORY).ref(`live_shares/${TOKEN}`).set({
      uid: ALICE,
      expiresAt: Date.now() + 60_000,
      location: location(0),
    })
  );
});

test('live_shares: unauthenticated create is refused', async () => {
  await assertFails(
    db(null).ref(`live_shares/${TOKEN}`).set({ uid: ALICE, expiresAt: Date.now() + 60_000 })
  );
});

test('live_shares: another rider cannot hijack an existing token', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  await assertFails(db(MALLORY).ref(`live_shares/${TOKEN}/location`).set(location(5)));
  await assertFails(
    db(MALLORY).ref(`live_shares/${TOKEN}`).set({ uid: MALLORY, expiresAt: Date.now() + 60_000 })
  );
  await assertFails(db(MALLORY).ref(`live_shares/${TOKEN}`).remove());
});

test('live_shares: uid is immutable, even for the owner', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  await assertFails(db(ALICE).ref(`live_shares/${TOKEN}/uid`).set(BOB));
});

test('live_shares: anyone (signed out) can read a live, unexpired node', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  await assertSucceeds(db(null).ref(`live_shares/${TOKEN}/location`).get());
  await assertSucceeds(db(null).ref(`live_shares/${TOKEN}`).get());
});

test('live_shares: reading after expiresAt is denied', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare(ALICE, Date.now() - 1000));
  await assertFails(db(null).ref(`live_shares/${TOKEN}/location`).get());
  await assertFails(db(BOB).ref(`live_shares/${TOKEN}`).get());
});

test('live_shares: listing /live_shares is denied (no token enumeration)', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  await assertFails(db(null).ref('live_shares').get());
  await assertFails(db(ALICE).ref('live_shares').get());
});

test('live_shares: expiresAt more than 24h (+1 min slack) out is refused', async () => {
  await assertFails(
    db(ALICE).ref(`live_shares/${TOKEN}`).set({
      uid: ALICE,
      expiresAt: Date.now() + 25 * 60 * 60_000,
    })
  );
});

test('live_shares: ts must be the server timestamp, not a client clock', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  await assertFails(
    db(ALICE).ref(`live_shares/${TOKEN}/location`).set(location(1, { ts: Date.now() }))
  );
});

test('live_shares: extra keys are refused at every level', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  await assertFails(
    db(ALICE).ref(`live_shares/${TOKEN}/location`).set(location(1, { battery: 80 }))
  );
  await assertFails(db(ALICE).ref(`live_shares/${TOKEN}/note`).set('hi'));
});

test('live_shares: location missing seq, or out-of-range lat, is refused', async () => {
  await seed(`live_shares/${TOKEN}`, liveShare());
  const { seq, ...noSeq } = location(1); // eslint-disable-line no-unused-vars
  await assertFails(db(ALICE).ref(`live_shares/${TOKEN}/location`).set(noSeq));
  await assertFails(db(ALICE).ref(`live_shares/${TOKEN}/location`).set(location(1, { lat: 91 })));
  await assertFails(db(ALICE).ref(`live_shares/${TOKEN}/location`).set(location(1, { speedMs: -1 })));
});

test('live_shares: a token shorter than 32 characters is refused', async () => {
  const short = 'a'.repeat(31);
  await assertFails(
    db(ALICE).ref(`live_shares/${short}`).set({ uid: ALICE, expiresAt: Date.now() + 60_000 })
  );
  await seed(`live_shares/${short}`, liveShare());
  await assertFails(db(null).ref(`live_shares/${short}`).get());
});

// ---------------------------------------------------------------------------
// /group_rides/{rideId}
// ---------------------------------------------------------------------------

async function seedRide({ banned } = {}) {
  await seed(`group_rides/${RIDE}`, {
    meta: { creatorId: ALICE },
    ...(banned ? { banned: { [banned]: true } } : {}),
    locations: {
      [ALICE]: { lat: 23.8, lng: 90.4, ts: Date.now(), seq: 0 },
      [BOB]: { lat: 23.9, lng: 90.5, ts: Date.now(), seq: 0 },
    },
  });
}

test('group_rides: creator writes meta once', async () => {
  await assertSucceeds(db(ALICE).ref(`group_rides/${RIDE}/meta`).set({ creatorId: ALICE }));
  // create-once: even the creator cannot rewrite it.
  await assertFails(db(ALICE).ref(`group_rides/${RIDE}/meta`).set({ creatorId: ALICE }));
});

test('group_rides: claiming meta for someone else is refused', async () => {
  await assertFails(db(MALLORY).ref(`group_rides/${RIDE}/meta`).set({ creatorId: ALICE }));
});

test('group_rides: a non-creator cannot overwrite existing meta', async () => {
  await seedRide();
  await assertFails(db(MALLORY).ref(`group_rides/${RIDE}/meta`).set({ creatorId: MALLORY }));
  await assertFails(db(MALLORY).ref(`group_rides/${RIDE}/meta/creatorId`).set(MALLORY));
});

test('group_rides: meta is readable by any signed-in rider (creator cross-check)', async () => {
  await seedRide();
  await assertSucceeds(db(BOB).ref(`group_rides/${RIDE}/meta`).get());
  await assertFails(db(null).ref(`group_rides/${RIDE}/meta`).get());
});

test('group_rides: a member writes and reads their own location', async () => {
  await seedRide();
  await assertSucceeds(db(BOB).ref(`group_rides/${RIDE}/locations/${BOB}`).set(location(1)));
  await assertSucceeds(db(BOB).ref(`group_rides/${RIDE}/locations`).get());
});

test('group_rides: location writes are refused before meta exists', async () => {
  await assertFails(db(BOB).ref(`group_rides/${RIDE}/locations/${BOB}`).set(location(0)));
});

test('group_rides: writing someone else\'s location is refused', async () => {
  await seedRide();
  await assertFails(db(MALLORY).ref(`group_rides/${RIDE}/locations/${BOB}`).set(location(9)));
  await assertFails(db(BOB).ref(`group_rides/${RIDE}/locations/${ALICE}`).set(location(9)));
});

test('group_rides: signed-out readers are refused', async () => {
  await seedRide();
  await assertFails(db(null).ref(`group_rides/${RIDE}/locations`).get());
});

test('group_rides: client ts and extra keys are refused', async () => {
  await seedRide();
  await assertFails(
    db(BOB).ref(`group_rides/${RIDE}/locations/${BOB}`).set(location(1, { ts: Date.now() }))
  );
  await assertFails(
    db(BOB).ref(`group_rides/${RIDE}/locations/${BOB}`).set(location(1, { name: 'x' }))
  );
  await assertFails(db(BOB).ref(`group_rides/${RIDE}/chat`).set('hi'));
});

test('group_rides: only the creator can ban', async () => {
  await seedRide();
  await assertSucceeds(db(ALICE).ref(`group_rides/${RIDE}/banned/${MALLORY}`).set(true));
  await assertFails(db(BOB).ref(`group_rides/${RIDE}/banned/${ALICE}`).set(true));
  await assertFails(db(MALLORY).ref(`group_rides/${RIDE}/banned/${MALLORY}`).remove());
});

test('group_rides: a banned rider can neither read nor write locations', async () => {
  await seedRide({ banned: BOB });
  await assertFails(db(BOB).ref(`group_rides/${RIDE}/locations`).get());
  await assertFails(db(BOB).ref(`group_rides/${RIDE}/locations/${BOB}`).set(location(2)));
});

test('group_rides: the creator can delete a banned member\'s location', async () => {
  await seedRide({ banned: BOB });
  await assertSucceeds(db(ALICE).ref(`group_rides/${RIDE}/locations/${BOB}`).remove());
});

test('group_rides: the creator cannot write (only delete) someone else\'s location', async () => {
  await seedRide();
  await assertFails(db(ALICE).ref(`group_rides/${RIDE}/locations/${BOB}`).set(location(7)));
});

test('group_rides: the creator removes the whole ride; nobody else can', async () => {
  await seedRide();
  await assertFails(db(BOB).ref(`group_rides/${RIDE}`).remove());
  await assertFails(db(MALLORY).ref(`group_rides/${RIDE}`).remove());
  await assertSucceeds(db(ALICE).ref(`group_rides/${RIDE}`).remove());
});

test('group_rides: listing /group_rides is denied', async () => {
  await seedRide();
  await assertFails(db(ALICE).ref('group_rides').get());
});

// ---------------------------------------------------------------------------
// /chat_presence/{chatId}/{uid}
// ---------------------------------------------------------------------------

test('chat_presence: a participant writes their own typing flag', async () => {
  await assertSucceeds(db(ALICE).ref(`chat_presence/${DM}/${ALICE}`).set({ typing: true, ts: SERVER_TS }));
  await assertSucceeds(db(BOB).ref(`chat_presence/${DM}/${BOB}`).set({ typing: false, ts: SERVER_TS }));
});

test('chat_presence: both participants can read the room', async () => {
  await seed(`chat_presence/${DM}/${ALICE}`, { typing: true, ts: Date.now() });
  await assertSucceeds(db(ALICE).ref(`chat_presence/${DM}`).get());
  await assertSucceeds(db(BOB).ref(`chat_presence/${DM}`).get());
});

test('chat_presence: writing as the other participant is refused', async () => {
  await assertFails(db(ALICE).ref(`chat_presence/${DM}/${BOB}`).set({ typing: true, ts: SERVER_TS }));
});

test('chat_presence: an outsider can neither read nor write', async () => {
  await seed(`chat_presence/${DM}/${ALICE}`, { typing: true, ts: Date.now() });
  await assertFails(db(MALLORY).ref(`chat_presence/${DM}`).get());
  await assertFails(db(MALLORY).ref(`chat_presence/${DM}/${MALLORY}`).set({ typing: true, ts: SERVER_TS }));
  await assertFails(db(null).ref(`chat_presence/${DM}`).get());
});

test('chat_presence: a uid that is only a substring of the id is not a participant', async () => {
  // 'alice' is a prefix of 'alice-uid' but not followed by '_'.
  await assertFails(db('alice').ref(`chat_presence/${DM}`).get());
  await assertFails(db('uid').ref(`chat_presence/${DM}`).get());
});

test('chat_presence: client ts and extra keys are refused', async () => {
  await assertFails(db(ALICE).ref(`chat_presence/${DM}/${ALICE}`).set({ typing: true, ts: Date.now() }));
  await assertFails(
    db(ALICE).ref(`chat_presence/${DM}/${ALICE}`).set({ typing: true, ts: SERVER_TS, text: 'draft' })
  );
  await assertFails(db(ALICE).ref(`chat_presence/${DM}/${ALICE}`).set({ typing: 'yes', ts: SERVER_TS }));
});
