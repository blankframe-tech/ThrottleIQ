# ThrottleIQ beta-v4.7.1 — `1.0.0-beta.4.7.1+29`

_Released 2026-10-16 · AAB: `app/build/app/outputs/bundle/release/app-release.aab` · versionCode 29 · previous: `beta-v4.7.0` (+28)_

## Play Console release notes (en-US, under 500 chars)

```
What's new in 4.7.1
• Places: the full-screen map's exit and filter buttons no longer hide under the iPhone status bar, so you can always get back to the half view.
• Live share uses less data while you're stopped or crawling in traffic.
• Fixes and polish.
```

## What changed since beta-v4.7.0

- **Full-screen map controls** (`places_list_screen.dart`): full screen drops the AppBar, which was the only thing clearing the status bar, so the exit and filter buttons sat under the Dynamic Island and couldn't be tapped. The body is now in a top-only `SafeArea`. Regression test in `places_hub_test.dart`. Installed on an iPhone (iOS 27 beta) before release, not yet checked by hand.
- **Live share write gate** (`d0a4311`): a tick writes `liveSessions/{token}` only on a new token, a status change, 100 m moved or 15 s elapsed. A moving rider still updates every 10 s.
- Not user-facing: rules compile-warning fix, users visibility backfill script (not run), Spark quota load test, docs.

## Known gaps

- The beta-v4.7.0 gaps still apply (see that file and `issues_open.md` §103).
