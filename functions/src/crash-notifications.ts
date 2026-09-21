import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';

initializeApp();

const db = getFirestore();

/**
 * Whether crash-alert delivery is actually wired to a provider.
 *
 * FALSE means `sendContactNotification` builds the message and sends nothing.
 * It gates the status this function writes: while it is false a notification
 * settles at `mock_not_sent`, NOT at `contacted`, because `contacted` is read
 * by `escalateCrashAlert` (and by any future dashboard) as "a human was
 * reached" — and nobody was. Flip this to true in the same change that adds
 * the Twilio/SendGrid call, never before. See issues_open.md §81.2.
 */
const DELIVERY_IMPLEMENTED = false;

interface CrashNotification {
  uid: string;
  rideId: string;
  timestamp: string;
  lastLat?: number;
  lastLng?: number;
  /**
   * `mock_not_sent` is a terminal state: the alert was processed, contacts
   * were resolved, and no message left the building. It is deliberately NOT
   * `contacted`, and `escalateCrashAlert` deliberately does not pick it up —
   * escalating something that was never sent in the first place would just
   * not-send it a second time.
   */
  status:
    | 'pending'
    | 'contacted'
    | 'mock_not_sent'
    | 'acknowledged'
    | 'escalated';
}

interface EmergencyContact {
  id: string;
  name: string;
  phone: string;
  email?: string;
}

/**
 * Triggered when a crash notification is created
 * Sends SMS/email to emergency contacts
 * Escalates if no ACK in 15 minutes
 */
export const onCrashNotification = onDocumentCreated(
  'crashNotifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const notification = snap.data() as CrashNotification;
    const { uid, rideId, lastLat, lastLng } = notification;

    try {
      // Fetch user's emergency contacts
      const contactsSnapshot = await db
        .collection('users')
        .doc(uid)
        .collection('emergencyContacts')
        .get();

      if (contactsSnapshot.empty) {
        console.log(`No emergency contacts found for user ${uid}`);
        return;
      }

      // `id` is the document id, NOT a field in the document — the client
      // writes only {name, phone, email, createdAt} (see
      // emergency_contacts_provider.dart). Spreading doc.data() alone left
      // `contact.id` undefined, and the Admin SDK rejects an undefined field
      // value, so the notificationLog write below threw and took the whole
      // handler down with it on the first real crash. issues_open.md §81.2.
      const contacts = contactsSnapshot.docs.map(
        (doc) => ({ id: doc.id, ...doc.data() }) as EmergencyContact
      );

      // Resolved once, not per contact: the message addresses the rider by
      // name. Previously it interpolated the raw Firebase uid, which would
      // have texted a contact something like "your emergency contact
      // 8f2c...e41 may have crashed".
      const riderName = await lookUpRiderName(uid);

      for (const contact of contacts) {
        await sendContactNotification(
          contact,
          uid,
          riderName,
          rideId,
          lastLat,
          lastLng
        );
      }

      await snap.ref.update({
        status: DELIVERY_IMPLEMENTED ? 'contacted' : 'mock_not_sent',
        contactedAt: new Date().toISOString(),
        contactsResolved: contacts.length,
      });
    } catch (error) {
      console.error(`Error processing crash notification: ${error}`);
      throw error;
    }
  }
);

/**
 * Send notification to a contact via SMS or email.
 * MOCK: Replace with actual Twilio/SendGrid integration.
 *
 * Neither the message content built below nor any contact PII is logged or
 * persisted (issues §24.8). This function was previously logging
 * `contact.phone`/`contact.email` directly via console.log, and the SMS body
 * it logged also carried the crash's GPS coordinates — third-party PII the
 * contact never consented to ThrottleIQ having, landing in Cloud Logging
 * (retained by default, visible to anyone with project Viewer) and in
 * `notificationLog`. The message bodies still exist here (a real
 * Twilio/SendGrid integration will need exactly this content to actually
 * send something) but are only ever handed to that future call, never to
 * console.log or Firestore.
 */
