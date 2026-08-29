#!/usr/bin/env bash
set -euo pipefail

# One-shot publish of the already-built AAB (versionCode 4) to the Internal
# testing track via the Android Publisher API. Run this yourself from the
# repo root:
#
#   bash scripts/publish_release.sh
#
# Requires secrets/new.txt to contain a fresh androidpublisher-scoped token
# (re-run the gcloud auth commands first if it's more than ~1hr old).

cd "$(dirname "$0")/.."

PKG="com.bft.throttleiq"
VERSION_CODE="4"
AAB="app/build/app/outputs/bundle/release/app-release.aab"

TOKEN=$(grep -o 'ya29\.[A-Za-z0-9_.\-]*' secrets/new.txt | head -1)
if [ -z "$TOKEN" ]; then
  echo "ERROR: couldn't find a ya29.* token in secrets/new.txt. Re-run the gcloud auth step first."
  exit 1
fi

if [ ! -f "$AAB" ]; then
  echo "ERROR: $AAB not found. Run 'flutter build appbundle' in app/ first."
  exit 1
fi

echo "==> Creating edit session..."
EDIT_JSON=$(curl -sS -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}/edits")
echo "$EDIT_JSON"
EDIT_ID=$(echo "$EDIT_JSON" | jq -r '.id // empty')
if [ -z "$EDIT_ID" ]; then
  echo "ERROR: no edit id in response above. Stopping — check the error before retrying."
  exit 1
fi
echo "    editId = $EDIT_ID"

echo "==> Uploading AAB (this can take a minute for 78MB)..."
BUNDLE_JSON=$(curl -sS -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"${AAB}" \
  "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${PKG}/edits/${EDIT_ID}/bundles?uploadType=media")
echo "$BUNDLE_JSON"
GOT_VERSION_CODE=$(echo "$BUNDLE_JSON" | jq -r '.versionCode // empty')
if [ "$GOT_VERSION_CODE" != "$VERSION_CODE" ]; then
  echo "ERROR: expected versionCode $VERSION_CODE, got '$GOT_VERSION_CODE'. Stopping — do not proceed to track/commit."
  exit 1
fi
echo "    uploaded versionCode = $GOT_VERSION_CODE"

echo "==> Assigning versionCode $VERSION_CODE to the internal testing track..."
TRACK_JSON=$(curl -sS -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"track\":\"internal\",\"releases\":[{\"versionCodes\":[\"${VERSION_CODE}\"],\"status\":\"completed\"}]}" \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}/edits/${EDIT_ID}/tracks/internal")
echo "$TRACK_JSON"
TRACK_NAME=$(echo "$TRACK_JSON" | jq -r '.track // empty')
if [ "$TRACK_NAME" != "internal" ]; then
  echo "ERROR: track update didn't come back as 'internal'. Stopping — do not commit."
  exit 1
fi

echo "==> Committing the edit (this is the actual publish step)..."
COMMIT_JSON=$(curl -sS -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PKG}/edits/${EDIT_ID}:commit")
echo "$COMMIT_JSON"

echo "==> Done. versionCode $VERSION_CODE should now be on the internal testing track."
