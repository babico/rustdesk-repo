#!/usr/bin/env bash
# download-debs.sh — Download all RustDesk .deb packages for a given version
set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"
DEB_DIR="docs/pool/main/r/rustdesk"

echo "==> Downloading RustDesk $VERSION .deb packages..."
mkdir -p "$DEB_DIR"

BASE_URL="https://github.com/rustdesk/rustdesk/releases/download/${VERSION}"

declare -A PACKAGES=(
  ["rustdesk-${VERSION}-x86_64.deb"]="amd64"
  ["rustdesk-${VERSION}-aarch64.deb"]="arm64"
  ["rustdesk-${VERSION}-armv7-sciter.deb"]="armhf"
)

for PKG in "${!PACKAGES[@]}"; do
  DEST="$DEB_DIR/$PKG"
  URL="$BASE_URL/$PKG"

  if [ -f "$DEST" ]; then
    echo "  [skip] $PKG already exists"
    continue
  fi

  echo "  [download] $PKG"
  HTTP_STATUS=$(curl -sSL -w "%{http_code}" -o "$DEST" "$URL")

  if [ "$HTTP_STATUS" -eq 200 ]; then
    SIZE=$(du -sh "$DEST" | cut -f1)
    echo "  [ok] $PKG ($SIZE)"
  else
    echo "  [warn] $PKG not available (HTTP $HTTP_STATUS), skipping"
    rm -f "$DEST"
  fi
done

echo "==> Download complete."
ls -lh "$DEB_DIR"/*.deb 2>/dev/null || echo "(no .deb files found)"