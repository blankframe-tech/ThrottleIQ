# Presentation Directory

Presentation layer containing UI components (screens, widgets) and state management (providers).

## Submodules

This directory contains the following submodules:

- **[providers](./providers)**: Contains Riverpod state management providers and notifiers for this feature. These manage state and bind data to the UI.
- **[screens](./screens)**: Contains Flutter UI screen widgets for this feature. These are the main views presented to the user.
- **[widgets](./widgets)**: The Places hub's pieces: place card and rating badges, map view, filter sheet, Highway Radar banner, Saved tab, status panels, and the shared Directions/Call launchers.

## Files

The following files are present in this directory:

- `place_category_l10n.dart`: Localized place-category names.
- `place_category_style.dart`: Each category's accent color and map icon.
- `place_tag_l10n.dart`: Localized rider-tag names.
