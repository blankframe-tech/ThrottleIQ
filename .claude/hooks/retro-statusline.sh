#!/bin/sh
# statusLine command: tracks how much of the 5-hour limit THIS chat has consumed.
# Baseline = five_hour.used_percentage the first time the session is seen (reset
# when the window rolls over). At >=60 points consumed it drops a flag that
# retro-guard.sh turns into a "run /retro" instruction. Needs jq; claude.ai
# Pro/Max only (rate_limits is absent otherwise, so this is then a no-op).
THRESHOLD=60
in=$(cat)
sid=$(printf '%s' "$in" | jq -r '.session_id // empty')
pct=$(printf '%s' "$in" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rst=$(printf '%s' "$in" | jq -r '.rate_limits.five_hour.resets_at // empty')
[ -n "$sid" ] && [ -n "$pct" ] || exit 0

dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/retro-guard"; mkdir -p "$dir"
base="$dir/$sid.base"
if [ -f "$base" ]; then
  read -r b_pct b_rst < "$base"
  # Window rolled over since baseline: this chat's usage in the new window starts at 0.
  [ "$b_rst" != "$rst" ] && { b_pct=0; printf '%s %s\n' 0 "$rst" > "$base"; }
else
  b_pct=$pct; printf '%s %s\n' "$pct" "$rst" > "$base"
fi
used=$(awk -v p="$pct" -v b="$b_pct" 'BEGIN{d=p-b; if(d<0)d=0; printf "%d", d}')
if [ "$used" -ge "$THRESHOLD" ]; then
  [ -f "$dir/$sid.flag" ] || : > "$dir/$sid.flag"
  printf 'chat %s%% of 5h limit | RETRO DUE' "$used"
else
  printf 'chat %s%% of 5h limit' "$used"
fi
