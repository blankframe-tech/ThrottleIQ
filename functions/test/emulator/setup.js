'use strict';

/**
 * Shared setup for the emulator suite. Run only through
 * `npm run test:emulator`, which starts the Firestore + Database emulators
 * under the throwaway `demo-throttleiq` project (a `demo-` project id can
 * never reach a real backend), so FIRESTORE_EMULATOR_HOST and
 * FIREBASE_DATABASE_EMULATOR_HOST are set before this file loads.
 */

const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getDatabase } = require('firebase-admin/database');

const PROJECT_ID = 'demo-throttleiq';

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_DATABASE_EMULATOR_HOST) {
  throw new Error(
    'Emulator suite: FIRESTORE_EMULATOR_HOST / FIREBASE_DATABASE_EMULATOR_HOST ' +
      'are not set. Run it with `npm run test:emulator`, never against a live project.'
  );
}

const app =
  getApps()[0] ??
  initializeApp({
    projectId: PROJECT_ID,
    databaseURL: `http://${process.env.FIREBASE_DATABASE_EMULATOR_HOST}?ns=${PROJECT_ID}`,
  });

const db = getFirestore(app);
const rtdb = getDatabase(app);

/** Wipes the emulators' data so each file starts from nothing. */
async function clearEmulators() {
  const fsHost = process.env.FIRESTORE_EMULATOR_HOST;
  const res = await fetch(
    `http://${fsHost}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' }
  );
  if (!res.ok) throw new Error(`Firestore emulator clear failed: ${res.status}`);
  await rtdb.ref().set(null);
}

module.exports = { app, db, rtdb, clearEmulators };
