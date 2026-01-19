#!/usr/bin/env bash
#
# FluxPath Core Engine
# "This is where the wiring happens."
#

set -euo pipefail

# -------- BRANDING --------
c_cyan="\e[36m"; c_magenta="\e[35m"; c_green="\e[32m"; c_red="\e[31m"; c_yellow="\e[33m"; c_blue="\e[34m"; c_reset="\e[0m"

info()  { echo -e "${c_blue}[INFO]${c_reset} $*"; }
ok()    { echo -e "${c_green}[ OK ]${c_reset} $*"; }
warn()  { echo -e "${c_yellow}[WARN]${c_reset} $*"; }
fail()  { echo -e "${c_red}[FAIL]${c_reset} $*"; exit 1; }

# -------- DEFAULTS --------
USER_NAME="${USER:-syko}"
HOME_DIR="/home/${USER_NAME}"

PRINTER_DATA="${PRINTER_DATA:-${HOME_DIR}/printer_data}"
MOONRAKER_CONF="${MOONRAKER_CONF:-${PRINTER_DATA}/config/moonraker.conf}"
BACKEND_DIR="${BACKEND_DIR:-${PRINTER_DATA}/fluxpath}"

FLUIDD_DIR="${FLUIDD_DIR:-${HOME_DIR}/fluidd}"
MAINSAIL_DIR="${MAINSAIL_DIR:-${HOME_DIR}/mainsail}"

ACTION="install"   # install | uninstall | repair
DRY_RUN="no"
DEV_MODE="no"

INSTALL_FLUIDD_PANEL="no"
INSTALL_MAINSAIL_PANEL="no"

VERSION_STRING="0.1.0-dev"
SNAPSHOT_ROOT="${PRINTER_DATA}/fluxpath_snapshots"

usage() {
  cat <<EOF
FluxPath Core Engine

Usage:
  $(basename "$0") [options]

Options:
  --action install|uninstall|repair   What to do (default: install)
  --backend-dir PATH                  Backend directory (default: ${BACKEND_DIR})
  --fluidd-panel yes|no               Install Fluidd panel (default: ${INSTALL_FLUIDD_PANEL})
  --mainsail-panel yes|no             Install Mainsail panel (default: ${INSTALL_MAINSAIL_PANEL})
  --dry-run yes|no                    Simulate actions only (default: ${DRY_RUN})
  --dev yes|no                        Developer mode (default: ${DEV_MODE})
EOF
}

# -------- ARG PARSING --------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action) ACTION="$2"; shift 2;;
    --backend-dir) BACKEND_DIR="$2"; shift 2;;
    --fluidd-panel) INSTALL_FLUIDD_PANEL="$2"; shift 2;;
    --mainsail-panel) INSTALL_MAINSAIL_PANEL="$2"; shift 2;;
    --dry-run) DRY_RUN="$2"; shift 2;;
    --dev) DEV_MODE="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) fail "Unknown option: $1";;
  esac
done

