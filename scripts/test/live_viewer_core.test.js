'use strict';

/**
 * Unit tests for public/live-viewer-core.js — the pure half of the live
 * viewer's Firestore + Realtime Database merge. No emulator needed.
 *
 * Run with:  node --test test/live_viewer_core.test.js   (from scripts/)
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const core = require(path.join(__dirname, '..', '..', 'public', 'live-viewer-core.js'));

const T0 = 1_790_000_000_000;

const fsSession = (atMs, extra = {}) => ({
  lastLat: 23.8,
  lastLng: 90.4,
  speedMs: 5,
  updatedAt: { toDate: () => new Date(atMs) }, // Firestore Timestamp shape
  ...extra,
});
const rtLoc = (atMs, extra = {}) => ({ lat: 23.81, lng: 90.41, ts: atMs, seq: 1, speedMs: 9, ...extra });

test('toMillis reads Timestamp, toMillis(), Date, ISO and number; null otherwise', () => {
  assert.equal(core.toMillis({ toDate: () => new Date(T0) }), T0);
  assert.equal(core.toMillis({ toMillis: () => T0 }), T0);
  assert.equal(core.toMillis(new Date(T0)), T0);
  assert.equal(core.toMillis(new Date(T0).toISOString()), T0);
  assert.equal(core.toMillis(T0), T0);
  assert.equal(core.toMillis(null), null);
  assert.equal(core.toMillis('not a date'), null);
  assert.equal(core.toMillis(NaN), null);
});

test('firestorePosition / rtdbPosition reject missing or non-numeric coordinates', () => {
  assert.equal(core.firestorePosition(null), null);
  assert.equal(core.firestorePosition({ lastLat: 1 }), null);
  assert.equal(core.rtdbPosition(null), null);
  assert.equal(core.rtdbPosition({ lat: '1', lng: 2 }), null);
  // 0,0 is a real coordinate, not "missing".
  assert.ok(core.rtdbPosition({ lat: 0, lng: 0, ts: T0 }));
});

test('pickFreshest prefers the newer source', () => {
  const fs = core.firestorePosition(fsSession(T0));
  const rtNewer = core.rtdbPosition(rtLoc(T0 + 3000));
  const rtOlder = core.rtdbPosition(rtLoc(T0 - 3000));
  assert.equal(core.pickFreshest(fs, rtNewer).source, 'rtdb');
  assert.equal(core.pickFreshest(fs, rtOlder).source, 'firestore');
});

test('pickFreshest: RTDB wins a tie; a timed position beats an untimed one', () => {
  const fs = core.firestorePosition(fsSession(T0));
  assert.equal(core.pickFreshest(fs, core.rtdbPosition(rtLoc(T0))).source, 'rtdb');
  assert.equal(core.pickFreshest(fs, core.rtdbPosition(rtLoc(undefined))).source, 'firestore');
  const fsUntimed = core.firestorePosition({ lastLat: 1, lastLng: 1 });
  assert.equal(core.pickFreshest(fsUntimed, core.rtdbPosition(rtLoc(T0))).source, 'rtdb');
});

test('pickFreshest with only one source returns it; with none returns null', () => {
  const fs = core.firestorePosition(fsSession(T0));
  const rt = core.rtdbPosition(rtLoc(T0));
  assert.equal(core.pickFreshest(fs, null), fs);
  assert.equal(core.pickFreshest(null, rt), rt);
  assert.equal(core.pickFreshest(null, null), null);
});

test('ageMs applies the server time offset and never goes negative', () => {
  const pos = core.rtdbPosition(rtLoc(T0));
  // Local clock 2 s behind the server: offset +2000.
  assert.equal(core.ageMs(pos, T0 - 2000 + 1500, 2000), 1500);
  assert.equal(core.ageMs(pos, T0 - 10_000, 0), 0);
  assert.equal(core.ageMs(null, T0, 0), Infinity);
});

test('transportState: realtime only when connected AND the RTDB fix is fresh', () => {
  const fsPos = core.firestorePosition(fsSession(T0 - 8000));
  const rtPos = core.rtdbPosition(rtLoc(T0 - 1000));
  const now = T0;
  assert.equal(core.transportState({ rtdbConnected: true, rtPos, fsPos, nowMs: now, offsetMs: 0 }), 'realtime');
  // Socket down: the fix may be fresh but no more are coming.
  assert.equal(core.transportState({ rtdbConnected: false, rtPos, fsPos, nowMs: now, offsetMs: 0 }), 'delayed');
  // Socket up but the rider's phone stopped sending.
  const oldRt = core.rtdbPosition(rtLoc(T0 - 6000));
  assert.equal(core.transportState({ rtdbConnected: true, rtPos: oldRt, fsPos, nowMs: now, offsetMs: 0 }), 'delayed');
});

test('transportState: Firestore-only viewers (no RTDB configured) read as delayed, then offline', () => {
  const fsPos = core.firestorePosition(fsSession(T0 - 9000));
  assert.equal(core.transportState({ rtdbConnected: false, rtPos: null, fsPos, nowMs: T0, offsetMs: 0 }), 'delayed');
  assert.equal(
    core.transportState({ rtdbConnected: false, rtPos: null, fsPos, nowMs: T0 + 30_000, offsetMs: 0 }),
    'offline'
  );
  assert.equal(core.transportState({ rtdbConnected: true, rtPos: null, fsPos: null, nowMs: T0, offsetMs: 0 }), 'offline');
});

test('badgeLabel covers every state and defaults to offline', () => {
  assert.equal(core.badgeLabel('realtime'), 'Live · 1s');
  assert.equal(core.badgeLabel('delayed'), 'Updates every 10s');
  assert.equal(core.badgeLabel('offline'), 'Waiting for signal');
  assert.equal(core.badgeLabel('???'), 'Waiting for signal');
});

test('seq tracker: an in-order stream has no gaps', () => {
  const t = core.createSeqTracker();
  assert.equal(t.observe(0), 'first');
  for (let i = 1; i < 10; i++) assert.equal(t.observe(i), 'next');
  assert.deepEqual(t.stats(), {
    received: 10, missed: 0, gaps: 0, outOfOrder: 0, duplicates: 0, restarts: 0, lastSeq: 9,
  });
});

test('seq tracker: counts gaps and how many updates were skipped', () => {
  const t = core.createSeqTracker();
  t.observe(3);
  assert.equal(t.observe(7), 'gap');
  assert.equal(t.observe(8), 'next');
  const s = t.stats();
  assert.equal(s.gaps, 1);
  assert.equal(s.missed, 3);
});

test('seq tracker: out-of-order and duplicates do not drag lastSeq backwards', () => {
  const t = core.createSeqTracker();
  t.observe(5);
  assert.equal(t.observe(3), 'out_of_order');
  assert.equal(t.observe(5), 'duplicate');
  assert.equal(t.observe(6), 'next'); // would be a false "gap" if last had moved to 3
  const s = t.stats();
  assert.equal(s.outOfOrder, 1);
  assert.equal(s.duplicates, 1);
  assert.equal(s.gaps, 0);
});

test('seq tracker: a drop back to 0 is a writer restart, not an error', () => {
  const t = core.createSeqTracker();
  t.observe(40);
  assert.equal(t.observe(0), 'restart');
  assert.equal(t.observe(1), 'next');
  assert.equal(t.stats().outOfOrder, 0);
  assert.equal(t.stats().restarts, 1);
});

test('seq tracker: invalid values are ignored; reset clears everything', () => {
  const t = core.createSeqTracker();
  assert.equal(t.observe(undefined), 'invalid');
  assert.equal(t.stats().received, 0);
  t.observe(1);
  t.observe(5);
  t.reset();
  assert.equal(t.observe(9), 'first');
  assert.equal(t.stats().gaps, 0);
});

test('isStale uses the 30 s threshold and is false before anything arrived', () => {
  assert.equal(core.isStale(T0, null), false);
  assert.equal(core.isStale(T0 + 30_000, T0), false);
  assert.equal(core.isStale(T0 + 30_001, T0), true);
});

test('samePoint', () => {
  assert.equal(core.samePoint({ lat: 1, lng: 2 }, { lat: 1, lng: 2 }), true);
  assert.equal(core.samePoint({ lat: 1, lng: 2 }, { lat: 1, lng: 3 }), false);
  assert.equal(core.samePoint(null, { lat: 1, lng: 2 }), false);
});
