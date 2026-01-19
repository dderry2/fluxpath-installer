#!/usr/bin/env bash

# ============================
# FluxPath Config Doctor Menu
# ============================

show_menu() {
  clear
  echo "======================================="
  echo "        FluxPath Config Doctor"
  echo "======================================="
  echo "Choose an option:"
  echo
  echo "  1) Dry-run (show what would move)"
  echo "  2) Clean (strict MMU + strict config)"
  echo "  3) Scan (CRLF + macro/Jinja checks)"
  echo "  4) Restore from archive"
  echo "  5) Exit"
  echo
  read -rp "Enter choice: " choice

  case "$choice" in
    1)
      echo
      echo "Running dry-run..."
      "$0" dry-run
      pause_menu
      ;;
    2)
      echo
      echo "Running strict cleanup..."
      "$0" clean
      pause_menu
      ;;
    3)
      echo
      echo "Running scan..."
      "$0" scan
      pause_menu
      ;;
    4)
      echo
      echo "Available archives:"
      ls -1 "${ARCHIVE_ROOT}"
      echo
      read -rp "Enter archive name to restore: " arch
      "$0" restore "$arch"
      pause_menu
      ;;
    5)
      echo "Goodbye."
      exit 0
      ;;
    *)
      echo "Invalid choice."
      pause_menu
      ;;
  esac
}

pause_menu() {
  echo
  read -rp "Press Enter to return to menu..." _
  show_menu
}

# If script is run with no arguments, show menu
if [[ $# -eq 0 ]]; then
  show_menu
  exit 0
fi


#
# FluxPath Config Doctor
# - Strict MMU cleaner (mmu/)
# - Strict Klipper config cleaner (printer_data/config/)
# - Dry-run + restore
# - CRLF detector + light macro/Jinja checks
#

set -euo pipefail

CONFIG_DIR="${HOME}/printer_data/config"
MMU_DIR="${CONFIG_DIR}/mmu"
ARCHIVE_ROOT="${CONFIG_DIR}/config_archives"

mkdir -p "${ARCHIVE_ROOT}"

timestamp() {
  date +%Y%m%d_%H%M%S
}

log() {
  echo "[ConfigDoctor] $*"
}

usage() {
  cat <<EOF
FluxPath Config Doctor

Usage:
  $0 dry-run          # Show what WOULD be moved (MMU + config)
  $0 clean            # Perform strict cleanup (MMU + config)
  $0 restore <dir>    # Restore from archive directory name (under ${ARCHIVE_ROOT})
  $0 scan             # Scan for CRLF + suspicious macro/Jinja issues

Archives are stored in: ${ARCHIVE_ROOT}
EOF
}

# --- MMU strict rules ---

is_mmu_required_file() {
  local rel="$1"
  case "$rel" in
    mmu/mmu_main.cfg \
    mmu/mmu_vars.cfg \
    mmu/mmu_primitives.cfg \
    mmu/mmu_preload.cfg \
    mmu/mmu_load.cfg \
    mmu/mmu_unload.cfg \
    mmu/mmu_toolchange.cfg \
    mmu/mmu_sensors.cfg \
    mmu/mmu_calibration.cfg \
    mmu/mmu_diagnostics.cfg \
    mmu/mmu_ui.cfg \
    mmu/mmu_hardware.cfg \
    mmu/mmu_steppers.cfg)
      return 0 ;;
    *) return 1 ;;
  esac
}

is_mmu_required_dir() {
  local rel="$1"
  case "$rel" in
    mmu \
    mmu/core \
    mmu/flows \
    mmu/debug \
    mmu/sensors \
    mmu/ui)
      return 0 ;;
    *) return 1 ;;
  esac
}

# --- Config strict rules ---

is_config_required_file() {
  local rel="$1"
  case "$rel" in
    printer.cfg \
    moonraker.conf)
      return 0 ;;
  esac

  case "$rel" in
    *.cfg|*.conf)
      return 0 ;;
    *) return 1 ;;
  esac
}

is_config_required_dir() {
  local rel="$1"
  case "$rel" in
    . \
    mmu \
    macros \
    scripts \
    timelapse \
    gcodes \
    cfg.d|*.cfg.d)
      return 0 ;;
    *) return 1 ;;
  esac
}

# --- Core movers ---

