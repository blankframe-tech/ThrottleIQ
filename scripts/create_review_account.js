#!/usr/bin/env node
'use strict';

/**
 * create_review_account.js — creates (or repairs) a single real sign-in
 * account for Google Play's "App access" review form (Play Console →
 * App content → App access → Admin Account), so a Play reviewer can sign in
 * with email/password and reach the main app past onboarding.
 *
 * Mirrors exactly what the app itself writes on first sign-in/registration,
 * so this account is indistinguishable from a real one to the client:
 *   - Firebase Auth user with `displayName` set — app_router.dart gates
 *     onboarding on `auth.displayName == null`, so this alone is what lets
 *     the reviewer skip onboarding after logging in.
 *   - `users/{uid}` profile doc — same fields ProfileRepository.ensureProfile
 *     writes on first login (displayName, email, emailLower, followerCount,
 *     followingCount, createdAt, updatedAt).
 *   - `usernames/{handle}` claim + `users/{uid}.username`/`usernameLower` —
 *     same shape ProfileRepository.setUsername's transaction writes. Handle
 *     is derived from the email's local part exactly like
 *     ProfileRepository.suggestUsernameBase does (lowercase, strip to
 *     [a-z0-9_], clamp 3-20 chars).
 *
 * Tagged `playReviewAccount: true` (not `qaSeed`) so cleanup_qa_test_riders.js
 * can never touch it and it's easy to find again — this account should
 * persist indefinitely, since Google re-reviews using it on every submission
 * that needs an "App access" form (see docs/HANDOFF_Document.md).
 *
 * Idempotent: re-running with the same email updates the existing Auth
 * user's password/displayName and re-syncs the Firestore docs rather than
 * failing — this is meant to be safe to re-run whenever Play Console's
 * password field needs to change.
 *
 * Adds no bike/rides — onboarding's "add a bike" step has a Skip button
 * (onboarding_screen.dart), so a bare profile is enough to reach the main
 * app. If a reviewer needs to see Garage/ride-history screens populated,
 * add a bike by hand afterwards; this script only covers login access.
 *
 * ---------------------------------------------------------------------------
 * Usage:
 *   node create_review_account.js                                    # dry run, no creds needed
 *   FIREBASE_PROJECT_ID=throttleiqfb node create_review_account.js --yes-i-really-mean-it
 *
 * Flags:
 *   --email <address>      Default: rider.admin@example.com
 *   --password <password>  Default: Test@123
 *   --display-name <name>  Default: "ThrottleIQ Reviewer"
 *   --username <handle>    Default: derived from the email's local part
 *   --dry-run              Explicit form of the default. Prints the planned
 *                          payload only. No credentials needed.
 *   --yes-i-really-mean-it Actually create/update the Auth account and
 *                          Firestore docs. Requires FIREBASE_PROJECT_ID and
 *                          GOOGLE_APPLICATION_CREDENTIALS (see scripts/README.md).
 *   --non-interactive       Skip the typed confirmation prompt.
 *   --help
 */

let admin;

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const CONFIRMATION_PHRASE = 'CREATE REVIEW ACCOUNT';

const DEFAULTS = {
  email: 'rider.admin@example.com',
  password: 'Test@123',
  displayName: 'ThrottleIQ Reviewer',
};

const log = (...args) => console.log(...args);
const warn = (...args) => console.warn(...args);

function fail(message) {
  console.error(`\n  ERROR  ${message}\n`);
  process.exit(1);
}

function rule(char = '-') {
  log(char.repeat(66));
}

// Same sanitizing as ProfileRepository.suggestUsernameBase in
// app/lib/features/profile/data/repositories/profile_repository.dart —
// lowercase, strip to [a-z0-9_], clamp to the 3-20 char window
// setUsername's regex (`^[a-z0-9_]{3,20}$`) requires.
function suggestUsernameBase(email) {
  const local = email.split('@')[0].toLowerCase();
  let base = local.replace(/[^a-z0-9_]/g, '');
  if (base.length > 20) base = base.slice(0, 20);
  while (base.length < 3) base += '0';
  return base;
}

function parseArgs(argv) {
  const opts = {
    email: DEFAULTS.email,
    password: DEFAULTS.password,
    displayName: DEFAULTS.displayName,
    username: null,
    confirmed: false,
    nonInteractive: false,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') opts.help = true;
    else if (arg === '--yes-i-really-mean-it') opts.confirmed = true;
    else if (arg === '--dry-run') {
      // explicit form of the default
    } else if (arg === '--non-interactive') opts.nonInteractive = true;
    else if (arg === '--email') opts.email = argv[++i];
    else if (arg.startsWith('--email=')) opts.email = arg.slice('--email='.length);
    else if (arg === '--password') opts.password = argv[++i];
    else if (arg.startsWith('--password=')) opts.password = arg.slice('--password='.length);
    else if (arg === '--display-name') opts.displayName = argv[++i];
    else if (arg.startsWith('--display-name=')) opts.displayName = arg.slice('--display-name='.length);
    else if (arg === '--username') opts.username = argv[++i];
    else if (arg.startsWith('--username=')) opts.username = arg.slice('--username='.length);
    else throw new Error(`Unknown argument: ${arg}\nRun with --help for usage.`);
  }
  if (!opts.username) opts.username = suggestUsernameBase(opts.email);
  return opts;
}

