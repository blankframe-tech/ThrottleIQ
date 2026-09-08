'use strict';

const assert = require('assert');
const {
  geohashEncode,
  toPlaceDocument,
  POLICE_CHECKPOSTS_V3,
  EXPECTED_PROJECT_ID,
  COLLECTION,
  SEED_AUTHOR,
} = require('../seed_police_checkposts_v3');

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

console.log('\nPolice Checkposts v3 Seed — Unit Tests\n');

test('POLICE_CHECKPOSTS_V3 has 35 entries', () => {
  assert.strictEqual(POLICE_CHECKPOSTS_V3.length, 35);
});

test('all slugs are unique in v3', () => {
  const slugs = POLICE_CHECKPOSTS_V3.map((p) => p.slug);
  const unique = new Set(slugs);
  assert.strictEqual(unique.size, slugs.length, 'Duplicate slugs detected in v3');
});

test('all names are unique in v3', () => {
  const names = POLICE_CHECKPOSTS_V3.map((p) => p.name);
  const unique = new Set(names);
  assert.strictEqual(unique.size, names.length, 'Duplicate names detected in v3');
});

test('all locations have valid Dhaka/perimeter coordinates', () => {
  for (const post of POLICE_CHECKPOSTS_V3) {
    assert.ok(post.latitude >= 23.60 && post.latitude <= 23.95,
      `${post.slug}: latitude ${post.latitude} out of Dhaka range`);
    assert.ok(post.longitude >= 90.30 && post.longitude <= 90.55,
      `${post.slug}: longitude ${post.longitude} out of Dhaka range`);
  }
});

test('toPlaceDocument produces correct category and schema', () => {
  const fakeTs = { toDate: () => new Date() };
  const doc = toPlaceDocument(POLICE_CHECKPOSTS_V3[0], fakeTs);
  assert.strictEqual(doc.category, 'police');
  assert.strictEqual(doc.createdBy, SEED_AUTHOR);
  assert.strictEqual(doc.verified, true);
  assert.ok(doc.osmId.startsWith('dmp:checkpost:'));
  assert.ok(typeof doc.geohash === 'string' && doc.geohash.length === 9);
  assert.strictEqual(doc.ratingSum, 0);
  assert.strictEqual(doc.ratingCount, 0);
  assert.ok(Array.isArray(doc.commonChecks));
  assert.ok(doc.commonChecks.length > 0);
});

test('geohashEncode produces valid precision-9 hashes for all 35 entries', () => {
  for (const post of POLICE_CHECKPOSTS_V3) {
    const hash = geohashEncode(post.latitude, post.longitude, 9);
    assert.strictEqual(hash.length, 9, `Hash length for ${post.slug} must be 9`);
  }
});

test('constants are correct', () => {
  assert.strictEqual(EXPECTED_PROJECT_ID, 'throttleiqfb');
  assert.strictEqual(COLLECTION, 'places');
  assert.strictEqual(SEED_AUTHOR, 'system:dmp-checkpost-seed-v3');
});

console.log(`\nResults: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
