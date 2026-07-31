# ThrottleIQ — Machine Memory for Motorcycles

## The Problem

Motorcyclists have no equivalent of a car's onboard computer. Every ride's
speed, braking, and route data disappears the moment it happens, maintenance
is tracked in a notebook or not at all, and if a rider goes down alone on a
back road, nobody knows until they're overdue. Existing fitness/ride apps
(Strava, etc.) are built for cyclists and runners — they don't understand
motorcycle-specific risk (crashes at speed, fatigue on long highway stretches)
or motorcycle-specific upkeep (chain, oil, tires tied to distance ridden).

## The Solution

ThrottleIQ is a mobile app that turns a rider's phone into a black box and
riding companion for their bike:

- **Ride recording & analysis** — GPS + accelerometer capture 20+ data points
  a second: speed, acceleration, braking, jerk, route. Fully offline-first,
  so recording never depends on a signal.
- **Crash detection & emergency share** — detects a crash signature
  (impact + speed-drop) and can alert emergency contacts with a live,
  token-based location link — no account required on their end.
- **Maintenance tracking** — service intervals (chain, oil, tires, etc.)
  tracked automatically against actual distance ridden, not guesswork.
- **Social & community** — share rides with a following, audience-tiered
  privacy controls, forums, and a place directory (fuel, garages, parts)
  built by riders for riders.
- **Garage** — a fleet view of every bike a rider owns, its stats, and its
  maintenance history in one place.

## Why Now

Phones already have every sensor this needs (GPS, accelerometer) — the gap
is software, not hardware. Riders increasingly expect the kind of telemetry
and safety net that cars have had for a decade, and no incumbent app is
built rider-first for it.

## Status

Live beta (`v2.0.0-beta.5`) on iOS and Android, built solo, with a working
release pipeline (signed builds, GitHub releases). Core loop — record a
ride, get analyzed stats, track maintenance, share with friends — is fully
functional today. Offline-first architecture with automatic cloud sync
means the app works with zero connectivity and catches up when signal
returns.

## What's Next

- Crash-detection escalation (SMS/email if an emergency contact doesn't
  acknowledge within 15 minutes)
- Turn-by-turn "curvy road" navigation for scenic/sport riders
- Clubs and group ride events
- Premium tier (advanced analytics, unlimited history, priority support)

## Ask

Looking for [funding / mentorship / pilot riders / distribution partners —
fill in based on the competition] to take ThrottleIQ from a working solo-built
beta to the default riding companion for motorcyclists.
