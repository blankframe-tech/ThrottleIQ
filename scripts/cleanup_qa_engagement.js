#!/usr/bin/env node
'use strict';

/**
 * cleanup_qa_engagement.js — removes QA-seed engagement left on the live feed,
 * which cleanup_qa_test_riders.js does not touch (issues §79, §80).
 *
 *   §79  Comments (and any legacy likes) that `qaSeed` accounts left on OTHER
 *        riders' shared rides. Each parent's `comments` tally is decremented by
 *        the number removed, so the tallies the security rules check stay true.
 *   §80  The dead `likes` integer still sitting on `qashare_*` shared rides.
 *        Nothing reads it (votes are the only engagement model). Removed with
 *        FieldValue.delete().
 *
 * How it finds things without a composite index: for each shared ride
 * (`rides/{id}`) it runs a single-field `where('qaSeed', '==', true)` query on
 * that ride's own `comments` and `likes` subcollections. A collectionGroup
 * sweep would need a collection-group index this project does not have (the same
 * FAILED_PRECONDITION cleanup_qa_test_riders.js documents for forum posts).
 *
 * ---------------------------------------------------------------------------
 * This permanently deletes data. There is no undo.
 * ---------------------------------------------------------------------------
 *
 * Safety design (same posture as cleanup_qa_test_riders.js):
 *   - --dry-run is the DEFAULT. Reads only; prints exactly what it would change.
 *   - Requires FIREBASE_PROJECT_ID=throttleiqfb and application-default
 *     credentials that resolve to that same project.
 *   - Requires --yes-i-really-mean-it, plus a typed confirmation phrase.
 *   - Idempotent: a second run finds nothing.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=throttleiqfb node cleanup_qa_engagement.js
 *   FIREBASE_PROJECT_ID=throttleiqfb node cleanup_qa_engagement.js --yes-i-really-mean-it
 */

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const CONFIRMATION_PHRASE = 'DELETE QA ENGAGEMENT';
const SUBCOLLECTIONS = ['comments', 'likes'];
const RIDE_PAGE = 300;

const log = (...a) => console.log(...a);
const warn = (...a) => console.warn(...a);
function fail(msg) { console.error(`\n  ERROR  ${msg}\n`); process.exit(1); }

function parseArgs(argv) {
  const opts = { confirmed: false, help: false, nonInteractive: false };
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg === '--yes-i-really-mean-it') opts.confirmed = true;
    else if (arg === '--dry-run') { /* the default */ }
    else if (arg === '--non-interactive') opts.nonInteractive = true;
    else throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
  }
  return opts;
}

const USAGE = `
cleanup_qa_engagement.js — remove QA-seed comments/likes on shared rides and the
dead 'likes' field on qashare_* rides (issues §79, §80).

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node cleanup_qa_engagement.js
      Dry run (default). Reads only.
  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node cleanup_qa_engagement.js --yes-i-really-mean-it
      Actually change data. THIS CANNOT BE UNDONE.
`;

function assertProjectEnv() {
  const p = process.env.FIREBASE_PROJECT_ID;
  if (!p) fail(`FIREBASE_PROJECT_ID is not set. Set it to '${EXPECTED_PROJECT_ID}'.`);
  if (p !== EXPECTED_PROJECT_ID) fail(`FIREBASE_PROJECT_ID is '${p}', not '${EXPECTED_PROJECT_ID}'. Refusing to run.`);
  return p;
}

function assertResolvedProject(app) {
  const resolved = (app.options && app.options.projectId) ||
    process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
  if (resolved !== EXPECTED_PROJECT_ID) {
    fail(`Credentials resolve to project '${resolved}', not '${EXPECTED_PROJECT_ID}'. Refusing to run.`);
  }
}

async function confirmRealChange({ nonInteractive }) {
  if (nonInteractive) { warn('  NOTE   --non-interactive: skipping the typed confirmation prompt.\n'); return; }
  const readline = require('node:readline/promises');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  let typed;
  try { typed = await rl.question(`  Type '${CONFIRMATION_PHRASE}' to proceed, anything else to abort: `); }
  finally { rl.close(); }
  if (typed.trim() !== CONFIRMATION_PHRASE) fail('Confirmation phrase did not match. Nothing was changed.');
  log('');
}

