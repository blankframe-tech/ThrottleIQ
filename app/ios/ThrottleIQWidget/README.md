# ThrottleIQ iOS Widget Extension — setup

**The target is registered in `Runner.xcodeproj` and builds automatically as
part of `flutter build ios`.** This used to be a manual Xcode step (hand-editing
`project.pbxproj` was judged too risky to automate — see the note that used to
be here); it was done programmatically instead, with the `xcodeproj` Ruby gem
driving the same target/build-phase/entitlements structure Xcode's own "New
Target" flow would have produced, then verified with `flutter build ios
--simulator` and by confirming `pluginkit -m -p com.apple.widgetkit-extension`
lists `com.bft.throttleiq.ThrottleIQWidget` on the built simulator app.

What's already done, so you don't need to:
- The `ThrottleIQWidget` target exists, with the four widgets in
  `ThrottleIQWidget.swift` (Start Ride, Start Auto-Tracking, Ride Stats,
  Maintenance) as its `WidgetBundle`.
- `ios/Flutter/Widget.xcconfig` feeds it `FLUTTER_BUILD_NAME`/
  `FLUTTER_BUILD_NUMBER` (via `Generated.xcconfig`) without pulling in
  CocoaPods — the widget links no pods, only `WidgetKit`/`SwiftUI`.
- `INFOPLIST_FILE`, `GENERATE_INFOPLIST_FILE=NO`, bundle id
  (`com.bft.throttleiq.ThrottleIQWidget`), deployment target (iOS 14.0), and
  `CODE_SIGN_ENTITLEMENTS` are all set on the target.
- Runner embeds the extension via an "Embed Foundation Extensions" copy-files
  phase, positioned **before** Flutter's "Thin Binary" and "[CP] Embed Pods
  Frameworks" script phases — appending it after those (Xcode's own template
  order for a plain app) produces a build-graph cycle when combined with
  Flutter's script phases specifically. If you ever regenerate this target
  from scratch in Xcode, move that phase manually if the build reports
  "Cycle inside Runner".
- Both `Runner/Runner.entitlements` and
  `ThrottleIQWidget/ThrottleIQWidget.entitlements` declare the App Group
  `group.com.bft.throttleiq`, and `Runner`'s build settings point at its
  entitlements file.

## What's NOT done — needs your Apple Developer account

Nobody but the account owner can do this part; it needs credentials this
automation doesn't have.

1. Open `Runner.xcworkspace` (not the `.xcodeproj`) in Xcode.
2. Select the **Runner** target → **Signing & Capabilities** → pick your
   **Team**. Repeat for the **ThrottleIQWidget** target.
3. With Automatic signing and a team selected, Xcode creates the
   `group.com.bft.throttleiq` App Group and its provisioning profiles for
   you — this is the "step 5 creates the group for you" shortcut. If you
   manage profiles by hand instead, register the App Group at
   <https://developer.apple.com/account/resources/identifiers/list/applicationGroup>
   and enable it on the `com.bft.throttleiq` App ID first.
4. Confirm both targets show a checked `group.com.bft.throttleiq` under App
   Groups and no red signing errors.

**Without a team, the app groups is a not-yet-functional passenger:** it
built and installed fine on the simulator in this session with entitlements
resolving to an empty `<dict/>` at the codesign layer (Xcode disallows
custom entitlements for a team-less "Sign to Run Locally" identity on iOS,
even on the simulator) — confirmed via
`codesign -d --entitlements :- build/ios/iphonesimulator/Runner.app`. The
widgets will render (`pluginkit` sees them) but will keep showing their
placeholder text until a real team is assigned and the App Group actually
takes effect.

## Verify on a device or simulator with your team assigned

1. Run the **Runner** scheme. Launch once so it publishes widget data (the
   app calls `HomeWidgetService.bootstrap()` from `main()`).
2. Long-press the home screen → **+** → search **ThrottleIQ**. Four widgets
   should be offered: Start Ride (small), Start Auto-Tracking (small), Ride
   Stats (medium), Maintenance (medium).
3. Add each. Before the app has published anything they must show `—` /
   "No data yet" / "No service data yet" — never a blank box. After a ride
   exists, Ride Stats shows real distances.
4. Tap Start Ride: the app opens on the Record screen. Tap Start
   Auto-Tracking: the app opens on Settings, where the auto-tracking switch
   lives — see `HomeWidgetService.registerAutoTrackingHandler` for why that
   widget doesn't flip the switch itself.

---

## Troubleshooting

**Widgets show placeholders forever.** Almost always the App Group step
above. Verify the identical string appears in both targets' entitlements and
that the group exists on the developer portal for the app ID.

**"Cycle inside Runner; building could produce unreliable results."** The
"Embed Foundation Extensions" copy-files phase is running after Flutter's
"Thin Binary" script phase. Move it to right after "Embed Frameworks" in
Runner's Build Phases list (see "What's already done" above).

**"Multiple commands produce …" or duplicate `@main`.** `ThrottleIQWidget.swift`
was added to the Runner target as well as ThrottleIQWidget's. Select the file
→ File Inspector → Target Membership → untick **Runner**.

**Widget picker shows nothing.** The extension did not embed. Runner target →
Build Phases → **Embed Foundation Extensions** must list
`ThrottleIQWidget.appex`.

**Archive fails on version mismatch.** The widget's version strings must stay
the `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)` variables — don't
hardcode them in `Info.plist`.

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
`HomeWidgetService`: `ThrottleIQStartRideWidget`,
`ThrottleIQAutoTrackingWidget`, `ThrottleIQRideStatsWidget`,
`ThrottleIQMaintenanceWidget`.

## Not done

- **Tapping Start Ride only opens the app** (lands on the Record screen); it
  does not start recording by itself — the rider still uses slide-to-start.
  Deliberate: see the comment on `HomeWidgetService.registerStartRideHandler`
  in `app.dart`. Start Auto-Tracking follows the same rule, for a sharper
  reason — enabling it can require a location-permission prompt and can fail,
  neither of which has anywhere to surface from a bare widget tap, so it
  opens Settings instead of trying to flip the switch itself.
- The Apple Developer account steps above (team assignment, App Group
  registration/verification).
