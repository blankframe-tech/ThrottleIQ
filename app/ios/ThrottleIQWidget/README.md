# ThrottleIQ iOS Widget Extension — setup

The Swift sources in this folder are complete, but the widget extension
**target does not exist in `Runner.xcodeproj` yet**. Nothing in this folder is
compiled until you create it.

This was left as a manual step on purpose: `Runner.xcodeproj/project.pbxproj`
is a machine-generated file that currently produces a working, device-verified
release build, and hand-editing it is the single most reliable way to break an
iOS build in a way that is hard to diagnose. Xcode's "New Target" flow writes
the same entries correctly.

**Android is unaffected** — the Android widgets are already fully wired and
ship in the release APK. Skipping this whole document costs you the iOS
widgets only.

---

## Facts you'll need

| Thing | Value |
| --- | --- |
| Runner bundle ID | `com.bft.throttleiq` |
| Widget bundle ID | `com.bft.throttleiq.ThrottleIQWidget` |
| App Group | `group.com.bft.throttleiq` |
| Runner deployment target | iOS 13.0 (Podfile pins platform 14.0) |
| Swift version | 5.0 |
| Target / product name | `ThrottleIQWidget` (exactly — the folder name must match) |

---

## 1. Create the App Group on the developer portal

1. Sign in at <https://developer.apple.com/account/resources/identifiers/list/applicationGroup>.
2. **Identifiers → + → App Groups → Continue.**
3. Description `ThrottleIQ Widgets`, Identifier `group.com.bft.throttleiq`. **Continue → Register.**
4. Go to **Identifiers → App IDs → `com.bft.throttleiq`**, enable **App Groups**,
   click **Edit**, tick `group.com.bft.throttleiq`, **Save**.

If you are using Xcode automatic signing you can skip this section — step 5
creates the group and provisioning profiles for you. Do it manually only if
you manage profiles by hand.

## 2. Open the workspace (not the project)

5. `open /Users/blackbird/Everything/dev/repos/ThrottleIQ/app/ios/Runner.xcworkspace`

   Always the **`.xcworkspace`**. Opening `Runner.xcodeproj` directly breaks
   the CocoaPods integration.

## 3. Add the Widget Extension target

6. **File → New → Target…**
7. Platform **iOS**, choose **Widget Extension**, **Next**.
8. Fill in:
   - Product Name: **`ThrottleIQWidget`** (exact spelling and case)
   - Team: the same team as Runner
   - Language: **Swift**
   - **Untick "Include Configuration App Intent"** (and "Include Live Activity"
     if offered). These sources use `StaticConfiguration`; leaving the box
     ticked generates an `AppIntent`-based template that will not compile
     against them.
   - Project: **Runner**, Embed in Application: **Runner**
9. **Finish.** When Xcode asks *"Activate ThrottleIQWidget scheme?"* click
   **Activate**.

## 4. Replace the generated sources with the ones in this folder

Xcode has just created a group named `ThrottleIQWidget` containing its own
template files. Replace them:

10. In the Project navigator, select every file Xcode generated inside the
    `ThrottleIQWidget` group — typically `ThrottleIQWidget.swift`,
    `ThrottleIQWidgetBundle.swift`, `AppIntent.swift`, and `Info.plist` — and
    **Delete → Move to Trash**. Keep the `Assets.xcassets` it generated.
11. Right-click the `ThrottleIQWidget` group → **Add Files to "Runner"…**
12. Select `ThrottleIQWidget.swift` and `Info.plist` from
    `app/ios/ThrottleIQWidget/`.
    - **Untick** "Copy items if needed" (the files are already in place).
    - Under "Add to targets", tick **ThrottleIQWidget only**. Make sure
      **Runner is unticked** — adding the widget sources to the app target
      causes duplicate-`@main` errors.
    - **Add.**
13. Select the **ThrottleIQWidget target → Build Settings**, search
    `Info.plist File`, and confirm `INFOPLIST_FILE` is
    `ThrottleIQWidget/Info.plist`. Fix it if Xcode left a stale path from the
    file you deleted.
14. In the same Build Settings, search `Generate Info.plist File` and set
    **`GENERATE_INFOPLIST_FILE` to `No`** — otherwise Xcode ignores the plist
    you just added and synthesises its own.

## 5. Add the App Group capability to BOTH targets

15. Select the **Runner** target → **Signing & Capabilities** → **+ Capability**
    → **App Groups**. Click **+** under the group list and add
    `group.com.bft.throttleiq`, then tick it.
    - This creates `ios/Runner/Runner.entitlements`. The Runner target has no
      entitlements file today, so this step is required, not optional.
16. Select the **ThrottleIQWidget** target → **Signing & Capabilities** →
    **+ Capability** → **App Groups** → add/tick the same
    `group.com.bft.throttleiq`.
17. Xcode will have generated `ThrottleIQWidget/ThrottleIQWidget.entitlements`
    (or offered to). A correct copy already exists in this folder; if Xcode
    created a different file, either point `CODE_SIGN_ENTITLEMENTS` at
    `ThrottleIQWidget/ThrottleIQWidget.entitlements` or verify Xcode's version
    lists `group.com.bft.throttleiq` under
    `com.apple.security.application-groups`.
