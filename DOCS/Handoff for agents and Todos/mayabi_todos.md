# Maya Ride (branch `mayabi`): todos

Owner-side work for the Maya Ride integration. This branch is never merged into `main`. Details: the `mayabi` section of `HANDOFF_Document.md`. Maya's developers start at `mayabi/README.md`.

## How Maya's data syncs with ours

This part stays with us. It's the partner API in our Cloud Functions (`functions/src/partner-api/`), reached at `throttleiqfb.web.app/api/partner/`. Maya's app calls it with an API key we issue.

- **After every trip:** the app uploads speed per road segment plus the ride totals. No GPS track leaves the phone. Those speeds go into the same Dhaka road-speed pool our ThrottleIQ riders feed (`roadSpeedSamples`), tagged as Maya's (`source: maya`).
- **Scoring:** the server scores each ride against how Dhaka riders usually ride each segment at that time of day and in that weather. The scoring and the pooled data stay on our server, which is why handing over the phone code doesn't give away the model.
- **Also on the API:** each rider's running score, deleting a rider's data, live-share links, and alerts that turn the rider's live link red and notify Maya's ops server.
- **Privacy:** Maya's rider IDs are stored only as a hash, never raw.

## To go live (in order)

- [ ] **1. Switch Firebase to the paid (Blaze) plan.** Cloud Functions and the outbound webhook need it.
- [ ] **2. Deploy from the `mayabi` checkout:** `cd functions && npm run build && firebase deploy --only functions:partnerApi,functions:onRoadSpeedSampleCreated,hosting`
- [ ] **3. Count the existing samples, once, in a quiet hour:** `node scripts/rebuild-road-segment-stats.js --project=throttleiqfb` (dry run), then again with `--yes-i-really-mean-it`. Run from `functions/` with `GOOGLE_APPLICATION_CREDENTIALS` set.
- [ ] **4. Issue Maya's key and webhook secret:** `node scripts/create-partner.js --project=throttleiqfb --id=maya --name="Maya Ride" --webhook=<Maya's https URL> --yes-i-really-mean-it`. Send both to Maya privately; they're shown once and not stored.

## Before riders use it

- [ ] Test on real Android and iOS phones: sensor rates, recording with the screen locked, battery use at 50 Hz, and the iOS SMS link to two or more contacts.
- [ ] Have a native speaker review the Bangla text (`mayabi/README.md` §6, `mayabi/PRIVACY.md`).
- [ ] Agree with Maya where the API key lives. Their server is safer; a key inside the app can be extracted. Rotate it if a build leaks.
- [ ] Add a per-key rate limit before a second partner or a key inside a public build (`shortcut:` in `functions/src/partner-api/index.ts`).
- [ ] Check API latency from Dhaka (the function runs in us-central1).
- [ ] Tune the score weights once real Maya rides come in (`scoring.ts`; bump `SCORING_VERSION`).
- [ ] Contract: anonymised road-speed data from Maya's rides joins our pool and stays; Maya can erase rider-linked data; the key can be revoked if Maya stops paying.
