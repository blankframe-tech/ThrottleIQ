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
Places  → place detail | add place | (header) my places, routes
Routes  → route detail → turn-by-turn navigation
Garage  → bike detail → edit bike | add bike | (header) edit profile,
           my places, my shared rides → maintenance → add service log

Full-screen (no bottom nav): Settings, Notifications, Edit Profile,
User Profile (:uid), Ride Summary, Ride Share, Forum Thread/Post,
Create Forum, Routes list/detail/navigate, Save Route
```

---

## 1. Auth & onboarding (`features/auth`)

- **Splash screen** — routes to login or home based on auth state.
- **Login** — email/password sign-in, "Continue with Google".
- **Register** — create an account.
- **Onboarding** — shown once after first sign-in (until `displayName` is set), before the user reaches the main shell.

## 2. Record a ride (`features/ride`)

- **Record screen** (center tab, default screen) — shows the active bike (or a warning + "Add Bike" CTA if none is selected), "swipe right" / "slide to start ride" gesture to begin recording, notifications bell, settings shortcut.
- **Active ride screen** (`/ride/active`, full-screen) — live map + stats, pause/resume, end ride (with confirmation), **share live location** (generates a `/live/{token}` link via SMS/share sheet, hosted at `throttleiqfb.web.app`), and a full-screen **crash-detected "Are you OK?" overlay** with a dismiss countdown.
- **Ride summary screen** (`/ride/summary/:rideId`) — post-ride score (out of 100), map/route, **Share** (posts to the social feed), **Export JSON**, **Export GPX**, "Save & done".

## 3. Rides / stats (`features/stats`) — bottom nav tab "Rides"

- **"Your Journey"** — rider rank/level (New Rider → Weekend Rider → Steady Cruiser → Road Regular → Seasoned Rider → Veteran → Road Master, 500 km per level).
- Badges (earned via `badgeSyncProvider`).
- Ride history line chart and a recent-rides list.
- Empty state for zero-ride accounts.

## 4. Garage (`features/garage`) — bottom nav tab "Garage"

- **Garage screen** — bike list; header menu → **Edit Profile**, **My Places**, **My Shared Rides**; empty state with "Add Bike" CTA.
- **Add/Edit Bike screen** (`/home/garage/add`, `/home/garage/:bikeId/edit`).
- **Bike detail screen** (`/home/garage/:bikeId`) — bike info, delete (with confirmation), **"Discuss this bike"** deep link into the matching forum thread.

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
- **Edit profile screen** (`/profile/edit`) — profile fields + **audience/privacy picker**: Everyone / Mutuals / Only me.

---

## Known UI gaps (as of this pass)

- No dedicated screen shows `VehicleState` confidence/heading/cornering data captured per-point (Phase 1 of the vehicle-state engine persists it; nothing renders it yet — see `HANDOFF_Document.md`).
- Fuel log, documents wallet and curated "best roads nearby" from the competitor feature map in `HANDOFF_Document.md` Part 2 are not built. (Turn-by-turn navigation now IS — see §6a — though geometrically, not via a routing engine.)
- **Discovered (public) routes can't be opened yet.** A route doc lives under `users/{uid}/routes/{id}`, and `routeByIdProvider` looks it up under the *signed-in* rider's uid, so only your own routes have a working detail screen. Opening someone else's needs the owner uid threaded through the route params. The Discover cards are deliberately non-tappable rather than tappable-and-broken.
- iOS Simulator screenshots for every screen above are still outstanding — see the note at the top of this file.
- **None of the 2026-08-01 feature work below has been exercised on a device** — it is verified by `flutter analyze`, 363 passing tests, and a release build only. See "Done, but NOT yet verified" in `HANDOFF_Document.md`.
