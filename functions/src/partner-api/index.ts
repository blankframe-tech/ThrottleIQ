import { onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import {
  AuthError,
  NotFoundError,
  applySampleToStats,
  authenticate,
  deleteRider,
  endLive,
  ingestRide,
  raiseAlert,
  riderScore,
  startLive,
  updateLive,
} from './core';
import { ValidationError, parseRideUpload } from './scoring';

if (getApps().length === 0) initializeApp();

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
 * The partner API (Maya Ride first). Partner apps or servers call it with
 * `x-api-key`; see mayabi/API.md for the contract.
 *
 *   POST   /v1/rides              upload a finished ride → its score
 *   GET    /v1/riders/{riderRef}  a rider's running score
 *   DELETE /v1/riders/{riderRef}  erase a rider's rides, score, alerts, links
 *   POST   /v1/live               start a live-share link
 *   POST   /v1/live/{token}       position update
 *   DELETE /v1/live/{token}       end the link
 *   POST   /v1/alerts             SOS / crash / unusual stop → partner webhook
 *
 * shortcut: no per-key rate limit; add one (e.g. a token bucket in
 * partners/{id}) before a second partner or a public key is issued.
 */
export async function route(db: FirebaseFirestore.Firestore, req: Req, deps = { fetch }): Promise<Res> {
  try {
    const key = req.headers['x-api-key'];
    const partner = await authenticate(db, Array.isArray(key) ? key[0] : key);
    // Reached directly (/v1/...) or through the Hosting rewrite
    // (https://throttleiqfb.web.app/api/partner/v1/...), which keeps the path.
    const parts = req.path.split('/').filter(Boolean);
    if (parts[0] === 'api' && parts[1] === 'partner') parts.splice(0, 2);
    if (parts[0] !== 'v1') throw new NotFoundError('unknown path');
    const [, resource, id] = parts;
    const m = req.method;

    if (resource === 'rides' && !id && m === 'POST') {
      return { status: 200, body: await ingestRide(db, partner, parseRideUpload(req.body, new Date())) };
    }
    if (resource === 'riders' && id && m === 'GET') {
      return { status: 200, body: await riderScore(db, partner, decodeURIComponent(id)) };
    }
    if (resource === 'riders' && id && m === 'DELETE') {
      return { status: 200, body: await deleteRider(db, partner, decodeURIComponent(id)) };
    }
    if (resource === 'live' && !id && m === 'POST') {
      return { status: 201, body: await startLive(db, partner, req.body) };
    }
    if (resource === 'live' && id && m === 'POST') {
      await updateLive(db, partner, id, req.body);
      return { status: 200, body: { ok: true } };
    }
    if (resource === 'live' && id && m === 'DELETE') {
      await endLive(db, partner, id);
      return { status: 200, body: { ok: true } };
    }
    if (resource === 'alerts' && !id && m === 'POST') {
      return { status: 201, body: await raiseAlert(db, partner, req.body, deps) };
    }
    throw new NotFoundError('unknown path');
  } catch (e) {
    if (e instanceof AuthError) return { status: 401, body: { error: e.message } };
    if (e instanceof ValidationError) return { status: 400, body: { error: e.message } };
    if (e instanceof NotFoundError) return { status: 404, body: { error: e.message } };
    console.error('partnerApi failed', e);
    return { status: 500, body: { error: 'internal error' } };
  }
}

export const partnerApi = onRequest({ maxInstances: 20 }, async (req, res) => {
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
