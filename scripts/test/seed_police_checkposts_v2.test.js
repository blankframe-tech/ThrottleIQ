'use strict';

const assert = require('assert');
const {
  geohashEncode,
  toPlaceDocument,
  POLICE_CHECKPOSTS_V2,
  EXPECTED_PROJECT_ID,
  COLLECTION,
  SEED_AUTHOR,
} = require('../seed_police_checkposts_v2');

let passed = 0;
let failed = 0;

function test(label, fn) {
  try {
    fn();
    console.log(`  ✓ ${label}`);
    passed++;
  } catch (e) {
    console.error(`  ✗ ${label}`);
    console.error(`    ${e.message}`);
    failed++;
  }
}

console.log('\nPolice Checkposts v2 Seed — Unit Tests\n');

test('POLICE_CHECKPOSTS_V2 has 25 entries', () => {
  assert.strictEqual(POLICE_CHECKPOSTS_V2.length, 25);
});

test('all slugs are unique', () => {
  const slugs = POLICE_CHECKPOSTS_V2.map((p) => p.slug);
  const unique = new Set(slugs);
  assert.strictEqual(unique.size, slugs.length, 'Duplicate slugs detected');
});

test('all names are unique', () => {
  const names = POLICE_CHECKPOSTS_V2.map((p) => p.name);
  const unique = new Set(names);
  assert.strictEqual(unique.size, names.length, 'Duplicate names detected');
});

test('all locations have valid Dhaka-area coordinates', () => {
  for (const post of POLICE_CHECKPOSTS_V2) {
    assert.ok(post.latitude >= 23.60 && post.latitude <= 23.95,
      `${post.slug}: latitude ${post.latitude} out of Dhaka range`);
    assert.ok(post.longitude >= 90.30 && post.longitude <= 90.55,
      `${post.slug}: longitude ${post.longitude} out of Dhaka range`);
  }
});

test('toPlaceDocument produces correct category and schema', () => {
  const fakeTs = { toDate: () => new Date() };
  const doc = toPlaceDocument(POLICE_CHECKPOSTS_V2[0], fakeTs);
  assert.strictEqual(doc.category, 'police');
  assert.strictEqual(doc.createdBy, SEED_AUTHOR);
  assert.strictEqual(doc.verified, true);
  assert.ok(doc.osmId.startsWith('dmp:checkpost:'));
  assert.ok(typeof doc.geohash === 'string' && doc.geohash.length === 9);
  assert.strictEqual(doc.ratingSum, 0);
  assert.strictEqual(doc.ratingCount, 0);
});

test('geohashEncode produces 9-char precision-9 hashes', () => {
  const h1 = geohashEncode(23.8955, 90.3985); // Abdullahpur
  const h2 = geohashEncode(23.7005, 90.4440); // Matuail
  assert.strictEqual(h1.length, 9);
  assert.strictEqual(h2.length, 9);
  assert.notStrictEqual(h1, h2);
});

test('constants are correct', () => {
  assert.strictEqual(EXPECTED_PROJECT_ID, 'throttleiqfb');
  assert.strictEqual(COLLECTION, 'places');
  assert.strictEqual(SEED_AUTHOR, 'system:dmp-checkpost-seed-v2');
});

console.log(`\nResults: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
