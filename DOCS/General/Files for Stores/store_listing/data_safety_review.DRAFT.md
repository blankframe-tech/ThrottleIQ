> DRAFT for owner review, 2026-10-22

# Play Data Safety: review against the code

Companion to `throttleiq_data_safety.DRAFT.csv` (same columns and rows as `throttleiq_data_safety.csv`, 23 answers changed). Covers operations_manager_todo.md item 2. Nothing here is submitted; the existing CSV and `data_safety_and_permissions.md` are unchanged.

Method: read `app/android/app/src/main/AndroidManifest.xml`, `app/pubspec.yaml`, and grepped `app/lib` for every Firebase SDK, Cloudinary upload folder, outbound host, Firestore collection holding personal data, and on-device-only storage. Compared the result with `public/privacy.html` (the canonical policy; `public/privacy-policy.html` is only a redirect to it) and the existing CSV/md.

## 1. Per data type

"Optional" means Play's "users can choose whether this data is collected". "Shared" follows the existing doc's convention: visible to other riders or to anyone with a link counts as shared. Service providers (Firebase, Cloudinary, Open-Meteo, OSM) acting for the app are not "sharing" in Play's sense.

### Location

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| Precise location | Yes | Yes (live-share link, `/r/@handle` link, group-ride map, shared rides, cop-checkpoint places) | Yes (Settings → Your ThrottleIQ → Ride tracking off; auto-detect is opt-in) | App functionality | `features/ride/domain/entities/live_session_entity.dart`; `features/social/data/repositories/group_ride_repository.dart` `updateMemberLocation` (`groupRides/{id}/memberLocations/{uid}`); `core/services/public_live_link_setting.dart`; `core/cloud/cloud_repository.dart` (ride tracks); manifest `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` | Unchanged |
| Approximate location | Yes | No | Yes (opt-in "Help improve crash detection") | Analytics | `core/cloud/impact_event_payload.dart` `crashEventCloudPayload` (`geohash6`) | Unchanged. See open question 6 on the always-on road-speed pool and Firebase Analytics IP location |

### Personal info

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| Name | Yes | Yes (public profile) | No (display name required at onboarding) | App functionality, Account management | `features.md` §1 (onboarding until `displayName` set); privacy.html §1, §5 | Unchanged |
| Email address | Yes | No (see mismatch M1) | No | Account management, **App functionality**, **Fraud prevention, security, and compliance** | `users/{uid}/private/account`, `emailLookup` (SECURITY.md step 1/3); moderation warnings are emailed (`moderation_policy.md` §3) | **Added two purposes**: find-a-rider-by-verified-email is a feature, and moderation warnings use the address |
| User IDs (CSV label "Personal identifiers", `PSL_USER_ACCOUNT`) | Yes | Yes (`@username` public; uid in follow QR link `/u/<uid>`) | No | App functionality, Account management, Fraud prevention, security, and compliance | Firebase Auth uid on every `users/{uid}/...` record, `reports.reporterId/reportedId` (`moderation_policy.md`), `crashEvents.ownerUid` (`impact_event_payload.dart`), `features/social/domain/utilities/follow_link.dart` | **Newly ticked.** Play defines User IDs as account ID / account name; uid and @username fit. Open decision 2 |
| Phone number, address, other | No | | | | Rider's own phone is never asked for. Emergency-contact phones are other people's: see Contacts | Unchanged |

### Messages

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| Other in-app messages | Yes | No (two participants only) | Yes (chat is optional; Community module can be Off) | App functionality, Fraud prevention, security, and compliance (report copies kept 90 days) | `app/lib/features/chat/`; `moderation_policy.md` (snapshot); privacy.html §1 DM row | **Newly ticked.** `data_safety_and_permissions.md` already says "Yes, collected, not shared", but the CSV had it blank. Bug in the CSV |

