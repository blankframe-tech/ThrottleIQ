'use strict';

/**
 * Spark-quota simulation: replays the app's real Firestore query and write
 * shapes against the emulator, through the client SDK with firestore.rules
 * enforced, and counts billable reads and writes per scenario.
 *
 * Only operation counts mean anything here. Emulator latency is not
 * production latency, so none is reported.
 *
 * Billing rules applied (firebase.google.com/docs/firestore/pricing):
 *   - a query is at least 1 read even when it returns nothing;
 *   - a listener costs its initial result, then 1 read per changed doc;
 *   - a rules get()/exists() is 1 read per request (counted by hand below,
 *     the emulator does not report it).
 *
 * Run (from scripts/):  npm run loadtest:quota
 * Never point this at production: it is the thing that would spend the
 * daily quota riders use.
 */

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const {
  doc, collection, query, where, orderBy, limit,
  getDoc, getDocs, setDoc, onSnapshot, writeBatch, runTransaction,
  Timestamp, serverTimestamp, collectionGroup, documentId,
} = require('firebase/firestore');

const RULES = fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8');
const settle = (ms = 250) => new Promise((r) => setTimeout(r, ms));

let env;
const counter = () => ({ reads: 0, writes: 0, denied: 0 });

/** Wraps one signed-in client so every call it makes is counted. */
function client(uid, c) {
  const db = env.authenticatedContext(uid).firestore();
  const unsubs = [];
  const guard = async (fn) => {
    try { return await fn(); } catch (e) {
      if (e.code === 'permission-denied') { c.denied++; return null; }
      throw e;
    }
  };
  return {
    db,
    async getDocs(q, ruleGets = 0) {
      const s = await guard(() => getDocs(q));
      if (s) c.reads += Math.max(1, s.size) + ruleGets;
      return s;
    },
    async getDoc(ref, ruleGets = 0) {
      const s = await guard(() => getDoc(ref));
      if (s) c.reads += 1 + ruleGets;
      return s;
    },
    async set(ref, data, ruleGets = 0) {
      if (await guard(() => setDoc(ref, data).then(() => true))) { c.writes++; c.reads += ruleGets; }
    },
    async batch(ops, ruleGets = 0) {
      const b = writeBatch(db);
      for (const [ref, data, opts] of ops) b.set(ref, data, opts ?? {});
      if (await guard(() => b.commit().then(() => true))) { c.writes += ops.length; c.reads += ruleGets; }
    },
    async txnSet(ref, data) {
      const ok = await guard(() => runTransaction(db, async (tx) => {
        await tx.get(ref);
        tx.set(ref, data);
      }).then(() => true));
      if (ok) { c.reads++; c.writes++; }
    },
    listen(target) {
      let first = true;
      unsubs.push(onSnapshot(target, (s) => {
        if (first) { c.reads += Math.max(1, s.size ?? 1); first = false; return; }
        // A local echo of this client's own write is not billed; the server's
        // confirmation of it (serverTimestamp resolved) is.
        if (!s.docChanges) { if (!s.metadata.hasPendingWrites) c.reads++; return; }
        c.reads += s.docChanges().filter((ch) => !ch.doc.metadata.hasPendingWrites).length;
      }, (e) => { if (e.code === 'permission-denied') c.denied++; }));
    },
    stop() { unsubs.forEach((u) => u()); },
  };
}

const seed = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

// ---------------------------------------------------------------------------
// 1. Live share: rider writes liveSessions/{token} every 10 s
//    (live_session_coordinator.dart:63; the RTDB relay is off because
//    database.rules.json denies everything, B9). Each web viewer
//    (public/live-viewer.html) holds a listener on the session doc.
async function liveShare(viewers, ticks) {
  const c = counter();
  const token = 'a'.repeat(32);
  const session = () => ({
    uid: 'rider', rideId: 'ride-1', active: true, status: 'riding', shareable: true,
    lastLat: 23.8 + Math.random() / 100, lastLng: 90.4, speedMs: 8, batteryPct: 70,
    expiresAt: Timestamp.fromMillis(Date.now() + 23 * 3600_000), updatedAt: serverTimestamp(),
  });
  const rider = client('rider', c);
  await rider.set(doc(rider.db, 'liveSessions', token), session());
  const vs = [];
  for (let i = 0; i < viewers; i++) {
    const v = client(`viewer${i}`, c);
    v.listen(doc(v.db, 'liveSessions', token));
    vs.push(v);
  }
  await settle(500);
  const base = { ...c };
  for (let t = 0; t < ticks; t++) {
    await rider.set(doc(rider.db, 'liveSessions', token), session());
    await settle();
  }
  [rider, ...vs].forEach((x) => x.stop());
  return perTick(c, base, ticks);
}

