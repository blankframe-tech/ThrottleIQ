#!/usr/bin/env bash
# Deploys Firebase Hosting (public/ + firebase.json) for throttleiqfb, but only
# from a committed, pushed tree, so the live pages always match origin/main.
#
# Usage: bash scripts/deploy_hosting.sh
set -euo pipefail

cd "$(dirname "$0")/.."

git fetch -q origin main
DIRTY="$(git status --porcelain -- public firebase.json)"
if [ -n "$DIRTY" ]; then
  echo "❌ public/ or firebase.json has uncommitted changes:"
  echo "$DIRTY" | sed 's/^/    /'
  echo "Commit and push them first."
  exit 1
fi
if ! git merge-base --is-ancestor HEAD origin/main; then
  echo "❌ HEAD ($(git rev-parse --short HEAD)) is not on origin/main. Push or merge it to main first."
  exit 1
fi

echo "Deploying Hosting from $(git rev-parse --short HEAD) (on origin/main)..."
npx firebase-tools@15 deploy --only hosting --project throttleiqfb
