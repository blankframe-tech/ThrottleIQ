import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

// A basic set of toxic keywords for automated moderation demonstration.
// In a production app, this would use Google Cloud Natural Language API or Perspective API.
// Known-weak placeholder (docs/Issues.md §62.5): a handful of English
// substrings catches nothing in Bangla/Banglish (this app's actual user
// base) and nothing with trivial evasion. Replacing it with real NLP
// moderation is tracked separately, not attempted here.
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

      // File an automated report for admin review. Status is 'pending', not
      // 'actioned' (docs/Issues.md §62.5 — this used to auto-mark it
      // 'actioned' even though nothing was actually reviewed, so downstream
      // tooling that trusts `status` treated unverified content as
      // resolved). This write goes through the Admin SDK, which bypasses
      // firestore.rules entirely, but the semantics should still be honest:
      // hiding the message is automated, closing the report isn't.
      await admin.firestore().collection("reports").add({
        reporterId: "system",
        reportedId: messageData.senderId,
        contentType: "chat",
        contentId: snapshot.ref.id,
        reason: "Automated toxicity detection",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "pending",
      });
    }
  }
);
