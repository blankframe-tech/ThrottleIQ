#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# ThrottleIQ End-to-End Deployment Script
#
# Pipeline:
#   1. Pre-flight QA & Guardian checks
#   2. Commit & Push to origin/master
#   3. Build and launch release build on connected iPhone
#   4. Build Android APK & AAB
#   5. Create GitHub Release with tag and attach APK & AAB
#
# Usage:
#   bash scripts/deploy.sh [OPTIONS]
#
# Options:
#   --skip-qa         Skip static analysis and unit test suite
#   --skip-ios        Skip building and installing on connected iPhone
#   --skip-android    Skip building Android APK & AAB
#   --skip-github     Skip creating GitHub release tag
#   --device <id>     Specify iOS device id (defaults to auto-detect connected iPhone)
#   --tag <tag>       Specify release tag (defaults to derived from pubspec.yaml)
#   --help            Show this help message
# ─────────────────────────────────────────────────────────────────────────────

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${REPO_ROOT}/app"

SKIP_QA=false
SKIP_IOS=false
SKIP_ANDROID=false
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
    --skip-android)
      SKIP_ANDROID=true
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
      sed -n '3,24p' "$0" | sed 's/^# \?//'
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

# 2. QA Gate
if [ "$SKIP_QA" = false ]; then
  echo ""
  echo "==> [1/5] Running Quality Gate (analyze + test)..."
  cd "${APP_DIR}"
  echo "--- Running static analysis ---"
  flutter analyze --no-fatal-infos
  echo "--- Running test suite ---"
  flutter test
  echo "--- Checking onboarding guardian compilation ---"
  dart analyze \
    lib/features/auth/presentation/screens/onboarding_manifest.dart \
    lib/features/auth/presentation/screens/onboarding_tour_provider.dart \
    lib/features/auth/presentation/screens/onboarding_screen.dart \
    lib/features/auth/presentation/widgets/onboarding_slide_page.dart \
    lib/features/profile/presentation/screens/edit_profile_screen.dart
  cd "${REPO_ROOT}"
  echo "✅ QA Gate Passed!"
else
  echo ""
  echo "==> [1/5] QA Gate skipped (--skip-qa)"
fi

# 3. Commit & Push
echo ""
echo "==> [2/5] Committing & Pushing to GitHub..."
cd "${REPO_ROOT}"
if [ -n "$(git status --porcelain)" ]; then
  echo "Found uncommitted changes. Staging and committing..."
  git add -A
  git commit -m "chore(release): bump version to ${PUBSPEC_VERSION} and update deployment artifacts"
else
  echo "Working tree is clean."
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Pushing ${CURRENT_BRANCH} to origin..."
git push origin "${CURRENT_BRANCH}"
echo "✅ Git push complete!"

# 4. iOS Release run
if [ "$SKIP_IOS" = false ]; then
  echo ""
  echo "==> [3/5] Deploying Release build to connected iPhone..."
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
  flutter run --release -d "${IOS_DEVICE_ID}"
  cd "${REPO_ROOT}"
  echo "✅ iOS Release run complete!"
else
  echo ""
  echo "==> [3/5] iOS release run skipped (--skip-ios)"
fi

# 5. Android Builds (APK & AAB)
if [ "$SKIP_ANDROID" = false ]; then
  echo ""
  echo "==> [4/5] Building Android Release Binaries (APK & AAB)..."
  cd "${APP_DIR}"
  echo "--- Building release APK ---"
  flutter build apk --release
  APK_PATH="${APP_DIR}/build/app/outputs/flutter-apk/app-release.apk"
  if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK build failed — file not found: $APK_PATH" >&2
    exit 1
  fi
  echo "APK ready: $APK_PATH ($(du -h "$APK_PATH" | cut -f1))"

  echo "--- Building release AAB ---"
  flutter build appbundle --release
  AAB_PATH="${APP_DIR}/build/app/outputs/bundle/release/app-release.aab"
  if [ ! -f "$AAB_PATH" ]; then
    echo "❌ AAB build failed — file not found: $AAB_PATH" >&2
    exit 1
  fi
  echo "AAB ready: $AAB_PATH ($(du -h "$AAB_PATH" | cut -f1))"
  cd "${REPO_ROOT}"
  echo "✅ Android builds complete!"
else
  echo ""
  echo "==> [4/5] Android build skipped (--skip-android)"
fi

# 6. GitHub Release
if [ "$SKIP_GITHUB" = false ]; then
  echo ""
  echo "==> [5/5] Creating GitHub Release (${RELEASE_TAG})..."
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

### Binaries Attached
- \`app-release.apk\` (Direct Android Install)
- \`app-release.aab\` (Google Play App Bundle)
EOF
)
  fi

  APK_ATTACH="${APP_DIR}/build/app/outputs/flutter-apk/app-release.apk"
  AAB_ATTACH="${APP_DIR}/build/app/outputs/bundle/release/app-release.aab"

  ATTACHMENTS=()
  [ -f "$APK_ATTACH" ] && ATTACHMENTS+=("$APK_ATTACH")
  [ -f "$AAB_ATTACH" ] && ATTACHMENTS+=("$AAB_ATTACH")

  # Create tag and release via gh CLI
  gh release create "${RELEASE_TAG}" "${ATTACHMENTS[@]}" \
    --title "ThrottleIQ — ${RELEASE_TAG} (v${PUBSPEC_VERSION})" \
    --notes "${RELEASE_NOTES}"

  echo "✅ GitHub Release created: https://github.com/blankframe-tech/ThrottleIQ/releases/tag/${RELEASE_TAG}"
else
  echo ""
  echo "==> [5/5] GitHub release skipped (--skip-github)"
fi

echo ""
echo "🎉 Deployment Complete!"
