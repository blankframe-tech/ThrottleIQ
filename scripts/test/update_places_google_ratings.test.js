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

  const hero = calculateGoogleRating('Hero service center(60 feet chapra masque mirpur)', 'garage');
  assert.strictEqual(hero.rating, 4.4);
  assert.strictEqual(hero.reviews, 95);
});

test('unverified or unknown places return 0.0 rating and 0 reviews', () => {
  const unverifiedStation = calculateGoogleRating('Random Unlisted Pump 123', 'fuel', 'node/9999');
  assert.deepStrictEqual(unverifiedStation, { rating: 0.0, reviews: 0 });

  const unverifiedGarage = calculateGoogleRating('Local Alley Workshop', 'garage', 'node/8888');
  assert.deepStrictEqual(unverifiedGarage, { rating: 0.0, reviews: 0 });

  const unverifiedParts = calculateGoogleRating('Obscure Spare Shack', 'parts', 'node/7777');
  assert.deepStrictEqual(unverifiedParts, { rating: 0.0, reviews: 0 });
});

console.log(`\nResults: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
