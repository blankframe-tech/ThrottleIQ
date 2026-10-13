# Utils Directory

Contains helper functions, constants, and extensions specific to this layer.

## Submodules

This directory contains the following submodules:

- **[extensions](./extensions)**: Components and logic related to extensions.
- **[formatters](./formatters)**: Components and logic related to formatters.

## Files

The following files are present in this directory:

- `badge_rarity.dart`: Badge rarity tiers, ownership % math, and local earned-date replay (pure).
- `badges.dart`: Dart source code.
- `bike_image_resolver.dart`: Resolves and validates bike photo paths and URLs.
- `crop_geometry.dart`: Pure geometry for the photo cropper.
- `downsample.dart`: Evenly thins a list to a budget, keeping first and last.
- `firebase_error_mapper.dart`: Dart source code.
- `geo_math.dart`: Great-circle distance and related geo maths.
- `geohash_util.dart`: Dart source code.
- `greetings.dart`: Time-aware greeting lines for the record screen.
- `image_crop_io.dart`: Decodes, rotates, crops and writes image pixels.
- `initials.dart`: Dart source code.
- `num_cast.dart`: Safe numeric reads for JSON/Firestore data.
- `ride_speed_invariant.dart`: Enforces "max speed ≥ average speed, ≤ plausible ceiling".
- `rider_stats.dart`: Dart source code.
- `riding_score.dart`: Dart source code.
- `slugify.dart`: Dart source code.

