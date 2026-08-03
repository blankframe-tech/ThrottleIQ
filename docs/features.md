# Features

_Last updated: 2026-08-01 · Branch: `main` · Source: `app/lib/features/**` + `app/lib/core/router/app_router.dart`_

What a signed-in user can actually do in the app today, organized by the
five-tab bottom nav. This is a living document — regenerate/update it
whenever screens, routes, or user-facing flows change (see the doc-update
hook in `.claude/settings.json`).

> 📸 **Screenshots: TODO.** This pass was done by reading the screen source
> (`app/lib/features/*/presentation/screens/*.dart`) and the router, not by
> driving the iOS Simulator — no simulator-automation tool was available in
> this session. Capture screenshots per section below next time the app is
> run on a simulator/device.

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

- **Record screen** (center tab, default screen) — reordered 2026-08-01, top to bottom: **greeting → quote → bike picker → ride with friends → stats → slide to start**. Notifications bell and settings shortcut sit above. Shows a warning + "Add Bike" CTA when no bike is selected.
  - **Casual, time-aware greeting** (`core/utils/greetings.dart`) — six buckets by hour (late night / early morning / morning / afternoon / evening / night), five variants each ("Late night runs, huh?", "Cold start, clear roads.", "Golden hour. Go."). Pure and unit-tested, with an injectable `Random`; rolled once per screen build so a provider tick doesn't reshuffle it.
  - **Quote** — compact single block (max 3 lines). The large speedometer image that used to sit above it was removed 2026-08-01; it dominated the screen and pushed everything useful below the fold.
- **Active ride screen** (`/ride/active`, full-screen) — live map + stats, pause/resume, end ride (with confirmation), **share live location** (generates a `/live/{token}` link via SMS/share sheet, hosted at `throttleiqfb.web.app`), and a full-screen **crash-detected "Are you OK?" overlay** with a dismiss countdown.
  - The viewer page (`public/live-viewer.html`) carries an **install call-to-action**, added 2026-08-02 — it's the only page a non-user ever sees. It renders in both the live view and the expired-link state (a dead link is where it matters most). Store URLs live in one `APP_LINKS` block in that file and are null until the listings exist; until then it offers the GitHub beta APK. Set a store URL there and its button appears automatically.
- **Ride summary screen** (`/ride/summary/:rideId`) — post-ride score (out of 100), map/route, **Share** (posts to the social feed), **Export JSON**, **Export GPX**, "Save & done".

## 3. Rides / stats (`features/stats`) — bottom nav tab "Rides"

- **"Your Journey"** — rider rank/level (New Rider → Weekend Rider → Steady Cruiser → Road Regular → Seasoned Rider → Veteran → Road Master, 500 km per level).
- Badges (earned via `badgeSyncProvider`).
- Ride history line chart and a rides list.
- **Sortable rides list** (added 2026-08-03): chips for **Recent / Top speed / Distance / Duration / Best score**. The trailing figure on each row follows the active sort, so the list explains its own order.
  - Ranking reads the **full** ride history and truncates afterwards — `recentRides` is capped at 10, so sorting *that* by top speed would show the fastest of your last ten while calling it your fastest. `RiderStatsSummary.allRides` exists for this.
  - Ties break by recency (repeated commutes and 0.0 km test rides tie constantly; without it the list reshuffles between rebuilds). Missing values sort **last** — a ride with no recorded duration is a data gap, not the longest ride.
  - The sort is **not persisted**: it's a momentary question, not a preference.
- Empty state for zero-ride accounts.

## 4. Garage (`features/garage`) — bottom nav tab "Garage"

- **Garage screen** — bike list; header menu → **Profile**, **My Places**, **My Shared Rides**; empty state with "Add Bike" CTA.
- **Add/Edit Bike screen** (`/home/garage/add`, `/home/garage/:bikeId/edit`).
- **Bike detail screen** (`/home/garage/:bikeId`) — bike info, delete (with confirmation), **"Discuss this bike"** deep link into the matching forum thread. Deleting a bike removes its rides, their GPS points and its maintenance logs; it silently deadlocked before 2026-08-01 (`Issues.md` §7).

## 5. Maintenance (`features/maintenance`) — reached from Garage/bike detail

