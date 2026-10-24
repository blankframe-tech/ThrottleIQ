# Features

_Last updated: 2026-10-22 · Source: `app/lib/features/**` and `app/lib/core/router/app_router.dart` · Latest release: `beta-v4.7.1` (1.0.0-beta.4.7.1+29)_

What a signed-in rider can do in the app today, organised by the bottom nav. Update this file when screens, routes or user-facing flows change. History of fixes lives in `issues_fixed.md`; open work in `issues_open.md`; project state in `HANDOFF_Document.md`.

**Verification status.** This file was written from the code and the tests, not from a device. Anything marked "not checked on a device" has passed `scripts/check.sh` only. The app has not been driven screen by screen on a simulator since 2026-08; the 2026-10-21 simulator E2E run covered launch and ride teardown only. Screenshots of every screen are still outstanding.

**Facts that apply everywhere**

- Two themes: **Calming** light (default) and **Carbon Mono** dark, chosen in Settings as System / Dark / Light (`core/theme/`). One rounded shape profile. Nothing else is configurable.
- Fully localised: English and Bangla (or follow the phone). Bangla strings are machine-drafted and wait for native review (`app/lib/l10n/bn_pending_review.txt`). Numerals stay 0-9 in Bangla on purpose.
- Offline first: rides, bikes, maintenance and fuel live in SQLite (schema v29, `core/database/database_helper.dart`) and sync to Firestore through `SyncManager` and a durable outbox. When both devices edit one record, the later `updated_at` wins. Details: `DOCS/For Devs and Contributors/architecture/arch.md` §5.
- Firebase is on the free Spark plan: no Cloud Functions run in production. Anything that needs one (SMS or email alerts, scheduled purges, push) is not live.
- The Realtime Database is retired. Its rules deny every read and write and release builds carry no `RTDB_URL`. The client code in `core/realtime/` (live-share position, chat "typing…") stays but does nothing.
- Crash detection runs in **shadow mode only**: it records and asks after the ride, and sends no alert to anyone. See "Shadow-mode crash detection" below.

## Your ThrottleIQ: app modules (Settings → Your ThrottleIQ)

Lets minimalist or privacy-minded riders turn parts of the app off. Device-local (SharedPreferences `module_*`); nothing is deleted. Model: `core/services/app_modules.dart`. Turning a module off asks first, and the nav updates live.

- **Community:** Everything / Forums only / Off. Forums only: the first tab becomes **Forums**, and the ride feed, people, chat, follows, follow QR, notifications bell, group rides, ride sharing and other riders' profiles are hidden. Off: the tab and every "Share to forum" / "Ask owners" entry go too.
- **Places & routes:** hides the Places tab, My places, routes and "Save as route".
- **Ride tracking:** off makes a maintenance-only app. Record and Rides are replaced by a **Maintenance** tab, auto-tracking is refused, and the odometer is synced by hand.
- One route gate: `AppModules.redirectFor` inside the router redirect, so deep links, widgets and notifications land on the home tab. The feature tour skips steps for modules that are off.

## UI hierarchy

```
Splash → Login / Register → Onboarding (first sign-in, until displayName is set)
(any screen) → Update required (blocking, when this build < config/app.minBuild)
(Android release, not from Google Play) → Install-from-Play screen (App Check sideload gate)

Bottom nav (AppShell): Social · Places · ●Record · Rides · Garage
Social  → Rides | People | Forums tabs → forum thread → post detail; create forum; chats
Places  → hub: Places | Routes | Saved → place detail, add place, my places
Record  → active ride → ride summary → share → save as route
Record  → group: invite friends / join with code → group ride map
Rides   → analytics detail; all rides → ride summary
Garage  → header (profile menu, notifications, settings) → bike detail → edit / add bike
          → maintenance → add visit, part detail, setup, fuel log

Full screen (no bottom nav): Settings, Notifications, Profile, Edit Profile, User Profile (:uid),
Ride Summary, Ride Share, Forum Thread/Post, Create Forum, Routes, Save Route, Group Ride map, Chats
```

While a ride runs, a **ride-in-progress strip** above the bottom nav ("Recording ride · km · time" or "Ride paused") returns to `/ride/active` from any shell tab. When paused with a parking pin it offers **Directions to bike**.

## 1. Auth & onboarding (`features/auth`)

