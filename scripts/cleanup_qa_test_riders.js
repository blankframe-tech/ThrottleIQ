#!/usr/bin/env node
'use strict';

/**
 * cleanup_qa_test_riders.js — removes everything created by
 * seed_qa_test_riders.js: the fake Auth accounts, their profiles/bikes/rides,
 * their shared-feed rides, and their forum posts.
 *
 * Finds the batch by the same two markers the seed script stamps on
 * everything: `qaSeed: true` on every Firestore document, and the
 * `@qa-seed.invalid` email domain on every Auth account.
 *
 * Forum posts are the one exception to "just query qaSeed == true": Firestore
 * requires a composite index for any `collectionGroup('posts').where(...)`
 * query, and this project doesn't have one for `posts`/`qaSeed` (found
 * running this against a real canary batch — FAILED_PRECONDITION). Instead
 * this queries `forums/{forumId}/posts` directly for every forum id the seed
 * script could ever have written to (`qa_seed_catalog.allSeedableForumIds()`
 * — deterministic, since BIKE_CATALOG/TOPICS are its only inputs), which is a
 * plain single-field query and needs no index.
 *
 * Deliberately does NOT delete forum documents themselves, even ones the seed
 * script created (`qaSeedCreatedForum: true`) — a real rider may have posted
 * into one since. It does decrement each forum's postCount by the number of
 * seeded posts removed from it, since that counter would otherwise be wrong.
 *
 * ---------------------------------------------------------------------------
 * This permanently deletes data. There is no undo.
 * ---------------------------------------------------------------------------
 *
 * Safety design (same posture as reset_beta_data.js):
 *   - --dry-run is the DEFAULT. Counts only, deletes nothing.
 *   - Requires FIREBASE_PROJECT_ID=throttleiqfb and GOOGLE_APPLICATION_CREDENTIALS.
 *   - Requires --yes-i-really-mean-it, plus a typed confirmation phrase.
 *   - Idempotent: re-running finds fewer (eventually zero) tagged documents.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=throttleiqfb node cleanup_qa_test_riders.js
 *   FIREBASE_PROJECT_ID=throttleiqfb node cleanup_qa_test_riders.js --yes-i-really-mean-it
 */

let admin;

const { QA_EMAIL_DOMAIN, allSeedableForumIds } = require('./qa_seed_catalog');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const CONFIRMATION_PHRASE = 'DELETE QA SEED DATA';
const BATCH_COMMIT_SIZE = 400;
const AUTH_DELETE_CHUNK = 1000;
const WHERE_IN_CHUNK = 30;

const log = (...args) => console.log(...args);
const warn = (...args) => console.warn(...args);

function fail(message) {
  console.error(`\n  ERROR  ${message}\n`);
  process.exit(1);
}

function rule(char = '-') {
  log(char.repeat(66));
}

function parseArgs(argv) {
  const opts = { confirmed: false, help: false, nonInteractive: false };
  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg === '--yes-i-really-mean-it') opts.confirmed = true;
    else if (arg === '--dry-run') {
      // explicit form of the default
    } else if (arg === '--non-interactive') opts.nonInteractive = true;
    else throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
  }
  return opts;
}

const USAGE = `
cleanup_qa_test_riders.js — remove all QA test riders created by
seed_qa_test_riders.js (matched by qaSeed: true and the @${QA_EMAIL_DOMAIN}
email domain).

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node cleanup_qa_test_riders.js
      Dry run (the default). Counts everything, deletes nothing.

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node cleanup_qa_test_riders.js --yes-i-really-mean-it
      Actually delete. THIS CANNOT BE UNDONE.

Flags:
  --dry-run                 Count only (default).
  --yes-i-really-mean-it    Required to delete anything.
  --non-interactive         Skip the typed confirmation prompt (scripted/CI use).
  --help                    This message.
`;

