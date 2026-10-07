'use strict';

/**
 * End-to-end delivery tests for the Realtime Database channel — the
 * "do the WebSockets actually work" suite.
 *
 * Unlike rtdb_rules.test.js (which only asks "is this read/write allowed?"),
 * every test here runs two independent SDK clients, each with its own app and
 * therefore its own WebSocket to the database emulator: a WRITER (the rider's
 * phone) and a READER (the partner's viewer, or another group member). What
 * is asserted is what a rider would notice:
 *
 *   - a fast stream arrives complete and in order (no `seq` gaps, no
 *     reordering), with bounded latency;
 *   - `.info/connected` really reflects the socket going down and up;
 *   - `onDisconnect().remove()` runs server-side when the writer drops, so a
 *     typing bubble / marker never outlives a dead phone;
 *   - writes made while offline are delivered after reconnect;
 *   - a reader the rules refuse is TOLD so (permission error), rather than
 *     silently waiting forever on a listener that will never fire.
 *
 * Contract: DOCS/For Devs and Contributors/architecture/realtime-database.md.
 * Run with:  npm run test:rtdb   (from scripts/)
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'database.rules.json'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const MALLORY = 'mallory-uid';
const TOKEN = 'd'.repeat(40);
const RIDE = 'ride-delivery';
const DM = `${ALICE}_${BOB}`;
const SERVER_TS = { '.sv': 'timestamp' };

// Generous: the emulator is local, so anything near this means something is
// genuinely wrong (polling fallback, Nagle-style batching, a stuck queue).
const P95_LATENCY_BOUND_MS = 500;
const STREAM_LENGTH = 20;
const STREAM_INTERVAL_MS = 120;

let testEnv;
const openDbs = [];

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rtdb-delivery-test',
    database: { rules: RULES, host: '127.0.0.1', port: 9000 },
  });
});

test.after(async () => {
  for (const db of openDbs) {
    try { db.goOffline(); } catch (_) { /* already gone */ }
  }
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearDatabase();
});

/// A fresh client with its OWN app (and so its own WebSocket). Rules-unit-
/// testing caches one app per context, so a new context = a new connection.
function client(uid) {
  const ctx = uid ? testEnv.authenticatedContext(uid) : testEnv.unauthenticatedContext();
  const db = ctx.database();
  openDbs.push(db);
  return db;
}

async function seed(pathName, value) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.database().ref(pathName).set(value);
  });
}

/// Resolves with the first value for which [predicate] is true, or rejects
/// after [timeoutMs] with [label] — so a broken socket fails the test with a
/// name instead of hanging the whole run.
function waitForValue(ref, predicate, label, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      ref.off('value', onValue);
      reject(new Error(`timed out after ${timeoutMs}ms waiting for: ${label}`));
    }, timeoutMs);
    const onValue = (snap) => {
      const value = snap.val();
      if (!predicate(value)) return;
      clearTimeout(timer);
      ref.off('value', onValue);
      resolve(value);
    };
    ref.on('value', onValue, (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function percentile(values, p) {
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1);
  return sorted[Math.max(0, idx)];
}

function location(seq) {
  return { lat: 23.81 + seq * 1e-4, lng: 90.41, ts: SERVER_TS, seq, speedMs: 8 };
}

test('a 1 Hz-style live-share stream arrives complete, in order, with bounded latency', async () => {
  await seed(`live_shares/${TOKEN}`, { uid: ALICE, expiresAt: Date.now() + 10 * 60_000 });

  const writer = client(ALICE);
  const reader = client(null); // the partner viewer never signs in

  const sentAt = new Map();
  const received = [];
  const latencies = [];
  const ref = reader.ref(`live_shares/${TOKEN}/location`);

  const done = new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`only received seqs ${received.join(',')}`)),
      STREAM_LENGTH * STREAM_INTERVAL_MS + 5000
    );
    ref.on(
      'value',
      (snap) => {
        const v = snap.val();
        if (!v) return;
        if (sentAt.has(v.seq)) latencies.push(Date.now() - sentAt.get(v.seq));
        received.push(v.seq);
        if (v.seq === STREAM_LENGTH - 1) {
          clearTimeout(timer);
          resolve();
        }
      },
      (err) => {
        clearTimeout(timer);
        reject(err);
      }
    );
  });

  // Let the reader's initial (empty) snapshot land before streaming.
  await sleep(200);

  for (let seq = 0; seq < STREAM_LENGTH; seq++) {
    sentAt.set(seq, Date.now());
    await writer.ref(`live_shares/${TOKEN}/location`).set(location(seq));
    await sleep(STREAM_INTERVAL_MS);
  }
  await done;
  ref.off();

  // Every seq exactly once, strictly increasing: no gaps, no reordering.
  assert.deepEqual(received, Array.from({ length: STREAM_LENGTH }, (_, i) => i));

  const p50 = percentile(latencies, 50);
  const p95 = percentile(latencies, 95);
  console.log(`[delivery] ${received.length}/${STREAM_LENGTH} delivered, p50=${p50}ms p95=${p95}ms`);
  assert.ok(p95 < P95_LATENCY_BOUND_MS, `p95 latency ${p95}ms exceeds ${P95_LATENCY_BOUND_MS}ms`);
});

