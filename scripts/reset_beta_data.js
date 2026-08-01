#!/usr/bin/env node
'use strict';

/**
 * reset_beta_data.js — wipe all ThrottleIQ user content so beta testers start
 * from an empty slate.
 *
 * Deletes every document in the app's Firestore collections (recursively,
 * including subcollections) and then every Firebase Authentication user.
 *
 * ---------------------------------------------------------------------------
 * THIS IS IRREVERSIBLE. There is no undo, no soft delete, and no export step.
 * ---------------------------------------------------------------------------
 *
 * Safety design:
 *   - --dry-run is the DEFAULT. The script never writes unless you pass
 *     --yes-i-really-mean-it explicitly.
 *   - Refuses to run unless the FIREBASE_PROJECT_ID env var is exactly
 *     'throttleiqfb', and refuses again if the credentials the Admin SDK
 *     actually resolved point at a different project.
 *   - Idempotent and resumable: it deletes what is there. If it is interrupted
 *     (or rate-limited, or you Ctrl-C it), run it again — already-deleted docs
 *     simply are not found the second time.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=throttleiqfb node reset_beta_data.js
 *   FIREBASE_PROJECT_ID=throttleiqfb node reset_beta_data.js --yes-i-really-mean-it
 *
 * Flags:
 *   --dry-run                 Count only, change nothing. (default)
 *   --yes-i-really-mean-it    Actually delete. Required for any write.
 *   --only=a,b,c              Restrict to these top-level collections (plus
 *                             'auth' for Firebase Auth users). Useful for
 *                             resuming a partial run.
 *   --skip-auth               Leave Firebase Auth accounts alone.
 *   --help
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS to point at a service-account JSON
 * key with Firebase Admin rights. See scripts/README.md.
 */

// firebase-admin is required lazily inside main(), *after* --help and the
// project guard have had their say. That way `--help` and a mis-set
// FIREBASE_PROJECT_ID both give a useful message on a machine where
// `npm install` has not been run yet, instead of a module-not-found stack.
let admin;

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/** The only project this script will ever touch. */
const EXPECTED_PROJECT_ID = 'throttleiqfb';

/**
 * Firestore's write batch hard limit is 500 operations. Commit at 400 to leave
 * headroom and to keep each commit small enough to retry cheaply.
 */
const BATCH_COMMIT_SIZE = 400;

/** Firebase Auth deleteUsers() accepts at most 1000 uids per call. */
const AUTH_DELETE_CHUNK = 1000;

/**
 * Top-level Firestore collections, verified against `firestore.rules` and the
 * repositories under `app/lib/**` rather than assumed.
 *
 * Subcollections are NOT listed here on purpose — the walker discovers them at
 * runtime with `DocumentReference.listCollections()`, so nothing is missed if a
 * feature adds one. The comments below record what was found at the time of
 * writing, as documentation only.
 *
 * Two naming corrections worth knowing, because the obvious guesses are wrong:
 *   - There is NO `shared_rides` collection. Shared/public rides live in the
 *     TOP-LEVEL `rides` collection (RideShareRepository writes
 *     `rides/{rideId}`), which is a different thing from the per-user
 *     `users/{uid}/rides` backup of ride summaries. Both are wiped.
 *   - There is NO top-level `notifications` collection. In-app notifications
 *     are `users/{uid}/notifications` (NotificationRepository), so they are
 *     removed as part of the users tree.
 */
