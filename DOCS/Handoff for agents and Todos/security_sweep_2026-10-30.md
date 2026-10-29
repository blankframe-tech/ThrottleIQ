# Security sweep, 2026-10-30

Source: CodeQL (20 open alerts), `npm audit` on `functions/` and `scripts/`, CI security runs, and three read-only agent reviews (rules, functions, app/scripts/history/CI). CodeRabbit Deep Scan was not run: it is billed per scan and not part of the trial.

Work on one branch, `security/sweep-2026-10`, opened as a PR so CodeRabbit and CI review it. **One commit per row.** Each rules commit ships with its deny test in `scripts/test/rules/`; each functions commit with its test in `functions/test/`. Run focused tests per commit and `scripts/check.sh` once at the end. Nothing here deploys; rules and functions deploy only when the owner asks.

Severity: H high, M medium, L low. Status: `[ ]` open.

## A. Dependencies and CI (do first, smallest)

| # | Sev | Commit | Where |
|---|---|---|---|
| [ ] A1 | M | `chore(scripts): track package-lock.json` — drop line 2 of `scripts/.gitignore`, add `!package-lock.json` after `*.json` | `scripts/.gitignore` |
| [ ] A2 | M | `fix(scripts): bump firebase-admin and firebase, npm audit fix` — 22 vulns (8 high: undici, node-forge, grpc-js, @fastify/busboy); rerun `scripts/test` | `scripts/package.json`, lockfile |
| [ ] A3 | M | `ci: npm ci in scripts and osv-scan its lockfile` | `ci.yml:83`, `security.yml:43-45` |
| [ ] A4 | L | `ci(cla): exact bot names instead of bot*` | `cla.yml:34` |
| [ ] A5 | L | `ci(summary): drop unneeded checkout and contents permission` | `summary.yml:17,26-27` |

## B. Firestore rules (each with a deny test)

| # | Sev | Commit | Where |
|---|---|---|---|
| [ ] B1 | M | `fix(rules): ride comment create must bump the counter` — today a bare create then counted delete drives `comments` below zero. Confirm every build ≥ `config/app.minBuild` writes comments transactionally first | `firestore.rules:1190-1206`; test in `critic_oct27_rules.test.js` |
| [ ] B2 | M | `fix(rules): notification shape — hasOnly, createdAt == request.time, read false, groupRideId ≤128, follow id = follow_{uid}` — stops inbox flooding and pinning | `firestore.rules:792-818`; `audit90_rules.test.js` |
| [ ] B3 | M | `fix(rules): validate public routes` — hasOnly, name ≤100, description ≤2000, `timesRidden` int and +1 only, `photoUrlAllowed(mapSnapshotUrl)` | `firestore.rules:713-716`; `access_matrix_rules.test.js` |
| [ ] B4 | L | `fix(rules): profile keys allow-list` — hasOnly on create, affectedKeys on update | `firestore.rules:588-596` |
| [ ] B5 | L | `fix(rules): cap place tags and type-check place fields` | `firestore.rules:1609-1612`; `places_rules.test.js` |
| [ ] B6 | L | `fix(rules): forum alsoIn elements and create text sizes` | `firestore.rules:1288-1300,1363-1366` |
| [ ] B7 | L | `fix(rules): validate group ride roster rows` | `firestore.rules:2059-2075` |
| [ ] B8 | L | `fix(rules): follow edge hasOnly` | `firestore.rules:1852-1856` |
| [ ] B9 | L | `fix(rules): live-share token must match [A-Za-z0-9]{32}` (paired with C4) | `livePointers` `:1794-1797`, `handleLinks` `:1813-1822` |

## C. Cloud Functions (mostly not deployed until Blaze; fix before then)

| # | Sev | Commit | Where |
|---|---|---|---|
| [ ] C1 | M | `fix(functions): erasure timeout 540s, retries on, profile deleted before the Cloudinary sweep` — 60 s default can leave an account half-erased with no marker | `account-deletion.ts:91`, `account-erasure.ts:461-465` |
| [ ] C2 | M | `fix(functions): erasure removes the rider from groupRides positions/all` | `account-erasure.ts:210-242` |
| [ ] C3 | L | `fix(functions): erasure clears forum createdBy/maintainerIds and legacy likes` | `account-erasure.ts` |
| [ ] C4 | L | `fix(functions): only erase live_shares paths for well-formed tokens` — a token of `/` today wipes every rider's live shares | `account-erasure.ts:112-113,174` |
| [ ] C5 | M (latent) | `fix(functions): cap emergency contacts at 5 and rate-limit crash alerts per rider` — before `DELIVERY_IMPLEMENTED` goes on | `crash-core.ts:78,97`, `firestore.rules:650,970-991` |
| [ ] C6 | L | `perf(functions): drop the legacy-votes full scan` — the vote uid backfill ran 2026-10-29 | `account-erasure.ts:332-344` |

## D. Scripts, app, hosting, CodeQL

| # | Sev | Commit | Where |
|---|---|---|---|
| [ ] D1 | M | `docs: redact the old shared test passwords` | `issues_fixed.md:4078,4082` |
| [ ] D2 | L | `fix(scripts): redact passwords in dry-run and provided-password logs` | `seed_qa_test_riders.js:669`, `create_review_account.js:229,341` |
| [ ] D3 | L | `chore(docs): delete DOCS/old/ui_stuff mockups` — closes 15 CodeQL alerts (XSS, cross-window) | `DOCS/old/ui_stuff/*.html` |
| [ ] D4 | L | `fix(hosting): SRI on Leaflet tags in live-viewer` | `public/live-viewer.html:7-15` |
| [ ] D5 | L | `fix(app): raise live-link password minimum to 12` | `public_live_link_setting.dart` |
| [ ] D6 | L | `fix(app): don't log the live-share token` | `outbox_service.dart:174` |
| [ ] D7 | L | Dismiss CodeQL #46 (Math.random builds fake stats, not passwords) and #24/#28 (SHA-1 is Cloudinary's signature scheme; switch only after checking Cloudinary supports SHA-256 for this account) | GitHub UI, no commit |

## E. Owner only (no commit)

- Rotate the Play review account password (`create_review_account.js --password`) and confirm the old `@qa-seed.invalid` riders are deleted. Their passwords were public in history 2026-08-27 to 2026-09-10.
- Cloudinary: restrict the `throttleiq_unsigned` preset (formats, max size, folder, moderation).
- GCP: confirm the Firebase API keys have app/API restrictions and App Check is enforced.
- GitHub: Settings › Code security › turn on push protection.
- `secret/` holds service-account keys and Google Drive syncs this tree; move them out of the synced folder or accept that Drive has a copy.
- After merge: deploy rules (B) and, on Blaze, functions (C).

## Not checked

Emulator runs for these findings (none proven by a failing test yet), live GCP/Cloudinary/GitHub settings, `badge-*.ts` (not deployed).
