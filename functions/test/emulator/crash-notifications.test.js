'use strict';

/**
 * Crash-alert idempotency (issues §101.S5) against the Firestore emulator:
 * a duplicate delivery of the create event, or two overlapping escalation
 * sweeps, must not send twice.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const { db, rtdb, clearEmulators } = require('./setup');
const { handleCrashNotification, runEscalationSweep } = require('../../lib/crash-core');
const { CLAIM_LEASE_MS, ALERT_LIMIT } = require('../../lib/crash-claim');

const UID = 'crashRiderUid00000000000001';

async function logRows(filter) {
  const snap = await db.collection(`users/${UID}/notificationLog`).get();
  return snap.docs.map((d) => d.data()).filter(filter);
}

test.before(async () => {
  await clearEmulators();
  await db.doc(`users/${UID}`).set({ displayName: 'Rider' });
  await db.doc(`users/${UID}/emergencyContacts/c1`).set({ name: 'A', phone: '+880100' });
  await db.doc(`users/${UID}/emergencyContacts/c2`).set({ name: 'B', email: 'b@example.com' });
});

test('a duplicated create event notifies each contact once', async () => {
  const ref = db.doc('crashNotifications/ride-1');
  await ref.set({ uid: UID, rideId: 'ride-1', timestamp: new Date().toISOString(), status: 'pending' });

  // Two deliveries racing, then a late third one.
  const raced = await Promise.all([
    handleCrashNotification(db, ref),
    handleCrashNotification(db, ref),
  ]);
  const late = await handleCrashNotification(db, ref);

  assert.deepEqual(raced.filter(Boolean).length, 1, 'exactly one delivery did the work');
  assert.equal(late, false);
  const rows = await logRows((r) => r.rideId === 'ride-1');
  assert.equal(rows.length, 2, 'one log row per contact');
  assert.equal((await ref.get()).get('status'), 'mock_not_sent');
});

test('a stale processing claim is taken over; a fresh one is not', async () => {
  const stale = db.doc('crashNotifications/ride-2');
  await stale.set({
    uid: UID,
    rideId: 'ride-2',
    status: 'processing',
    claimedAt: new Date(Date.now() - CLAIM_LEASE_MS - 1000).toISOString(),
  });
  assert.equal(await handleCrashNotification(db, stale), true);
  assert.equal((await logRows((r) => r.rideId === 'ride-2')).length, 2);

  const fresh = db.doc('crashNotifications/ride-3');
  await fresh.set({
    uid: UID,
    rideId: 'ride-3',
    status: 'processing',
    claimedAt: new Date().toISOString(),
  });
  assert.equal(await handleCrashNotification(db, fresh), false);
  assert.equal((await logRows((r) => r.rideId === 'ride-3')).length, 0);
});

test('overlapping escalation sweeps escalate each alert once', async () => {
  const old = new Date(Date.now() - 20 * 60 * 1000).toISOString();
  await db.doc('crashNotifications/esc-1').set({ uid: UID, rideId: 'esc-1', status: 'contacted', contactedAt: old });
  await db.doc('crashNotifications/esc-2').set({ uid: UID, rideId: 'esc-2', status: 'contacted', contactedAt: old });
  // Abandoned mid-escalation: picked up again.
  await db.doc('crashNotifications/esc-3').set({
    uid: UID,
    rideId: 'esc-3',
    status: 'escalating',
    contactedAt: old,
    escalatingAt: new Date(Date.now() - CLAIM_LEASE_MS - 1000).toISOString(),
  });
  // Another sweep is mid-escalation right now: left alone.
  await db.doc('crashNotifications/esc-4').set({
    uid: UID,
    rideId: 'esc-4',
    status: 'escalating',
    contactedAt: old,
    escalatingAt: new Date().toISOString(),
  });
  // Not due yet.
  await db.doc('crashNotifications/esc-5').set({
    uid: UID,
    rideId: 'esc-5',
    status: 'contacted',
    contactedAt: new Date().toISOString(),
  });

  const results = await Promise.all([runEscalationSweep(db), runEscalationSweep(db)]);
  await runEscalationSweep(db);

  assert.equal(results[0].escalated + results[1].escalated, 3);
  for (const id of ['esc-1', 'esc-2', 'esc-3']) {
    const rows = await logRows((r) => r.type === 'escalation' && r.rideId === id);
    assert.equal(rows.length, 1, `${id} escalated once`);
    assert.equal((await db.doc(`crashNotifications/${id}`).get()).get('status'), 'escalated');
  }
  for (const id of ['esc-4', 'esc-5']) {
    const rows = await logRows((r) => r.type === 'escalation' && r.rideId === id);
    assert.equal(rows.length, 0, `${id} not escalated`);
  }
});

test('a failed escalation fails the sweep instead of reporting success', async () => {
  // No uid: the follow-up log write throws for this doc.
  await db.doc('crashNotifications/esc-bad').set({
    rideId: 'esc-bad',
    status: 'contacted',
    contactedAt: new Date(Date.now() - 20 * 60 * 1000).toISOString(),
  });
  await assert.rejects(runEscalationSweep(db), /1 escalation\(s\) failed: esc-bad/);
});

// Security sweep 2026-10-30 C5: once delivery is real, each alert texts every
// contact, so a rider (or a stolen account) could flood strangers' phones.
const SPAMMER = 'crashRiderUid00000000000002';

test('an alert reaches at most 5 contacts', async () => {
  for (let i = 0; i < 7; i++) {
    await db.doc(`users/${SPAMMER}/emergencyContacts/c${i}`).set({ name: `C${i}`, phone: `+88010${i}` });
  }
  const ref = db.doc('crashNotifications/spam-0');
  await ref.set({ uid: SPAMMER, rideId: 'spam-0', status: 'pending' });
  assert.equal(await handleCrashNotification(db, ref), true);
  assert.equal((await ref.get()).get('contactsResolved'), 5);
  const rows = await db.collection(`users/${SPAMMER}/notificationLog`).get();
  assert.equal(rows.size, 5);
});

test('alerts past the per-rider limit are held back, not sent', async () => {
  // spam-0 above already counted once.
  for (let i = 1; i <= ALERT_LIMIT; i++) {
    const ref = db.doc(`crashNotifications/spam-${i}`);
    await ref.set({ uid: SPAMMER, rideId: `spam-${i}`, status: 'pending' });
    await handleCrashNotification(db, ref);
    const status = (await ref.get()).get('status');
    assert.equal(status, i < ALERT_LIMIT ? 'mock_not_sent' : 'rate_limited', `alert ${i + 1}`);
  }
  const rows = await db.collection(`users/${SPAMMER}/notificationLog`).get();
  assert.equal(rows.size, 5 * ALERT_LIMIT, 'nothing logged for the held-back alert');
});

test.after(async () => {
  await rtdb.app.delete();
});