plan_moves() {
  local root="$1"
  local archive="$2"
  local mode="$3"   # mmu or config
  local dry="$4"    # 0/1

  while IFS= read -r -d '' path; do
    rel="${path#$CONFIG_DIR/}"

    # Directories: decide if they are allowed
    if [[ -d "$path" ]]; then
      if [[ "$mode" == "mmu" ]]; then
        if is_mmu_required_dir "$rel"; then
          continue
        fi
        # Only touch dirs under mmu/
        [[ "$rel" == mmu/* || "$rel" == mmu ]] || continue
      else
        if is_config_required_dir "$rel"; then
          continue
        fi
      fi
      # We don't delete dirs, they’ll be recreated in archive if needed
      continue
    fi

    # Files:
    if [[ "$mode" == "mmu" ]]; then
      # Only consider files under mmu/
      [[ "$rel" == mmu/* ]] || continue
      if is_mmu_required_file "$rel"; then
        continue
      fi
    else
      # Whole config tree
      if is_config_required_file "$rel"; then
        continue
      fi
    fi

    dest="${archive}/${rel}"
    if [[ "$dry" -eq 1 ]]; then
      log "WOULD MOVE: ${rel} -> ${dest}"
    else
      mkdir -p "$(dirname "$dest")"
      mv "$path" "$dest"
      log "MOVED: ${rel} -> ${dest}"
    fi
  done < <(find "$root" -mindepth 1 -print0)
}

do_dry_run() {
  log "Dry-run: MMU strict cleanup plan"
  archive="${ARCHIVE_ROOT}/dryrun_$(timestamp)_mmu"
  plan_moves "${CONFIG_DIR}" "${archive}" "mmu" 1
  log "Dry-run: Config strict cleanup plan"
  archive="${ARCHIVE_ROOT}/dryrun_$(timestamp)_config"
  plan_moves "${CONFIG_DIR}" "${archive}" "config" 1
}

do_clean() {
  archive="${ARCHIVE_ROOT}/archive_$(timestamp)"
  log "Creating archive: ${archive}"
  mkdir -p "${archive}"

  log "Cleaning MMU (strict)…"
  plan_moves "${CONFIG_DIR}" "${archive}" "mmu" 0

  log "Cleaning main config (strict)…"
  plan_moves "${CONFIG_DIR}" "${archive}" "config" 0

  log "Cleanup complete. Archive at: ${archive}"
}

do_restore() {
  local name="$1"
  local archive="${ARCHIVE_ROOT}/${name}"

  if [[ ! -d "$archive" ]]; then
    log "Archive not found: ${archive}"
    exit 1
  fi

  log "Restoring from archive: ${archive}"
  while IFS= read -r -d '' path; do
    rel="${path#$archive/}"
    dest="${CONFIG_DIR}/${rel}"
    mkdir -p "$(dirname "$dest")"
    mv "$path" "$dest"
    log "RESTORED: ${rel}"
  done < <(find "$archive" -type f -print0)

  log "Restore complete."
}

do_scan() {
  log "Scanning for CRLF in ${CONFIG_DIR}…"
  if grep -R $'\r' "${CONFIG_DIR}" >/dev/null 2>&1; then
    log "CRLF FOUND. Files:"
    grep -R -n $'\r' "${CONFIG_DIR}" || true
  else
    log "No CRLF detected."
  fi

  log "Scanning for duplicate gcode_macro names…"
  awk '
    /^

\[gcode_macro / {
      name=$2
      gsub(/\]

/,"",name)
      count[name]++
    }
    END {
      for (n in count) if (count[n]>1)
        printf("DUPLICATE MACRO: %s (%d times)\n", n, count[n])
    }
  ' "${CONFIG_DIR}"/*.cfg "${MMU_DIR}"/*.cfg 2>/dev/null || true

  log "Scanning for suspicious unbalanced Jinja blocks…"
  grep -R "{% " "${CONFIG_DIR}" | sed 's/^/[JINJA] /' || true
}

# --- Main ---

cmd="${1:-}"

case "$cmd" in
  dry-run)
    do_dry_run
    ;;
  clean)
    do_clean
    ;;
  restore)
    shift || true
    [[ $# -eq 1 ]] || { usage; exit 1; }
    do_restore "$1"
    ;;
  scan)
    do_scan
    ;;
  *)
    usage
    ;;
esac
