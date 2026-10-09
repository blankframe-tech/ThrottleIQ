#!/bin/sh
# UserPromptSubmit hook, two jobs:
#  1. Hard rule: ponytail + caveman must be active in this config dir; if not, tell
#     Claude to flag it to the user instead of silently running without them.
#  2. If retro-statusline.sh flagged this chat as >=60% of the 5h limit, ask
#     the user to type /retro (once per chat; the skill is user-invocable only).
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty')
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
msg=""

grep -q '"ponytail@ponytail"' "$cfg/plugins/installed_plugins.json" 2>/dev/null ||
  msg="$msg PROJECT RULE VIOLATED: ponytail plugin is not installed in $cfg. Tell the user to run: CLAUDE_CONFIG_DIR=$cfg claude plugin install ponytail@ponytail."
grep -q 'caveman' "$cfg/settings.json" 2>/dev/null ||
  msg="$msg PROJECT RULE VIOLATED: caveman hooks are missing in $cfg. Tell the user to run: python3 -I ~/Everything/dev/tools/ensure_caveman.py fix."

grep -q '"mattpocock-skills@' "$cfg/plugins/installed_plugins.json" 2>/dev/null ||
  msg="$msg PROJECT RULE VIOLATED: the /retro skill (mattpocock-skills) is not installed in $cfg. Tell the user to run: CLAUDE_CONFIG_DIR=$cfg claude plugin install mattpocock-skills@claude-plugins-official."

flag="$cfg/retro-guard/$sid.flag"
if [ -n "$sid" ] && [ -f "$flag" ] && [ ! -f "$flag.done" ]; then
  : > "$flag.done"
  msg="$msg This chat has used 60%+ of the 5-hour limit. Tell the user, at the start of your reply, to type /retro now (it cannot be invoked by Claude)."
fi

[ -n "$msg" ] || exit 0
jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}'
