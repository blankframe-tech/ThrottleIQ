#!/usr/bin/env node
'use strict';
const { cert, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

/**
 * rewrite_road_speed_samples.js — one-off: drop exact times from the
 * anonymous road-speed pool.
 *
 * Samples in `roadSpeedSamples/{cell}/samples` used to carry
 * `createdAt` (server time), and one ride's samples were written one after
 * another in route order. The app now writes a UTC day number (`day`)
 * instead, in shuffled order. This rewrites every old sample as a NEW doc
 * (new auto id) with `createdAt` replaced by its UTC `day`, then deletes the
 * old doc. A rewrite rather than an update, because Firestore keeps each
 * doc's original create time and an update would not reset it. All docs are
 * shuffled before writing, so each batch mixes cells and rides. Without this,
 * old samples also drop out of the app's reads, which order by `day`.
 *
 * Run it after the rules that require `day` are deployed (old builds stop
 * writing `createdAt` then). The Admin SDK bypasses rules.
 *
 * Safety:
 *   - --dry-run is the DEFAULT: reads only, prints counts.
 *   - The service-account key's project_id must be 'throttleiqfb'.
 *   - Writes need --yes-i-really-mean-it plus a typed confirmation.
 *   - Each batch creates the new docs and deletes their old docs together,
 *     so a sample is never lost or doubled. Idempotent: docs that already
 *     have no `createdAt` are skipped.
 *
 * Usage (from scripts/):
 *   node oneoff/rewrite_road_speed_samples.js --service-account=/path/to/key.json
 *   node oneoff/rewrite_road_speed_samples.js --service-account=/path/to/key.json --yes-i-really-mean-it
 */

const fs = require('node:fs');
const crypto = require('node:crypto');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const CONFIRMATION_PHRASE = 'REWRITE ROAD SAMPLES';
const PAGE = 400;
const BATCH = 200; // 200 creates + 200 deletes

const SAMPLE_PATH = /^roadSpeedSamples\/[^/]+\/samples\/[^/]+$/;
const DAY_MS = 86400000;

function fail(msg) { console.error(`\n  ERROR  ${msg}\n`); process.exit(1); }

/** The new doc for the old sample at `path`, or null when it needs nothing. */
function rewrittenSample(path, data) {
  if (!SAMPLE_PATH.test(path) || !data.createdAt || typeof data.createdAt.toMillis !== 'function') return null;
  const { createdAt, ...rest } = data;
  return { ...rest, day: Math.floor(createdAt.toMillis() / DAY_MS) };
}

function parseArgs(argv) {
  const opts = { serviceAccount: null, confirmed: false, nonInteractive: false, help: false };
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg.startsWith('--service-account=')) opts.serviceAccount = arg.slice('--service-account='.length);
    else if (arg === '--yes-i-really-mean-it') opts.confirmed = true;
    else if (arg === '--non-interactive') opts.nonInteractive = true;
    else if (arg === '--dry-run') { /* the default */ }
    else throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
  }
  return opts;
}

async function confirm(nonInteractive) {
  if (nonInteractive) return;
  const readline = require('node:readline/promises');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await rl.question(`  Type "${CONFIRMATION_PHRASE}" to continue: `);
  rl.close();
  if (answer.trim() !== CONFIRMATION_PHRASE) fail('Confirmation did not match. Nothing was changed.');
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    console.log(fs.readFileSync(__filename, 'utf8').split('*/')[0]);
    return;
  }
  if (!opts.serviceAccount) fail('Pass --service-account=/path/to/key.json.');
  let key;
  try {
    key = JSON.parse(fs.readFileSync(opts.serviceAccount, 'utf8'));
  } catch (e) {
    fail(`Cannot read the service-account key: ${e.message}`);
  }
  if (key.project_id !== EXPECTED_PROJECT_ID) {
    fail(`The key is for project '${key.project_id}', not '${EXPECTED_PROJECT_ID}'. Refusing to run.`);
  }

  const app = initializeApp({ credential: cert(key), projectId: EXPECTED_PROJECT_ID });
  const db = getFirestore(app);
  const { FieldPath } = require('firebase-admin/firestore');

  const todo = [];
  let scanned = 0;
  let last = null;
  for (;;) {
    let q = db.collectionGroup('samples').orderBy(FieldPath.documentId()).limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    scanned += snap.size;
    for (const doc of snap.docs) {
      const data = rewrittenSample(doc.ref.path, doc.data());
      if (data) todo.push({ ref: doc.ref, data });
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }

  console.log(`  Scanned ${scanned} \`samples\` docs; ${todo.length} road-speed samples still carry \`createdAt\`.`);
  if (!opts.confirmed) {
    console.log('  Dry run: nothing changed. Re-run with --yes-i-really-mean-it to rewrite them.');
    return;
  }
  if (todo.length === 0) return;
  await confirm(opts.nonInteractive);

  for (let i = todo.length - 1; i > 0; i--) { // Fisher-Yates
    const j = crypto.randomInt(i + 1);
    [todo[i], todo[j]] = [todo[j], todo[i]];
  }
  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = db.batch();
    for (const { ref, data } of todo.slice(i, i + BATCH)) {
      batch.create(ref.parent.doc(), data);
      batch.delete(ref);
    }
    await batch.commit();
    console.log(`  Rewrote ${Math.min(i + BATCH, todo.length)}/${todo.length}`);
  }
  console.log('  Done. A second run should report 0 samples carrying `createdAt`.');
}

if (require.main === module) {
  main().catch((e) => fail(e.stack || String(e)));
}

module.exports = { rewrittenSample, parseArgs };