- Splash routes by auth state. Login: email/password and "Continue with Google". Register: the same, plus "Continue with Google" (same `signInWithGoogle()`).
- **Onboarding** after first sign-in: profile name, first bike (Brand/Model use the suggest-as-you-type `BrandModelAutocompleteField`), then the feature tour (`onboarding_manifest.dart`, `kOnboardingManifestVersion` 5: record, cockpit, rides and badges, garage, profile/QR, auto-tracking, maintenance, places, social; grouped by tab). Each step shows a real capture of its screen (`assets/images/tour_*.jpg`) with numbered callouts pinned on it, in one accent colour. Since 2026-10-25 the capture sits on the left (up to 42% of the width) and the text on the right, scaled down to fit, so no step scrolls. Bump the version when the slide list changes so finished riders see the new tour. The tour also runs from Settings.
- **Forced update gate** (`core/services/app_update_gate.dart`): at start the app reads `config/app.minBuild` (now 29). A lower build shows a blocking screen that opens `https://blankframe.tech/ThrottleIQ/install`. Offline, slow (5 s), denied or missing all fail open.
- **App Check sideload gate** (`core/services/app_check_gate.dart`, `d92f694e`): an Android release build that App Check rejects (not installed from Google Play) shows "Install from Google Play". iOS and debug-provider builds are never blocked. Runbook: `DOCS/For Devs and Contributors/guides/app_check.md`. Not released yet.

## 2. Record a ride (`features/ride`)

- **Record screen** (center tab, default): bike-photo hero with a time-aware greeting, a stat strip (rides, km, current day streak), the Solo/Group selector, and a pinned **hold-to-start** ring (`HoldToStartButton`, 900 ms) with the quote as a footer. "Add a bike" card when no bike exists.
  - With two or more bikes, tapping the hero opens a picker sheet; with one, there is no switch control. The background tints with the bike's colour when it has a photo.
  - A blocked start (GPS off, permission denied) shows a persistent card and a snackbar with a "Turn on Location" / "Settings" action.
  - Auto-tracking and the home-screen widgets only open Record; recording still needs the hold.
- **Active ride** (`/ride/active`): live map (speed-coloured trail), timer, pause/resume, end ride, discard, share live location, alerts and phone placement.
  - **End ride** opens a bottom sheet: hold-to-end (1.2 s), a share toggle, "Keep riding". **Discard** is a text button below; nothing of a discarded ride leaves the phone.
  - Pausing stops GPS (Android tracking notification stops too) and dims the map only.
  - **Cockpit alerts:** ease on the brakes, smooth on the throttle, watch your speed (one alert per excursion), time for a break (after 90 min, repeating every 15 min). All EN/BN. Cockpit text has a minimum size; text scaling is capped at 1.3×.
  - **Share live location:** tapping the icon is the opt-in. It makes a `/live/{token}` link (viewer at `throttleiqfb.web.app`, with an install call-to-action). While live, the icon offers "Share link again" and "Stop sharing now". The permanent `/r/{username}` link is the password link: with Settings → Privacy & Safety → "Password link (/r/@handle)" on (default off, password 8+ chars), every in-app ride shares to it automatically, the viewer asks for the password, and after the ride it shows the last known location ("Last seen", open in Maps). Backed by `handleLinks/{sha256(uid+password)}`; the old public `livePointers/{uid}` is owner-only. Ending the ride cancels the live session in the background through the outbox.
  - **⋮ menu** (`ride_actions_menu.dart`): **Cop checkpoint here** writes a public `police` place at the current fix, expiring in 24 h or permanent (name is fixed English text). **Parking pin** saves a device-only pin and pauses the ride. **Minimize** goes to Places (or Rides with Places off); recording continues, but turn guidance and alert flashes are not visible.
  - **Phone placement** pill (top-left): On a mount / In a pocket / In a bag; read at impact time by the crash detector and remembered between rides.
  - **Group talk** button opens the live group map; the Record screen shows an "Open push-to-talk" banner during a group ride.
  - **Beta-only:** the handles in `BetaTesters.jamLabelling` (`core/constants/beta_testers.dart`) get an "I'm in a jam" button that writes labelled jam windows to `users/{uid}/rides/{id}/jamLabels` for tuning the jam algorithm.
