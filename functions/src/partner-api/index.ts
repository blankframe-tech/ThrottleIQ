import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import {
  AlertDeps,
  AuthError,
  ForbiddenError,
  KEY_RATE_PER_MIN,
  NotFoundError,
  Partner,
  RIDER_RATE_PER_MIN,
  RateLimitError,
  applySampleToStats,
  authenticate,
  authenticateRider,
  checkRate,
  deleteRider,
  endLive,
  ingestRide,
  mintRiderToken,
  raiseAlert,
  riderKeyOf,
  riderScore,
  startLive,
  updateLive,
} from './core';
import { ValidationError, parseRideUpload, ref } from './scoring';

if (getApps().length === 0) initializeApp();

/** Server-only key behind rider keys, sample ids and rider tokens (core.ts). */
const partnerRiderSecret = defineSecret('PARTNER_RIDER_SECRET');

/** Minimal request/response surface, so tests can call [route] directly. */
export interface Req {
  method: string;
  path: string;
  headers: Record<string, string | string[] | undefined>;
  body: unknown;
}
export interface Res {
  status: number;
  body: unknown;
}

/**
 * The partner API (Maya Ride first); see mayabi/API.md for the contract.
 *
 * Two callers:
 * - the partner's SERVER, with `x-api-key`: any of its riders. The key never
 *   ships in an app.
 * - a rider's APP, with `authorization: Bearer <rider token>` that the
 *   partner's server minted for her: only her own riderRef and live links.
 *
 *   POST   /v1/riders/{riderRef}/token  (key only) a 24 h rider token
 *   POST   /v1/rides              upload a finished ride → its score
 *   GET    /v1/riders/{riderRef}  a rider's running score
 *   DELETE /v1/riders/{riderRef}  erase a rider's rides, score, alerts, links
 *   POST   /v1/live               start a live-share link
 *   POST   /v1/live/{token}       position update
 *   DELETE /v1/live/{token}       end the link
 *   POST   /v1/alerts             SOS / crash / unusual stop → partner webhook
 *
 * Rate limits: KEY_RATE_PER_MIN per partner, RIDER_RATE_PER_MIN per rider.
 */
export async function route(db: FirebaseFirestore.Firestore, req: Req, deps: AlertDeps = { fetch }): Promise<Res> {
  try {
    const header = (name: string) => {
      const v = req.headers[name];
      return Array.isArray(v) ? v[0] : v;
    };
    const bearer = /^Bearer (\S+)$/.exec(header('authorization') ?? '')?.[1];
    let partner: Partner;
    let scoped: string | undefined; // the only riderRef a rider token may touch
    if (bearer !== undefined && header('x-api-key') === undefined) {
      ({ partner, riderRef: scoped } = await authenticateRider(db, bearer));
    } else {
      partner = await authenticate(db, header('x-api-key'));
    }
    checkRate(`key:${partner.id}`, KEY_RATE_PER_MIN);
    /** Checks a riderRef the caller named: her own for a rider token, and rate-limited per rider. */
    const riderRate = (riderRef: string) =>
      checkRate(`rider:${partner.id}:${riderKeyOf(partner.id, riderRef)}`, RIDER_RATE_PER_MIN);
    // A rider token counts against its rider on every call, live updates included.
    if (scoped !== undefined) riderRate(scoped);
    const rider = (riderRef: unknown) => {
      if (typeof riderRef !== 'string') return; // the handler's own validation answers 400
      if (scoped === undefined) riderRate(riderRef);
      else if (riderRef !== scoped) throw new ForbiddenError('this token is for another rider');
    };
    const bodyRider = () => rider((req.body as Record<string, unknown> | null)?.riderRef);

    // Reached directly (/v1/...) or through the Hosting rewrite
    // (https://throttleiqfb.web.app/api/partner/v1/...), which keeps the path.
    const parts = req.path.split('/').filter(Boolean);
    if (parts[0] === 'api' && parts[1] === 'partner') parts.splice(0, 2);
    if (parts[0] !== 'v1') throw new NotFoundError('unknown path');
    const [, resource, rawId, sub] = parts;
    const id = rawId === undefined ? undefined : decodeURIComponent(rawId);
    const m = req.method;
    if (parts.length > (sub === undefined ? 3 : 4)) throw new NotFoundError('unknown path');

    if (resource === 'riders' && id && sub === 'token' && m === 'POST') {
      if (scoped !== undefined) throw new ForbiddenError('rider tokens are minted with the partner key');
      rider(id);
      return { status: 201, body: mintRiderToken(partner.id, ref({ riderRef: id }, 'riderRef')) };
    }
    if (sub !== undefined) throw new NotFoundError('unknown path');
    if (resource === 'rides' && !id && m === 'POST') {
      bodyRider();
      return { status: 200, body: await ingestRide(db, partner, parseRideUpload(req.body, new Date())) };
    }
    if (resource === 'riders' && id && m === 'GET') {
      rider(id);
      return { status: 200, body: await riderScore(db, partner, id) };
    }
    if (resource === 'riders' && id && m === 'DELETE') {
      rider(id);
      return { status: 200, body: await deleteRider(db, partner, id) };
    }
    if (resource === 'live' && !id && m === 'POST') {
      bodyRider();
      return { status: 201, body: await startLive(db, partner, req.body) };
    }
    if (resource === 'live' && id && m === 'POST') {
      await updateLive(db, partner, id, req.body, scoped);
      return { status: 200, body: { ok: true } };
    }
    if (resource === 'live' && id && m === 'DELETE') {
      await endLive(db, partner, id, scoped);
      return { status: 200, body: { ok: true } };
    }
    if (resource === 'alerts' && !id && m === 'POST') {
      bodyRider();
      return { status: 201, body: await raiseAlert(db, partner, req.body, deps, scoped) };
    }
    throw new NotFoundError('unknown path');
  } catch (e) {
    if (e instanceof AuthError) return { status: 401, body: { error: e.message } };
    if (e instanceof ForbiddenError) return { status: 403, body: { error: e.message } };
    if (e instanceof RateLimitError) return { status: 429, body: { error: e.message } };
    if (e instanceof ValidationError) return { status: 400, body: { error: e.message } };
    if (e instanceof NotFoundError) return { status: 404, body: { error: e.message } };
    if (e instanceof URIError) return { status: 400, body: { error: 'bad path encoding' } };
    console.error('partnerApi failed', e);
    return { status: 500, body: { error: 'internal error' } };
  }
}

export const partnerApi = onRequest({ maxInstances: 20, secrets: [partnerRiderSecret] }, async (req, res) => {
  const out = await route(getFirestore(), {
    method: req.method,
    path: req.path,
    headers: req.headers,
    body: req.body,
  });
  res.status(out.status).json(out.body);
});

/** Keeps roadSegmentStats in step with every new road-speed sample. */
export const onRoadSpeedSampleCreated = onDocumentCreated(
  'roadSpeedSamples/{segmentId}/samples/{sampleId}',
  async (event) => {
    const data = event.data?.data();
    if (data) await applySampleToStats(getFirestore(), event.params.segmentId, data);
  },
);