const COLLECTIONS = [
  {
    name: 'users',
    note:
      'Rider accounts. Subcollections seen in code: rides (which itself nests ' +
      'rides/{rideId}/track/{chunkId} — the chunked GPS trail), bikes, ' +
      'maintenance, emergencyContacts, routes, falseCrashPositives, ' +
      'earnedBadges, notifications, challengeProgress.',
  },
  {
    name: 'rides',
    note:
      'Shared/public ride feed (top-level, NOT users/{uid}/rides). ' +
      'Subcollections: likes, votes, comments.',
  },
  { name: 'forums', note: 'Forum threads. Subcollections: posts -> (votes, replies).' },
  { name: 'forum_follows', note: 'Forum follow edges.' },
  { name: 'follows', note: 'Rider follow graph, `follows/{follower}_{followee}`.' },
  { name: 'usernames', note: '@handle reservations -> uid. Must go or handles stay taken.' },
  { name: 'places', note: 'Rider-contributed POIs.' },
  { name: 'reviews', note: 'Place reviews.' },
  { name: 'liveSessions', note: 'Live-share sessions keyed by share token.' },
  { name: 'crashNotifications', note: 'Crash alert records.' },
  {
    name: 'groupRides',
    note:
      'Group rides. Subcollections: invitations, memberLocations. ' +
      'Referenced by GroupRideRepository but has no rule in firestore.rules, ' +
      'so it may well be empty — deleted defensively, costs nothing if so.',
  },
  {
    name: 'challenges',
    note:
      'Challenge definitions (ChallengeRepository). Also has no rule in ' +
      'firestore.rules. Per-rider progress lives at ' +
      'users/{uid}/challengeProgress and goes with the users tree.',
  },
];

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const opts = {
    confirmed: false,
    skipAuth: false,
    only: null,
    help: false,
  };

  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') {
      opts.help = true;
    } else if (arg === '--yes-i-really-mean-it') {
      opts.confirmed = true;
    } else if (arg === '--dry-run') {
      // Explicit form of the default. Accepted so the safe invocation can be
      // written out in full in a runbook.
    } else if (arg === '--skip-auth') {
      opts.skipAuth = true;
    } else if (arg.startsWith('--only=')) {
      opts.only = arg
        .slice('--only='.length)
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
    } else {
      throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
    }
  }

  if (opts.only && opts.only.length === 0) {
    throw new Error('--only= was given with no collection names.');
  }

  return opts;
}

const USAGE = `
reset_beta_data.js — irreversibly wipe all ThrottleIQ beta data.

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node reset_beta_data.js
      Dry run (the default). Counts everything, deletes nothing.

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node reset_beta_data.js --yes-i-really-mean-it
      Actually delete. THIS CANNOT BE UNDONE.

Flags:
  --dry-run                 Count only (default).
  --yes-i-really-mean-it    Required to delete anything.
  --only=a,b,c              Only these top-level collections. Use 'auth' for
                            Firebase Auth users. Handy for resuming.
  --skip-auth               Do not touch Firebase Auth accounts.
  --help                    This message.

Environment:
  FIREBASE_PROJECT_ID              Must equal '${EXPECTED_PROJECT_ID}'.
  GOOGLE_APPLICATION_CREDENTIALS   Path to a service-account JSON key.

Known top-level collections:
${COLLECTIONS.map((c) => `  - ${c.name}`).join('\n')}
  - auth  (Firebase Authentication users)
`;

// ---------------------------------------------------------------------------
// Small output helpers
// ---------------------------------------------------------------------------

const log = (...args) => console.log(...args);
const warn = (...args) => console.warn(...args);

function fail(message) {
  console.error(`\n  ERROR  ${message}\n`);
  process.exit(1);
}

function rule(char = '-') {
  log(char.repeat(66));
}

function plural(n, one, many) {
  return `${n} ${n === 1 ? one : many}`;
}

// ---------------------------------------------------------------------------
// Batched deleter
//
// Accumulates delete operations and flushes at BATCH_COMMIT_SIZE. Because each
// commit is independent, a crash mid-run just leaves fewer documents for the
// next run to find — which is exactly what makes this resumable.
// ---------------------------------------------------------------------------

class BatchDeleter {
  constructor(db, { enabled }) {
    this.db = db;
    this.enabled = enabled; // false in dry-run: count, never write
    this.batch = enabled ? db.batch() : null;
    this.pending = 0;
    this.committed = 0;
    this.commits = 0;
  }

  async delete(ref) {
    if (!this.enabled) {
      this.committed += 1;
      return;
    }
    this.batch.delete(ref);
    this.pending += 1;
    if (this.pending >= BATCH_COMMIT_SIZE) {
      await this.flush();
    }
  }

  async flush() {
    if (!this.enabled || this.pending === 0) return;
    await this.batch.commit();
    this.committed += this.pending;
    this.commits += 1;
    this.pending = 0;
    this.batch = this.db.batch();
  }

  get total() {
    return this.committed + this.pending;
  }
}

// ---------------------------------------------------------------------------
// Recursive Firestore walk
//
// listDocuments() rather than get(): it also returns "phantom" document refs —
// ids that hold subcollections but have no document of their own. A plain
// query would not see those, and their subcollections would survive the wipe
// and quietly reappear in collection-group queries.
// ---------------------------------------------------------------------------

/**
 * Depth-first: purge everything under a document, then the document itself.
 * @returns {Promise<number>} documents accounted for at and below this ref
 */
async function purgeDocument(docRef, deleter, stats, depth) {
  let count = 0;
  const subcollections = await docRef.listCollections();
  for (const sub of subcollections) {
    count += await purgeCollection(sub, deleter, stats, depth + 1);
  }
  await deleter.delete(docRef);
  count += 1;
  return count;
}

