'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { kind, violations } = require('../ste_sentence_length.js');

const n = (count) => Array.from({ length: count }, (_, i) => `w${i}`).join(' ');

test('an imperative is procedural; an ID like SET-1 is not', () => {
  assert.equal(kind('Check the oil.'), 'procedural');
  assert.equal(kind('SET-1 The rider can choose.'), 'descriptive');
  assert.equal(kind('The app records rides.'), 'descriptive');
});

test('limits are 20 procedural and 25 descriptive words, per table cell and sentence', () => {
  assert.deepEqual(violations(`Check ${n(19)}.`), []);
  assert.equal(violations(`Check ${n(20)}.`)[0].count, 21);
  assert.deepEqual(violations(`| A | The ${n(24)}. Short one. |`), []);
  assert.equal(violations(`The ${n(25)}.`).length, 1);
});

test('code fences, headings and table rules are skipped', () => {
  assert.deepEqual(violations(`# The ${n(30)}\n\`\`\`\nThe ${n(30)}\n\`\`\`\n|---|---|`), []);
});