- **A ride survives the app being killed.** On next launch `restoreInterruptedRide` brings it back **paused** ("Ride kept from last time"): resume, end and save, or discard. Aggregates are rebuilt from stored fixes; elapsed time is snapshotted every 10 s; event counts restart at 0. Every fix is written through until 8 points are stored, so a ride killed in its first seconds is kept. A finished ride is never offered back. On Android the foreground service keeps storing fixes if the UI dies (after 20 s without a heartbeat) and posts "Recording stopped, tap to resume" if everything dies; Xiaomi, OPPO, vivo and realme riders get a one-time battery-settings guide. Not checked on a device.
- **Ending and sharing work offline.** Share and live-share teardown go through the durable outbox (`core/cloud/outbox_service.dart`): written to SQLite first, drained on connectivity change, login and a 5-minute timer, with backoff 30 s to 30 min. Photo uploads resume instead of restarting. The composer says "Saved, we'll post it when you're back online". Not checked on a device (airplane-mode test pending).
- **Ride summary** (`/ride/summary/:rideId`): riding score (0-100), interactive map with speed bands and a legend, 4-stat and jam cards (moving vs in jam), Riding Pace card, Speed and Elevation profile charts (elevation hidden when there is no barometer data or the trace is flat), Route GPS Details, **Ride cost** card (distance × Σ cost/km, with fuel price and mileage per bike), "Faster than usual here" card, share, **Save as Route**, export **JSON / GPX / CSV**, **Delete ride**, **Report a crash or fall**, and **Share to forum**.
  - **Change bike:** "Logged to {bike} · CHANGE" appears only for the latest completed ride, with 2+ bikes. It also patches the shared post's bike fields.
  - **Faster than usual here:** after each ride the app contributes anonymous per-segment speeds (geohash-7 cell, weekday, hour, weather code from Open-Meteo; no uid, ride id or coordinates) to a shared pool and privately checks for a statistical outlier (z-score and a km/h floor). Needs 5+ prior samples on a cell, so it rarely fires yet.
  - Close and "Save & done" pop back to the list the ride was opened from.
  - A ride that recorded a crash signal shows a "Suspected crash" badge in All rides.
- **Auto-tracking** (Settings, `AutoTrackingTile`): an opt-in all-day detector (free stack, `auto_tracking_service.dart`). It re-checks the real OS "Always" permission each time it is shown, and has **Active hours** (a daily window). It stands down while a manual ride is running, paused included. Detected trips are not saved as rides: they merge into a **daily ride summary** (fragments within 20 min merge; km, ride time, time stopped) shown as a "Today" row, in "Daily ride summaries" (last 14 days) and in a 9 pm notification. Detected distance not covered by a recorded ride adds to the active bike's odometer. Not checked on a device.
- **Route following:** see §6a. Directions from a place also starts a ride (§6).

## 3. Rides / stats (`features/stats`): bottom nav tab "Rides"

- Rank/level card (New Rider to Road Master, 500 km per level), a slim level bar and a dense 4-stat strip.
- **Analytics:** 16 stacked chart cards (distance, speeds, duration, moving vs stopped, jam time, riding score, hard brakes, rapid accel, overspeed alerts, riding-days heatmap and streaks, rides by hour and weekday, distance per bike, longest rides, max lean, peak g, elevation gain, fuel spend per month, km/L, cost per km, litres per month). A tap opens `AnalyticsDetailScreen`: range 7D to All, min/max/avg/total, trend against the previous period, per-ride table, CSV through the share sheet. Logic: `stats/domain/ride_analytics.dart`. Lean and g are GPS-kinematic estimates (about ±3-5° on long sweepers, under-read on tight turns); elevation comes from stored altitude.
- **Badges** (`BadgeGrid`): one tile per family (rides, distance, long ride, streaks, and more in `core/utils/badges.dart`), with bronze-to-diamond tiers. A tap opens a ladder; a tier opens `BadgeDetailSheet` (earned date or progress, share). The top-speed family and the "X% of riders own this" and rarity figures are gone: riders can award themselves badges, so the counts meant nothing. The client still increments the `stats/badges` counters that the rules pair with each award.
- **Sortable rides list:** Recent / Top speed / Distance / Duration / Best score; ranks the full history, ties by recency, missing values last, not persisted. **All rides** (`/rides/all`) has the same chips, infinite scroll, route thumbnails, a "Followed \<route\>" pill, and the "Suspected crash" badge.
- Errors show a plain message with "Try again" (shared `ErrorView`). Empty state for zero rides.

## 4. Garage (`features/garage`): bottom nav tab "Garage" (route `/home/profile`)

