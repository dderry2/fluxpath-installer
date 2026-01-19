#!/bin/bash

echo "=== FluxPath Repository Restructuring ==="

BASE_DIR="/home/syko/FluxPath"
BACKUP_DIR="$BASE_DIR/_backup_repo_restructure_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

echo "Backup directory: $BACKUP_DIR"
echo

# -----------------------------------------
# 1. Create modern repo structure
# -----------------------------------------
echo "--- Creating modern repo structure ---"

mkdir -p "$BASE_DIR/scripts"
mkdir -p "$BASE_DIR/systemd"
mkdir -p "$BASE_DIR/tools"
mkdir -p "$BASE_DIR/docs"
mkdir -p "$BASE_DIR/legacy"
mkdir -p "$BASE_DIR/tests"

echo

# -----------------------------------------
# 2. Move systemd service files
# -----------------------------------------
echo "--- Moving systemd service files ---"

if [ -f "/etc/systemd/system/fluxpath.service" ]; then
    sudo cp "/etc/systemd/system/fluxpath.service" "$BASE_DIR/systemd/"
    echo "Copied fluxpath.service → systemd/"
fi

echo

# -----------------------------------------
# 3. Move scripts into /scripts
# -----------------------------------------
echo "--- Organizing scripts ---"

SCRIPT_PATTERNS=(
    "*backend*.sh"
    "*fluxpath*.sh"
    "*upgrade*.sh"
    "*disable*.sh"
    "*kill*.sh"
)

for pattern in "${SCRIPT_PATTERNS[@]}"; do
    for file in "$BASE_DIR"/$pattern; do
        if [ -f "$file" ]; then
            echo "Moving $file → scripts/"
            mv "$file" "$BASE_DIR/scripts/"
        fi
    done
done

echo

# -----------------------------------------
# 4. Move installers and deprecated scripts to /legacy
# -----------------------------------------
echo "--- Moving legacy installers ---"

LEGACY_PATTERNS=(
    "FluxPath_Installer_v*.sh"
    "install_fluxpath*.sh"
    "fluxpath_installer.sh"
    "*moonraker*"
    "*Service*"
)

for pattern in "${LEGACY_PATTERNS[@]}"; do
    for file in "$BASE_DIR"/$pattern; do
        if [ -e "$file" ]; then
            echo "Moving $file → legacy/"
            mv "$file" "$BASE_DIR/legacy/"
        fi
    done
done

echo

# -----------------------------------------
# 5. Move docs into /docs
# -----------------------------------------
echo "--- Organizing documentation ---"

DOC_PATTERNS=(
    "README.md"
    "CHANGELOG.md"
    "docs/*"
)

for pattern in "${DOC_PATTERNS[@]}"; do
    for file in $BASE_DIR/$pattern; do
        if [ -e "$file" ]; then
            echo "Moving $file → docs/"
            mv "$file" "$BASE_DIR/docs/" 2>/dev/null || true
        fi
    done
done

echo

# -----------------------------------------
# 6. Remove stale __pycache__
# -----------------------------------------
echo "--- Removing all __pycache__ directories ---"
find "$BASE_DIR" -type d -name "__pycache__" -print -exec rm -rf {} +
echo

# -----------------------------------------
# 7. Move unknown or suspicious files to backup
# -----------------------------------------
echo "--- Backing up unknown files ---"

for file in "$BASE_DIR"/*; do
    case "$file" in
        "$BASE_DIR/scripts" | "$BASE_DIR/systemd" | "$BASE_DIR/tools" | "$BASE_DIR/docs" | "$BASE_DIR/legacy" | "$BASE_DIR/tests" | "$BASE_DIR/fluxpath" | "$BASE_DIR/core" | "$BASE_DIR/fp_core" | "$BASE_DIR/mmu" | "$BASE_DIR/server.py" | "$BASE_DIR/venv" | "$BASE_DIR/pyproject.toml" | "$BASE_DIR/__init__.py" )
            # safe, do nothing
            ;;
        *)
            if [ -e "$file" ]; then
                echo "Backing up $file → $BACKUP_DIR"
                mv "$file" "$BACKUP_DIR/"
            fi
            ;;
    esac
done

echo

# -----------------------------------------
# 8. Final summary
# -----------------------------------------
echo "=== Restructure complete ==="
echo "Backup folder: $BACKUP_DIR"
echo "Review before deleting permanently."

