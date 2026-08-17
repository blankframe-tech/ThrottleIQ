# ThrottleIQ — Screen Walkthrough

Every screen in the app, captured from the iOS Simulator (iPhone 17, iOS 26.5)
and numbered in the order you'd want to walk someone new through it.

Two skins, 40 screens each, identical filenames — so `01_login.png` in either
folder is the same screen in a different theme, easy to compare side by side.

| Folder | Skin | Look |
|--------|------|------|
| [`carbon_mono/`](carbon_mono/) | Carbon Mono (app default) | Dark, sharp, instrument-panel |
| [`trail_social/`](trail_social/) | Trail Social | Dark feed, punchy orange, rounded |

Each folder has its own README listing what every numbered screenshot shows.

## The run, in order

Auth (01–02) → recording a ride (03–12) → your rides and progress (13–16) →
garage and maintenance (17–22) → places and routes (23–28) →
social and community (29–35) → profile and settings (36–40).

## Skin differences worth knowing

Skins change more than colour — they carry a shape profile too. On the Record
screen, rounded skins like Trail Social render the start control as a circular
**press-and-hold** button, where sharp-edged skins like Carbon Mono use a
**slide-to-start** track. Compare `03_home_record.png` across the two folders.

## Not captured

- **Onboarding** (`/auth/onboarding`) — only shown to a brand-new account with no display name.
- **Group ride live map** (`/group-ride/:id`) — needs a real group ride with an invited rider.
- **Route detail / navigation** — no saved or public routes exist on this account yet.
