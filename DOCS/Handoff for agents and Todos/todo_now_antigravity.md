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

- [ ] **6. Documentation**
  - [ ] **Write a PRD in ASD-STE100 format.** Cover the app (rides, forum, profiles, chat, trust & safety) and the Firebase backend: problem, users, goals and non-goals, functional and non-functional requirements, constraints and success metrics. Follow ASD-STE100 (Simplified Technical English): use only approved words and their approved meanings, keep procedural sentences to 20 words or fewer and descriptive sentences to 25 or fewer, write one instruction per sentence, use the active voice, and use the imperative for procedures. Save it as `DOCS/PRD.md`.

- [ ] **7. Places Hub Redesign Follow-ups & Fixes (§97)**
  - [ ] **Fix §97.1 (ListTile in PopupMenuItem):** Replace `ListTile` inside `PopupMenuItem` with `Row` in `places_list_screen.dart:156,164`.
  - [ ] **Fix §97.2 (RenderFlex 3.0 px overflow):** Bump ribbon height to 52 in `places_list_screen.dart:348` and carousel height to 204 in `places_map_view.dart:28`.
  - [ ] **Fix §97.3 (Invalid image data bursts):** Add `onBackgroundImageError: hasPhoto ? (_, __) {} : null` in `user_avatar.dart:23`.
  - [ ] **Fix §97.4 (Place photos in detail view):** Add photo thumbnails/banner in `PlaceDetailScreen` when `place.photoUrls.isNotEmpty`.
  - [ ] **Fix §97.5 (Lazy list in Saved tab):** Refactor `SavedPlacesTab` (`saved_places_tab.dart:69`) from eager `ListView` to `ListView.builder` per §91.4.

- [ ] **Next Steps if Token Limit Reached**: Continue from the first unchecked item in this list.