function assertProjectEnv() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) fail(`FIREBASE_PROJECT_ID is not set. Set it to '${EXPECTED_PROJECT_ID}'.`);
  if (projectId !== EXPECTED_PROJECT_ID) fail(`FIREBASE_PROJECT_ID is '${projectId}', not '${EXPECTED_PROJECT_ID}'. Refusing to run.`);
  return projectId;
}

function assertResolvedProject(app) {
  const resolved = (app.options && app.options.projectId) ||
    process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
  if (resolved !== EXPECTED_PROJECT_ID) {
    fail(`The supplied credentials resolve to project '${resolved}', not '${EXPECTED_PROJECT_ID}'. Refusing to run.`);
  }
}

async function confirmRealDelete({ nonInteractive }) {
  if (nonInteractive) {
    warn('  NOTE   --non-interactive: skipping the typed confirmation prompt.\n');
    return;
  }
  const readline = require('node:readline/promises');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  let typed;
  try {
    typed = await rl.question(`  Type '${CONFIRMATION_PHRASE}' to proceed, anything else to abort: `);
  } finally {
    rl.close();
  }
  if (typed.trim() !== CONFIRMATION_PHRASE) fail('Confirmation phrase did not match. Nothing was deleted.');
  log('');
}

class BatchDeleter {
  constructor(db, { enabled }) {
    this.db = db;
    this.enabled = enabled;
    this.batch = enabled ? db.batch() : null;
    this.pending = 0;
    this.committed = 0;
  }
  delete(ref) {
    if (!this.enabled) { this.committed += 1; return; }
    this.batch.delete(ref);
    this.pending += 1;
    if (this.pending >= BATCH_COMMIT_SIZE) return this.flush();
  }
  update(ref, data) {
    if (!this.enabled) return;
    this.batch.update(ref, data);
    this.pending += 1;
    if (this.pending >= BATCH_COMMIT_SIZE) return this.flush();
  }
  async flush() {
    if (!this.enabled || this.pending === 0) return;
    await this.batch.commit();
    this.committed += this.pending;
    this.pending = 0;
    this.batch = this.db.batch();
  }
  get total() { return this.committed + this.pending; }
}

/** Deletes a doc and everything under it (subcollections found at runtime). */
async function purgeDocRecursive(docRef, deleter) {
  const subcollections = await docRef.listCollections();
  for (const sub of subcollections) {
    const docs = await sub.listDocuments();
    for (const d of docs) await purgeDocRecursive(d, deleter);
  }
  await deleter.delete(docRef);
}

