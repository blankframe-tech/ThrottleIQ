# Parallel agents

When work is split across several implementation agents at once, give each agent its own git
worktree (`isolation: "worktree"`, or `git worktree add`) on its own branch, then merge the
branches one by one into the integration branch and run `scripts/check.sh` **once, after the
last merge** (it regenerates l10n). Each agent likewise runs it once at the end of its own work.

Why: agents sharing one checkout break each other mid-run. On 2026-10-09 a half-added set of
`tour*` l10n keys broke another agent's Android build, a `dart format` over a whole folder
rewrapped files another agent owned, and `arb_parity_test` failed on a third agent's strings.

Inside a worktree:
- Run `dart format` only on files you changed.
- Edit `app/lib/l10n/app_en.arb` / `app_bn.arb` with targeted inserts; merge conflicts there are
  expected and resolved at merge time, then regenerate with `flutter gen-l10n`.
- New Rides-tab charts go in their own family file under `stats/.../charts/` plus one registry
  line, never in a shared `switch`; `chart_registry_structure_test.dart` enforces this.
