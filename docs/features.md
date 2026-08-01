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
Rides   → stats/journey (rank, badges, chart, recent rides)
Record  → active ride (live) → crash overlay (conditional) → ride summary
Places  → place detail | add place | (header) my places
Garage  → bike detail → edit bike | add bike | (header) edit profile,
           my places, my shared rides → maintenance → add service log

Full-screen (no bottom nav): Settings, Notifications, Edit Profile,
User Profile (:uid), Ride Summary, Ride Share, Forum Thread/Post
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

## 6. Places / POI directory (`features/poi_directory`) — bottom nav tab "Places"

- **Places list screen** — nearby places, "import nearby places" (Overpass-backed), "Add place" FAB, empty state.
- **Place detail screen** — address, phone, hours, star rating, **submit a review**.
- **Add place screen**.
- **My places screen** (`/places/mine`, reached from Garage header menu) — places the current user added.

## 7. Social (`features/social`, `features/forums`) — bottom nav tab "Social"

- **Feed tab** — shared rides with score, comment count, inline comments; "Find riders" (search by username); empty state pointing users to share a ride from its summary screen.
- **Forums tab** (`forums_home_screen.dart`) — forum list, search, → **forum thread screen** → **new post** (bottom sheet) → **post detail screen**.
- **Ride share screen** (`/ride/share/:rideId`).
- **My shared rides screen** (`/rides/mine`, reached from Garage header menu) — delete a shared ride.
- **Notifications screen** (`/notifications`).
- **User profile screen** (`/profile/:uid`) — public profile view, showing a rider's bikes.

## 8. Profile & settings (`features/profile`)

- **Settings screen** (`/settings`) — profile summary, **Appearance** (theme switch: *Carbon Mono* dark instrument-panel theme vs. *Editorial* light warm-paper theme — added 2026-08-01, see `app/lib/core/theme/theme_style_provider.dart`), **Emergency Contacts** (add/delete; used by crash-detection escalation), **Sign Out**.
- **Edit profile screen** (`/profile/edit`) — profile fields + **audience/privacy picker**: Everyone / Mutuals / Only me.

---

## Known UI gaps (as of this pass)

- No dedicated screen shows `VehicleState` confidence/heading/cornering data captured per-point (Phase 1 of the vehicle-state engine persists it; nothing renders it yet — see `HANDOFF_Document.md`).
- Fuel log, documents wallet, curated "best roads nearby", and turn-by-turn navigation from the competitor feature map in `HANDOFF_Document.md` §12 are not built.
- iOS Simulator screenshots for every screen above are still outstanding — see the note at the top of this file.
