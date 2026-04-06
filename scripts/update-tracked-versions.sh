#!/usr/bin/env bash
# update-tracked-versions.sh — Upsert newly fetched versions into per-app tracking files.
# Usage: update-tracked-versions.sh <app_name> '<json-array-of-versions>'
# Tracking files live under tracked_versions/<app_name>.json
set -euo pipefail

APP_NAME="${1:?Usage: $0 <app_name> '<json-array>'}"
VERSIONS_JSON="${2:?Usage: $0 <app_name> '<json-array>'}"
APPS_JSON="apps.json"

APP=$(jq -e --arg n "$APP_NAME" '.[] | select(.name == $n)' "$APPS_JSON") \
  || { echo "ERROR: app '$APP_NAME' not found in $APPS_JSON"; exit 1; }

GITHUB_REPO=$(echo "$APP" | jq -r '.github_repo')
POOL_LETTER=$(echo "$APP" | jq -r '.pool_letter')
VERSION_PREFIX=$(echo "$APP" | jq -r '.version_prefix')
POOL="docs/pool/main/${POOL_LETTER}/${APP_NAME}"
FILE="tracked_versions/${APP_NAME}.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p tracked_versions
[ -f "$FILE" ] || echo "[]" > "$FILE"

echo "==> Updating $FILE..."

echo "$VERSIONS_JSON" | jq -r '.[]' | while read -r V; do
  # Detect which archs are actually in the pool for this version
  ARCHS="[]"
  while IFS=$'\t' read -r ARCH SUFFIX; do
    DEB_TPL=$(echo "$APP" | jq -r '.deb_pattern')
    PKG=$(echo "$DEB_TPL" | sed "s/\${VERSION}/$V/g; s/\${SUFFIX}/$SUFFIX/g")
    [ -f "$POOL/$PKG" ] && ARCHS=$(echo "$ARCHS" | jq --arg a "$ARCH" '. + [$a]')
  done < <(echo "$APP" | jq -r '.architectures | to_entries[] | [.key, .value] | @tsv')

  # Try to get the upstream release date
  TAG="${VERSION_PREFIX}${V}"
  REL_DATE=$(curl -sSf \
    "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${TAG}" \
    2>/dev/null | jq -r '.published_at // empty' || true)
  [ -z "$REL_DATE" ] && REL_DATE="$NOW"

  echo "  [track] $V  archs=$(echo "$ARCHS" | jq -r 'join(",")' )  released=$REL_DATE"

  ENTRY=$(jq -n \
    --arg  v  "$V"        \
    --arg  a  "$NOW"      \
    --arg  r  "$REL_DATE" \
    --argjson archs "$ARCHS" \
    '{"version":$v,"released_at":$r,"added_at":$a,"archs":$archs}')

  TMP=$(mktemp)
  jq --argjson e "$ENTRY" \
    'map(select(.version != $e.version)) + [$e] | sort_by(.version) | reverse' \
    "$FILE" > "$TMP"
  mv "$TMP" "$FILE"
done

echo "==> $FILE now has $(jq 'length' "$FILE") entries."