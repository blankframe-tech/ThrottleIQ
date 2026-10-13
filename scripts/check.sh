#!/usr/bin/env bash
# The one quality gate. Local runs, the pre-push hook, deploy.sh and CI all
# call this, so there is a single list of checks and it runs once per change
# set instead of analyze/test being re-run after every step.
#
# Usage: scripts/check.sh [--base <rev>] [--ci] [--force]
#   --base <rev>  diff base for "changed files" checks (default: merge-base
#                 with origin/main). CI passes the push/PR base.
#   --ci          CI mode: no pass stamp; rules and functions are left to
#                 their own CI jobs.
#   --force       run even if this exact commit already passed.
#   --covers <sha> exit 0 if an earlier pass covers <sha> (used by pre-push).
#
# Runs every check even after a failure and prints one summary, so a lint
# can't hide a test failure. On a clean tree, a pass is stamped in
# .git/throttleiq-check-passed (the HEAD sha); re-running on the same commit,
# and the pre-push hook, then return at once.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE=""; CI=false; FORCE=false
COVERS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --covers) COVERS="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --ci) CI=true; shift ;;
    --force) FORCE=true; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Hooks live in .githooks; point this clone at them (idempotent).
[ "$(git config core.hooksPath)" = ".githooks" ] || git config core.hooksPath .githooks

STAMP="$(git rev-parse --git-dir)/throttleiq-check-passed"
HEAD_SHA="$(git rev-parse HEAD)"
clean() { [ -z "$(git status --porcelain)" ]; }

# A pass covers <sha> if <sha> is the stamped commit, or descends from it
# through docs-only changes (DOCS/, *.md), which no check here reads.
stamp_covers() {
  local sha="$1" passed
  [ -f "$STAMP" ] || return 1
  passed="$(cat "$STAMP")"
  [ "$passed" = "$sha" ] && return 0
  git merge-base --is-ancestor "$passed" "$sha" 2>/dev/null || return 1
  [ -z "$(git diff --name-only "$passed" "$sha" | grep -vE '^DOCS/|\.md$')" ]
}
if [ -n "$COVERS" ]; then stamp_covers "$COVERS"; exit $?; fi

if [ "$CI" = false ] && [ "$FORCE" = false ] && clean && stamp_covers "$HEAD_SHA"; then
  echo "check: ${HEAD_SHA:0:7} already passed (use --force to re-run)."
  exit 0
fi

if [ -z "$BASE" ]; then
  BASE="$(git merge-base HEAD origin/main 2>/dev/null || git rev-parse HEAD~1)"
fi
if ! git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  echo "check: base '$BASE' not found; changed-file checks use HEAD~1."
  BASE="$(git rev-parse HEAD~1)"
fi

# Changed vs base, plus uncommitted and untracked (empty in CI).
changed() {
  { git diff --name-only --diff-filter=ACMR "$BASE" -- "$@"
    git ls-files --others --exclude-standard -- "$@"; } | sort -u
}

FAILED=()
step() { # step <name> <command...>
  local name="$1"; shift
  local t0=$SECONDS
  echo; echo "── $name"
  if "$@"; then echo "✔ $name ($((SECONDS - t0))s)"
  else echo "✘ $name ($((SECONDS - t0))s)"; FAILED+=("$name"); fi
}

# ── Checks ───────────────────────────────────────────────────────────────────

l10n() { (cd app && flutter gen-l10n >/dev/null) || return 1
  # Generated files must match the ARBs that were committed with them.
  if [ "$CI" = true ] && [ -n "$(git status --porcelain app/lib/l10n)" ]; then
    echo "Generated l10n is stale: run flutter gen-l10n and commit."; return 1; fi; }

format_changed() {
  local files
  files="$(changed 'app/*.dart' | grep -vE '(\.g\.dart|l10n/app_localizations.*\.dart)$' || true)"
  [ -z "$files" ] && { echo "No changed Dart files."; return 0; }
  echo "$files" | xargs dart format --output=none --set-exit-if-changed
}

# Raw `x['k'] as double` crashes on an int from Firestore/JSON (grill 78,
# §1.3.4). Use asDouble/asDoubleOrNull from core/utils/num_cast.dart.
guard_as_double() { ! grep -rnE "\] as double\b" app/lib; }

# Ratchet (§90.B6): bare `catch (_)` swallows errors. The count may only go
# down; lower MAX when you remove some. Prefer reportNonFatal
# (core/utils/error_reporter.dart) or a logged `catch (e)`.
CATCH_MAX=66
guard_bare_catch() {
  local n; n=$(grep -rn "catch (_)" app/lib | wc -l | tr -d ' ')
  echo "bare catch (_): $n (max $CATCH_MAX)"; [ "$n" -le "$CATCH_MAX" ]; }

# Team NJ4675FFUX is a personal Apple team: paid-only entitlements break every
# iPhone build. See .agents/skills/deploy/SKILL.md.
guard_entitlements() {
  ! grep -nE '<key>(com\.apple\.developer\.(associated-domains|icloud[^<]*|applesignin|usernotifications[^<]*)|aps-environment)</key>' \
    app/ios/*/*.entitlements; }

analyze() { (cd app && flutter analyze); }
tests() { (cd app && flutter test --reporter=failures-only); }

rules_if_changed() {
  if [ -z "$(changed firestore.rules database.rules.json 'scripts/test/rules/*')" ]; then
    echo "Rules unchanged; skipped."; return 0; fi
  (cd scripts && npm run --silent test:rules); }

functions_if_changed() {
  if [ -z "$(changed 'functions/src/*' 'functions/test/*' functions/package.json)" ]; then
    echo "Functions unchanged; skipped."; return 0; fi
  (cd functions && npm run --silent build && npm test --silent); }

step "l10n generate" l10n
step "format (changed files)" format_changed
step "guard: raw as double" guard_as_double
step "guard: bare catch ratchet" guard_bare_catch
step "guard: paid-only entitlements" guard_entitlements
step "flutter analyze" analyze
step "flutter test" tests
if [ "$CI" = false ]; then
  step "rules tests (if changed)" rules_if_changed
  step "functions (if changed)" functions_if_changed
fi

echo
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "check: FAILED — ${FAILED[*]}"
  exit 1
fi
if [ "$CI" = false ] && clean; then echo "$HEAD_SHA" > "$STAMP"; fi
echo "check: all passed (${SECONDS}s)."
