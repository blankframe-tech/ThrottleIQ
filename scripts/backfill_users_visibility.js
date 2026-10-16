#!/usr/bin/env node
'use strict';

/**
 * backfill_users_visibility.js — one-off: set `visibility: 'public'` on every
 * `users/{uid}` profile that has no `visibility` (or a null one).
 *
 * Why: the A4/D9 rules only allow a `users` list query that filters
 * `visibility == 'public'`, so a legacy profile without the field drops out
 * of search, suggestions and All People until the rider signs in again
 * (ProfileRepository.ensureProfile stamps it). Single-doc reads already treat
 * a missing field as public, so this changes no rider's privacy.
 *
 * Safety:
 *   - --project=<id> is REQUIRED. Outside the emulator, the key in
 *     GOOGLE_APPLICATION_CREDENTIALS must belong to that project.
 *   - Dry run is the DEFAULT: reads only, prints the count and a few uids.
 *   - Writes need --yes-i-really-mean-it plus a typed confirmation
 *     (--non-interactive skips the prompt).
 *   - Idempotent: only docs still missing the field are written; a second run
 *     finds 0. Each write carries the doc's read time as a precondition, so a
 *     rider who sets their own visibility mid-run is never overwritten (that
 *     doc is reported as skipped; re-run to pick up anything left).
 *   - Batched: reads 300 docs a page; writes go through a BulkWriter.
 *
 * Usage (from scripts/):
 *   export GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/throttleiqfb-admin.json
 *   node backfill_users_visibility.js --project=throttleiqfb                         # dry run
 *   node backfill_users_visibility.js --project=throttleiqfb --yes-i-really-mean-it  # writes
 */

const fs = require('node:fs');

const CONFIRMATION_PHRASE = 'BACKFILL VISIBILITY';
const PAGE = 300;

function fail(msg) { console.error(`\n  ERROR  ${msg}\n`); process.exit(1); }

/** Missing and null both count as "no visibility". */
function needsBackfill(data) {
  return data.visibility === undefined || data.visibility === null;
}

function parseArgs(argv) {
  const opts = { project: null, confirmed: false, nonInteractive: false, help: false };
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg.startsWith('--project=')) opts.project = arg.slice('--project='.length);
    else if (arg === '--yes-i-really-mean-it') opts.confirmed = true;
    else if (arg === '--non-interactive') opts.nonInteractive = true;
    else if (arg === '--dry-run') { /* the default */ }
    else throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
  }
  return opts;
}

/**
 * Scans `users` and, when `write` is true, stamps 'public' on the docs that
 * need it. Returns { scanned, missing, written, skipped, sample }.
 */
async function backfill(db, { write = false, log = () => {} } = {}) {
  const { FieldPath } = require('firebase-admin').firestore;
  const todo = [];
  let scanned = 0;
  let last = null;
  for (;;) {
    let q = db.collection('users').orderBy(FieldPath.documentId()).limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    scanned += snap.size;
    for (const doc of snap.docs) if (needsBackfill(doc.data())) todo.push(doc);
    if (snap.size < PAGE) break;
    last = snap.docs[snap.docs.length - 1];
  }

  const result = { scanned, missing: todo.length, written: 0, skipped: [], sample: todo.slice(0, 10).map((d) => d.id) };
  if (!write || todo.length === 0) return result;

  const writer = db.bulkWriter();
  writer.onWriteError(() => false); // no retries: a failed precondition means the rider changed it
  const writes = todo.map((doc) =>
    writer.update(doc.ref, { visibility: 'public' }, { lastUpdateTime: doc.updateTime })
      .then(() => { result.written += 1; })
      .catch((e) => { result.skipped.push(doc.id); log(`  skipped ${doc.id}: ${e.code || e.message}`); }));
  await writer.close(); // flushes; awaiting the writes first would hang below 20 ops
  await Promise.all(writes);
  return result;
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
  if (!opts.project) fail('Pass --project=<firebase project id>.');

  const emulator = process.env.FIRESTORE_EMULATOR_HOST;
  if (!emulator) {
    const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!keyPath) fail('Set GOOGLE_APPLICATION_CREDENTIALS to the service-account key.');
    let key;
    try { key = JSON.parse(fs.readFileSync(keyPath, 'utf8')); } catch (e) { fail(`Cannot read the key: ${e.message}`); }
    if (key.project_id !== opts.project) {
      fail(`The key is for project '${key.project_id}', not '${opts.project}'. Refusing to run.`);
    }
  }

  const admin = require('firebase-admin');
  const app = admin.initializeApp({ projectId: opts.project });
  const db = admin.firestore(app);
  console.log(`  Project: ${opts.project}${emulator ? ` (emulator ${emulator})` : ''}`);

  const dry = await backfill(db);
  console.log(`  Scanned ${dry.scanned} profiles; ${dry.missing} have no visibility.`);
  if (dry.sample.length) console.log(`  First uids: ${dry.sample.join(', ')}`);
  if (!opts.confirmed || dry.missing === 0) {
    if (!opts.confirmed) console.log('  Dry run: nothing changed. Re-run with --yes-i-really-mean-it to write.');
    return;
  }
  await confirm(opts.nonInteractive);

  const r = await backfill(db, { write: true, log: console.warn });
  console.log(`  Wrote ${r.written}; skipped ${r.skipped.length} (changed during the run).`);
  console.log('  Done. A second run should report 0 profiles with no visibility.');
}

if (require.main === module) {
  main().catch((e) => fail(e.stack || String(e)));
}

module.exports = { needsBackfill, parseArgs, backfill };