// ---------------------------------------------------------------------------
// 2. Group ride map: every member publishes every tick when moved >= 25 m
//    (group_ride_broadcast_gate.dart; always true while riding above
//    4.5 km/h). Each member's map holds listeners on the ride doc, members
//    and voiceNotes (group_ride_providers.dart), plus the "Riding Now" query.
//    shared (§104.2, group_ride_map_screen.dart _tick): one batch writes
//    memberLocations/{uid} and positions/all (1 rules get() on the ride, shared
//    by both), then one get() of positions/all (+1 rules get()). Every member
//    is in the doc, so the missing-member memberLocations query never runs.
//    legacy (build 29, or rules not deployed): writes memberLocations/{uid}
//    (1 rules get()) and listens to the whole memberLocations collection.
async function groupRide(rideId, n, ticks, shared = true) {
  const c = counter();
  const uids = Array.from({ length: n }, (_, i) => `${rideId}-m${i}`);
  await seed(async (db) => {
    await setDoc(doc(db, 'groupRides', rideId), {
      creatorId: uids[0], creatorName: 'c', name: 'ride', status: 'active',
      memberIds: uids, invitedIds: [], maxParticipants: 20,
      startTime: Timestamp.now(), createdAt: Timestamp.now(), lastActiveAt: Timestamp.now(),
    });
    for (const u of uids) {
      await setDoc(doc(db, 'groupRides', rideId, 'members', u), {
        userId: u, userName: u, userPhotoUrl: '', status: 'joined', joinedAt: Timestamp.now(),
      });
    }
  });
  const ms = uids.map((u) => {
    const m = client(u, c);
    const ride = doc(m.db, 'groupRides', rideId);
    m.listen(ride);
    m.listen(collection(ride, 'members'));
    if (!shared) m.listen(collection(ride, 'memberLocations'));
    m.listen(query(collection(ride, 'voiceNotes'), orderBy('createdAt', 'desc'), limit(20)));
    m.listen(query(collection(m.db, 'groupRides'),
      where('memberIds', 'array-contains', u), where('status', '==', 'active')));
    return { u, m };
  });
  await settle(800);
  const base = { ...c };
  for (let t = 0; t < ticks; t++) {
    const pos = () => ({ lat: 23.8 + Math.random() / 100, lng: 90.4, timestamp: serverTimestamp() });
    const loc = (m, u) => doc(m.db, 'groupRides', rideId, 'memberLocations', u);
    const all = (m) => doc(m.db, 'groupRides', rideId, 'positions', 'all');
    await Promise.all(ms.map(({ u, m }) => (shared
      ? m.batch([[loc(m, u), { userId: u, ...pos() }], [all(m), { [u]: pos() }, { merge: true }]], 1)
      : m.set(loc(m, u), { userId: u, ...pos() }, 1))));
    if (shared) await Promise.all(ms.map(({ m }) => m.getDoc(all(m), 1)));
    await settle(400);
  }
  ms.forEach(({ m }) => m.stop());
  return perTick(c, base, ticks);
}

// ---------------------------------------------------------------------------
// 3. Saving a ride: last-writer-wins transaction on the ride doc
//    (last_writer_wins.dart:33) plus one batch of 500-point track chunks
//    (cloud_repository.dart:858, ride_track_codec.dart:41).
async function rideSave(minutes) {
  const c = counter();
  const r = client('saver', c);
  const rideRef = doc(r.db, 'users', 'saver', 'rides', 'ride-1');
  await r.txnSet(rideRef, { id: 'ride-1', distance_km: 30, syncedAt: serverTimestamp() });
  const points = minutes * 60; // 1 Hz
  const ops = [];
  for (let i = 0; i * 500 < points; i++) {
    const pts = Array.from({ length: Math.min(500, points - i * 500) * 5 }, () => Math.random());
    ops.push([doc(rideRef, 'track', `${i}`), { index: i, points: pts, syncedAt: serverTimestamp() }]);
  }
  await r.batch(ops);
  return c;
}

// ---------------------------------------------------------------------------
// 4. Idle sync cycle, every 5 min while the process lives
//    (sync_manager.dart:258): incremental `syncedAt > since` pulls of bikes,
//    maintenance, fuel logs and rides (cloud_repository.dart:549). Nothing
//    changed, so each query returns 0 docs and bills the 1-read minimum.
async function syncIdle() {
  const c = counter();
  const s = client('syncer', c);
  await seed(async (db) => {
    for (let i = 0; i < 50; i++) {
      await setDoc(doc(db, 'users', 'syncer', 'rides', `r${i}`), { syncedAt: Timestamp.fromMillis(Date.now() - 86400_000) });
    }
  });
  const since = Timestamp.now();
  for (const col of ['bikes', 'maintenance', 'fuelLogs', 'rides']) {
    await s.getDocs(query(collection(s.db, 'users', 'syncer', col), where('syncedAt', '>', since)));
  }
  return c;
}

