'use strict';

/**
 * Pure partner-API logic (src/partner-api/scoring.ts): validation, time
 * bands, baselines and the ride score. No emulator needed.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const s = require('../lib/partner-api/scoring');

const NOW = new Date('2026-10-17T12:00:00Z');
// gulshan-ish precision-7 geohash cells (Dhaka starts with "wh0")
const SEG_A = 'wh0r3qs';
const SEG_B = 'wh0r3qt';

function ride(over = {}) {
  return {
    rideId: 'ride_1',
    riderRef: 'mayabi-42',
    startedAt: '2026-10-17T02:30:00Z', // 08:30 Dhaka: morning peak
    endedAt: '2026-10-17T03:00:00Z',
    distanceKm: 17,
    pickupKm: 3,
    tripKm: 8,
    returnKm: 6,
    movingSeconds: 1500,
    avgSpeedKmh: 22,
    maxSpeedKmh: 48,
    hardBrakes: 1,
    rapidAccels: 0,
    highJerks: 2,
    overspeeds: 0,
    weatherCode: null,
    segments: [
      { segmentId: SEG_A, avgSpeedKmh: 25, pointCount: 12 },
      { segmentId: SEG_B, avgSpeedKmh: 70, pointCount: 6 },
    ],
    impacts: [],
    ...over,
  };
}

test('Bangladesh time: hour, ISO weekday and Dhaka traffic bands', () => {
  const d = new Date('2026-10-17T18:30:00Z'); // Sun 18 Oct, 00:30 in Dhaka
  assert.equal(s.bdHour(d), 0);
  assert.equal(s.bdWeekday(d), 7); // ISO Sunday
  assert.equal(s.bdWeekday(new Date('2026-10-17T06:00:00Z')), 6); // Sat noon
  assert.equal(s.timeBand(5), 'night');
  assert.equal(s.timeBand(8), 'morningPeak');
  assert.equal(s.timeBand(13), 'day');
  assert.equal(s.timeBand(19), 'eveningPeak');
  assert.equal(s.timeBand(23), 'late');
});

test('wet WMO codes', () => {
  for (const c of [51, 61, 65, 80, 95, 99]) assert.equal(s.isWet(c), true, c);
  for (const c of [null, 0, 3, 45, 70]) assert.equal(s.isWet(c), false, c);
});

test('geohash centre lands in Dhaka; non-geohash is null', () => {
  const c = s.geohashCentre(SEG_A);
  assert.ok(Math.abs(c.lat - 23.79) < 0.1 && Math.abs(c.lng - 90.41) < 0.1, JSON.stringify(c));
  assert.equal(s.inBangladesh(c), true);
  assert.equal(s.geohashCentre('wh0a!!!'), null);
  assert.equal(s.inBangladesh(s.geohashCentre('u4pruyd')), false); // Denmark
});

test('parseRideUpload accepts a good ride', () => {
  const r = s.parseRideUpload(ride(), NOW);
  assert.equal(r.segments.length, 2);
  assert.equal(r.startedAt.toISOString(), '2026-10-17T02:30:00.000Z');
});

test('parseRideUpload rejects what would poison the pool', () => {
  const bad = [
    { segments: [{ segmentId: 'u4pruyd', avgSpeedKmh: 30, pointCount: 3 }] }, // abroad
    { segments: [{ segmentId: 'wh0r3', avgSpeedKmh: 30, pointCount: 3 }] }, // wrong precision
    { segments: [{ segmentId: SEG_A, avgSpeedKmh: 400, pointCount: 3 }] }, // impossible speed
    { segments: [{ segmentId: SEG_A, avgSpeedKmh: 30, pointCount: 3 }, { segmentId: SEG_A, avgSpeedKmh: 30, pointCount: 3 }] },
    { endedAt: '2026-10-17T02:00:00Z' }, // ends before it starts
    { endedAt: '2026-10-18T12:00:00Z', startedAt: '2026-10-18T11:00:00Z' }, // future
    { startedAt: '2026-08-01T00:00:00Z', endedAt: '2026-08-01T01:00:00Z' }, // too old
    { riderRef: 'has space' },
    { rideId: '' },
    { hardBrakes: 1.5 },
    { pickupKm: 30 }, // legs exceed distance
    { weatherCode: 120 },
    { impacts: [{ tier: 3, reason: 'impact', peakAccelMs2: 40, speedBeforeKmh: 20 }] },
    { impacts: [{ tier: 2, reason: 'impact', peakAccelMs2: 40, speedBeforeKmh: 20, riderSaysFell: 'yes' }] },
  ];
  for (const over of bad) {
    assert.throws(() => s.parseRideUpload(ride(over), NOW), s.ValidationError, JSON.stringify(over));
  }
  assert.throws(() => s.parseRideUpload(null, NOW), s.ValidationError);
});

test('eventScore matches the app formula and clamps', () => {
  assert.equal(s.eventScore(1, 0, 2), 93);
  assert.equal(s.eventScore(30, 0, 0), 0);
  assert.equal(s.eventScore(0, 0, 0), 100);
});

function statsWith(meanKmh, n, spread = 4) {
  // n samples alternating mean ± spread
  let st;
  for (let i = 0; i < n; i++) st = s.addSample(st, meanKmh + (i % 2 ? spread : -spread), 8, null);
  return st;
}

test('addSample keeps moments per band and wet pool', () => {
  let st = s.addSample(undefined, 30, 8, null);
  st = s.addSample(st, 10, 8, 63);
  st = s.addSample(st, 50, 19, null);
  assert.deepEqual(st.all, { n: 3, sum: 90, sumSq: 900 + 100 + 2500 });
  assert.equal(st.bands.morningPeak.n, 2);
  assert.equal(st.bands.eveningPeak.n, 1);
  assert.deepEqual(st.wet, { n: 1, sum: 10, sumSq: 100 });
});

test('pickBaseline prefers wet, then the band, then all; needs 5 samples', () => {
  const st = statsWith(30, 10);
  assert.equal(s.pickBaseline(st, 'morningPeak', false).basis, 'morningPeak');
  assert.equal(s.pickBaseline(st, 'eveningPeak', false).basis, 'all');
  assert.equal(s.pickBaseline(st, 'morningPeak', true).basis, 'morningPeak'); // too few wet
  assert.equal(s.pickBaseline(statsWith(30, 4), 'morningPeak', false), null);
  const b = s.pickBaseline(st, 'morningPeak', false);
  assert.ok(Math.abs(b.meanKmh - 30) < 1e-9 && Math.abs(b.stddevKmh - 4) < 1e-9);
});

test('isSpeedOutlier needs both the z-score and the 20 km/h floor', () => {
  const b = { sampleCount: 10, meanKmh: 30, stddevKmh: 4, basis: 'all' };
  assert.equal(s.isSpeedOutlier(55, b), true);
  assert.equal(s.isSpeedOutlier(45, b), false); // z 3.75 but only 15 over
  assert.equal(s.isSpeedOutlier(60, { ...b, stddevKmh: 15 }), false); // 30 over, z 2
  assert.equal(s.isSpeedOutlier(51, { ...b, stddevKmh: 0 }), true);
});

test('scoreRide: event score minus road and overspeed penalties', () => {
  const r = s.parseRideUpload(ride({ overspeeds: 1 }), NOW);
  const stats = new Map([
    [SEG_A, statsWith(28, 10)],
    [SEG_B, statsWith(30, 10)],
  ]);
  const out = s.scoreRide(r, stats);
  assert.equal(out.eventScore, 93);
  assert.equal(out.segmentsCompared, 2);
  assert.equal(out.fasterThanUsual.length, 1);
  assert.equal(out.fasterThanUsual[0].segmentId, SEG_B);
  assert.equal(out.roadPenalty, 4);
  assert.equal(out.overspeedPenalty, 3);
  assert.equal(out.score, 86);
  assert.equal(out.tier, 'smooth');
  assert.equal(out.scoringVersion, 1);
});

test('scoreRide with no pool yet is the event score alone', () => {
  const out = s.scoreRide(s.parseRideUpload(ride(), NOW), new Map());
  assert.equal(out.score, 93);
  assert.equal(out.segmentsCompared, 0);
});

test('road penalty is capped', () => {
  const segments = [];
  const stats = new Map();
  const ids = ['wh0r3q0', 'wh0r3q1', 'wh0r3q2', 'wh0r3q3', 'wh0r3q4', 'wh0r3q5', 'wh0r3q6', 'wh0r3q7', 'wh0r3q8', 'wh0r3q9'];
  for (const id of ids) {
    segments.push({ segmentId: id, avgSpeedKmh: 90, pointCount: 4 });
    stats.set(id, statsWith(30, 10));
  }
  const out = s.scoreRide(s.parseRideUpload(ride({ segments, hardBrakes: 0, highJerks: 0 }), NOW), stats);
  assert.equal(out.roadPenalty, s.MAX_ROAD_PENALTY);
  assert.equal(out.score, 70);
});

test('contract: the Dart kit\'s upload (mayabi/test/fixtures) passes validation', () => {
  const fixture = require('../../mayabi/test/fixtures/ride_upload.json');
  const r = s.parseRideUpload(fixture, new Date('2026-10-17T04:00:00Z'));
  assert.equal(r.rideId, 'fixture_ride');
  assert.ok(r.segments.length > 5);
  assert.ok(Math.abs(r.pickupKm + r.tripKm + r.returnKm - r.distanceKm) < 1e-9);
  const score = s.scoreRide(r, new Map());
  assert.equal(score.score, 100);
});
