'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const path = require('node:path');

const { checkText } = require('../check_listing_lengths');

const doc = (o) => Object.entries(o).map(([k, v]) => `<!-- ${k} -->\n${v}\n<!-- /${k} -->`).join('\n');
const ok = { title: 'ThrottleIQ', short: 'Short', full: 'Full', whatsnew: 'New' };

test('a listing inside every limit passes', () => {
  assert.deepEqual(checkText(doc(ok), 'x'), []);
});

test('fields over their limit, missing or empty fail', () => {
  assert.match(checkText(doc({ ...ok, title: 'a'.repeat(31) }), 'x')[0], /title" is 31 chars, limit 30/);
  assert.match(checkText(doc({ ...ok, short: 'a'.repeat(81) }), 'x')[0], /limit 80/);
  assert.match(checkText(doc({ ...ok, full: 'a'.repeat(4001) }), 'x')[0], /limit 4000/);
  assert.match(checkText(doc({ title: 'x', short: 'x', full: 'x' }), 'x')[0], /missing field "whatsnew"/);
  assert.match(checkText(doc({ ...ok, short: ' ' }), 'x')[0], /empty/);
});

test('Bangla counts code points', () => {
  assert.deepEqual(checkText(doc({ ...ok, title: 'ক'.repeat(30) }), 'x'), []);
  assert.equal(checkText(doc({ ...ok, title: 'ক'.repeat(31) }), 'x').length, 1);
});

test('the play_listing_v1 pack passes', () => {
  execFileSync(process.execPath, [path.join(__dirname, '..', 'check_listing_lengths.js')], { stdio: 'pipe' });
});
