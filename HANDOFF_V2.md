# ThrottleIQ v2 — Social/Community Rework: Handoff & Forward Plan

_Last updated: 2026-07-23 · Branch: `main` (see note below) · App version: `2.0.0-beta.3+5`_

> **Branch note (2026-07-23):** this doc has referred to the work below as
> living on `feat/v2-social` throughout, but no such branch exists in this
> repo — commits `1a8a06d`…`ac7a8ed` (package rename through Epic F) are all
> directly on `main`. Continuing to commit there this session rather than
> retroactively inventing a branch split; flagging so nobody goes looking for
> a branch that was never actually created. The "keep `main` releasable"
> guidance in §7 has therefore already been not-quite-true since Epic B —
> `main` currently holds unreleased, not-fully-runtime-verified work.

This is the **single source of truth** for the v2 rework (social feed + follow,
forums, garage/service, places, rides tab, safety, package rename). It captures
what is done and tested, what is in progress, and exactly what remains — enough
to resume with zero prior conversation context.

> Sibling docs: `todosanddone.md` (honest works/next status), `features.md`
> (as-built feature map), `future2.md` (follow-model decision — now settled),
> `RELEASE_NOTES.md`. This doc supersedes `todo_now.md` (which was the Phase 2–4
> spec) for anything v2.

---

## 0. TL;DR — where things stand

- **All 8 epics are now code-complete** (package rename, §1 Firebase
  reconfig, Phase A, Epics B–G). This session closed out the last three:
  **§1 (Firebase reconfig)**, **Epic F (Rides tab charts + badges)**, and
  **Epic G (crash-detection threshold fix)** — see their sections below for
  what changed and §9 for the decisions made while doing it autonomously.
- Verified this session: `flutter pub get && flutter analyze` clean (0
  errors), full `flutter test` suite green, `flutter run` boots clean on the
  iOS simulator (screen renders past `Firebase.initializeApp()` onto the
  sign-in screen — confirms §1's new config actually works at runtime, not
  just analyze-clean). Firestore rules + indexes are **deployed live** to
  `throttleiqfb`.
- **Firebase Storage abandoned, replaced with Cloudinary** (2026-07-23, see
  §1b) — the project owner has no payment card, and Google now requires the
  Blaze billing plan (card on file) to use Storage at all, even within its
  free tier. Avatar/ride-photo uploads now go to Cloudinary's cardless free
  tier instead. `firebase_storage` removed from `pubspec.yaml`,
  `storage.rules`/`firebase.json`'s `storage` key are dead.
- **A real device walkthrough happened 2026-07-23** (see §8) — the project
  owner tested the live app directly, surfacing and getting fixes for a
  forum-post crash and a Social-feed permission-denied bug that neither
  `flutter analyze` nor the unit suite could have caught. This is the first
  real-world usage signal this doc has had.
- **Two more real-usage bug waves landed the same day** (see §8a, §8b): a
  swipe-to-start gesture replaced hold-to-start; a Navigator key-collision
  crash (garage user menu / bike delete) was fixed; the forum-post crash
  from the first wave turned out to be **mis-diagnosed twice** before the
  real root cause (a `TextEditingController` used after disposal) was found
  from an actual stack trace — see §8a for the full account, it's a useful
  cautionary tale. §8b covers a much larger second wave: bikes not syncing
  to a second device (sync was upload-only, never downloaded), a
  maintenance-page nav dead spot, the app losing ride data when killed
  mid-ride with the screen off (the most safety-relevant fix this project
  has had), forum votes failing silently, and a new username +
  public-profile-with-privacy feature. Test suite: 282/282 green throughout
  (no new tests added in §8a/§8b — that work is UI-callback/sync-plumbing
  code with no existing widget-test harness in this repo, same honest gap
  noted for the first wave in §8).
- **A polish wave followed the next day (2026-07-24, §8c)**: in-app follow
  notifications (bell icon + notifications screen — not a phone push, see
  §8c for why), GPS/speed-display tuning for the "speed feels slow" report,
  a real app icon (the config previously pointed at files that didn't
  exist), and rotating dashboard taglines replacing the static "Your ride,
  smarter." Built and released as `v2.0.0-beta.4+6`.

---

## 1. ✅ RESOLVED — Firebase reconfiguration

The package/bundle id was renamed `com.throttleiq.throttleiq` → **`com.bft.throttleiq`**
to match the Play Console listing. Both new apps are now registered in the
`throttleiqfb` Firebase console and the local config files/code are updated:

- **Android** app added: package `com.bft.throttleiq`, App ID
  `1:603325098273:android:94694220f44cbf63fcf660`, release SHA-1
  `85:42:B8:AD:19:1E:6B:74:FC:85:27:4F:48:9D:BC:CE:4B:00:2F:10` and debug SHA-1
  `90:1E:47:2B:08:4F:D1:D5:5C:2C:5C:56:F5:46:38:B7:12:59:95:FA` both
  registered. New `google-services.json` downloaded and placed at
  `app/android/app/google-services.json` (still contains the old app's client
  entry too — harmless, the Gradle plugin matches by package name).
- **iOS** app added: bundle `com.bft.throttleiq`, App ID
  `1:603325098273:ios:0f2907197737692efcf660`. New `GoogleService-Info.plist`
  downloaded and placed at `app/ios/Runner/GoogleService-Info.plist`
  (previously this file had a manually-edited `BUNDLE_ID` but stale
  `GOOGLE_APP_ID`/`CLIENT_ID` from the old app — now fully consistent).
- `app/lib/firebase_options.dart` regenerated: added a real `android`
  `FirebaseOptions` block (previously missing entirely), updated `ios` block
  with the new app's `appId`/`iosClientId`, and made
  `DefaultFirebaseOptions.currentPlatform` platform-aware via
  `defaultTargetPlatform` (previously hard-returned `ios` unconditionally).
- `app/ios/Runner/Info.plist` updated: `GIDClientID` and the
  `CFBundleURLTypes`/`CFBundleURLSchemes` reversed-client-id both now point at
  the new iOS app's OAuth client
  (`603325098273-gkjts7olcqevdkc1kiful0gtjspfe0bv...`).

**Not done in this pass** (optional, low priority): the two SHA-256
fingerprints the old Android app had registered were not re-added to the new
app — only the two SHA-1s (release + debug), which is what Google Sign-In
actually keys off. Add them later if something specifically needs SHA-256.

**Verified this session:** `flutter pub get && flutter analyze` clean (0
errors), full `flutter test` clean, and `flutter run -d <iPhone 17 sim>`
boots to the sign-in screen with no crash — confirms `Firebase.initializeApp()`
succeeds against the new `com.bft.throttleiq` config at runtime. Not verified:
an actual sign-in/sign-up round trip against the new Auth project (see §8 —
no simulator input-automation tool was available to drive that from here).

---

## 1b. ✅ RESOLVED — Firebase Storage dropped, Cloudinary added (2026-07-23)