test('the server timestamp a reader sees is the server clock, not the writer\'s', async () => {
  await seed(`live_shares/${TOKEN}`, { uid: ALICE, expiresAt: Date.now() + 10 * 60_000 });
  const writer = client(ALICE);
  const reader = client(null);

  const before = Date.now();
  await writer.ref(`live_shares/${TOKEN}/location`).set(location(0));
  const v = await waitForValue(
    reader.ref(`live_shares/${TOKEN}/location`),
    (val) => val && val.seq === 0,
    'seq 0'
  );
  assert.equal(typeof v.ts, 'number', 'ts must resolve to a number, not the {.sv} placeholder');
  // Same machine as the emulator, so the server clock is ours (± a little).
  assert.ok(Math.abs(v.ts - before) < 5000, `ts ${v.ts} not near ${before}`);
});

test('.info/connected goes false on goOffline() and true again on goOnline()', async () => {
  const db = client(ALICE);
  const connected = db.ref('.info/connected');

  await waitForValue(connected, (v) => v === true, 'initial connect');
  db.goOffline();
  await waitForValue(connected, (v) => v === false, 'disconnect after goOffline');
  db.goOnline();
  await waitForValue(connected, (v) => v === true, 'reconnect after goOnline');
});

test('onDisconnect().remove() clears a typing flag when the writer\'s socket drops', async () => {
  const writer = client(ALICE);
  const reader = client(BOB);
  const mine = writer.ref(`chat_presence/${DM}/${ALICE}`);
  const theirs = reader.ref(`chat_presence/${DM}/${ALICE}`);

  await mine.onDisconnect().remove();
  await mine.set({ typing: true, ts: SERVER_TS });
  await waitForValue(theirs, (v) => v && v.typing === true, 'typing:true seen by the other rider');

  // Simulates the phone losing signal / being killed: the server, not the
  // client, has to run the cleanup.
  writer.goOffline();
  await waitForValue(theirs, (v) => v === null, 'typing flag removed by onDisconnect');
});

test('onDisconnect().remove() takes a group-ride marker off the map when its rider drops', async () => {
  await seed(`group_rides/${RIDE}/meta`, { creatorId: ALICE });
  const bob = client(BOB);
  const alice = client(ALICE);
  const mine = bob.ref(`group_rides/${RIDE}/locations/${BOB}`);

  await mine.onDisconnect().remove();
  await mine.set(location(0));
  const locations = alice.ref(`group_rides/${RIDE}/locations`);
  await waitForValue(locations, (v) => v && v[BOB], 'bob visible to alice');

  bob.goOffline();
  await waitForValue(locations, (v) => !v || !v[BOB], 'bob removed after disconnect');
});

