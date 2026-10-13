#!/bin/sh
# Stop hook: if UI-affecting app code changed, ask Claude to run the E2E
# integration test (app/integration_test/e2e_test.dart) before stopping.
# Skips itself when no UI file changed, when the same file list + device state
# was already reported (stamp in .git/claude-e2e-last), or when stop_hook_active is set.
input=$(cat)
if printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  printf '{}'; exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || { printf '{}'; exit 0; }

# Uncommitted + untracked + unpushed changes.
changed=$( { git status --porcelain 2>/dev/null | cut -c4-; \
             git diff --name-only '@{u}..HEAD' 2>/dev/null; } | sort -u )

ui=$(printf '%s\n' "$changed" | grep -E '^app/lib/(features/[^/]+/presentation/|shared/widgets/|core/(router|theme)/)|^app/integration_test/' | head -20)
if [ -z "$ui" ]; then printf '{}'; exit 0; fi

device=$(xcrun simctl list devices booted 2>/dev/null | grep -Eo '\([0-9A-F-]{36}\)' | head -1 | tr -d '()')

# Report each (file list, device) state once, not on every stop.
stamp_file="$(git rev-parse --git-dir 2>/dev/null)/claude-e2e-last"
stamp=$(printf '%s|%s' "$ui" "$device" | shasum | cut -d' ' -f1)
if [ -f "$stamp_file" ] && [ "$(cat "$stamp_file")" = "$stamp" ]; then printf '{}'; exit 0; fi
printf '%s' "$stamp" > "$stamp_file"
if [ -n "$device" ]; then
  how="A simulator is booted ($device). From app/, run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/e2e_test.dart -d $device. Report pass or fail. Do not hide a failure."
else
  how="No simulator or emulator is booted, so the test cannot run here. Say so in one line, name the changed UI files, and give this command for the user: cd app && flutter drive --driver=test_driver/integration_test.dart --target=integration_test/e2e_test.dart"
fi

reason="UI files changed this session:
$ui
$how Skip this only if the change cannot affect the Places/Saved/bottom-nav flow in the E2E test, and say why."
# JSON-escape: backslash, quote, newline.
esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS="\\n"}1')
printf '{"decision":"block","reason":"%s"}' "$esc"