18. Confirm both targets show a checked `group.com.bft.throttleiq` and no red
    signing errors.

    **This is the step that silently breaks everything if skipped.** With no
    App Group, `UserDefaults(suiteName:)` returns `nil` on one side and the
    widgets show `—` / "No data yet" forever, with no error anywhere.

## 6. Match build settings to Runner

19. **ThrottleIQWidget target → General → Minimum Deployments**: set **iOS 14.0**
    (WidgetKit's floor; Runner declares 13.0 but the Podfile already pins the
    platform to 14.0, so nothing regresses). Do **not** set it above 14.0
    unless you also raise Runner's.
20. **Build Settings → Swift Language Version**: `Swift 5`.
21. **Build Settings → Product Bundle Identifier**: confirm
    `com.bft.throttleiq.ThrottleIQWidget`. It must be a child of the Runner
    bundle ID.
22. Confirm the widget's `CFBundleShortVersionString` / `CFBundleVersion` are
    still `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` (they are, in the
    provided `Info.plist`). Hardcoded values that drift from Runner's are
    rejected at App Store upload.

## 7. Register the URL scheme

Already done — `CFBundleURLTypes` in `ios/Runner/Info.plist` now declares the
`throttleiq` scheme, appended alongside the existing Google Sign-In entry.
Nothing to do here; just don't remove it, or the Start Ride widget's
`widgetURL(URL(string: "throttleiq://startride"))` will open nothing.

23. To verify: **Runner target → Info → URL Types** should list an entry with
    identifier `com.bft.throttleiq` and scheme `throttleiq`.

## 8. Build and verify

24. Select the **Runner** scheme and a real device, then **Product → Run**.
    Launch the app once so it publishes widget data (the app calls
    `HomeWidgetService.bootstrap()` from `main()`).
25. Long-press the home screen → **+** → search **ThrottleIQ**. Three widgets
    should be offered: Start Ride (small), Ride Stats (medium), Maintenance
    (medium).
26. Add each. Before the app has published anything they must show `—` /
    "No data yet" / "No service data yet" — never a blank box. After a ride
    exists, Ride Stats shows real distances.
27. Tap the Start Ride widget: the app should open. (See "Not done" below for
    what it does *not* yet do.)

---

## Troubleshooting

**Widgets show placeholders forever.** Almost always the App Group (step 15/16).
Verify the identical string appears in both targets' entitlements and that the
group exists on the developer portal for the app ID.

**"Multiple commands produce …" or duplicate `@main`.** `ThrottleIQWidget.swift`
was added to the Runner target as well. Select the file → File Inspector →
Target Membership → untick **Runner**.

**Widget picker shows nothing.** The extension did not embed. Runner target →
Build Phases → **Embed Foundation Extensions** (older Xcode: "Embed App
Extensions") must list `ThrottleIQWidget.appex`.

**Archive fails on version mismatch.** Step 22 — the widget's version strings
must be the `$(FLUTTER_BUILD_*)` variables.

**`flutter build ios` stops working after this.** Nothing in this flow should
affect it; if it does, the fastest recovery is
`git checkout -- ios/Runner.xcodeproj/project.pbxproj` and starting over from
step 6.

---

## Data contract (do not drift)

`ThrottleIQWidget.swift` reads these keys from
`UserDefaults(suiteName: "group.com.bft.throttleiq")`. They are written by
`lib/core/services/home_widget_service.dart` and mirrored by
`android/app/src/main/kotlin/com/bft/throttleiq/WidgetKeys.kt`. All three must
change together — a mismatch does not fail any build, it just renders the
placeholder.

| Key | Type | Example |
| --- | --- | --- |
| `ti_weekly_km` | String | `128.4 km` |
| `ti_weekly_km_raw` | Double | `128.437` |
| `ti_total_km` | String | `12,480 km` |
| `ti_total_km_raw` | Double | `12480.2` |
| `ti_ride_count` | String | `42 rides` |
| `ti_ride_count_raw` | Int | `42` |
| `ti_bike_name` | String | `Yamaha MT-07 (2021)` |
| `ti_service_label` | String | `Oil Change` |
| `ti_service_summary` | String | `Oil Change overdue by 240.0 km` |
| `ti_km_until_due` | String | `240.0 km` |
| `ti_km_until_due_raw` | Double | `-240.0` |
| `ti_overdue` | Bool | `true` |

The widget `kind` strings must equal the `iOS*Widget` constants in
`HomeWidgetService`: `ThrottleIQStartRideWidget`, `ThrottleIQRideStatsWidget`,
`ThrottleIQMaintenanceWidget`.

## Not done

- **Tapping Start Ride only opens the app**; it does not jump straight into
  recording. Routing the `throttleiq://startride` URL requires a change to
  `lib/core/router/app_router.dart`, which was out of scope. The URL is
  already delivered on both platforms, so the remaining work is one deep-link
  handler on the Dart side.
- The widget extension target itself (this document).
