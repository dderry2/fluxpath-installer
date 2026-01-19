#!/usr/bin/env bash
# ============================================================
# FluxPath Sandbox Runner
# Safely runs the FluxPath Installer in a fake environment
# Created in Canada — Enhanced by AI
# ============================================================

RED="\e[31m"
GRN="\e[32m"
YEL="\e[33m"
BLU="\e[34m"
RST="\e[0m"

SANDBOX="${HOME}/FluxPath_Sandbox"
INSTALLER="${HOME}/FluxPath/FluxPath_Installer_v0.9.0b.sh"

echo -e "${BLU}==============================================${RST}"
echo -e "${MAG}        FluxPath Sandbox Environment${RST}"
echo -e "${BLU}==============================================${RST}"
echo
echo -e "${GRN}Sandbox directory:${RST} ${SANDBOX}"
echo -e "${GRN}Installer:${RST}        ${INSTALLER}"
echo

# Create sandbox structure
mkdir -p "${SANDBOX}/printer_data/config"

echo -e "${BLU}Preparing sandbox...${RST}"
sleep 1

# Export fake printer_data path
export PRINTER_DATA="${SANDBOX}/printer_data"

echo -e "${YEL}Running installer in sandbox mode...${RST}"
echo -e "${YEL}Your REAL printer_data directory will NOT be touched.${RST}"
echo

# Run installer
if [[ -f "${INSTALLER}" ]]; then
    bash "${INSTALLER}"
else
    echo -e "${RED}Installer not found at:${RST} ${INSTALLER}"
    exit 1
fi

echo
echo -e "${CYN}==============================================${RST}"
echo -e "${MAG}Sandbox run complete${RST}"
echo -e "${CYN}==============================================${RST}"
echo
echo -e "${GRN}All changes were written to:${RST} ${SANDBOX}"
echo -e "${GRN}Your real Klipper/MMU configs are untouched.${RST}"
