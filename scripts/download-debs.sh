#!/usr/bin/env bash
# download-debs.sh — Download .deb files for a given app + version.
# Reads architecture / URL info from apps.json.
# Usage: download-debs.sh <app_name> <version>
# Idempotent: skips files already present in the pool.
set -euo pipefail

APP_NAME="${1:?Usage: $0 <app_name> <version>}"
VERSION="${2:?Usage: $0 <app_name> <version>}"
APPS_JSON="apps.json"

APP=$(jq -e --arg n "$APP_NAME" '.[] | select(.name == $n)' "$APPS_JSON") \
  || { echo "ERROR: app '$APP_NAME' not found in $APPS_JSON"; exit 1; }

DISPLAY=$(echo "$APP" | jq -r '.display_name')
POOL_LETTER=$(echo "$APP" | jq -r '.pool_letter')
POOL_DIR="docs/pool/main/${POOL_LETTER}/${APP_NAME}"

echo "==> $DISPLAY $VERSION"
mkdir -p "$POOL_DIR"

ANY_NEW=0
while IFS=$'\t' read -r ARCH SUFFIX; do
  # Build URL and filename from templates
  URL_TPL=$(echo "$APP" | jq -r '.download_url')
  DEB_TPL=$(echo "$APP" | jq -r '.deb_pattern')
  URL=$(echo "$URL_TPL" | sed "s/\${VERSION}/$VERSION/g; s/\${SUFFIX}/$SUFFIX/g")
  PKG=$(echo "$DEB_TPL" | sed "s/\${VERSION}/$VERSION/g; s/\${SUFFIX}/$SUFFIX/g")

  DEST="$POOL_DIR/$PKG"
  if [ -f "$DEST" ]; then
    echo "  [skip]  $PKG"
    continue
  fi

  echo "  [fetch] $PKG"
  HTTP=$(curl -sSL -w "%{http_code}" -o "${DEST}.tmp" "$URL")
  if [ "$HTTP" = "200" ]; then
    mv "${DEST}.tmp" "$DEST"
    echo "  [ok]    $PKG ($(du -sh "$DEST" | cut -f1))"
    ANY_NEW=1
  else
    rm -f "${DEST}.tmp"
    echo "  [miss]  $PKG — HTTP $HTTP (not available upstream)"
  fi
done < <(echo "$APP" | jq -r '.architectures | to_entries[] | [.key, .value] | @tsv')

[ "$ANY_NEW" -eq 0 ] && echo "  (all files already present)"
echo ""