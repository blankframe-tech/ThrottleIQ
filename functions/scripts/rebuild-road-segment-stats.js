#!/usr/bin/env node
'use strict';

/**
 * rebuild-road-segment-stats.js: recompute every roadSegmentStats/{segmentId}
 * from all roadSpeedSamples/{segmentId}/samples/* (the app's and partners').
 *
 * Run once after first deploying `onRoadSpeedSampleCreated`, so the samples
 * written before the trigger existed are counted. It overwrites each stats
 * doc, so run it in a quiet hour: a sample landing mid-run may be counted
 * twice or not at all until the next rebuild.
 *
 * Usage (from functions/, after `npm run build`):
 *   export GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/throttleiqfb-admin.json
 *   node scripts/rebuild-road-segment-stats.js --project=throttleiqfb                         # dry run
 *   node scripts/rebuild-road-segment-stats.js --project=throttleiqfb --yes-i-really-mean-it  # writes
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { addSample } = require('../lib/partner-api/scoring');

async function main() {
  const project = (process.argv.find((a) => a.startsWith('--project=')) ?? '').slice(10);
  const write = process.argv.includes('--yes-i-really-mean-it');
  if (!project) throw new Error('--project is required');
  const db = getFirestore(initializeApp({ projectId: project }));

  const stats = new Map();
  let samples = 0;
  for await (const doc of db.collectionGroup('samples').stream()) {
    const segment = doc.ref.parent.parent;
    if (!segment || segment.parent.id !== 'roadSpeedSamples') continue;
    const d = doc.data();
    if (typeof d.speedKmh !== 'number' || typeof d.hour !== 'number') continue;
    stats.set(segment.id, addSample(stats.get(segment.id), d.speedKmh, d.hour, d.weatherCode));
    samples++;
  }
  console.log(`${samples} samples over ${stats.size} road cells on ${project}`);
  if (!write) {
    console.log('Dry run. Add --yes-i-really-mean-it to write.');
    return;
  }
  const writer = db.bulkWriter();
  for (const [id, st] of stats) {
    writer.set(db.doc(`roadSegmentStats/${id}`), { ...st, updatedAt: FieldValue.serverTimestamp() });
  }
  await writer.close();
  console.log(`wrote ${stats.size} stats docs`);
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
