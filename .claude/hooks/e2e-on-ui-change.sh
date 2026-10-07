#!/bin/sh
# Stop hook: if UI-affecting app code changed, ask Claude to run the E2E
# integration test (app/integration_test/e2e_test.dart) before stopping.
# Skips itself when no UI file changed, or when stop_hook_active is set (no loops).
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
