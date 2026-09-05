# Play Store screenshot shot list

`aso_refresh_notes.md` flagged that `store_listing/` has an icon and
feature graphic but no actual screenshots — the single highest-conversion
gap left before launch, per current ASO guidance. This turns that into a
concrete list: exactly which screens to capture, in what order, and what
caption overlay text to add (Play screenshots convert better with a short
caption bar, not a bare screenshot).

**How to capture:** real device, real (or realistic seeded) data — not the
emulator, not a blank/empty state. If a screen has no real content yet
(e.g. a fresh account's empty forum), use the seeded QA content
(`Issues.md` §55) rather than shipping a screenshot of an empty screen.
Portrait orientation, matching Play's standard phone screenshot spec.

Order matters — it mirrors the message-priority order already established
per segment in `pitch_and_marketing_materials.md`, broadest appeal first:

| # | Screen | Caption overlay (EN) | Caption overlay (BN) | Why this order |
|---|---|---|---|---|
| 1 | Ride summary card (post-ride: max speed, distance, duration, hard-braking/accel counts) | "Every ride, fully analyzed" | "প্রতিটি রাইডের সম্পূর্ণ বিশ্লেষণ" | Broadest appeal — the core loop everyone uses |
| 2 | Live ride-recording screen (speed/accel/distance mid-ride) | "Works even with zero signal" | "সিগন্যাল না থাকলেও কাজ করে" | Offline-first hook, strongest for commuters |
| 3 | Garage / maintenance screen (bike list + service intervals by distance) | "Never guess when it's due again" | "আর অনুমানে চলবে না" | Commuter segment's #2 message |
| 4 | Crash-detection countdown screen | "A countdown, not a guess" | "অনুমান না, একটা কাউন্টডাউন" | Family-segment hook — keep this caption precise, no overclaim |
| 5 | Live-location share view (from the rider's side, choosing contacts) | "Share your ride, live, with who you choose" | "যাকে চান, তার সাথে লাইভ শেয়ার করুন" | Backs the crash-detection screenshot with the actual mechanism |
| 6 | Group-ride live map (multiple riders' positions) | "See your whole group, live" | "পুরো গ্রুপ একসাথে, লাইভ" | Enthusiast segment's group-ride hook |
| 7 | Rider forum / feed (brand-model forum with real posts) | "Find your bike's people" | "আপনার বাইকের কমিউনিটি" | Community, secondary for both segments |
| 8 (optional) | Places directory (nearby fuel/garage/parts on map) | "The nearest fuel stop, one tap away" | "সবচেয়ে কাছের ফুয়েল পাম্প, এক ট্যাপে" | Rounds out feature coverage if an 8th slot is used |

**Caption-writing rule, same as everywhere else in this folder:** screenshot
4/5 captions must not imply automatic notification or SMS/email delivery —
see the no-overclaim rule in `.claude/skills/throttleiq-marketing/SKILL.md`.
"A countdown, not a guess" is deliberately precise about what's real.

**Do not include:** a screenshot of any screen showing mocked/unbuilt
behavior (no SMS-escalation screen exists to shoot anyway, since it isn't
built), or a screenshot of an obviously empty state (a forum with zero
posts, a Places map with zero pins) — better to seed content first
(`marketing.md` §3's cold-start fix) than ship a screenshot that makes the
app look abandoned.
