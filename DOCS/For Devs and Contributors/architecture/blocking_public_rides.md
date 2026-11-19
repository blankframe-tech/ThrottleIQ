# Blocking and public rides: design note (issue #105)

Written 2026-11-20 by an agent, for the owner to pick an option. No code changed. Nothing here has been run in the emulator yet; the claims marked *check* need a rules test before anyone builds on them.

## The problem in one paragraph

Blocking (`users/{blocker}/blocks/{blocked}`, written by `ProfileRepository.blockUser`) already hides chats, follows, notifications and followers/mutual rides on the server: those reads pin one author (`userId ==`), so `rideVisibleTo` can call `exists()` on the block path. Public rides are read by one global query, `rides where audience == 'public' orderBy createdAt desc limit 20` (`RideShareRepository.getPublicRides`). A rule that depends on who is asking and who wrote each ride cannot be proven for that query, so the public branch of `rideVisibleTo` has no block check. Today the app downloads blocked riders' public rides and drops them in `visibleFeedProvider`. A blocked rider can still read the blocker's public rides, routes included.

## Two separate goals

1. **Security:** a blocked rider can't read the blocker's public rides. This has to be enforced on the server.
2. **Hygiene:** the blocker's phone never downloads the blocked rider's rides. This is a cost and comfort goal; the client filter already hides them on screen.

## What the rules engine can and can't do

- `get` of one ride: rules see `resource.data.userId`, so `!exists(/users/$(resource.data.userId)/blocks/$(request.auth.uid))` works on the public branch for single-document reads. *Check:* add it to a `get`-only rule and confirm the list query still passes.
- `list` (the feed): rules must be provable from the query's filters alone. Firestore has no "array does not contain" filter, so a `hiddenFrom: [uids]` array on each ride can't be required by rules for the feed query. Rules also can't read the values of a query's `not-in` filter, so a client-side `where('userId', 'not-in', blockers)` can't be enforced either.

## Options

| | A. Lock details, not the feed row | B. Feed through a Cloud Function | C. Per-viewer feed documents |
|---|---|---|---|
| How | The public feed reads a slim `publicRides/{rideId}` summary (title, distance, date, author name and avatar; no route, no photos, no points). The full `rides/{id}` is `get`-only for non-authors, and its public branch adds the block `exists()` check. | Clients lose `list` on public rides; a callable function runs the feed query with the Admin SDK and filters both block directions. `get` keeps the rule from option A. | A writer fans each public ride out to `feeds/{viewer}/items/{rideId}` for the viewers who may see it. |
| Goal 1 | Partly: the blocked rider still sees that the blocker posted (the summary row) but can't open the ride, route or photos. | Fully. | Fully. |
| Goal 2 | No (client filter stays). | Yes. | Yes. |
| Spark plan | Works. The summary is written by the author's client in the same batch as the ride; rules check the two match. | **Needs Blaze**: functions don't deploy on Spark (#97). | Fan-out would run on clients or a function; client fan-out to all viewers isn't possible without knowing them. Needs Blaze in practice. |
| Read cost | Same feed reads (20 per page) plus 1 `get` per opened ride, as today. | Same reads, billed to the function; plus function invocations. | 1 read per item, but every public ride costs 1 write per viewer: unbounded on a 50,000 reads / 20,000 writes a day Spark budget. |
| Write cost | +1 write per published or edited public ride; a block costs nothing extra. | None extra. | Prohibitive. |
| Migration | Backfill `publicRides` from existing public rides (one admin script, dry run first, like the Maps revert script). Old app builds keep listing `rides` until `config/app.minBuild` passes the new build; then tighten `list`. | Ship the callable, then raise `minBuild`, then remove `list`. | Large. |

## Recommendation

**A now, B when the project moves to Blaze.** A closes the part that matters for safety (a blocked rider can't open the blocker's routes, start and end points included) without new infrastructure, and it keeps working on Spark. B is the complete answer and reuses A's `get` rule, so A is not wasted work. C is not worth it at this scale.

## What building A takes

1. Rules: `publicRides/{rideId}` readable by any signed-in rider; writable only by the ride's author, fields limited to the summary, and only together with the matching `rides/{rideId}` (same `userId`, `audience == 'public'`). `rides/{id}`: split `read` into `get` (with the block check on the public branch) and `list` (unchanged until `minBuild`).
2. App: write the summary in the same batch as a public ride (and delete it when the ride goes private or is deleted); feed reads `publicRides`; opening a ride does a `get`; handle `permission-denied` on that `get` as "not available".
3. Tests in `scripts/test/rules/`, written as the attacker: the blocked rider's `get` of the blocker's public ride is denied; a summary with a route field or another author's `userId` is denied; the feed `list` on `publicRides` passes.
4. A backfill script with dry run, `--apply` and a backup, then `minBuild`, then the `list` change.

## Open questions for the owner

- Is showing the blocker's summary row to the blocked rider acceptable until B? If not, the only Spark-compatible answer is to stop showing public rides from people who blocked you on the client and accept that it isn't enforced.
- Does the bug bounty (#166) treat "blocked rider sees the summary row" as in scope?
