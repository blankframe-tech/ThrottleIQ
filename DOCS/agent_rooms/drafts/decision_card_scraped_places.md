> DRAFT for owner review, 2026-10-22

# Decision card: scraped Google Maps data in `places` (owner item #1)

## Summary

On 2026-10-19, `scripts/oneoff/import_google_places.js` wrote data from an Apify scrape of Google Maps into production. `places` went from 521 to 1,238 docs. The import added 717 new Dhaka places (71 fuel, 394 garage, 252 parts), filled empty fields on 80 existing places (5 of them renamed), and set 69 Google ratings to 0. The 717 carry `createdBy: 'system:gmaps-seed-dhaka'` and `verified: true`. `judge.md` says Google's Maps terms forbid this data, and that the likely cost is a takedown or removal from Google Play, not a lawsuit. A revert script is written and tested on the emulator, but it has never run against production, not even as a dry run. You choose one of three options: A (remove everything the import added), B (delete only the 717 new places), or C (keep the data while a lawyer reviews it). All counts above match the repo (HANDOFF 2026-10-19 entry, `issues_fixed.md` §105.1).

## Facts checked against the repo

| Claim | Repo says | Source |
|---|---|---|
| 717 new places | 717 (71 fuel, 394 garage, 252 parts), `createdBy: 'system:gmaps-seed-dhaka'` | `issues_fixed.md` §105.1; `import_google_places.js:35` |
| 80 enriched | 80 enriched (5 renamed), marked only by an added `googlePlaceId` | `issues_fixed.md` §105.1; `judge.md:89` |
| 1,238 total | 1,238 after the import; the import made 866 writes | HANDOFF "2026-10-19"; `issues_fixed.md` §105.1 |
| 521 before | 521 existing places at the 2026-10-19 dry run | `issues_fixed.md` §105.1 |
| Imported places marked verified | `verified: true` is still at `import_google_places.js:169` | `judge.md:88`; checked in the file |
| Export (Google rows) | 897 rows, Apify dataset `7tcKVfmd9vYe3nGnS`, at `~/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json` (the file exists, not opened). A gitignored copy is at `DOCS/old/apify/2026-10-19_gmaps-dhaka-places/items.json` in the main checkout, which Drive syncs | `scripts/README.md` revert section; `issues_fixed.md` §105.1 pointer; `DOCS/old/apify/README.md` |
| Admin key | The script's usage names `~/.secrets/throttleiqfb-admin.json`. **That file does not exist on this machine** (checked whether it exists only). The owner page's SECURITY step 3 says how to generate it | `scripts/README.md` revert section; owner page, SECURITY step 3 |

All counts are as of 2026-10-19. Riders may have added places since then, so the real total and the number left after a revert can differ. The dry run prints the live numbers.

## What the revert script really does

`scripts/oneoff/revert_google_places.js` (run from `scripts/`):

- **Selection:** it deletes docs with `createdBy == 'system:gmaps-seed-dhaka'`. A doc by any other author that carries `googlePlaceId` counts as enriched, because nothing else writes that field. It never touches other places.
- **`--seeded-only` (Option B):** deletes the seeded places. Needs no export.
- **`--from=<export.json>` (Option A):** does B, then on each of the 80 enriched places removes `googlePlaceId` and clears each field that still equals the Google value: `phone` and `hours` become null, `address` becomes `''`, and a renamed place gets the generic name `Fuel`, `Garage` or `Parts` back. A value that was already there and happens to equal Google's is cleared too, so read the dry-run list.
- **Skips:** any seeded place someone changed since the import (`updatedAt` or `updatedBy` set, or `ratingCount > 0`). It lists them instead of deleting them.
- **Safety:** a dry run is the default and only reads. `--apply` requires `--backup=<new file>`, which is written before the first write. `--restore=<backup> [--apply]` undoes the run. Each write checks the doc's read time first, so a place a rider changes mid-run is skipped. Re-running does nothing once the job is done.
- **Not undoable:** the 69 ratings the import set to 0. Places riders saved stay as dead entries in their phone's SQLite. Since the 104.1 fix, phones that cached a deleted place keep it until their 3-day re-read of that map cell (`issues_fixed.md` §104.1 "Limits").
- **Tested:** 6 unit tests (`scripts/test/revert_google_places.test.js`), plus an emulator round trip with the real 897-row export: B deleted 766 and kept one reviewed place, A then cleared 30, and the restore gave back the collection exactly (`judge.md` 2026-10-21 update). It has not been tested against a review that lands mid-run.

Commands, from `scripts/README.md` (revert section):

