# Test Directory

Contains unit, widget, and integration tests for the application.

## Submodules

This directory contains the following submodules:

- **[calculators](./calculators)**: Contains domain-specific calculators and algorithms (e.g., fuel efficiency, distance).
- **[cloud](./cloud)**: Ride upload-payload tests (route columns).
- **[core](./core)**: Contains core application infrastructure, services, theme definitions, and utilities shared across the app. SyncManager's guard behaviour is covered in `core/cloud/sync_manager_guard_test.dart`.
- **[database](./database)**: Components and logic related to database.
- **[features](./features)**: Contains all the feature-based modules of the application following clean architecture.
- **[repositories](./repositories)**: Ride repository tests.

## Files

The following files are present in this directory:

- `widget_test.dart`: Unit/Widget test file.
- `key_screens.dart`: pumps the key screens (cockpit, login, register, Settings > Advanced) from fixed data with fakes, with the app's real fonts. Shared by the two files below.
- `text_scale_sweep_test.dart`: every key screen at 1.0, 1.3, 1.6 and 2.0 text scale, English and Bangla; any overflow fails (#48).
- `key_screens_golden_test.dart`: golden screenshots in `goldens/`, light and dark (#49).

## Fonts and goldens

`fonts/` holds the exact IBM Plex and Space Grotesk files google_fonts downloads at runtime, named the way google_fonts caches them (`<family>_<variant>_<sha256>.ttf`); `loadKeyScreenFonts()` points google_fonts at that folder. A screen that asks for a variant not in the folder fails `setUpAll` with "unable to load font X": copy that file in from `https://fonts.gstatic.com/s/a/<sha256>.ttf` (the hash is in the google_fonts package source). Licence: `fonts/OFL.txt`.

Goldens run on macOS only (`@TestOn('mac-os')`): text antialiasing differs on Linux, so CI (ubuntu) skips them and `scripts/check.sh` on the Mac checks them. After an intended visual change, regenerate on the Mac and review the PNG diff before committing:

```sh
cd app && flutter test --update-goldens test/key_screens_golden_test.dart
```
