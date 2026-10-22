> DRAFT for owner review, 2026-10-22

# Proposed deploy and test rules (issues §107.1)

Source: `issues_open.md` §107.1, which carries three rules that lived only in
the retired `BIGGG_JOBB.md` §3.5-3.7, §3.9, §3.11 (old text:
`git show 3ebbd21d:"DOCS/Handoff for agents and Todos/BIGGG_JOBB.md"`).
Nothing below is merged yet. Each block says which existing file it would go
into and is written in that file's voice.

## 1. What `.agents/rules/` already covers

Checked all four files (`deploy.md`, `qa-gate.md`, `parallel-agents.md`,
`efficiency-tools.md`) on 2026-10-22.

| Rule | In `.agents/rules/`? | Where it is written today |
|---|---|---|
| A. Ship the app before a rule that tightens a write contract | No | `SECURITY.md` steps 1-3 (lines ~40-58) apply the same order to one case (the email migration, gated by `config/app.minBuild`). `issues_fixed.md` §78.27 marks that one case OBSOLETE; the general rule is BIGGG §3.7's last line. |
| B. Never `firebase deploy --force`; strip `__name__` before diffing indexes | No | `HANDOFF_Document.md:151` (both halves), `issues_open.md` §84 (lines 295-297), `SECURITY.md:64` ("If the CLI offers to delete indexes that are not in the file, answer no"). `HANDOFF_Document.md:148` also says: use `npx firebase-tools@15` and never run a bare `firebase deploy`. |
| C1. Tests never touch the network | No | Only in a code comment, `app/lib/shared/widgets/app_tile_layer.dart:83-93`. Nearest rule: `qa-gate.md` item 5 (real SQLite, no DAO mocks), which is about fakes, not the network. |
| C2. Cloud Functions cannot deploy on Spark | No | `HANDOFF_Document.md:62` and `:110` (Functions never deployed, project on Spark, owner item 3); `backend_options.md:3-6`. |

`deploy.md` today covers only the app release (QA, version bump, iPhone,
Android, GitHub release). `scripts/deploy.sh` contains no `firebase` command
(grep for `firebase` and `rules` returns nothing). So no rule file governs
Firebase deploys (rules, indexes, functions) at all. That is why A, B and C2
go into `deploy.md` as one new section.

## 2. Fact check of the §107.1 text

- `app_tile_layer.dart:95`: correct. The declaration is
  `app/lib/shared/widgets/app_tile_layer.dart:94-97`; line 95 is
  `Platform.environment.containsKey('FLUTTER_TEST')`, which selects
  `_BlankTileProvider` (class at `:236`) instead of `cachedTileProvider`. The
  doc comment above it (`:83-93`) says no HTTP request is made under
  `flutter test` and gives two reasons: Dio's pending timers failed screen
  tests, and the old `NetworkTileProvider` hit `tile.openstreetmap.org`.
- "Strip `__name__`": matches BIGGG §3.6 and `HANDOFF_Document.md:151`.
- "`firestore.rules` deployed first made new chats fail for old builds once
  (§78.27)": matches BIGGG §3.7. `issues_fixed.md` §78.27 (line ~5385) now
  says that specific case is OBSOLETE (the rule went live on 2026-09-21). The
  general rule still stands.
- "`artifactregistry` needs Blaze": matches BIGGG §3.11. Not checked against
  Google's docs from here.
- One stale number elsewhere: §84 says the index file went 12 → 16 on
  2026-09-21. `firestore.indexes.json` holds 20 composite indexes and 8 field
  overrides on 2026-10-22. Not a §107.1 fact, so it does not change the rules
  below.

## 3. Proposed text for `.agents/rules/deploy.md`

Append as a new section after step 6 ("Repeatable Script Alternative"):

```markdown
## Firebase deploys (rules, indexes, functions)

`scripts/deploy.sh` ships the app only; it never touches Firebase. Rules,
indexes and functions are deployed by hand, by the owner or on the owner's
explicit request, and these rules apply every time:

1. **Ship the app before any rule that tightens a write contract.**
   If a `firestore.rules` change refuses a write that a released build still
   makes, release the build with the matching client change first, raise
   `config/app.minBuild` to it (see `SECURITY.md` step 2), and only then deploy
   the rules. Deploying first breaks that write for every rider on an older
   build. It happened once: the chat-create rule made new chats fail for builds
   before the deterministic DM id (issues_fixed.md §78.27).

2. **Never run `firebase deploy --force`.** It deletes every live index that
   is missing from `firestore.indexes.json`, and a dropped index breaks its
   query in production at once (`failed-precondition`). If the CLI offers to
   delete indexes that are not in the file, answer no. Retire an index only
   through issues §84: remove it from the file and from the console together.
   - Name the targets (`--only firestore:rules`, `--only firestore:indexes`);
     never run a bare `firebase deploy`. Use `npx firebase-tools@15`.
   - When diffing live indexes against `firestore.indexes.json`, strip the
     implicit `__name__` field Firestore appends to every composite index
     first, or every index shows as a false mismatch.

3. **Cloud Functions cannot deploy on Spark.** The project is on Spark until
   the owner decides (owner item 3); deploying functions needs
   `artifactregistry.googleapis.com`, which needs Blaze. Server-side code
   written now fixes nothing in production until Blaze is on and the function
   is deployed. Don't report a `functions/` change as a fix for a live
   problem; say it is written and waits on Blaze.
```

## 4. Proposed text for `.agents/rules/qa-gate.md`

Insert as a new numbered item after item 5 ("Never mock DAOs in database
tests"), renumbering the items after it:

```markdown
6. **Tests never touch the network.** `flutter test` must make zero HTTP
   requests. `AppTileLayer` already swaps in a blank tile provider under
   `FLUTTER_TEST` (`app/lib/shared/widgets/app_tile_layer.dart:94-97`); keep
   it that way, and give any new network client the same seam (an injected
   Dio/Firestore/HTTP client, or an `FLUTTER_TEST` switch). A test that hits
   the network is flaky and slow, and fetching OSM tiles in bulk breaks
   OpenStreetMap's usage policy.
```

## 5. Open points for the owner

- Should rule 2 also forbid agents from running `firebase deploy` at all
  unless asked? `HANDOFF_Document.md:148` implies it; neither rules file says
  it. [PLACEHOLDER: owner decision]
- Rule 3 could be dropped from `deploy.md` once Blaze is enabled; keep a dated
  note instead? [PLACEHOLDER: owner decision]
- No guard in `scripts/check.sh` enforces rule 6 (the guards at `:99-134` are
  `as double`, the bare-catch ratchet and entitlements). A network-blocking
  test harness would be a separate task. [PLACEHOLDER: wanted or not]
