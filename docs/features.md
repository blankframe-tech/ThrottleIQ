# Features

_Last updated: 2026-08-11 · Branch: `main` · Source: `app/lib/features/**` + `app/lib/core/router/app_router.dart`_

What a signed-in user can actually do in the app today, organized by the
five-tab bottom nav. This is a living document — regenerate/update it
whenever screens, routes, or user-facing flows change (see the doc-update
hook in `.claude/settings.json`).

> 📸 **Screenshots: TODO.** This pass was done by reading the screen source
> (`app/lib/features/*/presentation/screens/*.dart`) and the router, not by
> driving the iOS Simulator. The app *was* built and booted on the simulator
> on 2026-08-11 (clean, no Dart exceptions), but it stops at the sign-in
> screen — reaching any screen documented below needs real credentials, and
> no sign-in or tap automation is available here. **So nothing in this file
> from 2026-08-11 has been seen rendered**, including the redesigned Record
> screen and the Retro skin. Capture screenshots per section below next time
> the app is run signed-in on a simulator/device.

---

## UI hierarchy

```
Splash → (auth redirect) → Login / Register → Onboarding (first sign-in only)
                                                    │
                                                    ▼
                        ┌───────────────────────────────────────────────┐
                        │              Bottom nav (AppShell)             │
                        │  Social · Rides · ●Record· Places · Garage     │
                        └───────────────────────────────────────────────┘
Social  → Feed tab | Forums tab → forum thread → post detail
                                → create forum
Rides   → stats/journey (rank, badges, chart, recent rides)
Record  → active ride (live) → crash overlay (conditional) → ride summary
                             → ride share → save as route
Record  → ride with friends → friend picker → group ride live map
Places  → place detail | add place | (header) my places, routes
Routes  → route detail → turn-by-turn navigation
Garage  → bike detail → edit bike | add bike | (header) profile,
           my places, my shared rides → maintenance → add service log

Full-screen (no bottom nav): Settings, Notifications, Profile,
Edit Profile, User Profile (:uid), Ride Summary, Ride Share,
Forum Thread/Post, Create Forum, Routes list/detail/navigate,
Save Route, Group Ride map
```

---

## 1. Auth & onboarding (`features/auth`)

- **Splash screen** — routes to login or home based on auth state.
- **Login** — email/password sign-in, "Continue with Google".
- **Register** — create an account.
- **Onboarding** — shown once after first sign-in (until `displayName` is set), before the user reaches the main shell.

## 2. Record a ride (`features/ride`)

