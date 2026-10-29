# Security sweep, 2026-10-30

Source: CodeQL (20 open alerts), `npm audit` on `functions/` and `scripts/`, CI security runs, and three read-only agent reviews (rules, functions, app/scripts/history/CI). CodeRabbit Deep Scan was not run: it is billed per scan and not part of the trial.

Work on one branch, `security/sweep-2026-10`, opened as a PR so CodeRabbit and CI review it. **One commit per row.** Each rules commit ships with its deny test in `scripts/test/rules/`; each functions commit with its test in `functions/test/`. Run focused tests per commit and `scripts/check.sh` once at the end. Nothing here deploys; rules and functions deploy only when the owner asks.

Severity: H high, M medium, L low. Status: `[x]` done (issue, commit), `[-]` skipped. Run results: "Result, 2026-10-30" at the end.

## A. Dependencies and CI (do first, smallest)

| # | Sev | Commit | Where |
|---|---|---|---|
| [x] A1 #65 `fbd588f2` | M | `chore(scripts): track package-lock.json` — drop line 2 of `scripts/.gitignore`, add `!package-lock.json` after `*.json` | `scripts/.gitignore` |
| [x] A2 #66 `2e84c2de` | M | `fix(scripts): bump firebase-admin and firebase, npm audit fix` — 22 vulns (8 high: undici, node-forge, grpc-js, @fastify/busboy); rerun `scripts/test` | `scripts/package.json`, lockfile |
| [x] A3 #67 `ba4976e6` | M | `ci: npm ci in scripts and osv-scan its lockfile` | `ci.yml:83`, `security.yml:43-45` |
| [x] A4 #68 `f1045006` | L | `ci(cla): exact bot names instead of bot*` | `cla.yml:34` |
| [x] A5 #69 `e9e9d678` | L | `ci(summary): drop unneeded checkout and contents permission` | `summary.yml:17,26-27` |

## B. Firestore rules (each with a deny test)

| # | Sev | Commit | Where |
|---|---|---|---|
| [x] B1 #70 `c2d8ff3e` | M | `fix(rules): ride comment create must bump the counter` — today a bare create then counted delete drives `comments` below zero. Confirm every build ≥ `config/app.minBuild` writes comments transactionally first | `firestore.rules:1190-1206`; test in `critic_oct27_rules.test.js` |
| [x] B2 #71 `eeeac20b` | M | `fix(rules): notification shape — hasOnly, createdAt == request.time, read false, groupRideId ≤128, follow id = follow_{uid}` — stops inbox flooding and pinning | `firestore.rules:792-818`; `audit90_rules.test.js` |
| [x] B3 #72 `69c1c9fa` | M | `fix(rules): validate public routes` — hasOnly, name ≤100, description ≤2000, `timesRidden` int and +1 only, `photoUrlAllowed(mapSnapshotUrl)` | `firestore.rules:713-716`; `access_matrix_rules.test.js` |
| [x] B4 #73 `fdb9a1a0` | L | `fix(rules): profile keys allow-list` — hasOnly on create, affectedKeys on update | `firestore.rules:588-596` |
| [x] B5 #74 `0d0c4077` | L | `fix(rules): cap place tags and type-check place fields` | `firestore.rules:1609-1612`; `places_rules.test.js` |
| [x] B6 #75 `084e4c7c` | L | `fix(rules): forum alsoIn elements and create text sizes` | `firestore.rules:1288-1300,1363-1366` |
| [x] B7 #76 `10c0dcbe` | L | `fix(rules): validate group ride roster rows` | `firestore.rules:2059-2075` |
| [x] B8 #77 `f24a7cd8` | L | `fix(rules): follow edge hasOnly` | `firestore.rules:1852-1856` |
| [x] B9 #78 `43b43ed6` | L | `fix(rules): live-share token must match [A-Za-z0-9]{32}` (paired with C4) | `livePointers` `:1794-1797`, `handleLinks` `:1813-1822` |

