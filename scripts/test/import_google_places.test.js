'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { parseGooglePlace, planImport, hoursFrom, SEED_AUTHOR, toPlaceDocument } = require('../oneoff/import_google_places');

const row = (over = {}) => ({
  title: 'Hazipara CNG Filling Station',
  categoryName: 'Gas station',
  location: { lat: 23.757, lng: 90.4172 },
  address: 'DIT Rd, Dhaka 1219, Bangladesh',
  phone: '+880 1875-446038',
  placeId: 'ChIJ_a',
  openingHours: Array.from({ length: 7 }, (_, i) => ({ day: `Day${i}`, hours: 'Open 24 hours' })),
  ...over,
});

const place = (id, data) => ({ id, data: { category: 'fuel', latitude: 23.757, longitude: 90.4172, name: 'Fuel', ...data } });

test('parseGooglePlace maps, trims country, and skips off-topic/closed/outside rows', () => {
  const c = parseGooglePlace(row());
  assert.equal(c.category, 'fuel');
  assert.equal(c.address, 'DIT Rd, Dhaka 1219');
  assert.equal(c.hours, '24/7');
  assert.equal(parseGooglePlace(row({ categoryName: 'Bicycle Shop' })), null);
  assert.equal(parseGooglePlace(row({ categoryName: 'Gas shop' })), null, 'LPG sellers are not fuel');
  assert.equal(parseGooglePlace(row({ categoryName: 'Oil change service' })).category, 'fuel', 'a named filling station stays fuel');
  assert.equal(parseGooglePlace(row({ categoryName: 'Mechanic', title: 'Moto Doc' })).category, 'garage');
  assert.equal(parseGooglePlace(row({ temporarilyClosed: true })), null);
  assert.equal(parseGooglePlace(row({ location: { lat: 22.3, lng: 91.8 } })), null);
});

test('hoursFrom collapses identical days and lists mixed ones', () => {
  assert.equal(hoursFrom([]), null);
  const week = (h) => Array.from({ length: 7 }, (_, i) => ({ day: 'Monday', hours: h }));
  assert.equal(hoursFrom(week('9 AM–9 PM')), '9 AM–9 PM daily');
  assert.equal(hoursFrom([{ day: 'Monday', hours: '9 AM–5 PM' }, { day: 'Friday', hours: 'Closed' }]), 'Mon 9 AM–5 PM, Fri Closed');
});

test('planImport resets every Google rating', () => {
  const plan = planImport([], [place('a', { googleRating: 4.3, googleRatingCount: 1420 }), place('b', {})]);
  assert.deepEqual(plan.resetRatings, ['a']);
});

test('a nearby same-category place is enriched, not duplicated; rider names are kept', () => {
  const plan = planImport(
    [row(), row({ placeId: 'ChIJ_b', location: { lat: 23.7571, lng: 90.4172 } })],
    [place('generic', { name: 'Fuel' })],
  );
  assert.equal(plan.updates.length, 1);
  assert.deepEqual(plan.updates[0].patch, {
    googlePlaceId: 'ChIJ_a', phone: '+880 1875-446038', hours: '24/7', name: 'Hazipara CNG Filling Station', address: 'DIT Rd, Dhaka 1219',
  });
  assert.equal(plan.creates.length, 1, 'second business at the same spot is created');

  const named = planImport([row()], [place('rider', { name: 'Padma Pump', phone: '017' })]);
  assert.equal(named.updates[0].patch.name, undefined);
  assert.equal(named.updates[0].patch.phone, undefined);
});

test('far, other-category, or already-imported places are handled correctly', () => {
  const plan = planImport(
    [row({ placeId: 'far', location: { lat: 23.8, lng: 90.4 } }), row({ placeId: 'known' })],
    [place('x', { category: 'garage' }), place('y', { googlePlaceId: 'known', latitude: 23.0, longitude: 90.0 })],
  );
  assert.deepEqual(plan.creates.map((c) => c.googlePlaceId), ['far']);
  assert.equal(plan.updates.length, 0);
});

test('created docs carry no Google rating and the seed sentinel', () => {
  const doc = toPlaceDocument(parseGooglePlace(row()), 'now');
  assert.equal(doc.googleRating, 0);
  assert.equal(doc.createdBy, SEED_AUTHOR);
  assert.equal(doc.geohash.length, 9);
});
