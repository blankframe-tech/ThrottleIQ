# ThrottleIQ — Feature Map & UI Flow (as built)

_Last updated: 2026-07-23 · Reflects the shipped code on `main` (v2 Editorial redesign, released `v2.0.0-beta.3+5`)._

> **Correction (2026-07-24):** several screens/flows shipped after this file
> was last substantively written and aren't reflected below — a username
> step in onboarding, a public profile screen (`/profile/:uid`, reachable
> from search results and forum posts), a notifications screen + dashboard
> bell icon (follow notifications), a rotating dashboard tagline, and a real
> app icon. Latest release is `v2.0.0-beta.4+6`; `feat/v2-social` was never
> an actual branch (see `HANDOFF_V2.md`'s branch note). `HANDOFF_V2.md`
> §8a–§8c has the full current account — treat this file as a snapshot of
> the pre-2026-07-23 screen inventory, still broadly accurate for anything
> it doesn't call out as changed.

> ⚠️ **Correction (2026-07-23):** the "Social tab" and "AI tab" entries in §2
> below are stale and describe an app state that predates even the v1 release
> — on `main` today the chatbot feature doesn't exist at all (removed long
> ago, replaced by the Stats/Rides tab), and the Social tab has a real
> Feed/Forums/Places experience, not a "Coming in V2" placeholder. Treat those
> two subsections as historical only; for the real current+in-progress Social
> structure see `HANDOFF_V2.md` §2–§5 (which is current through Epic E).

> **v2 rework in progress** on `feat/v2-social` — several flows below are being
> restructured (feed→search+follow+votes, Service tab→Places, Insights→Rides,
> garage user menu + per-bike service, map-pin places). This file describes the
> **current shipped** app; for the target structure see **`HANDOFF_V2.md`**.

This documents what a user actually sees and can do in the app **right now**, screen by screen — plus which features exist only as backend/logic with no UI yet. Verified by reading the router (`lib/core/router/app_router.dart`), the shell, and every screen file.

---

## 1. App map (route hierarchy)

```
/splash                         SplashScreen (auth check → redirect)
/auth/login                     LoginScreen
/auth/register                  RegisterScreen
/auth/onboarding                OnboardingScreen (display name + first bike)

/ride/active                    ActiveRideScreen        (full-screen, no bottom nav)
/ride/summary/:rideId           RideSummaryScreen       (full-screen, no bottom nav)
/settings                       SettingsScreen          (gear icon on Record tab)

AppShell — bottom navigation bar with 5 tabs:
├── /home/social                SocialScreen            [tab 1: "Social"] (Feed/Forums/Places sub-tabs)
├── /home/stats                 StatsScreen             [tab 2: "Insights" — → renaming to "Rides" in v2]
├── /home/record                RecordScreen            [tab 3: "Record" — center/default]
├── /home/maintenance           MaintenanceScreen       [tab 4: "Service" — → moving into Garage; slot becomes "Places" in v2]
│     └── /home/maintenance/add     AddMaintenanceLogScreen (?bikeId=)
└── /home/garage                GarageScreen            [tab 5: "Garage"]
      ├── /home/garage/add          AddEditBikeScreen (create)
      └── /home/garage/:bikeId      BikeDetailScreen
            └── /home/garage/:bikeId/edit  AddEditBikeScreen (edit)

Also registered full-screen (no shell): /forums/:forumId (+ /post/:postId),
/places (+ /add, /:placeId).
```

**Auth guard (router redirect):** unauthenticated → `/auth/login` · authenticated but no display name → `/auth/onboarding` · authenticated → `/home/record` (Record is the landing tab).

The whole app is **portrait-locked**, **light Editorial BW theme** (warm paper, black ink panels, Space Grotesk + Inter, blue primary accent + orange attention).

---

## 2. Screen-by-screen

### Splash (`/splash`)
Logo + auth state check, then auto-redirects. No user interaction.

### Login (`/auth/login`)
- Email + password fields → **Sign In** (Firebase Auth)
- **Continue with Google** button (Google → Firebase credential; account auto-created on first use)
- Link → Register
- Firebase errors mapped to friendly messages (wrong password, no user, etc.)

### Register (`/auth/register`)
- Email + password + confirm → creates Firebase account → onboarding

### Onboarding (`/auth/onboarding`)
Two steps, shown once (until a display name exists):
1. **Your name** — saved to the profile (SQLite + Firestore `/users/{uid}`)
2. **Your first bike** — make/model/cc etc. → becomes the active bike

### ▶ Record tab (`/home/record`) — the landing screen
- **Settings** gear (AppBar) → `/settings`
- **Active bike card** (name, cc) with **Change** → Garage; if no bike: "Add Bike" prompt
- Stat placeholders (distance/duration counters)
- **Hold-to-start button** (long-press with progress ring — prevents pocket starts). Disabled until a bike exists.
- On start: requests location permission (two-step: while-in-use → always for background), checks GPS is on, then navigates to Active Ride.