test('writes made while offline are delivered after the writer reconnects', async () => {
  await seed(`group_rides/${RIDE}/meta`, { creatorId: ALICE });
  const writer = client(BOB);
  const reader = client(ALICE);
  const writerConnected = writer.ref('.info/connected');
  await waitForValue(writerConnected, (v) => v === true, 'writer connected');

  writer.goOffline();
  await waitForValue(writerConnected, (v) => v === false, 'writer offline');

  // Queued locally; nothing reaches the server yet.
  const acks = [];
  for (let seq = 0; seq < 5; seq++) {
    acks.push(writer.ref(`group_rides/${RIDE}/locations/${BOB}`).set(location(seq)));
  }
  await sleep(300);
  const meanwhile = (await reader.ref(`group_rides/${RIDE}/locations/${BOB}`).get()).val();
  assert.equal(meanwhile, null, 'an offline write must not reach other clients');

  writer.goOnline();
  const v = await waitForValue(
    reader.ref(`group_rides/${RIDE}/locations/${BOB}`),
    (val) => val && val.seq === 4,
    'last queued seq after reconnect'
  );
  assert.equal(v.seq, 4);
  await Promise.all(acks); // every queued write was acknowledged by the server
});

test('a reader the rules refuse gets a permission error, not silence', async () => {
  await seed(`chat_presence/${DM}/${ALICE}`, { typing: true, ts: Date.now() });
  const outsider = client(MALLORY);

  const err = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('listener neither fired nor errored')), 5000);
    outsider.ref(`chat_presence/${DM}`).on(
      'value',
      () => {
        clearTimeout(timer);
        reject(new Error('outsider received data'));
      },
      (e) => {
        clearTimeout(timer);
        resolve(e);
      }
    );
  });
  assert.match(String(err.code || err.message), /permission/i);
});

test('an expired live share stops a fresh viewer with a permission error', async () => {
  await seed(`live_shares/${TOKEN}`, {
    uid: ALICE,
    expiresAt: Date.now() - 1000,
    location: { lat: 1, lng: 1, ts: Date.now(), seq: 0 },
  });
  const viewer = client(null);
  await assert.rejects(viewer.ref(`live_shares/${TOKEN}/location`).get(), /permission/i);
});

test('removing a live share cancels an attached viewer\'s listener (permission_denied)', async () => {
  // Real emulator behaviour, pinned here because the viewer depends on it:
  // the read rule keys on `expiresAt`, so once the owner deletes the node the
  // server re-evaluates the listen, finds no permission, and CANCELS it —
  // the viewer never receives a plain `null`. public/live-viewer.html treats
  // that cancellation as "the realtime channel ended" and falls back to the
  // Firestore session (which carries the authoritative ended/revoked state),
  // not as a fatal error.
  await seed(`live_shares/${TOKEN}`, { uid: ALICE, expiresAt: Date.now() + 60_000 });
  const writer = client(ALICE);
  const viewer = client(null);
  await writer.ref(`live_shares/${TOKEN}/location`).set(location(0));

  const ref = viewer.ref(`live_shares/${TOKEN}/location`);
  const seen = [];
  const cancelled = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`no cancellation; saw ${JSON.stringify(seen)}`)), 5000);
    ref.on(
      'value',
      (snap) => seen.push(snap.val()),
      (err) => {
        clearTimeout(timer);
        resolve(err);
      }
    );
  });
  await waitForValue(ref, (v) => v && v.seq === 0, 'viewer sees location');

  // "Stop sharing now": the app deletes the node.
  await writer.ref(`live_shares/${TOKEN}`).remove();
  const err = await cancelled;
  assert.match(String(err.code || err.message), /permission/i);
  assert.ok(seen.every((v) => v === null || v.seq === 0), 'no data after removal');
});
