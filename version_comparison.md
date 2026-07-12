# ThrottleIQ Version Comparison

After analyzing the different versions of the ThrottleIQ legacy project (`FlutterSpecialistClaude` and `FlutterSpecialistClaude 2` through `5`), I have determined that **`FlutterSpecialistClaude` (Version 1)** is the most advanced version, containing the newest features, most up-to-date dependencies, and background processing capabilities. 

All of the numbered versions (`2` through `5`) were last modified on April 28th, whereas the base `FlutterSpecialistClaude` directory contains much newer code from May 14th.

## Key Advancements in `FlutterSpecialistClaude` (Version 1)

Here are the primary differences that make Version 1 the most advanced:

### 1. Additional Dependencies & Features
Version 1 introduces new dependencies in `pubspec.yaml` that are completely missing from the older numbered versions. This indicates new features were being actively built:
*   **Background & Performance Processing**:
    *   `wakelock_plus: ^1.2.0`
    *   `workmanager: ^0.9.0+3`
    *   `flutter_background: ^1.1.0`
*   **QR Code Capabilities**:
    *   `qr_flutter: ^4.1.0`

### 2. Dependency Upgrades
Version 1 also features significant upgrades across the board for core infrastructure compared to the older versions:
*   **Riverpod:** Upgraded from `^2.5.1` to `^3.3.1`
*   **Go Router:** Upgraded from `^13.2.0` to `^17.2.3`
*   **Firebase Core:** Upgraded from `^2.27.1` to `^4.8.0`
*   **Sensors Plus:** Upgraded from `^4.0.2` to `^7.0.0`
*   **Geolocator:** Upgraded from `^11.0.0` to `^14.0.2`

### 3. Core Logic & Provider Differences (`lib/features/ride/`)
The main logic differences between the most advanced version (Version 1) and older versions (like Version 2) reside in the Ride feature:

*   **`ride_recording_provider.dart`**:
    *   **Version 1** contains much more logic (386 lines vs 318 lines).
    *   **Version 1** directly integrates live sensor data streams (`sensors_plus`) for computing `sensorAccelMs2` right within the provider state. 
    *   **Version 2** completely removed the live sensor polling from the provider and switched to relying purely on `google_maps_flutter`, whereas Version 1 (and the others) use `flutter_map` alongside `latlong2`.

*   **`event_detector.dart`**:
    *   **Version 1** is more streamlined. It relies on the sensor stream in the provider to detect hard braking and rapid acceleration.
    *   **Version 2** tries to calculate acceleration locally within the detector itself, which was an older approach before moving the continuous sensor stream to the provider in Version 1.

### 4. UI Differences
Differences were also detected in the presentation layer, adapting to the more advanced provider logic:
*   `active_ride_screen.dart`
*   `ride_summary_screen.dart`
*   `splash_screen.dart`

## Conclusion

If you are looking to resume development from the most feature-rich and up-to-date codebase, you should exclusively use the **`FlutterSpecialistClaude`** directory. It contains the most advanced background location, sensor polling, and modern dependency ecosystem of all the legacy folders.
