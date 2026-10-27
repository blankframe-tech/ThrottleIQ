'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { uidToBackfill, parseArgs } = require('../oneoff/backfill_vote_uid.js');

test('a ride or forum-post vote without uid gets its doc id as uid', () => {
  assert.equal(uidToBackfill('rides/r1/votes/alice', { value: 1 }), 'alice');
  assert.equal(uidToBackfill('forums/f1/posts/p1/votes/bob', { value: -1 }), 'bob');
});

test('a vote that already has uid is skipped (re-runs are no-ops)', () => {
  assert.equal(uidToBackfill('rides/r1/votes/alice', { value: 1, uid: 'alice' }), null);
});

test('a `votes` collection anywhere else is left alone', () => {
  assert.equal(uidToBackfill('polls/x/votes/alice', { value: 1 }), null);
  assert.equal(uidToBackfill('forums/f1/votes/alice', { value: 1 }), null);
});

test('dry run is the default and --service-account is parsed', () => {
  assert.deepEqual(parseArgs(['--service-account=/k.json']), {
    serviceAccount: '/k.json', confirmed: false, nonInteractive: false, help: false,
  });
  assert.equal(parseArgs(['--service-account=/k.json', '--yes-i-really-mean-it']).confirmed, true);
  assert.throws(() => parseArgs(['--service-acount=/k.json']), /Unknown argument/);
});
