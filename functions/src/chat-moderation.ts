import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// A basic set of toxic keywords for automated moderation demonstration.
// In a production app, this would use Google Cloud Natural Language API or Perspective API.
const TOXIC_KEYWORDS = [
  "idiot",
  "stupid",
  "jerk",
  "dumb",
  "hate",
  "ugly",
];

export const onMessageCreate = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const messageData = snapshot.data();
    const text = messageData.text?.toLowerCase() || "";

    // Simple toxicity check
    const isToxic = TOXIC_KEYWORDS.some((word) => text.includes(word));

    if (isToxic) {
      logger.info(`Toxic message detected in chat ${event.params.chatId}, hiding message.`);
      
      // We can update the message to be hidden or flagged
      await snapshot.ref.update({
        isToxic: true,
        text: "*** This message was hidden by automated moderation ***",
      });

      // Optionally, we could create an automated report
      await admin.firestore().collection("reports").add({
        reporterId: "system",
        reportedId: messageData.senderId,
        contentType: "chat",
        contentId: snapshot.ref.id,
        reason: "Automated toxicity detection",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "actioned",
      });
    }
  }
);
