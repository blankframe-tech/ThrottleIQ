# open55 handoff — social bugs, maintenance costs, media collage (2026-10-01) — ALL SIX DONE in code (analyze clean, 1349/1349 tests); committed ad9fa2c..e1c7c85 (not pushed); remaining: device check

## Goal
Six user asks, done in parallel by three subagents in the same working tree (nothing committed yet):

| # | Ask | Owner stream |
|---|-----|--------------|
| 1 | Finished group rides still show in Social "Riding Now" | A — social bugs |
| 2 | Posts from some followed riders missing from feed | A |
| 3 | Starting a group ride doesn't take you to the live/push-to-talk screen (only reachable from Social card) | A |
| 4 | Simplify maintenance page; move customize / sync odo / reset log / km-mi into a "Maintenance settings" section at the end, losing no features | B — maintenance |
| 5 | Typical cost per maintained item + fuel price + avg mileage → ride summary shows total ride cost with breakdown (Fuel + engine oil + …) per bike | B |
| 6 | Map art is one tile in a unified photo collage, laid out by count, as one big picture | C — collage |

## File ownership (to avoid clobbering)
- A: social providers/repositories, group ride screens, ride record/active screens, Riding Now part of `social_screen.dart`.
- B: `lib/features/maintenance/**`, `ride/presentation/screens/ride_summary_screen.dart`.
- C: new `social/presentation/widgets/ride_media_collage.dart`, media section of `social_screen.dart`, `shared_ride_detail_screen.dart`, `ride_share_screen.dart`.
- All: l10n ARB files (en + bn), then `flutter gen-l10n`.

## Plan / approach
- 1: fix at the source (ending a ride marks the group ride ended) and filter as a fallback (status + staleness cutoff).
- 2: find the real cause (likely `whereIn` 10/30-ID truncation, a visibility value mismatch, or a missing index); chunk the queries and merge the results.
- 3: navigate to the group ride map/PTT screen on start, or show a prominent entry point on the active ride screen.
- 5: pure calculator. cost/km = fuel price ÷ km/l + Σ(item cost ÷ interval km), using average logged cost when there is one and the typical cost otherwise. Ride cost = distance × cost/km.
- 6: pure layout function (count → tiles), unit tested. Layouts: 1 full, 2 side by side, 3 map-big + 2 stacked, 4 grid, 5+ grid with "+N".

## Success criteria
- `flutter analyze` clean and `flutter test` green.
- Each bug has a root cause identified with file:line.
- Nothing from maintenance lost: an inventory of every action before and after.
- Ride summary shows the cost breakdown, and a hint when there's no cost data.
- Any Firestore rules/index changes flagged (NOT deployed).

## Next steps if interrupted
1. `git status` / `git diff --stat` to see what landed.
2. Run `cd app && flutter analyze && flutter test`.
3. Re-dispatch any stream whose work is missing, using this file as the spec.
4. Commit per stream (feat(social)/fix(social)/feat(maintenance)), and log to DOCS/Handoff for agents and Todos/HANDOFF_Document.md as §87.
5. On-device check: Riding Now strip empty after rides end, feed shows all followees, starting a group ride opens PTT, collage visuals, ride cost card.