### Photos and audio

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| Photos | Yes | Yes | Yes | App functionality | Cloudinary folders: `avatars/$uid` (`profile_repository.dart:336`), `rideShares/$uid` (`ride_share_repository.dart:37`), `forumPhotos/$uid` (`forum_repository.dart:490`), `places/$uid` (`place_repository.dart:31`), `bikes/$uid` (`core/cloud/cloud_repository.dart:366`, run by `sync_manager.dart:576`) | Unchanged answers; evidence widened (bike, forum and place photos). See M2, M3 |
| Voice or sound recordings | Yes | Yes (group-ride members) | Yes | App functionality | `group_ride_map_screen.dart:537` `uploadAudio` to `voiceNotes/$uid/<rideId>`; manifest `RECORD_AUDIO` | Unchanged |

### Health and fitness

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| Health info | **Owner decision** (left unticked) | | | | SafeQR medical info: `features/profile/presentation/providers/medical_info_provider.dart` stores it in SharedPreferences only, never Firestore; manifest `android:allowBackup="false"`. Not collected. **But** the "Did you fall?" follow-up stores `severity` = `none` / `minor` / `medical` (`features/ride/domain/entities/impact_event_types.dart` `ImpactSeverity`) in `users/{uid}/impactEvents` for every answered impact, and in `crashEvents` when opted in (`impact_event_payload.dart`) | Unchanged. Open decision 1 |
| Fitness info | No | | | | Activity recognition only starts auto-detect | Unchanged |

### Contacts

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| Contacts | Yes | No | Yes | App functionality | `features/profile/presentation/providers/emergency_contacts_provider.dart` writes `users/{uid}/emergencyContacts` (`name`, `phone`, `email`), typed by hand; follow graph (follows). No `READ_CONTACTS` permission | **Newly ticked.** Play's Contacts type covers contact names and social-graph info; these are third parties' names and numbers in the cloud. Open decision 3 |

### Financial info

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| Purchase history / Other financial info | **Owner decision** (left unticked) | | | | Fuel fill-ups with price (`users/{uid}/fuelLogs`, `core/cloud/outbox_service.dart:46`), service bills in `maintenance_logs` and running costs in `users/{uid}/private/{bikeId}` (`core/cloud/maintenance_settings_sync.dart`). No payments | Unchanged. Open decision 4 |

### App activity

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| App interactions (Page views and taps) | Yes | No | Yes (opt-out, on by default) | Analytics | `core/analytics/analytics_service.dart` (`analytics_enabled` default `true`, off in debug, screen patterns + closed event list, no user id) | Unchanged |
| Other user-generated content | Yes | Yes | Yes | App functionality, **Fraud prevention, security, and compliance** | Forums, shared rides, comments, places, reviews (`features.md` §6, §7); report snapshots (`moderation_policy.md`) | **Added Fraud prevention purpose**, as `data_safety_and_permissions.md` already instructs for report copies |
| Other actions (impact records) | Yes | No | No | App functionality, Analytics | `impact_event_payload.dart` `impactEventCloudPayload` to `users/{uid}/impactEvents` | Unchanged. Note: Precise location is marked Optional because Ride tracking can be turned off; the same switch stops impact records, so Optional would be equally defensible here. Owner's call |
| In-app search history, installed apps | No | | | | Search is not stored | Unchanged |

### App info and performance, identifiers

| Type | Collected | Shared | Optional | Purpose | Evidence | vs existing CSV |
|---|---|---|---|---|---|---|
| Crash logs | Yes | No | No | Analytics | `app/lib/main.dart:84-134` (Crashlytics, `setCrashlyticsCollectionEnabled(!kDebugMode)`); no `setUserIdentifier` anywhere in `app/lib` | Unchanged |
| Diagnostics | Not declared | | | | See open question 6 | Unchanged |
| Device or other IDs | Yes | No | No | App functionality, Analytics | Firebase installation ID, Analytics app-instance ID; App Check attestation (`firebase_app_check` in pubspec). Manifest removes `AD_ID` and sets the four `google_analytics_*` ad flags to false | Unchanged |