```bash
cd scripts
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.secrets/throttleiqfb-admin.json"
export FIREBASE_PROJECT_ID=throttleiqfb
EXPORT="$HOME/.secrets/throttleiq/gmaps-dhaka-2026-10-19.json"
BACKUP="$HOME/.secrets/throttleiq/places-revert-$(date +%F-%H%M).json"
node oneoff/revert_google_places.js --seeded-only                                 # B, dry run
node oneoff/revert_google_places.js --from="$EXPORT"                              # A, dry run
node oneoff/revert_google_places.js --from="$EXPORT" --apply --backup="$BACKUP"   # write (or --seeded-only)
node oneoff/revert_google_places.js --from="$EXPORT"                              # expect 0 to delete, 0 to clear
node oneoff/revert_google_places.js --restore="$BACKUP" [--apply]                 # undo
```

## Quota cost (Spark: 50,000 reads, 20,000 writes, 20,000 deletes a day)

Limits are from `scripts/README.md` §104 and the load-test reports. Production uses 1,454-7,166 reads, 57-881 writes and at most 13 deletes a day (7 days to 2026-10-21, `load_test/quota-rehearsal-2026-10-21.md` "Not checked").

- **Each dry run** reads the whole `places` collection (`db.collection('places').get()`), so about 1,238 reads.
- **Full sequence for A** (dry run, apply, verify run): about 3 x 1,238 = about 3,700 reads (7% of the daily limit), up to 717 deletes (3.6%) and up to 80 updates (0.4%). Adding a B dry run first makes it about 5,000 reads.
- **Restore, if needed:** up to 717 creates and 80 updates, plus 1 read per entry.
- **Total:** well inside one day's quota, even on top of the busiest day measured. To be safe, run it right after the quota reset (about 13:00 Dhaka in summer, 14:00 in winter, `scripts/README.md` §104).
- **Time:** the owner page estimates about 20 minutes to run (owner item #1 "eff"). Generating the admin key first adds a few minutes.

## Options

| Option | What happens | Cost | Risk | Reversible? |
|---|---|---|---|---|
| **A. Full revert** | Generate the admin key, run the A dry run, review the skip and clear lists, then `--from="$EXPORT" --apply --backup="$BACKUP"`, then a verify dry run. Deletes the untouched seeded places (up to 717) and clears Google-filled fields on the 80. `places` returns to about 521 plus anything riders added since. | About 20 min (owner page). About 3,700-5,000 reads, at most 717 deletes and 80 updates, all well under Spark limits. $0. | **Legal/store:** removes the Google content the judge flagged from Firestore. Copies remain in the export, the gitignored `items.json` in the Drive-synced tree, the revert backup, phone caches and riders' saved places. **Product:** the directory loses most garages (394) and parts shops (252), the categories OSM covers poorly (`features.md` §6 "Data"), so some areas of Dhaka will look empty. **§104 read cost:** released builds (29 and older) still re-read all places within 25 km every 5 km. That costs about 1,000-1,200 reads per fetch after the import and about 400-515 before it (`issues_fixed.md` §104.1, `load-test-2026-10-15.md`), so A brings per-fetch reads back down about 2.4x. Builds with the 104.1 fix (not released) mostly avoid that cost anyway. | Yes, through `--restore=<backup> --apply`, as long as the backup file is kept. The 69 zeroed ratings cannot be restored in any option. |
| **B. Delete only the seeded docs** | Same steps with `--seeded-only`. No export needed. Deletes the untouched seeded places. The 80 enriched docs keep their Google-sourced phone, hours, address and 5 renamed names, plus `googlePlaceId`. | Same as A minus up to 80 updates. $0. | **Legal/store:** about 90% of the data goes (owner page), but the 80 still hold Google Maps content, so the legal problem is reduced, not closed. **Product and §104:** same as A. | Yes, through `--restore`. A can still run later because A covers everything B does (`scripts/README.md`). |
| **C. Keep, mark `verified: false`, get a legal opinion** | No delete. Someone must set `verified: false` on the 717 and stop the importer writing `verified: true` (`import_google_places.js:169`). **No script for this exists:** `revert_google_places.js` has no such mode, so an agent has to write one (dry run by default). Then a lawyer gives a written opinion. | Lawyer fee: [PLACEHOLDER: fee and timeline from a Bangladesh or Google-terms lawyer]. A flag script costs about 1 read per place plus up to 717 writes. | **Legal/store:** the risk continues until the opinion arrives. `judge.md:93` says no attribution makes the use allowed. **Product:** the directory stays full, but the scraped places lose the Verified badge and drop out of the "verified only" filter. **§104:** released builds keep paying about 2.4x more reads per places fetch. Until a decision, `judge.md` says not to market the places directory. | Yes. The flag can be flipped back, and A or B can still run while the export exists. |

Not an option: switching to the Places API. Its terms allow storing only the Place ID (`judge.md:93`; owner page option D).

## Recommendation

**A, the full revert, after the dry run.** Reasons, all from the repo:

1. `judge.md:93` and the owner page say B still leaves Google Maps content on 80 docs. Only A removes all of it.
2. The export A needs exists at the documented path, and the script backs up and can restore everything it changes. The step from B to A buys little extra safety.
3. The quota cost is a small share of one Spark day, and released builds read about 2.4x less per places fetch afterwards (§104).
4. The cost is real: most garage and parts listings disappear. Rebuild the directory from rider submissions, field visits and OpenStreetMap, as `judge.md` and the owner page recommend.

If the admin key cannot be made soon, the export turns out to be unusable, or the A dry run lists clears that look wrong, run B now and A later.

## Owner sign-off question

> "Do you approve Option A: generate the throttleiqfb admin key, run `revert_google_places.js --from=<export>` as a dry run, send the printed counts and the skip and clear lists for review, and, once those look right, run it with `--apply --backup=<new file>`? Or do you choose B (`--seeded-only`) or C (keep the data, mark it unverified, get a legal opinion)?"

## Follow-ups after the decision

| Step | Who |
|---|---|
| Generate `~/.secrets/throttleiqfb-admin.json` (owner page, SECURITY step 3) | Owner |
| Run the dry run and share the output (counts, skipped places, clear list). Production runs are the owner's job (`judge.md` "Next steps" 2) | Owner, with an Operations Manager agent reading the output |
| Run `--apply --backup=...`, then the verify dry run (expect 0 and 0) | Owner |
| Stop the importer writing `verified: true` (`import_google_places.js:169`), whatever the choice | Architect agent |
| Option C only: write a dry-run-by-default script that sets `verified: false` on `createdBy == 'system:gmaps-seed-dhaka'` | Architect agent |
| Update `features.md` §6 "Data", HANDOFF "Data" and "Decisions in force", `needs_attention.md` "Decisions", and `issues_fixed.md` §105 with the result and new counts | Product Manager or docs agent |
| Decide whether to delete the export, the gitignored `items.json` copy and the revert backup once the restore window is over (all three hold Google content) | Owner, with [PLACEHOLDER: how long to keep the backup] |
| Plan rider and field collection for garages and parts, plus an OSM refresh | Product Manager agent |

## Where the room file disagrees with the repo

- **The 40-point cap.** The room says the scraped data caps the audit score at 40. `judge.md:115` gives three reasons for the cap: rules and functions not live, the Google data, and nothing run on a phone. The owner page calls the data "one reason".
- **"Saved Apify backup."** The room says Option A uses a saved Apify backup. It is the Apify **export** (`--from=`). The script writes its own **backup** through `--backup=` on apply, and both are needed.
- **"1,238 to 521."** The room lists this under A only. B also deletes the 717, so it lands on the same count. A differs only in the 80 enriched docs. The real end count can be higher if seeded places were edited (they are skipped) or riders added places.
- **"Eliminating legal risk."** A removes the Google content from Firestore, but copies remain in the export, the Drive-synced `items.json`, the backup, phone caches and saved places.
- **Option C.** The room lists `verified: false` as if it were ready. No script or mode sets it today.
- **Other mismatches in the repo itself.** `DOCS/old/apify/README.md` ("Lessons") says Google Maps data is fine "for facts only (name, location, phone, hours)". That contradicts `judge.md:93`. `issues_fixed.md` §105.1 says both "Written to production" and "Nothing has been written to Firestore" (`judge.md:91` already flags this). Several files still cite "issues_open.md §105", which moved to `issues_fixed.md` on 2026-10-22. `features.md` §6 gives 395 OSM + 717 Google = 1,112, not 1,238; the other 126 are presumably cameras, checkposts and rider places, but that is not verified. The owner page says the revert has "12 unit tests"; the test file has 6.

## Sources

- `judge.md:86-109` (2026-10-19 review, legal section, next steps), `:115` (score cap), `:144-148` (2026-10-21 revert update)
- `scripts/oneoff/revert_google_places.js` (header and `main`)
- `scripts/README.md`: table rows for `import_google_places.js` and `revert_google_places.js`, the revert section, and §104 quota limits
- `scripts/oneoff/import_google_places.js:35,169`
- `DOCS/Handoff for agents and Todos/HANDOFF_Document.md`: "Data" table row, "Decisions in force", and the 2026-10-19 entry
- `DOCS/Handoff for agents and Todos/issues_fixed.md` §104.1, §105
- `DOCS/Handoff for agents and Todos/needs_attention.md` "Decisions"
- `DOCS/Handoff for agents and Todos/features.md` §6 "Data"
- `DOCS/Handoff for agents and Todos/load_test/load-test-2026-10-15.md`, `quota-rehearsal-2026-10-21.md`
- `DOCS/old/apify/README.md`
- `DOCS/agent_rooms/chief_of_staff_todo.md` item 1
- Owner page `~/Everything/dev/housekeeping/owner_works_now.html`: Google Maps data item and SECURITY step 3 (outside the repo)
