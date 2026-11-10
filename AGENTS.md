Frozen until 12 Play testers are opted in: only security, store/GTM, tester-reported bugs and the growth-loop fixes. No new screens, collections or strings beyond those. (Freeze option B, the default since 2026-11-02 in `~/Everything/dev/products/decision.md`.)

Agent rules (read before any change):
- No deploy without an explicit "OK to deploy X" from the owner in the same session; never run a bare `firebase deploy` (always `--only <target>`).
- Wait for CI to finish green on a PR before merging it.
- Never merge `mayabi` into `main` (and no cherry-picks from it without asking).
- Never upload a build to Play that the owner hasn't installed on his own phone first.

# ThrottleIQ agent pointers

- Start with `CLAUDE.md` (project rules) and `.agents/rules/`.
- Project state, open issues, todos: `DOCS/Handoff for agents and Todos/HANDOFF_Document.md`.
- Quality gate: `scripts/check.sh`, once per change set. Zero failures required.
- Review rules: `CODING_STANDARDS.md`.
