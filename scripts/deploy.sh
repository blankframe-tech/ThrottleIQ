#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# ThrottleIQ End-to-End Deployment Script
#
# Pipeline:
#   1. Commit release changes
#   2. Quality gate (scripts/check.sh) and push the current branch
#   3. Build and launch release build on connected iPhone
#   4. Create GitHub Release with tag and notes only (no binaries)
#
# No Android build: Android installs come only from Google Play, and the
# Play upload (versionCode = pubspec build number) is done by hand.
#
# Usage:
#   bash scripts/deploy.sh [OPTIONS]
#
# Options:
#   --skip-qa         Skip static analysis and unit test suite
#   --skip-ios        Skip building and installing on connected iPhone
#   --skip-github     Skip creating GitHub release tag
#   --device <id>     Specify iOS device id (defaults to auto-detect connected iPhone)
#   --tag <tag>       Specify release tag (defaults to derived from pubspec.yaml)
#   --help            Show this help message
# ─────────────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${REPO_ROOT}/app"

SKIP_QA=false
SKIP_IOS=false
SKIP_GITHUB=false
IOS_DEVICE_ID=""
RELEASE_TAG=""
RELEASE_NOTES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-qa)
      SKIP_QA=true
      shift
      ;;
    --skip-ios)
      SKIP_IOS=true
      shift
      ;;
    --skip-github)
      SKIP_GITHUB=true
      shift
      ;;
    --device)
      IOS_DEVICE_ID="$2"
      shift 2
      ;;
    --tag)
      RELEASE_TAG="$2"
      shift 2
      ;;
    --notes)
      RELEASE_NOTES="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '3,25p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

echo "========================================================"
echo "           🚀 ThrottleIQ Deployment Pipeline            "
echo "========================================================"

