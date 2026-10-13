'use strict';

/**
 * Unit tests for the pure badge-stats helpers. Runs against the compiled
 * output: `npm test` builds first. No emulator or credentials needed.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  MILESTONE_BADGE_IDS,
  isCountedBadgeId,
  tallyBadgeOwners,
} = require('../lib/badge-catalog');

test('catalog ids are unique', () => {
  assert.equal(new Set(MILESTONE_BADGE_IDS).size, MILESTONE_BADGE_IDS.length);
});

test('isCountedBadgeId accepts catalog ids only', () => {
  assert.equal(isCountedBadgeId('first_ride'), true);
  assert.equal(isCountedBadgeId('smooth_operator'), true);
  // Challenge badges share the collection but are not milestones.
  assert.equal(isCountedBadgeId('monthly_500km'), false);
  assert.equal(isCountedBadgeId(''), false);
  assert.equal(isCountedBadgeId(undefined), false);
  assert.equal(isCountedBadgeId(42), false);
});

test('tallyBadgeOwners counts known ids and zero-fills the rest', () => {
  const owners = tallyBadgeOwners([
    'first_ride',
    'first_ride',
    'km_100',
    'junk_id',
    'weekly_streak',
  ]);
  assert.equal(owners.first_ride, 2);
  assert.equal(owners.km_100, 1);
  assert.equal(owners.km_5000, 0);
  assert.equal('junk_id' in owners, false);
  assert.equal('weekly_streak' in owners, false);
  assert.equal(Object.keys(owners).length, MILESTONE_BADGE_IDS.length);
});
