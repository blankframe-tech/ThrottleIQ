# ThrottleIQ: go-to-market judge

Scored 2026-10-14 from the README, `DOCS/Handoff for agents and Todos/HANDOFF_Document.md`, `scripts/check.sh`, `.gitignore` and the git log. I did not run the gate, the app or CI. Test counts and "real riders testing" are the repo's own statements. Treat the score as +/- 10 points.

## Verdict

**45%, cap 45.** The most mature project in the folder: an offline-first Flutter ride tracker, garage and rider community with Firebase, in English and Bangla. A signed beta (`1.0.0-beta.4.5.0+26`) is said to be with real riders. It is not safe to open publicly yet: the Firebase project is on the Spark plan, so Cloud Functions cannot deploy, and the handoff does not confirm the latest Firestore rules are live. Crash detection and emergency alerts are off.

## What exists

- App (`app/`): ride recording (GPS plus 20 Hz motion sensors), analytics, garage and maintenance, places and routes, social (feed, forums, DMs, group rides), live-share link, data export, account deletion, English and Bangla.
- Backend: Firestore rules (274 emulator tests on 2026-10-09), Cloud Functions (12 tests, written but not deployable), Cloudinary for photos, Hosting.
- Quality gate: `scripts/check.sh` runs l10n, format, CI guards, analyze, 2131 Flutter tests and the rules and functions suites; a pre-push hook and CI call it. Last green per the handoff: 2026-10-13 after the dependabot merge.
- Release keystore and `secret/` are git-ignored (checked); `app/android/key.properties.example` is the only tracked key file.
- Branches: `main`, `experimental` (same commit), `indriyo` (dash-cam hardware integration), local `test`.

## Gaps (ranked)

1. **Cloud Functions cannot deploy** (Spark plan, needs Blaze): account cleanup, ride identity and chat moderation are not live. `firestore:rules` for badge counters and fuel sync were "NOT yet deployed" on 2026-10-09; no later note confirms it.
2. **Crash detection and emergency alerting are not live** (detector off pending calibration, no SMS or email provider). The README says so plainly, which is the right call.
3. **No device or E2E run** for the latest changes. The `home_widget` 0.10 widgets and the Indriyo HUD are marked unchecked on a device. 2131 tests are unit and widget tests.
4. **Founder-only items open** (2026-10-08): Play and Apple declarations, analytics consent, chat moderation policy, group-ride location function, CSP/SRI, contact email and secrets layout.
5. **No public listing.** Distribution is a GitHub Releases APK and a Play internal track. The iOS team `NJ4675FFUX` is a personal Apple team (no push, no Associated Domains).
6. **Market validation:** how many real riders, how often they ride and whether they would keep using it are not recorded anywhere I read.
7. **Security:** about 150 audit findings (§101) were triaged; most fixes are on a branch pass, and the `functions` emulator suite was not run for that pass. No human review of the rules or auth code.
8. **Hygiene:** `SECURITY.md` is the GitHub template (wrong versions, no contact). `DOCS/General/screenshots_ui` is about 1.9 GB. `ios/Podfile.lock` is modified and uncommitted. Not workspace-standard: no `AGENTS.md` or `CODING_STANDARDS.md` (it has `CLAUDE.md` and `.agents/rules/`).

## Scores (0-10)

| Dimension (weight) | Score |
|---|---|
| Product works (25) | 7 |
| Quality and verification (15) | 8 |
| Security and privacy (15) | 6 |
| Legal and compliance (10) | 3 |
| Market validation (15) | 3 |
| Deploy and operations (10) | 4 |
| Claims honesty (10) | 8 |
| **Weighted** | **58** |
| **Cap** | **45** (backend only partly deployed; store declarations and consent policy open) |
| **Final** | **45** |

## Next steps, in order

1. **You:** confirm what is live: `firebase deploy --only firestore:rules,firestore:indexes` and the Blaze decision for Functions. Record the result here.
2. **You:** run the current build on a real phone through one real ride, a widget refresh and an account deletion.
3. **You:** count the beta riders and ask five of them what they would miss if the app vanished.
4. **You:** finish the Play and Apple declarations, analytics consent and the chat moderation policy.
5. **Code:** replace `SECURITY.md`; commit or revert the `Podfile.lock` change; add the missing `AGENTS.md`.
6. **You:** get a human to review `firestore.rules` and the auth and moderation functions.
7. Keep crash detection off until it is calibrated on real rides.

## Update 1 (2026-10-14, pushed `6ca31db` to `main`)

Done: real `SECURITY.md` (private reports to the owner's email), `AGENTS.md`, `CODING_STANDARDS.md`; `check.sh` passed.
**Deployed to `throttleiqfb`:** Firestore indexes and Hosting. **Not deployed, on purpose:** `firestore.rules`. Per the handoff, old builds lose search, All People and forum post create and delete when the new rules go live, and `users` docs need a `visibility: 'public'` backfill first. Rules compile with one warning (line 455). Functions cannot deploy on Spark.
**Skipped:** the old `seed_police_checkposts` v1 and v2 scripts are required by tests and docs, so they stay. `app/ios/Podfile.lock` stays uncommitted: its diff removes `home_widget`, but `pubspec.yaml` and `pubspec.lock` still list it, so the lockfile and pubspec disagree and need a human look. Local branch `test` and `screenshots_ui` untouched. Score unchanged at 45%.

## Update 2 (2026-10-14): Firestore rules deployed

`firebase deploy --only firestore:rules` to `throttleiqfb` at the owner's request; the CLI reported the rules released ("already up to date, skipping upload": the file matched an existing ruleset, so the live rules may have been unchanged). Compile warning at line 455 remains. The `users` `visibility: 'public'` backfill was **not** run, and no old-build behaviour was checked: if beta riders on old builds report broken search, All People or forum posts, that is the cause named in the handoff.
