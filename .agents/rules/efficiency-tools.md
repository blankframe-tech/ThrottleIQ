---
trigger: always_on
---

# Efficiency Tooling — Always-On Rules

1. **Always use ponytail and caveman** on every task in this repo. Both must be
   active (`claude-work`/`-hat`/`-biz` or plain `claude`). Do not disable them,
   switch them off, or work around them. If either is missing, tell the user
   how to fix it; do not continue silently.
   - ponytail: `claude plugin install ponytail@ponytail`
   - caveman: `python3 -I ~/Everything/dev/tools/ensure_caveman.py fix`
2. **Retro at 60%**: when a single chat has consumed 60% or more of the
   5-hour usage limit, run `/retro` (from the `mattpocock-skills` plugin; user-invocable only, so ask the user to type it).
   The statusline shows `chat N% of 5h limit`; `.claude/hooks/retro-guard.sh`
   asks the user automatically.
   - install: `claude plugin install mattpocock-skills@claude-plugins-official`
