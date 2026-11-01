# Public Directory

Static assets served by Firebase Hosting for project `throttleiqfb`
(`firebase.json` → `hosting.public: "public"`). Deploy with:

```bash
firebase deploy --only hosting
```

## Files

- `live-viewer.html` — the live-ride viewer. Hosting rewrites `/live/**` to it
  (see `firebase.json`); the last path segment is the session token, which it
  looks up in the `liveSessions` Firestore collection.
- `privacy.html` — **the** privacy policy, published at
  <https://throttleiqfb.web.app/privacy.html>. This URL is what goes into Play
  Console → App content → Privacy policy, and Play will not publish the app
  without it because of `ACCESS_BACKGROUND_LOCATION`. Edit this file, not a copy.
- `privacy-policy.html` — the old policy path, now a redirect to `/privacy.html`
  so previously handed-out links keep working. No policy text lives here.
- `follow.html` — fallback for follow links (the "My QR code" in the app).
  Rewritten from `/u/**`, `/ThrottleIQ/u/**` and `/throttleiq/u/**`. Tries to
  open the app (`intent://` on Android, `throttleiq://u/<uid>` button
  elsewhere), otherwise links to the install page. URL rules mirror
  `app/lib/features/social/domain/utilities/follow_link.dart`.
- `well-known/assetlinks.json` and `well-known/apple-app-site-association.json`
  — served at `/.well-known/assetlinks.json` and
  `/.well-known/apple-app-site-association` by rewrites (Hosting's `**/.*`
  ignore would skip a real `.well-known/` folder). assetlinks carries the
  upload keystore's SHA-256 (`4A:7B:…`) and Play's app-signing SHA-256
  (`CF:1E:…`, issues_fixed §113); if Play's signing key ever changes, update
  both copies (here and the landing-page repo). AASA names Team ID `NJ4675FFUX`.
  Firebase Hosting does not serve this file: `throttleiqfb.web.app` answers
  `/.well-known/assetlinks.json` itself with `[]` (`cache-control: private,
  no-store`, checked 2026-11-01), so the `throttleiqfb.web.app` App Links host
  can't verify from here.
  The canonical follow link is on `blankframe.tech`, so these two files and
  the `/ThrottleIQ/u/*` page must also be served from **blankframe.tech**
  (same files, or proxy that path to this Hosting site).