### Top-level answers

| Question | Answer | Evidence |
|---|---|---|
| Collects or shares required data | Yes | above |
| Encrypted in transit | Yes | every host in `app/lib` is `https://` (Firebase, `api.cloudinary.com`, `tile.openstreetmap.org`, `overpass-api.de`, `nominatim.openstreetmap.org`, `api.open-meteo.com`) |
| Users can request deletion | Yes (in-app delete plus manual cloud deletion within 30 days by email) | privacy.html §9; `data_safety_and_permissions.md` |

## 2. Diff summary vs the existing CSV

| Change | Why |
|---|---|
| Ticked Messages → Other in-app messages (collected, not shared, optional, App functionality + Fraud prevention) | The md already declares it; the CSV omitted it |
| Ticked Personal info → User IDs (collected, shared, required, App functionality + Account management + Fraud prevention; shared for App functionality) | uid on every record and public @username (decision 2) |
| Ticked Contacts (collected, not shared, optional, App functionality) | Emergency contacts in Firestore, follow graph (decision 3) |
| Email: added App functionality and Fraud prevention purposes | Find-by-email feature; moderation warnings by email |
| Other UGC: added Fraud prevention purpose | Report snapshots kept 90 days, per the md |

Everything else is identical to the existing CSV (checked with `diff`: only these 23 rows differ).

## 3. Open decisions for the owner (ops item 2)

1. **Health info.** SafeQR is on-device only, so by itself it is not "collected" and needs no tick. The real question is the impact `severity` answer, whose values include `medical`, uploaded for every answered impact (not opt-in) to the rider's private `impactEvents`, and copied to `crashEvents` with the opt-in. Options: (a) tick Health info: collected, not shared, optional, App functionality + Analytics; (b) rename the value in the UI and data so it describes the crash rather than the person's injury; (c) keep unticked with a written rationale. Recommended: (a) until a lawyer says otherwise. [PLACEHOLDER: owner/lawyer decision]
2. **User IDs.** Ticked in the draft. If you untick it, write down why; Play's definition ("account ID, account number, or account name") matches the uid and @username. [PLACEHOLDER: owner confirms]
3. **Contacts.** Ticked in the draft for emergency contacts and follows. Alternative reading: emergency-contact phone numbers go under Personal info → Phone number. Either way, something should be declared. [PLACEHOLDER: owner confirms]
4. **Fuel and service costs.** Purchase history or Other financial info? These are amounts the rider types, not transactions made through the app. Left unticked. [PLACEHOLDER: owner decision]
5. **Analytics opt-out wording.** The CSV says Optional for App interactions. On the store listing and in the app, keep one phrasing everywhere: suggested "Anonymous usage statistics are on by default. Turn them off in Settings → Privacy & Safety → Share anonymous usage statistics." The in-app label already matches: `shareUsageStats` = "Share anonymous usage statistics" (`app/lib/l10n/app_en.arb`). Note Firebase Analytics still assigns an app-instance ID, which is why Device or other IDs lists Analytics.
6. **Things Google's SDKs may collect on their own.** Check Google's Firebase "data disclosure for Play's Data safety section" page for Analytics and Crashlytics before submitting, in particular whether Analytics' IP-derived region counts as Approximate location and whether Crashlytics needs Diagnostics. [PLACEHOLDER: not verified; no web access used for this draft]
7. **Anonymous road-speed pool.** After every ride the app writes geohash-7 (~150 m) cell, speed, weekday, hour and weather to a shared pool, with no uid, on by default, with no separate switch (privacy.html §2; `features.md` §2). Play exempts data that is truly anonymous; confirm you are comfortable relying on that. [PLACEHOLDER: owner decision]

## 4. Mismatches between code and `public/privacy.html`

