'use strict';

/**
 * Quota rehearsal (issues §104): spends a THROWAWAY Spark project's daily
 * Firestore quota on purpose and records how the client SDK reports it.
 * The app's outage handling (app/lib/core/cloud/firestore_quota.dart) relies
 * on the answers, above all on `count()` failing with `resource-exhausted`.
 *
 * Never point this at throttleiqfb: it would lock every rider out until the
 * reset. It refuses any project id that doesn't contain "quota-lab".
 *
 * Run (from scripts/), with the lab project's web app config:
 *   node loadtest/quota_rehearsal.js --project=throttleiq-quota-lab-… \
 *     --api-key=… --app-id=… [--phase=all|reads|writes]
 *
 * Phases: `reads` seeds, observes a healthy baseline, spends the read quota
 * and observes again; `writes` spends the write quota and observes again;
 * `all` (default) does both; `observe` only observes. Prints one markdown
 * table per observation round.
 */

function arg(name, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

const projectId = arg('project');
const apiKey = arg('api-key');
const appId = arg('app-id');
const phase = arg('phase', 'all');

if (!projectId || !projectId.includes('quota-lab') || projectId === 'throttleiqfb') {
  console.error('Refusing: --project must be a throwaway id containing "quota-lab".');
  process.exit(2);
}
if (!apiKey || !appId) {
  console.error('Missing --api-key / --app-id (firebase apps:sdkconfig web … --project=<lab>).');
  process.exit(2);
}

// Loaded only after the guard, so nothing can reach Firestore first.
const { initializeApp, deleteApp } = require('firebase/app');
const {
  getFirestore, terminate, doc, collection, query, where, limit,
  getDoc, getDocs, getDocsFromServer, setDoc, onSnapshot, writeBatch,
  runTransaction, getCountFromServer,
} = require('firebase/firestore');

const OBSERVE_MS = 20000;
let appSeq = 0;

/** A fresh client: empty cache and no memory of earlier failures. */
function freshDb() {
  const app = initializeApp(
    { projectId, apiKey, appId, authDomain: `${projectId}.firebaseapp.com` },
    `lab-${appSeq++}`,
  );
  return { app, db: getFirestore(app) };
}

async function dispose({ app, db }) {
  await terminate(db).catch(() => {});
  await deleteApp(app).catch(() => {});
}

/** Runs [fn] with a deadline and says what happened, in a few words. */
async function outcome(fn) {
  let timer;
  try {
    const deadline = new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('__deadline__')), OBSERVE_MS);
    });
    return (await Promise.race([fn(), deadline])) ?? 'ok';
  } catch (e) {
    if (e.message === '__deadline__') return `no answer in ${OBSERVE_MS / 1000} s (pending)`;
    return `error \`${e.code ?? e.message}\``;
  } finally {
    clearTimeout(timer);
  }
}

function firstSnapshot(q) {
  return new Promise((resolve, reject) => {
    const unsubscribe = onSnapshot(
      q,
      { includeMetadataChanges: true },
      (snap) => {
        unsubscribe();
        resolve(`snapshot, ${snap.size} docs, fromCache=${snap.metadata.fromCache}`);
      },
      reject,
    );
  });
}

const OBSERVATIONS = [
  ['`count()` on config (the app\'s probe)', (db) =>
    getCountFromServer(collection(db, 'config')).then((s) => `count = ${s.data().count}`)],
  ['query `get`', (db) =>
    getDocs(query(collection(db, 'open'), limit(50)))
      .then((s) => `${s.size} docs, fromCache=${s.metadata.fromCache}`)],
  ['listener, first event', (db) => firstSnapshot(query(collection(db, 'open'), limit(5)))],
  ['doc `get`', (db) =>
    getDoc(doc(db, 'open', 'doc-1')).then((s) => `exists=${s.exists()}, fromCache=${s.metadata.fromCache}`)],
  ['plain `set`', (db) =>
    setDoc(doc(db, 'open', `probe-${Date.now()}`), { at: Date.now() }).then(() => 'acknowledged')],
  ['`set` behind a rules `get()`', (db) =>
    setDoc(doc(db, 'guarded', `probe-${Date.now()}`), { at: Date.now() }).then(() => 'acknowledged')],
  ['transaction (read + write)', (db) =>
    runTransaction(db, async (tx) => {
      await tx.get(doc(db, 'open', 'doc-1'));
      tx.set(doc(db, 'open', 'tx-probe'), { at: Date.now() });
    }).then(() => 'committed')],
];

