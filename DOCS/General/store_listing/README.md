# Store_listing Directory

Everything needed to fill in the Google Play Console listing for **Throttle IQ**
(`com.bft.throttleiq`).

## Privacy policy URL — required by Play

Play Console → App content → **Privacy policy**:

```
https://throttleiqfb.web.app/privacy.html
```

This URL is **mandatory** for this app, not optional: the app declares
`ACCESS_BACKGROUND_LOCATION`, which is a restricted permission, and Play blocks
the listing without a reachable, public privacy policy that specifically
explains the background-location use.

The page's source of truth is **`public/privacy.html`** at the repo root — it is
served by Firebase Hosting (`firebase.json` → `hosting.public: "public"`, project
`throttleiqfb`). Publish or update it with:

```bash
firebase deploy --only hosting
```

Verify it loads publicly (no sign-in, no redirect chain) before pasting the URL
into Play Console — Play's reviewers fetch it anonymously.

`public/privacy-policy.html` is the old path, kept only as a redirect to
`/privacy.html` so any link already handed out still resolves. Do not paste the
old path into Play Console.

> There used to be a duplicate `store_listing/privacy-policy.html` here. It has
> been removed: it had drifted (different publisher name and contact address
> than the app actually uses) and having two policy files invited uploading the
> wrong one. Edit `public/privacy.html` only.

## Files

- `store_listing.md` — app name, short/full description, category, tags.
- `data_safety_and_permissions.md` — Data Safety form answers and the
  background-location declaration.
- `throttleiq_playstore_icon_512.png` — 512×512 store icon.
- `throttleiq_feature_graphic_1024x500.png` — 1024×500 feature graphic.