| # | Mismatch | Code | privacy.html | Fix direction |
|---|---|---|---|---|
| M1 | Email shown to other riders | Rules deployed 2026-10-22 refuse email on public profiles; new profiles keep it in `users/{uid}/private/account`. Old profiles still hold it until `migrate_emails_private.js` runs (HANDOFF "Production backend") | §5 says your email is readable by other signed-in riders | Already planned: ops item 1 step 5 after the migration. Over-discloses, so safe for now |
| M2 | Bike photos | Uploaded to Cloudinary `bikes/$uid` on sync (`core/cloud/cloud_repository.dart:347-366`); also stated in `phone_vs_cloud_data.md` | §1: "Bike photos stay on your phone only"; §4 Cloudinary row omits them | **Under-discloses.** Update privacy.html §1 and §4 |
| M3 | Forum and place photos | Cloudinary `forumPhotos/$uid` (`forum_repository.dart:490`), `places/$uid` (`place_repository.dart:31`) | §4 Cloudinary row lists only profile picture, shared-ride photos, voice clips | Under-discloses. Add to §4 |
| M4 | Nominatim | `features/poi_directory/data/services/nominatim_service.dart` sends the pin's coordinates to `nominatim.openstreetmap.org/reverse` when adding a place | Not listed in §4 third parties | Under-discloses. Add a §4 row |
| M5 | Group-ride live positions | `groupRides/{id}/memberLocations/{uid}` (lat, lng, time) every 20 s / 25 m, visible to members (`group_ride_repository.dart:526`, `features.md` §7b) | §5 mentions only voice clips for group rides; §4 Firestore row does not list group rides | Under-discloses. Add to §5 and §4 |
| M6 | Password `/r/@handle` live link | `core/services/public_live_link_setting.dart`, `handleLinks/{hash}` (off by default; password-gated; shares every ride and keeps the last ride's end point) | §6 describes only the token link | Under-discloses an opt-in feature. Add to §6, including the retained last location |
| M7 | Camera | Manifest declares `CAMERA` for QR scan (`scan_follow_qr_screen.dart`); `ImageSource.camera` offered in forum, add-place, odometer and receipt pickers | §1 "What the app does not collect": "Photos are chosen one at a time through your phone's own picker" | Wording gap. Say the camera is used for QR scan and for taking a photo you choose to attach |
| M8 | Fuel logs, paperwork, running costs | `users/{uid}/fuelLogs`, `users/{uid}/private/{bikeId}` (paperwork kind, expiry, notes; running costs) | §1, §2, §8, §9 list bikes, maintenance logs and routes but never fuel logs or papers | Under-discloses. Add to §1 and to the deletion list in §9 |
| M9 | Emergency contacts purpose | Never contacted (`features.md` §8; `functions/src/crash-notifications.ts` is a mock) | §1 row: "So the app knows who to reach if you're in a crash" | Misleading purpose; §7 corrects it. Reword the §1 row |
| M10 | Beta jam labels | `users/{uid}/rides/{id}/jamLabels` for handles in `BetaTesters.jamLabelling` (`jam_label_repository.dart`) | Not mentioned | Minor (beta testers only); private ride data. Optional mention |
| M11 | No privacy policy link in the app | No `privacy.html` URL anywhere in `app/lib` (only `community.html` in the report sheet) | n/a | Apple requires an in-app link; add one in Settings next to the Terms link (ops item 3) |

## 5. Stale statements in the existing store docs

- `data_safety_and_permissions.md` says "No `READ_CONTACTS`, `CAMERA`, or `SMS` permission". The manifest now declares `CAMERA` (QR scan) and `WRITE_EXTERNAL_STORAGE` (maxSdk 29, saving the QR image).
- `app_content_remaining.md` says `the.abraar.rar@gmail.com` is "the address used throughout `public/privacy.html`". privacy.html uses only `hello@blankframe.tech`. `SECURITY.md` still lists `the.abraar.rar@gmail.com` for vulnerability reports.
- `data_safety_and_permissions.md` "Photos" row says shared "if attached to a shared ride/review"; bike photos, forum photos and place photos are uploaded too.
