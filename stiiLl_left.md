# Still Unsolved Issues

These items from the Antigravity Grill verification remain open and unresolved:

### Safety & Telemetry
- **Crash Detection Switched Off:** `SensorConstants.impactDetectorLiveEnabled = false`. Needs the founder's decision on alert delivery and field/drop tests for calibration.
- **Gyro Heading Sign & Axis:** Cannot be verified without a mounted phone.
- **Route Navigation vs. Recording:** Route navigation does not record the ride. Needs a design call on merging navigation into the active-ride cockpit.
- **Crash Ride Badge:** Crash rides appear in history lists but without a clear "crash" badge.

### Infrastructure & Deployments
- **Map Tile Provider:** Release builds still hit OSM directly. A dedicated tile provider (e.g. MapTiler, Stadia) needs to be chosen and configured.
- **Keystore & CI:** Keystore lacks a backup. CI exists but hasn't run on GitHub, and branch protection is missing.
- **Firebase Blaze Plan Needed:** Real SMS/escalation, signed Cloudinary uploads, full account deletion, and adding new followers to old posts all require upgrading to the Blaze plan.
- **Chat Rule Backward Compatibility:** The new chat-create rule requires a fixed DM id, which will break older builds once deployed. The app build must ship before the rules.

### UI / UX & Assets
- **SafeQR Print:** SafeQR lacks a "Print sticker" feature (requires the `printing` package).
- **HoldToStartButton Flaw:** The button completes a hold if the press and release land in the exact same frame.
- **Missing Localization:** New Bangla strings (emergency banner, SafeQR share, moving/stopped) require native-speaker review. The new "Sync issues" screen is not localized.
- **Pitch Deck Discrepancies:** The iDEA pitch deck still claims working crash detection and a team structure not reflected in the repo history.
- **Outbox Scoping:** The immediate outbox attempt (`_attemptOne`) is not correctly scoped to the signed-in rider.
