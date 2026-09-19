'use strict';

/**
 * Security-rules tests for revoking a live-share link — §78.7 (claude_sol
 * §2.1.2).
 *
 * The bug: the end-of-ride teardown set `active:false, status:'completed'`
 * but never `shareable:false`, so an ended session — last position included —
 * stayed readable by anyone holding the link until its 24h `expiresAt`. The
 * fix has two halves pinned down here: the teardown's own write (done by the
 * owner) must be enough to shut the public `get`, and the owner (only) may
 * delete the doc outright for "Stop sharing now".
 *
 * Lives in its own file, with its own projectId, so `node --test` running it
 * in parallel with firestore_rules.test.js can't have one file's
 * `clearFirestore()` wipe the other's fixtures mid-test.
 *
 * Run with:  npm run test:rules   (from scripts/)
 */

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  Timestamp,
  serverTimestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const MALLORY = 'mallory-uid';
const LIVE_TOKEN = 'b'.repeat(32);

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'throttleiq-rules-test-live',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'liveSessions', LIVE_TOKEN), {
      uid: ALICE,
      rideId: 'ride-1',
      active: true,
      status: 'riding',
      shareable: true,
      lastLat: 23.8,
      lastLng: 90.4,
      expiresAt: Timestamp.fromMillis(Date.now() + 60 * 60_000),
      updatedAt: Timestamp.now(),
    });
  });
});

test('after the owner tears the session down, an unauthenticated get is denied', async () => {
  const anon = testEnv.unauthenticatedContext().firestore();
  // Sanity: the link works while the ride is live.
  await assertSucceeds(getDoc(doc(anon, 'liveSessions', LIVE_TOKEN)));

  // The exact write `_deliverLiveTeardown` makes (outbox_service.dart).
  const owner = testEnv.authenticatedContext(ALICE).firestore();
  await assertSucceeds(
    updateDoc(doc(owner, 'liveSessions', LIVE_TOKEN), {
      status: 'completed',
      active: false,
      shareable: false,
      updatedAt: serverTimestamp(),
    })
  );

  // expiresAt is still an hour out: only `shareable:false` is closing this.
  await assertFails(getDoc(doc(anon, 'liveSessions', LIVE_TOKEN)));
});

test('the owner can delete their live session ("Stop sharing now")', async () => {
  const owner = testEnv.authenticatedContext(ALICE).firestore();
  await assertSucceeds(deleteDoc(doc(owner, 'liveSessions', LIVE_TOKEN)));
});

test("a signed-in non-owner cannot delete someone else's live session", async () => {
  const mallory = testEnv.authenticatedContext(MALLORY).firestore();
  await assertFails(deleteDoc(doc(mallory, 'liveSessions', LIVE_TOKEN)));
});

test('an unauthenticated link holder cannot delete the live session', async () => {
  const anon = testEnv.unauthenticatedContext().firestore();
  await assertFails(deleteDoc(doc(anon, 'liveSessions', LIVE_TOKEN)));
});
