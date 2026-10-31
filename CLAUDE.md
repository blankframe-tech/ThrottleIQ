# ThrottleIQ

- Project state, open issues and feature map: `DOCS/Handoff for agents and Todos/` (start with `HANDOFF_Document.md`).
- Always-on rules: `.agents/rules/` (QA gate, deploy pipeline, parallel agents).
- Quality gate: `scripts/check.sh`, once per change set (also run by CI and the pre-push hook).
- Deploying or releasing: the `deploy` skill / `scripts/deploy.sh`.
- Output rule: when the user says "output only X" / "nothing else", the final reply is exactly X: no summary, no ponytail footer. Still put full effort into the work itself (verify builds, versionCode, signing).
- Hard rule: always use ponytail + caveman; run `/retro` when a chat uses 60%+ of the 5h limit (`.agents/rules/efficiency-tools.md`).