## C. Cloud Functions (mostly not deployed until Blaze; fix before then)

| # | Sev | Commit | Where |
|---|---|---|---|
| [x] C1 #79 `ad73658f` | M | `fix(functions): erasure timeout 540s, retries on, profile deleted before the Cloudinary sweep` — 60 s default can leave an account half-erased with no marker | `account-deletion.ts:91`, `account-erasure.ts:461-465` |
| [x] C2 #80 `a3ee2323` | M | `fix(functions): erasure removes the rider from groupRides positions/all` | `account-erasure.ts:210-242` |
| [x] C3 #81 `47a33eda` | L | `fix(functions): erasure clears forum createdBy/maintainerIds and legacy likes` | `account-erasure.ts` |
| [x] C4 #82 `047fccfa` | L | `fix(functions): only erase live_shares paths for well-formed tokens` — a token of `/` today wipes every rider's live shares | `account-erasure.ts:112-113,174` |
| [x] C5 #83 `40a4f218` | M (latent) | `fix(functions): cap emergency contacts at 5 and rate-limit crash alerts per rider` — before `DELIVERY_IMPLEMENTED` goes on | `crash-core.ts:78,97`, `firestore.rules:650,970-991` |
| [-] C6 #84 skipped | L | `perf(functions): drop the legacy-votes full scan` — the vote uid backfill ran 2026-10-29 | `account-erasure.ts:332-344` |

## D. Scripts, app, hosting, CodeQL

| # | Sev | Commit | Where |
|---|---|---|---|
| [x] D1 #85 `4ac39a0c` | M | `docs: redact the old shared test passwords` | `issues_fixed.md:4078,4082` |
| [x] D2 #86 `aaeaccf6` | L | `fix(scripts): redact passwords in dry-run and provided-password logs` | `seed_qa_test_riders.js:669`, `create_review_account.js:229,341` |
| [x] D3 #87 `618e0469` | L | `chore(docs): delete DOCS/old/ui_stuff mockups` — closes 15 CodeQL alerts (XSS, cross-window) | `DOCS/old/ui_stuff/*.html` |
| [x] D4 #88 `988bf98c` | L | `fix(hosting): SRI on Leaflet tags in live-viewer` | `public/live-viewer.html:7-15` |
| [x] D5 #89 `f9e1bb4d` | L | `fix(app): raise live-link password minimum to 12` | `public_live_link_setting.dart` |
| [x] D6 #90 `53328356` | L | `fix(app): don't log the live-share token` | `outbox_service.dart:174` |
| [x] D7 #91 dismissed | L | Dismiss CodeQL #46 (Math.random builds fake stats, not passwords) and #24/#28 (SHA-1 is Cloudinary's signature scheme; switch only after checking Cloudinary supports SHA-256 for this account) | GitHub UI, no commit |

## E. Owner only (no commit), each a GitHub issue assigned to the-abraar

- [ ] E1 #92 Rotate the Play review account password (`create_review_account.js --password`) and confirm the old `@qa-seed.invalid` riders are deleted. Their passwords were public in history 2026-08-27 to 2026-09-10; D1 removed them from the current files only, history still has them.
- [ ] E2 #93 Cloudinary: restrict the `throttleiq_unsigned` preset (formats, max size, folder, moderation).
- [ ] E3 #94 GCP: confirm the Firebase API keys have app/API restrictions and App Check is enforced. The agent tried `gcloud services api-keys list` as the.abraar.rar@gmail.com: permission denied (`apikeys.keys.list`), so this needs the console or an owner account.
- [x] E4 #95 GitHub push protection: already on (secret scanning and push protection both `enabled`, checked through the API 2026-10-30). Closed.
- [ ] E5 #96 `secret/` holds service-account keys and Google Drive syncs this tree; move them out of the synced folder or accept that Drive has a copy.
- [ ] E6 #97 After merge: deploy rules (B) and, on Blaze, functions (C). See "Before you deploy" below.

