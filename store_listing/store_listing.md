# Play Store Listing — Throttle IQ (com.bft.throttleiq)

Copy this into Play Console → Store presence → Main store listing.

## App name
Throttle IQ
(already locked in at app creation)

## Short description (max 80 characters — this is 78)
Track every ride: speed, routes, crash alerts, bike maintenance & rider feed.

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
• Export any ride as JSON or GPX to use in other tools

CRASH DETECTION
• Detects a likely crash from a sudden impact combined with a rapid drop in speed
• Starts a countdown you can cancel if you're okay
• Share a live link with your emergency contacts so they can see your location, speed, and battery in real time during a ride

GARAGE & MAINTENANCE
• Track multiple bikes, their odometers, and service history
• Log maintenance so you never lose track of what's due

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

Throttle IQ is under active development — expect frequent updates as we add features like curvy-route navigation, club events, and leaderboards.

---

## Privacy policy URL
`https://throttleiqfb.web.app/privacy.html`

Goes in **App content → Privacy policy**, not in the store listing text. Source file is `public/privacy.html`; see `data_safety_and_permissions.md`. Required before this app can be published at all (background location).

## Category
Suggested: Auto & Vehicles (alternative: Maps & Navigation)

## Tags / search terms (for your own reference — Play auto-derives from description + category)
motorcycle, ride tracker, GPS tracker, crash detection, bike maintenance, rider community, motorcycle log, ride log

## Notes on what was deliberately left out (accuracy)
- No claim of automatic SMS/email alerts to emergency contacts on no-response — that escalation path is currently mocked in the backend (Cloud Functions with Twilio/SendGrid aren't deployed yet per `todosanddone.md`). Only the manual live-share link and in-app countdown are described above, because those are the parts that actually work today.
- No claim about GPS route/track syncing across devices — only ride summaries, bikes, and maintenance data sync today; the point-by-point GPS trail doesn't sync yet.
- No specific data-point-per-second or accuracy numbers, to avoid over-precise claims that could be read as guarantees.

Update this listing once the SMS/email escalation is actually wired up — that's a meaningful safety feature worth promoting once it's real.
