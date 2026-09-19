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
- `ACTIVITY_RECOGNITION` (both the Android and the GMS variant): auto ride detection
- `RECORD_AUDIO`: group-ride push-to-talk voice clips (`record` package). **Must be declared on the form. See "Audio" below.**
- `USE_FULL_SCREEN_INTENT`: the crash-countdown alert over the lock screen (`NotificationService.showCrashAlert`). Since Android 14, Play only auto-grants this to calling/alarm apps, so expect a Play Console declaration for it (issues_open.md §69.O8)
- `AD_ID` is explicitly **removed** (`tools:node="remove"` in the manifest), so answer "No" to advertising ID
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

### Audio
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Voice or sound recordings | Yes | Yes (with the other members of that group ride) | App functionality (group-ride push-to-talk) |

Source: `GroupRideRepository.sendVoiceNote` uploads the clip (max 60 s,
min 0.8 s, enforced in `firestore.rules`) to Cloudinary and stores its URL
in `groupRides/{id}/voiceNotes`, readable by the ride's creator, members and
invitees. The Cloudinary URL itself is public to anyone who has it. Until
2026-09-19, `public/privacy.html` said "no microphone" (issues_open.md §69.O1),
which contradicted this. It's corrected now; deploy hosting before
submitting the form.

### App activity
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Other user-generated content (forum posts, replies, comments, ride captions, place reviews) | Yes | Yes | App functionality (community features) |

### Messages
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Other in-app messages | Yes | No | App functionality (one-to-one direct messages between riders) |

Source: `app/lib/features/chat/` — real, live one-to-one chat, message text
stored in Firestore (`firestore.rules`' `/chats/{chatId}/messages`, readable
only by the two participants). Mark "Shared: No" — unlike forum posts,
these are never publicly readable. Added 2026-09-05 alongside the matching
`public/privacy.html` update (that page had the same gap — see
`DOCS/Handoff for agents and Todos/issues_fixed.md` §59); this is the second of the two places that
page's own consistency rule (above) requires updating together.

Note: **do not** declare "App interactions" for analytics. `app/pubspec.yaml` still has no `firebase_analytics` and no third-party behavioural-analytics SDK — nothing in the app tracks usage/interactions, and claiming otherwise on the form contradicts `public/privacy.html`. `firebase_crashlytics` **was** added (see issues_fixed.md §38) — that's diagnostics, declared separately below, not "App activity."

### App info and performance (Diagnostics)
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Crash logs | Yes | No | Analytics (Firebase Crashlytics — app stability/crash monitoring) |

Source: `app/lib/main.dart` wires `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and a `runZonedGuarded` handler to `FirebaseCrashlytics.instance`, gated off in debug builds (`setCrashlyticsCollectionEnabled(!kDebugMode)`) so only real installs report. Update `public/privacy.html` to mention crash diagnostics if it doesn't already, so this stays consistent with the form.

### Device or other IDs
| Type | Collected? | Shared? | Purpose |
|---|---|---|---|
| Device or other IDs | Yes | No | App functionality (Firebase installation ID, created by the Firebase SDKs) |

Note: `firebase_messaging` was declared in `pubspec.yaml` but nothing in `app/lib/` ever called it — removed 2026-09-19 (issues_fixed.md §69.O7) rather than left as dead weight. No FCM registration token is requested or stored today. Do not describe push tokens as collected unless the dependency is added back and actually wired up.

### Is all user data encrypted in transit?
**Yes** (Firebase/Cloudinary use HTTPS/TLS)

### Do you provide a way for users to request data deletion?
**Yes, and in-app.** Settings → **Delete Account** (`AuthNotifier.deleteAccount()`)
deletes the Firebase Auth user first, then wipes local SQLite. Cloud cleanup
runs server-side in the `onUserAccountDeleted` Cloud Function
(`functions/src/account-deletion.ts`), which recursively deletes
`users/{uid}` and its subcollections plus the rider's shared rides, live
sessions, crash notifications, follow edges and username claim.
**That function has never been deployed** (issues_fixed.md §69.8). Until
`firebase deploy --only functions` runs, an in-app deletion leaves the cloud
records orphaned, and the form must not claim otherwise. Cloudinary assets
and content posted in other people's spaces are still handled by the email
route in §9 of `https://throttleiqfb.web.app/privacy.html` (issues_open.md §69.O2).
Give that URL as the web deletion link, since Play requires one even when
deletion is in-app.

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
