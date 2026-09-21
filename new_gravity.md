# New Issues Found (New Gravity)

These are new issues surfaced during the recent fix pass and verification:

### 1. Places Screen "Browse routes" Button Visual Clash
* **Location:** `places_list_screen.dart:126-137`
* **Issue:** 
  1. **Hardcoded Button Height:** The button hardcodes `OutlinedButton.styleFrom(minimumSize: const Size(0, 48))` instead of inheriting the theme default (52dp or 54dp). It is the only button in the app that is shorter than the theme and does not scale with the skin system.
  2. **Design Collision:** The button is shrink-wrapped and left-aligned. Because it sits directly under pill-shaped category chips with only 8dp of padding, it clashes visually. The intended "this is different" signal currently reads as "these components don't match". 
* **Fix Required:** Use `AppDimensions.controlHeight` instead of `48`. Revisit the design spacing (more separation from the chip row) or revert to a standard full-width outlined button.

### 2. Map Tile OSM Rate-Limiting During Tests
* **Location:** `app_tile_layer.dart` / Widget tests
* **Issue:** During automated test runs (`flutter test`), the app attempts to hit OSM tile servers (`https://tile.openstreetmap.org/...`) and produces `ClientException: HTTP request failed. Client is already closed.` errors.
* **Fix Required:** Mock the tile layer or network requests during widget testing to prevent spamming OSM servers and causing flaky test timeouts or rate limits.
