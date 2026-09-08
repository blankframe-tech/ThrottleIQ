'use strict';

/**
 * Unit tests for seed_ai_cameras.js — checks camera dataset completeness,
 * schema mapping, geohashing, and metadata consistency.
 *
 * Run with:  npm test
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  geohashEncode,
  toPlaceDocument,
  AI_CAMERAS,
  EXPECTED_PROJECT_ID,
  COLLECTION,
  SEED_AUTHOR,
} = require('../seed_ai_cameras.js');

test('seed_ai_cameras has at least 30 major camera intersections in Dhaka', () => {
  assert.ok(AI_CAMERAS.length >= 30, `Expected at least 30 cameras, found ${AI_CAMERAS.length}`);
});

test('every camera entry has valid coordinates inside Dhaka metropolitan region', () => {
  for (const cam of AI_CAMERAS) {
    assert.ok(typeof cam.name === 'string' && cam.name.startsWith('AI Camera - '));
    assert.ok(typeof cam.slug === 'string' && cam.slug.length > 0);
    assert.ok(typeof cam.address === 'string' && cam.address.length > 0);
    // Dhaka bounding box: lat 23.65 - 23.92, lng 90.30 - 90.52
    assert.ok(cam.latitude >= 23.65 && cam.latitude <= 23.95, `Latitude out of bounds: ${cam.name} (${cam.latitude})`);
    assert.ok(cam.longitude >= 90.30 && cam.longitude <= 90.55, `Longitude out of bounds: ${cam.name} (${cam.longitude})`);
  }
});

test('key user-requested locations are present in AI_CAMERAS', () => {
  const slugs = new Set(AI_CAMERAS.map((c) => c.slug));
  const required = [
    'hotel-intercontinental',
    'pan-pacific-sonargaon',
    'banglamotor',
    'bijoy-sarani',
    'jahangir-gate',
    'farmgate',
    'karwan-bazar',
    'abdul-gani-road',
    'airport-road',
  ];

  for (const key of required) {
    assert.ok(slugs.has(key), `Missing required location: ${key}`);
  }
});

test('toPlaceDocument produces valid Firestore place structure matching ThrottleIQ schema', () => {
  const fakeTimestamp = { seconds: 1234567890, nanoseconds: 0 };
  const sample = AI_CAMERAS[0];
  const doc = toPlaceDocument(sample, fakeTimestamp);

  assert.equal(doc.category, 'aiCamera');
  assert.equal(doc.verified, true);
  assert.equal(doc.createdBy, SEED_AUTHOR);
  assert.equal(doc.createdAt, fakeTimestamp);
  assert.equal(doc.ratingSum, 0);
  assert.equal(doc.ratingCount, 0);
  assert.equal(doc.osmId, `dmp:ai-camera:${sample.slug}`);
  assert.equal(doc.geohash, geohashEncode(sample.latitude, sample.longitude, 9));
  assert.ok(doc.violationsDetected.length >= 6);
  assert.ok(doc.connectedApps.length >= 2);
});