### Active Ride (`/ride/active`) — full-screen HUD
- Big **speed readout** (km/h) + distance + elapsed time
- **G-force bar** (BRAKE ←→ ACCEL live from accelerometer)
- **Status pills** (GPS/recording state)
- **Alert banner** — flashes on hard braking, rapid acceleration, overspeed, fatigue (with haptic pattern)
- **Pause/Resume** and **End Ride** (with "End Ride?" confirm dialog)
- **Live-share button** (top bar) — shares `throttleiqfb.web.app/live/{token}` via the system share sheet; the viewer updates every 10 s, no login needed
- **Crash countdown overlay** — full-screen red "CRASH DETECTED" takeover with a 60 s countdown and a big **I'M OK** button; if it hits 0, emergency contacts are notified
- Behind the scenes while recording: points buffered to SQLite every 20 samples/10 s, wakelock held, ride state persisted for crash-of-app recovery.

### Ride Summary (`/ride/summary/:rideId`)
- Distance, duration, max/avg speed stats
- **Riding Events** cards — hard brakes, rapid accels, high-jerk counts
- **Riding Score** (0–100 gauge)
- **Export JSON / Export GPX** → writes the file and opens the system share sheet
- **Done** → back to Record tab

### Settings (`/settings`)
- Profile card (name initial, display name, email)
- **Emergency Contacts** — add (name/phone/email dialog), list, delete; used by crash escalation
- **Sign Out**

### Social tab (`/home/social`)
**Placeholder.** Icon + "Social Feed — share rides, follow riders…" + a **"Coming in V2"** chip. No functionality.

### AI tab (`/home/chatbot`)
**UI shell only.** A chat interface ("ThrottleIQ AI — Motorcycle Intelligence") that replies with a canned message: *"AI Chatbot integration coming soon! Connect your Claude API key…"*. No model behind it.

### Service tab (`/home/maintenance`)
- Maintenance log list for the active bike (type, date, odometer, cost, notes)
- **Add** → AddMaintenanceLogScreen (`?bikeId=`) — pick type (oil, chain, tyres…), date, odometer, cost, notes
- Stored in SQLite (`maintenance` table, FK → bike, cascade delete)

### Garage tab (`/home/garage`)
- Bike list (cards); tap → **Bike Detail** (specs, stats, maintenance shortcuts, edit/delete)
- **Add bike** → AddEditBikeScreen (make, model, year, cc, etc.)
- One bike is "active" — used by Record and Service
- Deleting a bike cascades: its rides and their GPS points are removed

---

## 3. Primary UI flows

**First run**
```
Splash → Login → (Register?) → Onboarding: name → first bike → Record tab
```

**Record a ride** (the core loop)
```
Record tab → hold-to-start (perms + GPS check)
  → Active Ride HUD (speed / g-force / alerts / pause)
  → End Ride (confirm)
  → Ride Summary (stats, events, score)
  → Done → Record tab
```

**Manage bikes / service**
```
Garage → add/edit/detail bike            Service → log list → Add entry
```

---

## 4. ⚠️ Built in code, but NO UI wired to it yet

These have data models, repositories, providers — and in some cases full screens — but **nothing in the running app reaches them**. They ship in the APK as dead weight until wired.

| Feature | What exists | What's missing |
|---|---|---|
| ~~Crash countdown~~ | **WIRED 2026-07-14** — full-screen overlay + I'M OK button on Active Ride | — |
| ~~Live ride sharing~~ | **WIRED 2026-07-14** — share button on Active Ride; viewer hosted at `throttleiqfb.web.app/live/{token}` (verified 200) | Real-device tap-through pending |
| ~~Emergency contacts~~ | **WIRED 2026-07-14** — CRUD UI on the new Settings screen | — |
| ~~Cloud sync~~ | **WIRED 2026-07-14** — SyncManager starts on login / stops on logout (`app.dart`) | — |
| ~~Export JSON/GPX~~ | **WIRED 2026-07-14** — buttons on Ride Summary → share sheet (app-docs dir; the Downloads API is desktop-only) | — |
| **POI directory** (fuel/garages/parts) | Full data layer: entities, geohash utils, place+review repositories, Firestore rules & indexes | **No presentation layer at all** — no map/list screen exists |
| **Social: feed / routes / group rides / challenges** | Data layer + privacy-zone clipper exist; the four "screens" turned out to be **empty stubs** (static empty-states, zero data wiring) | Real feed/routes/group-ride UI is a feature build, not a wiring task; the Social tab keeps its placeholder |
| ~~User profile page~~ | **WIRED 2026-07-14** — Settings screen with profile card + sign out | — |

## 5. Placeholders (intentional)

- **Social tab** — "Coming in V2" card (the real screens exist but aren't connected; see above)
- **AI chatbot** — chat UI with canned response, awaiting a real model integration

---

## 6. Wiring status (2026-07-14)

Items 1–4 of the original wiring plan are **done** (crash overlay, sync bootstrap, export buttons, Settings screen — see §4). The social screens were descoped after inspection: they are empty stubs, so there is nothing real to route — a feed is a genuine feature build. POI UI remains the other genuine build.

Also fixed during wiring: the P6 rewrite of `EventDetector` had silently dropped hard-brake/rapid-accel counting (restored + tested), and a batch of latent errors in never-imported files (hand-rolled Taylor-series trig → `dart:math`, wrong DAO constructors, Android-unsupported Downloads API). **Test suite: 184/184 green.**
