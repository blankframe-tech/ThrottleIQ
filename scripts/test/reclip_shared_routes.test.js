'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const R = require('../oneoff/reclip_shared_routes.js');

const M_PER_DEG = 111320;

/** A seeded PRNG (mulberry32) so failures reproduce. */
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 2 ** 32;
  };
}

/** ~3 km out of `home` on a random, gently wandering heading, a point every 15 m. */
function rideFrom(home, rand) {
  const mPerDegLng = M_PER_DEG * Math.cos((home.lat * Math.PI) / 180);
  let heading = rand() * 2 * Math.PI;
  let x = 0;
  let y = 0;
  const pts = [home];
  for (let k = 0; k < 200; k++) {
    heading += (rand() - 0.5) * 0.15;
    x += 15 * Math.sin(heading);
    y += 15 * Math.cos(heading);
    pts.push({ lat: home.lat + y / M_PER_DEG, lng: home.lng + x / mPerDegLng });
  }
  return pts;
}

/** Old builds: every point within r of either end dropped, r = 200 + seed % 150. */
function oldClip(pts, seed) {
  const r = 200 + (seed % 150);
  const hidden = (p) => R.haversine(p, pts[0]) <= r || R.haversine(p, pts[pts.length - 1]) <= r;
  let i = 0;
  while (i < pts.length && hidden(pts[i])) i++;
  let j = pts.length - 1;
  while (j >= i && hidden(pts[j])) j--;
  return pts.slice(i, j + 1);
}

/** Algebraic (Kasa) least-squares circle fit; returns the centre. */
function fitCentre(pts) {
  const { lat: lat0, lng: lng0 } = pts[0];
  const mPerDegLng = M_PER_DEG * Math.cos((lat0 * Math.PI) / 180);
  const a = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]];
  for (const p of pts) {
    const x = (p.lng - lng0) * mPerDegLng;
    const y = (p.lat - lat0) * M_PER_DEG;
    const row = [x, y, 1];
    const rhs = -(x * x + y * y);
    for (let i = 0; i < 3; i++) {
      for (let j = 0; j < 3; j++) a[i][j] += row[i] * row[j];
      a[i][3] += row[i] * rhs;
    }
  }
  for (let c = 0; c < 3; c++) {
    let piv = c;
    for (let r = c + 1; r < 3; r++) if (Math.abs(a[r][c]) > Math.abs(a[piv][c])) piv = r;
    [a[c], a[piv]] = [a[piv], a[c]];
    for (let r = 0; r < 3; r++) {
      if (r === c || a[c][c] === 0) continue;
      const f = a[r][c] / a[c][c];
      for (let k = c; k < 4; k++) a[r][k] -= f * a[c][k];
    }
  }
  const d = a[0][3] / a[0][0];
  const e = a[1][3] / a[1][1];
  return { lat: lat0 + -e / 2 / M_PER_DEG, lng: lng0 + -d / 2 / mPerDegLng };
}

/** Share of 300 riders whose home a 6-share circle fit misses by > 100 m. */
function missRate(shareOf) {
  const rand = rng(42);
  let far = 0;
  const riders = 300;
  for (let k = 0; k < riders; k++) {
    const seed = crypto.randomInt(0, 2 ** 31);
    const home = { lat: 23.7 + rand() * 0.2, lng: 90.35 + rand() * 0.2 };
    const firsts = [];
    for (let s = 0; s < 6; s++) firsts.push(shareOf(rideFrom(home, rand), seed)[0]);
    if (R.haversine(fitCentre(firsts), home) > 100) far++;
  }
  return far / riders;
}

test('the old clip is triangulable (sanity check of the attack)', () => {
  assert.ok(missRate((ride, seed) => oldClip(ride, seed)) < 0.2);
});

test('re-clipped from the full track: >= 95% of fits miss home by > 100 m', () => {
  const rate = missRate((ride, seed) => R.reclip({ stored: oldClip(ride, seed), track: ride, seed }).polyline);
  assert.ok(rate >= 0.95, `miss rate ${rate}`);
});

