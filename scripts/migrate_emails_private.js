#!/usr/bin/env node
'use strict';

/**
 * migrate_emails_private.js — one-off B2 migration (CrtiQue_Oct14.md).
 *
 * Public profiles (`users/{uid}`) used to carry `email`/`emailLower`, and any
 * signed-in rider could list them. For every profile that still has either
 * field this:
 *   1. copies {email, emailLower} to the owner-only `users/{uid}/private/account`;
 *   2. writes `emailLookup/{sha256(lowercased email)}` -> {uid} (find-by-email);
 *   3. deletes `email` and `emailLower` from the public profile.
 * The app does the same for each rider on their next sign-in
 * (ProfileRepository.ensureProfile); this covers riders who don't come back.
 *
 * Run it AFTER the B2 rules are deployed (they refuse a new email on the
 * public doc, so an old build can't put it back).
 *
 * Safety:
 *   - --dry-run is the DEFAULT: reads only, prints counts.
 *   - The service-account key's project_id must be 'throttleiqfb'.
 *   - Writes need --yes-i-really-mean-it plus a typed confirmation.
 *   - Idempotent: a second run finds nothing to move.
 *   - Prints counts and uids only, never an email address.
 *
 * Usage (from scripts/):
 *   node migrate_emails_private.js --service-account=/path/to/key.json
 *   node migrate_emails_private.js --service-account=/path/to/key.json --yes-i-really-mean-it
 */

const fs = require('node:fs');
const { createHash } = require('node:crypto');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const CONFIRMATION_PHRASE = 'MOVE EMAILS';
const PAGE = 300;
/** Three writes per profile; Firestore caps a batch at 500. */
const PROFILES_PER_BATCH = 150;

function fail(msg) { console.error(`\n  ERROR  ${msg}\n`); process.exit(1); }

/** Same formula as the app's emailLookupId and firestore.rules. */
function emailLookupId(email) {
  return createHash('sha256').update(email.trim().toLowerCase()).digest('hex');
}

/**
 * What to do for one profile doc, or null when it has no email field.
 * `email` wins over `emailLower`; an empty or non-string value is only
 * stripped.
 */
function planForProfile(uid, data) {
  if (!('email' in data) && !('emailLower' in data)) return null;
  const raw = [data.email, data.emailLower].find((v) => typeof v === 'string' && v.trim() !== '');
  if (!raw) return { uid, account: null, lookupId: null };
  const email = raw.trim();
  return { uid, account: { email, emailLower: email.toLowerCase() }, lookupId: emailLookupId(email) };
}

/** Lookup ids claimed by more than one uid; the last write would win. */
function duplicateLookups(plans) {
  const owners = new Map();
  for (const p of plans) {
    if (!p.lookupId) continue;
    owners.set(p.lookupId, [...(owners.get(p.lookupId) || []), p.uid]);
  }
  return [...owners.values()].filter((uids) => uids.length > 1);
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
  const { FieldValue, FieldPath } = admin.firestore;

  const plans = [];
  let scanned = 0;
  let last = null;
  for (;;) {
    let q = db.collection('users').orderBy(FieldPath.documentId()).limit(PAGE);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    scanned += snap.size;
    for (const doc of snap.docs) {
      const plan = planForProfile(doc.id, doc.data());
      if (plan) plans.push(plan);
    }
    last = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGE) break;
  }

  const dupes = duplicateLookups(plans);
  console.log(`  Scanned ${scanned} profiles; ${plans.length} carry an email field.`);
  if (dupes.length > 0) {
    console.warn(`  WARNING ${dupes.length} email(s) are on more than one profile; uids: ${dupes.map((u) => u.join('+')).join(', ')}`);
  }
  if (!opts.confirmed) {
    console.log('  Dry run: nothing changed. Re-run with --yes-i-really-mean-it to move them.');
    return;
  }
  await confirm(opts.nonInteractive);

  for (let i = 0; i < plans.length; i += PROFILES_PER_BATCH) {
    const batch = db.batch();
    for (const p of plans.slice(i, i + PROFILES_PER_BATCH)) {
      const user = db.collection('users').doc(p.uid);
      if (p.account) {
        batch.set(user.collection('private').doc('account'), p.account, { merge: true });
        batch.set(db.collection('emailLookup').doc(p.lookupId), { uid: p.uid });
      }
      batch.update(user, { email: FieldValue.delete(), emailLower: FieldValue.delete() });
    }
    await batch.commit();
    console.log(`  Moved ${Math.min(i + PROFILES_PER_BATCH, plans.length)}/${plans.length}`);
  }
  console.log('  Done. A second run should report 0 profiles with an email field.');
}

if (require.main === module) {
  main().catch((e) => fail(e.stack || String(e)));
}

module.exports = { emailLookupId, planForProfile, duplicateLookups };
