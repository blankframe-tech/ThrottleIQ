'use strict';

/**
 * Security-rules tests for the 2026-10-14 critique fixes in `firestore.rules`
 * (CrtiQue_Oct14.md): B2 (email harvesting), B3 (block gaps) and the
 * `config/app` doc behind the forced-update gate.
 *
 * Each "succeeds" case is the payload the app writes; each "denied" case is
 * the hole the rule closes. Own projectId so `node --test` can run this file
 * in parallel with the others.
 *
 * Run with:  npm run test:rules   (from scripts/)
 */

const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  deleteField,
  query,
  where,
  orderBy,
  limit,
  writeBatch,
  serverTimestamp,
  Timestamp,
} = require('firebase/firestore');

const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', '..', 'firestore.rules'),
  'utf8'
);

const ALICE = 'alice-uid';
const BOB = 'bob-uid';
const MALLORY = 'mallory-uid';
const DM_ID = `${ALICE}_${MALLORY}`; // sorted: 'alice-uid' < 'mallory-uid'
const ALICE_EMAIL = 'Alice@Example.com';

/** Same as ProfileRepository.emailLookupId. */
const lookupId = (email) =>
  createHash('sha256').update(email.trim().toLowerCase()).digest('hex');

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-throttleiq-rules-oct14',
    firestore: { rules: RULES }, // host: FIRESTORE_EMULATOR_HOST (emulators:exec)
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, name] of [[ALICE, 'alice'], [BOB, 'bob'], [MALLORY, 'mallory']]) {
      await setDoc(doc(db, 'users', uid), {
        displayName: name, usernameLower: name, visibility: 'public', createdAt: Timestamp.now(),
      });
    }
    await setDoc(doc(db, 'chats', DM_ID), { participants: [ALICE, MALLORY], updatedAt: Timestamp.now() });
  });
});

function dbFor(uid, token) {
  return testEnv.authenticatedContext(uid, token).firestore();
}

async function block(blocker, blocked) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', blocker, 'blocks', blocked), { blockedAt: Timestamp.now() });
  });
}

// ---------------------------------------------------------------------------
// B2: email off the public profile, lookup by hash, list cap
// ---------------------------------------------------------------------------

test('B2: a NEW email on the public profile is denied, even the caller\'s own', async () => {
  const db = dbFor(ALICE, { email: ALICE_EMAIL });
  await assertFails(setDoc(doc(db, 'users', ALICE), {
    email: ALICE_EMAIL, emailLower: ALICE_EMAIL.toLowerCase(),
  }, { merge: true }));
  await assertFails(setDoc(doc(db, 'users', ALICE), { emailLower: 'alice@example.com' }, { merge: true }));
});

// N2 (Oct15), decided: the rules do NOT accept the beta 4.5 shape. That build
// writes email/emailLower onto the public profile, and any rule that let it
// through would publish the address again. Old builds have no minBuild gate,
// so SECURITY.md's deploy order (testers on the new build first) is the fix.
// These pin the break that runbook describes.
test('N2 (Oct15): a beta 4.5 sign-up (email on the new profile) is refused', async () => {
  const db = dbFor('new-uid', { email: 'new@example.com', email_verified: true });
  const legacy = {
    displayName: 'new', email: 'new@example.com', emailLower: 'new@example.com',
    visibility: 'public', followerCount: 0, followingCount: 0,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  await assertFails(setDoc(doc(db, 'users', 'new-uid'), legacy, { merge: true }));
  const { email, emailLower, ...current } = legacy;
  await assertSucceeds(setDoc(doc(db, 'users', 'new-uid'), current, { merge: true }));
});

test('N2 (Oct15): after the migration, a beta 4.5 ensureProfile (rename path) is refused', async () => {
  const db = dbFor(ALICE, { email: ALICE_EMAIL, email_verified: true });
  await assertFails(setDoc(doc(db, 'users', ALICE), {
    displayName: 'alice2', email: ALICE_EMAIL, emailLower: ALICE_EMAIL.toLowerCase(),
    updatedAt: serverTimestamp(),
  }, { merge: true }));
});

test('B2: ensureProfile strips a legacy email and writes the owner-only account doc', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'users', ALICE), {
      email: ALICE_EMAIL, emailLower: 'alice@example.com',
    });
  });
  const db = dbFor(ALICE, { email: ALICE_EMAIL });
  await assertSucceeds(setDoc(doc(db, 'users', ALICE), {
    displayName: 'alice', email: deleteField(), emailLower: deleteField(), updatedAt: serverTimestamp(),
  }, { merge: true }));
  await assertSucceeds(setDoc(doc(db, 'users', ALICE, 'private', 'account'), {
    email: ALICE_EMAIL, emailLower: 'alice@example.com',
  }, { merge: true }));
  await assertSucceeds(getDoc(doc(db, 'users', ALICE, 'private', 'account')));
  await assertFails(getDoc(doc(dbFor(BOB), 'users', ALICE, 'private', 'account')));
  await assertFails(setDoc(doc(dbFor(BOB), 'users', ALICE, 'private', 'account'), { email: 'x@y.z' }));
});

