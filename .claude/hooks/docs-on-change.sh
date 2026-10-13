#!/bin/sh
# Stop hook: if project files changed, ask Claude to update the handoff docs
# in DOCS/Handoff for agents and Todos/ before stopping.
# Skips itself when only DOCS/ or .claude/ changed, when the handoff docs were
# already touched after the newest changed file, or when stop_hook_active is set.
input=$(cat)
if printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  printf '{}'; exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || { printf '{}'; exit 0; }

# Uncommitted + untracked + unpushed changes, minus docs and agent config.
changed=$( { git status --porcelain 2>/dev/null | cut -c4- | tr -d '"'; \
             git diff --name-only '@{u}..HEAD' 2>/dev/null; } | sort -u \
           | grep -Ev '^(DOCS/|\.claude/)' | head -20 )
if [ -z "$changed" ]; then printf '{}'; exit 0; fi

# Docs already updated after the newest code change: nothing to ask for.
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }
newest_code=0
for f in $changed; do
  [ -f "$f" ] || continue
  t=$(mtime "$f"); [ "$t" -gt "$newest_code" ] && newest_code=$t
done
newest_doc=0
for f in "DOCS/Handoff for agents and Todos"/*.md; do
  t=$(mtime "$f"); [ "$t" -gt "$newest_doc" ] && newest_doc=$t
done
if [ "$newest_doc" -ge "$newest_code" ]; then printf '{}'; exit 0; fi

printf '{"decision":"block","reason":"Before fully stopping: if this session changed app behavior, fixed or surfaced an issue, or changed project status, update features.md, HANDOFF_Document.md, and/or issues_open.md (new or still-open issues) / issues_fixed.md (resolved ones) in DOCS/Handoff for agents and Todos/ to reflect it (skip docs/pitch.md, which is off-limits unless the user asks). If nothing doc-worthy changed this session, no action is needed \\u2014 just say so briefly and stop."}'