/** Pure: what to do about one shared ride, given what was found on it. Exported for tests. */
function planForRide({ rideId, rideData, seeded }) {
  const removals = [];
  for (const sub of SUBCOLLECTIONS) {
    for (const id of seeded[sub] || []) removals.push({ sub, id });
  }
  const removedComments = (seeded.comments || []).length;
  const parentTally = typeof rideData.comments === 'number' ? rideData.comments : 0;
  const update = {};
  if (removedComments > 0) update.comments = Math.max(0, parentTally - removedComments);
  const clearDeadLikes = rideId.startsWith('qashare_') && Object.prototype.hasOwnProperty.call(rideData, 'likes');
  return { removals, update, clearDeadLikes };
}

async function main() {
  let opts;
  try { opts = parseArgs(process.argv.slice(2)); } catch (e) { fail(e.message); }
  if (opts.help) { log(USAGE); return; }
  const projectId = assertProjectEnv();
  const admin = require('firebase-admin');
  const app = admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId });
  assertResolvedProject(app);
  const db = admin.firestore();
  const { FieldValue } = admin.firestore;
  const live = opts.confirmed;

  log(`\ncleanup_qa_engagement — project ${projectId} — ${live ? 'LIVE (will change data)' : 'DRY RUN (reads only)'}\n`);

  const plans = [];
  let rides = 0;
  let last = null;
  for (;;) {
    let q = db.collection('rides').orderBy('__name__').limit(RIDE_PAGE);
    if (last) q = q.startAfter(last);
    const page = await q.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      rides++;
      const seeded = {};
      for (const sub of SUBCOLLECTIONS) {
        const snap = await doc.ref.collection(sub).where('qaSeed', '==', true).get();
        seeded[sub] = snap.docs.map((d) => d.id);
      }
      const plan = planForRide({ rideId: doc.id, rideData: doc.data(), seeded });
      if (plan.removals.length || plan.clearDeadLikes) plans.push({ ref: doc.ref, id: doc.id, ownerIsSeed: doc.data().qaSeed === true, plan });
    }
    last = page.docs[page.docs.length - 1];
  }

  let nComments = 0, nLikes = 0, nDead = 0, onRealPosts = 0;
  for (const p of plans) {
    const c = p.plan.removals.filter((r) => r.sub === 'comments').length;
    const l = p.plan.removals.filter((r) => r.sub === 'likes').length;
    nComments += c; nLikes += l; if (p.plan.clearDeadLikes) nDead++;
    if (!p.ownerIsSeed && (c || l)) onRealPosts += c + l;
    if (c || l) log(`  ${p.ownerIsSeed ? 'seed ' : 'REAL '} ride ${p.id}: remove ${c} comment(s), ${l} like(s)` +
      (p.plan.update.comments !== undefined ? `; comments tally -> ${p.plan.update.comments}` : ''));
  }
  log(`\n  Shared rides scanned:                         ${rides}`);
  log(`  QA-seed comments to remove:                   ${nComments}`);
  log(`  QA-seed likes to remove:                      ${nLikes}`);
  log(`  ...of which sit on REAL (non-seed) rides:     ${onRealPosts}`);
  log(`  qashare_* rides whose dead 'likes' to clear:  ${nDead}\n`);

  if (!live) { log('  Dry run — nothing changed. Re-run with --yes-i-really-mean-it to apply.\n'); return; }
  if (!plans.length) { log('  Nothing to do.\n'); return; }
  await confirmRealChange(opts);

  let batch = db.batch(); let ops = 0;
  const flush = async () => { if (ops) { await batch.commit(); batch = db.batch(); ops = 0; } };
  for (const p of plans) {
    for (const r of p.plan.removals) { batch.delete(p.ref.collection(r.sub).doc(r.id)); if (++ops >= 400) await flush(); }
    const update = { ...p.plan.update };
    if (p.plan.clearDeadLikes) update.likes = FieldValue.delete();
    if (Object.keys(update).length) { batch.update(p.ref, update); if (++ops >= 400) await flush(); }
  }
  await flush();
  log('  Done.\n');
}

if (require.main === module) {
  main().catch((e) => { console.error(e); process.exit(1); });
}

module.exports = { planForRide };
