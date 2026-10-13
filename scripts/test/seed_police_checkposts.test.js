'use strict';

/**
 * Unit tests for seed_police_checkposts.js — checks police checkposts dataset,
 * coordinates bounding, schema mapping, and metadata consistency.
 *
 * Run with:  npm test
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  geohashEncode,
  toPlaceDocument,
  POLICE_CHECKPOSTS,
  EXPECTED_PROJECT_ID,
  COLLECTION,
  SEED_AUTHOR,
} = require('../seed_police_checkposts.js');

test('seed_police_checkposts has 30 major checkposts in Dhaka', () => {
  assert.equal(POLICE_CHECKPOSTS.length, 30);
});

test('every police checkpost entry has valid coordinates inside Dhaka metro region', () => {
  for (const post of POLICE_CHECKPOSTS) {
    assert.ok(typeof post.name === 'string' && post.name.startsWith('DMP Traffic Checkpost - '));
    assert.ok(typeof post.slug === 'string' && post.slug.length > 0);
    assert.ok(typeof post.address === 'string' && post.address.length > 0);
    // Dhaka bounding box: lat 23.65 - 23.95, lng 90.30 - 90.55
    assert.ok(post.latitude >= 23.65 && post.latitude <= 23.95, `Latitude out of bounds: ${post.name} (${post.latitude})`);
    assert.ok(post.longitude >= 90.30 && post.longitude <= 90.55, `Longitude out of bounds: ${post.name} (${post.longitude})`);
  }
});

test('key enforcement hotspots in Dhaka are present in POLICE_CHECKPOSTS', () => {
  const slugs = new Set(POLICE_CHECKPOSTS.map((p) => p.slug));
  const hotspots = [
    'polashi-azimpur',
    'farmgate-khamarbari',
    'agargaon-passport-office',
    'kuril-300-feet-entry',
    'airport-kawla-footbridge',
    'science-lab-city-college',
    'mirpur-10-stadium',
    'ecb-chottor-matikata',
  ];

  for (const key of hotspots) {
    assert.ok(slugs.has(key), `Missing hotspot checkpost: ${key}`);
  }
});

test('toPlaceDocument produces valid Firestore place structure with police category', () => {
  const fakeTimestamp = { seconds: 1234567890, nanoseconds: 0 };
  const sample = POLICE_CHECKPOSTS[0];
  const doc = toPlaceDocument(sample, fakeTimestamp);

  assert.equal(doc.category, 'police');
  assert.equal(doc.verified, true);
  assert.equal(doc.createdBy, SEED_AUTHOR);
  assert.equal(doc.createdAt, fakeTimestamp);
  assert.equal(doc.ratingSum, 0);
  assert.equal(doc.ratingCount, 0);
  assert.equal(doc.osmId, `dmp:checkpost:${sample.slug}`);
  assert.equal(doc.geohash, geohashEncode(sample.latitude, sample.longitude, 9));
  assert.ok(doc.commonChecks.length >= 5);
});