- **Maintenance screen** (`/home/maintenance?bikeId=`) — service log list per bike, reminders shown as "every N km", delete a log entry, empty state ("No active bike" / "No service logs yet").
- **Add service log screen** (`/home/maintenance/add`).
- **Service types** (expanded 2026-08-01): the original Oil Change / Air Filter / Chain Lube / Tire Check plus Radiator-Coolant, Front Disc Pads, Rear Drum Pads, Brake Fluid, Spark Plug, Battery, Valve Clearance, Clutch Cable and Suspension — and a **Custom** type that requires the rider to name the service ("What did you service?"), shown by that name in the log list.
- **Reminders** cover the original four plus brake fluid and front disc pads. The rest are log-only by design: a card per type would bury the ones that matter. See `_reminderTypes` in `maintenance_provider.dart`.

## 6. Places / POI directory (`features/poi_directory`) — bottom nav tab "Places"

- **Places list screen** — nearby places, "import nearby places" (Overpass-backed), "Add place" FAB, empty state; a labelled **Routes** row at the top of the list (see §6a).
- **Place detail screen** — address, phone, hours, star rating, **submit a review**.
- **Add place screen**.
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

- **Feed tab** — shared rides with score, comment count, inline comments; "Find riders" (search by username); empty state pointing users to share a ride from its summary screen.
  - Each card renders the ride's **route map** (Strava-style). With a photo, photo and map sit side by side; without one, the map spans the card.
  - Rides carry an optional **caption**, written on the share screen.
- **Forums tab** (`forums_home_screen.dart`) — "Your bikes" forums (both brand-level *and* model-level, e.g. Yamaha and Yamaha RX100), Topics, **Rider forums**, and brand search → **forum thread screen** → **new post** (bottom sheet) → **post detail screen**.
  - The "Your bikes" list is cached in `SharedPreferences` keyed by a garage signature, so it no longer re-runs a Firestore transaction per bike on every visit.
  - **Rider-created forums** (`/forums/create`): the creator becomes a maintainer and can appoint others (by UID — a beta shortcut). Maintainers and the creator can delete posts/replies; riders can always delete their own. The global admin (`the.abraar.rar@gmail.com`) can moderate anywhere. Enforced in `firestore.rules`, not just client-side.
  - Topics now include Engine Rebuild, Mileage Tips and Engine Oil Review.
- **Ride share screen** (`/ride/share/:rideId`) — caption, photo, audience, and **Save as route**.
- **My shared rides screen** (`/rides/mine`, reached from Garage header menu) — delete a shared ride.
- **Notifications screen** (`/notifications`).
- **User profile screen** (`/profile/:uid`) — public profile view, showing a rider's bikes.

## 7b. Ride with friends / group rides (`features/social`)

Added 2026-08-01, on the group-ride data layer that had existed with no UI.

- **"Ride with friends"** button on the Record screen, under the bike picker.
- **Friend picker** — search riders by username, pick **2 to 10** (bounds enforced by a pure `validateGroupSelection`; live "n/10" counter, self excluded, duplicates collapsed, an 11th refused).
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

- **Settings screen** (`/settings`) — profile summary, **Appearance** (theme switch: *Carbon Mono* dark instrument-panel theme vs. *Editorial* light warm-paper theme — added 2026-08-01, see `app/lib/core/theme/theme_style_provider.dart`), **Emergency Contacts** (add/delete; used by crash-detection escalation), **Sign Out**.
  - **Language** (added 2026-08-02, directly below Appearance): System default / English / বাংলা, persisted like the theme. Only the **settings screen itself** is translated so far — the rest of the app is still hardcoded English. The point of this pass was proving the pipeline end to end, not translating ~700 strings.
    - **Numerals stay Western (0-9) in Bangla**, deliberately — speed, distance and odometer are read at a glance through a visor, and BD speedometers, road signs and number plates all use 0-9. A test fails if a Bengali numeral ever appears in a Bangla string. See `core/i18n/numeric_locale.dart`.
    - ⚠️ **Font caveat:** IBM Plex has no Bengali glyphs, so Bangla falls back to the platform face (Noto Sans Bengali / system). No tofu, but Bangla renders in a visibly different typeface. Bundling a Bengali face and setting `fontFamilyFallback` is outstanding.
    - To add a string: add the key to **both** `lib/l10n/app_en.arb` and `app_bn.arb`, run `flutter gen-l10n`, and **commit the regenerated `lib/l10n/app_localizations*.dart`** — it's generated-and-committed so a clean checkout analyzes without a codegen step.
  - The Appearance section shows a live **app-mark preview** that swaps with the theme. The mark itself is otherwise only used on the splash and sign-in screens, which a signed-in rider never sees — so without this the toggle looked like it wasn't changing the logo at all (`Issues.md` §8).
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
