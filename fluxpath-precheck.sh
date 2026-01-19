#!/usr/bin/env bash
#
# FluxPath Precheck
# "Before we touch your system, let's understand it."
#

set -euo pipefail

# -------- BRANDING --------
c_cyan="\e[36m"; c_magenta="\e[35m"; c_green="\e[32m"; c_red="\e[31m"; c_yellow="\e[33m"; c_blue="\e[34m"; c_reset="\e[0m"

banner() {
  echo -e "${c_magenta}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║              FluxPath // System Precheck             ║"
  echo "║        MMU Intelligence Layer • v0.1.0-dev           ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${c_reset}"
}

info()  { echo -e "${c_blue}[INFO]${c_reset} $*"; }
ok()    { echo -e "${c_green}[ OK ]${c_reset} $*"; }
warn()  { echo -e "${c_yellow}[WARN]${c_reset} $*"; }
fail()  { echo -e "${c_red}[FAIL]${c_reset} $*"; exit 1; }

banner

# -------- CONFIGURABLE DEFAULTS --------
USER_NAME="${USER:-syko}"
HOME_DIR="/home/${USER_NAME}"
PRINTER_DATA="${PRINTER_DATA:-${HOME_DIR}/printer_data}"
MOONRAKER_LOG="${PRINTER_DATA}/logs/moonraker.log"
MOONRAKER_CONF="${PRINTER_DATA}/config/moonraker.conf"
DEFAULT_BACKEND_DIR="${PRINTER_DATA}/fluxpath"
DEFAULT_FLUIDD_DIR="${HOME_DIR}/fluidd"
DEFAULT_MAINSAIL_DIR="${HOME_DIR}/mainsail"
SNAPSHOT_DIR="${PRINTER_DATA}/fluxpath_snapshots"

# -------- BASIC CHECKS --------

check_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    fail "I was expecting '${cmd}', but it's not in PATH."
  fi
}

info "Scanning your environment…"

check_cmd "curl"
check_cmd "ss"
check_cmd "sed"
check_cmd "grep"
check_cmd "awk"
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not found; JSON parsing will be limited. (Optional but recommended.)"
fi

# -------- MOONRAKER STATUS --------

info "Checking Moonraker API at http://localhost:7125/server/info …"
if ! curl -sS http://localhost:7125/server/info >/tmp/fluxpath_server_info.json 2>/dev/null; then
  fail "Moonraker API is not reachable. I can't safely proceed until it's online."
fi

if command -v jq >/dev/null 2>&1; then
  MOONRAKER_VERSION=$(jq -r '.result.moonraker_version' </tmp/fluxpath_server_info.json 2>/dev/null || echo "unknown")
  KLIPPY_STATE=$(jq -r '.result.klippy_state' </tmp/fluxpath_server_info.json 2>/dev/null || echo "unknown")
else
  MOONRAKER_VERSION="unknown"
  KLIPPY_STATE="unknown"
fi

ok "Moonraker is talking. Version: ${MOONRAKER_VERSION}, Klippy: ${KLIPPY_STATE}"

# -------- PATH & FILE CHECKS --------

[ -d "${PRINTER_DATA}" ] || fail "printer_data not found at ${PRINTER_DATA}"
ok "printer_data found at ${PRINTER_DATA}"

[ -f "${MOONRAKER_CONF}" ] || fail "Moonraker config not found at ${MOONRAKER_CONF}"
ok "Moonraker config found at ${MOONRAKER_CONF}"

# -------- UI DETECTION --------

FLUIDD_PRESENT="no"
MAINSAIL_PRESENT="no"

if [ -d "${DEFAULT_FLUIDD_DIR}" ]; then
  FLUIDD_PRESENT="yes"
  ok "Fluidd detected at ${DEFAULT_FLUIDD_DIR}"
else
  warn "Fluidd not detected at ${DEFAULT_FLUIDD_DIR}"
fi

if [ -d "${DEFAULT_MAINSAIL_DIR}" ]; then
  MAINSAIL_PRESENT="yes"
  ok "Mainsail detected at ${DEFAULT_MAINSAIL_DIR}"
else
  warn "Mainsail not detected at ${DEFAULT_MAINSAIL_DIR}"
fi

# -------- BACKEND PRESENCE --------

if [ -d "${DEFAULT_BACKEND_DIR}" ]; then
  warn "Existing FluxPath backend detected at ${DEFAULT_BACKEND_DIR}"
else
  ok "No existing FluxPath backend at ${DEFAULT_BACKEND_DIR} — clean slate."
fi

# -------- EXTENSION LIST --------

info "Checking Moonraker extensions list…"
EXT_LIST=$(curl -sS http://localhost:7125/server/extensions/list 2>/dev/null || echo "")
echo "${EXT_LIST}" | grep -q "fluxpath" && warn "FluxPath already appears in /server/extensions/list."

# -------- SNAPSHOT --------

mkdir -p "${SNAPSHOT_DIR}"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/precheck-$(date +%Y%m%d-%H%M%S).txt"

{
  echo "FluxPath Precheck Snapshot"
  echo "Timestamp: $(date)"
  echo "User: ${USER_NAME}"
  echo "Moonraker version: ${MOONRAKER_VERSION}"
  echo "Klippy state: ${KLIPPY_STATE}"
  echo "printer_data: ${PRINTER_DATA}"
  echo "Moonraker config: ${MOONRAKER_CONF}"
  echo "Backend (default): ${DEFAULT_BACKEND_DIR}"
  echo "Fluidd present: ${FLUIDD_PRESENT} (${DEFAULT_FLUIDD_DIR})"
  echo "Mainsail present: ${MAINSAIL_PRESENT} (${DEFAULT_MAINSAIL_DIR})"
} > "${SNAPSHOT_FILE}"

ok "Snapshot captured at ${SNAPSHOT_FILE}"

# -------- EXPORT ENV --------

cat <<EOF >/tmp/fluxpath_precheck_env
PRINTER_DATA="${PRINTER_DATA}"
MOONRAKER_CONF="${MOONRAKER_CONF}"
DEFAULT_BACKEND_DIR="${DEFAULT_BACKEND_DIR}"
DEFAULT_FLUIDD_DIR="${DEFAULT_FLUIDD_DIR}"
DEFAULT_MAINSAIL_DIR="${DEFAULT_MAINSAIL_DIR}"
FLUIDD_PRESENT="${FLUIDD_PRESENT}"
MAINSAIL_PRESENT="${MAINSAIL_PRESENT}"
MOONRAKER_VERSION="${MOONRAKER_VERSION}"
EOF

ok "Precheck complete. Environment looks ready for FluxPath."
