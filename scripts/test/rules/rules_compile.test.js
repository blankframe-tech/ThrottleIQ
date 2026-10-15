'use strict';

/**
 * `firestore.rules` must compile with no warnings. The emulator returns the
 * same issues `firebase deploy` prints (e.g. the old "Invalid type. Received
 * one of [null]. Expected one of [map]." on the publicStatsValid call), so a
 * new warning fails here instead of surfacing only at deploy time.
 *
 * Run with:  npm run test:rules   (from scripts/)
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('firestore.rules compiles with no warnings or errors', async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  const content = fs.readFileSync(path.join(__dirname, '../../../firestore.rules'), 'utf8');
  const res = await fetch(`http://${host}/emulator/v1/projects/throttleiq-rules-compile:securityRules`, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ rules: { files: [{ name: 'firestore.rules', content }] } }),
  });
  const body = await res.json();
  assert.equal(res.status, 200, JSON.stringify(body));
  assert.deepEqual(body.issues ?? [], [], JSON.stringify(body.issues, null, 2));
});
