import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { lookup } from 'node:dns/promises';
import { BlockList, isIP } from 'node:net';
import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';
import {
  RideScore,
  RideUpload,
  SegmentStats,
  ValidationError,
  bdHour,
  bdWeekday,
  isWet,
  ref,
  scoreRide,
  tierOf,
  timeBand,
} from './scoring';

/**
 * Firestore half of the partner API, taking `db` (and `fetch`) as
 * parameters so test/emulator/partner-api.test.js can run it directly.
 *
 * Collections (all server-only; the rules' final catch-all denies clients):
 *   partnerKeys/{sha256(apiKey)}          → { partnerId, active }
 *   partners/{partnerId}                  → { name, active, webhookUrl?, webhookSecret? }
 *   partnerRides/{partnerId}__{rideId}    → ride summary, segments, impacts, score
 *   partnerRiders/{partnerId}__{riderKey} → running score per rider
 *   partnerAlerts/{auto}                  → SOS / crash / unusual-stop alerts
 *   partnerLive/{token}                   → { partnerId, riderKey } owner of a live link
 *   roadSegmentStats/{segmentId}          → pooled speed moments (trigger-owned)
 * plus the shared pools the app already uses: roadSpeedSamples and
 * liveSessions (the hosted viewer reads those unchanged).
 */

export interface Partner {
  id: string;
  name: string;
  webhookUrl?: string;
  webhookSecret?: string;
}

export class AuthError extends Error {}
export class ForbiddenError extends Error {}
export class NotFoundError extends Error {}
export class RateLimitError extends Error {}

export const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

/**
 * Per-partner key derived from the server-only Functions secret
 * PARTNER_RIDER_SECRET. Fails closed: no secret, no partner API.
 */
function partnerSecret(partnerId: string): Buffer {
  const master = process.env.PARTNER_RIDER_SECRET;
  if (!master || master.length < 32) throw new Error('PARTNER_RIDER_SECRET is not set');
  return createHmac('sha256', master).update(`partner:${partnerId}`).digest();
}

const keyed = (partnerId: string, label: string) =>
  createHmac('sha256', partnerSecret(partnerId)).update(label).digest('hex').slice(0, 32);

/**
 * A rider as stored: a keyed HMAC of the partner's own rider id, so
 * ThrottleIQ never holds Maya's ids, the same rider always maps to the same
 * key, and nobody without the server secret can reverse it by guessing ids.
 */
export const riderKeyOf = (partnerId: string, riderRef: string) => keyed(partnerId, `rider:${riderRef}`);

/** One road-pool sample id per (ride, cell): stable for retries; the id itself reveals no ride or rider. */
export const sampleIdOf = (partnerId: string, rideId: string, segmentId: string) =>
  keyed(partnerId, `sample:${rideId}:${segmentId}`);

// ── Rider tokens ───────────────────────────────────────────────────────────

export const RIDER_TOKEN_TTL_MS = 24 * 3600 * 1000;

const tokenSig = (partnerId: string, body: string) =>
  createHmac('sha256', partnerSecret(partnerId)).update(`token:${body}`).digest();

/**
 * A bearer token for ONE rider, minted by the partner's server with its API
 * key (`POST v1/riders/{riderRef}/token`) and handed to that rider's app.
 * Format `tiqr.<base64url {p, r, e}>.<base64url HMAC>`; stateless, so it
 * lives until `e` (revoke all of a partner's by deactivating the partner).
 */
export function mintRiderToken(partnerId: string, riderRef: string, now = Date.now()) {
  const e = now + RIDER_TOKEN_TTL_MS;
  const body = Buffer.from(JSON.stringify({ p: partnerId, r: riderRef, e })).toString('base64url');
  return { token: `tiqr.${body}.${tokenSig(partnerId, body).toString('base64url')}`, expiresAt: new Date(e).toISOString() };
}