test('B2: the owner creates, updates and deletes their own email lookup', async () => {
  const db = dbFor(ALICE, { email: ALICE_EMAIL, email_verified: true });
  const ref = doc(db, 'emailLookup', lookupId(ALICE_EMAIL));
  await assertSucceeds(setDoc(ref, { uid: ALICE }));
  await assertSucceeds(setDoc(ref, { uid: ALICE }));
  await assertSucceeds(deleteDoc(ref));
});

test('B2: nobody can point someone else\'s email at themselves', async () => {
  const db = dbFor(MALLORY, { email: 'mallory@example.com', email_verified: true });
  await assertFails(setDoc(doc(db, 'emailLookup', lookupId(ALICE_EMAIL)), { uid: MALLORY }));
  // Their own hash, but naming another uid, or carrying extra keys.
  await assertFails(setDoc(doc(db, 'emailLookup', lookupId('mallory@example.com')), { uid: ALICE }));
  await assertFails(setDoc(doc(db, 'emailLookup', lookupId('mallory@example.com')), {
    uid: MALLORY, email: 'mallory@example.com',
  }));
  // No email on the token at all.
  await assertFails(setDoc(doc(dbFor(MALLORY), 'emailLookup', lookupId('')), { uid: MALLORY }));
});

test('B2: a lookup left by a deleted account passes to the email\'s new holder', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'emailLookup', lookupId(ALICE_EMAIL)), { uid: 'old-alice-uid' });
  });
  const ref = doc(dbFor(ALICE, { email: ALICE_EMAIL, email_verified: true }), 'emailLookup', lookupId(ALICE_EMAIL));
  await assertSucceeds(setDoc(ref, { uid: ALICE }));
});

test('N3 (Oct15): an unverified email cannot claim or take over its lookup', async () => {
  // Signing up with an address you don't own gives a token with that email
  // but email_verified false (or absent).
  for (const token of [{ email: ALICE_EMAIL }, { email: ALICE_EMAIL, email_verified: false }]) {
    const ref = doc(dbFor(MALLORY, token), 'emailLookup', lookupId(ALICE_EMAIL));
    await assertFails(setDoc(ref, { uid: MALLORY }));
  }
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'emailLookup', lookupId(ALICE_EMAIL)), { uid: 'old-alice-uid' });
  });
  await assertFails(setDoc(doc(dbFor(MALLORY, { email: ALICE_EMAIL }), 'emailLookup', lookupId(ALICE_EMAIL)),
    { uid: MALLORY }));
});

test('B2: any signed-in rider may get a lookup; nobody may list them', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'emailLookup', lookupId(ALICE_EMAIL)), { uid: ALICE });
  });
  const snap = await assertSucceeds(getDoc(doc(dbFor(BOB), 'emailLookup', lookupId(ALICE_EMAIL))));
  if (snap.get('uid') !== ALICE) throw new Error('lookup did not resolve');
  await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), 'emailLookup', lookupId(ALICE_EMAIL))));
  await assertFails(getDocs(collection(dbFor(BOB), 'emailLookup')));
  await assertFails(getDocs(query(collection(dbFor(BOB), 'emailLookup'), limit(1))));
});

test('B2: only the stored owner may delete a lookup', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'emailLookup', lookupId(ALICE_EMAIL)), { uid: ALICE });
  });
  await assertFails(deleteDoc(doc(dbFor(MALLORY), 'emailLookup', lookupId(ALICE_EMAIL))));
});

test('B2: a users list must ask for at most 20 docs', async () => {
  const db = dbFor(BOB);
  const recent = (n) => {
    const q = [where('visibility', '==', 'public'), orderBy('createdAt', 'desc')];
    return getDocs(query(collection(db, 'users'), ...(n == null ? q : [...q, limit(n)])));
  };
  await assertSucceeds(recent(20));
  await assertFails(recent(21));
  await assertFails(recent(null));
  // searchByUsername's query, at its default page.
  await assertSucceeds(getDocs(query(collection(db, 'users'),
    where('visibility', '==', 'public'),
    where('usernameLower', '>=', 'a'), where('usernameLower', '<', 'a'), limit(20))));
});

// ---------------------------------------------------------------------------
// B3: blocks on chats, notifications and follows
// ---------------------------------------------------------------------------

