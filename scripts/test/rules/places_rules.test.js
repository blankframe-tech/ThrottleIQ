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

const { doc, setDoc, Timestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-places',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
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