export function verifyRiderToken(token: string, now = Date.now()): { partnerId: string; riderRef: string } {
  const bad = () => new AuthError('invalid or expired rider token');
  const parts = token.split('.');
  if (token.length > 1000 || parts.length !== 3 || parts[0] !== 'tiqr') throw bad();
  let claims: { p?: unknown; r?: unknown; e?: unknown };
  try {
    claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    throw bad();
  }
  const { p, r, e } = claims ?? {};
  if (typeof p !== 'string' || !/^[a-z0-9-]{2,32}$/.test(p) || typeof r !== 'string' || typeof e !== 'number') throw bad();
  const want = tokenSig(p, parts[1]);
  const got = Buffer.from(parts[2], 'base64url');
  if (got.length !== want.length || !timingSafeEqual(got, want) || e <= now) throw bad();
  return { partnerId: p, riderRef: r };
}

// ── Rate limits ────────────────────────────────────────────────────────────

export const KEY_RATE_PER_MIN = 1200;
export const RIDER_RATE_PER_MIN = 60;
const hits = new Map<string, { minute: number; n: number }>();

/** Test hook. */
export function clearRateLimits() {
  hits.clear();
}

/**
 * Fixed one-minute window per bucket (`key:<partnerId>`, `rider:<partnerId>:<riderKey>`).
 * shortcut: per instance, so the real cap is limit × maxInstances (20);
 * move to a Firestore/Redis counter if a partner needs a hard global quota.
 */
export function checkRate(bucket: string, limit: number, now = Date.now()) {
  const minute = Math.floor(now / 60_000);
  const h = hits.get(bucket);
  if (!h || h.minute !== minute) {
    if (hits.size > 50_000) hits.clear();
    hits.set(bucket, { minute, n: 1 });
    return;
  }
  if (++h.n > limit) throw new RateLimitError('rate limit exceeded, retry in a minute');
}

const keyCache = new Map<string, { partner: Partner; until: number }>();
const KEY_CACHE_MS = 5 * 60 * 1000;

/** Test hook: forget cached keys (a revoked key otherwise lives ≤ 5 min). */
export function clearKeyCache() {
  keyCache.clear();
}

/**
 * Resolves `x-api-key`. Only the key's SHA-256 is stored. Cached per
 * instance for 5 min, since live share calls this every 15 s per rider.
 */
export async function authenticate(db: Firestore, apiKey: string | undefined, now = Date.now()): Promise<Partner> {
  if (!apiKey || apiKey.length < 20 || apiKey.length > 200) throw new AuthError('missing or malformed API key');
  const hash = sha256(apiKey);
  const hit = keyCache.get(hash);
  if (hit && hit.until > now) return hit.partner;

  const key = await db.doc(`partnerKeys/${hash}`).get();
  if (!key.exists || key.get('active') !== true) throw new AuthError('unknown or revoked API key');
  const partner = await loadPartner(db, key.get('partnerId') as string);
  keyCache.set(hash, { partner, until: now + KEY_CACHE_MS });
  return partner;
}

async function loadPartner(db: Firestore, partnerId: string): Promise<Partner> {
  const doc = await db.doc(`partners/${partnerId}`).get();
  if (!doc.exists || doc.get('active') !== true) throw new AuthError('partner is not active');
  return {
    id: partnerId,
    name: (doc.get('name') as string) ?? partnerId,
    webhookUrl: doc.get('webhookUrl') ?? undefined,
    webhookSecret: doc.get('webhookSecret') ?? undefined,
  };
}

/** Resolves a rider bearer token to its (active) partner and rider. Cached like keys. */
export async function authenticateRider(db: Firestore, token: string, now = Date.now()) {
  const { partnerId, riderRef } = verifyRiderToken(token, now);
  const cacheKey = `partner:${partnerId}`;
  const hit = keyCache.get(cacheKey);
  const partner = hit && hit.until > now ? hit.partner : await loadPartner(db, partnerId);
  if (!hit || hit.until <= now) keyCache.set(cacheKey, { partner, until: now + KEY_CACHE_MS });
  return { partner, riderRef };
}

// ── Rides ──────────────────────────────────────────────────────────────────

