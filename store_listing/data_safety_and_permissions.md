# Play Console — Data Safety form & background location declaration

Based on the actual permissions in `app/android/app/src/main/AndroidManifest.xml` and the data flows in the codebase (Firebase + Cloudinary). Fill these into Play Console → App content.

## Privacy policy URL (App content → Privacy policy)

```
https://throttleiqfb.web.app/privacy.html
```

Source: `public/privacy.html`, deployed with `firebase deploy --only hosting`. Must be live and anonymously reachable **before** submitting — a background-location app is rejected without it. The answers below must stay consistent with what that page says; if you change one, change the other.

## Permissions actually declared in the manifest
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
- `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`
- `INTERNET`, `ACCESS_NETWORK_STATE`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- No `READ_CONTACTS`, `CAMERA`, or `SMS` permission — the app uses `image_picker` (system photo picker, no runtime permission needed on modern Android) and emergency contacts are typed in manually, not read from the phone's contact list.

## Data Safety form — suggested answers

### Does your app collect or share any of the required user data types?
**Yes**

### Location
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Precise location | Yes | Yes* | App functionality (ride recording, crash detection, nearby places) |

\* Mark "Shared" — a live-share link exposes real-time location to whoever holds the link, and a shared/public ride can expose the route to other users. If you're not comfortable calling that "shared" in the Play sense, an alternative is to restrict this answer to "collected, not shared" only if you remove/disable the live-share and public-feed features before launch — but as shipped today, mark it shared.

### Personal info
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Name | Yes | Yes (if you use social/profile features) | Account management, social features |
| Email address | Yes | No | Account management |

### Photos or videos
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Photos | Yes | Yes (if attached to a shared ride/review) | App functionality |

### App activity
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Other user-generated content (forum posts, replies, comments, ride captions, place reviews) | Yes | Yes | App functionality (community features) |

Note: **do not** declare "App interactions" for analytics. `app/pubspec.yaml` still has no `firebase_analytics` and no third-party behavioural-analytics SDK — nothing in the app tracks usage/interactions, and claiming otherwise on the form contradicts `public/privacy.html`. `firebase_crashlytics` **was** added (see Issues.md §38) — that's diagnostics, declared separately below, not "App activity."

### App info and performance (Diagnostics)
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Crash logs | Yes | No | Analytics (Firebase Crashlytics — app stability/crash monitoring) |

Source: `app/lib/main.dart` wires `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and a `runZonedGuarded` handler to `FirebaseCrashlytics.instance`, gated off in debug builds (`setCrashlyticsCollectionEnabled(!kDebugMode)`) so only real installs report. Update `public/privacy.html` to mention crash diagnostics if it doesn't already, so this stays consistent with the form.

### Device or other IDs
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Device or other IDs | Yes | No | App functionality (Firebase installation ID, created by the Firebase SDKs) |

Note: `firebase_messaging` is declared in `pubspec.yaml` but nothing in `app/lib/` calls it — no FCM registration token is requested or stored today. Do not describe push tokens as collected until that is actually wired up.

### Is all user data encrypted in transit?
**Yes** (Firebase/Cloudinary use HTTPS/TLS)

### Do you provide a way for users to request data deletion?
**Yes** — there is no in-app delete-account flow yet (confirmed: nothing in `app/lib/` calls `User.delete()` or deletes a user's Firestore tree). Answer "Users can request that their data be deleted" and give the deletion URL as `https://throttleiqfb.web.app/privacy.html` — §9 of that page is the documented request route (email `the.abraar.rar@gmail.com` from the signup address). Switch this to "account deletion in-app" once the flow ships.

### Security practices
- Data is encrypted in transit: Yes
- Users can request data deletion: Yes
- Independent security review: No (unless you've had one)

---

## Background location — required extra steps

`ACCESS_BACKGROUND_LOCATION` is a **restricted permission**. Google requires, in addition to the Data Safety form:

1. **Prominent in-app disclosure** shown *before* requesting the permission, explaining what the app does with background location and that it happens even when the app isn't in use. (Worth double-checking this exists in the app's location-permission flow — Play reviewers check for it specifically.)
2. **Permissions Declaration form** in Play Console (appears under App content once a background-location-using APK/AAB is detected): you'll need to explain, in your own words, why the app needs background location. Suggested answer:

> "Throttle IQ records motorcycle rides — GPS route, speed, and distance — which continue for the length of a ride even if the rider's screen locks or they switch to another app (e.g. a maps app) mid-ride. Background location access is required so ride recording and crash detection don't stop the moment the screen turns off, which is the normal riding condition on a motorcycle."

3. A **short video or screenshots** may be requested showing the background-location feature in use — have a short screen recording of a ride being recorded with the screen locked/backgrounded ready, in case Play asks for it during review.

---

## Content rating questionnaire — heads up

The app includes user-generated content (forums, ride sharing, reviews) and location sharing between users, which typically pushes content ratings up from "Everyone." Answer the IDARC questionnaire honestly based on the actual social/UGC features; don't rely on this doc for exact answers since it changes by region — just know to expect a rating above the lowest tier because of UGC + location-sharing, not because of anything alarming in the app itself.