# 1. Version extraction
PUBSPEC_VERSION=$(grep '^version:' "${APP_DIR}/pubspec.yaml" | sed 's/version: //; s/"//g; s/'\''//g')
echo "📦 App Version in pubspec: ${PUBSPEC_VERSION}"

if [ -z "$RELEASE_TAG" ]; then
  # Derive tag from pubspec version: e.g. 1.0.0-beta.2.6+11 -> beta-v2.6
  if [[ "$PUBSPEC_VERSION" =~ beta\.([0-9.]+) ]]; then
    RELEASE_TAG="beta-v${BASH_REMATCH[1]}"
  else
    RELEASE_TAG="v${PUBSPEC_VERSION%%+*}"
  fi
fi
echo "🏷️ Target Release Tag: ${RELEASE_TAG}"

# 2. Commit (before the gate, so the gate stamps the exact commit pushed)
echo ""
echo "==> [1/4] Committing release changes..."
cd "${REPO_ROOT}"
# Never auto-stage new files (issues §101.S9): a stray secret dropped in the
# tree (.env.production, a .p12, a service-account key) would otherwise be
# committed and pushed. Anything untracked must be committed or ignored by
# hand first.
UNTRACKED_FILES="$(git ls-files --others --exclude-standard)"
if [ -n "${UNTRACKED_FILES}" ]; then
  echo "❌ Untracked files in the working tree — refusing to auto-commit them:"
  echo "${UNTRACKED_FILES}" | sed 's/^/    /'
  echo "Commit them yourself, add them to .gitignore, or remove them, then re-run."
  exit 1
fi
# Only the version bump is committed here: any other dirty tracked file is
# unfinished work that must not ship under a "chore(release)" commit.
OTHER_DIRTY="$(git diff --name-only HEAD -- . ':(exclude)app/pubspec.yaml')"
if [ -n "${OTHER_DIRTY}" ]; then
  echo "❌ Tracked files other than app/pubspec.yaml have uncommitted changes:"
  echo "${OTHER_DIRTY}" | sed 's/^/    /'
  echo "Commit or stash them yourself, then re-run."
  exit 1
fi
if ! git diff --quiet HEAD -- app/pubspec.yaml; then
  echo "Committing the app/pubspec.yaml version bump..."
  git add app/pubspec.yaml
  git commit -m "chore(release): bump version to ${PUBSPEC_VERSION}"
else
  echo "Working tree is clean."
fi

# 3. Quality gate: scripts/check.sh is the single gate (also run by CI and
# the pre-push hook). It stamps the commit, so the push below doesn't re-run it.
if [ "$SKIP_QA" = false ]; then
  echo ""
  echo "==> [2/4] Running quality gate (scripts/check.sh)..."
  bash "${REPO_ROOT}/scripts/check.sh"
  echo "✅ QA Gate Passed!"
else
  echo ""
  echo "==> [2/4] QA Gate skipped (--skip-qa)"
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Pushing ${CURRENT_BRANCH} to origin..."
if [ "$SKIP_QA" = true ]; then git push --no-verify origin "${CURRENT_BRANCH}"; else git push origin "${CURRENT_BRANCH}"; fi
echo "✅ Git push complete!"

# Map tile provider (issues §78.16). The public OpenStreetMap tile server is not
# for a released app (its usage policy asks apps not to bulk-fetch). Export
# TILE_URL_TEMPLATE / TILE_API_KEY / TILE_ATTRIBUTION before running this script
# and they are passed to every release build below as --dart-define; AppTileLayer
# reads them. Whatever is unset is simply not defined. See app_tile_layer.dart.
# Local, git-ignored provider settings (secret/tiles.env) fill in whatever isn't exported.
TILES_ENV="$(dirname "$0")/../secret/tiles.env"
# shellcheck disable=SC1090
[ -z "${TILE_URL_TEMPLATE:-}" ] && [ -f "$TILES_ENV" ] && . "$TILES_ENV"
TILE_DEFINES=()
[ -n "${TILE_URL_TEMPLATE:-}" ] && TILE_DEFINES+=("--dart-define=TILE_URL_TEMPLATE=${TILE_URL_TEMPLATE}")
[ -n "${TILE_API_KEY:-}" ] && TILE_DEFINES+=("--dart-define=TILE_API_KEY=${TILE_API_KEY}")
[ -n "${TILE_ATTRIBUTION:-}" ] && TILE_DEFINES+=("--dart-define=TILE_ATTRIBUTION=${TILE_ATTRIBUTION}")
if [ -z "${TILE_URL_TEMPLATE:-}" ]; then
  echo "NOTE: TILE_URL_TEMPLATE is not set — release builds will use the public OpenStreetMap tile server. Fine for testing, not for a launch (issues §78.16)."
fi

# 4. iOS Release run
if [ "$SKIP_IOS" = false ]; then
  echo ""
  echo "==> [3/4] Deploying Release build to connected iPhone..."
  cd "${APP_DIR}"
  if [ -z "$IOS_DEVICE_ID" ]; then
    # Auto-detect connected iOS device ID
    DETECTED_DEVICE=$(flutter devices 2>/dev/null | grep -i "ios" | grep -v "macOS" | head -n 1 | awk -F '•' '{print $2}' | tr -d ' ' || true)
    if [ -n "$DETECTED_DEVICE" ]; then
      IOS_DEVICE_ID="$DETECTED_DEVICE"
    else
      # Default fallback
      IOS_DEVICE_ID="00008120-001E5D190A85A01E"
    fi
  fi
  echo "Targeting iOS Device: ${IOS_DEVICE_ID}"
  flutter run --release -d "${IOS_DEVICE_ID}" ${TILE_DEFINES[@]+"${TILE_DEFINES[@]}"}
  cd "${REPO_ROOT}"
  echo "✅ iOS Release run complete!"
else
  echo ""
  echo "==> [3/4] iOS release run skipped (--skip-ios)"
fi

# 5. GitHub Release
if [ "$SKIP_GITHUB" = false ]; then
  echo ""
  echo "==> [4/4] Creating GitHub Release (${RELEASE_TAG})..."
  cd "${REPO_ROOT}"
  
  if [ -z "$RELEASE_NOTES" ]; then
    # Generate notes from recent commits
    PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$PREV_TAG" ]; then
      COMMITS_LOG=$(git log "${PREV_TAG}..HEAD" --pretty=format:"- %s" || echo "")
    else
      COMMITS_LOG=$(git log -n 10 --pretty=format:"- %s")
    fi

    RELEASE_NOTES=$(cat <<EOF
## 🏍️ ThrottleIQ Release ${RELEASE_TAG} (v${PUBSPEC_VERSION})

### Recent Updates
${COMMITS_LOG}

### Install
Android builds ship through Google Play only: https://throttleiqfb.web.app/install
EOF
)
  fi

  # Create tag and release via gh CLI
  # --target: without it gh tags the default branch's head, not this commit.
  gh release create "${RELEASE_TAG}" \
    --target "$(git rev-parse HEAD)" \
    --title "ThrottleIQ — ${RELEASE_TAG} (v${PUBSPEC_VERSION})" \
    --notes "${RELEASE_NOTES}"

  echo "✅ GitHub Release created: https://github.com/blankframe-tech/ThrottleIQ/releases/tag/${RELEASE_TAG}"
else
  echo ""
  echo "==> [4/4] GitHub release skipped (--skip-github)"
fi

echo ""
echo "🎉 Deployment Complete!"
