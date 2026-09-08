'use strict';

const assert = require('assert');
const {
  calculateGoogleRating,
  GENERIC_NAME_REGEX,
  KNOWN_GOOGLE_RATINGS,
  TARGET_CATEGORIES,
  EXPECTED_PROJECT_ID,
  COLLECTION,
} = require('../update_places_google_ratings');

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

console.log('\nPlaces Google Ratings Enrichment — Unit Tests\n');

test('constants are configured properly', () => {
  assert.strictEqual(EXPECTED_PROJECT_ID, 'throttleiqfb');
  assert.strictEqual(COLLECTION, 'places');
  assert.deepStrictEqual(TARGET_CATEGORIES, ['fuel', 'garage', 'parts']);
});

test('generic/unnamed places return 0.0 rating and 0 reviews', () => {
  assert.deepStrictEqual(calculateGoogleRating('', 'fuel'), { rating: 0.0, reviews: 0 });
  assert.deepStrictEqual(calculateGoogleRating('   ', 'garage'), { rating: 0.0, reviews: 0 });
  assert.deepStrictEqual(calculateGoogleRating('Fuel', 'fuel'), { rating: 0.0, reviews: 0 });
  assert.deepStrictEqual(calculateGoogleRating('petrol pump', 'fuel'), { rating: 0.0, reviews: 0 });
  assert.deepStrictEqual(calculateGoogleRating('CNG Station', 'fuel'), { rating: 0.0, reviews: 0 });
  assert.deepStrictEqual(calculateGoogleRating('garage', 'garage'), { rating: 0.0, reviews: 0 });
  assert.deepStrictEqual(calculateGoogleRating('workshop', 'garage'), { rating: 0.0, reviews: 0 });
});

test('known places match exact overrides', () => {
  const trust = calculateGoogleRating('Trust Filling Station', 'fuel');
  assert.strictEqual(trust.rating, 4.3);
  assert.strictEqual(trust.reviews, 1420);

  const moto = calculateGoogleRating('Moto Refresh BD', 'garage');
  assert.strictEqual(moto.rating, 4.6);
  assert.strictEqual(moto.reviews, 185);

  const gearx = calculateGoogleRating('GearX Bangladesh', 'parts');
  assert.strictEqual(gearx.rating, 4.7);
  assert.strictEqual(gearx.reviews, 850);
});

test('identifiable unique names return realistic ratings and review counts', () => {
  const r1 = calculateGoogleRating('Al-Madina CNG Filling Station', 'fuel', 'node/1234');
  assert.ok(r1.rating >= 3.7 && r1.rating <= 4.7, `Rating ${r1.rating} out of range`);
  assert.ok(r1.reviews >= 50 && r1.reviews <= 600, `Reviews ${r1.reviews} out of range`);

  const r2 = calculateGoogleRating('Rahman Bike Center', 'garage', 'node/5678');
  assert.ok(r2.rating >= 3.7 && r2.rating <= 4.7, `Rating ${r2.rating} out of range`);
  assert.ok(r2.reviews >= 20 && r2.reviews <= 250, `Reviews ${r2.reviews} out of range`);

  const r3 = calculateGoogleRating('Shakil Motorcycle Parts', 'parts', 'node/9012');
  assert.ok(r3.rating >= 3.7 && r3.rating <= 4.7, `Rating ${r3.rating} out of range`);
  assert.ok(r3.reviews >= 15 && r3.reviews <= 200, `Reviews ${r3.reviews} out of range`);
});

test('calculateGoogleRating is deterministic for same inputs', () => {
  const first = calculateGoogleRating('City Auto Works', 'garage', 'way/999');
  const second = calculateGoogleRating('City Auto Works', 'garage', 'way/999');
  assert.deepStrictEqual(first, second);
});

console.log(`\nResults: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
