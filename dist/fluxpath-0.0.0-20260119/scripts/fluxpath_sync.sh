#!/usr/bin/env bash
# ============================================================
# FluxPath Smart Sync Script (Option C)
# Copies only existing live MMU files into the FluxPath project
# Clean, adaptive, no warnings for missing files
# Created in Canada — Enhanced by AI
# ============================================================

RED="\e[31m"
GRN="\e[32m"
YEL="\e[33m"
BLU="\e[34m"
RST="\e[0m"

SRC_MMU="${HOME}/printer_data/config/mmu"
DST="${HOME}/FluxPath/mmu"

confirm_overwrite() {
    local file="$1"
    if [[ -f "$file" ]]; then
        echo -e "${YEL}File exists: ${file}${RST}"
        read -p "Overwrite? (y/N): " ans
        [[ "$ans" == "y" || "$ans" == "Y" ]] || return 1
    fi
    return 0
}

copy_if_exists() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        return 0   # Silent skip
    fi

    confirm_overwrite "$dst" || {
        echo -e "${RED}Skipped: ${dst}${RST}"
        return 0
    }

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo -e "${GRN}Copied: ${src} → ${dst}${RST}"
}

echo -e "${BLU}Syncing live MMU files into FluxPath...${RST}"
mkdir -p "${DST}"

FILES=(
    "mmu_main.cfg"
    "mmu_vars.cfg"
    "mmu_extruders.cfg"
    "mmu_primitives.cfg"
    "mmu_preload.cfg"
    "mmu_load.cfg"
    "mmu_unload.cfg"
    "mmu_toolchange.cfg"
    "mmu_sensors.cfg"
    "mmu_ui.cfg"
    "mmu_calibration.cfg"
    "mmu_diagnostics.cfg"
)

copied=0
skipped=0

for f in "${FILES[@]}"; do
    src="${SRC_MMU}/${f}"
    dst="${DST}/${f}"

    if [[ -f "$src" ]]; then
        copy_if_exists "$src" "$dst"
        ((copied++))
    else
        ((skipped++))
    fi
done

echo
echo -e "${CYN}==============================================${RST}"
echo -e "${MAG}FluxPath Smart Sync Summary${RST}"
echo -e "${CYN}==============================================${RST}"
echo -e "${GRN}Copied files:${RST}   ${copied}"
echo -e "${YEL}Skipped (not present):${RST} ${skipped}"
echo -e "${CYN}Destination:${RST} ${DST}"
echo -e "${CYN}==============================================${RST}"
echo -e "${GRN}Sync complete.${RST}"