/**
 * @returns {Promise<number>} documents accounted for in this collection subtree
 */
async function purgeCollection(collRef, deleter, stats, depth = 0) {
  const docRefs = await collRef.listDocuments();
  let count = 0;

  for (const docRef of docRefs) {
    count += await purgeDocument(docRef, deleter, stats, depth);

    // A heartbeat on long runs so an operator can see it is not wedged.
    if (deleter.enabled && deleter.total - stats.lastReport >= 1000) {
      stats.lastReport = deleter.total;
      log(`    … ${deleter.total} documents deleted so far`);
    }
  }

  // Record the shape of what was found, one line per distinct subcollection
  // path, so the dry-run output is actually informative about nesting.
  if (depth > 0 && docRefs.length > 0) {
    const key = `${collRef.parent ? '…/' : ''}${collRef.id}`;
    stats.subcollections[key] = (stats.subcollections[key] || 0) + docRefs.length;
  }

  return count;
}

// ---------------------------------------------------------------------------
// Firebase Auth
// ---------------------------------------------------------------------------

async function listAllAuthUsers(auth) {
  const uids = [];
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) uids.push(user.uid);
    pageToken = page.pageToken;
  } while (pageToken);
  return uids;
}

async function purgeAuthUsers(auth, { enabled }) {
  const uids = await listAllAuthUsers(auth);
  if (!enabled || uids.length === 0) {
    return { found: uids.length, deleted: 0, failed: 0 };
  }

  let deleted = 0;
  let failed = 0;
  for (let i = 0; i < uids.length; i += AUTH_DELETE_CHUNK) {
    const chunk = uids.slice(i, i + AUTH_DELETE_CHUNK);
    const result = await auth.deleteUsers(chunk);
    deleted += result.successCount;
    failed += result.failureCount;
    for (const err of result.errors) {
      warn(`    ! could not delete ${chunk[err.index]}: ${err.error.message}`);
    }
    log(`    … ${deleted}/${uids.length} auth users deleted`);
  }
  return { found: uids.length, deleted, failed };
}

// ---------------------------------------------------------------------------
// Guards
// ---------------------------------------------------------------------------

function assertProjectEnv() {
  const projectId = process.env.FIREBASE_PROJECT_ID;

  if (!projectId) {
    fail(
      'FIREBASE_PROJECT_ID is not set.\n' +
        `         This script refuses to run without it, so it can never be pointed\n` +
        `         at the wrong project by accident. Set it to '${EXPECTED_PROJECT_ID}'.`
    );
  }

  if (projectId !== EXPECTED_PROJECT_ID) {
    fail(
      `FIREBASE_PROJECT_ID is '${projectId}', not '${EXPECTED_PROJECT_ID}'.\n` +
        '         Refusing to run. This script only ever wipes the ThrottleIQ beta project.'
    );
  }

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    warn(
      '  NOTE   GOOGLE_APPLICATION_CREDENTIALS is not set — falling back to whatever\n' +
        '         application-default credentials this machine has. See scripts/README.md.\n'
    );
  }

  return projectId;
}

/**
 * Second guard, after the SDK has resolved credentials: the env var says one
 * thing, but the service-account key is what actually decides which project
 * gets written to. They must agree.
 */
