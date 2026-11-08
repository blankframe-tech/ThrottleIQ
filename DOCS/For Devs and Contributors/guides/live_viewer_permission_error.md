# Live viewer: "Failed to connect to session. Please check permissions."

Written 2026-11-03 from a debugging chat. Nothing was changed in code; the cause of the original report was never confirmed.

## Symptom

`https://throttleiqfb.web.app/live/<token>` shows "🏍️ Live Rider … Failed to connect to session. Please check permissions." Console: `Firestore error: FirebaseError: Missing or insufficient permissions.` (from `public/live-viewer.html:815-821`).

## What the message means

The `onSnapshot` error callback on `liveSessions/{token}` fired with `permission-denied`. The viewer shows the same generic text for every such denial, so a stale link looks like a permissions fault. A missing doc is different: it shows "Session not found or has expired."

## Causes, most likely first

1. **Link is stale or was never shared.** `firestore.rules` (`match /liveSessions/{token}`) allows `get` only if `shareable == true` and `expiresAt > request.time`. An expired (24h TTL) or non-shared session is denied, not "not found".
2. **The visitor's browser failed App Check.** Firestore App Check is enforced (since 2026-11-01). The viewer uses reCAPTCHA Enterprise (`ReCaptchaEnterpriseProvider`, min score 0.5). A VPN, ad-blocker, privacy extension or private window can drop the score and get every read rejected.
3. **Site-wide App Check misconfiguration** (reCAPTCHA key not allowing `throttleiqfb.web.app`, key not registered as the web app's provider). Would fail for everyone.
4. Rules not deployed, or the network blocking Firestore (less likely).

## How it was narrowed down

- The iPhone publishing a session works. That only proves the app side: the phone uses an App Check debug token, the web viewer uses reCAPTCHA, so it says nothing about the viewer.
- A friend opened a fresh shared link on a laptop and it worked. That rules out cause 3, so the failing link was stale/unshared (1) or the reporter's browser failed reCAPTCHA (2). Not confirmed which.

## How to diagnose next time

1. Open a fresh link (ride live, sharing on) in a clean Chrome profile, no VPN or ad-blocker. Works: the old link was stale. Fails: go on.
2. DevTools, Network: look for a failed `exchangeRecaptchaEnterpriseToken`. A 4xx means a key or domain config problem. If it succeeds, check the App Check metrics for the low score.
3. Quick unblock: Firebase console, App Check, APIs, Cloud Firestore, Unenforce (takes effect in minutes). Re-enforce after the fix. See `app_check.md`.

## Open improvement (not done)

Make the viewer's `permission-denied` branch say "This link has expired or isn't shared", and log whether the App Check token failed, so the generic text stops hiding the real reason.
