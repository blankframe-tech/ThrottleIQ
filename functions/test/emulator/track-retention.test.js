'use strict';

/**
 * purgeOldTrackChunks (track-retention.ts) against the Firestore emulator:
 * raw GPS chunks older than 12 months go, ride summaries and newer chunks
 * stay. The collection-group index it needs is not enforced here.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');

const { db, rtdb, clearEmulators } = require('./setup');
const { purgeOldTrackChunks } = require('../../lib/track-retention');

const NOW = new Date('2026-10-14T00:00:00Z');
const monthsAgo = (m, extraMs = 0) => {
  const d = new Date(NOW);
  d.setMonth(d.getMonth() - m);
  return Timestamp.fromMillis(d.getTime() + extraMs);
};
const exists = async (path) => (await db.doc(path).get()).exists;

test('old track chunks are deleted; summaries and recent chunks are kept', async () => {
  await clearEmulators();
  const batch = db.batch();
  const set = (path, data) => batch.set(db.doc(path), data);
  set('users/u1/rides/old', { start_time: '2025-08-01T08:00:00.000', distance: 9000 });
  set('users/u1/rides/old/track/0', { index: 0, points: [1, 2, 3, 4, 5], syncedAt: monthsAgo(14) });
  set('users/u1/rides/old/track/1', { index: 1, points: [1, 2, 3, 4, 5], syncedAt: monthsAgo(13) });
  set('users/u2/rides/edge/track/0', { index: 0, points: [], syncedAt: monthsAgo(12, 1000) });
  set('users/u2/rides/recent/track/0', { index: 0, points: [], syncedAt: monthsAgo(1) });
  // Not a ride trail: never touched, however old.
  set('elsewhere/x/track/0', { syncedAt: monthsAgo(30) });
  await batch.commit();

  const deleted = await purgeOldTrackChunks(db, NOW);
  assert.equal(deleted, 2);
  assert.equal(await exists('users/u1/rides/old/track/0'), false);
  assert.equal(await exists('users/u1/rides/old/track/1'), false);
  assert.equal(await exists('users/u1/rides/old'), true, 'summary kept');
  assert.equal(await exists('users/u2/rides/edge/track/0'), true, 'inside the window');
  assert.equal(await exists('users/u2/rides/recent/track/0'), true);
  assert.equal(await exists('elsewhere/x/track/0'), true);
});

test('pages past one batch and is a no-op on a re-run', async () => {
  await clearEmulators();
  // More than one 400-doc page, all expired.
  for (let start = 0; start < 450; start += 225) {
    const batch = db.batch();
    for (let i = start; i < start + 225; i++) {
      batch.set(db.doc(`users/u1/rides/r${i}/track/0`), { index: 0, points: [], syncedAt: monthsAgo(24) });
    }
    await batch.commit();
  }
  assert.equal(await purgeOldTrackChunks(db, NOW), 450);
  assert.equal(await purgeOldTrackChunks(db, NOW), 0);
});

test.after(async () => {
  await rtdb.app.delete();
});
