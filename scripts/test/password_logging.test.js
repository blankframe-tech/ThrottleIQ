// Dry runs must never print a password (security sweep 2026-10-30, D2).
// No emulator or credentials needed; runs under `npm test`.
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const run = (script, ...args) =>
  execFileSync(process.execPath, [path.join(__dirname, '..', 'oneoff', script), ...args], {
    encoding: 'utf8',
    env: { ...process.env, PLAY_REVIEW_PASSWORD: '' },
  });

test('create_review_account dry run does not echo a provided password', () => {
  const out = run('create_review_account.js', '--dry-run', '--password', 'Provided-Secret-123');
  assert.ok(!out.includes('Provided-Secret-123'), out);
  assert.match(out, /as provided, not echoed/);
});

test('seed_qa_test_riders dry run redacts the sample rider password', () => {
  const out = run('seed_qa_test_riders.js', '--dry-run');
  assert.match(out, /"password": "\[redacted\]"/);
});
