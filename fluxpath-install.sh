#!/usr/bin/env bash
#
# FluxPath Installer
# "Interactive, opinionated, and a little bit sentient-feeling."
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

c_cyan="\e[36m"; c_magenta="\e[35m"; c_green="\e[32m"; c_red="\e[31m"; c_yellow="\e[33m"; c_blue="\e[34m"; c_reset="\e[0m"

info()  { echo -e "${c_blue}[INFO]${c_reset} $*"; }
ok()    { echo -e "${c_green}[ OK ]${c_reset} $*"; }
warn()  { echo -e "${c_yellow}[WARN]${c_reset} $*"; }
fail()  { echo -e "${c_red}[FAIL]${c_reset} $*"; exit 1; }
title() { echo -e "\n${c_magenta}=== $* ===${c_reset}\n"; }

banner() {
  echo -e "${c_magenta}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║              FluxPath // MMU Intelligence            ║"
  echo "║        Guided Installer • Interactive by Default     ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${c_reset}"
}

usage() {
  cat <<EOF
FluxPath Installer

Usage:
  $(basename "$0") [options]

Options:
  --auto                     Non-interactive mode (use defaults/flags)
  --ui fluidd|mainsail|both|none
  --backend-dir PATH         Override backend directory
  --dry-run                  Simulate actions only
  --uninstall                Uninstall FluxPath
  --repair                   Repair FluxPath install
  --doctor                   Diagnostics only (no changes)
  --dev                      Developer mode (more verbose)
  --help                     Show this help

No arguments → interactive install.
EOF
}

AUTO_MODE="no"
UI_CHOICE=""
BACKEND_DIR_OVERRIDE=""
DO_DRY_RUN="no"
DO_UNINSTALL="no"
DO_REPAIR="no"
DO_DOCTOR="no"
DEV_MODE="no"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO_MODE="yes"; shift;;
    --ui) UI_CHOICE="$2"; shift 2;;
    --backend-dir) BACKEND_DIR_OVERRIDE="$2"; shift 2;;
    --dry-run) DO_DRY_RUN="yes"; shift;;
    --uninstall) DO_UNINSTALL="yes"; shift;;
    --repair) DO_REPAIR="yes"; shift;;
    --doctor) DO_DOCTOR="yes"; shift;;
    --dev) DEV_MODE="yes"; shift;;
    -h|--help) usage; exit 0;;
    *) fail "Unknown option: $1";;
  esac
done

banner
title "FluxPath Session Start"

# -------- DOCTOR MODE --------

if [ "${DO_DOCTOR}" = "yes" ]; then
  title "FluxPath Doctor"
  bash "${SCRIPT_DIR}/fluxpath-precheck.sh"
  if curl -sS http://localhost:7125/server/extensions/list >/tmp/fluxpath_ext_list.json 2>/dev/null; then
    echo
    echo "Current Moonraker extensions:"
    cat /tmp/fluxpath_ext_list.json
  else
    warn "Could not query /server/extensions/list"
  fi
  echo
  ok "Doctor run complete. No changes were made."
  exit 0
fi

# -------- PRECHECK --------

info "First, I’ll scan your environment so I don’t step on anything important."
bash "${SCRIPT_DIR}/fluxpath-precheck.sh"

# shellcheck disable=SC1091
source /tmp/fluxpath_precheck_env

DEFAULT_BACKEND_DIR="${DEFAULT_BACKEND_DIR:-${PRINTER_DATA}/fluxpath}"

INSTALL_FLUIDD_PANEL="no"
INSTALL_MAINSAIL_PANEL="no"
BACKEND_DIR="${DEFAULT_BACKEND_DIR}"

if [ -n "${BACKEND_DIR_OVERRIDE}" ]; then
  BACKEND_DIR="${BACKEND_DIR_OVERRIDE}"
fi

# -------- DETERMINE ACTION --------

ACTION="install"
if [ "${DO_UNINSTALL}" = "yes" ]; then
  ACTION="uninstall"
elif [ "${DO_REPAIR}" = "yes" ]; then
  ACTION="repair"
fi

# -------- INTERACTIVE FLOW --------

