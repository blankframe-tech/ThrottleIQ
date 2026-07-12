import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

interface CrashNotification {
  uid: string;
  rideId: string;
  timestamp: string;
  lastLat?: number;
  lastLng?: number;
  status: 'pending' | 'contacted' | 'acknowledged';
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
export const onCrashNotification = functions.firestore
  .document('crashNotifications/{notificationId}')
  .onCreate(async (snap, context) => {
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

      const contacts = contactsSnapshot.docs.map(
        (doc) => doc.data() as EmergencyContact
      );

      // Send notification to each contact (SMS/Email)
      // MOCK: In production, integrate with Twilio for SMS or SendGrid for email
      for (const contact of contacts) {
        await sendContactNotification(
          contact,
          uid,
          rideId,
          lastLat,
          lastLng
        );
      }

      // Update notification status
      await snap.ref.update({
        status: 'contacted',
        contactedAt: new Date().toISOString(),
      });

      // Schedule escalation check in 15 minutes
      scheduleEscalation(uid, rideId, context.eventId);
    } catch (error) {
      console.error(`Error processing crash notification: ${error}`);
      throw error;
    }
  });

/**
 * Send notification to a contact via SMS or email
 * MOCK: Replace with actual Twilio/SendGrid integration
 */
async function sendContactNotification(
  contact: EmergencyContact,
  uid: string,
  rideId: string,
  lastLat?: number,
  lastLng?: number
): Promise<void> {
  const location = lastLat && lastLng
    ? `https://maps.google.com/?q=${lastLat},${lastLng}`
    : 'Location unavailable';

  // MOCK SMS message
  const smsMessage = `ALERT: ${contact.name}, your emergency contact ${uid} may have crashed. ` +
    `Ride: ${rideId}. Location: ${location}. Reply CONFIRM if they are OK.`;

  // MOCK email subject
  const emailSubject = `ThrottleIQ Emergency Alert - Potential Crash`;

  // MOCK email body
  const emailBody = `
Dear ${contact.name},

You are listed as an emergency contact on ThrottleIQ. We detected a potential motorcycle crash.

Rider UID: ${uid}
Ride ID: ${rideId}
Location: ${location}
Time: ${new Date().toISOString()}

If you can confirm they are OK, please respond to this email or call them directly.

If no confirmation is received within 15 minutes, we will send a follow-up alert.

Stay safe,
ThrottleIQ Safety Team
  `;

  console.log(`[MOCK] Sending SMS to ${contact.phone}: ${smsMessage}`);
  console.log(`[MOCK] Sending email to ${contact.email}: ${emailSubject}`);

  // TODO: Integrate with Twilio for SMS
  // TODO: Integrate with SendGrid or Firebase Email for email

  // For now, log the attempt
  await db
    .collection('users')
    .doc(uid)
    .collection('notificationLog')
    .add({
      contactId: contact.id,
      contactName: contact.name,
      phone: contact.phone,
      email: contact.email,
      rideId,
      timestamp: new Date().toISOString(),
      method: contact.phone ? 'sms' : 'email',
      status: 'sent',
    });
}

/**
 * Schedule escalation check for 15 minutes
 * MOCK: Use Pub/Sub scheduled functions in production
 */
function scheduleEscalation(
  uid: string,
  rideId: string,
  notificationId: string
): void {
  // In production, schedule a Cloud Task or use Pub/Sub
  // For MVP, we log intent
  console.log(`Scheduled 15-min escalation check for ${uid} ride ${rideId}`);

  // TODO: Implement via Cloud Tasks or Pub/Sub delayed task
}

/**
 * Escalation check: sends follow-up if no ACK after 15 min
 * Triggered by Pub/Sub scheduler
 */
export const escalateCrashAlert = functions
  .pubsub.schedule('every 15 minutes')
  .onRun(async (context) => {
    try {
      // Find crash notifications that are still 'contacted' after 15+ minutes
      const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);

      const pendingSnapshot = await db
        .collectionGroup('crashNotifications')
        .where('status', '==', 'contacted')
        .where('contactedAt', '<=', fifteenMinutesAgo.toISOString())
        .limit(10)
        .get();

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
  });

/**
 * Send follow-up escalation alert
 */
async function sendFollowUpAlert(uid: string, rideId: string): Promise<void> {
  console.log(`[MOCK] Sending follow-up escalation alert for ${uid} ride ${rideId}`);

  // TODO: Send via SMS or email
  // In production, could also trigger emergency services (911) if configured

  await db
    .collection('users')
    .doc(uid)
    .collection('notificationLog')
    .add({
      rideId,
      timestamp: new Date().toISOString(),
      type: 'escalation',
      status: 'sent',
    });
}
