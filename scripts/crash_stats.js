#!/usr/bin/env node
'use strict';

/**
 * crash_stats.js — honest numbers from shadow-mode crash detection.
 *
 * Reads `crashEvents` (the de-identified, opt-in research copies the app
 * writes when a rider answers "Did you fall?" or reports a missed fall) and
 * prints the figures defined in the crash-detection plan §11:
 *
 *   - detected crashes: tier 1+ events the rider confirmed (crash or fall)
 *   - missed falls:     falls riders reported that the detector never flagged
 *   - recall:           detected / (detected + missed)
 *   - false questions:  tier 1+ events answered "phone fell", "bump" or
 *                       "hard stop"
 *   - breakdowns by placement, surface, bike class, speed band, district
 *
 * Read-only. Unconfirmed candidates are never counted as crashes.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=throttleiqfb node crash_stats.js
 *   FIREBASE_PROJECT_ID=throttleiqfb node crash_stats.js --csv out.csv \
 *     --districts bd_districts.geojson
 *
 * --districts takes a GeoJSON FeatureCollection of Polygon/MultiPolygon
 * district boundaries (an open Bangladesh admin-boundaries dataset; check
 * its licence) and maps each event's geohash cell to a district by its
 * centre. Without it, events are grouped by 4-character geohash (~20 km).
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS like the other scripts here.
 */

const fs = require('fs');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const FALL_LABELS = new Set(['crash', 'fall']);
const FALSE_LABELS = new Set(['phone_fell', 'bump', 'hard_stop']);
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/** Centre of a geohash cell, or null for anything that isn't one. */
function decodeGeohash(hash) {
  if (typeof hash !== 'string' || hash.length === 0) return null;
  let lat = [-90, 90];
  let lng = [-180, 180];
  let even = true;
  for (const ch of hash.toLowerCase()) {
    const v = BASE32.indexOf(ch);
    if (v < 0) return null;
    for (let bit = 4; bit >= 0; bit--) {
      const range = even ? lng : lat;
      const mid = (range[0] + range[1]) / 2;
      if ((v >> bit) & 1) range[0] = mid;
      else range[1] = mid;
      even = !even;
    }
  }
  return { lat: (lat[0] + lat[1]) / 2, lng: (lng[0] + lng[1]) / 2 };
}

/** Ray casting over one GeoJSON ring ([lng, lat] pairs). */
function inRing(lat, lng, ring) {
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i];
    const [xj, yj] = ring[j];
    if (yi > lat !== yj > lat && lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

function inPolygon(lat, lng, rings) {
  if (!inRing(lat, lng, rings[0])) return false;
  return !rings.slice(1).some((hole) => inRing(lat, lng, hole));
}

/** The name of the district feature containing (lat, lng), or null. */
function districtOf(lat, lng, features) {
  for (const f of features || []) {
    const g = f.geometry || {};
    const polys = g.type === 'Polygon' ? [g.coordinates] : g.type === 'MultiPolygon' ? g.coordinates : [];
    if (polys.some((rings) => inPolygon(lat, lng, rings))) {
      const p = f.properties || {};
      return p.ADM2_EN || p.district || p.name || p.NAME_2 || 'unnamed';
    }
  }
  return null;
}

function speedBand(kmh) {
  if (typeof kmh !== 'number') return 'unknown';
  if (kmh < 10) return '<10 km/h';
  if (kmh < 25) return '10-25 km/h';
  if (kmh < 50) return '25-50 km/h';
  return '50+ km/h';
}

/**
 * The plan §11 figures for a list of crashEvents documents. [areaOf] maps
 * an event to its area label (district or geohash prefix).
 */
function summarize(events, areaOf = (e) => (e.geohash6 || '').slice(0, 4) || 'unknown') {
  const detected = events.filter((e) => FALL_LABELS.has(e.label) && e.detectedTier >= 1);
  const missed = events.filter((e) => e.label === 'missed');
  const falseQuestions = events.filter((e) => FALSE_LABELS.has(e.label) && e.detectedTier >= 1);
  const confirmedFalls = [...detected, ...missed];
  const by = (list, key) =>
    list.reduce((acc, e) => {
      const k = key(e) ?? 'unknown';
      acc[k] = (acc[k] || 0) + 1;
      return acc;
    }, {});
  const recall = confirmedFalls.length ? detected.length / confirmedFalls.length : null;
  return {
    answeredEvents: events.length,
    detectedCrashes: detected.length,
    missedFalls: missed.length,
    recall: recall === null ? null : Math.round(recall * 1000) / 10,
    falseQuestions: falseQuestions.length,
    unsure: events.filter((e) => e.label === 'unsure').length,
    areas: Object.keys(by(confirmedFalls, areaOf)).filter((a) => a !== 'unknown').length,
    fallsByArea: by(confirmedFalls, areaOf),
    fallsByPlacement: by(confirmedFalls, (e) => e.placement),
    fallsBySurface: by(confirmedFalls, (e) => e.surface),
    fallsByBikeClass: by(confirmedFalls, (e) => e.bikeClass),
    fallsBySpeed: by(confirmedFalls, (e) => speedBand(e.speedBeforeKmh)),
    detectedByTier: by(detected, (e) => `tier ${e.detectedTier}`),
    rulesVersions: by(events, (e) => e.rulesVersion),
  };
}

const CSV_FIELDS = ['id', 'label', 'detectedTier', 'reason', 'peakG', 'speedBeforeKmh', 'placement',
  'bikeClass', 'bikeCc', 'surface', 'severity', 'geohash6', 'hourLocal', 'weekday', 'platform',
  'rulesVersion', 'consentVersion', 'createdAt'];

function toCsv(events) {
  const cell = (v) => {
    const s = v === undefined || v === null ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [CSV_FIELDS.join(','), ...events.map((e) => CSV_FIELDS.map((f) => cell(e[f])).join(','))].join('\n') + '\n';
}

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  if (process.env.FIREBASE_PROJECT_ID !== EXPECTED_PROJECT_ID) {
    console.error(`FIREBASE_PROJECT_ID must be '${EXPECTED_PROJECT_ID}'.`);
    process.exit(1);
  }
  const admin = require('firebase-admin');
  admin.initializeApp({ projectId: EXPECTED_PROJECT_ID });
  const snap = await admin.firestore().collection('crashEvents').get();
  // ownerUid stays behind: these figures never need to know who.
  const events = snap.docs.map((d) => {
    const { ownerUid, ...rest } = d.data();
    void ownerUid;
    return { id: d.id, ...rest };
  });

  const districtsFile = arg('--districts');
  let areaOf;
  if (districtsFile) {
    const features = JSON.parse(fs.readFileSync(districtsFile, 'utf8')).features;
    areaOf = (e) => {
      const c = decodeGeohash(e.geohash6);
      return c ? districtOf(c.lat, c.lng, features) : null;
    };
  }
  console.log(JSON.stringify(summarize(events, areaOf), null, 2));

  const csv = arg('--csv');
  if (csv) {
    fs.writeFileSync(csv, toCsv(events));
    console.error(`Wrote ${events.length} rows to ${csv}`);
  }
}

module.exports = { decodeGeohash, districtOf, summarize, speedBand, toCsv };

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