- **Header:** profile summary (menu: Profile, My Places, My Shared Rides), notifications bell with unread badge, and Settings gear.
- **Your Bikes:** list with photo, **Add/Edit Bike** (`/home/profile/add`, `/:bikeId/edit`): brand/model suggestions from `core/constants/bike_catalog.dart` (Bangladesh market; Yamaha FZ-S generations converge on one `FZS`), a 12-swatch colour picker or Auto, and a photo with an in-app cropper (Free / 1:1 / 4:3 / 16:9, rotate; offered, not forced). Photos fall back to an icon when the file is missing, which is normal for a bike synced from another device.
- **Bike detail** (`/home/profile/:bikeId`): info, Service & maintenance card, fuel card, **Discuss this bike** and **Ask owners** (forum), and removal.
- **Removing a bike archives it** (`ArchiveBikeDialog`): four unticked options (shared rides, calculated miles, service logs, photos). After archiving, the rider gets the deletion date (90 days), *Download a local copy* (JSON), *Delete now* (type the name) and *Done*. The garage has a collapsible "Archived bikes" list ("Deleted in N days") with Unarchive. `BikeArchiveService.purgeExpired` runs on app start, so a bike is purged only once the app is opened after its deadline (Spark has no scheduled functions). Deletes are durable (tombstones; `SyncManager` removes the Firestore copy).
- **Fuel log** (`/home/maintenance/fuel`, `/fuel/add`): fill-ups synced to `users/{uid}/fuelLogs`; km/L between full-tank fills.

## 5. Maintenance (`features/maintenance`): reached from Garage / bike detail

Redesigned 2026-10-07 to answer "what does my bike need next, and when?". Not checked on a device. Open items: `issues_open.md` §95.

- **Engine** (`domain/calculators/maintenance_forecast.dart`) is the only definition of "due": the page, part detail, bike detail, garage card, widget and notifications all use it.
  - Km or time, whichever comes first (`interval_km`, optional `interval_days`). Default warning windows: 20% / last 150 km, and 15% of the days (clamped 3-30). Riders can set their own.
  - Projected date = km left ÷ average daily km over 30 days (rides plus detected trips).
  - Baselines: last log, else the rider's "last done", else the bike's add date (only if it had ≤ 500 km then). Otherwise the check is **unknown** ("Set last done"), never overdue by guesswork.
  - **Riding adaptation** (`riding_conditions.dart`, switch "Adapt to my riding"): stop-and-go share (oil, filter, clutch × 0.8-0.9), 3+ hard brakes per 100 km (pads, rotors × 0.85), a "dusty, wet or broken roads" profile (air filter, chain × 0.7, chain slack × 0.8). Combined factor floor 0.7; time limits are never scaled.
- **Setup** (`/home/maintenance/setup`): schedule template (Pulsar 150, Hornet 160, FZ, R15/MT-15, Gixxer, Apache 160 matched by brand/model, else generic ≤125 / 126-200 / >200 cc; each with its free-service schedule), roads, oil grade (mineral 1,500 km / 180 d, semi 2,500 / 240, full synthetic 3,500 / 365), last oil change, then notification permission. Intervals the rider set (`source = user`) are never retuned.
- **Page** (`/home/maintenance?bikeId=`), top to bottom: setup card; **Up next** hero (Done it / Remind me later for 3 days; "All good until ~date" when nothing is due within 14 days); 60-day strip; checks grouped Needs attention / Coming up / All good / Not known yet; **Quick check** (6 MSF T-CLOCS tiles, nudge after 7 days, local only); **service history as visits**; **Running costs** (৳/km, 12-month spend, 6-month chart); **Papers** (tax token, insurance, fitness, registration, licence, reminders 30 days ahead); **settings card** (schedule, adapt, reminders, running costs, custom checks, sync odometer, reset log, **Export service record** PDF, km/mi).
  - A row opens **part detail** (`/home/maintenance/check`): status, projected date, interval source, adaptation, history, cost trend, actions.
  - **Odometer sync** is typed by the rider; the photo is only a reference.
- **Log a visit** (`/home/maintenance/add?bikeId=&serviceType=&visitId=`): one entry per trip to the mechanic. Due items are pre-ticked; bundles for oil change, servicing, chain care, brakes and the next **Free service #n**; custom job; oil brand and grade; odometer; one bill; shop with remembered shops; notes; receipt photo (local only). Saving shows Undo; `visitId` edits a visit.
- **Reminders** (`data/services/maintenance_alerts.dart`): a local notification once per item per status per service, after a ride, after a change, on cold start and resume; date-driven items and papers are scheduled for the day they enter their warning window (up to 12). Android channel "Maintenance". Fuel and unknown items never notify.
- **Order a low part** is a demo (cash on delivery), shown only to `BetaTesters.partOrdering`. Nothing is sent or charged.
- Data: `maintenance_logs` carry a `visit_id`; `bike_maintenance_configs`, `bike_maintenance_profiles`, `bike_paperwork`, `precheck_issues`, tombstones and `detection_odometer_credits` hold the rest. Settings backup (`MaintenanceSettingsSync`) carries configs, profile and paperwork.

## 6. Places (`features/poi_directory`): bottom nav tab "Places"

