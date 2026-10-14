'use strict';

/**
 * Shadow-mode crash detection: users/{uid}/impactEvents/{id} (the rider's
 * own impacts) and crashEvents/{id} (the opt-in, de-identified research
 * copy). Pairs the shapes impact_event_payload.dart writes with the
 * payloads the rules refuse. Own projectId so `node --test` can run this
 * file in parallel with the others.
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
  doc,
  setDoc,
  getDoc,
  deleteDoc,
  serverTimestamp,
  Bytes,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-crash-events',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

function impact(overrides) {
  return {
    schema: 1,
    rideId: 'ride-1',
    at: '2026-10-14T15:28:58.900Z',
    tier: 1,
    reason: 'tipOver',
    peakUserG: 2.7,
    peakRawG: 3.1,
    freefallMs: 180,
    stillAfter: true,
    resumedAfter: false,
    speedBeforeMs: 0,
    gpsGapS: 11.9,
    lat: 23.7808,
    lng: 90.4071,
    placement: 'pocket',
    features: { peakUserMs2: 26.5, rotationDeg: 140.2, rulesVersion: 1 },
    imu: Bytes.fromUint8Array(new Uint8Array([1, 2, 3])),
    consent: false,
    createdAt: '2026-10-14T15:29:24.000Z',
    syncedAt: serverTimestamp(),
    ...overrides,
  };
}

function crashEvent(overrides) {
  return {
    ownerUid: ALICE,
    createdAt: '2026-10-14T15:29:24.000Z',
    platform: 'ios',
    label: 'crash',
    detectedTier: 1,
    reason: 'tipOver',
    peakG: 3.1,
    speedBeforeKmh: 12.7,
    placement: 'pocket',
    bikeCc: 125,
    bikeClass: 'commuter',
    surface: 'rail_crossing',
    severity: 'minor',
    geohash6: 'wh0r4p',
    hourLocal: 21,
    weekday: 3,
    rulesVersion: 1,
    consentVersion: 1,
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

// One Firestore instance per context: calling ctx.firestore() twice throws.
const dbs = new WeakMap();
const db = (ctx) => {
  if (!dbs.has(ctx)) dbs.set(ctx, ctx.firestore());
  return dbs.get(ctx);
};
const mine = (ctx, id = 'ev-1') =>
  doc(db(ctx), `users/${ALICE}/impactEvents/${id}`);
const central = (ctx, id = 'ev-1') => doc(db(ctx), `crashEvents/${id}`);

test('a rider writes, reads and deletes their own impact', async () => {
  const alice = testEnv.authenticatedContext(ALICE);
  await assertSucceeds(setDoc(mine(alice), impact()));
  await assertSucceeds(getDoc(mine(alice)));
  await assertSucceeds(
    setDoc(mine(alice), impact({ label: 'crash', labelSource: 'rider',
      labeledAt: '2026-10-14T16:10:00.000Z', labelDetail: { severity: 'minor' } }))
  );
  await assertSucceeds(deleteDoc(mine(alice)));
});

test('a reported miss (tier -1, no sensor data) is accepted', async () => {
  const alice = testEnv.authenticatedContext(ALICE);
  await assertSucceeds(
    setDoc(mine(alice), {
      schema: 1,
      rideId: 'ride-1',
      at: '2026-10-14T15:28:50.000Z',
      tier: -1,
      reason: 'riderReport',
      placement: 'pocket',
      label: 'missed',
      labelSource: 'rider',
      labeledAt: '2026-10-14T16:10:00.000Z',
      consent: true,
      createdAt: '2026-10-14T16:10:00.000Z',
      syncedAt: serverTimestamp(),
    })
  );
});

test("nobody else can read or write a rider's impacts", async () => {
  const alice = testEnv.authenticatedContext(ALICE);
  await assertSucceeds(setDoc(mine(alice), impact()));
  const bob = testEnv.authenticatedContext(BOB);
  await assertFails(getDoc(mine(bob)));
  await assertFails(setDoc(mine(bob, 'ev-2'), impact()));
  await assertFails(getDoc(mine(testEnv.unauthenticatedContext())));
});

test('impact payloads outside the shape are refused', async () => {
  const alice = testEnv.authenticatedContext(ALICE);
  await assertFails(setDoc(mine(alice), impact({ tier: 3 })));
  await assertFails(setDoc(mine(alice), impact({ label: 'totally fine' })));
  await assertFails(setDoc(mine(alice), impact({ extra: 'field' })));
  await assertFails(setDoc(mine(alice), impact({ schema: 2 })));
  await assertFails(
    setDoc(mine(alice), impact({ imu: Bytes.fromUint8Array(new Uint8Array(70000)) }))
  );
  await assertFails(setDoc(mine(alice), impact({ syncedAt: 'yesterday' })));
});

test('an opted-in rider creates and updates their research copy', async () => {
  const alice = testEnv.authenticatedContext(ALICE);
  await assertSucceeds(setDoc(central(alice), crashEvent()));
  await assertSucceeds(
    setDoc(central(alice), crashEvent({ label: 'fall', severity: 'none' }))
  );
});

test('research copies are never readable by clients', async () => {
  const alice = testEnv.authenticatedContext(ALICE);
  await assertSucceeds(setDoc(central(alice), crashEvent()));
  await assertFails(getDoc(central(alice)));
  await assertFails(getDoc(central(testEnv.authenticatedContext(BOB))));
});

test("a research copy can't be written under someone else's uid", async () => {
  const bob = testEnv.authenticatedContext(BOB);
  await assertFails(setDoc(central(bob), crashEvent()));
  const alice = testEnv.authenticatedContext(ALICE);
  await assertSucceeds(setDoc(central(alice), crashEvent()));
  await assertFails(setDoc(central(bob), crashEvent({ ownerUid: BOB })));
  await assertFails(deleteDoc(central(bob)));
});

test('research copies refuse precise location, free text and unknown labels', async () => {
  const alice = testEnv.authenticatedContext(ALICE);
  await assertFails(setDoc(central(alice), crashEvent({ lat: 23.81 })));
  await assertFails(setDoc(central(alice), crashEvent({ geohash6: 'wh0r4p9k' })));
  await assertFails(setDoc(central(alice), crashEvent({ note: 'fell at the rails' })));
  await assertFails(setDoc(central(alice), crashEvent({ label: 'whatever' })));
  await assertFails(setDoc(central(alice), crashEvent({ surface: 'ice' })));
  const { consentVersion, ...noConsent } = crashEvent();
  void consentVersion;
  await assertFails(setDoc(central(alice), noConsent));
});

test('the owner can delete their copy, even one that never existed', async () => {
  const alice = testEnv.authenticatedContext(ALICE);
  await assertSucceeds(deleteDoc(central(alice, 'never-written')));
  await assertSucceeds(setDoc(central(alice), crashEvent()));
  await assertSucceeds(deleteDoc(central(alice)));
  await assertFails(deleteDoc(central(testEnv.unauthenticatedContext(), 'x')));
});