async function sendContactNotification(
  contact: EmergencyContact,
  uid: string,
  riderName: string,
  rideId: string,
  lastLat?: number,
  lastLng?: number
): Promise<void> {
  // Explicit null checks — a truthiness check would treat a legitimate 0
  // coordinate (equator / prime meridian) as "no location".
  const location = lastLat != null && lastLng != null
    ? `https://maps.google.com/?q=${lastLat},${lastLng}`
    : 'Location unavailable';

  // MOCK SMS message — built for a future Twilio call, deliberately never
  // logged (see doc comment above).
  const smsMessage = `ALERT: ${contact.name}, your emergency contact ${riderName} may have crashed. ` +
    `Location: ${location}. Reply CONFIRM if they are OK.`;

  // MOCK email subject/body — same "built for later, never logged" rule.
  const emailSubject = `ThrottleIQ Emergency Alert - Potential Crash`;
  const emailBody = `
Dear ${contact.name},

You are listed as an emergency contact on ThrottleIQ. We detected a potential motorcycle crash.

Rider: ${riderName}
Location: ${location}
Time: ${new Date().toISOString()}

If you can confirm they are OK, please respond to this email or call them directly.

If no confirmation is received within 15 minutes, we will send a follow-up alert.

Stay safe,
ThrottleIQ Safety Team
  `;
  // Referenced (not logged) so a real Twilio/SendGrid call has something to
  // send once this MOCK is replaced — see this function's doc comment.
  void smsMessage;
  void emailSubject;
  void emailBody;

  // No PII, no message content, no GPS — just enough to know an attempt was
  // made and for which contact record, without saying who that contact is.
  if (!DELIVERY_IMPLEMENTED) {
    // No PII, no message content, no GPS — just enough to know an attempt was
    // made and for which contact record, without saying who that contact is.
    console.log(
      `[MOCK] Would notify emergencyContacts/${contact.id} for uid ${uid} (ride ${rideId}); ` +
        'no message was actually sent (crash-alert delivery is not yet implemented).'
    );
  }

  // For now, log the attempt — contactId only, so a real integration's
  // delivery log doesn't duplicate the contact's phone/email at rest
  // (issues §24.8). Look up the contact by id if that's ever needed.
  await db
    .collection('users')
    .doc(uid)
    .collection('notificationLog')
    .add({
      contactId: contact.id,
      rideId,
      timestamp: new Date().toISOString(),
      method: contact.phone ? 'sms' : 'email',
      // Not 'sent': delivery is still a MOCK, and a log that says 'sent'
      // would be read as proof a contact was reached when nobody was.
      status: DELIVERY_IMPLEMENTED ? 'sent' : 'mock_not_sent',
    });
}

/**
 * The rider's display name, for the message body. Falls back to a neutral
 * phrase rather than to the uid — a contact reading "your emergency contact
 * 8f2c...e41" learns nothing and is likelier to treat it as spam.
 */
async function lookUpRiderName(uid: string): Promise<string> {
  try {
    const profile = await db.collection('users').doc(uid).get();
    const name = profile.data()?.displayName;
    if (typeof name === 'string' && name.trim().length > 0) return name.trim();
  } catch (e) {
    logger.error(`lookUpRiderName failed for ${uid}`, e);
  }
  return 'a ThrottleIQ rider';
}

/**
 * Escalation check: sends follow-up if no ACK after 15 min
 * Triggered by Pub/Sub scheduler
 */
/** Max notifications escalated per 15-minute tick. */
const ESCALATION_BATCH = 100;

export const escalateCrashAlert = onSchedule(
  'every 15 minutes',
  async () => {
    try {
      // Find crash notifications that are still 'contacted' after 15+ minutes
      const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);

      // Only genuinely-delivered alerts escalate. A `mock_not_sent` alert is
      // terminal — re-running a mock does not reach anyone, and sweeping it
      // here would churn the log and hide the fact that nothing was sent.
      //
      // Ordered oldest-first and capped: if more than ESCALATION_BATCH are due
      // in one 15-minute window the oldest go first and the rest wait for the
      // next tick, rather than an arbitrary subset being picked. The cap is
      // logged when hit — silently truncating an emergency path is exactly the
      // sort of thing that should page someone.
      const pendingSnapshot = await db
        .collectionGroup('crashNotifications')
        .where('status', '==', 'contacted')
        .where('contactedAt', '<=', fifteenMinutesAgo.toISOString())
        .orderBy('contactedAt', 'asc')
        .limit(ESCALATION_BATCH)
        .get();

      if (pendingSnapshot.size === ESCALATION_BATCH) {
        logger.warn(
          `escalateCrashAlert: hit the ${ESCALATION_BATCH}-doc batch cap; ` +
            'more alerts are due and will wait for the next 15-minute tick.'
        );
      }

      for (const doc of pendingSnapshot.docs) {
        const notification = doc.data() as CrashNotification & {
          contactedAt: string;
        };

        // Send follow-up escalation
        console.log(`Escalating crash alert for ${notification.uid}`);
        await sendFollowUpAlert(notification.uid, notification.rideId);

        // Mark as escalated
        await doc.ref.update({
          status: 'escalated',
          escalatedAt: new Date().toISOString(),
        });
      }
    } catch (error) {
      console.error(`Error in escalation check: ${error}`);
    }
  }
);

/**
 * Send follow-up escalation alert
 */
async function sendFollowUpAlert(uid: string, rideId: string): Promise<void> {
  if (!DELIVERY_IMPLEMENTED) {
    console.log(
      `[MOCK] Would send follow-up escalation for ${uid} ride ${rideId}; ` +
        'nothing was sent.'
    );
  }

  // TODO: Send via SMS or email once DELIVERY_IMPLEMENTED flips.
  // Deliberately NOT wired to emergency services — see README's Safety
  // section: alerting is contacts-only by design.

  await db
    .collection('users')
    .doc(uid)
    .collection('notificationLog')
    .add({
      rideId,
      timestamp: new Date().toISOString(),
      type: 'escalation',
      // see sendContactNotification
      status: DELIVERY_IMPLEMENTED ? 'sent' : 'mock_not_sent',
    });
}