- **Hub** (`places_list_screen.dart`): **Places | Routes | Saved** switcher.
  - **Places:** live search (300 ms debounce), category ribbon with counts (Fuel / Garage / Parts / Recreation / All), filter sheet (radius 5-50 km remembered, sort, verified only, rider tags), **Map / List** toggle and a full-screen map mode. The map has category pins, grid clustering, radius ring and a card carousel.
  - **Cards:** distance, Verified badge, rider ratings, **Rider Approved** (≥ 4.5 from ≥ 5 ThrottleIQ riders), up to three tags, one-tap Directions / Call / Save. No Google ratings are stored or shown any more (§105); unrated places say "No ratings yet".
  - **AI cameras and police checkposts** are not shown in the Places hub. The Highway Radar warning banner and its red map pins were removed on 2026-10-25 because riders had to dismiss them every time. Riders can still report a cop checkpoint from the ride ⋮ menu. Temporary cop checkpoints show "Reported 2:14 PM · expires in 23 h" and drop out after expiry.
  - **Saved:** local SQLite bookmarks (works offline, wiped on account deletion) and the way into **Places I added**.
  - **OpenStreetMap import** ("Scan OpenStreetMap", capped at 25 km). Location and network errors are typed (GPS off, denied, denied forever, offline).
- **During a ride** (`live_ride_places_provider.dart`, 2026-10-22): places within 10 km on the ride map, refreshed every 5 km from an on-device cache (`data/ride_places_cache.dart`). It pulls only places with `updatedAt` after the last pull and re-reads a whole geohash cell every 3 days; cached places show at once and offline (issues_fixed §104.1).
- **Offline places cache** (2026-10-25, not released): the Places tab reads from the same cache (`placesCacheProvider`), so an area the rider has ridden through or opened loads from the phone and still shows offline. A fresh coarse cell counts for the finer cells inside it. **Settings → Offline places → Clear** empties it. Known limit: a rating change does not touch `updatedAt`, so list cards can show a rating up to 3 days old (place detail is live).
- **Place detail:** address, phone, hours, rating, reviews, photo, **Directions** and **Call**. Directions hands off to the rider's maps app by coordinates (`domain/place_directions.dart`) and also starts a ride first, silently skipping it when it cannot (no bike, no permission, ride active).
- **Add place:** optional photo (Cloudinary), optional informal address with reverse-geocode autofill from the pin, a required map location, rider tags (24/7, octane 95, digital payment, EFI diagnostics, puncture repair, paddock stand, genuine parts, bike parking, restrooms; max 12). **My places** (`/places/mine`) lists the rider's own.
- **Data:** Dhaka is seeded in production. 395 OSM places (2026-08-12, `createdBy: 'system:osm-seed-dhaka'`) plus 717 Google Maps gap-fill places (2026-10-19, `system:gmaps-seed-dhaka`), 1,238 `places` docs in all, all `verified: true`. OSM covers chain stations well and small independent garages and parts counters poorly. Seed and import scripts live in `scripts/oneoff/` (`scripts/README.md`). The Google import is not checked on a device. Open: §104.1 (nearby refetch cost), §105.

## 6a. Routes (`features/routes`): the Routes tab of the Places hub (also `/routes`)

- **Routes list** (`/routes`): "My routes" and "Discover" (public routes from any rider); thumbnail, distance, "Ridden N×", private/public badge. A finished ride that followed one of the rider's own routes bumps its count (best effort; not queued).
- **Save as route** (`/routes/save/:rideId`): name, description, private/public; the track is rebuilt from the ride's points. **Route detail** (`/routes/:routeId`, `?owner=<uid>` opens another rider's public route read-only): map, stats, toggle, delete, turn list, "Start navigation".
- **Following a route records the ride.** `/routes/:routeId/navigate` is a pre-flight (name, length, manoeuvres, first instruction, "Start ride & guide me"); it starts or attaches to a real recording at `/ride/active`. Guidance is drawn over the cockpit by `NavigationBanner`: next manoeuvre and distance, distance remaining, ETA, an off-route warning past 100 m, and a close button that drops guidance while recording continues. The ride stores `route_id` / `route_name` (schema v17). Navigating without recording is not possible.
- Guidance is geometric (`turn_instruction.dart`): no routing engine, no street names, no lane guidance, no rerouting. `test/features/routes/gpx_replay.dart` replays any GPX through the session. **Not checked on a device**: nobody has ridden a route with this (`issues_open.md` §78.21).

## 7. Social (`features/social`, `features/forums`, `features/chat`, `features/moderation`): bottom nav tab "Social"

