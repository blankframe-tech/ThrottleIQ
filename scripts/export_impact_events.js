#!/usr/bin/env node
'use strict';

/**
 * export_impact_events.js — pull shadow-mode impacts for calibration.
 *
 * Reads every `users/{uid}/impactEvents/{id}` (the riders' private copies,
 * with their sensor windows) and writes, into --out:
 *   - impact_events.csv: one row per impact, the rider as a salted hash
 *   - windows/<id>.tiqw.gz: the gzip'd sensor window, when --windows is set
 *     (format: ImpactWindowRecorder in the app, "TIQW" v1)
 *
 * Read-only: nothing in Firestore changes. The output holds sensor data and
 * rough positions of real riders — keep it off git and delete it after use.
 *
 * Usage:
 *   FIREBASE_PROJECT_ID=throttleiqfb node export_impact_events.js --out /tmp/impacts \
 *     [--since 2026-10-01] [--windows] [--salt <secret>]
 *
 * Requires GOOGLE_APPLICATION_CREDENTIALS like the other scripts here.
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const EXPECTED_PROJECT_ID = 'throttleiqfb';
const FIELDS = ['id', 'rider', 'rideId', 'at', 'tier', 'reason', 'peakUserG', 'peakRawG',
  'freefallMs', 'rotationDeg', 'orientationChangeDeg', 'stillAfter', 'resumedAfter',
  'speedBeforeMs', 'speedAfterMs', 'gpsGapS', 'placement', 'appForeground', 'charging',
  'vibrationRms', 'sampleRateHz', 'label', 'labelSource', 'labeledAt', 'surface', 'severity',
  'hasWindow', 'createdAt'];

/** Flattens one impactEvents document into a CSV record. */
function toRecord(id, uid, d, salt) {
  const rider = crypto.createHash('sha256').update(`${salt}:${uid}`).digest('hex').slice(0, 12);
  const detail = d.labelDetail || {};
  return {
    ...d,
    id,
    rider,
    surface: detail.surface,
    severity: detail.severity,
    hasWindow: d.imu ? 1 : 0,
  };
}

function toCsvRow(rec) {
  return FIELDS.map((f) => {
    const v = rec[f];
    const s = v === undefined || v === null ? '' : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(',');
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
  const out = arg('--out');
  if (!out) {
    console.error('--out <dir> is required.');
    process.exit(1);
  }
  const since = arg('--since');
  const salt = arg('--salt') || crypto.randomBytes(8).toString('hex');
  const withWindows = process.argv.includes('--windows');

  const admin = require('firebase-admin');
  admin.initializeApp({ projectId: EXPECTED_PROJECT_ID });
  const snap = await admin.firestore().collectionGroup('impactEvents').get();

  fs.mkdirSync(path.join(out, 'windows'), { recursive: true });
  const rows = [FIELDS.join(',')];
  let windows = 0;
  for (const doc of snap.docs) {
    const d = doc.data();
    if (since && (d.at || '') < since) continue;
    const uid = doc.ref.parent.parent.id;
    rows.push(toCsvRow(toRecord(doc.id, uid, d, salt)));
    if (withWindows && d.imu) {
      fs.writeFileSync(path.join(out, 'windows', `${doc.id}.tiqw.gz`), d.imu.toUint8Array());
      windows++;
    }
  }
  fs.writeFileSync(path.join(out, 'impact_events.csv'), rows.join('\n') + '\n');
  console.error(`Exported ${rows.length - 1} impacts (${windows} windows) to ${out}`);
}

module.exports = { toRecord, toCsvRow, FIELDS };

if (require.main === module) {
  main().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
