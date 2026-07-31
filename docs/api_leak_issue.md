# GitHub secret-scanning alert: Google API Key in `public/live-viewer.html`

GitHub's secret scanning flagged the Firebase Web API key in
`public/live-viewer.html` (introduced via commit `b3b149a`):

```
public/live-viewer.html
    const FALLBACK_CONFIG = {
      apiKey: "AIzaSyAP16m8JzeIisHX1Wb0ImLGAu7AAHM4b-I",
      authDomain: "throttleiqfb.firebaseapp.com",
      projectId: "throttleiqfb",
      storageBucket: "throttleiqfb.firebasestorage.app",
      ...
    };
```

## Can this API key be used to do anything harmful?

Realistically, not much beyond what the app already lets any visitor do —
but there are a couple of real, low-severity risks worth knowing about.

**What it can't do:**
- It can't bypass Firestore rules or Storage rules. Firestore is
  owner-gated per collection (rides, bikes, maintenance, etc., with the
  audience-based sharing logic), and Storage (`storage.rules`) is
  auth-gated with owner-only writes. The key alone doesn't grant a token;
  someone would still need a valid signed-in `request.auth.uid` to
  read/write anything, and even then they're bound by the same rules
  every real user is.
- It can't read other users' private data. Public rides, public profile
  fields, and forums are already meant to be visible to any authenticated
  user by design — that's not a new exposure.

**What it realistically enables:**
- Someone could hit the Firebase Auth REST API directly with this key to
  script things the app's UI already allows anyone to do — sign up fake
  accounts, or trigger password-reset/email-verification emails to
  arbitrary addresses. That's more of a spam/cost nuisance (email quota,
  "denial of wallet" on usage-based billing) than a data breach.
- If any *other* Google Cloud APIs (Maps, Places, etc.) are enabled and
  left unrestricted on this same key in Google Cloud Console, those could
  be quota-abused too. This is the one thing worth checking directly in
  the console (APIs & Services → Credentials → this key → "API
  restrictions") — it isn't visible from the repo.

## Why this isn't a real leak

Firebase Web API keys are meant to be public — they identify the project
when making client-side calls, they don't grant privileged access on
their own. The exact same key is already visible to anyone viewing the
page source of the live `https://throttleiqfb.web.app/live/...` page
(Firebase Hosting serves it client-side), so committing it to the repo
didn't newly expose anything. Firebase's own docs explicitly call this
key non-secret; the actual access control is the Firestore/Storage
Security Rules.

## Recommendation

- Don't rotate the key — that risks breaking the live app for no real
  security gain.
- Do check the key's API restrictions in Google Cloud Console to confirm
  it's scoped to Firebase/Identity services only.
- Close the GitHub secret-scanning alert once confirmed (mark as "used in
  tests" / "false positive" or revoked-as-appropriate per your review).