export interface IngestResult extends RideScore {
  rideId: string;
  /** True when this rideId was already uploaded: the stored score comes back. */
  replayed: boolean;
}

const SAMPLE_BATCH = 400;

/** Reads the stats docs for [segmentIds], 300 refs per getAll. */
async function readStats(db: Firestore, segmentIds: string[]): Promise<Map<string, SegmentStats>> {
  const out = new Map<string, SegmentStats>();
  for (let i = 0; i < segmentIds.length; i += 300) {
    const refs = segmentIds.slice(i, i + 300).map((id) => db.doc(`roadSegmentStats/${id}`));
    if (refs.length === 0) continue;
    for (const snap of await db.getAll(...refs)) {
      if (snap.exists) out.set(snap.id, snap.data() as SegmentStats);
    }
  }
  return out;
}

/**
 * Adds the ride's segment speeds to the shared Dhaka pool, in the same shape
 * the ThrottleIQ app writes (plus `source`). Each cell gets its own keyed id
 * (sampleIdOf), so a retry overwrites instead of adding a second sample and
 * the stats trigger (onCreate) counts each one once. Samples carry no rider
 * or ride id and no stored per-trip id; `createdAt` is kept to the hour.
 */
async function writeSamples(db: Firestore, partnerId: string, ride: RideUpload) {
  const weekday = bdWeekday(ride.startedAt);
  const hour = bdHour(ride.startedAt);
  const createdAt = Timestamp.fromMillis(Math.floor(Date.now() / 3_600_000) * 3_600_000);
  for (let i = 0; i < ride.segments.length; i += SAMPLE_BATCH) {
    const batch = db.batch();
    for (const s of ride.segments.slice(i, i + SAMPLE_BATCH)) {
      batch.set(db.doc(`roadSpeedSamples/${s.segmentId}/samples/${sampleIdOf(partnerId, ride.rideId, s.segmentId)}`), {
        speedKmh: s.avgSpeedKmh,
        weekday,
        hour,
        weatherCode: ride.weatherCode,
        createdAt,
        source: partnerId,
      });
    }
    await batch.commit();
  }
}

/**
 * `POST /v1/rides`. Scores the ride against the pool *before* its own
 * samples join it, then records the ride and the rider's running score in
 * one transaction (so a retried upload is a no-op), then writes the samples.
 */
