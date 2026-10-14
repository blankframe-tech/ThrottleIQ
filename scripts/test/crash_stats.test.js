'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { decodeGeohash, districtOf, summarize, speedBand, toCsv } = require('../crash_stats');
const { toRecord, toCsvRow, FIELDS } = require('../export_impact_events');

test('decodeGeohash finds the centre of a cell', () => {
  // A cell in central Dhaka.
  const c = decodeGeohash('wh0r3n');
  assert.ok(Math.abs(c.lat - 23.81) < 0.02, `lat ${c.lat}`);
  assert.ok(Math.abs(c.lng - 90.40) < 0.02, `lng ${c.lng}`);
  assert.equal(decodeGeohash('not a hash!'), null);
  assert.equal(decodeGeohash(''), null);
});

test('districtOf maps a point to the polygon that holds it', () => {
  const square = (name, lng0, lat0) => ({
    properties: { ADM2_EN: name },
    geometry: {
      type: 'Polygon',
      coordinates: [[[lng0, lat0], [lng0 + 1, lat0], [lng0 + 1, lat0 + 1], [lng0, lat0 + 1], [lng0, lat0]]],
    },
  });
  const features = [square('Dhaka', 90, 23.5), square('Gazipur', 90, 24.5)];
  assert.equal(districtOf(23.81, 90.4, features), 'Dhaka');
  assert.equal(districtOf(24.9, 90.4, features), 'Gazipur');
  assert.equal(districtOf(22.0, 91.8, features), null);
});

test('summarize counts only confirmed falls as crashes, and computes recall', () => {
  const events = [
    { label: 'crash', detectedTier: 1, placement: 'pocket', surface: 'rail_crossing', geohash6: 'wh0r4p', speedBeforeKmh: 12.7, rulesVersion: 1 },
    { label: 'fall', detectedTier: 2, placement: 'mount', geohash6: 'wh0r4p', speedBeforeKmh: 30, rulesVersion: 1 },
    { label: 'missed', placement: 'pocket', geohash6: 'wh2b1c', rulesVersion: 1 },
    { label: 'bump', detectedTier: 1, placement: 'mount', rulesVersion: 1 },
    { label: 'unsure', detectedTier: 1, rulesVersion: 1 },
  ];
  const s = summarize(events);
  assert.equal(s.detectedCrashes, 2);
  assert.equal(s.missedFalls, 1);
  assert.equal(s.recall, 66.7);
  assert.equal(s.falseQuestions, 1);
  assert.equal(s.unsure, 1);
  assert.equal(s.areas, 2);
  assert.deepEqual(s.fallsByPlacement, { pocket: 2, mount: 1 });
  assert.equal(s.fallsBySpeed['10-25 km/h'], 1);
});

test('summarize with no answers has no recall rather than 0%', () => {
  assert.equal(summarize([]).recall, null);
});

test('speedBand and CSV escaping', () => {
  assert.equal(speedBand(5), '<10 km/h');
  assert.equal(speedBand(undefined), 'unknown');
  const csv = toCsv([{ id: 'a', label: 'crash', surface: 'x, "y"' }]);
  assert.match(csv, /"x, ""y"""/);
});

test('exported impacts carry a salted rider hash, never the uid', () => {
  const rec = toRecord('ev-1', 'secret-uid', { tier: 1, labelDetail: { surface: 'wet' }, imu: {} }, 'salt');
  assert.notEqual(rec.rider, 'secret-uid');
  assert.equal(rec.rider.length, 12);
  assert.equal(rec.surface, 'wet');
  assert.equal(rec.hasWindow, 1);
  const row = toCsvRow(rec);
  assert.ok(!row.includes('secret-uid'));
  assert.equal(row.split(',').length, FIELDS.length);
});
