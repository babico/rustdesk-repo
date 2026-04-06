#!/usr/bin/env bash
# build-repo.sh — Build a full APT repository index from ALL .deb files in the pool.
# Scans all apps defined in apps.json. Every version present in docs/pool/ is indexed.
set -euo pipefail

GPG_KEY_ID="${1:-}"
GPG_PASSPHRASE="${2:-}"

APPS_JSON="apps.json"
REPO_ROOT="docs"
DIST="stable"
COMP="main"
POOL="$REPO_ROOT/pool/$COMP"
DISTS="$REPO_ROOT/dists/$DIST"

echo "==> Building APT index from pool (all apps, all versions)..."

# Gather all unique architectures from all apps
ALL_ARCHS=$(jq -r '.[].architectures | keys[]' "$APPS_JSON" | sort -u | tr '\n' ' ')
echo "    Architectures: $ALL_ARCHS"

# Count total debs
TOTAL_DEBS=$(find "$POOL" -name '*.deb' 2>/dev/null | wc -l || echo 0)
echo "    Total .deb files in pool: $TOTAL_DEBS"

# Clean stale index
rm -rf "$DISTS"
mkdir -p "$DISTS/$COMP"

# ── Per-architecture Packages files ──────────────────────────────────────────
# We link each arch's debs into a temp staging tree so dpkg-scanpackages
# sees only the right files per architecture.

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

for ARCH in $ALL_ARCHS; do
  STAGE_POOL="$STAGING/$ARCH/pool/$COMP"
  mkdir -p "$STAGE_POOL"

  # For each app, find debs matching this architecture's suffix
  while IFS= read -r APP_ROW; do
    APP_NAME=$(echo "$APP_ROW" | jq -r '.name')
    POOL_LETTER=$(echo "$APP_ROW" | jq -r '.pool_letter')
    SUFFIX=$(echo "$APP_ROW" | jq -r --arg a "$ARCH" '.architectures[$a] // empty')

    [ -z "$SUFFIX" ] && continue  # this app doesn't have this arch

    SRC_POOL="$POOL/${POOL_LETTER}/${APP_NAME}"
    [ -d "$SRC_POOL" ] || continue

    STAGE_APP="$STAGE_POOL/${POOL_LETTER}/${APP_NAME}"
    mkdir -p "$STAGE_APP"

    while IFS= read -r -d '' DEB; do
      ln "$DEB" "$STAGE_APP/$(basename "$DEB")" 2>/dev/null \
        || cp "$DEB" "$STAGE_APP/$(basename "$DEB")"
    done < <(find "$SRC_POOL" -name "*${SUFFIX}" -print0 2>/dev/null)
  done < <(jq -c '.[]' "$APPS_JSON")

  COUNT=$(find "$STAGE_POOL" -name '*.deb' 2>/dev/null | wc -l)
  if [ "$COUNT" -eq 0 ]; then
    echo "  [skip] $ARCH — no packages"
    continue
  fi

  PKG_DIR="$DISTS/$COMP/binary-$ARCH"
  mkdir -p "$PKG_DIR"

  # Scan from staging root → Filename paths will be pool/...
  (cd "$STAGING/$ARCH" && \
    dpkg-scanpackages "pool/$COMP" /dev/null 2>/dev/null) \
    > "$PKG_DIR/Packages"

  FIRST=$(grep '^Filename:' "$PKG_DIR/Packages" | head -1)
  echo "  [ok]  $ARCH — $COUNT pkg(s)  ($FIRST)"

  gzip -9 -k -f "$PKG_DIR/Packages"
done

# ── Release file ──────────────────────────────────────────────────────────────
echo "==> Generating Release..."

OWNER="${GITHUB_REPOSITORY_OWNER:-babico}"
SLUG="${GITHUB_REPOSITORY:-babico/apt-packages}"
APP_COUNT=$(jq 'length' "$APPS_JSON")

# Count total unique versions across all apps
TOTAL_VERSIONS=0
while IFS= read -r APP_ROW; do
  APP_NAME=$(echo "$APP_ROW" | jq -r '.name')
  TFILE="tracked_versions/${APP_NAME}.json"
  if [ -f "$TFILE" ]; then
    V_COUNT=$(jq 'length' "$TFILE")
    TOTAL_VERSIONS=$((TOTAL_VERSIONS + V_COUNT))
  fi
done < <(jq -c '.[]' "$APPS_JSON")

cat > "$DISTS/Release" <<RELEASE
Origin: Personal APT Mirror
Label: Personal APT Repository
Suite: $DIST
Codename: $DIST
Architectures: $(echo $ALL_ARCHS | tr ' ' ' ')
Components: $COMP
Description: Personal APT mirror — $APP_COUNT app(s), $TOTAL_VERSIONS version(s) available
Date: $(date -Ru)
RELEASE

for ALGO in MD5Sum SHA1 SHA256 SHA512; do
  echo "$ALGO:" >> "$DISTS/Release"
  find "$DISTS/$COMP" -type f | sort | while read -r F; do
    REL="${F#$DISTS/}"
    SZ=$(stat -c%s "$F")
    case "$ALGO" in
      MD5Sum)  SUM=$(md5sum    "$F" | awk '{print $1}') ;;
      SHA1)    SUM=$(sha1sum   "$F" | awk '{print $1}') ;;
      SHA256)  SUM=$(sha256sum "$F" | awk '{print $1}') ;;
      SHA512)  SUM=$(sha512sum "$F" | awk '{print $1}') ;;
    esac
    printf " %s %s %s\n" "$SUM" "$SZ" "$REL"
  done >> "$DISTS/Release"
done

# ── GPG sign ──────────────────────────────────────────────────────────────────
if [ -n "$GPG_KEY_ID" ]; then
  echo "==> Signing with key $GPG_KEY_ID..."
  export GPG_TTY; GPG_TTY=$(tty 2>/dev/null || true)
  OPTS="--batch --pinentry-mode loopback"
  [ -n "$GPG_PASSPHRASE" ] && OPTS="$OPTS --passphrase-fd 0"

  echo "$GPG_PASSPHRASE" | gpg $OPTS --default-key "$GPG_KEY_ID" \
    --clearsign  --output "$DISTS/InRelease"  "$DISTS/Release"
  echo "$GPG_PASSPHRASE" | gpg $OPTS --default-key "$GPG_KEY_ID" \
    --detach-sign --armor --output "$DISTS/Release.gpg" "$DISTS/Release"
  gpg --armor --export "$GPG_KEY_ID" > "$REPO_ROOT/apt-repo.gpg"
  echo "==> Signed OK."
else
  echo "==> No GPG key — skipping signatures."
fi

echo ""
echo "==> Index summary:"
for ARCH in $ALL_ARCHS; do
  F="$DISTS/$COMP/binary-$ARCH/Packages"
  [ -f "$F" ] && echo "   $ARCH: $(grep -c '^Package:' "$F") package(s)" || echo "   $ARCH: (none)"
done