if [ "${AUTO_MODE}" = "no" ] && [ "${ACTION}" = "install" ]; then
  title "UI Integration"

  if [ "${FLUIDD_PRESENT}" = "yes" ]; then
    echo "• Fluidd detected at ${DEFAULT_FLUIDD_DIR}"
  else
    echo "• Fluidd not detected."
  fi

  if [ "${MAINSAIL_PRESENT}" = "yes" ]; then
    echo "• Mainsail detected at ${DEFAULT_MAINSAIL_DIR}"
  else
    echo "• Mainsail not detected."
  fi

  echo
  echo "Where should FluxPath show up?"
  echo "  1) Fluidd"
  echo "  2) Mainsail"
  echo "  3) Both"
  echo "  4) None (backend only, headless brain)"
  read -rp "Choose [1-4]: " ui_sel

  case "${ui_sel}" in
    1) INSTALL_FLUIDD_PANEL="yes"; INSTALL_MAINSAIL_PANEL="no";;
    2) INSTALL_FLUIDD_PANEL="no"; INSTALL_MAINSAIL_PANEL="yes";;
    3) INSTALL_FLUIDD_PANEL="yes"; INSTALL_MAINSAIL_PANEL="yes";;
    4) INSTALL_FLUIDD_PANEL="no"; INSTALL_MAINSAIL_PANEL="no";;
    *) warn "That was a bit unexpected. I’ll default to Fluidd only."; INSTALL_FLUIDD_PANEL="yes";;
  esac

  title "Backend Location"

  echo "Default backend directory:"
  echo "  ${DEFAULT_BACKEND_DIR}"
  read -rp "Use this location? [Y/n]: " use_def
  use_def="${use_def:-Y}"

  if [[ "${use_def}" =~ ^[Nn]$ ]]; then
    read -rp "Enter custom backend directory path: " custom_backend
    [ -n "${custom_backend}" ] && BACKEND_DIR="${custom_backend}"
  fi

else
  case "${UI_CHOICE}" in
    fluidd) INSTALL_FLUIDD_PANEL="yes"; INSTALL_MAINSAIL_PANEL="no";;
    mainsail) INSTALL_FLUIDD_PANEL="no"; INSTALL_MAINSAIL_PANEL="yes";;
    both) INSTALL_FLUIDD_PANEL="yes"; INSTALL_MAINSAIL_PANEL="yes";;
    none|"") INSTALL_FLUIDD_PANEL="no"; INSTALL_MAINSAIL_PANEL="no";;
    *) warn "Unknown --ui '${UI_CHOICE}', defaulting to none."; INSTALL_FLUIDD_PANEL="no";;
  esac
fi

# -------- SUMMARY --------

title "Plan Overview"

echo "Action:               ${ACTION}"
echo "Backend directory:    ${BACKEND_DIR}"
echo "Fluidd panel:         ${INSTALL_FLUIDD_PANEL}"
echo "Mainsail panel:       ${INSTALL_MAINSAIL_PANEL}"
echo "Moonraker config:     ${MOONRAKER_CONF}"
echo "Dry-run:              ${DO_DRY_RUN}"
echo "Developer mode:       ${DEV_MODE}"
echo

if [ "${AUTO_MODE}" = "no" ]; then
  read -rp "Does this look right? [Y/n]: " confirm
  confirm="${confirm:-Y}"
  if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    fail "Okay, I’ll stop here. No changes made."
  fi
fi

# -------- CORE ENGINE CALL --------

title "Executing FluxPath Core Engine"

bash "${SCRIPT_DIR}/fluxpath-installer.sh" \
  --action "${ACTION}" \
  --backend-dir "${BACKEND_DIR}" \
  --fluidd-panel "${INSTALL_FLUIDD_PANEL}" \
  --mainsail-panel "${INSTALL_MAINSAIL_PANEL}" \
  --dry-run "${DO_DRY_RUN}" \
  --dev "${DEV_MODE}"

ok "FluxPath session complete."

echo
echo -e "${c_cyan}Next steps:${c_reset}"
echo "  • Drop your real backend Python extension into:"
echo "      ${BACKEND_DIR}/backend"
echo "  • Drop your real Fluidd/Mainsail panel assets into:"
echo "      <ui>/fluxpath-panel"
echo "  • Then we can wire the API and UI together for a true MMU control surface."
