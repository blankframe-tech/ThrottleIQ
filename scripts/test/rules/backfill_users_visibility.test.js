'use strict';

/**
 * backfill_users_visibility.js against the Firestore emulator (Admin SDK, no
 * rules involved). Lives in test/rules/ only because that suite is the one
 * that runs inside `firebase emulators:exec`.
 *
 * Run with:  npm run test:rules   (from scripts/)
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { backfill } = require('../../oneoff/backfill_users_visibility.js');

const app = admin.initializeApp({ projectId: 'demo-throttleiq-backfill' }, 'backfill-test');
const db = admin.firestore(app);

test.before(async () => {
  const batch = db.batch();
  batch.set(db.doc('users/legacy1'), { displayName: 'Old one' });
  batch.set(db.doc('users/legacy2'), { displayName: 'Old two', visibility: null });
  batch.set(db.doc('users/mutual'), { displayName: 'M', visibility: 'mutual' });
  batch.set(db.doc('users/private'), { displayName: 'P', visibility: 'private' });
  await batch.commit();
});

test.after(() => app.delete());

test('dry run counts the legacy profiles and writes nothing', async () => {
  const r = await backfill(db);
  assert.equal(r.scanned, 4);
  assert.equal(r.missing, 2);
  assert.equal(r.written, 0);
  assert.equal((await db.doc('users/legacy1').get()).get('visibility'), undefined);
});

test('a write run stamps public only where it is missing, and a re-run is a no-op', async () => {
  const r = await backfill(db, { write: true });
  assert.deepEqual([r.missing, r.written, r.skipped.length], [2, 2, 0]);
  const vis = async (id) => (await db.doc(`users/${id}`).get()).get('visibility');
  assert.equal(await vis('legacy1'), 'public');
  assert.equal(await vis('legacy2'), 'public');
  assert.equal(await vis('mutual'), 'mutual');
  assert.equal(await vis('private'), 'private');
  assert.deepEqual([(await backfill(db, { write: true })).missing], [0]);
});
