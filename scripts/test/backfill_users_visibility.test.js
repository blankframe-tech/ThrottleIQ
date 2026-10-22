'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { needsBackfill, parseArgs } = require('../oneoff/backfill_users_visibility.js');

test('only a missing or null visibility needs the backfill', () => {
  assert.equal(needsBackfill({ displayName: 'A' }), true);
  assert.equal(needsBackfill({ visibility: null }), true);
  for (const v of ['public', 'mutual', 'private']) assert.equal(needsBackfill({ visibility: v }), false);
});

test('dry run is the default and --project is parsed', () => {
  assert.deepEqual(parseArgs(['--project=demo']), { project: 'demo', confirmed: false, nonInteractive: false, help: false });
  assert.equal(parseArgs(['--project=demo', '--yes-i-really-mean-it']).confirmed, true);
  assert.throws(() => parseArgs(['--projet=demo']), /Unknown argument/);
});