/** The parent-doc half of ChatRepository.sendMessage's batch. */
function chatPreview(db, sender) {
  return updateDoc(doc(db, 'chats', DM_ID), {
    lastMessage: { senderId: sender, text: 'hi', createdAt: serverTimestamp() },
    updatedAt: serverTimestamp(),
  });
}

test('B3: a blocked rider cannot write the inbox preview', async () => {
  await assertSucceeds(chatPreview(dbFor(MALLORY), MALLORY));
  await block(ALICE, MALLORY);
  await assertFails(chatPreview(dbFor(MALLORY), MALLORY));
});

test('B3: a blocked rider cannot even send the full message batch', async () => {
  await block(ALICE, MALLORY);
  const db = dbFor(MALLORY);
  const batch = writeBatch(db);
  batch.set(doc(collection(db, 'chats', DM_ID, 'messages')), {
    senderId: MALLORY, text: 'hi', createdAt: serverTimestamp(), isRead: false,
  });
  batch.update(doc(db, 'chats', DM_ID), {
    lastMessage: { senderId: MALLORY, text: 'hi', createdAt: serverTimestamp() },
    updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});

test('B3: a blocked rider cannot open a new chat room', async () => {
  const id = `${BOB}_${MALLORY}`;
  const create = (db) => setDoc(doc(db, 'chats', id), {
    participants: [BOB, MALLORY], updatedAt: serverTimestamp(),
  });
  await block(BOB, MALLORY);
  await assertFails(create(dbFor(MALLORY)));
  // The block is lifted: the same create goes through.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await deleteDoc(doc(ctx.firestore(), 'users', BOB, 'blocks', MALLORY));
  });
  await assertSucceeds(create(dbFor(MALLORY)));
});

/** NotificationRepository.notifyFollow's write. */
function notifyFollow(db, toUid, fromUid) {
  return setDoc(doc(db, 'users', toUid, 'notifications', `follow_${fromUid}`), {
    type: 'follow', fromUid, fromName: 'Mallory', fromPhotoUrl: null, createdAt: serverTimestamp(), read: false,
  });
}

test('B3: notifications are refused across a block, in either direction', async () => {
  await assertSucceeds(notifyFollow(dbFor(MALLORY), ALICE, MALLORY));
  await block(ALICE, MALLORY);
  // The follow-row rewrite (an update) and a fresh group-ride invite.
  await assertFails(notifyFollow(dbFor(MALLORY), ALICE, MALLORY));
  await assertFails(setDoc(doc(collection(dbFor(MALLORY), 'users', ALICE, 'notifications')), {
    type: 'groupRideInvite', fromUid: MALLORY, fromName: 'Mallory', groupRideId: 'gr1',
    createdAt: serverTimestamp(), read: false,
  }));
  // Alice blocked Mallory; Alice can't ping Mallory either.
  await assertFails(notifyFollow(dbFor(ALICE), MALLORY, ALICE));
  // Bob is unaffected.
  await assertSucceeds(notifyFollow(dbFor(BOB), ALICE, BOB));
});

/** FollowRepository.follow's write. */
function follow(db, follower, followee) {
  return setDoc(doc(db, 'follows', `${follower}_${followee}`), {
    followerUid: follower, followeeUid: followee, createdAt: serverTimestamp(),
  });
}

test('B3: a block refuses a follow edge in either direction', async () => {
  await block(ALICE, MALLORY);
  await assertFails(follow(dbFor(MALLORY), MALLORY, ALICE));
  await assertFails(follow(dbFor(ALICE), ALICE, MALLORY));
  await assertSucceeds(follow(dbFor(BOB), BOB, ALICE));
});

// ---------------------------------------------------------------------------
// config/app: the forced-update gate
// ---------------------------------------------------------------------------

test('config: anyone (even signed out) reads config/app; no client writes it', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'config', 'app'), { minBuild: 42 });
  });
  const anon = testEnv.unauthenticatedContext().firestore();
  const snap = await assertSucceeds(getDoc(doc(anon, 'config', 'app')));
  if (snap.get('minBuild') !== 42) throw new Error('minBuild not readable');
  await assertFails(setDoc(doc(dbFor(ALICE), 'config', 'app'), { minBuild: 0 }));
  await assertFails(updateDoc(doc(dbFor(ALICE), 'config', 'app'), { minBuild: 0 }));
  await assertFails(deleteDoc(doc(dbFor(ALICE), 'config', 'app')));
  const admin = dbFor('admin-uid', { admin: true, email: 'the.abraar.rar@gmail.com', email_verified: true });
  await assertFails(setDoc(doc(admin, 'config', 'app'), { minBuild: 0 }));
});
