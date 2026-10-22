> DRAFT for owner review, 2026-10-22

# Play reviewer video script: Background Location and Full-Screen Intent (PM item 3)

Companion to `data_safety_and_permissions.md` ("Background location: required extra steps"). Checked against the code on 2026-10-22 (build `1.0.0-beta.4.7.1+29`).

## 1. What the code does (facts the video must match)

### Background location (`ACCESS_BACKGROUND_LOCATION`, `AndroidManifest.xml:7`)

- **One feature asks for it:** Settings → **"Detect rides automatically"** (`autoTrackingTileTitle`), off by default. Subtitle: "Logs a ride without you tapping start. Uses about 3–5% battery a day when you are not riding." (`autoTrackingTileSubtitle`)
- **Prominent disclosure** before any request: `ensureBackgroundLocationDisclosure` in `app/lib/features/ride/presentation/widgets/recording_gate.dart`, called from `auto_tracking_tile.dart:134`. Dialog, not dismissible by tapping outside:
  - Title (`backgroundLocation`): "Background location"
  - Body (`backgroundLocationRationale`): "With "Detect rides automatically" on, ThrottleIQ collects your location to detect and record your rides, even when the app is closed or not in use. It watches for motion first and turns GPS on only once you are moving in a vehicle. The next screen asks for "Allow all the time" location access. You can turn this off at any time in Settings."
  - Buttons: "Not now" (`notNow`, makes no request) and "Continue" (`continueLabel`).
  - Shown until accepted once; skipped if "Allow all the time" is already granted. **To film it, use a fresh install or clear the app's data.**
