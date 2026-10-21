'use strict';

/**
 * purgeOldReportSnapshots (report-retention.ts) against the Firestore
 * emulator: a report's message snapshot goes 180 days after review; the
 * report stays, and open or recently closed reports keep theirs.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');

const { db, rtdb, clearEmulators } = require('./setup');
const { purgeOldReportSnapshots } = require('../../lib/report-retention');

const NOW = new Date('2026-10-21T00:00:00Z');
const daysAgo = (d) => Timestamp.fromMillis(NOW.getTime() - d * 86_400_000);
const SNAP = { text: 'you idiot', senderId: 'm', sentAt: daysAgo(400) };
const get = async (id) => (await db.doc(`reports/${id}`).get()).data();

test('snapshots of reports reviewed over 180 days ago are removed, nothing else', async () => {
  await clearEmulators();
  const batch = db.batch();
  const set = (id, data) => batch.set(db.doc(`reports/${id}`), { status: 'actioned', ...data });
  set('old', { snapshot: SNAP, reviewedAt: daysAgo(181), note: 'warned' });
  set('edge', { snapshot: SNAP, reviewedAt: daysAgo(179) });
  set('open', { snapshot: SNAP, status: 'pending' });
  set('oldNoSnap', { reviewedAt: daysAgo(300) });
  await batch.commit();

  assert.equal(await purgeOldReportSnapshots(db, NOW), 1);
  assert.deepEqual(await get('old'), { status: 'actioned', reviewedAt: daysAgo(181), note: 'warned' });
  assert.deepEqual((await get('edge')).snapshot, SNAP);
  assert.deepEqual((await get('open')).snapshot, SNAP);
  assert.equal(await purgeOldReportSnapshots(db, NOW), 0, 'a re-run is a no-op');
});

test.after(async () => {
  await rtdb.app.delete();
});