- **Tabs: Rides / People / Forums.** The AppBar search icon opens a combined rider and forum search (rider name or email; forums matched over a bounded most-followed page).
- **Rides (feed):** shared rides with route map plus up to 3 photos in one collage (`ride_media_collage.dart`), caption, tier-coloured riding-score badge (hidden on rides shared before scores existed), vote, comments. Cards show `@username` and bike name. Sort chips **Hot / Recent / Following** (Following queries the people you follow); the feed pages as you scroll. Following someone updates the feed at once.
  - **Own shared ride:** ⋮ **Edit ride** (caption and photos), **Delete ride** (the post only), **See more**. Other riders' posts: **Report ride**.
  - **"RIDING NOW" strip:** the rider's own active group rides (`watchActiveGroupRidesForUser`); hidden when there are none. Rides idle for 4 hours drop out.
- **People:** rider search, the **Following** list, and "All people" with "Load more". There is no Discover or "followed rider is live" section: that would need a new public live signal, which is a privacy decision (`liveSessions` stay token-keyed and non-enumerable). Blocking a rider also removes follows in both directions.
- **Follow QR:** *My QR code* (`/profile/qr`, link `https://www.blankframe.tech/ThrottleIQ/u/<uid>`) and *Scan QR* (`/profile/scan`) follow a rider and open People. System-camera scans open the app by App Link / Universal Link / `throttleiq://u/<uid>`; pending follows survive sign-in. Web fallback: `public/follow.html`.
- **Ride share** (`/ride/share/:rideId`): caption, up to 3 photos, audience (Everyone / "Anyone who follows you" / ...), a "How it will look" preview, Save as route. **My shared rides** (`/rides/mine`) deletes shared rides. Hidden-start radius uses a private per-rider seed. A shared ride's bike fields are a snapshot, patched when the rider corrects the bike.
- **Forums "Pit Wall"** (`forums_home_screen.dart`): a **Pulse | Hubs** toggle.
  - **Pulse:** recent posts across garage and followed forums (at most 8 forums × 10 posts a page; filters All / My bikes / Help & fixes / DIY guides / Most voted are client-side; **Saved** is local bookmarks).
  - **Hubs:** "Your garage" cards (one forum per bike, model level only; **Ask owners**, **Browse board**), brand paddocks (counts sum the brand and its model forums), topic boards, rider clubs. A brand forum also shows its model forums' posts tagged "from <model>". Yamaha FZ-S generations share `yamaha__fzs`.
  - **New post** (`/forums/new`, `new_forum_post_screen.dart`, 2026-10-25, not released): opens straight on title, "What's going on", photos, bike byline and type. **Share** then picks groups: **All Riders** (the master group, `kAllRidersForumId`) always, plus up to 5 of the rider's garage/followed forums and topic boards (`kForumPostMaxGroups`). The first pick is the post's home (its count and moderators); the rest go in the post's `alsoIn` and those feeds pick it up through a `collectionGroup('posts')` query. Picking nothing posts to All Riders. The All Riders feed is every post in every group (Hubs → All Riders). Needs the new `posts` indexes and rules deployed. Known limit: a forum's maintainers moderate only posts whose home is their forum; cross-posted copies are not counted in a group's `postCount`.
  - **Posts:** types `troubleshoot` / `diyGuide` / `gearReview` / `general`, up to 4 photos (`kForumPostMaxImages`, Cloudinary `forumPhotos/<uid>/`), byline bike badge, optional attachment card (**Share to forum** from a ride summary or a maintenance visit). The author of a troubleshoot post can mark it solved and pin the accepted reply. Author names open the profile. Posts page 25 at a time.
  - **Rider-created forums** (`/forums/create`): the creator is a maintainer and can appoint others by UID (beta shortcut). Maintainers and the creator delete posts and replies; riders delete their own; the global admin (`the.abraar.rar@gmail.com`) can moderate anywhere (enforced in `firestore.rules`).
- **Chats** (`/chats`, `/chats/:chatId`): 1:1 messages (newest 50, "Load older messages"). The list hides blocked riders, a blocked chat shows a banner instead of the input, a failed send restores the text with Retry. The "typing…" line is inert (RTDB retired).
- **Reporting and blocking** (`features/moderation`): report a ride, chat message, forum post or rider from a scrolling sheet; the report keeps the document path and a protected copy of the content for 90 days. Tapping the chat header opens the rider's profile (Report, Block). Blocked-users list in Settings. Policy: human review within 24 h, written rules at `public/community.html`, runbook in `DOCS/General/Files for Stores/moderation_policy.md`.
- **Notifications** (`/notifications`; bell on the Garage header): follows, group-ride invites and "X joined your ride". All in-app; there is **no push**.
- **User profile** (`/profile/:uid`): public view with the rider's bikes (visibility enforced in `firestore.rules`, `bikesVisibleTo`). Errors tell private, offline and other apart. Follow buttons share one widget (spinner, error, no duplicate notifications).
- Not checked on a device: the compact shared-ride card and owner actions, the collage, the People tab.