test('re-clipped from the stored line only: >= 95% of fits miss home by > 100 m', () => {
  const rate = missRate((ride, seed) => {
    const out = R.reclip({ stored: oldClip(ride, seed), seed });
    assert.equal(out.source, 'stored');
    return out.polyline;
  });
  assert.ok(rate >= 0.95, `miss rate ${rate}`);
});

test('no re-clipped point is within 200 m of the true ends', () => {
  const rand = rng(7);
  for (let k = 0; k < 200; k++) {
    const seed = crypto.randomInt(0, 2 ** 31);
    const ride = rideFrom({ lat: 23.8, lng: 90.4 }, rand);
    for (const track of [ride, []]) {
      for (const p of R.reclip({ stored: oldClip(ride, seed), track, seed }).polyline) {
        assert.ok(R.haversine(p, ride[0]) > 200);
        assert.ok(R.haversine(p, ride[ride.length - 1]) > 200);
      }
    }
  }
});

test('decoy, radius and clip match the app clipper', () => {
  for (const seed of [0, 7, 149, 150, 10649, 10650, 2 ** 31 - 1]) {
    const off = R.offsetMetersFor(seed);
    assert.ok(off >= 130 && off <= 200);
    assert.ok(R.bearingFor(seed) >= -180 && R.bearingFor(seed) < 180);
    assert.ok(R.radiusFor(seed) - off >= 200);
    const end = { lat: 23.8, lng: 90.4 };
    assert.ok(Math.abs(R.haversine(end, R.hiddenCentre(end, seed)) - off) < 1);
  }
  // Same numbers as privacy_zone_clipper.dart for one seed.
  assert.equal(R.offsetMetersFor(123456789), 130 + (Math.floor(123456789 / 150) % 71));
  assert.equal(R.radiusFor(123456789), R.offsetMetersFor(123456789) + 200 + (123456789 % 150));
  assert.deepEqual(R.clipPolyline([{ lat: 0, lng: 0 }, { lat: 0, lng: 0.001 }], 1), []);
});

test('the track decoder sorts chunks by index and drops a partial block', () => {
  const pts = R.decodeTrack([
    { index: 1, points: [3, 4, 0, 0, 0, 9] },
    { index: 0, points: [1, 2, 0, 0, 0] },
  ]);
  assert.deepEqual(pts, [{ lat: 1, lng: 2 }, { lat: 3, lng: 4 }]);
});

test('simplify keeps the result a subset, ends kept, under the cap', () => {
  const line = Array.from({ length: 5000 }, (_, i) => ({ lat: i * 1e-4, lng: Math.sin(i) * 1e-3 }));
  const out = R.simplifyPolyline(line);
  assert.ok(out.length <= 1000);
  assert.equal(out[0], line[0]);
  assert.equal(out[out.length - 1], line[line.length - 1]);
  const set = new Set(line);
  assert.ok(out.every((p) => set.has(p)));
});

test('readPolyline drops malformed points', () => {
  assert.deepEqual(R.readPolyline([{ lat: 1, lng: 2 }, { lat: 'x' }, null]), [{ lat: 1, lng: 2 }]);
  assert.deepEqual(R.readPolyline(undefined), []);
});

test('--before scopes by createdAt; undated docs count as old', () => {
  const before = Date.parse('2026-11-10T00:00:00+06:00');
  assert.equal(R.inScope(new Date('2026-09-01'), before), true);
  assert.equal(R.inScope(new Date('2026-11-11'), before), false);
  assert.equal(R.inScope({ toMillis: () => before - 1 }, before), true);
  assert.equal(R.inScope(undefined, before), true);
  assert.equal(R.inScope(new Date('2026-11-11'), null), true);
});

test('dry run is the default; --apply needs --before and --backup', () => {
  const o = R.parseArgs(['--service-account=/k.json']);
  assert.equal(o.apply, false);
  assert.equal(o.before, null);
  assert.throws(() => R.parseArgs(['--apply']), /--before/);
  assert.throws(() => R.parseArgs(['--apply', '--before=2026-11-10']), /--backup/);
  assert.equal(R.parseArgs(['--apply', '--before=2026-11-10', '--backup=b.json']).apply, true);
  assert.throws(() => R.parseArgs(['--before=10/11/2026']), /YYYY-MM-DD/);
  assert.throws(() => R.parseArgs(['--aply']), /Unknown argument/);
});
