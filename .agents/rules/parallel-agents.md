# Parallel agents

When work is split across several implementation agents at once, create a github issue for each of them, assign 'the-abraar' account. Then give each agent its own git worktree (`isolation: "worktree"`, or `git worktree add`) on its own branch, then then merge the
branches one by one into the integration branch and run `scripts/check.sh` **once, after the
last merge** (it regenerates l10n). Each agent likewise runs it once at the end of its own work. then close the issues and the PRs. 

Security work is the exception: never open a public issue, PR description or commit message that
explains an unfixed weakness. Open it as a draft GitHub security advisory (Security → Advisories →
New draft; agents without access hand it to the owner), keep the working notes in git-ignored
`DOCS/private/`, and use a neutral title ("rules: tighten X validation") with no exploit steps
until the fix is deployed. Public docs name the area only: "known: <area> hardening pending, not
eligible" (`SECURITY.md`).

Why: agents sharing one checkout break each other mid-run. On 2026-10-09 a half-added set of
`tour*` l10n keys broke another agent's Android build, a `dart format` over a whole folder
rewrapped files another agent owned, and `arb_parity_test` failed on a third agent's strings.

The same applies to separate Claude Code sessions started by hand: every parallel session gets its
own worktree and branch, and the branches are merged into `main` one at a time. On 2026-10-15 three
sessions shared one checkout. The first "commit and push all" swept the others' work into `8bdb803`,
and a repo-wide `dart format` plus a `git checkout -- app` left churn in `main`'s history.

Committing:
- Stage only the files this session changed, by explicit path. Treat "commit all" as "commit only
  your files". Never `git add -A` / `git add .` while another session may share the tree.
- Never run `git checkout --`, `git restore`, `git stash` or `git reset` on paths you didn't change.
- If `git status` shows changes you didn't make, leave them and report them; don't commit them.

Inside a worktree:
- Run `dart format` only on files you changed.
- Edit `app/lib/l10n/app_en.arb` / `app_bn.arb` with targeted inserts; merge conflicts there are
  expected and resolved at merge time, then regenerate with `flutter gen-l10n`.
- New Rides-tab charts go in their own family file under `stats/.../charts/` plus one registry
  line, never in a shared `switch`; `chart_registry_structure_test.dart` enforces this.
