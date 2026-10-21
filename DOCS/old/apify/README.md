# Apify scrapes: data and lessons

Every Apify run on account `the-abraar`, as of 2026-10-21. Each folder holds the run's `input.json` and its full dataset as `items.json`. **The data folders are gitignored** (they hold Facebook users' names and posts and Google Maps content). Only this README is tracked. Google Drive still syncs the folder.

Token: `~/.secrets/throttleiq/apify_token` (chmod 600). Never paste it into chat or commit it.

## Runs

| Folder | Actor | Items | Cost | What came of it |
|---|---|---|---|---|
| `2026-10-19_gmaps-dhaka-places` | `compass/crawler-google-places` | 897 | $3.59 | `scripts/oneoff/import_google_places.js` added 717 places and enriched 80 in production (issues_open §105.1) |
| `2026-10-19_fb-group-search-datahamster` | `datahamster/facebook-groups-search` | 4 | $0.03 | Found the two public traffic groups; nothing for bike maintenance |
| `2026-10-19_fb-group-search-memo23-aborted` | `memo23/facebook-search-groups-scraper` | 0 | $0.005 | Aborted when the $5 free limit ran out |
| `2026-10-19_fb-traffic-groups` | `apify/facebook-groups-scraper` | 300 | $1.50 | 1 enforcement report in 300 posts; checkpost idea dropped (§105.4) |
| `2026-10-21_fb-bike-groups` | `apify/facebook-groups-scraper` | 378 (3 are errors) | $2.65 | `DOCS/old/apify/2026-10-21_fb_bike_groups.md` (§105.3) |

Total: $7.78 of a $10 monthly limit (raised from the free $5 on 2026-10-21; the cycle resets on the 18th).

Run dates are Dhaka time; Apify shows the 10-19 runs as 2026-10-18 ~20:00 UTC.

## Lessons

**Cost and limits**
- Free plan = $5/month, and it runs out quietly: the 10-19 session hit it mid-run and the group search aborted. Check `GET /v2/users/me/limits` before a run and pass `maxTotalChargeUsd` on the run so it cannot overspend.
- Real prices: Google Maps ≈ $0.004 per place; Facebook groups ≈ $0.005–0.007 per post. Private or wrong group URLs return an error item and cost almost nothing.
- Unnamed datasets expire on Apify. Download right away; a session scratchpad is temporary (the first traffic export was lost there and had to be re-downloaded).

**Finding Facebook groups**
- Web search finds Facebook *pages*, not *groups*. The two group-search actors found only traffic groups and an unrelated TorrentBD group. Listing sites (motobyk.com/communities, motorcyclevalley.com) gave usable `groups/...` URLs, but about half were private or wrong. Expect that.
- The biggest groups are private (Traffic Alert BD at 450k members; BD Biker Club, Gixxer Riders BD, Royal Enfield BD). `apify/facebook-groups-scraper` only reads public groups; logging in to read private ones breaks Facebook's terms. Don't.
- Group quality varies: Freewheelers (`groups/fcb.zone`) = long technical questions, the best source. BikeBD (`groups/bikebdofficial`) = mixed. Motorcycle Valley = ads and reels, ~100 of 125 posts had no text. Skip it.
- Around a quarter of posts are photo- or video-only with no text. Budget for that when sizing a run.

**What the data is good for**
- Google Maps: use it for facts only (name, location, phone, hours) to fill gaps OSM misses. Storing or showing Google ratings or reviews breaks Google's terms, so they were dropped (§105.1). Match by coordinates (60 m), not by name.
- Facebook posts: good for research (what riders ask about), not for seeding the app. Checkpost reports live in private groups, so public scrapes don't find them (§105.4). Never put scraped names or posts in Firestore or git.

**Process that worked**
- Dry run → review → write, for anything touching production (`scripts/README.md`).
- Read post text into a compact file (index, group, comment and like counts, first 400 chars) and read it whole; keyword counts miss Bangla and Banglish posts.
