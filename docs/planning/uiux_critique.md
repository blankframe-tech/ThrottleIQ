# ThrottleIQ — UI/UX Critique

Based on a review of the actual app screenshots in `screenshots/carbon_mono/`
(login → recording → summary → stats → garage → places → social → settings).
Screenshot filenames are referenced so each point can be cross-checked against
the image directly.

## Strengths, briefly

- Consistent dark, high-contrast visual language (black + neon lime accent)
  that reads as "motorcycle instrument cluster," not a generic app template.
- Ride summary, maintenance, and stats screens are information-dense in a
  good way — clear hierarchy, sensible grouping.
- Good micro-copy honesty in Settings (e.g. "Detect rides automatically...
  uses 3–5% battery").
- Empty states (Routes, Places) have friendly, instructive copy instead of
  just "nothing here."

## Real problems

1. **The paused-ride screen makes safety data unreadable**
   (`06_ride_paused.png`) — When you pause, a dark scrim drops over the
   *entire* screen including the stat card: speed, distance, and the
   brake/accel meter all fade to near-illegible grey-on-black. If this
   screen is meant to be glanced at mid-ride, dimming the exact numbers you'd
   check is backwards. Dim the map, not the stat card.

2. **The exposed "Emergency Contacts" feature is half-built and says so**
   (`38_settings.png`) — Copy literally reads *"Logged if a crash is
   detected... Automatic SMS/email alerts aren't live yet."* Shipping a
   safety feature that tells the user it won't actually alert anyone is
   worse than not showing it — it invites a false sense of security. Hide it
   or clearly gate it as "Coming soon" instead of leaving it in the main
   settings list looking functional.

3. **Home tab has a large dead zone** (`03_home_record.png`) — Between "Ride
   with friends" and the slide-to-start bar there's roughly half a screen of
   empty black space. The bike card also reserves a big rectangle for a
   photo that's never there — just a generic grey silhouette. Reads as a
   layout built for content (bike photos, recent activity) that doesn't
   exist yet, not a deliberate minimalist choice.

4. **Live-ride map is too busy for a glance-while-riding UI**
   (`05_ride_recording.png`) — Default OSM styling with dense labels, under
   a card that already covers ~40% of the screen. For a screen whose entire
   purpose is a half-second glance during motion, the map needs heavier
   decluttering (fewer labels, bigger route line) instead of competing with
   the stat card.

5. **Places list: floating button covers content** (`23_places_nearby.png`)
   — The "+ Add place" FAB sits directly on top of the last visible list row
   (CNG Fuel Station), with no bottom padding reserved for it. A layout bug,
   not a design decision.

6. **Ratings render as "★ —"** (`23_places_nearby.png`) — Every place with 0
   reviews shows a star plus a bare dash instead of something like "No
   ratings yet." At a glance it looks broken rather than "no data."

7. **Ride summary has a redundant score presentation**
   (`08_ride_summary.png`) — One card says `100 / SMOOTH OP.`, and the
   adjacent card says `RIDING SCORE / Smooth op. / out of 100`. Same number,
   same label, said twice in adjacent boxes — reads as two half-finished
   versions of the same widget rather than one considered one.

8. **Maintenance status pill doesn't seem to change with urgency**
   (`21_maintenance_service_checks.png`) — Chain Lube shows 609/700 km left
   (~13% margin) and still shows a green "OK" pill, identical to a part with
   19,909 km left. If "OK" never shifts to a "due soon" state before hitting
   zero, the pill isn't doing its job as an early warning — which is the
   entire point of a maintenance tracker.

9. **Chart readability** (`13_stats_your_journey.png`) — Distance/speed line
   charts have no y-axis gridlines or intermediate labels — only the single
   peak value and two endpoint dates are shown. The curves also spike
   sharply between points (looks like an over-eager spline interpolation),
   which can visually imply values that were never actually recorded.

## Smaller polish items

- Theme picker exposes 9 skins as a flat list with only two color dots + one
  line of description each (`40_theme_picker.png`) — hard to picture
  "rounded vs. sharp edges" without a live preview thumbnail.
- Secondary captions ("Distance," "Avg Speed," "km/h") are low-contrast
  grey-on-black throughout — worth a contrast pass given this is meant to be
  read outdoors/in sunlight.
- "In jam" as a stat label (`08_ride_summary.png`) is cute but informal next
  to otherwise precise labels like "moving" / "duration" — inconsistent
  register.
- Slide-to-start for the single most frequent action (starting a ride) adds
  friction; it's a pattern usually reserved for destructive/irreversible
  actions, not the primary CTA.

## Suggested next step

Turn this into a prioritized punch-list (safety-critical → layout bugs →
polish) in `docs/Issues.md` if/when these are picked up as actual work items.