- **Request order after "Continue"** (`AutoTrackingNotifier.enable` in `auto_tracking_provider.dart`, then `AutoTrackingService.start`):
  1. While-in-use location, if not granted yet.
  2. "Allow all the time" (on Android 11+ the system opens the app's location settings page).
  3. Notification permission (Android 13+).
  4. **Full-screen intent settings page** (Android 14+, `requestFullScreenIntentPermission` inside `NotificationService.requestPermissions`).
  5. Physical activity (activity recognition).
  6. Battery-optimisation exemption dialog.
  7. Foreground service starts with the notification "ThrottleIQ / Watching for rides" (`auto_tracking_service.dart:594-595`; hard-coded English).
- Refusing "Allow all the time" shows: "ThrottleIQ needs "Always" location access to detect rides while the app is closed. You can change this in Settings." (`autoTrackingAlwaysPermissionRequiredMessage`) and the switch stays off.
- **What a detected trip becomes:** not a saved ride. Trips merge into a **daily ride summary**, shown as a "Today" row (`autoSummaryTodayTitle`) and in "Daily ride summaries" (`dailySummariesTitle`, last 14 days), plus an evening notification "Today on the road" / "Tap to see your day." (`notifDigestTitle`, `notifDigestTap`, after 9 pm). Distance not covered by a recorded ride adds to the active bike's odometer, which drives maintenance reminders (`features.md` §2).
- **Manual rides do not use background location:** Record tab → hold-to-start ring (900 ms) → while-in-use permission only. While recording, a foreground service notification shows "Ride Recording Active" / "ThrottleIQ is recording your ride in the background" (`rideRecordingActive`, `recordingNotificationTextUser`).

### Full-Screen Intent (`USE_FULL_SCREEN_INTENT`, `AndroidManifest.xml:57`)

- **Only one code path uses it:** `NotificationService.showCrashAlert` (`notification_service.dart:185-215`): a crash countdown over the lock screen with an "I'm OK" action.
- **That path is switched off in every build.** `showCrashAlert` returns at once while `SensorConstants.crashAlertsEnabled` is `false` (`sensor_constants.dart:70`, a compile-time constant). Crash detection runs in shadow mode and alerts no one (`features.md`, "Shadow-mode crash detection").
- **No in-app disclosure exists for it.** Yet the app still **asks** for it: `requestFullScreenIntentPermission()` runs every time `NotificationService.requestPermissions()` runs, which is when auto-tracking is turned on and at the end of maintenance setup (`maintenance_setup_screen.dart:92`). On Android 14+ that opens a system settings page with no explanation.

### Consequence for the video

- Background location: fully demonstrable with the release build.
- Full-screen intent: **cannot be demonstrated honestly with the build being submitted.** Filming a debug build with the flag turned on would show behaviour the submitted app does not have.
- issues §109.13 already names the fallback: drop `USE_FULL_SCREEN_INTENT` (only crash alerts use it, and they are off). needs_attention.md records the owner's 2026-10-21 decision to keep both declarations. **Recommend the owner revisit that decision for the full-screen intent** before recording. [OWNER DECISION]

## 2. Before recording

- Device: a physical Android phone on Android 14 or later (so the full-screen intent page appears, if kept). [PLACEHOLDER: device model]
- Build: the exact AAB/APK submitted, installed from the Play internal track. [PLACEHOLDER: version code]
- Account: an ordinary rider account, not the admin account (`app_content_remaining.md`). [PLACEHOLDER: reviewer account]
- App data cleared, so the disclosure and every system prompt appear.
- Settings → Your ThrottleIQ → **Ride tracking** must be on, or auto-tracking is refused.
- A bike added in Garage (so detected distance has a bike to credit).
- Screen recording on (Android's built-in recorder), touches shown (Developer options → Show taps).
- The riding part is filmed by a passenger or with the phone mounted; the rider never handles the phone while moving.
- English UI (Settings → Language → English).

## 3. Shot list: Background location

**Length target:** 60-90 seconds. One continuous take per segment; cut between segments only.

| # | On screen (real UI) | Caption / voice-over (EN) | Approx. |
|---|---|---|---|
| 1 | App opens on the Record tab | "ThrottleIQ records motorcycle rides. This video shows the one optional feature that uses background location." | 5 s |
| 2 | Garage tab → gear icon → Settings. Scroll to "Detect rides automatically", switch off | "The feature is called Detect rides automatically. It is off by default." | 8 s |
| 3 | Tap the switch. The "Background location" dialog appears. Hold 3 s so the text is readable | "Before any permission request, the app explains what it collects, why, and that it runs when the app is closed." | 8 s |
| 4 | Tap "Continue". System while-in-use prompt → "While using the app" | "The rider continues. Android first asks for location while in use." | 6 s |
| 5 | System settings page for location → select "Allow all the time" → back | "Then Android asks for Allow all the time. This is needed because the feature detects rides while the app is closed." | 8 s |
| 6 | Notification permission → Allow. [If FSI kept: full-screen notifications page appears → see section 4.] Physical activity → Allow. Battery optimisation → Allow | "The app also asks for notifications, physical activity to detect vehicle motion, and to be exempt from battery optimisation." | 10 s |
| 7 | Back in Settings: switch on, Active hours row visible. Pull down the notification shade: "ThrottleIQ / Watching for rides" | "While the feature is on, a notification is always visible." | 6 s |
| 8 | Swipe the app away from Recents. Home screen | "The app is now closed." | 4 s |
| 9 | Short clip of riding (phone mounted, screen off or home screen). [VERIFY ON DEVICE: whether the notification text changes during a detected trip] | "The phone notices vehicle motion and only then turns on GPS." | 8 s |
| 10 | After the ride: open the app → Settings → "Today" row / "Daily ride summaries" showing the trip's km | "The detected trip appears in the daily ride summary, and its distance is added to the bike's odometer for service reminders." | 8 s |
| 11 | Settings → switch "Detect rides automatically" off. Notification disappears | "The rider can turn it off at any time." | 5 s |
| 12 | Record tab → hold the start ring. Only a while-in-use prompt ever appears (show on a second fresh install, or state it) | "Rides started by hand use a foreground service with while-in-use location, and never ask for background location." | 8 s |

## 4. Full-Screen Intent segment

Pick one option after the owner decision in section 1.

**Option A (recommended): remove the permission.** Drop `USE_FULL_SCREEN_INTENT` from the manifest and the `requestFullScreenIntentPermission()` call (issues §109.13). No video or declaration needed. Re-add both when crash alerts ship, with an in-app explanation before the request. (Code change; not part of this draft.)

**Option B: keep it and declare.** What can honestly be filmed with the release build:

| # | On screen | Caption (EN) | Approx. |
|---|---|---|---|
| B1 | During step 6 above, the system "Full-screen notifications" page for ThrottleIQ | "The app asks to show full-screen notifications. It is reserved for one safety feature: a crash countdown the rider can cancel from the lock screen." | 8 s |
| B2 | Settings → Privacy & Safety, or a title card | "That crash alert is still being tested and is switched off in this version. Today the app shows no full-screen notifications." | 6 s |

Risk with Option B: Play allows this permission for apps whose core function needs it (calling and alarm apps are the standard case), and a video that shows the feature switched off may not justify it. A video showing a debug build with the alert switched on would misrepresent the submitted app; do not do that. [OWNER DECISION]

## 5. Play Console declaration text

### Background location (Permissions declaration form)

Replaces the suggested answer in `data_safety_and_permissions.md`, which says the feature "records the ride"; in the code, detected trips go to a daily summary, not saved rides.

> ThrottleIQ has one optional feature that uses background location: "Detect rides automatically". It is off by default and is turned on in Settings, after an in-app disclosure that explains the data collected and why. With it on, the app uses Android activity recognition to notice when the rider is moving in a vehicle and only then turns on GPS, including while the app is closed. Detected trips are kept on the phone and summarised into a daily ride summary, and their distance updates the bike's odometer so distance-based service reminders stay accurate. A persistent "Watching for rides" notification is shown while the feature is on. Rides the rider starts by hand use a foreground service with while-in-use location and do not request background location. The rider can turn the feature off at any time in Settings.

Video link: [PLACEHOLDER: unlisted video URL; check the format Play Console asks for]

### Full-screen intent (only if Option B)

> ThrottleIQ requests full-screen intent for a single safety feature: after a likely motorcycle crash, a countdown notification appears over the lock screen so the rider can tell the app "I'm OK" without unlocking the phone. This crash alert is currently switched off while detection is tested on real roads, so the app shows no full-screen notifications in this version. [OWNER DECISION: Play may not accept a declaration for a feature that is switched off; see section 4.]

## 6. Mismatches found

1. Full-screen intent is requested (auto-tracking enable and maintenance setup) though no live feature uses it, and no in-app disclosure precedes it.
2. `data_safety_and_permissions.md` video plan ends with "the detected ride appearing afterwards" and its declaration says the feature "records the ride". Detected trips are not saved as rides; they appear in the daily summary.
3. The disclosure copy (`backgroundLocationRationale`) says "detect and record your rides", which slightly overstates for the same reason. Consider "detect your rides and add them to your daily summary". (Copy change in `app_en.arb` and `app_bn.arb`; not made here.)
4. The "Watching for rides" notification text is hard-coded English, so a Bangla-UI rider sees English.
5. The store listing (`store_listing.md`) says "Records automatically in the background, even with the screen locked" under Ride recording. Background recording of manual rides is real (foreground service), but a reviewer may read "automatically" as auto-detection. Keep the declaration wording above consistent with it.

## 7. Placeholders

- [PLACEHOLDER: device model and Android version]
- [PLACEHOLDER: version code of the submitted build]
- [PLACEHOLDER: reviewer test account]
- [PLACEHOLDER: video URL]
- [OWNER DECISION: full-screen intent, Option A or B]
- [VERIFY ON DEVICE: notification text during a detected trip; exact wording of each system prompt on the chosen phone]
