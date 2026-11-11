# Test Directory

Contains unit, widget, and integration tests for the application.

## Submodules

This directory contains the following submodules:

- **[calculators](./calculators)**: Contains domain-specific calculators and algorithms (e.g., fuel efficiency, distance).
- **[cloud](./cloud)**: Ride upload-payload tests (route columns).
- **[core](./core)**: Contains core application infrastructure, services, theme definitions, and utilities shared across the app. SyncManager's guard behaviour is covered in `core/cloud/sync_manager_guard_test.dart`.
- **[database](./database)**: Components and logic related to database.
- **[features](./features)**: Contains all the feature-based modules of the application following clean architecture.

## Files

The following files are present in this directory:

- `key_screens.dart`: pumps the key screens (cockpit, login, register, Settings > Advanced) from fixed data with fakes, with the app's real fonts. Shared by the two files below.
- `text_scale_sweep_test.dart`: every key screen at 1.0, 1.3, 1.6 and 2.0 text scale, English and Bangla; any overflow fails (#48).
- `key_screens_golden_test.dart`: golden screenshots in `goldens/`, light and dark (#49).

## Fonts and goldens

IBM Plex and Space Grotesk ship in `app/assets/google_fonts/` (named `<Family>-<Weight>.ttf`, the names google_fonts looks for in the asset bundle), so the app never downloads them. `loadKeyScreenFonts()` turns runtime fetching off, so a variant the app asks for that isn't bundled fails `setUpAll` with "unable to load font X": add that file from `https://fonts.gstatic.com/s/a/<sha256>.ttf` (the hash is in the google_fonts package source; check it with `shasum -a 256`). Licence: `assets/google_fonts/OFL.txt`.

Goldens run on macOS only (`@TestOn('mac-os')`): text antialiasing differs on Linux, so CI (ubuntu) skips them and `scripts/check.sh` on the Mac checks them. After an intended visual change, regenerate on the Mac and review the PNG diff before committing:

```sh
cd app && flutter test --update-goldens test/key_screens_golden_test.dart
```
