#!/usr/bin/env node
'use strict';

/**
 * backfill_vote_uid.js — one-off: add `uid` to old vote docs.
 *
 * Vote docs (`rides/{rideId}/votes/{uid}` and
 * `forums/{forumId}/posts/{postId}/votes/{uid}`) used to hold only `{value}`;
 * the voter was only the doc id. The app now writes `{value, uid}` so account
 * erasure can find a rider's votes with
 * `collectionGroup('votes').where('uid', '==', uid)`. This sets `uid` = doc id
 * on every vote doc that lacks it. Nothing else is touched.
 *
 * Run it AFTER the rules that accept `uid` on a vote are deployed. Build-29
 * clients overwrite a vote as `{value}` when the rider flips it, which drops
 * the backfilled `uid`, so run it again once config/app.minBuild passes the
 * release that writes `uid`.
 *
 * Safety:
 *   - --dry-run is the DEFAULT: reads only, prints counts.
 *   - The service-account key's project_id must be 'throttleiqfb'.
 *   - Writes need --yes-i-really-mean-it plus a typed confirmation.
 *   - Idempotent: docs that already have `uid` are skipped, so a second run
 *     finds nothing to do. A vote deleted mid-run fails its batch; re-run.
 *
 * Usage (from scripts/):
 *   node oneoff/backfill_vote_uid.js --service-account=/path/to/key.json
 *   node oneoff/backfill_vote_uid.js --service-account=/path/to/key.json --yes-i-really-mean-it
 */

const fs = require('node:fs');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const CONFIRMATION_PHRASE = 'BACKFILL VOTES';
const PAGE = 400;
const BATCH = 400;

/** Only the two vote collections the app writes. */
const VOTE_PATH = /^(rides\/[^/]+|forums\/[^/]+\/posts\/[^/]+)\/votes\/[^/]+$/;

function fail(msg) { console.error(`\n  ERROR  ${msg}\n`); process.exit(1); }

/** The uid to write on the vote doc at `path`, or null when it needs nothing. */
function uidToBackfill(path, data) {
  if (!VOTE_PATH.test(path) || 'uid' in data) return null;
  return path.slice(path.lastIndexOf('/') + 1);
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

  const admin = require('firebase-admin');
  const app = admin.initializeApp({ credential: admin.credential.cert(key), projectId: EXPECTED_PROJECT_ID });
  const db = admin.firestore(app);
  const { FieldPath } = admin.firestore;

  const todo = [];
  let scanned = 0;
  let last = null;
  for (;;) {
    let q = db.collectionGroup('votes').orderBy(FieldPath.documentId()).limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    scanned += snap.size;
    for (const doc of snap.docs) {
      const uid = uidToBackfill(doc.ref.path, doc.data());
      if (uid) todo.push({ ref: doc.ref, uid });
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }

  console.log(`  Scanned ${scanned} vote docs; ${todo.length} lack \`uid\`.`);
  if (!opts.confirmed) {
    console.log('  Dry run: nothing changed. Re-run with --yes-i-really-mean-it to backfill them.');
    return;
  }
  if (todo.length === 0) return;
  await confirm(opts.nonInteractive);

  for (let i = 0; i < todo.length; i += BATCH) {
    const batch = db.batch();
    for (const { ref, uid } of todo.slice(i, i + BATCH)) batch.update(ref, { uid });
    await batch.commit();
    console.log(`  Backfilled ${Math.min(i + BATCH, todo.length)}/${todo.length}`);
  }
  console.log('  Done. A second run should report 0 vote docs lacking `uid`.');
}

if (require.main === module) {
  main().catch((e) => fail(e.stack || String(e)));
}

module.exports = { uidToBackfill, parseArgs };