export async function ingestRide(db: Firestore, partner: Partner, ride: RideUpload): Promise<IngestResult> {
  const rideRef = db.doc(`partnerRides/${partner.id}__${ride.rideId}`);
  const riderKey = riderKeyOf(partner.id, ride.riderRef);
  const riderRef = db.doc(`partnerRiders/${partner.id}__${riderKey}`);

  const stats = await readStats(db, ride.segments.map((s) => s.segmentId));
  const score = scoreRide(ride, stats);

  const outcome = await db.runTransaction(async (tx) => {
    const [existing, rider] = await tx.getAll(rideRef, riderRef);
    if (existing.exists) {
      if (existing.get('riderKey') !== riderKey) {
        throw new ValidationError('rideId was already used by another rider');
      }
      return { replayed: true, score: existing.get('score') as RideScore, samplesWritten: existing.get('samplesWritten') === true };
    }
    tx.create(rideRef, {
      partnerId: partner.id,
      riderKey,
      rideId: ride.rideId,
      startedAt: Timestamp.fromDate(ride.startedAt),
      endedAt: Timestamp.fromDate(ride.endedAt),
      timeBand: timeBand(bdHour(ride.startedAt)),
      wet: isWet(ride.weatherCode),
      weatherCode: ride.weatherCode,
      distanceKm: ride.distanceKm,
      pickupKm: ride.pickupKm,
      tripKm: ride.tripKm,
      returnKm: ride.returnKm,
      movingSeconds: ride.movingSeconds,
      avgSpeedKmh: ride.avgSpeedKmh,
      maxSpeedKmh: ride.maxSpeedKmh,
      hardBrakes: ride.hardBrakes,
      rapidAccels: ride.rapidAccels,
      highJerks: ride.highJerks,
      overspeeds: ride.overspeeds,
      segments: ride.segments,
      impacts: ride.impacts,
      score,
      samplesWritten: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    const recent = ((rider.exists ? rider.get('recentScores') : []) as number[]).concat(score.score).slice(-20);
    tx.set(
      riderRef,
      {
        partnerId: partner.id,
        riderKey,
        rides: FieldValue.increment(1),
        scoreSum: FieldValue.increment(score.score),
        distanceKm: FieldValue.increment(ride.distanceKm),
        hardBrakes: FieldValue.increment(ride.hardBrakes),
        rapidAccels: FieldValue.increment(ride.rapidAccels),
        overspeeds: FieldValue.increment(ride.overspeeds),
        fellReports: FieldValue.increment(ride.impacts.filter((i) => i.riderSaysFell === true).length),
        recentScores: recent,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { replayed: false, score, samplesWritten: false };
  });

  // A crash between the transaction and here leaves samplesWritten false;
  // the partner's retry (replayed) finishes the job with the same ids.
  if (!outcome.samplesWritten) {
    await writeSamples(db, partner.id, ride);
    await rideRef.update({ samplesWritten: true });
  }
  return { ...outcome.score, rideId: ride.rideId, replayed: outcome.replayed };
}

/** `GET /v1/riders/{riderRef}`: a rider's running score with this partner. */
export async function riderScore(db: Firestore, partner: Partner, riderRefRaw: string) {
  const riderRef = ref({ riderRef: riderRefRaw }, 'riderRef');
  const doc = await db.doc(`partnerRiders/${partner.id}__${riderKeyOf(partner.id, riderRef)}`).get();
  if (!doc.exists) throw new NotFoundError('no rides for this rider yet');
  const rides = doc.get('rides') as number;
  const recent = (doc.get('recentScores') as number[]) ?? [];
  const avg = (doc.get('scoreSum') as number) / rides;
  const recentAvg = recent.length ? recent.reduce((a, b) => a + b, 0) / recent.length : avg;
  return {
    riderRef,
    rides,
    distanceKm: doc.get('distanceKm') as number,
    averageScore: Math.round(avg * 10) / 10,
    recentAverageScore: Math.round(recentAvg * 10) / 10,
    recentScores: recent,
    tier: tierOf(recentAvg),
    hardBrakes: doc.get('hardBrakes') as number,
    rapidAccels: doc.get('rapidAccels') as number,
    overspeeds: doc.get('overspeeds') as number,
    fellReports: doc.get('fellReports') as number,
  };
}

/**
 * `DELETE v1/riders/{riderRef}`: erases a rider's rides, running score,
 * alerts and live sessions. Her road-pool samples stay: they carry no rider
 * or ride id and no stored per-trip id (see writeSamples).
 */
export async function deleteRider(db: Firestore, partner: Partner, riderRefRaw: string) {
  const riderRef = ref({ riderRef: riderRefRaw }, 'riderRef');
  const riderKey = riderKeyOf(partner.id, riderRef);
  let deleted = 0;
  for (const collection of ['partnerRides', 'partnerAlerts', 'partnerLive']) {
    for (;;) {
      const page = await db
        .collection(collection)
        .where('partnerId', '==', partner.id)
        .where('riderKey', '==', riderKey)
        .limit(200)
        .get();
      if (page.empty) break;
      const batch = db.batch();
      page.docs.forEach((d) => {
        batch.delete(d.ref);
        // partnerLive/{token} is the server-only owner record of liveSessions/{token}.
        if (collection === 'partnerLive') batch.delete(db.doc(`liveSessions/${d.id}`));
      });
      await batch.commit();
      deleted += page.size;
    }
  }
  const rider = db.doc(`partnerRiders/${partner.id}__${riderKey}`);
  if ((await rider.get()).exists) {
    await rider.delete();
    deleted++;
  }
  return { riderRef, deleted };
}

// ── Live share ─────────────────────────────────────────────────────────────

export const LIVE_VIEWER_BASE = 'https://throttleiqfb.web.app/live';
export const LIVE_TTL_MS = 12 * 3600 * 1000;

export interface LivePosition {
  lat: number;
  lng: number;
  speedMs: number;
  batteryPct: number | null;
  status: 'riding' | 'paused';
}

export function parseLivePosition(body: unknown): LivePosition {
  const o = (typeof body === 'object' && body !== null ? body : {}) as Record<string, unknown>;
  const n = (k: string, min: number, max: number) => {
    const v = o[k];
    if (typeof v !== 'number' || !Number.isFinite(v) || v < min || v > max) {
      throw new ValidationError(`${k} must be a number in [${min}, ${max}]`);
    }
    return v;
  };
  const battery = o.batteryPct;
  if (battery != null && (typeof battery !== 'number' || battery < 0 || battery > 100)) {
    throw new ValidationError('batteryPct must be 0-100 or null');
  }
  const status = o.status ?? 'riding';
  if (status !== 'riding' && status !== 'paused') throw new ValidationError('status must be riding or paused');
  return {
    lat: n('lat', -90, 90),
    lng: n('lng', -180, 180),
    speedMs: n('speedMs', 0, 100),
    batteryPct: (battery as number | null | undefined) ?? null,
    status,
  };
}

/** 32 characters of [A-Za-z0-9], like the app's createLiveSessionToken. */
export function newLiveToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  // 248 = 4 × 62: rejecting bytes ≥ 248 keeps every character equally likely.
  let out = '';
  while (out.length < 32) {
    for (const b of randomBytes(48)) {
      if (b < 248 && out.length < 32) out += chars[b % 62];
    }
  }
  return out;
}

/**
 * `POST /v1/live`: a `liveSessions` doc in the shape the hosted viewer
 * already reads (`shareable: true`, Timestamp `expiresAt`), so the link
 * works in any browser with no app. Link holders can read that doc, so the
 * rider key lives only in the server-only `partnerLive/{token}`.
 */
export async function startLive(db: Firestore, partner: Partner, body: unknown, now = new Date()) {
  const o = (typeof body === 'object' && body !== null ? body : {}) as Record<string, unknown>;
  const riderRef = ref(o, 'riderRef');
  const pos = parseLivePosition(body);
  const token = newLiveToken();
  const expiresAt = new Date(now.getTime() + LIVE_TTL_MS);
  const batch = db.batch();
  batch.create(db.doc(`partnerLive/${token}`), {
    partnerId: partner.id,
    riderKey: riderKeyOf(partner.id, riderRef),
    createdAt: FieldValue.serverTimestamp(),
  });
  batch.create(db.doc(`liveSessions/${token}`), {
    token,
    uid: `partner:${partner.id}`,
    partnerId: partner.id,
    rideId: null,
    active: true,
    lastLat: pos.lat,
    lastLng: pos.lng,
    speedMs: pos.speedMs,
    batteryPct: pos.batteryPct,
    status: pos.status,
    shareable: true,
    updatedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(expiresAt),
  });
  await batch.commit();
  return { token, url: `${LIVE_VIEWER_BASE}/${token}`, expiresAt: expiresAt.toISOString() };
}

/**
 * The partner's live session [token]. With [riderRef] (a rider-token
 * caller), it must also be that rider's own link.
 */
async function ownedLive(db: Firestore, partner: Partner, token: string, riderRef?: string) {
  const unknown = () => new NotFoundError('unknown live session');
  if (!/^[A-Za-z0-9]{32}$/.test(token)) throw unknown();
  const doc = db.doc(`liveSessions/${token}`);
  const [snap, owner] = await db.getAll(doc, db.doc(`partnerLive/${token}`));
  if (!snap.exists || !owner.exists || owner.get('partnerId') !== partner.id) throw unknown();
  if (riderRef !== undefined && owner.get('riderKey') !== riderKeyOf(partner.id, riderRef)) throw unknown();
  return { doc, snap };
}

/** `POST /v1/live/{token}`: a position update. SOS/crash status is sticky. */
export async function updateLive(db: Firestore, partner: Partner, token: string, body: unknown, riderRef?: string) {
  const pos = parseLivePosition(body);
  const { doc, snap } = await ownedLive(db, partner, token, riderRef);
  if (snap.get('active') !== true) throw new NotFoundError('live session has ended');
  const current = snap.get('status');
  await doc.update({
    lastLat: pos.lat,
    lastLng: pos.lng,
    speedMs: pos.speedMs,
    batteryPct: pos.batteryPct,
    status: current === 'sos' || current === 'crash' ? current : pos.status,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * `DELETE /v1/live/{token}`: ends and revokes the link. The viewer's get
 * rule keys on `shareable`, not `active`, so clear it (as the app's own
 * teardown does) and drop her last position.
 */
export async function endLive(db: Firestore, partner: Partner, token: string, riderRef?: string) {
  const { doc } = await ownedLive(db, partner, token, riderRef);
  await doc.update({
    active: false,
    shareable: false,
    status: 'completed',
    lastLat: FieldValue.delete(),
    lastLng: FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

// ── Alerts (SOS, crash, unusual stop) ──────────────────────────────────────

export type AlertKind = 'sos' | 'crash' | 'unusualStop';

export interface AlertDeps {
  fetch: typeof fetch;
  /** Host → its addresses; defaults to DNS. Injected by tests. */
  resolve?: (host: string) => Promise<string[]>;
  now?: Date;
}

const PRIVATE = new BlockList();
for (const [net, bits] of [
  ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10], ['127.0.0.0', 8], ['169.254.0.0', 16],
  ['172.16.0.0', 12], ['192.0.0.0', 24], ['192.168.0.0', 16], ['198.18.0.0', 15], ['224.0.0.0', 3],
] as const) PRIVATE.addSubnet(net, bits, 'ipv4');
for (const [net, bits] of [
  ['::', 127], ['64:ff9b::', 96], ['fc00::', 7], ['fe80::', 10], ['ff00::', 8],
] as const) PRIVATE.addSubnet(net, bits, 'ipv6');
// No ::ffff:0:0/96 entry: BlockList already checks a mapped address against the
// ipv4 subnets above, and that entry would match every ipv4 address too.

/** True for a routable public unicast address; false for anything internal or not an IP. */
export function isPublicAddress(ip: string): boolean {
  const v = isIP(ip);
  if (v === 0) return false;
  return !PRIVATE.check(ip, v === 4 ? 'ipv4' : 'ipv6');
}

const dnsResolve = async (host: string) => (await lookup(host, { all: true })).map((a) => a.address);

/**
 * The webhook may only go to https on a host that resolves (now, on this
 * send) to public addresses only.
 * shortcut: fetch resolves again, so DNS rebinding between the two lookups
 * could still slip through; pin the address with an undici Agent if the
 * webhook URL ever becomes partner-editable.
 */
async function safeWebhook(url: string, resolve: (host: string) => Promise<string[]>): Promise<boolean> {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return false;
  }
  if (u.protocol !== 'https:' || u.username || u.password) return false;
  const host = u.hostname.replace(/^\[|\]$/g, '');
  try {
    const addrs = await resolve(host);
    return addrs.length > 0 && addrs.every(isPublicAddress);
  } catch {
    return false;
  }
}

/**
 * `POST /v1/alerts`. Records the alert, turns the rider's live link red,
 * and POSTs it to the partner's ops webhook, signed with HMAC-SHA256 of the
 * body (header `x-throttleiq-signature`). The webhook is the only place the
 * partner's own riderRef goes back out; it is never stored.
 *
 * Not a monitored emergency service: if the webhook is down the alert is
 * still stored and `delivery` says so, and the app must still offer the
 * rider SMS/999 itself.
 */
export async function raiseAlert(db: Firestore, partner: Partner, body: unknown, deps: AlertDeps, scopedRider?: string) {
  const o = (typeof body === 'object' && body !== null ? body : {}) as Record<string, unknown>;
  const riderRef = ref(o, 'riderRef');
  const kind = o.kind;
  if (kind !== 'sos' && kind !== 'crash' && kind !== 'unusualStop') {
    throw new ValidationError('kind must be sos, crash or unusualStop');
  }
  const coord = (k: string, lim: number) => {
    const v = o[k];
    if (v == null) return null;
    if (typeof v !== 'number' || !Number.isFinite(v) || Math.abs(v) > lim) throw new ValidationError(`${k} is invalid`);
    return v;
  };
  const lat = coord('lat', 90);
  const lng = coord('lng', 180);
  const liveToken = typeof o.liveToken === 'string' ? o.liveToken : null;
  const rideId = o.rideId == null ? null : ref(o, 'rideId');
  const now = deps.now ?? new Date();

  let liveUrl: string | null = null;
  if (liveToken) {
    const { doc } = await ownedLive(db, partner, liveToken, scopedRider);
    await doc.update({
      status: kind === 'crash' ? 'crash' : 'sos',
      ...(lat != null && lng != null ? { lastLat: lat, lastLng: lng } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });
    liveUrl = `${LIVE_VIEWER_BASE}/${liveToken}`;
  }

  const alertRef = db.collection('partnerAlerts').doc();
  await alertRef.set({
    partnerId: partner.id,
    riderKey: riderKeyOf(partner.id, riderRef),
    kind,
    lat,
    lng,
    liveToken,
    rideId,
    createdAt: Timestamp.fromDate(now),
    delivery: 'pending',
  });

  let delivery = 'no_webhook';
  if (partner.webhookUrl && partner.webhookSecret) {
    const payload = JSON.stringify({
      alertId: alertRef.id,
      kind,
      riderRef,
      rideId,
      lat,
      lng,
      liveUrl,
      createdAt: now.toISOString(),
    });
    try {
      if (!(await safeWebhook(partner.webhookUrl, deps.resolve ?? dnsResolve))) {
        delivery = 'failed_unsafe_webhook';
        console.warn('partner webhook refused (not public https)', partner.id);
      } else {
        const res = await deps.fetch(partner.webhookUrl, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'x-throttleiq-signature': createHmac('sha256', partner.webhookSecret).update(payload).digest('hex'),
          },
          body: payload,
          // A 3xx is a failed delivery: never re-send the signed body elsewhere.
          redirect: 'manual',
          signal: AbortSignal.timeout(5000),
        });
        delivery = res.status >= 200 && res.status < 300 ? 'delivered' : `failed_http_${res.status}`;
      }
    } catch (e) {
      delivery = 'failed_network';
      console.warn('partner webhook failed', partner.id, e);
    }
  }
  await alertRef.update({ delivery });
  return { alertId: alertRef.id, delivery, liveUrl };
}

// ── Segment stats (trigger) ────────────────────────────────────────────────

/**
 * Folds one new `roadSpeedSamples/{segmentId}/samples/*` doc into
 * `roadSegmentStats/{segmentId}` with atomic increments. Every sample goes
 * through here, the app's and partners' alike, so the pool has one owner.
 *
 * shortcut: Firestore triggers are at-least-once, so a rare retry counts a
 * sample twice; fine for a mean over hundreds, revisit if stats feed money.
 */
export async function applySampleToStats(
  db: Firestore,
  segmentId: string,
  data: { speedKmh?: unknown; hour?: unknown; weatherCode?: unknown },
) {
  const v = data.speedKmh;
  const hour = data.hour;
  if (typeof v !== 'number' || !Number.isFinite(v) || v < 0 || v > 200) return;
  if (typeof hour !== 'number' || hour < 0 || hour > 23) return;
  const inc = (x: number) => FieldValue.increment(x);
  const m = { n: inc(1), sum: inc(v), sumSq: inc(v * v) };
  await db.doc(`roadSegmentStats/${segmentId}`).set(
    {
      all: m,
      bands: { [timeBand(hour)]: m },
      ...(isWet(data.weatherCode as number | null) ? { wet: m } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}