- **Record screen** (center tab, default screen) — **redesigned 2026-08-11** as one instrument panel, top to bottom: **bike-photo hero (greeting overlaid) → stat strip → ride with friends**, with **slide-to-start pinned to the bottom** and the quote as a footer line under it. Notifications bell and settings shortcut sit above. Shows an "Add a bike" card in the hero's place when no bike is selected.
  - **Why it changed**: the previous stack (2026-08-04) was four cards of roughly equal weight in a scroll view, which gave the greeting the same visual authority as the control that actually starts a ride.
  - **The throttle is outside the scroll view**, not the last item in it — slide-to-start is the one control the screen exists for, so it sits at a fixed place under the thumb every time, and doesn't move when an error card appears above it.
  - **Hero** (`bike_picker_card.dart`) — the rider's own bike photo, full-bleed at 210px, under a three-stop scrim (the photo is theirs, so it can be a bright daylight shot or a night one; text laid straight on it is legible on neither). The greeting sits on top: the casual line carries the rider's name when the picked variant has a `{name}` slot, otherwise it becomes a small overline above the name.
  - **Stat strip** (`rider_stat_strip.dart`) — rides / kilometres / **current day streak**, from `riderStatsProvider`. These are the rider-wide totals that moved to the Rides tab in 2026-08-04; the *history* rightly lives there, but these three are the reason to go out again, which is what this screen is for. Rendered as a flat strip, not cards, so they read as context for the hero rather than three things to tap. Zeros render while stats resolve — the layout is fixed-height either way and a spinner sliding into a row of numbers is more disruptive than a number that ticks up a moment later.
    - `computeCurrentDayStreak` (new, `core/utils/badges.dart`) is deliberately **not** `computeLongestDayStreak`: a dashboard number labelled "streak" has to be the live one. Yesterday still counts so the number doesn't collapse to zero every morning; two days off ends it.
  - **Casual, time-aware greeting** (`core/utils/greetings.dart`) — six buckets by hour (late night / early morning / morning / afternoon / evening / night), five variants each ("Late night runs, huh?", "Cold start, clear roads.", "Golden hour. Go."). Pure and unit-tested, with an injectable `Random`; rolled once per screen build so a provider tick doesn't reshuffle it.
  - **The quote is a footer** (2026-08-04 → moved again 2026-08-11) — it was its own ink-block card, then a muted line inside the greeting card, and is now a small centred line *under* the slide-to-start bar. It also took over the line the "Swipe right to start recording" hint used to own: the bar labels its own gesture, so the hint was saying it twice. Open question still standing in `HANDOFF_Document.md`: whether the quote belongs on this screen at all, vs. an intermediate "here we go" screen between tapping start and recording beginning.
  - **Rider-wide totals moved off this screen** (2026-08-04) — total km / ride count / days-since-last-ride used to live here as the *active bike's* figures; they're now on the Rides tab under "Your Journey", scoped to the whole rider rather than one bike.
  - **Bike picker shows the rider's own bike photo** (2026-08-04) when one was added in Garage, with a fallback to the generic icon tile — see `BikePhoto` in §4. The photo can be cropped when it's added — see §4.
  - **Bike switching happens in place** (2026-08-11) — it used to be a card whose whole surface navigated to `/home/garage` with a "Change" label, so switching bikes meant leaving the screen you were about to start a ride from, and the label named something the card didn't do. The hero now owns switching:
    - **Two or more bikes** → tapping the hero opens a **picker sheet** with every bike and a check on the active one; picking one calls `setActiveBike` without navigating. A "CHANGE ⌄" affordance sits on the hero. (A sheet rather than the previous dropdown because the hero is a photo, and a menu anchored to a 210px image either covers the thing you're choosing or floats off it.)
    - **One bike** → no switch affordance at all. A picker whose only option is the one already selected is a control that can't do anything.
    - Sheet rows show **ride count**, not "Ready to ride" — every row would say "Ready to ride", which distinguishes nothing; ride count is what separates two similarly-named bikes.
    - Garage is no longer reachable from this card at all. It's one tap away on the bottom nav, and that's where a rider adds the second bike that turns this into a picker.
    - `test/features/ride/bike_picker_card_test.dart` still guards the original regression (picking a bike must switch it, not push a `MaterialPageRoute`).
  - **Slide-to-start button is theme-aware** (2026-08-04) — it used to hard-code a near-black track, which was correct on Carbon Mono but was the one black control on the light Editorial palette. Now derives its colors from `Theme.of(context).brightness`.
- **Active ride screen** (`/ride/active`, full-screen) — live map + stats, pause/resume, end ride (with confirmation), **discard ride**, **share live location** (generates a `/live/{token}` link via SMS/share sheet, hosted at `throttleiqfb.web.app`), and a full-screen **crash-detected "Are you OK?" overlay** with a dismiss countdown.
  - **Discard ride** (added 2026-08-11, `Issues.md` §20) — `cancelRide()` throws the ride away: local row and all its `ride_points` deleted, live session marked finished and the `/r/{username}` pointer cleared, buffered points dropped rather than flushed. Nothing about a discarded ride ever leaves the device — a ride that never reached `status = 'completed'` is invisible to every query *and* to the sync layer. The confirm dialog names what is lost (distance and duration) rather than asking a generic "are you sure?". Deliberately a **text button below** the pause/end pair, not a third equal-weight control: end-and-save is what almost every ride wants, and a delete-my-data action shouldn't look the same size and shape as the one next to it that keeps everything.
  - **A ride survives the app being killed** (changed 2026-08-11, `Issues.md` §18 — and §19 for the share-link leak found alongside it) — quitting mid-ride (swiping out of recents, OS jetsam, an OEM battery manager) used to be terminal in a quiet way: `recoverCrashRide` closed the ride out on next launch and filed it in history, so a rider who stopped for fuel and swiped the app away came back to two half-rides and no way to continue the first. `restoreInterruptedRide` now brings it back **paused** instead, with its distance, top speed, moving time, route and ride clock intact, and the rider chooses: **resume**, **end and save**, or **discard**. A "Ride kept from last time" banner explains why they're looking at a paused ride they never paused.
    - Aggregates are rebuilt from the GPS fixes that reached disk (`ride_resume.dart`, unit-tested); **elapsed time** is the one thing not derivable from them (a ride that sat 40 minutes at a chai stall spans far more wall-clock than it recorded), so it is snapshotted to `SharedPreferences` every 10s, and forced on pause and on the app leaving the foreground.
    - **Event counts restart at 0** on a resumed ride — hard-brake / rapid-accel / high-jerk come from `EventDetector`'s live thresholds over a continuous sample stream, which thinned stored points can't honestly reproduce. Narrow and documented rather than guessed at.
    - The first fix after any resume **skips its distance/accel/jerk derivatives** (`_skipNextDistanceDelta`). Otherwise `MotionCalculator` measures straight across the gap: park the bike, pause, drive home in a van and resume, and the ride gains the whole van journey as one straight line. Now that a pause can span an app restart, that gap is unbounded and the guard stopped being optional.
    - A ride already finalized (crash detection closed it, or `stopRide` wrote the row but died before clearing prefs) is **not** offered back — it's in history, and resuming it would duplicate it.
  - The viewer page (`public/live-viewer.html`) carries an **install call-to-action**, added 2026-08-02 — it's the only page a non-user ever sees. It renders in both the live view and the expired-link state (a dead link is where it matters most). Store URLs live in one `APP_LINKS` block in that file and are null until the listings exist; until then it offers the GitHub beta APK. Set a store URL there and its button appears automatically.
  - **Permanent per-rider link** (added 2026-08-04): `/r/{username}` — same page, new route. Resolves to whatever live session the rider currently has going (via `usernames/{handle}` → `livePointers/{uid}` → `liveSessions/{token}`, all keyed lookups, never a query — see `Issues.md` §14), or shows a "not riding right now" panel that flips itself live the moment they start. A rider shares this link once instead of a fresh `/live/{token}` link every ride. **Requires `firestore.rules` and `firebase.json` to both be deployed** — see the "Now" checklist in `HANDOFF_Document.md`.
- **Ride summary screen** (`/ride/summary/:rideId`) — post-ride score (out of 100), map/route, **Share** (posts to the social feed), **Export JSON**, **Export GPX**, "Save & done".
  - **Time in jam** (added 2026-08-12) — a second stat card, **moving** vs **in jam** (amber when > 0), under the existing distance/duration/avg/max row. This was the "surface the jam time back to the rider" idea from the proposed-features list below — the data (`movingSeconds`) was already being collected for the average-speed fix, so this is presentation plus one new persisted column, not new tracking. `jamSeconds()` (`domain/calculators/jam_time.dart`, unit-tested) is just the ride clock minus moving time, clamped to zero — deliberately not a second GPS-derived measurement, so it can never disagree with the moving-time average speed computed from the same data. `rides.moving_s` is a new nullable column (schema v9); older rides finalized before it existed show no jam card at all rather than a guessed zero — `RideEntity.jamSeconds` returns `null`, not `0`, when either input is missing. Also fixed a pre-existing mislabel in the first stat row: the duration cell said "moving" while actually showing total elapsed time; it now says "duration".

## 3. Rides / stats (`features/stats`) — bottom nav tab "Rides"

- **"Your Journey"** header, followed directly by the rider-wide **total km / rides / days since last ride** chips (moved here from the Record screen 2026-08-04 — these are the rider's totals across every bike, not one bike's).
- Rank/level card (New Rider → Weekend Rider → Steady Cruiser → Road Regular → Seasoned Rider → Veteran → Road Master, 500 km per level).
- **Distance and average-speed line charts** — each now marks the **peak point with a dot** and labels the peak's **value on the y-axis**, plus the **first/last ride's date on the x-axis** (`RideLineChart`, changed 2026-08-04). Deliberately not a full axis ladder — a 20-point sparkline only needs "how big did it get" and "over what span."
- **Badges**, moved below the charts (2026-08-04) — the trend changes every ride and badges move rarely, so burying the trend under a wall of icons made the rarely-changing thing the loudest. Now rendered as `BadgeGrid`: one tile per badge **family** (bronze/silver/gold/platinum/diamond-style tiers grouped under one icon), colored + the family icon when at least one tier is earned, gray otherwise. Tapping any tile opens a ladder sheet listing every tier with its own earned/locked state — earned rungs say what they mean, locked ones say what to do and how far off the rider is. See `HANDOFF_Document.md` for the open question on the "complete every badge → engine oil" reward, which has no claim flow built yet.
- **Sortable rides list** (added 2026-08-03): chips for **Recent / Top speed / Distance / Duration / Best score**. The trailing figure on each row follows the active sort, so the list explains its own order.
  - Ranking reads the **full** ride history and truncates afterwards — `recentRides` is capped at 10, so sorting *that* by top speed would show the fastest of your last ten while calling it your fastest. `RiderStatsSummary.allRides` exists for this.
  - Ties break by recency (repeated commutes and 0.0 km test rides tie constantly; without it the list reshuffles between rebuilds). Missing values sort **last** — a ride with no recorded duration is a data gap, not the longest ride.
  - The sort is **not persisted**: it's a momentary question, not a preference.
- **"All rides" button** (added 2026-08-04) — the compact list only ever shows 10; this opens `/rides/all` on top of the current screen. Same sort chips, lazy infinite scroll over the full history (not paged navigation — the data's already in memory, only rendering needs bounding), full per-ride detail (distance/duration/avg/top/score/events), and the ride's **route thumbnail** where one was recorded.
- Empty state for zero-ride accounts.

## 4. Garage (`features/garage`) — bottom nav tab "Garage"

- **Garage screen** — bike list; header menu → **Profile**, **My Places**, **My Shared Rides**; empty state with "Add Bike" CTA.
  - **Bike photos now render** on both the garage list and bike detail (fixed 2026-08-04, `Issues.md`) — a photo added via Edit Bike previously only ever saved to the entity; every screen that should have shown it (garage card, bike detail, record screen) still drew the generic icon tile. All three now go through a shared `BikePhoto` widget, which also falls back to the icon when the saved path points at a file that no longer exists — the normal case for a bike synced down from another device, since image paths are local and don't travel with sync.
- **Add/Edit Bike screen** (`/home/garage/add`, `/home/garage/:bikeId/edit`).
  - **Photos can be cropped** (added 2026-08-11). Picking a photo goes straight into an in-app cropper; once one is attached, **Crop** and **Replace** buttons sit under the preview, so re-framing a photo doesn't mean finding it in the library again.
    - **The crop is offered, not forced** — cancelling out of the cropper keeps the photo as picked rather than discarding the whole selection. "Right photo, no crop needed" is the common case, and re-picking would be a punishment for tapping Cancel.
    - **Built in-app, not `image_cropper`.** That plugin's screen is native chrome (UCrop / TOCropViewController), which would be the one screen in the app that ignores the skin the rider chose — wrong on eight of the nine — and it wants an Android manifest entry and a pod. This uses `package:image`, already a dependency for `ImageCompressionUtils`.
    - **Interaction: the photo is fixed, the frame moves.** The Instagram model (fixed frame, pan/zoom photo) makes an unconstrained "Free" crop awkward to express. Here the photo is letterboxed to fit and the frame is dragged and resized over it, which makes Free the default and turns the aspect presets — **Free / 1:1 / 4:3 / 16:9**, plus rotate — into a constraint on the frame rather than a separate mode. No zoom: for framing a bike it isn't needed, and it doubles the interaction surface.
    - **Free is the default deliberately.** One photo serves both a 44px square thumbnail and the 210px wide Record hero, so no single ratio is right for both; the display widgets keep using `BoxFit.cover` either way. The crop's job is to let the rider decide *what the subject is*, so both cover-crops centre on the bike rather than on whatever happened to be mid-frame.
    - **Where the code lives, and why it's split three ways:** the geometry is pure and unit-tested (`core/utils/crop_geometry.dart`, 29 tests — frame clamping, ratio anchoring, display→source mapping); the pixel pipeline is separate and independently tested (`core/utils/image_crop_io.dart`, 10 tests); the screen (`shared/screens/image_crop_screen.dart`) is only the gesture surface. **The split is not tidiness** — `flutter_test` runs widget code in a fake-async zone where real file reads and image decodes never complete, so a pipeline buried in a `State` method can only be exercised by hand. Pulled out, it takes an injectable output directory and is tested against four-colour quadrant fixtures that prove the *right region* was cut, not merely the right dimensions.
    - **EXIF orientation is baked in before measuring** (`img.bakeOrientation`). `ImagePicker` normally normalises it when re-encoding, but a crop applied to an image whose orientation tag hasn't been applied cuts the wrong region, sideways, with no error.
    - **Cropped photos are written to the app documents directory**, not left beside the `ImagePicker` original in a cache dir the OS may reclaim — which is the documented reason `BikePhoto` needs a fallback for a non-null-but-stale path at all. Only cropped photos get this; a photo kept as-picked still carries a cache path.
    - `ImageCropScreen.open(context, sourcePath:)` is generic and returns a path or null, so the other three pickers (profile avatar, place photo, ride photos) are one call away from the same treatment — **not wired up**, since only bike photos were asked for.
- **Bike detail screen** (`/home/garage/:bikeId`) — bike info, delete (with confirmation), **"Discuss this bike"** deep link into the matching forum thread. Deleting a bike removes its rides, their GPS points and its maintenance logs; it silently deadlocked before 2026-08-01 (`Issues.md` §7).
  - **Delete is now actually durable** (fixed 2026-08-04, `Issues.md` §12) — it previously only removed the local row, so the bike reappeared on the next sync (still selectable on the Record screen, still in its forum). Deletes now write a local tombstone in the same transaction and remove the Firestore copy (and its rides) via `SyncManager`.

## 5. Maintenance (`features/maintenance`) — reached from Garage/bike detail

- **Maintenance screen** (`/home/maintenance?bikeId=`) — service log list per bike, reminders shown as "every N km", delete a log entry, empty state ("No active bike" / "No service logs yet").
- **Add service log screen** (`/home/maintenance/add`).
- **Service types** (expanded 2026-08-01): the original Oil Change / Air Filter / Chain Lube / Tire Check plus Radiator-Coolant, Front Disc Pads, Rear Drum Pads, Brake Fluid, Spark Plug, Battery, Valve Clearance, Clutch Cable and Suspension — and a **Custom** type that requires the rider to name the service ("What did you service?"), shown by that name in the log list.
- **Reminders** cover the original four plus brake fluid and front disc pads. The rest are log-only by design: a card per type would bury the ones that matter. See `_reminderTypes` in `maintenance_provider.dart`.

## 6. Places / POI directory (`features/poi_directory`) — bottom nav tab "Places"

- **Places list screen** — nearby places, "import nearby places" (Overpass-backed), "Add place" FAB, empty state; a labelled **Routes** row at the top of the list (see §6a).
- **Place detail screen** — address, phone, hours, star rating, **submit a review**, and a photo when one was added.
- **Add place screen** — a photo is now **optional** (added 2026-08-04, Cloudinary-backed like ride photos; a failed upload doesn't cost the rest of the submission). Address is also optional, with **reverse-geocode autofill** from the dropped map pin (`NominatimService`, OpenStreetMap — an explicit rider action, never triggered by panning, per Nominatim's rate policy) and a helper note that the address is meant to be informal ("beside XYZ school," not a formal street address).
- **My places screen** (`/places/mine`, reached from Garage header menu) — places the current user added.
- **Categories**: Fuel, Garage, Parts, and **Recreation** (added 2026-08-01 — biker cafes, restaurants and viewpoints; the Overpass import pulls `amenity=cafe`, `amenity=restaurant` and `tourism=viewpoint` for it).

## 6a. Routes (`features/routes`) — reached from the labelled row at the top of Places

Added 2026-08-01. Built on the route data layer that had existed with no UI.

- **Routes list** (`/routes`) — "My routes" and "Discover" (public routes from any rider) tabs; cards show a map thumbnail, distance, times-ridden and a private/public badge.
- **Save as route** (`/routes/save/:rideId`) — reached from the end-of-ride share screen. Name + description, private/public switch; the track is re-derived from `RidePointDao`.
- **Route detail** (`/routes/:routeId`) — full map, stats, public/private toggle, delete, the derived turn list, and "Start navigation".
- **Turn-by-turn navigation** (`/routes/:routeId/navigate`) — live follow-the-line guidance: instruction banner with distance to the next turn, off-route warning past 100 m, distance remaining, speed-based ETA, wakelock held while navigating.
  - **Offline and geometric.** Turns are derived from the route's own recorded polyline (`turn_instruction.dart`) — no routing engine, no API key, no recurring cost. The trade-off: no street names, no lane guidance, and it does **not** reroute — it tells the rider they're off route rather than inventing a new path. Street names would need map matching (Phase 3 in `HANDOFF_Document.md`).

## 7. Social (`features/social`, `features/forums`) — bottom nav tab "Social"

- **Header search** (added 2026-08-04) — one box, riders and forums both, replacing the old standalone "Find riders" tile. A rider name or an email is routed to `searchByUsername`/`searchByEmail`; forums are matched in-memory over a bounded, most-followed page (`ForumRepository.searchForums`) since Firestore has no substring match. Debounced 250 ms so it isn't a query per keystroke.
- **Feed tab** — shared rides with score, comment count, inline comments; empty state pointing users to share a ride from its summary screen.
  - **Sort/filter chips** (added 2026-08-04, `FeedSort`) sit where "Find riders" used to: **Hot** (net upvotes, ties break by recency), **Recent** (default), **Following** (only riders you follow — an empty following list shows an empty feed on purpose, rather than silently ignoring the chip).
  - Each card renders the ride's **route map** (Strava-style). With photos, photos and map sit side by side; without any, the map spans the card.
  - **Up to 3 photos per ride** (added 2026-08-04, `kMaxRidePhotos`) — rendered as a swipeable strip with a "2/3" counter and page dots once there's more than one; a single photo behaves exactly as before (no swipe, no counter).
  - Rides carry an optional **caption**, written on the share screen.
- **Forums tab** (`forums_home_screen.dart`) — "Your bikes" forums, **Rider forums**, then **Find a forum** (search + Brands + Topics) → **forum thread screen** → **new post** (bottom sheet) → **post detail screen**.
  - **"Your bikes" is model-level only** (changed 2026-08-11) — one forum per bike you own (Yamaha RXS 1154), and **not** the brand forum above it. It used to add both: owning one bike enrolled you in every thread about every Yamaha ever made, which buried the forum you actually cared about under a much noisier one you never asked for. Brand forums still exist and are still followable — they're opt-in via discovery now rather than assigned by ownership. A bike with no model recorded contributes nothing (its only slug *is* the brand forum). Guarded by `test/features/forums/garage_forums_test.dart`.
  - **Topics moved under "Find a forum"** (2026-08-11) — Brands and Topics are the same act (finding a forum you don't own your way into), so they're two labelled groups in one discovery block rather than Topics being a top-level section of its own.
  - The "Your bikes" list is cached in `SharedPreferences` keyed by a garage signature, so it no longer re-runs a Firestore transaction per bike on every visit. Dropping the brand slugs changes that signature, so existing installs re-resolve once and then serve the shorter list from cache.
  - **Rider-created forums** (`/forums/create`): the creator becomes a maintainer and can appoint others (by UID — a beta shortcut). Maintainers and the creator can delete posts/replies; riders can always delete their own. The global admin (`the.abraar.rar@gmail.com`) can moderate anywhere. Enforced in `firestore.rules`, not just client-side.
  - Topics now include Engine Rebuild, Mileage Tips and Engine Oil Review.
  - Deleting a bike from Garage no longer leaves it choosable from Record or its forum reachable — see `Issues.md` §12; both were symptoms of the same delete-never-reached-the-cloud bug.
- **Ride share screen** (`/ride/share/:rideId`) — caption, **up to 3 photos** (was 1, changed 2026-08-04), audience, and **Save as route**.
- **My shared rides screen** (`/rides/mine`, reached from Garage header menu) — delete a shared ride.
- **Notifications screen** (`/notifications`).
- **User profile screen** (`/profile/:uid`) — public profile view, showing a rider's bikes.

## 7b. Ride with friends / group rides (`features/social`)

Added 2026-08-01, on the group-ride data layer that had existed with no UI.

- **"Ride with friends"** button on the Record screen, under the bike picker.
- **Friend picker** — search riders by username, pick **1 to 10** (changed from 2-10 on 2026-08-04 — riding with a single friend is the commonest case, and forcing a third invitee to unlock the feature was pure friction; bounds enforced by a pure `validateGroupSelection`; live "n/10" counter, self excluded, duplicates collapsed, an 11th refused).
- On confirm: the group ride is created, invites go out, each invitee gets an **in-app notification**, and **the inviter's ride starts recording immediately** via the normal recording path.
- **Accepting** — a group-ride invite in the notifications screen is tappable; tapping accepts and opens the shared map.
- **Shared live map** (`/group-ride/:groupRideId`) — every member is a **different colour**, assigned from a uid-sorted index so a rider keeps the same colour across rebuilds. Own marker is ringed. Roster splits "Riding" from "Invited"; each member shows "live" or "last seen 42s ago", and markers older than 30 s wash out rather than silently reading as current. Positions broadcast every 5 s. Members who've never reported a position are listed but never drawn at (0,0).
- ⚠️ **Invites are in-app only — there is no push notification.** The invitee sees it next time they open the app. Real push needs the Cloud Function this repo documents as a stub. See `Assumptions Made.md` #17.
- The roster lives at `groupRides/{id}/members/{uid}` — one document per rider, not an array on the ride (changed 2026-08-02, see `Issues.md` §10). Rides created before that keep a legacy inline array; reads merge both, the subcollection winning.

## 7a. Home-screen widgets (`core/services/home_widget_service.dart`)

Added 2026-08-01. Three widgets, styled Carbon Mono (carbon background, lime accent, monospace, sharp corners):

| Widget | Size | Shows |
|---|---|---|
| **Start ride** | 2×1 | A button that opens the app on the Record screen |
| **Ride stats** | 4×2 | Distance this week, total distance, ride count |
| **Next service** | 4×1 | Active bike, the most urgent due service, km until due; flips lime → red when overdue |

- **Android is fully working** — no manual step.
- **iOS ships as sources plus a numbered Xcode README** (`app/ios/ThrottleIQWidget/README.md`). The extension target must be added once through the Xcode GUI; **the iOS widgets do not exist until someone does that.** The one step people miss is adding the App Group capability to *both* the Runner and widget targets.
- Data republishes on app start, after a ride is finalized, and after a service log is added.
- The Start-ride widget **navigates to Record; it does not auto-start a recording.** A home-screen tap silently beginning a GPS recording would be surprising — the slide-to-start gesture keeps that deliberate.

## 8. Profile & settings (`features/profile`)

- **Settings screen** (`/settings`) — profile summary, **Appearance** (skin picker, see below), **Emergency Contacts** (add/delete; used by crash-detection escalation), **Sign Out**.
  - **Appearance → Skin** (changed 2026-08-11) — the two-way *Carbon Mono* / *Editorial* switch is now a **dropdown of nine skins**. Each row carries the skin's name, a one-line blurb, and a **swatch painted in that skin's own palette** (its background plus its primary and secondary accents) — with nine names and no preview the control would be a list of words. See `app/lib/features/profile/presentation/widgets/skin_dropdown.dart`.

    | Skin | Base | Accents |
    |---|---|---|
    | **Carbon Mono** *(default)* | carbon black | lime / magenta |
    | **Editorial** | cream paper | blue / orange |
    | **Nocturne** | deep indigo | lavender / teal |
    | **Trail Social** | dark slate | orange / blue |
    | **Calming** | warm cream | sage / clay |
    | **Positive Vibes** | white | green / teal |
    | **Retro** | paper white, ink rules | *(monochrome — no accent hue)* |
    | **Analyst Blue** | navy console | cyan / coral |
    | **Genesis** | near-black | gold / violet |

    The seven new skins come from the `ThrottleIQ Style Directions` deck (`landing-page/throttle-iq/new designs to be implemented later/`), whose colors are specified in oklch and were converted to sRGB. Where a direction named no value for a token the app needs — most define no `secondary`, none define shimmer or status colors — the value is **derived in the same oklch space** rather than borrowed from another skin.
    - Skins differ **only in palette**, with one documented exception (Retro, below). The shape system and IBM Plex typography are otherwise shared, so a skin is 22 color tokens and nothing else — the deck's per-direction typefaces (Playfair, Archivo Black, Space Mono…) were **not** adopted.
    - **Retro is the exception** (reworked 2026-08-11) — the deck's Rawblock direction rendered as an **old black-and-white terminal** rather than a mustard/rust poster. It is the one skin that changes shape and type as well as color:
      - **Strictly monochrome.** Paper white `#FAFAF7`, ink `#0A0A0A`, and a neutral grey ramp for everything between — no chroma in any of the 22 tokens. Since there is no red to spend on `danger`, **severity is encoded in value**: danger is pure ink (the loudest mark on paper), warning a dark grey, success a mid grey that recedes. That is a real trade — two states differing only in weight are harder to separate at a glance than red-vs-green — and it's the deliberate cost of the direction. Every status in the app pairs its color with an icon or a word, so nothing is carried by color alone. `app_theme_style_test.dart` asserts the neutrality and the severity ordering.
      - **Square corners and a heavy rule.** `AppTheme.build` takes every radius to 0 and widens outlines to 2px for this skin only; `border` is full-strength ink rather than a hairline tint, because the black rule *is* the direction.
      - **Monospace throughout.** Body type drops to IBM Plex Mono, and `AppTypography` (new) swaps the display face the same way `AppColors` swaps the palette — both are applied together in `ThemeStyleNotifier._applyTokens`, so a skin can't end up half-applied with mono type left behind on the next one.
    - `AppColorPalette` now carries an **`isDark` flag**. Base brightness, the `ColorScheme` variant, the status-bar icon color and which app mark is shown all used to be inferred from `style == carbonMono`, which stopped being a valid proxy the moment there was a second dark skin.
    - `AppColorPalette.forStyle` and the label/description lookups are **exhaustive switches with no `default`** — adding a skin without a palette or a name is a compile error, not a skin that silently renders as Carbon Mono.
    - Persistence writes `AppThemeStyle.name`, still decodes the legacy `carbon`/`editorial` values, and still *writes* those two spellings for the original pair so a rollback to an older build keeps the setting. An unrecognised stored value falls back to Carbon Mono.
    - Adding a skin means: an enum member, a palette, `theme<Name>Label` + `theme<Name>Description` in **both** ARBs, and `flutter gen-l10n`. The compiler names the rest.
  - **Language** (added 2026-08-02, directly below Appearance): System default / English / বাংলা, persisted like the theme. As of 2026-08-11 only the **settings screen itself** was translated, to prove the pipeline end to end. **2026-08-12:** the bottom nav, the Record screen's bike-picker hero + stat strip, and the full ride summary screen followed (34 more keys, real Bangla translations, `arb_parity_test.dart` still fully green — no partial/placeholder strings). The rest of the app — most screens under `features/*` — is still hardcoded English; see `HANDOFF_Document.md`'s Product checklist for the per-screen remaining-string breakdown.
    - **Numerals stay Western (0-9) in Bangla**, deliberately — speed, distance and odometer are read at a glance through a visor, and BD speedometers, road signs and number plates all use 0-9. A test fails if a Bengali numeral ever appears in a Bangla string. See `core/i18n/numeric_locale.dart`.
    - ~~⚠️ Font caveat~~ **FIXED 2026-08-12** — IBM Plex/Space Grotesk have no Bengali glyphs, so Bangla used to fall back to whichever face the platform substituted. Noto Sans Bengali (OFL-licensed, variable font) is now bundled as a real pubspec font asset — not fetched via `google_fonts` at runtime — and appended as `AppTypography.bengaliFallback` to every text style the app hands out, so it renders correctly offline from first launch. See `HANDOFF_Document.md`.
    - To add a string: add the key to **both** `lib/l10n/app_en.arb` and `app_bn.arb`, run `flutter gen-l10n`, and **commit the regenerated `lib/l10n/app_localizations*.dart`** — it's generated-and-committed so a clean checkout analyzes without a codegen step.
  - The Appearance section shows a live **app-mark preview** that swaps with the theme. The mark itself is otherwise only used on the splash and sign-in screens, which a signed-in rider never sees — so without this the toggle looked like it wasn't changing the logo at all (`Issues.md` §8). There are still only **two** marks; a skin gets the dark or light one per its `isDark` flag.
- **Profile screen** (`/profile`) — added 2026-08-01. A **read-only** view of your own profile: avatar, display name, @username, nickname, bio, join date, and your garage. A single **Edit** action opens the form. Same screen as `/profile/:uid` with the uid omitted, so viewing yourself and viewing another rider can't drift apart. (The garage menu entry now reads **"Profile"**, not "Edit Profile".)
- **Edit profile screen** (`/profile/edit`) — profile fields + **audience/privacy picker** (Everyone / Mutuals / Only me) + **"Who can see my bikes"** (Everyone / My followers / Only me, added 2026-08-01). The theme switcher is deliberately **not** here — it lives in Settings only.
  - Bike visibility is enforced in `firestore.rules` (`bikesVisibleTo`), not just in the UI, and mirrors the pure `canSeeBikes()` predicate. Accounts with no setting default to **public** — note that this *widened* read access, since the subcollection was previously owner-only; see `Assumptions Made.md` #15.

---

## Known UI gaps (as of this pass)

- No dedicated screen shows `VehicleState` confidence/heading/cornering data captured per-point (Phase 1 of the vehicle-state engine persists it; nothing renders it yet — see `HANDOFF_Document.md`).
- Fuel log, documents wallet and curated "best roads nearby" from the competitor feature map in `HANDOFF_Document.md` Part 2 are not built. (Turn-by-turn navigation now IS — see §6a — though geometrically, not via a routing engine.)
- ~~Discovered (public) routes can't be opened~~ **FIXED 2026-08-02** — the detail and navigate routes take an optional `?owner=<uid>`, so a public route from another rider opens read-only (Delete and the public/private toggle are hidden; navigation works, since following a track writes nothing). Omitting `owner` still means "mine", so existing links are unchanged.
- iOS Simulator screenshots for every screen above are still outstanding — see the note at the top of this file.
- **None of the 2026-08-01 feature work below has been exercised on a device** — it is verified by `flutter analyze`, 363 passing tests, and a release build only. See "Done, but NOT yet verified" in `HANDOFF_Document.md`.
