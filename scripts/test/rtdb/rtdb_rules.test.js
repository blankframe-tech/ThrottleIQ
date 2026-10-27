'use strict';

/**
 * Security-rules tests for database.rules.json (Realtime Database).
 *
 * B9 (critique 2026-10-14): RTDB is retired. Group-ride positions were
 * readable by any signed-in rider who knew the ride id, and the client is
 * being removed from `main`, so the rules now deny every read and write.
 * Each test below is a write or read the app (or the public live viewer)
 * used to make, and all of them must now be refused. The live viewer treats
 * a rules rejection as "no RTDB fix" and stays on Firestore.
 *
 * The old per-path rules and their delivery suite are in git history
 * (before 2026-10-14) if RTDB ever comes back behind a membership mirror.
 *
 * Run with:  npm run test:rtdb   (from scripts/)
 */

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
  assertFails,
} = require('@firebase/rules-unit-testing');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'database.rules.json'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const TOKEN = 'a'.repeat(32);
const RIDE = 'ride-1';
const DM = `${ALICE}_${BOB}`;
const SERVER_TS = { '.sv': 'timestamp' };
const location = (seq = 0) => ({ lat: 23.81, lng: 90.41, ts: SERVER_TS, seq });

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-rtdb-rules',
    database: { rules: RULES, host: '127.0.0.1', port: 9000 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearDatabase();
  // Leftover data from before the shutdown must not be readable either.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.database().ref().set({
      live_shares: { [TOKEN]: { uid: ALICE, expiresAt: Date.now() + 60_000 } },
      group_rides: { [RIDE]: { meta: { creatorId: ALICE }, locations: { [ALICE]: { lat: 1, lng: 1, ts: 1, seq: 0 } } } },
      chat_presence: { [DM]: { [ALICE]: { typing: true, ts: 1 } } },
    });
  });
});

const db = (uid) =>
  uid ? testEnv.authenticatedContext(uid).database() : testEnv.unauthenticatedContext().database();

test('the root is closed to reads and writes', async () => {
  await assertFails(db(ALICE).ref().get());
  await assertFails(db(ALICE).ref('anything').set(true));
});

test('live_shares: the owner can no longer write or remove a share', async () => {
  await assertFails(db(ALICE).ref(`live_shares/${'b'.repeat(32)}`).set({
    uid: ALICE, expiresAt: Date.now() + 60_000, location: location(0),
  }));
  await assertFails(db(ALICE).ref(`live_shares/${TOKEN}/location`).set(location(1)));
  await assertFails(db(ALICE).ref(`live_shares/${TOKEN}`).remove());
});

test('live_shares: the signed-out viewer can no longer read a live share', async () => {
  await assertFails(db(null).ref(`live_shares/${TOKEN}`).get());
  await assertFails(db(BOB).ref(`live_shares/${TOKEN}`).get());
});

test('group_rides: no meta, location or ban writes', async () => {
  await assertFails(db(BOB).ref('group_rides/ride-2/meta').set({ creatorId: BOB }));
  await assertFails(db(ALICE).ref(`group_rides/${RIDE}/locations/${ALICE}`).set(location(1)));
  await assertFails(db(ALICE).ref(`group_rides/${RIDE}/banned/${BOB}`).set(true));
  await assertFails(db(ALICE).ref(`group_rides/${RIDE}`).remove());
});

test('group_rides: positions are unreadable, even to the creator (B9)', async () => {
  await assertFails(db(BOB).ref(`group_rides/${RIDE}/locations`).get());
  await assertFails(db(ALICE).ref(`group_rides/${RIDE}/locations`).get());
  await assertFails(db(BOB).ref(`group_rides/${RIDE}/meta`).get());
});

test('chat_presence: participants can neither write nor read typing flags', async () => {
  await assertFails(db(BOB).ref(`chat_presence/${DM}/${BOB}`).set({ typing: true, ts: SERVER_TS }));
  await assertFails(db(BOB).ref(`chat_presence/${DM}`).get());
});
