#!/usr/bin/env node
'use strict';

/**
 * set_admin_claim.js — grant the `admin: true` custom claim to the app's one
 * admin account, so firestore.rules' isAdmin() can stop trusting an
 * email-string comparison.
 *
 * docs/Issues.md §24.9 (and the in-repo comment right above isAdmin() in
 * firestore.rules, which already flagged this): the rule was
 *   request.auth.token.email_verified == true &&
 *   request.auth.token.email.lower() == '<admin email>'
 * — trustworthy only as far as the token's `email` claim is, which is a
 * normal (if provider-verified) OIDC field, not a value Firebase Auth
 * reserves for authorization. A custom claim set via the Admin SDK is: it
 * can only ever be written server-side, with these exact credentials, never
 * by a client no matter what a Firestore rule or Cloud Function bug might
 * otherwise allow.
 *
 * firestore.rules' isAdmin() now checks `request.auth.token.admin == true`
 * FIRST and falls back to the email comparison — so nothing breaks before
 * this script has been run once, and the fallback can be deleted once it
 * has. This script is the one-time (or re-run-on-account-change) step that
 * makes the custom claim actually exist; nobody else can run it, since it
 * requires this project's own service-account credentials.
 *
 * ---------------------------------------------------------------------------
 * Usage:
 *   FIREBASE_PROJECT_ID=throttleiqfb node set_admin_claim.js --email you@example.com
 *   FIREBASE_PROJECT_ID=throttleiqfb node set_admin_claim.js --email you@example.com --yes-i-really-mean-it
 *
 * Flags:
 *   --email <address>          Required. The account to grant admin:true.
 *   --yes-i-really-mean-it     Actually write the claim. Without it, this
 *                              only looks the account up and prints what it
 *                              WOULD set — same --dry-run-by-default posture
 *                              as reset_beta_data.js in this directory.
 *   --revoke                   Remove the admin:true claim instead of
 *                              granting it (still gated by
 *                              --yes-i-really-mean-it).
 *   --help
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS to point at a service-account JSON
 * key with Firebase Admin rights, and FIREBASE_PROJECT_ID set to guard
 * against running this against the wrong project. See scripts/README.md for
 * how reset_beta_data.js sets up the same two things — this script expects
 * the same environment.
 *
 * A signed-in client does not see a custom claim change until its ID token
 * refreshes (on next sign-in, or by calling `getIdToken(true)` /
 * `user.getIdTokenResult(true)` in the app). The admin account should force
 * a refresh (sign out/in is simplest) after running this with
 * --yes-i-really-mean-it before relying on the new claim.
 */

let admin;

const EXPECTED_PROJECT_ID = 'throttleiqfb';

function parseArgs(argv) {
  const opts = { email: null, confirmed: false, revoke: false, help: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      opts.help = true;
    } else if (arg === '--yes-i-really-mean-it') {
      opts.confirmed = true;
    } else if (arg === '--revoke') {
      opts.revoke = true;
    } else if (arg === '--email') {
      opts.email = argv[++i] || null;
    } else if (arg.startsWith('--email=')) {
      opts.email = arg.slice('--email='.length);
    } else {
      console.error(`Unknown argument: ${arg}\n`);
      opts.help = true;
    }
  }
  return opts;
}

function printHelp() {
  console.log(`
set_admin_claim.js — grant/revoke the admin:true custom claim.

Usage:
  FIREBASE_PROJECT_ID=${EXPECTED_PROJECT_ID} node set_admin_claim.js --email you@example.com [--yes-i-really-mean-it] [--revoke]

Flags:
  --email <address>          Required. The account to grant/revoke admin:true.
  --yes-i-really-mean-it     Actually write the claim (default is dry-run: look up and print only).
  --revoke                   Remove the claim instead of granting it.
  --help                     Show this message.
`);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (opts.help) {
    printHelp();
    return;
  }

  if (!opts.email) {
    console.error('Missing required --email <address>. Run with --help for usage.');
    process.exitCode = 1;
    return;
  }

  const envProjectId = process.env.FIREBASE_PROJECT_ID;
  if (envProjectId !== EXPECTED_PROJECT_ID) {
    console.error(
      `Refusing to run: FIREBASE_PROJECT_ID must be exactly '${EXPECTED_PROJECT_ID}' ` +
        `(got ${envProjectId ? `'${envProjectId}'` : 'unset'}). This guards against ` +
        'accidentally granting admin rights on the wrong Firebase project.'
    );
    process.exitCode = 1;
    return;
  }

  try {
    admin = require('firebase-admin');
  } catch (err) {
    console.error(
      "Could not load 'firebase-admin'. Run `npm install` in this directory first.\n" +
        String(err)
    );
    process.exitCode = 1;
    return;
  }

  admin.initializeApp({ projectId: EXPECTED_PROJECT_ID });

  const resolvedProjectId = admin.app().options.projectId;
  if (resolvedProjectId !== EXPECTED_PROJECT_ID) {
    console.error(
      `Refusing to run: Admin SDK credentials resolved to project ` +
        `'${resolvedProjectId}', not '${EXPECTED_PROJECT_ID}'. Check ` +
        'GOOGLE_APPLICATION_CREDENTIALS.'
    );
    process.exitCode = 1;
    return;
  }

  let user;
  try {
    user = await admin.auth().getUserByEmail(opts.email);
  } catch (err) {
    console.error(`Could not find a Firebase Auth user for '${opts.email}': ${err.message}`);
    process.exitCode = 1;
    return;
  }

  const currentClaims = user.customClaims || {};
  const action = opts.revoke ? 'REVOKE' : 'GRANT';
  console.log(`Found ${opts.email} (uid: ${user.uid}).`);
  console.log(`Current custom claims: ${JSON.stringify(currentClaims)}`);
  console.log(`Would ${action} admin:true.`);

  if (!opts.confirmed) {
    console.log('\nDry run only — nothing was written. Re-run with --yes-i-really-mean-it to apply.');
    return;
  }

  const nextClaims = { ...currentClaims };
  if (opts.revoke) {
    delete nextClaims.admin;
  } else {
    nextClaims.admin = true;
  }

  await admin.auth().setCustomUserClaims(user.uid, nextClaims);
  console.log(`Done. New custom claims: ${JSON.stringify(nextClaims)}`);
  console.log(
    'The signed-in client will not see this until its ID token refreshes — ' +
      'sign out/in on that account (or call getIdTokenResult(true)) before relying on it.'
  );
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