## Before you deploy (E6)

- **Rules (B).** Checked against what build 29 (`beta-v4.7.1`) and `main` write: no supported build is rejected. Builds 26 and older have no update gate; riders still on one may get permission errors on profile, notification, route, follow and roster writes once these rules are live. Deploy order and command: `SECURITY.md` "Owner runbooks" (`--only firestore:rules`, never a bare deploy). The fixes are public in the merged diff, so deploy the rules soon.
- **Functions (C), only on Blaze.** C5 adds new behaviour on the crash-alert path: one alert reaches at most 5 emergency contacts, and a rider gets at most 3 alerts per hour (the rest end as `rate_limited` and send nothing). The app does not cap contacts, so a rider with more than 5 gets alerts sent to 5 of them, picked by document id. Confirm both numbers before `DELIVERY_IMPLEMENTED` goes on. C1 turns retries on for `onUserAccountDeleted`; each retry re-runs the legacy-votes scan (C6). No index deploy is needed.

## Result, 2026-10-30

Done on `security/sweep-2026-10`: 25 fix commits by four parallel agents (one worktree per group), merged one group at a time. Every rules and functions fix has a test that failed before the fix.

- **A.** `scripts/` npm audit: 20 (6 high, 14 moderate) before, 0 after. firebase-admin 12 → 13.10 (not 14: 14 drops the `admin.firestore()` style the scripts use about 80 times; a separate task), firebase 10 → 13.1, `@firebase/rules-unit-testing` 3 → 6, plus overrides for `@grpc/grpc-js` and `uuid`. The lockfile is now tracked and CI runs `npm ci` and OSV on it. CLA allow-list: `the-abraar, blankframe-tech, dependabot[bot], github-actions[bot]`. Optional follow-up: add `/scripts` to `.github/dependabot.yml`.
- **B.** All nine rows; rules suite 402 → 416 tests. Differences from the plan: B3 name cap is 300, not 100 (the app writes `"<user>'s <bike> Route"`); B6 caps are generous (500/200/2000) because the app caps none of those fields; B5 still lets a numeric tag through (harmless: the app drops non-string tags). Three old happy-path tests used shapes the app never writes and were corrected.
- **C.** C1–C5 done. C3 skipped its legacy-likes part (no like docs left in production, §80; rules have blocked new likes since §101.S3). **C6 skipped:** builds 29–31 still write votes without `uid`, so the scan stays until `config/app.minBuild` passes a release that writes `uid` and the backfill runs again (`needs_attention.md`, #56).
- **D.** D1 found the old passwords in 5 places (also `issues_fixed.md:4097,4099` and a comment in `create_review_account.js`); all redacted, git history still has them (E1). D2: a password you pass in is never printed; a generated one is printed once on purpose. D3 removed the 3 mockup HTML files (PNGs stay, the poster scripts use them). D4 SRI hashes were checked against both CDNs and Leaflet's published SRI. D5: riders who already set an 8–11 character link password keep it (only its hash is stored). D7: CodeQL #46 dismissed (false positive), #24 (won't fix, Cloudinary's SHA-1 signature), #28 (used in tests). After the merge CodeQL closed the 15 mockup alerts and #45; #44 (the one-time print of a generated review password, kept on purpose) was dismissed as won't fix. Open CodeQL alerts: 0.
- **Gate.** `scripts/check.sh` on the merged branch: all passed (flutter analyze, flutter test, rules 416/416, functions 15/15). Also `scripts` npm test 101/101 and the functions emulator suite 26/26.
- **Issues:** #65–#97, one per row, all assigned to the-abraar. Fix issues close with the PR; E1–E3, E5, E6 stay open.

## Not checked

Live GCP and Cloudinary settings (no access), `badge-*.ts` (not deployed), Admin SDK and Cloud Functions writers against the new rules (they bypass rules), builds 26 and older.
