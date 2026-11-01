---
name: dev-feat
description: >-
  ThrottleIQ feature/fix workflow, from issue to merged PR. Use when the user
  says "dev feat", "develop feature", "dev fix", or /dev-feat followed by a
  request: create a GitHub issue assigned to the-abraar, build it on its own
  branch in a worktree, open a PR that closes the issue, merge it into main,
  and delete the branch.
---

# dev-feat

Saying "dev feat: <request>" authorizes every step below, including the merge
into `main`. Don't stop to ask before creating the issue, the PR, or merging.
Do stop and report if the gate fails and you can't fix it.

## 1. Issue

```bash
gh issue create --assignee the-abraar --label enhancement \
  --title "<short title>" --body "<what + acceptance bullets>"
```

Use `--label bug` for a fix. Keep the issue number `N`.

## 2. Branch in a worktree

The main checkout often holds the owner's uncommitted work. Never branch,
stash or commit there (`.agents/rules/parallel-agents.md`).

```bash
git fetch -q origin
git worktree add .claude/worktrees/<slug> -b feat/N-<slug> origin/main   # fix/N-<slug> for bugs
```

Do all edits, tests and commits inside that worktree.

## 3. Build it

- Follow `CLAUDE.md`, `.agents/rules/` and `DOCS/Handoff for agents and Todos/HANDOFF_Document.md`.
- Add tests for new logic. `firestore.rules` changes ship with deny tests in
  `scripts/test/rules/` (qa-gate rule 4).
- Run `scripts/check.sh` once from the worktree root when done. Zero failures.
- Stage files by explicit path, then commit with a conventional message
  (`feat(scope): …`, `fix(scope): …`) that ends with `Refs #N`.

## 4. PR

```bash
git push -u origin feat/N-<slug>     # pre-push hook reuses the check.sh pass
gh pr create --base main --assignee the-abraar \
  --title "<same as commit subject>" --body "Closes #N

<what changed, how it was verified, anything left to deploy>"
```

## 5. Merge and clean up

Run these from the main checkout, not the worktree:

```bash
gh pr checks <pr> --watch --fail-fast     # main requires CI (flutter, rules, CodeQL) to pass
gh pr merge <pr> --merge                   # merge commit, like the rest of main's history
gh issue view N --json state               # must be CLOSED; else: gh issue close N
git push origin --delete feat/N-<slug>
git worktree remove .claude/worktrees/<slug>
git branch -D feat/N-<slug>; git fetch -p -q origin
```

Don't pass `--delete-branch` to `gh pr merge`. It tries to check out `main`
locally, which fails because `main` is already checked out in the main
checkout. The merge still lands, but the branch is left behind.

If `gh pr merge` fails because the PR conflicts with `main`, rebase the
branch on `origin/main` in the worktree, re-run `scripts/check.sh`, then
force-push with lease and merge again.

Merging doesn't deploy anything. If the change touches `firestore.rules`,
`functions/`, or the app, tell the user it still needs a deploy (the
`deploy` skill / `firebase deploy --only firestore:rules`), and don't run one
unless they asked.

## 6. Report

Give the issue and PR links, the merge commit, the check.sh result, and
anything left undeployed.
