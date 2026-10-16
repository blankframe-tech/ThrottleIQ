'use strict';

/**
 * Partner API (src/partner-api) against the Firestore emulator: auth, ride
 * ingest (idempotent, scored against the existing pool), rider score, live
 * sessions, alerts with a signed webhook, and the road-stats fold.
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const { createHmac } = require('node:crypto');

const { db, rtdb, clearEmulators } = require('./setup');
const core = require('../../lib/partner-api/core');
const { route } = require('../../lib/partner-api');

const KEY = 'tiq_test_key_0123456789abcdef';
const SEG_A = 'wh0r3qs';
const SEG_B = 'wh0r3qt';

async function seedPartner({ webhook = true } = {}) {
  await clearEmulators();
  core.clearKeyCache();
  await db.doc('partners/maya').set({
    name: 'Maya Ride',
    active: true,
    ...(webhook ? { webhookUrl: 'https://ops.maya.example/hook', webhookSecret: 'whsec' } : {}),
  });
  await db.doc(`partnerKeys/${core.sha256(KEY)}`).set({ partnerId: 'maya', active: true });
  await db.doc('partners/other').set({ name: 'Other', active: true });
  await db.doc(`partnerKeys/${core.sha256(KEY + 'other')}`).set({ partnerId: 'other', active: true });
}

const call = (method, path, body, key = KEY, deps) =>
  route(db, { method, path, headers: { 'x-api-key': key }, body }, deps);

function rideBody(over = {}) {
  const end = new Date(Date.now() - 60_000);
  const start = new Date(end.getTime() - 30 * 60_000);
  return {
    rideId: 'r1',
    riderRef: 'mayabi-42',
    startedAt: start.toISOString(),
    endedAt: end.toISOString(),
    distanceKm: 17,
    pickupKm: 3,
    tripKm: 8,
    returnKm: 6,
    movingSeconds: 1500,
    avgSpeedKmh: 22,
    maxSpeedKmh: 48,
    hardBrakes: 1,
    rapidAccels: 0,
    highJerks: 0,
    overspeeds: 0,
    weatherCode: null,
    segments: [
      { segmentId: SEG_A, avgSpeedKmh: 25, pointCount: 12 },
      { segmentId: SEG_B, avgSpeedKmh: 75, pointCount: 6 },
    ],
    impacts: [{ tier: 1, reason: 'impact', peakAccelMs2: 30, speedBeforeKmh: 18, riderSaysFell: false }],
    ...over,
  };
}

test('auth: missing, unknown and revoked keys are 401', async () => {
  await seedPartner();
  assert.equal((await call('GET', '/v1/riders/x', null, '')).status, 401);
  assert.equal((await call('GET', '/v1/riders/x', null, 'not_a_real_key_000000000')).status, 401);
  await db.doc(`partnerKeys/${core.sha256(KEY)}`).update({ active: false });
  core.clearKeyCache();
  assert.equal((await call('GET', '/v1/riders/x')).status, 401);
});

test('ride ingest scores against the pool before adding to it, and is idempotent', async () => {
  await seedPartner();
  // Pool: both cells usually ridden around 30 km/h.
  for (const seg of [SEG_A, SEG_B]) {
    for (let i = 0; i < 10; i++) {
      await core.applySampleToStats(db, seg, { speedKmh: i % 2 ? 34 : 26, hour: 8, weatherCode: null });
    }
  }
  const body = rideBody();
  const first = await call('POST', '/v1/rides', body);
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(first.body.replayed, false);
  assert.equal(first.body.eventScore, 95);
  assert.equal(first.body.segmentsCompared, 2);
  assert.deepEqual(first.body.fasterThanUsual.map((f) => f.segmentId), [SEG_B]);
  assert.equal(first.body.score, 91);

  // Samples joined the shared pool in the app's shape, tagged by source.
  const sample = await db.doc(`roadSpeedSamples/${SEG_B}/samples/maya__r1`).get();
  assert.equal(sample.get('speedKmh'), 75);
  assert.equal(sample.get('source'), 'maya');
  assert.equal(typeof sample.get('hour'), 'number');
  assert.equal((await db.doc('partnerRides/maya__r1').get()).get('samplesWritten'), true);

  // Retry: same score back, rider counted once.
  const again = await call('POST', '/v1/rides', body);
  assert.equal(again.body.replayed, true);
  assert.equal(again.body.score, 91);
  const rider = await call('GET', '/v1/riders/mayabi-42');
  assert.equal(rider.status, 200);
  assert.equal(rider.body.rides, 1);
  assert.equal(rider.body.averageScore, 91);
  assert.equal(rider.body.distanceKm, 17);
  assert.equal(rider.body.fellReports, 0);

  // No raw rider id is stored anywhere.
  const stored = JSON.stringify((await db.doc('partnerRides/maya__r1').get()).data());
  assert.ok(!stored.includes('mayabi-42'));
});

test('a rideId reused by another rider is refused; bad payloads are 400', async () => {
  await seedPartner();
  assert.equal((await call('POST', '/v1/rides', rideBody())).status, 200);
  assert.equal((await call('POST', '/v1/rides', rideBody({ riderRef: 'someone-else' }))).status, 400);
  assert.equal((await call('POST', '/v1/rides', rideBody({ rideId: 'r2', segments: [{ segmentId: 'u4pruyd', avgSpeedKmh: 30, pointCount: 2 }] }))).status, 400);
});

test('rider score: 404 before any ride, and kept per partner', async () => {
  await seedPartner();
  assert.equal((await call('GET', '/v1/riders/mayabi-42')).status, 404);
  await call('POST', '/v1/rides', rideBody());
  assert.equal((await call('GET', '/v1/riders/mayabi-42', null, KEY + 'other')).status, 404);
});

test('live share: start, update, end; viewer-shaped doc; other partners locked out', async () => {
  await seedPartner();
  const start = await call('POST', '/v1/live', { riderRef: 'mayabi-42', lat: 23.78, lng: 90.41, speedMs: 5, batteryPct: 80 });
  assert.equal(start.status, 201);
  const { token, url } = start.body;
  assert.match(token, /^[A-Za-z0-9]{32}$/);
  assert.equal(url, `https://throttleiqfb.web.app/live/${token}`);
  let doc = await db.doc(`liveSessions/${token}`).get();
  assert.equal(doc.get('shareable'), true);
  assert.equal(doc.get('status'), 'riding');
  assert.ok(doc.get('expiresAt').toDate() > new Date());

  assert.equal((await call('POST', `/v1/live/${token}`, { lat: 23.79, lng: 90.42, speedMs: 0, status: 'paused' })).status, 200);
  doc = await db.doc(`liveSessions/${token}`).get();
  assert.equal(doc.get('lastLat'), 23.79);
  assert.equal(doc.get('status'), 'paused');

  assert.equal((await call('POST', `/v1/live/${token}`, { lat: 1, lng: 1, speedMs: 0 }, KEY + 'other')).status, 404);
  assert.equal((await call('DELETE', `/v1/live/${token}`)).status, 200);
  doc = await db.doc(`liveSessions/${token}`).get();
  assert.equal(doc.get('status'), 'completed');
  assert.equal(doc.get('active'), false);
  assert.equal((await call('POST', `/v1/live/${token}`, { lat: 1, lng: 1, speedMs: 0 })).status, 404);
});

test('SOS alert: stored, live link turns sos and stays sos, webhook signed', async () => {
  await seedPartner();
  const { token } = (await call('POST', '/v1/live', { riderRef: 'mayabi-42', lat: 23.78, lng: 90.41, speedMs: 5 })).body;
  const sent = [];
  const fakeFetch = async (url, init) => {
    sent.push({ url, init });
    return { ok: true, status: 200 };
  };
  const res = await call('POST', '/v1/alerts', { riderRef: 'mayabi-42', kind: 'sos', lat: 23.781, lng: 90.411, liveToken: token, rideId: 'r1' }, KEY, { fetch: fakeFetch });
  assert.equal(res.status, 201, JSON.stringify(res.body));
  assert.equal(res.body.delivery, 'delivered');

  assert.equal(sent.length, 1);
  const payload = JSON.parse(sent[0].init.body);
  assert.equal(payload.riderRef, 'mayabi-42');
  assert.equal(payload.kind, 'sos');
  assert.equal(payload.liveUrl, `https://throttleiqfb.web.app/live/${token}`);
  const sig = createHmac('sha256', 'whsec').update(sent[0].init.body).digest('hex');
  assert.equal(sent[0].init.headers['x-throttleiq-signature'], sig);

  const alert = await db.doc(`partnerAlerts/${res.body.alertId}`).get();
  assert.equal(alert.get('delivery'), 'delivered');
  assert.equal(alert.get('riderRef'), undefined);

  // A later "riding" position must not clear the SOS on the viewer.
  await call('POST', `/v1/live/${token}`, { lat: 23.78, lng: 90.41, speedMs: 3 });
  assert.equal((await db.doc(`liveSessions/${token}`).get()).get('status'), 'sos');
});

test('alert delivery failures are recorded, not thrown', async () => {
  await seedPartner();
  const down = async () => { throw new Error('ECONNREFUSED'); };
  const r1 = await call('POST', '/v1/alerts', { riderRef: 'mayabi-42', kind: 'crash' }, KEY, { fetch: down });
  assert.equal(r1.status, 201);
  assert.equal(r1.body.delivery, 'failed_network');
  const r500 = await call('POST', '/v1/alerts', { riderRef: 'mayabi-42', kind: 'unusualStop' }, KEY, { fetch: async () => ({ ok: false, status: 503 }) });
  assert.equal(r500.body.delivery, 'failed_http_503');
  assert.equal((await call('POST', '/v1/alerts', { riderRef: 'mayabi-42', kind: 'panic' })).status, 400);

  await seedPartner({ webhook: false });
  const none = await call('POST', '/v1/alerts', { riderRef: 'mayabi-42', kind: 'sos' });
  assert.equal(none.body.delivery, 'no_webhook');
});

test('applySampleToStats folds speeds into all / band / wet, ignoring junk', async () => {
  await clearEmulators();
  await core.applySampleToStats(db, SEG_A, { speedKmh: 30, hour: 8, weatherCode: null });
  await core.applySampleToStats(db, SEG_A, { speedKmh: 20, hour: 8, weatherCode: 63 });
  await core.applySampleToStats(db, SEG_A, { speedKmh: 'fast', hour: 8 });
  await core.applySampleToStats(db, SEG_A, { speedKmh: 30, hour: 99 });
  const st = (await db.doc(`roadSegmentStats/${SEG_A}`).get()).data();
  assert.deepEqual(st.all, { n: 2, sum: 50, sumSq: 1300 });
  assert.deepEqual(st.bands.morningPeak, { n: 2, sum: 50, sumSq: 1300 });
  assert.deepEqual(st.wet, { n: 1, sum: 20, sumSq: 400 });
});

test('deleting a rider erases her rides, score, alerts and links, and only hers', async () => {
  await seedPartner({ webhook: false });
  await call('POST', '/v1/rides', rideBody());
  await call('POST', '/v1/rides', rideBody({ rideId: 'r2' }));
  await call('POST', '/v1/rides', rideBody({ rideId: 'r3', riderRef: 'another-rider' }));
  const { token } = (await call('POST', '/v1/live', { riderRef: 'mayabi-42', lat: 23.78, lng: 90.41, speedMs: 0 })).body;
  await call('POST', '/v1/alerts', { riderRef: 'mayabi-42', kind: 'sos', liveToken: token });

  const res = await call('DELETE', '/v1/riders/mayabi-42');
  assert.equal(res.status, 200);
  assert.equal(res.body.deleted, 5); // 2 rides + 1 alert + 1 live + rider doc
  assert.equal((await call('GET', '/v1/riders/mayabi-42')).status, 404);
  assert.equal((await db.doc('partnerRides/maya__r1').get()).exists, false);
  assert.equal((await db.doc(`liveSessions/${token}`).get()).exists, false);
  assert.equal((await call('GET', '/v1/riders/another-rider')).status, 200);
  // Anonymous pool samples stay.
  assert.equal((await db.doc(`roadSpeedSamples/${SEG_A}/samples/maya__r1`).get()).exists, true);
});

test('unknown paths and methods are 404', async () => {
  await seedPartner();
  assert.equal((await call('GET', '/v1/rides')).status, 404);
  assert.equal((await call('POST', '/v2/rides', {})).status, 404);
  // The Hosting rewrite keeps its /api/partner prefix.
  assert.equal((await call('GET', '/api/partner/v1/riders/nobody')).status, 404);
  assert.equal((await call('GET', '/api/partner/v1/riders/nobody')).body.error, 'no rides for this rider yet');
});

test.after(async () => {
  await rtdb.app.delete();
});