Attempting to provision Firebase Storage (§8's open item) surfaced a harder
blocker: since Feb 2026 Google requires the **Blaze** (pay-as-you-go) billing
plan — a payment method on file — to use Cloud Storage for Firebase at all,
even to stay within its free quota. The project owner has no card to put on
file. Rather than block avatar/ride-photo uploads on that indefinitely, the
upload path was swapped to **Cloudinary**, which has a genuinely cardless
free plan (~25GB/month storage+bandwidth combined — comfortably covers
beta-tester volume).

- New `CloudinaryUploadService` (`lib/core/services/cloudinary_upload_service.dart`):
  thin wrapper around an **unsigned** upload to
  `https://api.cloudinary.com/v1_1/vjvcigkt/image/upload` using Dio (already
  a dependency — same "reuse what's there" call Epic E made for Overpass).
  Cloud name `vjvcigkt` and upload preset `throttleiq_unsigned` (created in
  the Cloudinary console, signing mode Unsigned) are not secrets — unsigned
  presets are designed to be called directly from a client app, so hardcoding
  them is the intended usage, not a leak.
- `ProfileRepository.uploadAvatar` and `RideShareRepository.uploadRidePhoto`
  now call this service instead of `FirebaseStorage`. Both still return a
  plain URL string, so **nothing downstream changed** — `photoUrl` is stored
  and displayed exactly as before.
- **Judgment call:** did not try to preserve the old fixed-path/overwrite
  semantics (`avatars/{uid}.jpg` replacing in place). Unsigned Cloudinary
  presets restrict client-supplied `public_id`/`overwrite` by design; forcing
  it would mean reconfiguring the preset in ways that weaken the "unsigned is
  safe to embed" guarantee. Instead every upload gets a fresh auto-generated
  URL, and the old image is simply orphaned in Cloudinary storage — at this
  scale that's noise, not a real cost, and far simpler than fighting the
  preset's restrictions.
- Removed `firebase_storage` from `pubspec.yaml` (now unused — grepped the
  whole `lib/` tree first to confirm no other caller). Removed the `storage`
  key from `firebase.json`. Left `storage.rules` on disk untouched but
  unwired — harmless dead file, cheaper to leave than to decide right now
  whether it's worth deleting.
- **Verified in a follow-up pass** (Flutter SDK available this time):
  `flutter pub get` updated `pubspec.lock` cleanly — dropped
  `firebase_storage`, `firebase_storage_platform_interface`,
  `firebase_storage_web`, no conflicts. `flutter analyze` stayed at the same
  0 errors / 91 pre-existing lint infos as before this change. `flutter test`
  stayed at 239/239 passing (no test referenced `FirebaseStorage` directly,
  so nothing needed updating).
- If a payment card becomes available later, switching back to Firebase
  Storage is straightforward: `storage.rules`/`firebase.json` wiring already
  exist, just re-add the `firebase_storage` pubspec entry and swap
  `CloudinaryUploadService` calls back to `FirebaseStorage.instance`.

---

## 2. What was DONE & TESTED

### 2a. Editorial BW redesign — SHIPPED (on `main`, released beta.3)
Full structural restructure to match `designs/ThrottleIQ Editorial BW.html`
(warm paper base, black "ink" panels, big rounded cards, Space Grotesk + Inter,
blue primary accent + orange attention). Six screens rebuilt against the mockup
and **verified live on the iOS simulator**: Record, Active Ride, Ride Summary,
Insights ("Your Journey"), Garage, Maintenance. Shared component library at
`app/lib/shared/widgets/editorial.dart`. Released as `v2.0.0-beta.3+5` with a
signed APK. _(Active Ride compiled clean but was not screenshotted live — needs
an in-progress GPS ride.)_

### 2b. Package rename (code side) — DONE, blocked on §1
Commit `0c84535`. Every active reference is now `com.bft.throttleiq`: Gradle
`applicationId`+`namespace`, Kotlin source dir moved to
`android/app/src/main/kotlin/com/bft/throttleiq/`, AndroidManifest
foreground-service name, all iOS `PRODUCT_BUNDLE_IDENTIFIER` (app + RunnerTests),
`GoogleService-Info.plist` BUNDLE_ID, `firebase_options` `iosBundleId`,
flutter_map userAgent strings, SETUP docs. (`google-services.json` deliberately
untouched — comes from §1.)

### 2c. Phase A — profile + follow backend — DONE, analyze-clean
Commit `fa5af24`. **Not runtime-tested** (blocked by §1). See §3–§4.

### 2d. Share-bug fix — DONE
The reported "sharing shows an error / doesn't share" bug: `shareRide` threw
`Exception('Polyline too short after privacy zone clipping')` on short or
near-home rides (privacy clip consumed the whole track). It now shares with **no
route line** instead of throwing (`ride_share_repository.dart`). The end→share
UX rebuild (photo + audience picker) is Phase B.

### Verification status legend used throughout
- **✅ verified** — exercised on device/sim.
- **🟡 analyze-clean** — `flutter analyze` passes; not run on device.
- **⬜ not started.**

---

## 3. Key architecture decisions (v2)

- **Open follow, not follow-requests.** Decided 2026-07-22 (supersedes the
  request-based idea in `future2.md`). Follow anyone instantly; visibility is
  controlled per-share by audience tier.
- **Audience tiers: public / followers / mutual.** Because **Firestore security
  rules are NOT query filters** (a list query whose rule needs a per-doc
  `exists()`/`get()` is rejected wholesale), followers/mutual visibility is
  **materialized at share time** into the ride's `allowedUserIds` array (the
  author's follower or mutual uids). The feed reads it with
  `where('allowedUserIds', arrayContains: myUid)`. Each real feed query lines up
  with exactly one rule clause (`audience=='public'` | `allowedUserIds`
  array-contains me | `userId==me`). Trade-off: audience is a snapshot at share
  time (new followers don't retroactively gain access) — acceptable/common.
- **Follow counts via `count()` aggregation**, not denormalized counters — so no
  write ever touches another user's doc, and there's nothing to spoof.
- **Unique @usernames via a reservation collection** `usernames/{handleLower}` →
  `{uid}`, claimed in a transaction. Gives global uniqueness + O(1) handle→uid
  lookup without exposing the whole users collection.
- **Votes**: net score is **derived client-side** (`upvotes - downvotes`), not
  stored — so there's no orderable score field to spoof. Feed ranking sorts a
  recent window client-side. Per-user vote doc at `rides/{id}/votes/{uid}`;
  ride-doc `upvotes`/`downvotes` bump under a bounded ±1 rule.
- **User profile doc is now public-read** (any authed user) to enable
  search/follow; writes stay owner-only and every subcollection keeps its own
  owner-only rule. Email is intentionally searchable (user requirement).

---

## 4. Firestore data model (after Phase A)

Rules: `firestore.rules`. Indexes: `firestore.indexes.json`.

| Collection | Purpose | Read | Write |
|---|---|---|---|
| `users/{uid}` (root fields) | Public profile: displayName, username, usernameLower, nickname, bio, photoUrl, email, emailLower, **visibility** (`public`\|`mutual`\|`private`, added §8b), **publicStats** (`totalDistanceKm`/`totalRides`/`badgeIds`, denormalized on ride finalize, added §8b) | `profileVisibleTo()` (§8b — defaults to any-authed for every doc that never sets `visibility`) | owner |
| `users/{uid}/{rides,bikes,maintenance,emergencyContacts,...}` | Owner-only mirrors/contacts. `bikes`/`maintenance`/`rides` metadata now sync **both ways** (§8b — was upload-only before); `ride_points` (GPS trails) still upload-only/not pulled down, a known gap | owner | owner |
| `usernames/{handleLower}` | `{uid}` reservation for unique @handles | any authed | create-if-free / owner delete |
| `follows/{followerUid}_{followeeUid}` | Follow edge | any authed | follower only |
| `rides/{rideId}` | Shared-ride feed post + `audience`, `allowedUserIds`, `upvotes`, `downvotes`, `photoUrl`, `likes`*, `comments` | `rideVisibleTo()` | owner + bounded counter bumps |
| `rides/{rideId}/{likes,votes,comments}` | Engagement | `rideVisibleTo(parent)` | own doc / authed create |
| `forums/{forumId}` + `/posts/{postId}/{replies,votes}/...` | Bike/topic/general forums (`type`, `topic`) | authed | owner + bounded counters |
| `forum_follows/{uid}_{forumId}` | Forum membership | owner | owner |
| `places/{placeId}` (+ `osmId` when OSM-imported), `reviews/{uid}_{placeId}` | POI directory + reviews | authed | owner + bounded rating |
| `liveSessions/{token}`, `crashNotifications/{id}` | Live share / crash | token / owner | owner |

New indexes added: `rides` (`audience`+`createdAt`), `rides`
(`allowedUserIds` array-contains + `createdAt`), `rides` (`userId`+`createdAt`).

_*`rides.likes`/`toggleLike()` are now dead — see §6._

---

## 5. Forward plan — remaining epics (dependency order)

Legend: ✅ done · 🔜 next · ⬜ later. Package rename = "H" (done early, blocked on §1).

### A. Profile + follow backend — ✅ done (§2c)

### B. Social UI — ✅ done, analyze-clean (not runtime-tested)
- `RideShareModel`/`SharedRideEntity` caught up to the rules shape from Phase
  A: `isPrivate` bool replaced with `audience` (`public`/`followers`/`mutual`,
  clean cutover — no prod data on this collection yet), plus `photoUrl`,
  `upvotes`, `downvotes`, and an entity-only `myVote` (hydrated from
  `votes/{uid}`, never persisted — mirrors `isLikedByCurrentUser`).
- `RideShareRepository`: `shareRide` now takes `audience` + optional
  `photoUrl` and materializes `allowedUserIds` internally via
  `FollowRepository.getFollowers`/`getMutuals`. Added `uploadRidePhoto`
  (`rideShares/{uid}/{rideId}.jpg`), `getPublicRides`/`getSharedToMe`/
  `getMyRides` (each lines up with one `rideVisibleTo()` clause, replacing
  the old single `isPrivate`-filtered query + dead `getFriendsFeed`), and
  `vote`/`getMyVote` (bounded ±1-per-field transaction matching the rules'
  vote clause exactly).
- New `ride_share_screen.dart` (route `/ride/share/:rideId`): optional photo
  picker (gallery, mirrors `add_edit_bike_screen.dart`'s pattern) + audience
  pill picker, reached from `ride_summary_screen.dart`'s Share button (its
  old inline `_shareRide`/sharing state is gone — the button just navigates).
- `ride_feed_provider.dart`: `rideFeedProvider` unions the three queries
  above, dedupes by id, sorts by `netScore` desc then `createdAt` desc.
  `RideFeedNotifier` (renamed from `RideLikeNotifier`) adds an optimistic
  `vote()` alongside the existing `toggleLike()`.
- `social_screen.dart`: feed card's single heart replaced with an
  upvote/downvote arrow pair + net score, shows `photoUrl` when present via
  `cached_network_image`. Added a "Find riders" entry above the feed opening
  a search sheet (`ProfileRepository.searchByUsername`/`searchByEmail`,
  merged on one field) with a follow/unfollow toggle per result
  (`FollowRepository`/`follow_providers.dart` — no new profile-view screen,
  out of scope here).
- `storage.rules` **created** (didn't exist before — avatar upload was
  running unbacked by any rule) and registered in `firebase.json`: owner-write
  / any-authed-read for `avatars/{uid}.jpg` and `rideShares/{uid}/{rideId}.jpg`.
  **Superseded 2026-07-23** — see §1b: Firebase Storage was dropped entirely
  in favor of Cloudinary, so this file is now dead (left in place, unwired
  from `firebase.json`, harmless to leave or delete).
- `firestore.indexes.json`: dropped the stale `isPrivate+createdAt` index,
  added `userId+createdAt` (for `getMyRides`).
- Not yet deployed: `firebase deploy --only firestore:rules,firestore:indexes,storage`
  needs to run before any of this is live (same deploy step §7 already calls
  out, storage rules are new to that list). **Superseded** — no `storage`
  deploy target exists anymore; see §1b.

### C. Forums — ✅ done, analyze-clean (not runtime-tested)
- `slugify.dart` `_slugifyPart` now treats any run of whitespace/`-`/`_` as
  one separator before stripping invalid chars, so `mt-15`/`MT 15`/`MT-15`
  all collapse to the same forum slug (previously hyphen and whitespace were
  normalized differently, so `mt-15` and `MT-15` matched but `MT 15` didn't).
- **General (non-bike) forums**: `ForumType.general` + nullable `topic` field
  on `ForumEntity`/`ForumModel`; `generalForumSlug()` (single-segment) +
  `ForumRepository.getOrCreateGeneralForum` (same create-if-missing
  transaction as the brand path). Curated topics (Maintenance, Riding Skills,
  Two-Strokes, Dirt Bikes, Spark Plug Corner) live in
  `forums_home_screen.dart`, lazy-created on tap like brand forums already
  were — no rules change needed (the `forums/{id}` create rule was already
  brand/model-agnostic).
- **Forums home is a list now**: the popular-brands `Wrap` of `ActionChip`s
  became a plain tappable list (`_DiscoverRow`), plus a matching "Topics"
  list section for the general forums above.
- **Upvote/downvote on posts**: dropped the dead unused `likes` int, added
  `upvotes`/`downvotes` + `netScore` + entity-only `myVote` on
  `ForumPostEntity` (mirrors `SharedRideEntity`). `ForumRepository.votePost`/
  `getMyPostVote` use the same bounded ±1-per-field transaction as
  `RideShareRepository.vote`; `firestore.rules` posts block gets a matching
  `votes/{uid}` subcollection and update clause (simpler than rides' — no
  audience tiers to gate reads on). New `forumPostsNotifierProvider` gives
  `forum_thread_screen.dart`'s post cards optimistic voting, mirroring
  `RideFeedNotifier`.
- **Avatars**: extracted `UserProfileEntity.initials`'s algorithm into a
  shared `initialsFrom()` (`core/utils/initials.dart`) and a new
  `shared/widgets/user_avatar.dart` (`UserAvatar`) — photo when set, else a
  GitHub-style initials circle. Wired into forum post cards, the post detail
  header, and reply tiles; `ForumReplyEntity`/`Model` gained the
  `userPhotoUrl` field they were missing entirely (`ForumRepository.addReply`
  now takes it). Also swapped the rider-search tile in `social_screen.dart`
  (Epic B) onto the same widget instead of its ad hoc `CircleAvatar`.

### D. Garage / Service — ✅ done, analyze-clean (not runtime-tested)
- **Odometer**: `odometerKm` (nullable) on `BikeEntity`/`BikeModel`/`bikes`
  table, DB **migration v4→v5** in `database_helper.dart` (`_onUpgrade` +
  `_onCreate` both updated), optional form field in `AddEditBikeScreen`.
  `BikeEntity.currentOdometerKm` = baseline + GPS-tracked `totalDistanceKm` —
  `maintenance_provider.dart`'s reminder math and `maintenance_screen.dart`'s
  header now use it instead of raw `totalDistanceKm` (the actual bug: a bike
  with real prior mileage reported intervals from zero). `bike_detail_screen.dart`
  shows it as its own stat card alongside (not replacing) Total Distance.
- **"Add bike" moved below the list**: extracted the maintenance screen's
  dashed-button look into a shared `DashedAddButton`
  (`shared/widgets/editorial.dart`), used at the end of the bike list (and in
  the empty state) — the old top-right round `_InkAddButton` is gone.
- **Header "+" → user menu**: `garage_screen.dart`'s header now shows a
  `UserAvatar` (from `myProfileProvider`, wired since Phase A but never
  consumed by any screen) that opens a menu sheet with **Edit Profile**. New
  `EditProfileScreen` (route `/profile/edit`) is the first UI for
  `ProfileRepository`'s `updateProfile`/`setUsername`/`uploadAvatar` — none
  of that had a screen before this. Scope note: the doc's "+ my places" is
  left for Epic E to add to this same menu (owned-places derivation is
  explicitly that epic's deliverable — building a placeholder now would
  duplicate it).
- **Service moves into garage**: `MaintenanceScreen` takes an optional
  `bikeId`, falling back to `activeBikeProvider` when absent (bottom-nav tab
  behavior unchanged — Epic E removes that tab). `garage_screen.dart`'s
  "Tap for maintenance" now passes its own bike's id
  (`/home/maintenance?bikeId=...`) instead of silently showing whichever bike
  happened to be active.

### E. Nav + Places — ✅ done, analyze-clean (not runtime-tested)
- **Bottom nav**: dropped Service, added **Places** (`app_shell.dart`); order
  is now Social, Rides (renamed from Insights), Record, Places, Garage.
  `/home/maintenance` stays registered (still reached from garage's per-bike
  links, Epic D) — just not a tab. `social_screen.dart`'s Places tab removed
  (now 2 tabs: Feed, Forums); `PlacesListScreen` moved from a bare `/places`
  route into the shell at `/home/places` so it gets bottom-nav chrome, and
  now owns its own `Scaffold`/`AppBar` (previously borrowed Social's).
- **Map-pin picker**: new `shared/widgets/map_location_picker.dart` — a
  fixed center pin with the map panning underneath (Google/Uber-style
  pin-drop), simpler than drag-marker gestures. `add_place_screen.dart` now
  centers on GPS but lets the rider move the pin anywhere before submitting.
- **OSM Overpass import**: manual **"Import nearby"** action in the Places
  tab's app bar (not automatic — Overpass is a free, rate-limited public
  API, decided during this epic). New `OverpassService`
  (`data/services/overpass_service.dart`) queries `amenity=fuel`,
  `craft=motorcycle_repair`, `shop=motorcycle`; `PlaceEntity`/`Model` gained
  a nullable `osmId` so re-importing never duplicates
  (`PlaceRepository.getExistingOsmIds`). **Adaptation from the original
  plan**: used the already-declared-but-unused `dio` dependency instead of
  adding a new `http` package — one less dependency, and it retires a dead
  entry in `pubspec.yaml` instead of adding a new one.
- **Owned places**: `PlaceRepository.getPlacesByOwner` (`createdBy == uid` —
  the existing `places` read rule is already "any authed", so no rules
  change needed) + new `MyPlacesListScreen` at `/places/mine`, linked from
  the garage header's user menu (`_UserMenuButton`, built in Epic D with
  this exact slot marked).

### F. Rides tab (formerly Insights) — ✅ done, analyze-clean + unit-tested (not runtime-tested)
- **Graphs**: new `RideLineChart` (`features/stats/presentation/widgets/`,
  wraps `fl_chart`'s `LineChart` — first real usage of that dependency)
  renders distance-per-ride and avg-speed-per-ride cards on the Rides tab.
  Fed by a new `RiderStatsSummary.chartRides` field (oldest→newest, capped to
  the last 20 rides — `computeRiderStats`'s existing pure-function shape,
  just sorted the other direction from `recentRides`).
- **More badges**: `core/utils/badges.dart` replaces the 5 hardcoded
  milestone tuples with 13 badges (ride-count tiers 1/10/25/50/100, distance
  tiers 100/500/1000/2500/5000 km, top-speed tiers "Ton-up"/"Speed demon",
  and a riding-score-gated "Smooth operator") — still a pure function over
  `RiderStatsSummary`, same computation style as everything else in that
  file.
- **Discount-hook foundation**: `ChallengeRepository.earnBadge()` (the dead
  method §6 pointed at) turned out to be unusable as-is for this — it also
  updates a `challengeProgress` doc that only exists for real time-boxed
  challenges, so calling it for a standalone milestone badge would throw
  not-found. Added `earnMilestoneBadge()` instead (writes only to
  `earnedBadges`) plus a fire-and-forget `badgeSyncProvider` that persists
  newly-earned badges there whenever the Rides tab is open. The UI's
  earned/not-earned display never depends on this round trip — it's purely a
  durable record for a future partner-discount feature to read later. Added
  the matching `users/{uid}/earnedBadges` rule (owner-only) to
  `firestore.rules` — it didn't exist before, so this collection was
  previously write-denied for everyone.

### G. Safety — ✅ done, unit-tested
- Root cause confirmed and fixed: `event_detector.dart`'s
  `_crashAccelThreshold` was `8.0`, commented "g (>80 m/s²)" but compared
  directly against `accel.abs()` in **m/s²** — so the crash-detection window
  opened at ~0.8g (a normal hard brake or pothole), not ~8g. Raised to `80.0`
  (m/s², ~8.2g). `crash_detector_test.dart`'s synthetic impact values were
  updated to actually clear the new threshold — they'd been well below the
  intended trigger point too, so that test would have passed even against a
  detector that never fired on anything short of an actual crash. User
  should still fine-tune with real rides per the original note; this fix
  only corrects the units bug, not the underlying sensitivity tuning.
- **Follow-up (separate initiative, not part of this v2 branch's epic list):**
  a confidence-gated crash alert landed as part of the Vehicle State Engine
  Phase 1 work — see `VEHICLE_STATE_ARCHITECTURE.md`. A crash signal is now
  only acted on if the fused GPS+IMU state clears a trust threshold, so a
  correct-but-untuned threshold firing on garbage sensor data (e.g.
  mid-tunnel GPS loss) gets suppressed instead of triggering a false
  emergency-contact notification. `event_detector.dart`'s threshold itself
  is unchanged from the fix above.

### H. Package rename — ✅ done (§2b) — §1 is resolved, no longer blocked.

---

## 6. Known code facts / gotchas (verified during audit)

- ~~`firebase_options.currentPlatform` hard-returns `ios`~~ — fixed in §1.
- ~~`fl_chart` dependency present but unused anywhere~~ — used since Epic F.
- Slug helper `bikeForumSlug` does **not** unify `-` vs `_` (Epic C).
- Odometer needs a real DB migration (Epic D) — the app currently treats
  `totalDistanceKm` (GPS-accumulated) as the de-facto odometer.
- **Dead code** (never wired to UI): `RouteRepository`, `GroupRideRepository`.
  Their Firestore rules for `groupRides` don't exist, so they'd be denied.
  `ChallengeRepository`'s `challenges`/`challengeProgress` path (the
  time-boxed monthly-challenge mechanic, `seedMonthlyChallenges` etc.) is
  *still* dead and still has no rules — Epic F only reused its
  `earnedBadges` collection shape (via the new `earnMilestoneBadge`, not the
  original `earnBadge`), not the challenge/seeding machinery. That remains
  unbuilt if a future pass wants real time-boxed challenges.
- **New dead code from Epic B**: `RideShareRepository.toggleLike`,
  `RideFeedNotifier.toggleLike`, and the `likes` field on
  `RideShareModel`/`SharedRideEntity` are no longer called from any screen —
  `social_screen.dart`'s feed card replaced the heart with the upvote/
  downvote pair and never called `toggleLike` again. The backend/rules still
  fully support it (harmless to leave), but it's now orphaned; either wire a
  caller back in or delete it in a future pass — don't be surprised it's
  unreachable.
- Placeholder in AndroidManifest: `com.bft.throttleiq.LocationForegroundService`
  is declared but there is **no matching `.kt` source** — pre-existing; harmless
  unless started.
- **`ride_points` (GPS trails) are not cloud-synced** (§8b) — only the
  `rides` metadata row and `bikes`/`maintenance` sync both ways now. A ride
  pulled down to a second device shows correct stats but an empty map.
- **`SyncManager`'s auto-sync interval (5 min) and the new download pass
  both run on every cycle** — cheap at this project's per-user data volume,
  but worth revisiting if a rider ever accumulates hundreds of bikes/rides/
  maintenance logs (unlikely, but nothing currently bounds the collection
  size the download step reads).
- `RideDao`/`BikeDao`/`MaintenanceDao`'s `getUnsynced()`/`markSynced()` and
  `CloudRepository`'s upload methods predate this doc entirely — §8b only
  added the missing download half, didn't touch the upload path.

---

## 7. How to resume / verify

All 8 epics are code-complete. What's left is runtime verification, not
implementation:

1. `cd app && flutter pub get && flutter analyze` — should stay clean (0
   errors; ignore the ~91 pre-existing lint infos/warnings, none of them
   touch code from this doc's epics).
2. `flutter test` — full suite should stay green (282 tests as of §8b,
   including coverage for `chartRides`/`badges.dart` and the Vehicle State
   Engine calculators; no new tests from §8a/§8b themselves — see §0).
3. `flutter run` (sim or device) and actually sign in / sign up — this is
   the one thing that could NOT be verified from this environment (§8:
   no simulator input-automation tool available). Walk the Rides tab
   specifically to eyeball the new charts/badges render sensibly with real
   ride data, and confirm Auth/Firestore round-trip against the new
   `com.bft.throttleiq` Firebase project actually works end-to-end (§1 only
   confirmed the app *boots* without crashing, not a full sign-in).
3a. **Highest priority real-world test**: go for an actual ride with the
   screen off for several minutes, then check that (a) the app is still
   running/recording when you check back, and (b) if it *does* get killed,
   the ride still shows up in history afterward (§8b's fix). This is the
   one thing in this doc that most needs a real ride, not a simulator, to
   confirm — accept the battery-optimization-exemption prompt on Android
   when asked, that's part of the fix.
3b. Install the app on a **second device/account combo** and confirm bikes
   added on the first device appear after a few minutes (sync fires
   immediately on sign-in, then every 5 minutes after — no manual
   "refresh" trigger exists in the garage screen today, so this is a wait,
   not a tap) — confirms §8b's download-sync fix.
4. Storage backend deploy step is moot now — Firebase Storage was dropped in
   favor of Cloudinary (§1b). Firestore rules/indexes are already deployed;
   nothing else to deploy for storage.
5. Release build to verify: signed release APK flow (JAVA_HOME = Android
   Studio JBR, key.properties present) or TestFlight for iOS.
6. Device-upgrade path checks that were never runtime-testable from here:
   Epic D bumped the local SQLite schema to v5 (`bikes.odometer_km`) — a
   device upgrading from an older installed build exercises `_onUpgrade`,
   not `_onCreate`. Epic E's OSM import is a live outbound call to
   overpass-api.de — worth a real-network smoke test.
7. Once runtime-verified, this is ready to cut a new release build/version
   bump — nothing in §5 is still ⬜.

---

## 8. Open items after this session

- ~~`flutter pub get` not re-run after removing `firebase_storage`~~ — done
  in a follow-up pass: `pubspec.lock` updated cleanly, `flutter analyze`
  stayed at 0 errors, `flutter test` stayed at 239/239.
- ~~No live sign-in walkthrough~~ — **superseded 2026-07-23**: the project
  owner walked the real app on a real device/simulator themselves (this
  environment still can't drive the UI interactively — no simulator
  input-automation tool available). That surfaced two real bugs neither
  analyze nor the unit suite could have caught, both now fixed:
  - A crash creating a forum post
    (`'_dependents.isEmpty': is not true` — an `InheritedElement` popped a
    modal sheet in the same tick as invalidating a provider that swaps the
    screen underneath it). Fixed in `forum_thread_screen.dart`, and an
    identical instance found by audit and fixed in `add_place_screen.dart`.
  - The Social feed's Feed tab showing
    `[cloud_firestore/permission-denied]` instead of any rides:
    `RideShareRepository.getSharedToMe`'s query only filtered on
    `allowedUserIds arrayContains uid`, but the matching `rideVisibleTo()`
    rule branch also requires `audience in ['followers','mutual']` —
    Firestore can't verify an AND'd rule condition the query itself doesn't
    constrain, so it rejected the whole query. Fixed by adding the explicit
    `audience` filter to the query and the matching composite index
    (deployed live).
- **Firestore has 3 stale indexes** not present in `firestore.indexes.json`
  (2 pre-existing + 1 more from replacing the `allowedUserIds+createdAt`
  index above with the corrected 3-field version — the old one is now
  orphaned). Flagged by each deploy, not removed — deploying without
  `--force` leaves them in place rather than guessing they're safe to drop.

---

## 8a. UI/nav bug wave + the forum-crash mis-diagnosis (2026-07-23, same day)

More live-usage reports came in after §8 closed. Most were fixed cleanly;
one — the forum-post crash — is worth documenting as a cautionary tale
because two fix attempts were shipped and were **both wrong**.

- **Swipe-to-start replaces hold-to-start.** `record_screen.dart`'s
  `_HoldToStartButton` (900ms long-press) replaced with `_SlideToStartButton`:
  a `GestureDetector` driving an `AnimationController` directly off
  `onPanUpdate` (0→100% tracks the drag continuously, not just on release),
  committing the start at ≥60% on release (`onPanEnd`) and snapping back to
  0 otherwise. Not confirmed by the project owner as feeling right yet
  (drag mechanics/threshold) — flag if it needs tuning.
- **Navigator key-collision crash** (`keyReservation.contains(key)` —
  different bug from the InheritedElement one below) in
  `garage_screen.dart`'s `_UserMenuButton._showMenu`: it called
  `Navigator.pop(sheetContext)` immediately followed by `context.push(...)`
  in the same synchronous callback, racing the imperative sheet-pop against
  go_router's declarative page-list update. Fixed by returning the
  destination as the sheet's pop *result* and pushing only after that
  Future resolves — same fix applied to `bike_detail_screen.dart`'s delete
  confirmation, which had the identical shape.
- **Forum-post crash — fixed on the third attempt, first two were wrong.**
  Reported three separate times (same `'_dependents.isEmpty': is not true`
  assertion each time) before it was actually fixed:
  1. First attempt: reordered `Navigator.pop(sheetContext)` before
     `ref.invalidate(...)` in `_showNewPostSheet`. Theory: an
     invalidate-before-pop race. **Didn't fix it** — crash reproduced again.
  2. Second attempt: switched to `showModalBottomSheet<bool>`, moved the
     `ref.invalidate(...)` into `.then((posted) => ...)`. Theory: `.then()`
     only fires after the sheet's exit animation fully finishes, a
     "stronger guarantee." **This assumption was wrong** — `.then()` fires
     as soon as `Navigator.pop` is *called*, not once the animated
     transition has finished rendering. Crash reproduced a third time.
  3. Third attempt (the actual fix): pulled the **full stack trace** from
     the running `flutter run` process's console output instead of just the
     on-device red-screen summary — the summary only showed the
     `_dependents.isEmpty` assertion, which is a *cascading symptom*; the
     full trace revealed the real root exception: `A TextEditingController
     was used after being disposed` on the sheet's `TextField`. The old
     code created `titleController`/`bodyController` as locals in
     `_showNewPostSheet` and disposed them in the `.then()` callback from
     attempt 2 — which, per the finding above, fires before the exit
     animation finishes, so it disposed controllers still referenced by
     widgets mid-transition. Fixed by extracting the sheet into its own
     `_NewPostSheet extends ConsumerStatefulWidget`, with the controllers as
     `State` fields disposed in `State.dispose()` — a lifecycle Flutter
     guarantees runs only once the widget is actually gone, not merely
     "popped." The same audit found and fixed an identical-shaped (non-crashing,
     just a leak) case in `settings_screen.dart`'s `_showContactDialog`.
  - **Lesson for next time a fix "doesn't stick":** get the full stack
    trace from the running process's own console output before re-theorizing
    from the on-device summary text — the summary can omit the actual
    originating exception entirely.
- **Firestore permission-denied on the Social feed and Navigator/forum
  fixes above were verified only via `flutter analyze`/`flutter test`/clean
  simulator boot** — none were re-confirmed by an actual interactive retest
  before the next bug wave (§8b) arrived, since this environment still has
  no touch-injection tool.

---

## 8b. Second live-usage bug wave (2026-07-23) — sync, safety, and a new profile feature

A much larger bug/feature report arrived covering real riding usage, not
just UI interaction. In priority order (most safety-critical first):

### Ride data lost when the app is killed mid-ride, screen off
The most serious bug reported this project has had: riding with the screen
off, the app would get killed by the OS after a while (not immediately —
"kichukkhon pore," matching a background-process kill, not an instant
crash), and the ride would then be **completely missing from history** —
not partial, gone. Root-caused to two compounding bugs, both fixed:
- `RideRecordingNotifier.recoverCrashRide()` — meant to finalize a ride
  left dangling by an unclean app death — **existed but was never called
  from anywhere**. Now wired to run on every app startup for a signed-in
  user (`app.dart`, alongside `startAutoSync()`).
- `RideDao.getAllForBike`/`getAllForUser` both filter on
  `status = 'completed'`. A ride killed mid-recording stays at its initial
  `status = 'active'` forever, so even if `recoverCrashRide()` *had* run
  historically, an unfinished ride would still never have appeared in
  history — indistinguishable from data loss.
- `recoverCrashRide()` was rewritten to actually be useful: it recomputes
  real distance/avg/max speed from whatever `ride_points` made it to disk
  (the in-memory running aggregates don't survive process death) using a
  haversine sum, then finalizes the ride to `status = 'completed'`. Rides
  with under 2 persisted points are deleted rather than left as
  zero-everything clutter. Hard-brake/rapid-accel/high-jerk counts can't be
  reconstructed this way and are left at 0 for a recovered ride — a real,
  small, and honestly-scoped limitation.
- **Shrunk the data-loss window itself**: the point-write buffer went from
  20 points/10s to 5 points/3s (`_bufferFlushSize`/`_bufferFlushInterval` in
  `ride_recording_provider.dart`), and a `WidgetsBindingObserver` now force-
  flushes the buffer the instant the app leaves the foreground
  (`AppLifecycleState.paused`/`inactive`/`detached`/`hidden`) — screen-off is
  exactly the moment before an unexpected kill becomes likely, so this is
  the most direct fix for the reported symptom.
- **Android battery-optimization exemption requested** (`permission_handler`
  was already a dependency): several OEMs (Xiaomi/MIUI, Samsung, etc.) kill
  background processes even with an active foreground service unless the
  app is explicitly whitelisted — the most likely actual cause of the kill
  itself, as opposed to the data-loss-once-killed problem above. Added
  `android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` to
  `AndroidManifest.xml` and a best-effort request in `_requestPermissions()`.
- **Not yet confirmed by a real ride** — this can only be verified by
  actually riding with the screen off for a while, which this environment
  cannot do. Flag as the single highest-priority thing to real-world-test
  next.

### Bikes (and rides/maintenance) missing on a second device
Reported as: added bikes on the iOS simulator, installed the Android APK
under the same account, bikes weren't there. Root cause: `SyncManager`/
`CloudRepository` (§ existing, pre-dates this doc) only ever **uploaded**
local SQLite rows to Firestore — nothing ever pulled cloud data back down to
a device with an empty local DB. Fixed with new `CloudRepository.downloadBikes`/
`downloadMaintenance`/`downloadRides`, called at the start of every sync
cycle: pulls any cloud row not present locally by id (never overwrites a
local row, so an unsynced local edit can't be clobbered). Bikes specifically
also handle the "which bike is active" conflict (never let more than one
bike be `is_active` after a pull) and null out `image_path` (a local file
path from a different device is meaningless here). **Deliberately not
synced**: `ride_points` (the GPS trail) — `uploadRides` only ever pushed the
`rides` metadata row, never the point-by-point track, so a ride pulled down
to a new device shows in history with correct stats but an empty map.
Flagged, not silently left unaddressed — fixing it is a materially bigger
change (GPS-trail data volume) than this pass scoped.

### Maintenance page unreachable
Reported as "I can't find it anywhere," despite `garage_screen.dart` already
having a "Tap for maintenance" link on every bike card. Root cause: that
link was a `GestureDetector` **nested inside** the whole card's own tap
region (which navigates to bike detail). A plain `GestureDetector` only
hit-tests the *painted pixels* of its child, not the full row — most of
that row's visual width was empty space that silently fell through to the
outer card's tap, sending riders to bike detail instead. It looked
full-width tappable but usually wasn't. Fixed with
`behavior: HitTestBehavior.opaque` on the inner detector. The exact same
shape of bug was pre-emptively fixed on the forum post-card's author byline
(see username/profile section below) rather than waiting for it to be
reported too.

### Forum upvotes/downvotes "lost"
Audited the vote code (`forum_providers.dart`'s `ForumPostsNotifier.vote`,
`ForumRepository.votePost`, and the matching bounded ±1-per-field Firestore
rule) end-to-end and found no correctness bug — the transaction shape is
sound and matches the equivalent ride-share vote logic exactly. What *was*
wrong: a failed vote write was caught and silently reverted with **zero
user feedback**, which looks exactly like "my vote disappeared" from the
outside with nothing to distinguish a real failure from a display glitch.
`vote()` now rethrows after reverting; the call sites in
`forum_thread_screen.dart` show a SnackBar on failure. If votes are still
observed disappearing after this, that's a signal the actual write is
failing (worth checking connectivity/auth state at the time), not a logic
bug in the vote code itself.

### New: username system + public profile + privacy
A username system (reservation, search, `EditProfileScreen` field) already
existed from Phase A but was never surfaced at signup and had no screen to
view anyone else's profile. Added:
- **Auto-assigned @handle for every rider**: `AuthNotifier._ensureUsername`
  runs on every login (register, Google sign-in, or an existing account),
  best-effort, defaulting to the email's local part with a numeric-suffix
  retry loop on collision (`ProfileRepository.suggestUsernameBase`/
  `claimUsernameWithFallback`) — covers legacy accounts and anyone who skips
  onboarding, not just new signups.
- **Onboarding step 0 now also offers a username field**, prefilled with the
  same suggestion, editable, validated inline against the existing
  `^[a-z0-9_]{3,20}$` rule before continuing.
- **New `UserProfileScreen`** (route `/profile/:uid` — note `/profile/edit`
  is a separate literal route that must stay listed *before* this param
  route so it keeps matching first): avatar, bio, follower/following counts,
  a Follow button, total km/rides, and earned badges. Reached by tapping a
  rider's name/avatar in "Find riders" search results (`social_screen.dart`)
  or a forum post's author byline (`forum_thread_screen.dart`) — this also
  covers the "add people from their forum posts" request, since the profile
  screen is where Follow lives.
- **Privacy tri-state**: `UserProfileEntity.visibility` (`public` default /
  `mutual` / `private`), set from a `SegmentedButton` in `EditProfileScreen`.
  Enforced by a **deployed** `firestore.rules` change (`profileVisibleTo()`),
  not just a UI check — `mutual` checks both follow edges exist via two
  `exists()` calls (cheap: a profile view is always a single-doc read, never
  a list query, so this doesn't hit the "rules can't filter list queries"
  problem that shaped the ride-audience design in §3). Defaults to today's
  fully-open behavior for every profile that never sets it, so this is
  backward-compatible, not a regression.
- **Stats/badges design choice**: rather than opening the owner-only
  `rides`/`bikes` subcollections to cross-user reads (bigger surface, and
  those can carry more than a viewer should see), total km/rides/earned
  badge ids are **denormalized onto `users/{uid}.publicStats`**, recomputed
  and written by the owner's own device on every `stopRide()` from the
  already-existing pure `computeRiderStats`/`computeBadges` functions. Gated
  by the same `visibility` field as the rest of the profile doc. Means a
  public profile's stats can lag slightly behind reality between rides —
  same "write-behind, not blocking" trade-off Epic F already made for badge
  sync.

**Verification for all of §8b**: `flutter analyze` clean (0 new issues over
the pre-existing baseline), `flutter test` green (282/282 — no new tests
added this pass, all existing coverage stayed green including
`sync_manager_test.dart`), `flutter run` boots clean on the iOS simulator
with no runtime exceptions in the console. `firestore.rules` deployed live
to `throttleiqfb`. **Not verified**: any of this against real multi-device
usage, a real kill-mid-ride scenario, or an interactive UI walkthrough —
same standing limitation as every prior wave (no touch-injection tool in
this environment).

---

## 8c. Polish wave (2026-07-24) — notifications, speed responsiveness, app icon, dashboard taglines

A round of smaller product asks, done after §8b landed. Test suite stayed at
282/282 (no new tests — same UI/plumbing-code gap noted for prior waves).

- **Follow notifications, in-app only.** Following someone was completely
  silent before (no signal to the other rider at all). Added
  `users/{uid}/notifications/{id}` (new `NotificationRepository`,
  `AppNotificationEntity`, `notification_providers.dart`), written by the
  *follower's* device right after `FollowRepository.follow()` — the matching
  `firestore.rules` clause is the one owner-*write* exception in the whole
  `users/{uid}` subtree (bounded to `fromUid == request.auth.uid` so nobody
  can spoof who a notification is from). New bell icon + unread badge on the
  dashboard, new `NotificationsScreen` (route `/notifications`), tapping a
  notification opens the follower's profile and marks it read; opening the
  screen marks everything read in one batch. **Deliberately not a phone
  push** — real push needs a Cloud Function, and Cloud Functions can't be
  deployed on this project without the Blaze plan (no payment card, see
  §1b) — same blocker `functions/src/crash-notifications.ts` already has
  (it's mocked, never deployed). Documented directly on
  `AppNotificationEntity` so this doesn't get mistaken for a push system
  later.
- **Speed display responsiveness.** Reported as "speed updates feel slow."
  Two real, separate causes fixed: (1) `_startLocationStream` had no
  iOS-specific branch at all — it was constructing an `AndroidSettings`
  object and passing it on every platform, so iOS only picked up the
  fields it happens to share with the base `LocationSettings` class and
  silently ignored the rest. Added an `AppleSettings` branch
  (`ActivityType.automotiveNavigation`, `pauseLocationUpdatesAutomatically:
  false`). (2) Tightened both platforms' `distanceFilter` (5m→3m) and
  requested a `bestForNavigation` accuracy profile instead of plain `high`
  — the profile actually meant for turn-by-turn driving apps. On top of
  that, wrapped the active-ride speed number in a `TweenAnimationBuilder`
  (~450ms ease) so it glides between real fixes instead of hard-jumping —
  real GPS fixes are still discrete events, this just masks the gaps.
- **New app icon.** `pubspec.yaml`'s `flutter_launcher_icons` config pointed
  at `assets/images/app_icon*.png` paths that **didn't exist** (a stale
  placeholder note in `todosanddone.md` had this half-right — the paths
  were never actually created, not just placeholders). Found the real
  design source already in the repo (`designs/logo2/throttleiq-icon-v2.svg`
  — a self-contained 512×512 gauge mark, blue→green→orange, matching the
  app's actual palette), rasterized it at 1024×1024 via `rsvg-convert`
  rather than upscaling the small existing PNG, and fixed a transparency
  issue in the source (the rounded-corner background left the corners at
  alpha=0, which `remove_alpha_ios: true` would've flattened to an
  arbitrary/white fill — added an opaque backing rect of the same color
  first). Also fixed a real bug in the `flutter_launcher_icons` config
  itself: `windows: false`/`macos: false`/`web: false` crashed the tool
  outright on this version (0.13.1) — expects a map or omitted key, not a
  bare `false`. Regenerated both platforms' icon sets via
  `dart run flutter_launcher_icons`.
- **Rotating dashboard taglines.** The hero panel always said "Your ride,
  smarter." — replaced with `motorcycleQuotes` (16 original two-line
  taglines, not attributed quotes from any named person, to avoid any
  misattribution risk), picked once via a plain Riverpod `Provider`
  (`dashboardQuoteProvider`) so it's stable for the whole app session
  (Riverpod providers are memoized per container) and different again next
  cold start.

---

## 9. Decisions made autonomously this session (2026-07-23)

Working through this doc's remaining items end-to-end without checking in
per-step; logging every judgment call made along the way:

1. **Continued committing directly to `main`**, matching what every prior
   epic in this doc actually did (see the branch note at the top) — creating
   a `feat/v2-social` branch retroactively would fragment history rather
   than fix anything.
2. **Committed §1 (Firebase reconfig)** as its own commit before starting new
   work — it was sitting uncommitted from a prior session.
3. **Crash threshold raised to exactly 80.0 m/s²** (~8.2g) rather than a
   round 78.4 (8g × 9.8) — matched the existing code comment's stated intent
   verbatim rather than introducing a different number with the same doc
   already asking the user to fine-tune it against real rides anyway.
4. **Epic F's badge persistence scoped down** from what `ChallengeRepository`
   suggests is possible: reused only the `earnedBadges` collection shape,
   not the `challenges`/`challengeProgress`/monthly-seeding mechanic
   (§6) — that's a materially bigger feature (admin challenge creation, time
   windows, a seeding cron) than "more badges" asked for, and bolting
   milestone badges onto the *existing* buggy `earnBadge()` would have thrown
   at runtime (it updates a `challengeProgress` doc that doesn't exist for a
   milestone that isn't a real challenge). Wrote `earnMilestoneBadge()`
   instead, added the missing Firestore rule for the collection it uses.
5. **Badge sync is fire-and-forget, not blocking.** The Rides tab's
   earned/not-earned display is always computed live from local data;
   Firestore is a write-behind durability layer only, wrapped in a bare
   `try/catch` so a network hiccup never surfaces as UI breakage. This means
   the "discount-hook foundation" data can lag behind what the UI shows by
   however long the round trip takes — acceptable since nothing reads it yet.
6. **Chart data capped to the last 20 rides** (`chartLimit` param on
   `computeRiderStats`, defaults to 20) rather than plotting full ride
   history — no UI spec existed to pull a number from, and unbounded history
   risks a cluttered chart for a rider with hundreds of logged rides.
7. **Deployed `firestore:rules` and `firestore:indexes` to the live
   `throttleiqfb` project** without asking first — the handoff doc already
   named this as an explicit outstanding step (§7 in the prior version of
   this doc) and the user's instructions for this session were to complete
   everything left in the doc autonomously. Did **not** deploy `storage`
   (blocked, see §8) and did not use `--force` to prune the 2 stale indexes
   (destructive, and not asked for).
8. **Did not attempt to provision Firebase Storage** by other means (e.g.
   `gcloud` bucket creation) after the console-only error — that's a
   provisioning decision (region, pricing tier) that belongs to the project
   owner, not something to guess through a side channel.
9. **Stopped short of forcing simulator UI automation** (e.g. granting this
   environment's terminal Accessibility permissions to unblock AppleScript)
   — that's a macOS security setting change with effects beyond this one
   task, not something to flip autonomously for a single verification step.
10. **Did not upgrade `throttleiqfb` to the Blaze plan on the user's behalf.**
    Entering a payment method is something an agent should never do even
    with explicit permission — surfaced the requirement, asked the user, and
    when they confirmed no card was available, proposed Cloudinary as a
    concrete alternative rather than leaving the feature blocked indefinitely.
11. **Cloudinary preset created via console clicks, not blind config** — used
    the account the user was already logged into, created an *unsigned*
    preset specifically (never a signed one, which would need the API
    secret embedded in the client — a real credential, unlike an unsigned
    preset name).
12. **Bucket region question asked explicitly rather than assumed** — Firestore
    was already in `asia-south1` for the stated Dhaka user base; offered the
    same-region-vs-guaranteed-free-tier-region trade-off as a real choice
    rather than picking one silently (moot after the Cloudinary pivot, but
    the reasoning is preserved here since it's exactly the kind of call this
    log exists to capture).

### 2026-07-23 continued (§8a/§8b — second and third bug waves)

13. **Got the real stack trace before re-theorizing a second time**, after
    the first forum-crash fix (reordering pop/invalidate) didn't hold —
    pulled it from the running `flutter run` process's console rather than
    guessing again from the on-device summary. This is the single most
    reusable lesson from this session and is written up in full in §8a.
14. **Buffer flush shrunk from 20pts/10s to 5pts/3s** — a deliberate
    trade-off of more frequent disk writes (battery/IO cost) for a much
    smaller data-loss window on an unexpected kill. Not tuned against a real
    device's actual write latency/battery impact — flagged as something to
    revisit if it turns out to be too aggressive in practice.
15. **Requested Android battery-optimization exemption without asking
    first** — a permission prompt the rider can decline, not a background
    config change; declining just means the pre-existing (imperfect) kill
    resistance is all they get, so there's no downside to asking.
16. **Deployed the `firestore.rules` change for profile `visibility` to the
    live `throttleiqfb` project** without asking first, same reasoning as
    decision 7 — it's additive/backward-compatible (defaults every existing
    profile to today's fully-open read behavior) and directly implements
    what was asked for.
17. **Chose to denormalize `publicStats` onto the profile doc rather than
    opening the `rides`/`bikes` subcollections to cross-user reads** for the
    new profile screen's stats/badges — smaller new attack surface (three
    numbers + a badge-id list vs. full ride/bike records), and reuses the
    existing pure `computeRiderStats`/`computeBadges` functions instead of
    writing new cross-user aggregation logic.
18. **Did not attempt to sync `ride_points` (GPS trails) to Firestore** as
    part of the bike/ride sync fix — recognized it as a materially bigger
    change (data volume, and no existing upload path even for it) than the
    reported bug (bikes missing) actually required. Documented as an open
    gap (§8b) rather than silently left unaddressed.
19. **Made username selection skippable-but-defaulted rather than a hard
    onboarding gate** — the router's onboarding redirect only keys off
    `displayName`, not username; extending that gate to also block on a
    missing username was available but would have made a rider who
    legitimately wants to skip get stuck in a redirect loop. The auto-assign
    fallback (`_ensureUsername`) means every rider ends up with a handle
    either way, so a hard gate wasn't necessary to guarantee the outcome.
