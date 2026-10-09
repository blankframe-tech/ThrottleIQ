'use strict';

/**
 * Security-rules tests for `users/{uid}/fuelLogs/{id}` (fuel fill-ups,
 * schema v27). The "succeeds" payload is the shape FuelLogModel
 * .toCloudPayload writes plus the server-set `syncedAt`.
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
  getDoc,
  setDoc,
  deleteDoc,
  serverTimestamp,
  Timestamp,
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
    projectId: 'throttleiq-rules-test-fuel',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function fill(overrides = {}) {
  return {
    id: 'f1',
    bike_id: 'bike-1',
    filled_at: '2026-10-01T09:30:00.000',
    odometer_km: 12500.5,
    liters: 6.25,
    total_cost: 812.5,
    price_per_liter: 130,
    full_tank: true,
    station: 'Meghna Petroleum',
    created_at: '2026-10-01T09:31:00.000',
    updated_at: '2026-10-01T09:31:00.000',
    syncedAt: serverTimestamp(),
    ...overrides,
  };
}

const ref = (db, uid = ALICE, id = 'f1') =>
  doc(db, 'users', uid, 'fuelLogs', id);

test('owner can write, read and delete a well-formed fill-up', async () => {
  const db = dbFor(ALICE);
  await assertSucceeds(setDoc(ref(db), fill()));
  await assertSucceeds(getDoc(ref(db)));
  await assertSucceeds(deleteDoc(ref(db)));
});

test('optional station and note may be absent', async () => {
  const { station, ...rest } = fill();
  await assertSucceeds(setDoc(ref(dbFor(ALICE)), { ...rest, full_tank: false }));
});

test('another rider can neither read nor write', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(ref(ctx.firestore()), { ...fill(), syncedAt: Timestamp.now() });
  });
  const bob = dbFor(BOB);
  await assertFails(getDoc(ref(bob)));
  await assertFails(setDoc(ref(bob), fill()));
  await assertFails(deleteDoc(ref(bob)));
});

test('signed-out access is denied', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(setDoc(ref(db), fill()));
  await assertFails(getDoc(ref(db)));
});

test('field validation rejects bad payloads', async () => {
  const db = dbFor(ALICE);
  const bad = {
    'id mismatch': fill({ id: 'other' }),
    'zero litres': fill({ liters: 0 }),
    'negative cost': fill({ total_cost: -1 }),
    'negative price': fill({ price_per_liter: -5 }),
    'odometer too high': fill({ odometer_km: 3000000 }),
    'full_tank as int': fill({ full_tank: 1 }),
    'string litres': fill({ liters: '6' }),
    'unknown key': fill({ synced: 0 }),
    'client syncedAt': fill({ syncedAt: Timestamp.fromMillis(0) }),
    'station too long': fill({ station: 'x'.repeat(201) }),
  };
  for (const [name, payload] of Object.entries(bad)) {
    await assertFails(setDoc(ref(db), payload), name);
  }
  const { bike_id, ...noBike } = fill();
  await assertFails(setDoc(ref(db), noBike));
});
