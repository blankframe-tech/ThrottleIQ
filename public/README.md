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
