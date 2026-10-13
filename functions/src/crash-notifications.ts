import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { handleCrashNotification, runEscalationSweep } from './crash-core';

initializeApp();

const db = getFirestore();

/**
 * Triggered when a crash notification is created
 * Sends SMS/email to emergency contacts
 * Escalates if no ACK in 15 minutes
 *
 * The body, including the idempotency claim (issues §101.S5), is
 * `handleCrashNotification` in crash-core.ts.
 */
export const onCrashNotification = onDocumentCreated(
  'crashNotifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    await handleCrashNotification(db, snap.ref);
  }
);

/**
 * Escalation check: sends follow-up if no ACK after 15 min
 * Triggered by Pub/Sub scheduler
 *
 * Throws when any escalation (or the query) fails, so the scheduler records
 * a failed run; see `runEscalationSweep` in crash-core.ts.
 */
export const escalateCrashAlert = onSchedule(
  'every 15 minutes',
  async () => {
    await runEscalationSweep(db);
  }
);
