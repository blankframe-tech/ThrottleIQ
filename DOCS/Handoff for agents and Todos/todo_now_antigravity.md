# Implementation Tasks: Trust & Safety and Messaging

- [x] **0. Setup**
  - [x] Update `firestore.rules` for the `blocks` subcollection.
  - [x] Update `firestore.rules` for the `reports` top-level collection.
  - [x] Update `firestore.rules` for `chats` and `messages` collections.

- [x] **1. Blocking Users**
  - [x] Add `blocks` path to Firestore schema constants.
  - [x] Update `ProfileRepository` to manage blocking/unblocking users.
  - [x] Implement client-side filtering in `ProfileRepository` and `RideFeedProvider` to hide blocked users' content.
  - [x] Add "Block User" action to the `UserProfileScreen` overflow menu.
  - [x] Create a "Blocked Users" management screen in the settings.

- [x] **2. Reporting Users & Content**
  - [x] Create `ReportEntity` and `ReportModel`.
  - [x] Add `ReportRepository` for submitting reports.
  - [x] Create a reusable `ReportBottomSheet` UI component.
  - [x] Add "Report" action to `UserProfileScreen`, `_RideCard`, and `ForumPostCard`.

- [x] **3. Chat Feature (Direct Messaging)**
  - [x] Create `ChatEntity` and `MessageEntity` domain models.
  - [x] Implement `ChatRepository` for fetching chats and sending messages.
  - [x] Create `ChatListScreen` to display active conversations.
  - [x] Create `ChatRoomScreen` with real-time message updates.
  - [x] Add a "Message" button to the `UserProfileScreen` (hidden if blocked).

- [x] **4. Chat Moderation**
  - [x] Implement long-press action on chat messages in `ChatRoomScreen` to open the `ReportBottomSheet`.
  - [x] Create a Cloud Function (`onMessageCreate`) for automated toxicity detection.

- [x] **5. Data Encryption in Transit**
  - [x] Verified that all user data collected by the app is encrypted in transit (handled automatically by Firebase HTTPS/TLS for Firestore, Cloud Functions, and Firebase Auth).

- [ ] **Next Steps if Token Limit Reached**: Continue from the first unchecked item in this list.