async function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (err) {
    fail(err.message);
  }
  if (opts.help) { log(USAGE); return; }

  const projectId = assertProjectEnv();
  try {
    admin = require('firebase-admin');
  } catch (err) {
    fail("Cannot load 'firebase-admin'.\n         Run `npm install` in the scripts/ directory first.");
  }
  const app = admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId });
  assertResolvedProject(app);
  const db = admin.firestore();
  const auth = admin.auth();

  const deleting = opts.confirmed;

  rule('=');
  log(`  ThrottleIQ QA test rider cleanup — project '${projectId}'`);
  log(deleting ? '  MODE: DELETING FOR REAL. This is irreversible.' : '  MODE: dry run (default). Nothing will be modified.');
  rule('=');
  log('');

  if (deleting) {
    await confirmRealDelete({ nonInteractive: opts.nonInteractive });
    log('  Starting in 5 seconds. Ctrl-C now if this is not what you meant.');
    log('');
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  // ---- users tree (profile + bikes + rides), matched by qaSeed == true ----
  const userDeleter = new BatchDeleter(db, { enabled: deleting });
  const usersSnap = await db.collection('users').where('qaSeed', '==', true).get();
  const uids = usersSnap.docs.map((d) => d.id);
  for (const doc of usersSnap.docs) await purgeDocRecursive(doc.ref, userDeleter);
  await userDeleter.flush();

  // ---- usernames reserved by those uids ----
  const usernameDeleter = new BatchDeleter(db, { enabled: deleting });
  let usernamesFound = 0;
  for (let i = 0; i < uids.length; i += WHERE_IN_CHUNK) {
    const chunk = uids.slice(i, i + WHERE_IN_CHUNK);
    if (chunk.length === 0) continue;
    const snap = await db.collection('usernames').where('uid', 'in', chunk).get();
    usernamesFound += snap.size;
    for (const doc of snap.docs) usernameDeleter.delete(doc.ref);
  }
  await usernameDeleter.flush();

  // ---- shared/public rides feed, matched by qaSeed == true ----
  const rideDeleter = new BatchDeleter(db, { enabled: deleting });
  const ridesSnap = await db.collection('rides').where('qaSeed', '==', true).get();
  for (const doc of ridesSnap.docs) await purgeDocRecursive(doc.ref, rideDeleter);
  await rideDeleter.flush();

  // ---- forum posts, matched by qaSeed == true, one forum at a time ----
  // See the file header: this deliberately isn't a collectionGroup query.
  const postDeleter = new BatchDeleter(db, { enabled: deleting });
  const forumDecrements = new Map(); // forumRef.path -> count
  for (const forumId of allSeedableForumIds()) {
    const forumRef = db.collection('forums').doc(forumId);
    const postsSnap = await forumRef.collection('posts').where('qaSeed', '==', true).get();
    for (const doc of postsSnap.docs) {
      await purgeDocRecursive(doc.ref, postDeleter);
      forumDecrements.set(forumRef.path, (forumDecrements.get(forumRef.path) || 0) + 1);
    }
  }
  await postDeleter.flush();

  if (deleting && forumDecrements.size > 0) {
    const forumBatch = db.batch();
    for (const [path, count] of forumDecrements) {
      forumBatch.update(db.doc(path), { postCount: admin.firestore.FieldValue.increment(-count) });
    }
    await forumBatch.commit();
  }

  // ---- Auth accounts, matched by @qa-seed.invalid email domain ----
  const allUsers = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    allUsers.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  const qaAuthUids = allUsers
    .filter((u) => (u.email || '').toLowerCase().endsWith(`@${QA_EMAIL_DOMAIN}`))
    .map((u) => u.uid);

  let authDeleted = 0, authFailed = 0;
  if (deleting) {
    for (let i = 0; i < qaAuthUids.length; i += AUTH_DELETE_CHUNK) {
      const chunk = qaAuthUids.slice(i, i + AUTH_DELETE_CHUNK);
      const result = await auth.deleteUsers(chunk);
      authDeleted += result.successCount;
      authFailed += result.failureCount;
    }
  }

  log('');
  rule('=');
  log(deleting ? '  SUMMARY — deleted' : '  SUMMARY — dry run, nothing was changed');
  rule('=');
  log(`  users (+ bikes/rides subtrees)  ${String(userDeleter.total).padStart(6)}`);
  log(`  usernames                       ${String(usernamesFound).padStart(6)}`);
  log(`  shared feed rides               ${String(rideDeleter.total).padStart(6)}`);
  log(`  forum posts                     ${String(postDeleter.total).padStart(6)}`);
  log(`  forums with postCount adjusted  ${String(forumDecrements.size).padStart(6)}`);
  log(`  auth accounts                   ${String(deleting ? authDeleted : qaAuthUids.length).padStart(6)}`);
  if (authFailed) warn(`  auth accounts FAILED            ${String(authFailed).padStart(6)}`);
  rule('=');
  log('');
  log(deleting ? '  Done.' : '  This was a DRY RUN — nothing was touched. Re-run with --yes-i-really-mean-it to delete.');
  log('');
}

main().catch((err) => {
  console.error('\n  UNEXPECTED FAILURE');
  console.error(err && err.stack ? err.stack : err);
  process.exit(1);
});
