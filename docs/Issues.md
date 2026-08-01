# Issues

_Last updated: 2026-08-01_

Tracked problems found during review/QA that aren't simple TODOs (those live
in `HANDOFF_Document.md`'s "To do" section). One `##` section per issue.

---

## 1. API leak — GitHub secret-scanning alert (Firebase Web API key)

**Status:** Resolved / false positive — recommendation given, not yet marked closed on GitHub.

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

### Can this API key be used to do anything harmful?

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

### Why this isn't a real leak

Firebase Web API keys are meant to be public — they identify the project
when making client-side calls, they don't grant privileged access on
their own. The exact same key is already visible to anyone viewing the
page source of the live `https://throttleiqfb.web.app/live/...` page
(Firebase Hosting serves it client-side), so committing it to the repo
didn't newly expose anything. Firebase's own docs explicitly call this
key non-secret; the actual access control is the Firestore/Storage
Security Rules.

### Recommendation

- Don't rotate the key — that risks breaking the live app for no real
  security gain.
- Do check the key's API restrictions in Google Cloud Console to confirm
  it's scoped to Firebase/Identity services only.
- Close the GitHub secret-scanning alert once confirmed (mark as "used in
  tests" / "false positive" or revoked-as-appropriate per your review).

---

## 2. Maintenance page highlighted the wrong bottom-nav tab

**Status:** Fixed 2026-08-01 (commit `221bb57`).

Reported as: _"the maintenance page from garage, when selected, shows that
I'm on record page in bottom but opens the maintenance page correctly."_

**Root cause:** `AppShell._tabs` in `app/lib/shared/widgets/app_shell.dart`
listed only the five tab paths. `/home/maintenance` is a shell route but
not a tab, so `indexWhere` returned `-1` and the code fell through to a
hardcoded `2` — the Record tab. The screen itself was routed correctly all
along; only the highlight was wrong.

**Fix:** the location→tab mapping is now an explicit, pure
`shellTabIndexForLocation(String)`, with a `_nonTabShellRoutes` map sending
`/home/maintenance` to Garage (where it's reached from). Matching is
segment-aware, so a future `/home/recordings` can't steal the Record tab.
Covered by `app/test/shared/app_shell_test.dart`.

**Watch for:** any *new* `/home/*` shell route that isn't its own tab needs
an entry in `_nonTabShellRoutes`, or it will silently inherit the same
wrong-highlight behaviour. The Record fallback exists only to guarantee
`BottomNavigationBar` a valid index.

---

## 3. QA report

**Status:** Not started.

_No QA pass has been written up yet. When one is done (manual smoke test,
device walkthrough, or a scripted run), record findings here as dated
sub-sections — one per pass — rather than overwriting this placeholder._
