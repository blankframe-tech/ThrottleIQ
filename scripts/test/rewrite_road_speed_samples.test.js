'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');
const { rewrittenSample, parseArgs } = require('../oneoff/rewrite_road_speed_samples.js');

const PATH = 'roadSpeedSamples/w7z3s5d/samples/abc';
const OLD = {
  speedKmh: 42.5, weekday: 3, hour: 14, weatherCode: 1,
  createdAt: Timestamp.fromMillis(Date.UTC(2026, 9, 21, 23, 59, 59)),
};

test('an old sample keeps its fields, trades createdAt for its UTC day', () => {
  assert.deepEqual(rewrittenSample(PATH, OLD), {
    speedKmh: 42.5, weekday: 3, hour: 14, weatherCode: 1,
    day: Math.floor(Date.UTC(2026, 9, 21) / 86400000),
  });
});

test('a sample already in the new shape is skipped (re-runs are no-ops)', () => {
  const { createdAt, ...rest } = OLD;
  assert.equal(rewrittenSample(PATH, { ...rest, day: 20400 }), null);
});

test('a `samples` collection anywhere else is left alone', () => {
  assert.equal(rewrittenSample('crashEvents/x/samples/abc', OLD), null);
  assert.equal(rewrittenSample('roadSpeedSamples/w7z3s5d', OLD), null);
});

test('dry run is the default and --service-account is parsed', () => {
  assert.deepEqual(parseArgs(['--service-account=/k.json']), {
    serviceAccount: '/k.json', confirmed: false, nonInteractive: false, help: false,
  });
  assert.equal(parseArgs(['--service-account=/k.json', '--yes-i-really-mean-it']).confirmed, true);
  assert.throws(() => parseArgs(['--bogus']), /Unknown argument/);
});
