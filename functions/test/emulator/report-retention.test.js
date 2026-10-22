'use strict';

/**
 * purgeOldReportSnapshots (report-retention.ts) against the Firestore
 * emulator: a report's evidence copy goes 90 days after review; the report
 * stays, and open or recently closed reports keep theirs. A deleted rider's
 * report is anonymised once it is closed, never while pending.
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

test('evidence of reports reviewed over 90 days ago is removed, nothing else', async () => {
  await clearEmulators();
  const batch = db.batch();
  const set = (id, data) => batch.set(db.doc(`reports/${id}`), { status: 'actioned', ...data });
  set('old', { snapshot: SNAP, reviewedAt: daysAgo(91), note: 'warned' });
  set('oldSystem', { originalText: 'you idiot', reviewedAt: daysAgo(200) });
  set('edge', { snapshot: SNAP, reviewedAt: daysAgo(89) });
  set('open', { snapshot: SNAP, status: 'pending' });
  set('oldNoSnap', { reviewedAt: daysAgo(300) });
  set('reopened', { snapshot: SNAP, status: 'pending', reviewedAt: daysAgo(120) });
  await batch.commit();

  assert.equal(await purgeOldReportSnapshots(db, NOW), 2);
  assert.deepEqual(await get('old'), { status: 'actioned', reviewedAt: daysAgo(91), note: 'warned' });
  assert.deepEqual(await get('oldSystem'), { status: 'actioned', reviewedAt: daysAgo(200) });
  assert.deepEqual((await get('edge')).snapshot, SNAP);
  assert.deepEqual((await get('open')).snapshot, SNAP);
  assert.deepEqual((await get('reopened')).snapshot, SNAP, 'a reopened report keeps its evidence');
  assert.equal(await purgeOldReportSnapshots(db, NOW), 0, 'a re-run is a no-op');
});

test("a deleted rider's report is anonymised once closed, kept while pending", async () => {
  await clearEmulators();
  const batch = db.batch();
  const set = (id, data) =>
    batch.set(db.doc(`reports/${id}`), { reportedId: 'm', reportedAccountDeleted: true, snapshot: SNAP, ...data });
  set('pending', { status: 'pending' });
  set('closed', { status: 'dismissed', reviewedAt: daysAgo(2) });
  set('closedOld', { status: 'actioned', reviewedAt: daysAgo(120) });
  await batch.commit();

  assert.equal(await purgeOldReportSnapshots(db, NOW), 2);
  assert.deepEqual(await get('pending'), { reportedId: 'm', reportedAccountDeleted: true, snapshot: SNAP, status: 'pending' });
  assert.deepEqual(await get('closed'), {
    reportedId: '', originalText: '', status: 'dismissed', reviewedAt: daysAgo(2),
    snapshot: { ...SNAP, senderId: 'deleted-rider' },
  });
  assert.deepEqual(await get('closedOld'), { reportedId: '', status: 'actioned', reviewedAt: daysAgo(120) });
  assert.equal(await purgeOldReportSnapshots(db, NOW), 0, 'a re-run is a no-op');
});

test('pages past one batch, and stops at the deadline', async () => {
  await clearEmulators();
  for (let start = 0; start < 450; start += 225) {
    const batch = db.batch();
    for (let i = start; i < start + 225; i++) {
      batch.set(db.doc(`reports/r${i}`), { status: 'actioned', snapshot: SNAP, reviewedAt: daysAgo(100) });
    }
    await batch.commit();
  }
  assert.equal(await purgeOldReportSnapshots(db, NOW, Date.now() - 1), 0, 'past deadline: nothing done');
  assert.equal(await purgeOldReportSnapshots(db, NOW), 450);
  assert.equal(await purgeOldReportSnapshots(db, NOW), 0);
});

test.after(async () => {
  await rtdb.app.delete();
});