## 7b. Ride with friends / group rides (`features/social`)

- **Solo / Group selector** on Record. Group: **Invite friends** (pick 1-10 riders by username) or **Join with a code**.
- Creating a group ride generates a 6-character join code (no `0/O/1/I/L`), sends in-app invites, and starts the creator's recording at once. Accepting an invite from Notifications opens the map. When the creator stops recording the ride ends; others leave theirs.
- **Join by code:** a valid code joins an **active**, not-full ride with no approval. A rider the creator removed cannot rejoin. The code is shown (large, **Copy**, **Share**) from the map's share icon while the ride is active.
- **Live map** (`/group-ride/:groupRideId`): one colour per member (uid-sorted), own marker ringed, roster Riding / Invited, "live" or "last seen". Positions are sent every 20 s, or sooner after 25 m, and at least every 2 min; a member is stale after 160 s. Positions use Firestore `memberLocations` only. A "Ride stats" button goes back to the ride.
- **Push-to-talk voice notes:** hold the mic bar, release to send; clips play for members on the screen, skipping anything from before they opened it. Foreground only, no push; Cloudinary upload, `groupRides/{id}/voiceNotes/{noteId}` create/read only; clips under 800 ms are dropped. **Not verified with a real Bluetooth headset or helmet intercom.**
- The roster is `groupRides/{id}/members/{uid}`; older rides keep a legacy inline array and reads merge both.
- Invites and "joined" notifications are in-app only (no push, since Cloud Functions are not available on Spark). Assumption `#17` in `DOCS/For Devs and Contributors/architecture/assumptions.md`.

## 7a. Home-screen widgets (`core/services/home_widget_service.dart`)

Five Android widgets and an iOS WidgetKit extension (`app/ios/ThrottleIQWidget/`), themed to the app (`ti_theme_*` colours; Carbon Mono fallback):

| Widget | Shows |
|---|---|
| Start ride | Opens Record (hold-to-start still required) |
| Start Auto-Tracking | Opens Settings, where the switch lives |
| Ride stats | Distance this week, total distance, ride count |
| Next service | Active bike, most urgent due service, km until due; red when overdue |
| Apex Hunter | Cornering telemetry (max lean, peak g) |

- Data republishes on app start, after a ride is finalised and after a service log. Labels follow the device locale, not the in-app language.
- iOS: the extension and App Group were confirmed on a physical iPhone on 2026-08-17. The iOS widget code was not re-checked after the theme sync was added.

## 8. Profile & settings (`features/profile`)

- **Settings** (`/settings`): profile summary, Appearance (System / Dark / Light), Language (System / English / বাংলা), Your ThrottleIQ (modules), Auto-tracking and Active hours, **Emergency Contacts**, **SafeQR**, **Offline places** (clear the places cache), Privacy & Safety, feature tour, Blocked users, Sync issues, Sign out, Delete account.
  - **Emergency contacts are never contacted.** The list and a warning banner exist; the screen and a one-time acknowledgement say alerts are not sent automatically. `functions/src/crash-notifications.ts` is a mock that only logs, and Cloud Functions cannot deploy without the Blaze plan.
  - **SafeQR** (`/safe-qr`): a medical-info QR (blood group, allergies, conditions, medications, first emergency contact), plain text so any camera reads it, device-local per uid (a new phone starts blank). Save or share the QR image, or **print a sticker sheet** (six 50 mm stickers, English or Bangla). Not scanned off real paper.
  - **Privacy & Safety:** "Password link (/r/@handle)" (off by default; asks for a password, "Change password" when on); "Share anonymous usage statistics" (on by default, off in debug; screen views and seven funnel steps, no location, rides, messages or names); "Help improve crash detection" (off by default, see below).
  - **Sync issues** appears only when outbox writes failed for good.
  - **Delete account:** sign-in and phone data go at once; cloud data is deleted by hand within 30 days of an email to hello@blankframe.tech (no deletion function on Spark). Photos and voice notes are removed from Cloudinary once credentials are configured, names are stripped from forum posts, replies, comments and reviews, and the rider's side of chats is anonymised. Runbook: `DOCS/For Devs and Contributors/guides/account_deletion_runbook.md`.
