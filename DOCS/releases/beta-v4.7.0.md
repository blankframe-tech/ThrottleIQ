# ThrottleIQ beta-v4.7.0 — `1.0.0-beta.4.7.0+28`

_Released 2026-10-15 · AAB: `app/build/app/outputs/bundle/release/app-release.aab` · versionCode 28 · previous: `beta-v4.6.0` (+27)_

## Play Console release notes (en-US, under 500 chars)

```
What's new in 4.7.0
• Places: full-screen map. Hide everything but the map, filters and place cards, handy when you need fuel or a garage fast.
• Shared rides are more compact: @username, bike model and ride score in one tidy card.
• Your own shared ride: edit photos and caption, delete the post, or open the full ride.
• Delete a ride from Rides → History.
• During a ride, set where your phone is (mount, pocket, bag) from the top-left pill.
• Fixes and polish.
```

## What changed since beta-v4.6.0

- **Places full-screen map** (`places_list_screen.dart`, `placesFullMapProvider`): hides the app bar, hub tabs, search, radar banner and result row. Category chips, filter button and carousel stay. Android back exits full screen first.
- **Shared-ride feed card** (`social_feed_tab.dart`, `rider_handle.dart`): `@username` replaces the full name, bike model sits right-aligned, the "Motorcycle" label is gone, and the riding score moved into the stat row.
- **Owner menu on your shared ride** (`shared_ride_detail_screen.dart`, `edit_shared_ride_sheet.dart`): Edit ride (caption + up to 3 photos), Delete ride (post only, points to History for full delete), See more.
- **History → Delete ride** (`ride_summary_screen.dart`): local delete with a sync tombstone, plus a best-effort delete of the shared post.
- **Cockpit fixes** (`active_ride_screen.dart`, `phone_placement_selector.dart`): the beta "I'm in a jam" button no longer covers the speed panel. Phone placement moved from the Record screen to a top-left pill during the ride.

## Known gaps (see `issues_open.md` §103)

- Nothing above was checked on a device before release; the E2E test was not run.
- Deleting a ride doesn't roll back the bike odometer. Shared-post delete from History fails silently offline.
- New Bangla strings are machine-drafted (`bn_pending_review.txt`).
- Ride analytics don't record mid-ride phone-placement changes; placement is read only at impact time.
