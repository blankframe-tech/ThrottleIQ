# ThrottleIQ — Screen Walkthrough

Every main screen in the app, captured from the iOS Simulator (iPhone 17, iOS 26.5, 9:41 status bar,
Dhaka location) by the automated UI tour (`app/scripts/ui_tour/run_tour.sh`), and numbered in the
order you would walk someone new through it. Each look has 55 screens with identical
filenames, so `04_record_record_dashboard.png` in any folder is the same screen in a different look.

| Folder | Color mode | Shape | Brightness |
|--------|-----------|-------|------------|
| [`daily_curvy_light/`](daily_curvy_light/) | Daily (app default) | Curvy | Light |
| [`sport_boxy_dark/`](sport_boxy_dark/) | Sport | Boxy | Dark |
| [`adventure_boxy_dark/`](adventure_boxy_dark/) | Adventure | Boxy | Dark |

The themes are three independent axes (color mode x shape x brightness = 12 looks); these three are a
representative sample. Re-run the tour with other combo ids (e.g. `sport_curvy_light`) to capture more.
Each folder has its own README listing every screenshot.

## Not captured

- Scroll continuations, filled-in forms and feature-tour slides 2-7 (the tour takes them; they were left out to keep the repo small).
- **Group ride live map** (`/group-ride/:id`): needs a real group ride with an invited rider.
- **Route detail / navigation**: no saved or public routes exist on the test account.
