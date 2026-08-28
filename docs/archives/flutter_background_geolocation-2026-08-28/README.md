# Archived: `flutter_background_geolocation` auto-tracking implementation

**Archived 2026-08-28.** This is the paid-plugin implementation of
auto-tracking (background ride detection) that shipped in the code from
2026-08-16 (see `docs/auto_tracking_plan.md`) until it was swapped for a free
stand-in on 2026-08-28, because the plugin's Android licence key was never
purchased — the literal placeholder `PASTE_LICENCE_KEY_BEFORE_RELEASE` was
still in `AndroidManifest.xml`, and every Android release build crashed on
launch with a licensing error (`docs/Issues.md` §35). The product decision as
of 2026-08-28: **stay on the free tier for roughly the next three months**
rather than buy the key now. This archive exists so that decision is cheap to
revisit — see `docs/HANDOFF_Document.md`'s backlog for the pros/cons that
should drive the revisit, and `../auto_tracking_service.dart` in this repo
(the live file) for what replaced it.

## What's here

- `auto_tracking_service.dart` — the full paid-plugin implementation, as it
  stood immediately before the swap. Untouched since; this is a straight
  copy, not a summary.
- `platform-config.md` — every non-Dart change (pubspec, Gradle, both
  manifests, `AppDelegate.swift`) that came out alongside it, so restoring
  the plugin doesn't mean re-deriving them from scratch.

## How to restore it

1. Copy `auto_tracking_service.dart` back over
   `app/lib/core/services/auto_tracking_service.dart`.
2. Apply every block in `platform-config.md` to its file. Watch for drift —
   the free-tier implementation has had almost three months to change the
   surrounding code in each of those files by the time anyone reads this.
3. Buy a licence key at https://shop.transistorsoft.com for application id
   `com.bft.throttleiq` (per-app-id, one-time — price wasn't published
   without going through their site, so get a current quote rather than
   trusting a number written here) and paste it into the manifest.
4. `flutter pub get`, then `flutter build apk --release` and confirm it
   builds and the release APK doesn't crash on launch (that was exactly the
   original bug — `docs/Issues.md` §35 — don't just trust a clean build).
5. `AutoDetectionDao`, the `auto_detections`/`auto_fixes` schema, and
   `AutoRideReconcilerService` need no changes either direction — see
   `platform-config.md`'s last section.

## Why it might be worth reviving

The doc comment at the top of the archived file makes the case at the time
it was written: one paid, tested unit vs. reassembling platform activity
recognition, iOS significant-location-change, an OEM-battery-killer-resistant
foreground service, and a headless isolate out of separate free packages.
That case doesn't go away just because the licence wasn't bought — see the
pros/cons in `docs/HANDOFF_Document.md`.