// ---------------------------------------------------------------------------
// 5. One Social feed page (ride_feed_provider.dart:140): following + followers
//    (for mutuals), public / shared-to-me / mine (20 each), public posts of
//    followed authors in whereIn chunks of 30, 5 restricted posts per followed
//    author, then the reader's votes on the 20 shown rides in one
//    collection-group `documentId in` query (getMyVotes, §104.3; worst case:
//    the reader voted on all 20, so it returns 20 docs; no rules get()).
async function feedPage(follows) {
  const c = counter();
  const me = `reader${follows}`;
  const authors = Array.from({ length: Math.max(follows, 40) }, (_, i) => `author${i}`);
  await seed(async (db) => {
    let t = Date.now();
    for (const a of authors) {
      for (let k = 0; k < 3; k++) {
        await setDoc(doc(db, 'rides', `${a}-${k}`), {
          userId: a, audience: k === 2 ? 'followers' : 'public', allowedUserIds: [],
          createdAt: Timestamp.fromMillis(t--), upvotes: 0, downvotes: 0,
        });
      }
    }
    for (let i = 0; i < follows; i++) {
      await setDoc(doc(db, 'follows', `${me}_${authors[i]}`), { followerUid: me, followeeUid: authors[i] });
    }
  });
  const r = client(me, c);
  const rides = collection(r.db, 'rides');
  const following = (await r.getDocs(query(collection(r.db, 'follows'), where('followerUid', '==', me))))
    .docs.map((d) => d.data().followeeUid);
  if (following.length) await r.getDocs(query(collection(r.db, 'follows'), where('followeeUid', '==', me)));
  const pages = [
    r.getDocs(query(rides, where('audience', '==', 'public'), orderBy('createdAt', 'desc'), limit(20))),
    r.getDocs(query(rides, where('allowedUserIds', 'array-contains', me),
      where('audience', 'in', ['followers', 'mutual']), orderBy('createdAt', 'desc'), limit(20))),
    r.getDocs(query(rides, where('userId', '==', me), orderBy('createdAt', 'desc'), limit(20))),
  ];
  for (let i = 0; i < following.length; i += 30) {
    pages.push(r.getDocs(query(rides, where('userId', 'in', following.slice(i, i + 30)),
      where('audience', '==', 'public'), orderBy('createdAt', 'desc'), limit(20))));
  }
  for (const a of following) {
    pages.push(r.getDocs(query(rides, where('userId', '==', a),
      where('audience', 'in', ['followers']), orderBy('createdAt', 'desc'), limit(5)),
      2)); // rideVisibleTo: exists(follows edge) + exists(block)
  }
  await Promise.all(pages);
  await seed(async (db) => {
    for (let i = 0; i < 20; i++) await setDoc(doc(db, 'rides', `${authors[i]}-0`, 'votes', me), { value: 1, uid: me });
  });
  await r.getDocs(query(collectionGroup(r.db, 'votes'),
    where(documentId(), 'in', authors.slice(0, 20).map((a) => `rides/${a}-0/votes/${me}`))));
  return c;
}

function perTick(c, base, ticks) {
  return {
    attachReads: base.reads, attachWrites: base.writes,
    readsPerTick: (c.reads - base.reads) / ticks,
    writesPerTick: (c.writes - base.writes) / ticks,
    denied: c.denied,
  };
}

async function main() {
  env = await initializeTestEnvironment({
    projectId: 'throttleiq-loadtest',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  const out = { live: {}, group: {}, groupLegacy: {}, feed: {} };

  for (const v of [0, 1, 3]) out.live[v] = await liveShare(v, 12);
  for (const n of [3, 10, 20]) out.group[n] = await groupRide(`g${n}`, n, 6);
  for (const n of [3, 10, 20]) out.groupLegacy[n] = await groupRide(`l${n}`, n, 6, false);

  // 100 concurrent clients: five 20-rider group rides at once. Checks the
  // per-rider cost stays linear and no write is refused under contention.
  const runs = await Promise.all([0, 1, 2, 3, 4].map((i) => groupRide(`burst${i}`, 20, 6)));
  const sum = (k) => runs.reduce((s, x) => s + x[k], 0);
  out.burst100 = { readsPerTick: sum('readsPerTick'), writesPerTick: sum('writesPerTick'), denied: sum('denied') };

  out.rideSave60 = await rideSave(60);
  out.syncIdle = await syncIdle();
  for (const f of [0, 10, 30, 100]) out.feed[f] = await feedPage(f);

  // Self-checks: the shapes the app uses must pass the rules.
  for (const k of Object.keys(out.live)) assert.equal(out.live[k].denied, 0, `live ${k} denied`);
  for (const k of Object.keys(out.group)) assert.equal(out.group[k].denied, 0, `group ${k} denied`);
  for (const k of Object.keys(out.groupLegacy)) assert.equal(out.groupLegacy[k].denied, 0, `legacy group ${k} denied`);
  for (const k of Object.keys(out.feed)) assert.equal(out.feed[k].denied, 0, `feed ${k} denied`);
  assert.equal(out.rideSave60.writes, 1 + 8);
  assert.equal(out.syncIdle.reads, 4);

  console.log(JSON.stringify(out, null, 2));
  await env.cleanup();
  process.exit(0);
}

main().catch((e) => { console.error(e); process.exit(1); });