do_run() {
  if [ "${DRY_RUN}" = "yes" ]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

[ -d "${PRINTER_DATA}" ] || fail "printer_data not found at ${PRINTER_DATA}"
[ -f "${MOONRAKER_CONF}" ] || fail "Moonraker config not found at ${MOONRAKER_CONF}"

BACKEND_DIR_ABS="${BACKEND_DIR/#\~/${HOME_DIR}}"
SNAPSHOT_DIR="${SNAPSHOT_ROOT}/$(date +%Y%m%d-%H%M%S)"
mkdir -p "${SNAPSHOT_DIR}"

info "FluxPath Core Engine engaged."
info "Action: ${ACTION} | Backend: ${BACKEND_DIR_ABS} | Dry-run: ${DRY_RUN} | Dev: ${DEV_MODE}"

snapshot_state() {
  local label="$1"
  local file="${SNAPSHOT_DIR}/${label}.txt"
  {
    echo "FluxPath Snapshot: ${label}"
    echo "Timestamp: $(date)"
    echo "Backend dir: ${BACKEND_DIR_ABS}"
    echo "Moonraker config: ${MOONRAKER_CONF}"
    echo
    echo "Moonraker config contents:"
    echo "--------------------------"
    cat "${MOONRAKER_CONF}" || true
  } > "${file}"
  ok "Snapshot '${label}' saved to ${file}"
}

backup_moonraker_conf() {
  local backup="${MOONRAKER_CONF}.fluxpath.bak.$(date +%Y%m%d-%H%M%S)"
  do_run "cp '${MOONRAKER_CONF}' '${backup}'"
  ok "Moonraker config backed up to ${backup}"
}

ensure_extension_path() {
  info "Ensuring [server] has extension_path → ${BACKEND_DIR_ABS}"

  if ! grep -q "^

\[server\]

" "${MOONRAKER_CONF}"; then
    fail "No [server] section found in ${MOONRAKER_CONF}"
  fi

  if grep -q "^[[:space:]]*extension_path:" "${MOONRAKER_CONF}"; then
    do_run "sed -i 's|^[[:space:]]*extension_path:.*|extension_path: ${BACKEND_DIR_ABS}|' '${MOONRAKER_CONF}'"
    ok "Updated existing extension_path."
  else
    local tmp="${MOONRAKER_CONF}.tmp.$$"
    awk -v path="${BACKEND_DIR_ABS}" '
      BEGIN { in_server=0 }
      /^

\[server\]

/ { print; in_server=1; next }
      /^

\[/ && in_server==1 { print "extension_path: " path; in_server=0 }
      { print }
      END {
        if (in_server==1) {
          print "extension_path: " path
        }
      }
    ' "${MOONRAKER_CONF}" > "${tmp}"
    do_run "mv '${tmp}' '${MOONRAKER_CONF}'"
    ok "Added extension_path to [server]."
  fi
}

install_backend_skeleton() {
  info "Creating FluxPath backend skeleton at ${BACKEND_DIR_ABS}"
  do_run "mkdir -p '${BACKEND_DIR_ABS}/backend' '${BACKEND_DIR_ABS}/config' '${BACKEND_DIR_ABS}/logs'"

  local ver_file="${BACKEND_DIR_ABS}/VERSION"
  do_run "cat <<EOF > '${ver_file}'
FluxPath Backend
Version: ${VERSION_STRING}
Installed: $(date)
Backend dir: ${BACKEND_DIR_ABS}
EOF"

  local readme="${BACKEND_DIR_ABS}/backend/README.txt"
  do_run "cat <<'EOF' > '${readme}'
FluxPath Backend Placeholder

This is where the FluxPath Moonraker extension will live.
Think of this as the brainstem for your MMU intelligence layer.

Future:
- Add Python package here (e.g., fluxpath/__init__.py)
- Register as a Moonraker extension/agent
- Expose APIs for the UI panel
EOF"
  ok "Backend skeleton and version stamp created."
}

remove_backend() {
  if [ -d "${BACKEND_DIR_ABS}" ]; then
    info "Removing backend directory ${BACKEND_DIR_ABS}"
    do_run "rm -rf '${BACKEND_DIR_ABS}'"
    ok "Backend directory removed."
  else
    warn "Backend directory ${BACKEND_DIR_ABS} not found; nothing to remove."
  fi
}

install_fluidd_panel() {
  if [ "${INSTALL_FLUIDD_PANEL}" != "yes" ]; then return; fi
  if [ -d "${FLUIDD_DIR}" ]; then
    info "Installing FluxPath Fluidd panel placeholder → ${FLUIDD_DIR}/fluxpath-panel"
    do_run "mkdir -p '${FLUIDD_DIR}/fluxpath-panel'"
    do_run "cat <<'EOF' > '${FLUIDD_DIR}/fluxpath-panel/README.txt'
FluxPath • Fluidd Panel

This is the visual layer for FluxPath inside Fluidd.
Future:
- Add JS/HTML/CSS for the MMU dashboard
- Talk to the FluxPath backend via Moonraker APIs
EOF"
    ok "Fluidd panel placeholder installed."
  else
    warn "Fluidd directory not found at ${FLUIDD_DIR}; skipping Fluidd panel."
  fi
}

install_mainsail_panel() {
  if [ "${INSTALL_MAINSAIL_PANEL}" != "yes" ]; then return; fi
  if [ -d "${MAINSAIL_DIR}" ]; then
    info "Installing FluxPath Mainsail panel placeholder → ${MAINSAIL_DIR}/fluxpath-panel"
    do_run "mkdir -p '${MAINSAIL_DIR}/fluxpath-panel'"
    do_run "cat <<'EOF' > '${MAINSAIL_DIR}/fluxpath-panel/README.txt'
FluxPath • Mainsail Panel

This is the visual layer for FluxPath inside Mainsail.
Future:
- Add JS/HTML/CSS for the MMU dashboard
- Talk to the FluxPath backend via Moonraker APIs
EOF"
    ok "Mainsail panel placeholder installed."
  else
    warn "Mainsail directory not found at ${MAINSAIL_DIR}; skipping Mainsail panel."
  fi
}

remove_panels() {
  if [ -d "${FLUIDD_DIR}/fluxpath-panel" ]; then
    info "Removing Fluidd FluxPath panel at ${FLUIDD_DIR}/fluxpath-panel"
    do_run "rm -rf '${FLUIDD_DIR}/fluxpath-panel'"
    ok "Fluidd panel removed."
  fi
  if [ -d "${MAINSAIL_DIR}/fluxpath-panel" ]; then
    info "Removing Mainsail FluxPath panel at ${MAINSAIL_DIR}/fluxpath-panel"
    do_run "rm -rf '${MAINSAIL_DIR}/fluxpath-panel'"
    ok "Mainsail panel removed."
  fi
}

restart_moonraker() {
  info "Restarting Moonraker to apply changes…"
  do_run "sudo systemctl restart moonraker"
}

post_install_health_check() {
  info "Checking Moonraker health after changes…"
  if curl -sS http://localhost:7125/server/info >/dev/null 2>&1; then
    ok "Moonraker is responding. Backend wiring looks sane."
  else
    warn "Moonraker did not respond after restart. Check logs at ${PRINTER_DATA}/logs/moonraker.log"
  fi
}

# -------- ACTIONS --------

case "${ACTION}" in
  install)
    snapshot_state "before-install"
    backup_moonraker_conf
    ensure_extension_path
    install_backend_skeleton
    install_fluidd_panel
    install_mainsail_panel
    restart_moonraker
    post_install_health_check
    snapshot_state "after-install"
    ok "FluxPath install completed."
    ;;
  uninstall)
    snapshot_state "before-uninstall"
    backup_moonraker_conf
    remove_backend
    remove_panels
    restart_moonraker
    post_install_health_check
    snapshot_state "after-uninstall"
    ok "FluxPath uninstall completed."
    ;;
  repair)
    snapshot_state "before-repair"
    backup_moonraker_conf
    ensure_extension_path
    install_backend_skeleton
    install_fluidd_panel
    install_mainsail_panel
    restart_moonraker
    post_install_health_check
    snapshot_state "after-repair"
    ok "FluxPath repair completed."
    ;;
  *)
    fail "Unknown action: ${ACTION}"
    ;;
esac

echo
echo "FluxPath Core Summary:"
echo "  Action:            ${ACTION}"
echo "  Backend directory: ${BACKEND_DIR_ABS}"
echo "  Fluidd panel:      ${INSTALL_FLUIDD_PANEL}"
echo "  Mainsail panel:    ${INSTALL_MAINSAIL_PANEL}"
echo "  Dry-run:           ${DRY_RUN}"
echo "  Snapshots:         ${SNAPSHOT_DIR}"