function assertResolvedProject(app) {
  const resolved =
    (app.options && app.options.projectId) ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT;

  if (!resolved) {
    fail(
      'Could not determine which project the credentials belong to.\n' +
        '         Refusing to run rather than guess.'
    );
  }

  if (resolved !== EXPECTED_PROJECT_ID) {
    fail(
      `The supplied credentials resolve to project '${resolved}', not '${EXPECTED_PROJECT_ID}'.\n` +
        '         GOOGLE_APPLICATION_CREDENTIALS is probably pointing at the wrong\n' +
        '         service-account key. Refusing to run.'
    );
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (err) {
    fail(err.message);
  }

  if (opts.help) {
    log(USAGE);
    return;
  }

  const projectId = assertProjectEnv();

  try {
    admin = require('firebase-admin');
  } catch (err) {
    fail(
      "Cannot load 'firebase-admin'.\n" +
        '         Run `npm install` in the scripts/ directory first. See scripts/README.md.'
    );
  }

  const app = admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
  assertResolvedProject(app);

  const db = admin.firestore();
  const auth = admin.auth();

  const deleting = opts.confirmed;

  let targets = COLLECTIONS;
  let doAuth = !opts.skipAuth;
  if (opts.only) {
    const wanted = new Set(opts.only);
    const known = new Set([...COLLECTIONS.map((c) => c.name), 'auth']);
    for (const name of wanted) {
      if (!known.has(name)) {
        fail(
          `--only names an unknown collection: '${name}'.\n` +
            `         Known: ${[...known].join(', ')}`
        );
      }
    }
    targets = COLLECTIONS.filter((c) => wanted.has(c.name));
    doAuth = doAuth && wanted.has('auth');
  }

  rule('=');
  log(`  ThrottleIQ beta data reset — project '${projectId}'`);
  log(
    deleting
      ? '  MODE: DELETING FOR REAL. This is irreversible.'
      : '  MODE: dry run (default). Nothing will be modified.'
  );
  rule('=');
  log('');

  if (deleting) {
    log('  Starting in 5 seconds. Ctrl-C now if this is not what you meant.');
    log('  (Interrupting is safe — the script is resumable; just run it again.)');
    log('');
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  const results = [];
  const started = Date.now();

  for (const collection of targets) {
    const deleter = new BatchDeleter(db, { enabled: deleting });
    const stats = { subcollections: {}, lastReport: 0 };

    process.stdout.write(`  ${collection.name} … `);
    let count;
    try {
      count = await purgeCollection(db.collection(collection.name), deleter, stats);
      await deleter.flush();
    } catch (err) {
      log('FAILED');
      warn(`    ! ${err.message}`);
      warn('    ! Continuing with the next collection. Re-run to retry this one.');
      results.push({ name: collection.name, count: null, error: err.message });
      continue;
    }

    log(
      deleting
        ? `${plural(count, 'document', 'documents')} deleted ` +
            `(${plural(deleter.commits, 'batch', 'batches')})`
        : `${plural(count, 'document', 'documents')} would be deleted`
    );

    const nested = Object.entries(stats.subcollections);
    if (nested.length > 0) {
      for (const [name, n] of nested.sort((a, b) => b[1] - a[1])) {
        log(`      ↳ ${name}: ${plural(n, 'document', 'documents')}`);
      }
    }

    results.push({ name: collection.name, count, error: null });
  }

  let authResult = null;
  if (doAuth) {
    process.stdout.write('  Firebase Auth users … ');
    try {
      authResult = await purgeAuthUsers(auth, { enabled: deleting });
      log(
        deleting
          ? `${plural(authResult.deleted, 'account', 'accounts')} deleted` +
              (authResult.failed ? `, ${authResult.failed} failed` : '')
          : `${plural(authResult.found, 'account', 'accounts')} would be deleted`
      );
    } catch (err) {
      log('FAILED');
      warn(`    ! ${err.message}`);
    }
  } else {
    log('  Firebase Auth users … skipped');
  }

  // -------------------------------------------------------------------------
  // Summary
  // -------------------------------------------------------------------------

  const elapsed = ((Date.now() - started) / 1000).toFixed(1);
  const totalDocs = results.reduce((sum, r) => sum + (r.count || 0), 0);
  const failures = results.filter((r) => r.error);

  log('');
  rule('=');
  log(deleting ? '  SUMMARY — deleted' : '  SUMMARY — dry run, nothing was changed');
  rule('=');
  for (const r of results) {
    const value = r.error ? 'FAILED' : String(r.count);
    log(`  ${r.name.padEnd(22)} ${value.padStart(10)}`);
  }
  if (authResult) {
    const value = deleting ? authResult.deleted : authResult.found;
    log(`  ${'auth users'.padEnd(22)} ${String(value).padStart(10)}`);
  }
  rule('-');
  log(`  ${'firestore documents'.padEnd(22)} ${String(totalDocs).padStart(10)}`);
  log(`  ${'elapsed'.padEnd(22)} ${(elapsed + 's').padStart(10)}`);
  rule('=');

  if (failures.length > 0) {
    log('');
    warn(`  ${failures.length} collection(s) failed. Re-run to retry — the script is`);
    warn('  idempotent, so already-deleted documents are simply not found again.');
    log('');
    process.exitCode = 1;
    return;
  }

  log('');
  if (deleting) {
    log('  Done. Beta data has been wiped.');
    log('  Re-run the dry run to confirm everything reads back as 0.');
  } else {
    log('  This was a DRY RUN — nothing was touched.');
    log('  To actually delete, re-run with --yes-i-really-mean-it .');
    log('  There is no undo.');
  }
  log('');
}

main().catch((err) => {
  console.error('\n  UNEXPECTED FAILURE');
  console.error(err && err.stack ? err.stack : err);
  console.error(
    '\n  Nothing further was attempted. The script is resumable — fix the cause' +
      '\n  and run it again; documents already deleted will not be found twice.\n'
  );
  process.exit(1);
});
