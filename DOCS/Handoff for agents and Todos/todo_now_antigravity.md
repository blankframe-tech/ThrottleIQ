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

- [x] **7. Places Hub & Forums Pit Wall Redesign Follow-ups & Fixes (§97)**
  - [x] **Fix §97.1 (ListTile inside coloured DecoratedBox assertion):**
    - Replace `Container(decoration: BoxDecoration(color: context.palette.surface...))` with `Material(color: context.palette.surface, shape: RoundedRectangleBorder(...), clipBehavior: Clip.antiAlias, child: Column(...))` in `auto_tracking_tile.dart:31-40` & `222-231`.
    - Apply same `Material` wrapper to `route_detail_screen.dart:183` and `save_route_screen.dart:180`.
    - Replace `ListTile` inside `PopupMenuItem` with `Row(children: [Icon(...), SizedBox(width: 12), Expanded(child: Text(...))])` in `places_list_screen.dart:156,164`.
  - [x] **Fix §97.2 (RenderFlex 3.0 px overflow ×2):**
    - Bump carousel height from `196` to `208` in `places_map_view.dart:28`.
    - Add `tapTargetSize: MaterialTapTargetSize.shrinkWrap` to `placeActionButtonStyle` in `place_card.dart:23`.
    - Bump ribbon height to `52` in `places_list_screen.dart:348`.
  - [x] **Fix §97.3 (Invalid image data bursts of 10+):**
    - Refactor `user_avatar.dart:20-34` from `CircleAvatar(backgroundImage: CachedNetworkImageProvider(...))` to `ClipOval` + `CachedNetworkImage` with `placeholder: (_, __) => fallback` and `errorWidget: (_, __, ___) => fallback` so failed images gracefully display user initials and no unhandled decode exceptions escape into the zone.
    - Add `errorImage: MemoryImage(Uint8List.fromList(_transparentPixelPng))` to `TileLayer` in `app_tile_layer.dart:120`.
  - [x] **Fix §97.4 (Place photos in detail view):** Add photo thumbnails/banner in `PlaceDetailScreen` when `place.photoUrls.isNotEmpty`.
  - [x] **Fix §97.5 (Lazy list in Saved tab):** Refactor `SavedPlacesTab` (`saved_places_tab.dart:69`) from eager `ListView` to `ListView.builder` per §91.4.
  - [x] **Fix §97.6 (Web crash risk with Platform.isIOS):** Replace `Platform.isIOS` in `place_launch_actions.dart:94` with `defaultTargetPlatform == TargetPlatform.iOS` from `package:flutter/foundation.dart`.
  - [x] **Fix §97.7 (Inconsistent imports):** Standardize `forum_post_model.dart:2-3` imports to relative paths (`../../../../core/...`, `../../domain/...`).
  - [x] **Fix §97.8 (Partial photo upload failure):** Wrap `uploadPostPhoto` loop in `forum_thread_screen.dart:326` in dedicated try-catch with specific photo upload error feedback.

- [ ] **8. iOS & Android Widgets Device Deployment & Verification**
  - [ ] **Build & Deploy to Device:**
    - Deploy release build to connected iPhone: `cd app && flutter run --release -d 00008120-001E5D190A85A01E` (or standard `flutter run` for Android).
  - [ ] **Baseline Data Initialization:**
    - Launch ThrottleIQ once on device so `HomeWidgetService.bootstrap()` writes baseline values into shared App Group (`group.com.bft.throttleiq`) / SharedPreferences.
  - [ ] **Xcode App Group & Signing Check:**
    - In `app/ios/Runner.xcworkspace`, verify the `ThrottleIQWidget` target has developer Team assigned under **Signing & Capabilities** and `App Groups` (`group.com.bft.throttleiq`) is ticked without provisioning warnings.
  - [ ] **Home Screen Widgets Test:**
    - Add **Apex Hunter** (`.systemSmall` and `.systemMedium`) to home screen; verify Max Lean Left/Right, volt accent bar, lean rating badge, and symmetry score.
    - Add **Ride Stats** and **Maintenance** widgets; verify live telemetry updates and overdue chips.
    - Add **Start Ride** and **Auto-Tracking** quick launchers; verify one-tap deep link routing.
  - [ ] **iOS Lock Screen Accessories Test (iOS 16+):**
    - Customize Lock Screen; add ThrottleIQ accessory widgets:
      - `.accessoryCircular`: compact L/R lean gauge.
      - `.accessoryRectangular`: Apex Hunter, Ride Stats, and Maintenance summaries.
      - `.accessoryInline`: glanceable text banner under or above the clock.
  - [ ] **In-App Telemetry & Cockpit Widgets Test:**
    - Verify `DualLeanArcGauge` and `GForceFrictionCircle` render smoothly at 60/120fps during active rides and telemetry replays.
    - Verify `ConsumablesHealthCard` radial wear gauges on Maintenance screen reflect real check intervals and respond to taps.

- [ ] **9. Flaws found in the 2026-10-07 verification pass (do NOT fix blindly — each is a follow-up)**
  - [ ] **F1 (red test):** `app/test/features/routes/presentation/screens/save_route_screen_test.dart` ("SaveRouteScreen renders and wraps SwitchListTile in Material") fails. Left uncommitted. Fix the test or the screen.
  - [ ] **F2 (analyze warnings):** 4 `unused_import` warnings in `route_detail_screen_test.dart` (lines 4, 6, 7) and `save_route_screen_test.dart` (line 4). QA gate needs zero.
  - [ ] **F3 (dead code):** `AutoDetectionDao.purgeOldSummarizedFixes` (§93.2 retention) has no caller. Nothing purges fixes yet. Wire it into app start or the daily summary job.
  - [ ] **F4 (missing tests):** no test for `purgeOldSummarizedFixes` and no v21→v22 migration test for `fixes_purged`. QA rule 4 needs a happy-path and an edge-case test each.
  - [ ] **F5 (data-loss caveat):** purging fixes makes old days drop out of the recomputed daily summary (`fixes_purged = 0` filter). Decide if totals should be stored before purging.
  - [ ] **F6 (PRD too thin):** `DOCS/PRD.md` is 51 lines. It lacks chat, trust & safety, problem/users, goals and non-goals, non-functional requirements, constraints and success metrics. It also claims lean angle and crash alerts "must send" although crash detection is off and alerts are mocked, and "encrypt passwords" is not accurate (Firebase Auth handles passwords). The ASD-STE100 word and sentence-length check was not run. §6 stays unchecked.
  - [ ] **F7 (branch):** all this work is on `experimental`, not merged into `main`.
  - [ ] **F8 (no device check):** the §97 fixes and the new widget tests were verified by code reading and the test suite only, not on a device.

- [ ] **Next Steps if Token Limit Reached**: Continue from the first unchecked item in this list.
