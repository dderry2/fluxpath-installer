#!/bin/bash

set -e

echo "==============================================="
echo "        FluxPath Release Builder"
echo "==============================================="

ROOT_DIR="$HOME/FluxPath"
DIST_DIR="$ROOT_DIR/dist"
VERSION_FILE="$ROOT_DIR/VERSION"
RELEASE_META="$DIST_DIR/release_info.txt"

# ---------------------------------------------------------
# 1. Determine version
# ---------------------------------------------------------
echo ""
echo "--- Determining Version ---"

if [ -f "$VERSION_FILE" ]; then
    VERSION=$(cat "$VERSION_FILE")
else
    VERSION="0.0.0-$(date +%Y%m%d)"
fi

echo "VERSION=$VERSION"

RELEASE_NAME="fluxpath-$VERSION"
RELEASE_DIR="$DIST_DIR/$RELEASE_NAME"

# Clean old dist
rm -rf "$DIST_DIR"
mkdir -p "$RELEASE_DIR"

# ---------------------------------------------------------
# 2. Validate Git state
# ---------------------------------------------------------
echo ""
echo "--- Validating Git State ---"

cd "$ROOT_DIR"

if git diff --quiet && git diff --cached --quiet; then
    echo "GIT_CLEAN=true"
else
    echo "GIT_CLEAN=false"
    echo "WARNING: Uncommitted changes detected."
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "GIT_BRANCH=$CURRENT_BRANCH"

# ---------------------------------------------------------
# 3. Copy project components into release folder
# ---------------------------------------------------------
echo ""
echo "--- Copying Project Files ---"

mkdir -p "$RELEASE_DIR/backend"
mkdir -p "$RELEASE_DIR/ui"
mkdir -p "$RELEASE_DIR/config"
mkdir -p "$RELEASE_DIR/scripts"
mkdir -p "$RELEASE_DIR/systemd"

# Backend
cp -r "$ROOT_DIR/backend/"* "$RELEASE_DIR/backend/" 2>/dev/null || true

# UI Panels
cp -r "$ROOT_DIR/ui/"* "$RELEASE_DIR/ui/" 2>/dev/null || true

# Config templates
cp -r "$ROOT_DIR/config/"* "$RELEASE_DIR/config/" 2>/dev/null || true

# Scripts (excluding dist)
find "$ROOT_DIR/scripts" -maxdepth 1 -type f -exec cp {} "$RELEASE_DIR/scripts/" \;

# Systemd units
cp -r "$ROOT_DIR/systemd/"* "$RELEASE_DIR/systemd/" 2>/dev/null || true

echo "FILES_COPIED=true"

# ---------------------------------------------------------
# 4. Generate release metadata
# ---------------------------------------------------------
echo ""
echo "--- Generating Release Metadata ---"

cat << EOF > "$RELEASE_META"
FluxPath Release: $VERSION
Build Date: $(date)
Git Branch: $CURRENT_BRANCH
Git Commit: $(git rev-parse HEAD)
EOF

echo "RELEASE_METADATA=true"

# ---------------------------------------------------------
# 5. Create tarball
# ---------------------------------------------------------
echo ""
echo "--- Creating Tarball ---"

cd "$DIST_DIR"
tar -czf "$RELEASE_NAME.tar.gz" "$RELEASE_NAME"

if [ -f "$RELEASE_NAME.tar.gz" ]; then
    TARBALL_CREATED=true
else
    TARBALL_CREATED=false
fi

echo "TARBALL_CREATED=$TARBALL_CREATED"

# ---------------------------------------------------------
# 6. Final Summary
# ---------------------------------------------------------
echo ""
echo "==============================================="
echo "        FluxPath Release Build Summary"
echo "==============================================="
echo "Version:                $VERSION"
echo "Git Clean:              $GIT_CLEAN"
echo "Tarball Created:        $TARBALL_CREATED"
echo "Output:                 $DIST_DIR/$RELEASE_NAME.tar.gz"
echo "==============================================="
echo "Release build complete."
echo "Ready for GitHub Releases."
echo "==============================================="
