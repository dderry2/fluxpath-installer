#!/bin/bash

echo "=== FluxPath Full Repository Cleanup ==="

BASE_DIR="/home/syko/FluxPath"
BACKUP_DIR="$BASE_DIR/_backup_repo_cleanup_$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

echo "Backup directory: $BACKUP_DIR"
echo

# -----------------------------------------
# 1. Remove legacy installers
# -----------------------------------------
INSTALLER_PATTERNS=(
    "FluxPath_Installer_v*.sh"
    "install_fluxpath*.sh"
    "fluxpath_installer.sh"
    "install_fluxpath_all_in_one.sh"
    "install_fluxpath_full_stack.sh"
    "install_fluxpath_fluidd_panel.sh"
    "install_fluxpath_moonraker.sh"
)

echo "--- Removing legacy installers ---"
for pattern in "${INSTALLER_PATTERNS[@]}"; do
    for file in "$BASE_DIR"/$pattern; do
        if [ -f "$file" ]; then
            echo "Moving $file → $BACKUP_DIR"
            mv "$file" "$BACKUP_DIR/"
        fi
    done
done
echo

# -----------------------------------------
# 2. Remove legacy service files
# -----------------------------------------
echo "--- Removing orphaned service files ---"
for file in "$BASE_DIR"/*Service*; do
    if [ -f "$file" ]; then
        echo "Moving $file → $BACKUP_DIR"
        mv "$file" "$BACKUP_DIR/"
    fi
done
echo

# -----------------------------------------
# 3. Remove deprecated Moonraker integration
# -----------------------------------------
MOONRAKER_PATTERNS=(
    "moonraker"
    "moonraker_*"
    "moonraker-*.sh"
)

echo "--- Removing deprecated Moonraker integration ---"
for pattern in "${MOONRAKER_PATTERNS[@]}"; do
    for file in "$BASE_DIR"/$pattern; do
        if [ -e "$file" ]; then
            echo "Moving $file → $BACKUP_DIR"
            mv "$file" "$BACKUP_DIR/"
        fi
    done
done
echo

# -----------------------------------------
# 4. Remove old MMU prototypes
# -----------------------------------------
MMU_PATTERNS=(
    "mmu_old"
    "mmu_prototype"
    "mmu_test"
)

echo "--- Removing legacy MMU prototypes ---"
for pattern in "${MMU_PATTERNS[@]}"; do
    for file in "$BASE_DIR"/$pattern; do
        if [ -e "$file" ]; then
            echo "Moving $file → $BACKUP_DIR"
            mv "$file" "$BACKUP_DIR/"
        fi
    done
done
echo

# -----------------------------------------
# 5. Remove stale __pycache__ everywhere
# -----------------------------------------
echo "--- Removing all __pycache__ directories ---"
find "$BASE_DIR" -type d -name "__pycache__" -print -exec rm -rf {} +
echo

# -----------------------------------------
# 6. Remove old logs
# -----------------------------------------
echo "--- Removing old log files ---"
find "$BASE_DIR" -type f -name "*.log" -print -exec mv {} "$BACKUP_DIR/" \;
echo

# -----------------------------------------
# 7. Remove orphaned systemd service files
# -----------------------------------------
echo "--- Checking for orphaned systemd services ---"
SYSTEMD_FILES=(
    "/etc/systemd/system/fluxpath_old.service"
    "/etc/systemd/system/fluxpath_legacy.service"
    "/etc/systemd/system/fluxpath_ws.service"
)

for svc in "${SYSTEMD_FILES[@]}"; do
    if [ -f "$svc" ]; then
        echo "Moving $svc → $BACKUP_DIR"
        sudo mv "$svc" "$BACKUP_DIR/"
    fi
done
echo

# -----------------------------------------
# 8. Final summary
# -----------------------------------------
echo "=== Cleanup complete ==="
echo "All removed files were moved to:"
echo "  $BACKUP_DIR"
echo
echo "Review them before deleting permanently."
