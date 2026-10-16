# Play Store Listing — Throttle IQ (com.bft.throttleiq)

Copy this into Play Console → Store presence → Main store listing.

## App name
Throttle IQ
(already locked in at app creation)

## Short description (max 80 characters — this is 75)
Track every ride: routes, stats, bike maintenance, live share & rider feed.

## Full description (max 4000 characters — this is ~1850)

Throttle IQ is a ride tracking and motorcycle intelligence app built for riders who care about performance, safety, and keeping their bikes running right.

RIDE RECORDING
• Records automatically in the background, even with the screen locked
• Live speed, acceleration, altitude, and distance while you ride
• Smart alerts for overspeed, hard braking, rapid acceleration, and rider fatigue on long rides
• Works fully offline — rides are saved to your device first, every time

RIDE HISTORY & STATS
• Summary cards for every ride: max speed, distance, duration, hard-braking and rapid-acceleration counts
• Automatically separates moving time from stops
• Routes sync automatically across your devices
• Export any ride as JSON or GPX to use in other tools

LIVE SHARE
• Share a live link so family or friends can see your location, speed, and battery during a ride
• You choose when it starts, you can stop it any time, and it stops working after 24 hours

GARAGE & MAINTENANCE
• Track multiple bikes, their odometers, and service history
• See what each bike needs next and roughly when, by kilometres or date, whichever comes first
• Service schedules for popular models, adjusted for traffic and dusty or wet roads
• Log a whole service visit at once, with the bill and a photo of the receipt
• Reminders before something is due, and before your tax token or insurance expires
• Export a service record PDF when you sell your bike

RIDER PLACES
• Find fuel stops, repair garages, and parts shops near you, contributed and rated by other riders
• Quick one-tap access to the nearest fuel stop while riding

RIDER COMMUNITY
• Follow other riders and share your rides with photos and route summaries
• Upvote and comment in ride feeds and rider forums
• Choose who sees each ride with per-ride audience controls
• Your home location is never exposed — the start and end of every shared route are automatically trimmed

CLOUD BACKUP
• Your profile, bikes, and maintenance logs back up automatically when you're online
• Sign in with Google or email

Throttle IQ is under active development — expect frequent updates as we add features like curvy-route navigation and club events.

---

## Privacy policy URL
`https://throttleiqfb.web.app/privacy.html`

Goes in **App content → Privacy policy**, not in the store listing text. Source file is `public/privacy.html`; see `data_safety_and_permissions.md`. Required before this app can be published at all (background location).

## Category
Suggested: Auto & Vehicles (alternative: Maps & Navigation)

## Tags / search terms (for your own reference — Play auto-derives from description + category)
motorcycle, ride tracker, GPS tracker, bike maintenance, rider community, motorcycle log, ride log

## Notes on what was deliberately left out (accuracy)
- **No crash detection or emergency-alert claim anywhere (2026-10-14, critique `CrtiQue_Oct14.md` §11).** The detector is off in every build (`SensorConstants.impactDetectorLiveEnabled = false`), its thresholds are uncalibrated, and alert delivery to contacts is a mock. Advertising it would misrepresent the app to Google and to riders. Restore a safety section only after field calibration on labelled drop, pothole and fall recordings, and real delivery. Speed badges and leaderboards are gone from the app too, so the listing promises neither.
- No claim of automatic SMS/email alerts to emergency contacts on no-response — that escalation path is currently mocked in the backend (Cloud Functions with Twilio/SendGrid aren't deployed yet, blocked on the Blaze billing plan — see `DOCS/Handoff for agents and Todos/HANDOFF_Document.md`'s "Soon" section and `DOCS/For Devs and Contributors/architecture/backend_options.md`). Only the manual live-share link is described above, because it is the part that actually works today.
- No specific data-point-per-second or accuracy numbers, to avoid over-precise claims that could be read as guarantees.

GPS route/track syncing across devices is now real (chunked `track` docs, `DOCS/Handoff for agents and Todos/issues_fixed.md` §11) — added to the RIDE HISTORY & STATS section above (2026-09-05).

Update this listing once the SMS/email escalation is actually wired up — that's a meaningful safety feature worth promoting once it's real.

**Themes (2026-10-14):** the app has one light theme (Calming: cream and
sage) and one dark theme (Carbon Mono: carbon black and lime), plus "follow
the phone". The 28 color/shape combinations were cut (`CrtiQue_Oct14.md`
§14), so store screenshots need only these two looks, and the listing makes
no personalization claim.
