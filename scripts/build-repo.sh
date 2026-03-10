#!/usr/bin/env bash
# build-repo.sh — Build a proper APT repository from downloaded .deb files
set -euo pipefail

VERSION="${1:?Usage: $0 <version> [gpg_key_id] [gpg_passphrase]}"
GPG_KEY_ID="${2:-}"
GPG_PASSPHRASE="${3:-}"

REPO_ROOT="docs"
DIST="stable"
COMPONENT="main"
POOL_DIR="$REPO_ROOT/pool/$COMPONENT/r/rustdesk"
DISTS_DIR="$REPO_ROOT/dists/$DIST"

echo "==> Building APT repository structure..."

# Map .deb filenames to architectures
declare -A ARCH_MAP=(
  ["x86_64"]="amd64"
  ["aarch64"]="arm64"
  ["armv7-sciter"]="armhf"
)

# Process each architecture
for ARCH_KEY in "${!ARCH_MAP[@]}"; do
  APT_ARCH="${ARCH_MAP[$ARCH_KEY]}"
  DEB_FILE=$(find "$POOL_DIR" -name "*-${ARCH_KEY}.deb" 2>/dev/null | head -1)

  if [ -z "$DEB_FILE" ]; then
    echo "  [skip] No .deb found for $ARCH_KEY"
    continue
  fi

  PKG_DIR="$DISTS_DIR/$COMPONENT/binary-$APT_ARCH"
  mkdir -p "$PKG_DIR"

  echo "  [index] $APT_ARCH ($DEB_FILE)"

  # Generate Packages file for this arch
  # Path must be relative to repo root for apt to resolve pool paths
  (cd "$REPO_ROOT" && dpkg-scanpackages --arch "$APT_ARCH" \
    "pool/$COMPONENT/r/rustdesk" /dev/null 2>/dev/null \
    | grep -A 999 "Architecture: $APT_ARCH" \
    > "dists/$DIST/$COMPONENT/binary-$APT_ARCH/Packages" || true)

  # If the above grep approach misses files, fall back to full scan
  if [ ! -s "$PKG_DIR/Packages" ]; then
    (cd "$REPO_ROOT" && dpkg-scanpackages "pool/$COMPONENT/r/rustdesk" /dev/null \
      > "dists/$DIST/$COMPONENT/binary-$APT_ARCH/Packages" 2>/dev/null || true)
  fi

  gzip -9 -k -f "$PKG_DIR/Packages"
  echo "  [ok] $APT_ARCH Packages file generated"
done

# ── Generate Release file ──────────────────────────────────────────────────────
echo "==> Generating Release file..."

REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-your-github-username}"
REPO_NAME="${GITHUB_REPOSITORY:-your-github-username/rustdesk-apt}"
PAGES_URL="https://${REPO_OWNER}.github.io/${REPO_NAME##*/}"

cat > "$DISTS_DIR/Release" <<EOF
Origin: RustDesk APT Mirror
Label: RustDesk
Suite: $DIST
Codename: $DIST
Version: $VERSION
Architectures: amd64 arm64 armhf
Components: $COMPONENT
Description: Unofficial APT mirror for RustDesk releases
Date: $(date -Ru)
EOF

# Append checksums (MD5, SHA1, SHA256, SHA512)
for ALGO in MD5Sum SHA1 SHA256 SHA512; do
  echo "$ALGO:" >> "$DISTS_DIR/Release"
  find "$DISTS_DIR/$COMPONENT" -type f | sort | while read -r FILE; do
    REL_PATH="${FILE#$DISTS_DIR/}"
    SIZE=$(stat -c%s "$FILE")
    case "$ALGO" in
      MD5Sum)  SUM=$(md5sum    "$FILE" | awk '{print $1}') ;;
      SHA1)    SUM=$(sha1sum   "$FILE" | awk '{print $1}') ;;
      SHA256)  SUM=$(sha256sum "$FILE" | awk '{print $1}') ;;
      SHA512)  SUM=$(sha512sum "$FILE" | awk '{print $1}') ;;
    esac
    printf " %s %s %s\n" "$SUM" "$SIZE" "$REL_PATH"
  done >> "$DISTS_DIR/Release"
done

# ── Sign the Release file ──────────────────────────────────────────────────────
if [ -n "$GPG_KEY_ID" ]; then
  echo "==> Signing Release file with GPG key $GPG_KEY_ID..."

  export GPG_TTY=$(tty 2>/dev/null || true)

  if [ -n "$GPG_PASSPHRASE" ]; then
    GPGOPTS="--batch --passphrase-fd 0 --pinentry-mode loopback"
  else
    GPGOPTS="--batch"
  fi

  # InRelease (inline signature)
  echo "$GPG_PASSPHRASE" | gpg $GPGOPTS \
    --default-key "$GPG_KEY_ID" \
    --clearsign \
    --output "$DISTS_DIR/InRelease" \
    "$DISTS_DIR/Release"

  # Release.gpg (detached signature)
  echo "$GPG_PASSPHRASE" | gpg $GPGOPTS \
    --default-key "$GPG_KEY_ID" \
    --detach-sign --armor \
    --output "$DISTS_DIR/Release.gpg" \
    "$DISTS_DIR/Release"

  # Export public key for users to import
  gpg --armor --export "$GPG_KEY_ID" > "$REPO_ROOT/rustdesk-apt.gpg"
  echo "==> Repository signed successfully."
else
  echo "==> WARNING: Skipping GPG signing (no key configured)."
  echo "    Users will need 'trusted=yes' in their sources.list entry."
fi

echo "==> APT repository build complete."
echo ""
echo "Repository tree:"
find "$DISTS_DIR" -type f | sort