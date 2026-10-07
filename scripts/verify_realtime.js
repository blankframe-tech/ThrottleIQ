#!/usr/bin/env node
'use strict';

/**
 * Realtime Database smoke test: does a live-share stream actually reach an
 * unauthenticated viewer over the WebSocket, how fast, and does any of it get
 * lost?
 *
 * WRITER  firebase-admin (bypasses rules — stands in for the rider's phone)
 *         writes a throwaway /live_shares/{random 40-char token} node with
 *         expiresAt = now + 5 min, then --count location updates at 1 Hz
 *         (server timestamp + seq, the exact shape the app sends).
 * READER  the firebase JS client SDK, NOT signed in — exactly what
 *         public/live-viewer.html is — so the read goes through
 *         database.rules.json like a real viewer's.
 *
 * Reports received / lost / out-of-order and p50/p95/max latency, then
 * deletes the node. Exit code 0 only if every update arrived in order.
 *
 * Usage (from scripts/):
 *   npm run verify:realtime:emulator                  # against the emulator
 *   node verify_realtime.js --url=https://<db>.firebasedatabase.app [--count=20]
 *
 * Production needs Application Default Credentials (`gcloud auth
 * application-default login`) or GOOGLE_APPLICATION_CREDENTIALS. Nothing
 * touches production unless --url is passed explicitly.
 *
 * Contract: DOCS/For Devs and Contributors/architecture/realtime-database.md.
 */

const crypto = require('node:crypto');

function parseArgs(argv) {
  const args = { count: 20, url: null, emulator: false, intervalMs: 1000 };
  for (const a of argv) {
    if (a === '--emulator') args.emulator = true;
    else if (a.startsWith('--url=')) args.url = a.slice('--url='.length);
    else if (a.startsWith('--count=')) args.count = Number(a.slice('--count='.length));
    else if (a.startsWith('--interval-ms=')) args.intervalMs = Number(a.slice('--interval-ms='.length));
    else if (a === '--help' || a === '-h') args.help = true;
    else throw new Error(`Unknown argument: ${a}`);
  }
  if (!Number.isInteger(args.count) || args.count < 1 || args.count > 600) {
    throw new Error('--count must be an integer between 1 and 600');
  }
  return args;
}

const USAGE = `Usage:
  node verify_realtime.js --emulator [--count=N]
  node verify_realtime.js --url=https://<instance>.firebasedatabase.app [--count=N]`;

function percentile(values, p) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[idx];
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || (!args.url && !args.emulator)) {
    console.log(USAGE);
    process.exit(args.help ? 0 : 2);
  }
  if (args.url && args.emulator) throw new Error('Pass either --url or --emulator, not both');

  const projectId = process.env.GCLOUD_PROJECT || 'throttleiq-rtdb-test';
  let databaseURL = args.url;
  if (args.emulator) {
    const host = process.env.FIREBASE_DATABASE_EMULATOR_HOST || '127.0.0.1:9000';
    process.env.FIREBASE_DATABASE_EMULATOR_HOST = host;
    databaseURL = `http://${host}?ns=${projectId}-default-rtdb`;
  } else if (process.env.FIREBASE_DATABASE_EMULATOR_HOST) {
    // firebase-admin silently prefers the emulator when this is set, which
    // would report emulator numbers under a production URL.
    throw new Error('FIREBASE_DATABASE_EMULATOR_HOST is set; unset it to test --url');
  }

  const admin = require('firebase-admin');
  const { initializeApp, deleteApp } = require('firebase/app');
  const {
    getDatabase,
    connectDatabaseEmulator,
    ref,
    onValue,
    off,
  } = require('firebase/database');

  const writerApp = admin.initializeApp({ projectId, databaseURL }, 'verify-realtime-writer');
  const writer = writerApp.database();

  const readerApp = initializeApp({ projectId, databaseURL }, 'verify-realtime-reader');
  const reader = getDatabase(readerApp);
  if (args.emulator) {
    const [host, port] = process.env.FIREBASE_DATABASE_EMULATOR_HOST.split(':');
    connectDatabaseEmulator(reader, host, Number(port));
  }

  // 40 chars from a 62-symbol alphabet, like the app's 32-char token but
  // visibly distinct from any real one.
  const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const token = Array.from(crypto.randomBytes(40), (b) => ALPHABET[b % ALPHABET.length]).join('');
  const nodePath = `live_shares/${token}`;
  console.log(`[verify] ${args.emulator ? 'emulator' : databaseURL} — ${args.count} updates @ ${args.intervalMs}ms on /${nodePath}`);

  const sentAt = new Map();
  const latencies = [];
  const seen = [];
  let outOfOrder = 0;
  let readerError = null;

  try {
    await writer.ref(nodePath).set({
      uid: 'verify-realtime-smoke',
      expiresAt: Date.now() + 5 * 60_000,
    });

    const locRef = ref(reader, `${nodePath}/location`);
    const allArrived = new Promise((resolve) => {
      onValue(
        locRef,
        (snap) => {
          const v = snap.val();
          if (!v || typeof v.seq !== 'number') return;
          if (sentAt.has(v.seq)) latencies.push(Date.now() - sentAt.get(v.seq));
          if (seen.length && v.seq <= seen[seen.length - 1]) outOfOrder++;
          seen.push(v.seq);
          if (v.seq === args.count - 1) resolve();
        },
        (err) => {
          readerError = err;
          resolve();
        }
      );
    });

    for (let seq = 0; seq < args.count; seq++) {
      sentAt.set(seq, Date.now());
      await writer.ref(`${nodePath}/location`).set({
        lat: 23.81 + seq * 1e-5,
        lng: 90.41,
        speedMs: 8,
        ts: admin.database.ServerValue.TIMESTAMP,
        seq,
      });
      if (seq < args.count - 1) await sleep(args.intervalMs);
    }
    await Promise.race([allArrived, sleep(10_000)]);
    off(locRef);
  } finally {
    await writer.ref(nodePath).remove().catch((e) => console.error('[verify] cleanup failed:', e.message));
    await deleteApp(readerApp).catch(() => {});
    await writerApp.delete().catch(() => {});
  }

  const received = new Set(seen).size;
  const lost = args.count - received;
  const report = {
    sent: args.count,
    received,
    lost,
    outOfOrder,
    latencyMs: {
      p50: percentile(latencies, 50),
      p95: percentile(latencies, 95),
      max: latencies.length ? Math.max(...latencies) : null,
    },
    readerError: readerError ? String(readerError.code || readerError.message) : null,
  };
  console.log(JSON.stringify(report, null, 2));

  const ok = !readerError && lost === 0 && outOfOrder === 0;
  console.log(ok ? '[verify] PASS' : '[verify] FAIL');
  process.exit(ok ? 0 : 1);
}

if (require.main === module) {
  main().catch((e) => {
    console.error('[verify] error:', e.message);
    process.exit(1);
  });
}

module.exports = { parseArgs, percentile };