- **Profile** (`/profile`): read-only view of your own profile (avatar, name, @username, nickname, bio, join date, garage), with **Edit** (`/profile/edit`): fields, audience (Everyone / Mutuals / Only me), "Who can see my bikes" (Everyone / My followers / Only me), My QR code, Scan QR.
- **App mark:** a dark-only monoline crest on splash and sign-in; the OS launcher icon is the "Speed Gauge" mark.
- Fonts: Noto Sans Bengali is bundled and appended to every text style, so Bangla renders offline.
- To add a string: add the key to both `app/lib/l10n/app_en.arb` and `app_bn.arb`, run `flutter gen-l10n`, and commit the regenerated `app_localizations*.dart`.

## Shadow-mode crash detection (2026-10-15, not checked on a device)

Built after the first real field crash (2026-10-14, a walking-pace fall at a rail crossing the app never saw). The live alarm is **off** (`SensorConstants.crashAlertsEnabled = false`): the crash overlay, its notification and any message to contacts never show, and nothing is sent to anyone. Everything below only records and asks.

- **Detector** (`impact_detector.dart`), three tiers: 0 an impact (logged), 1 a possible fall (asked after the ride), 2 a likely crash (the only tier that may alarm, behind the flag). Impacts open at 2.5 g, on a clipped run, or when a ≥ 100 ms free fall ends. Tier 2 needs ≥ 15 km/h before, ≥ 4 g or clipping, and 10 s of stillness or held rotation. A tip-over from a standstill is its own tier-1 rule. Speed before impact is read 10 s back; 5 s of GPS silence counts as stopped.
- **Sensors:** 50 Hz on all three IMU streams; the raw accelerometer is on whenever shadow mode is.
- **Saved:** `impact_events` (schema v29) with a 12 s, 9-channel gzip sensor window (`impact_window_recorder.dart`). Caps: 20 events and 5 windows per ride. Rides gain `phone_placement` and `imu_rate_hz`; rows go with their ride in every delete path.
- **After the ride:** a "Possible fall at 9:28 PM, did you fall?" card on the summary (yes / phone fell / bump / braked hard / not sure; "yes" asks injury and road surface), plus **Report a crash or fall** for falls the detector missed, so recall can be measured.
- **Cloud:** `users/{uid}/impactEvents/{id}` (private). With the opt-in **Help improve crash detection** (`CrashResearchConsent`), answered events also go to `crashEvents/{id}`, de-identified (geohash-6, no position, no free text, never client-readable).
- **Scripts:** `scripts/crash_stats.js` (detected crashes, missed falls, recall, false questions) and `scripts/export_impact_events.js` (CSV plus windows for calibration, riders as salted hashes).

## Firestore quota outage mode (2026-10-21, merged to `main` 2026-10-22 as `c751968e`, not checked on a device)

- **What riders see:** when the Spark daily Firestore quota runs out, a strip above the bottom nav (`OverQuotaBar`, EN + BN) says the database is overloaded and their data is safe on the phone. `resource-exhausted` errors say the same. A comment or forum reply that fails to send stays in the text field.
- **What the app does:** `SyncManager` asks Firestore with one `count()` (1 read) at most every 15 min. On `resource-exhausted`, sync and the outbox pause (`FirestoreQuota`), so no queued entry burns its 20 attempts and no duplicates pile up. The first answer after the reset resumes everything. Rides, tracks, bikes, maintenance and fuel stay in SQLite and upload then.
- **Owner alert:** a Cloud Monitoring email at 80% of daily reads, writes or deletes, and again when reads or writes are used up (99%), live on `throttleiqfb` since 2026-10-21 (`scripts/monitoring/firestore-quota-alert.yaml`, steps in `scripts/README.md`).
- **Rehearsed** on a throwaway Spark project (`DOCS/Handoff for agents and Todos/load_test/quota-rehearsal-2026-10-21.md`): once reads run out, only transactions and `count()` fail; gets and listeners keep working, and nothing is lost. Details and limits: `issues_open.md` §104.6.

## Known gaps

- No screen shows the per-point `VehicleState` confidence, heading and cornering data the recorder captures (see `HANDOFF_Document.md`).
- Not built: documents wallet, curated "best roads nearby", push notifications of any kind, SMS or email alerts to emergency contacts, street-name turn-by-turn.
- Not checked on a device (they passed `scripts/check.sh` only): offline end and share, ride restore after a kill, route following, auto-tracking and its daily summary, the maintenance redesign, the feature tour, push-to-talk with a headset, crash shadow mode, quota outage mode, the Google Maps place import.
- Bangla review is pending for every machine-drafted string, including `overQuotaBar` and `errTooManyRequests`.