async function observe(title) {
  console.log(`\n### ${title}\n\n| Operation | Result |\n|---|---|`);
  for (const [name, run] of OBSERVATIONS) {
    const client = freshDb();
    console.log(`| ${name} | ${await outcome(() => run(client.db))} |`);
    await dispose(client);
  }
}

async function seed() {
  const client = freshDb();
  const batch = writeBatch(client.db);
  for (let i = 0; i < 500; i++) batch.set(doc(client.db, 'open', `doc-${i}`), { i });
  batch.set(doc(client.db, 'open', 'gate'), { ok: true });
  batch.set(doc(client.db, 'config', 'app'), { minBuild: 0 });
  await batch.commit();
  await dispose(client);
  console.log('Seeded 502 docs.');
}

/** About 500 reads per query; Spark allows 50,000 a day. */
async function spendReads() {
  const client = freshDb();
  try {
    for (let i = 1; i <= 200; i++) {
      // A different query each time (every seeded doc has i >= 0), so no
      // resume token lets the server answer with less than all 500 docs.
      const q = query(collection(client.db, 'open'), where('i', '>=', -i), limit(500));
      const result = await outcome(() => getDocsFromServer(q).then((s) => `ok:${s.size}`));
      if (!result.startsWith('ok:')) {
        console.log(`Read quota: query ${i} → ${result}`);
        return;
      }
      if (i % 20 === 0) console.log(`  ${i} queries read`);
    }
    console.log('Read quota: not refused after 200 queries (check the console Usage tab).');
  } finally {
    await dispose(client);
  }
}

/**
 * Writes until even a single one is refused; Spark allows 20,000 a day.
 * A batch is refused whole, so near the limit the size shrinks to 1.
 */
async function spendWrites() {
  let client = freshDb();
  let size = 500;
  let total = 0;
  try {
    for (let b = 1; b <= 300; b++) {
      const batch = writeBatch(client.db);
      for (let i = 0; i < size; i++) batch.set(doc(client.db, 'open', `burn-${Date.now()}-${b}-${i}`), { b, i });
      const result = await outcome(() => batch.commit().then(() => 'ok'));
      if (result === 'ok') {
        total += size;
        if (total % 5000 < size) console.log(`  ${total} writes committed`);
        continue;
      }
      console.log(`Write quota: a batch of ${size} after ${total} writes → ${result}`);
      if (size === 1) return;
      // A refused batch stays queued and blocks every later write on its
      // client, so the next, smaller try needs a fresh one.
      await dispose(client);
      client = freshDb();
      size = Math.max(1, Math.floor(size / 5));
    }
    console.log(`Write quota: not refused after ${total} writes (check the console Usage tab).`);
  } finally {
    await dispose(client);
  }
}

async function main() {
  console.log(`Quota rehearsal on ${projectId}, phase ${phase}, ${new Date().toISOString()}`);
  if (phase === 'all' || phase === 'reads') {
    await seed();
    await observe('Healthy baseline');
    await spendReads();
    await observe('Read quota spent');
  }
  if (phase === 'all' || phase === 'writes') {
    await spendWrites();
    await observe('Read and write quota spent');
  }
  // Enforcement lags: the first rehearsal read 100,000 docs before any
  // refusal. Re-run this until the table changes.
  if (phase === 'observe') await observe('Observed again');
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error(e);
    process.exit(1);
  },
);
