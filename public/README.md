# Public Directory

Static assets served by Firebase Hosting for project `throttleiqfb`
(`firebase.json` → `hosting.public: "public"`). Deploy only from a pushed
commit on `main`, with:

```bash
bash scripts/deploy_hosting.sh
```

It refuses to run if `public/` or `firebase.json` has uncommitted changes, or
if HEAD is not on `origin/main`, so the live pages always match the repo.
Pushing `main` does not deploy Hosting.

The bare root `/` redirects (302) to `/install`.

## Files

- `live-viewer.html` — the live-ride viewer. Hosting rewrites `/live/**` and
  `/r/**` to it (see `firebase.json`); the last path segment is the session
  token (or the rider's handle), which it looks up in Firestore. Its script is
  `live-viewer.js` (plus the pure helpers in `live-viewer-core.js`).
  - These paths get their own Content-Security-Policy in `firebase.json`: no
    inline scripts or `on*=` handlers, scripts only from this site, gstatic,
    unpkg and reCAPTCHA (App Check), connections only to Firebase. Keep page
    logic in `live-viewer.js`. A new CDN or API host must be added to that
    policy, or the browser blocks it.
  - Every CDN `<script>`/`<link>` carries `integrity` (SRI) and
    `crossorigin="anonymous"`. When you bump a version, recompute the hash:
    `curl -s <url> | openssl dgst -sha384 -binary | openssl base64 -A`.
  - The Hosting emulator sends the same CSP, so the `?emulator=1` mode (which
    talks to `127.0.0.1`) only works when `public/` is served some other way.
- `privacy.html` — **the** privacy policy, published at
  <https://throttleiqfb.web.app/privacy.html>. This URL is what goes into Play
  Console → App content → Privacy policy, and Play will not publish the app
  without it because of `ACCESS_BACKGROUND_LOCATION`. Edit this file, not a copy.
- `privacy-policy.html` — the old policy path, now a redirect to `/privacy.html`
  so previously handed-out links keep working. No policy text lives here.
- `follow.html` — fallback for follow links (the "My QR code" in the app).
  Rewritten from `/u/**`, `/ThrottleIQ/u/**` and `/throttleiq/u/**`. Offers an
  "Open in ThrottleIQ" button (`intent://` on Android, `throttleiq://u/<uid>`
  elsewhere) and an install link. It never opens the app by itself, and the
  app asks "Follow <name>?" before following. URL rules mirror
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
