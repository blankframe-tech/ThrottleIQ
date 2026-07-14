# ThrottleIQ — Feature Map & UI Flow (as built)

_Last updated: 2026-07-14 · Reflects the actual code on `main`, not the roadmap._

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

AppShell — bottom navigation bar with 5 tabs:
├── /home/social                SocialScreen            [tab 1: "Social"]
├── /home/chatbot               ChatbotScreen           [tab 2: "AI"]
├── /home/record                RecordScreen            [tab 3: "Record" — center/default]
├── /home/maintenance           MaintenanceScreen       [tab 4: "Service"]
│     └── /home/maintenance/add     AddMaintenanceLogScreen (?bikeId=)
└── /home/garage                GarageScreen            [tab 5: "Garage"]
      ├── /home/garage/add          AddEditBikeScreen (create)
      └── /home/garage/:bikeId      BikeDetailScreen
            └── /home/garage/:bikeId/edit  AddEditBikeScreen (edit)
```

**Auth guard (router redirect):** unauthenticated → `/auth/login` · authenticated but no display name → `/auth/onboarding` · authenticated → `/home/record` (Record is the landing tab).

The whole app is **portrait-locked, dark theme**.

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
- Behind the scenes while recording: points buffered to SQLite every 20 samples/10 s, wakelock held, ride state persisted for crash-of-app recovery.

### Ride Summary (`/ride/summary/:rideId`)
- Distance, duration, max/avg speed stats
- **Riding Events** cards — hard brakes, rapid accels, high-jerk counts
- **Riding Score** (0–100 gauge)
- **Done** → back to Record tab

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
| **Crash countdown ("Are you OK?")** | Detection logic (accel+jerk+speed fusion, tested) and `crashDetected`/`crashCountdown` state in the ride provider | **No widget renders it.** Active Ride screen has no countdown modal / "I'm OK" button. A crash currently changes state invisibly. |
| **Live ride sharing** | Token generation + 10-s Firestore publishing in the provider; `public/live-viewer.html` viewer page | No "Share ride" button anywhere; viewer page not hosted; share URL points at unregistered `throttleiq.app` |
| **Emergency contacts** | Entity + Riverpod provider (Firestore CRUD) | No contacts screen; no Settings/Profile page to reach one |
| **Cloud sync** | `SyncManager` (5-min auto + reconnect), `CloudRepository` | **Never instantiated** — no `main.dart`/app-lifecycle hookup, so rides stay local-only |
| **Export JSON/GPX** | `ExportService` writes both formats to Downloads | No export/share button on Ride Summary |
| **POI directory** (fuel/garages/parts) | Full data layer: entities, geohash utils, place+review repositories, Firestore rules & indexes | **No presentation layer at all** — no map/list screen exists |
| **Social: feed / routes / group rides / challenges** | Screens exist as files (`feed_screen.dart`, `route_list_screen.dart`, `group_ride_map_screen.dart`, `ride_detail_screen.dart`) + full data layer + privacy-zone clipper | **Screens are orphaned** — no route or navigation reaches them; the Social tab shows the "Coming in V2" placeholder instead |
| **User profile page** | Profile DAO + Firestore profile storage | No profile/settings screen (no logout button anywhere either) |

## 5. Placeholders (intentional)

- **Social tab** — "Coming in V2" card (the real screens exist but aren't connected; see above)
- **AI chatbot** — chat UI with canned response, awaiting a real model integration

---

## 6. Suggested wiring order (highest user value ÷ effort)

1. **Crash countdown modal** on Active Ride — the detection already runs; this is safety-critical and purely a widget.
2. **SyncManager bootstrap** in `main.dart` — one hookup makes every recorded ride actually back up.
3. **Export buttons** on Ride Summary — service is done, needs two buttons.
4. **Settings/Profile screen** — logout + emergency contacts entry point (both blocked on this page existing).
5. **Swap the Social placeholder** for the existing `FeedScreen` + route the orphaned social screens.
6. **POI screens** — the only feature needing genuinely new UI (map + list + detail + review form).
```