const USAGE = `
create_review_account.js — create/repair the Google Play "App access"
reviewer sign-in account.

  node create_review_account.js
      Dry run (the default). Prints the planned Auth + Firestore payload.
      No credentials needed, nothing is sent anywhere.

  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node create_review_account.js --yes-i-really-mean-it
      Actually create (or update, if it already exists) the Auth account and
      Firestore docs in the live '${EXPECTED_PROJECT_ID}' project.

Flags:
  --email <address>       Default: ${DEFAULTS.email}
  --password <password>   Default: ${DEFAULTS.password}
  --display-name <name>   Default: ${DEFAULTS.displayName}
  --username <handle>     Default: derived from the email's local part
  --dry-run               Explicit form of the default.
  --yes-i-really-mean-it  Required to actually create/update anything.
  --non-interactive       Skip the typed confirmation prompt.
  --help                  This message.

Environment (only needed for a real run):
  FIREBASE_PROJECT_ID              Must equal '${EXPECTED_PROJECT_ID}'.
  GOOGLE_APPLICATION_CREDENTIALS   Path to a service-account JSON key.
`;

function assertProjectEnv() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) fail(`FIREBASE_PROJECT_ID is not set. Set it to '${EXPECTED_PROJECT_ID}' to run for real.`);
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

async function confirmRealWrite({ nonInteractive }) {
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
  if (typed.trim() !== CONFIRMATION_PHRASE) fail('Confirmation phrase did not match. Nothing was created.');
  log('');
}

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
  if (!/^[a-z0-9_]{3,20}$/.test(opts.username)) {
    fail(`Derived/given username '${opts.username}' is not 3-20 chars of [a-z0-9_] — pass --username explicitly.`);
  }

  const writing = opts.confirmed;

  rule('=');
  log('  ThrottleIQ Play-review account');
  log(writing ? '  MODE: WRITING FOR REAL to a live project.' : '  MODE: dry run (default). Nothing will be created.');
  rule('=');
  log('');
  log(`  Email:         ${opts.email}`);
  log(`  Password:      ${opts.password}`);
  log(`  Display name:  ${opts.displayName}`);
  log(`  Username:      @${opts.username}`);
  log('');

  if (!writing) {
    log('  Would create/update:');
    log(`    - Firebase Auth user (email/password, displayName set so the`);
    log(`      router's onboarding gate is skipped on first login)`);
    log(`    - users/{uid}: displayName, email, emailLower, username,`);
    log(`      usernameLower, followerCount: 0, followingCount: 0,`);
    log(`      createdAt/updatedAt, playReviewAccount: true`);
    log(`    - usernames/${opts.username}: { uid }`);
    log('');
    log('  This was a DRY RUN — nothing was created, no credentials were used.');
    log(`  To actually create/update it, set FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} and`);
    log('  GOOGLE_APPLICATION_CREDENTIALS, then re-run with --yes-i-really-mean-it.');
    log('');
    return;
  }

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
  const Timestamp = admin.firestore.Timestamp;

  await confirmRealWrite({ nonInteractive: opts.nonInteractive });

  let userRecord;
  let created;
  try {
    userRecord = await auth.createUser({
      email: opts.email,
      password: opts.password,
      displayName: opts.displayName,
      emailVerified: true,
    });
    created = true;
    log(`  Created Auth user ${opts.email} (uid: ${userRecord.uid}).`);
  } catch (err) {
    if (err && err.code === 'auth/email-already-exists') {
      userRecord = await auth.getUserByEmail(opts.email);
      await auth.updateUser(userRecord.uid, {
        password: opts.password,
        displayName: opts.displayName,
        emailVerified: true,
      });
      created = false;
      log(`  ${opts.email} already existed (uid: ${userRecord.uid}) — updated password/displayName.`);
    } else {
      throw err;
    }
  }

  const uid = userRecord.uid;
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();

  await userRef.set(
    {
      displayName: opts.displayName,
      email: opts.email,
      emailLower: opts.email.toLowerCase(),
      username: opts.username,
      usernameLower: opts.username,
      ...(!userSnap.exists
        ? { followerCount: 0, followingCount: 0, createdAt: Timestamp.now() }
        : {}),
      updatedAt: Timestamp.now(),
      playReviewAccount: true,
    },
    { merge: true }
  );

  const usernameRef = db.collection('usernames').doc(opts.username);
  const usernameSnap = await usernameRef.get();
  if (usernameSnap.exists && usernameSnap.data().uid !== uid) {
    fail(
      `usernames/${opts.username} is already claimed by a different uid ` +
        `(${usernameSnap.data().uid}). Re-run with --username <other-handle>.`
    );
  }
  await usernameRef.set({ uid });

  log(`  Synced users/${uid} and usernames/${opts.username}.`);
  log('');
  rule('=');
  log(`  DONE — ${created ? 'created' : 'updated'} the review account.`);
  rule('=');
  log('');
  log('  Paste these into Play Console → App content → App access → Admin Account:');
  log(`    Username, email address, or phone number:  ${opts.email}`);
  log(`    Password:                                   ${opts.password}`);
  log('');
}

main().catch((err) => {
  console.error('\n  UNEXPECTED FAILURE');
  console.error(err && err.stack ? err.stack : err);
  process.exit(1);
});
