'use strict';

/**
 * places/{placeId} create rule — the Places hub's rider tags (`tags`).
 *
 * Pairs the exact shapes the app writes (PlaceModel.toFirestore: no `tags`
 * key for an untagged place, a short list of PlaceTag names otherwise) with
 * the payloads the rule refuses. Own projectId so `node --test` can run this
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

const { doc, setDoc, serverTimestamp, Timestamp } = require('firebase/firestore');

const inHours = (h) => Timestamp.fromMillis(Date.now() + h * 3600 * 1000);

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-places',
    firestore: { rules: RULES }, // host: FIRESTORE_EMULATOR_HOST (emulators:exec)
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

function place(overrides) {
  return {
    name: 'Central Moto Works',
    category: 'garage',
    latitude: 23.8,
    longitude: 90.36,
    geohash: 'wh0r1234',
    address: '',
    phone: null,
    hours: null,
    photoUrls: [],
    verified: false,
    createdBy: ALICE,
    createdAt: Timestamp.now(),
    ratingSum: 0,
    ratingCount: 0,
    googleRating: 0,
    googleRatingCount: 0,
    osmId: null,
    ...overrides,
  };
}

function aliceDb() {
  return testEnv.authenticatedContext(ALICE).firestore();
}

test('an untagged place (every pre-hub write, every OSM import) is still allowed', async () => {
  await assertSucceeds(setDoc(doc(aliceDb(), 'places', 'p1'), place({})));
});

test('a place with a few rider tags is allowed', async () => {
  await assertSucceeds(
    setDoc(doc(aliceDb(), 'places', 'p2'), place({ tags: ['efiDiagnostics', 'punctureRepair'] }))
  );
});

test('tags must be a list', async () => {
  await assertFails(setDoc(doc(aliceDb(), 'places', 'p3'), place({ tags: 'open24h' })));
});

test('no more than 12 tags', async () => {
  const tags = Array.from({ length: 13 }, (_, i) => `t${i}`);
  await assertFails(setDoc(doc(aliceDb(), 'places', 'p4'), place({ tags })));
});

test('no duplicate tags', async () => {
  await assertFails(
    setDoc(doc(aliceDb(), 'places', 'p5'), place({ tags: ['open24h', 'open24h'] }))
  );
});

test('the existing create constraints still hold alongside tags', async () => {
  await assertFails(
    setDoc(doc(aliceDb(), 'places', 'p6'), place({ tags: ['open24h'], verified: true }))
  );
});

test('create with expiresAt timestamp on police is allowed', async () => {
  await assertSucceeds(
    setDoc(
      doc(aliceDb(), 'places', 'p7'),
      place({ category: 'police', expiresAt: inHours(24) })
    )
  );
});

test('create with expiresAt on non-police category is denied', async () => {
  await assertFails(
    setDoc(
      doc(aliceDb(), 'places', 'p8'),
      place({ category: 'fuel', expiresAt: inHours(24) })
    )
  );
});

test('create with non-timestamp expiresAt on police is denied', async () => {
  await assertFails(
    setDoc(
      doc(aliceDb(), 'places', 'p9'),
      place({ category: 'police', expiresAt: '2026-10-18T00:00:00Z' })
    )
  );
});

test('create with expiresAt in the past is denied', async () => {
  await assertFails(
    setDoc(
      doc(aliceDb(), 'places', 'p10'),
      place({ category: 'police', expiresAt: inHours(-1) })
    )
  );
});

test('create with expiresAt more than two days out is denied', async () => {
  await assertFails(
    setDoc(
      doc(aliceDb(), 'places', 'p11'),
      place({ category: 'police', expiresAt: inHours(24 * 365) })
    )
  );
});

test('updatedAt as the server timestamp (what the app writes) is allowed', async () => {
  await assertSucceeds(
    setDoc(doc(aliceDb(), 'places', 'p12'), place({ updatedAt: serverTimestamp() }))
  );
});

test('a backdated updatedAt, which would dodge the ride cache delta pull, is denied', async () => {
  await assertFails(
    setDoc(doc(aliceDb(), 'places', 'p13'), place({ updatedAt: inHours(-1) }))
  );
});
