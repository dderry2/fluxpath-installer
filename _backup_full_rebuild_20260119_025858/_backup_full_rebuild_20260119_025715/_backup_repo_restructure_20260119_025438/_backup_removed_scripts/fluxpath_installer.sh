#!/usr/bin/env bash
# ============================================
# FluxPath MMU - FluxPath Installer v0.9.0-beta
# Offline, production-ready, menu-driven installer
# ============================================

set -e

# Colors
RED="\e[31m"; GRN="\e[32m"; YEL="\e[33m"; BLU="\e[34m"; MAG="\e[35m"; CYN="\e[36m"; RST="\e[0m"

FLUX_NAME="FluxPath MMU"
FLUX_INSTALLER_VERSION="0.9.0-beta"

CFG_ROOT="${HOME}/printer_data/config"
PRINTER_CFG="${CFG_ROOT}/printer.cfg"
MMU_DIR="${CFG_ROOT}/mmu"
BACKUP_DIR="${HOME}/mmu_backups"

mkdir -p "$BACKUP_DIR"

# ------------- Helpers -------------

pause() {
  echo
  read -rp "Press ENTER to continue..." _
}

header() {
  clear
  echo -e "${CYN}============================================${RST}"
  echo -e "${MAG}  ${FLUX_NAME}${RST}  ${YEL}(FluxPath Installer v${FLUX_INSTALLER_VERSION})${RST}"
  echo -e "${CYN}============================================${RST}"
  echo
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local ans
  echo -ne "${MAG}${prompt} ${RST}"
  read -r ans
  if [ -z "$ans" ]; then
    ans="$default"
  fi
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

get_service_status() {
  local svc="$1"
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    echo "ACTIVE"
  else
    echo "INACTIVE"
  fi
}

parse_macro_var() {
  local file="$1"
  local var="$2"
  if [ -f "$file" ]; then
    awk -F':' -v v="$var" '
      $1 ~ "^[[:space:]]*variable_"v"[[:space:]]*$" { sub(/^[[:space:]]*/, "", $2); print $2; exit }
      $1 ~ "^[[:space:]]*variable_"v"[[:space:]]" { sub(/^[[:space:]]*/, "", $2); print $2; exit }
    ' "$file"
  fi
}

# ------------- Backup / Restore -------------

backup_system() {
  header
  echo -e "${CYN}System Backup${RST}"
  echo
  local timestamp backup_file
  timestamp=$(date +"%Y%m%d_%H%M%S")
  backup_file="${BACKUP_DIR}/fluxpath_backup_${timestamp}.tar.gz"
  echo -e "${BLU}Creating backup at:${RST} ${backup_file}"
  tar -czf "$backup_file" \
    "${CFG_ROOT}" \
    "${HOME}/klipper" \
    "${HOME}/moonraker" \
    "${HOME}/mainsail" \
    "${HOME}/fluidd" \
    2>/dev/null || true
  echo
  echo -e "${GRN}Backup complete.${RST}"
  pause
}

restore_system() {
  header
  echo -e "${CYN}System Restore${RST}"
  echo
  if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}No backup directory found at ${BACKUP_DIR}.${RST}"
    pause
    return
  fi
  echo -e "${CYN}Available backups:${RST}"
  ls -1 "$BACKUP_DIR"
  echo
  read -rp "Enter backup filename to restore: " RESTORE_FILE
  if [ ! -f "${BACKUP_DIR}/${RESTORE_FILE}" ]; then
    echo -e "${RED}Backup file not found.${RST}"
    pause
    return
  fi
  if ! confirm "Are you sure you want to restore this backup? (y/N): " "n"; then
    echo -e "${YEL}Restore cancelled.${RST}"
    pause
    return
  fi
  echo -e "${YEL}Restoring backup...${RST}"
  tar -xzf "${BACKUP_DIR}/${RESTORE_FILE}" -C "${HOME}"
  echo -e "${GRN}Restore complete.${RST}"
  echo
  restart_services
}

# ------------- Restart Services -------------

restart_services() {
  echo -e "${CYN}Restarting Klipper and Moonraker...${RST}"
  sudo systemctl restart klipper 2>/dev/null || true
  sudo systemctl restart moonraker 2>/dev/null || true
  echo -e "${GRN}Services restarted.${RST}"
  pause
}

# ------------- Show Current Configuration -------------

show_current_config() {
  header
  echo -e "${CYN}Current ${FLUX_NAME} Configuration${RST}"
  echo

  local mmu_installed="NO"
  local include_present="NO"
  [ -d "$MMU_DIR" ] && mmu_installed="YES"
  if [ -f "$PRINTER_CFG" ] && grep -q "mmu/mmu_main.cfg" "$PRINTER_CFG" 2>/dev/null; then
    include_present="YES"
  fi

  echo -e "${CYN}Installation:${RST}"
  echo "  MMU directory:        $MMU_DIR"
  echo "  MMU installed:        $mmu_installed"
  echo "  printer.cfg include:  $include_present"
  echo

  local VARS_FILE="${MMU_DIR}/mmu_vars.cfg"
  local lanes active_lane
  lanes=$(parse_macro_var "$VARS_FILE" "mmu_lanes")
  active_lane=$(parse_macro_var "$VARS_FILE" "active_lane")
  [ -z "$lanes" ] && lanes="(unknown)"
  [ -z "$active_lane" ] && active_lane="(unknown)"

  echo -e "${CYN}Lanes:${RST}"
  echo "  Lanes:       $lanes"
  echo "  Active lane: $active_lane"
  echo

  local EXTR_FILE="${MMU_DIR}/mmu_extruders.cfg"
  echo -e "${CYN}Extruder Steppers:${RST}"
  if [ -f "$EXTR_FILE" ]; then
    awk '
      /^

\[extruder_stepper[[:space:]]+mmu_extruder_/ {
        gsub(/

\[|\]

/,"",$0);
        split($2,a,"_");
        lane=a[3];
        in_block=1;
        step=""; dir=""; en="";
      }
      in_block && $1 ~ /^step_pin/   { step=$2 }
      in_block && $1 ~ /^dir_pin/    { dir=$2 }
      in_block && $1 ~ /^enable_pin/ { en=$2 }
      in_block && NF==0 {
        if (lane != "") {
          printf("  mmu_extruder_%s -> step=%s dir=%s enable=%s\n", lane, step, dir, en);
        }
        in_block=0;
      }
      END {
        if (in_block && lane != "") {
          printf("  mmu_extruder_%s -> step=%s dir=%s enable=%s\n", lane, step, dir, en);
        }
      }
    ' "$EXTR_FILE"
  else
    echo "  (no mmu_extruders.cfg found)"
  fi
  echo

  echo -e "${CYN}Variables:${RST}"
  local p1 p2 p3 p4 c2s s2e np servo s_open s_cut
  p1=$(parse_macro_var "$VARS_FILE" "parking_to_cutter_1")
  p2=$(parse_macro_var "$VARS_FILE" "parking_to_cutter_2")
  p3=$(parse_macro_var "$VARS_FILE" "parking_to_cutter_3")
  p4=$(parse_macro_var "$VARS_FILE" "parking_to_cutter_4")
  c2s=$(parse_macro_var "$VARS_FILE" "cutter_to_filament_sensor")
  s2e=$(parse_macro_var "$VARS_FILE" "filament_sensor_to_extruder")
  np=$(parse_macro_var "$VARS_FILE" "nozzle_push")
  servo=$(parse_macro_var "$VARS_FILE" "cutter_servo")
  s_open=$(parse_macro_var "$VARS_FILE" "cutter_angle_open")
  s_cut=$(parse_macro_var "$VARS_FILE" "cutter_angle_cut")

  echo "  PARK→CUTTER: [${p1:-?}, ${p2:-?}, ${p3:-?}, ${p4:-?}]"
  echo "  Cutter→Sensor:      ${c2s:-?}"
  echo "  Sensor→Extruder:    ${s2e:-?}"
  echo "  Nozzle push:        ${np:-?}"
  echo "  Servo:              ${servo:-?}"
  echo "  Servo open angle:   ${s_open:-?}"
  echo "  Servo cut angle:    ${s_cut:-?}"
  echo

  echo -e "${CYN}Sensors (from printer.cfg):${RST}"
  if [ -f "$PRINTER_CFG" ]; then
    local pregate_present fs_present
    pregate_present=$(grep -E "^

\[filament_switch_sensor[[:space:]]+pregate\]

" "$PRINTER_CFG" 2>/dev/null || true)
    fs_present=$(grep -E "^

\[filament_switch_sensor[[:space:]]+filament_sensor\]

" "$PRINTER_CFG" 2>/dev/null || true)
    echo "  pregate:         $( [ -n "$pregate_present" ] && echo OK || echo MISSING )"
    echo "  filament_sensor: $( [ -n "$fs_present" ] && echo OK || echo MISSING )"
  else
    echo "  (printer.cfg not found)"
  fi
  echo

  echo -e "${CYN}Services:${RST}"
  local klip moon
  klip=$(get_service_status "klipper")
  moon=$(get_service_status "moonraker")
  echo "  Klipper:   $klip"
  echo "  Moonraker: $moon"

  echo
  echo -e "${GRN}End of configuration snapshot.${RST}"
  pause
}

# ------------- Validate Configuration -------------

validate_config() {
  header
  echo -e "${CYN}Validate Configuration${RST}"
  echo

  local ok=1

  if [ ! -f "$PRINTER_CFG" ]; then
    echo -e "${RED}printer.cfg not found at ${PRINTER_CFG}.${RST}"
    ok=0
  else
    echo -e "${GRN}printer.cfg found.${RST}"
  fi

  if [ ! -d "$MMU_DIR" ]; then
    echo -e "${RED}MMU directory not found at ${MMU_DIR}.${RST}"
    ok=0
  else
    echo -e "${GRN}MMU directory found.${RST}"
  fi

  if ! grep -q "mmu/mmu_main.cfg" "$PRINTER_CFG" 2>/dev/null; then
    echo -e "${RED}[include mmu/mmu_main.cfg] not found in printer.cfg.${RST}"
    ok=0
  else
    echo -e "${GRN}MMU include present in printer.cfg.${RST}"
  fi

  for f in mmu_main.cfg mmu_vars.cfg mmu_extruders.cfg mmu_primitives.cfg mmu_preload.cfg mmu_load.cfg mmu_unload.cfg mmu_toolchange.cfg mmu_sensors.cfg mmu_ui.cfg mmu_calibration.cfg mmu_diagnostics.cfg; do
    if [ ! -f "${MMU_DIR}/${f}" ]; then
      echo -e "${RED}Missing MMU file: ${f}${RST}"
      ok=0
    fi
  done

  local VARS_FILE="${MMU_DIR}/mmu_vars.cfg"
  local lanes
  lanes=$(parse_macro_var "$VARS_FILE" "mmu_lanes")
  if [ -z "$lanes" ]; then
    echo -e "${RED}mmu_lanes not defined in mmu_vars.cfg.${RST}"
    ok=0
  else
    echo -e "${GRN}mmu_lanes=${lanes}${RST}"
  fi

  if [ "$ok" -eq 1 ]; then
    echo
    echo -e "${GRN}Configuration validation PASSED.${RST}"
  else
    echo
    echo -e "${RED}Configuration validation FAILED. See messages above.${RST}"
  fi
  pause
}

# ------------- Uninstall MMU -------------

uninstall_mmu() {
  header
  echo -e "${CYN}Uninstall ${FLUX_NAME}${RST}"
  echo
  if ! confirm "This will remove MMU configs and printer.cfg include. Continue? (y/N): " "n"; then
    echo -e "${YEL}Uninstall cancelled.${RST}"
    pause
    return
  fi

  if [ -d "$MMU_DIR" ]; then
    rm -rf "$MMU_DIR"
    echo -e "${GRN}Removed ${MMU_DIR}.${RST}"
  else
    echo -e "${YEL}MMU directory not found; nothing to remove.${RST}"
  fi

  if [ -f "$PRINTER_CFG" ]; then
    tmpfile=$(mktemp)
    grep -v "mmu/mmu_main.cfg" "$PRINTER_CFG" > "$tmpfile" || true
    mv "$tmpfile" "$PRINTER_CFG"
    echo -e "${GRN}Removed MMU include from printer.cfg.${RST}"
  fi

  echo
  echo -e "${GRN}${FLUX_NAME} uninstalled.${RST}"
  pause
}

# ------------- Factory Reset MMU -------------

factory_reset_mmu() {
  header
  echo -e "${CYN}Factory Reset ${FLUX_NAME}${RST}"
  echo
  if ! confirm "This will delete MMU configs and reinstall from scratch. Continue? (y/N): " "n"; then
    echo -e "${YEL}Factory reset cancelled.${RST}"
    pause
    return
  fi
  if [ -d "$MMU_DIR" ]; then
    rm -rf "$MMU_DIR"
    echo -e "${GRN}Removed existing MMU directory.${RST}"
  fi
  install_fluxpath "normal"
}

# ------------- Generate Slicer Template -------------

generate_slicer_template() {
  header
  echo -e "${CYN}Generate Slicer Template${RST}"
  echo

  local out="${MMU_DIR}/fluxpath_slicer_template.txt"
  mkdir -p "$MMU_DIR"

  cat > "$out" <<'EOF'
# ============================================
# FluxPath MMU - Slicer Template
# ============================================

# Tools:
#   T0 -> Lane 1
#   T1 -> Lane 2
#   T2 -> Lane 3 (if configured)
#   T3 -> Lane 4 (if configured)

# Start G-code (example):
#   G28
#   M190 S[first_layer_bed_temperature]
#   M109 S[first_layer_temperature]
#   MMU_UI_PRINT_VARS

# Toolchange G-code:
#   ; Called when switching tools
#   ; Slicer will emit T0/T1/T2/T3 automatically
#   ; No extra code required if macros T0..T3 are defined in Klipper.

# End G-code (example):
#   M104 S0
#   M140 S0
#   G91
#   G1 Z10 F600
#   G90
#   MMU_UI_UNLOAD
#   M84

EOF

  echo -e "${GRN}Slicer template written to:${RST} ${out}"
  pause
}

# ------------- Deep Diagnostics -------------

deep_diagnostics() {
  header
  echo -e "${CYN}Deep Diagnostics${RST}"
  echo

  show_current_config

  echo
  echo -e "${CYN}Additional Checks:${RST}"
  echo

  if [ -f "$PRINTER_CFG" ]; then
    if grep -q "mmu/mmu_main.cfg" "$PRINTER_CFG"; then
      echo -e "${GRN}Include chain: printer.cfg -> mmu/mmu_main.cfg OK.${RST}"
    else
      echo -e "${RED}Include chain: mmu/mmu_main.cfg missing from printer.cfg.${RST}"
    fi
  fi

  echo
  echo -e "${CYN}Systemd Services:${RST}"
  echo "  klipper:   $(get_service_status "klipper")"
  echo "  moonraker: $(get_service_status "moonraker")"

  echo
  echo -e "${CYN}MMU Files:${RST}"
  for f in mmu_main.cfg mmu_vars.cfg mmu_extruders.cfg mmu_primitives.cfg mmu_preload.cfg mmu_load.cfg mmu_unload.cfg mmu_toolchange.cfg mmu_sensors.cfg mmu_ui.cfg mmu_calibration.cfg mmu_diagnostics.cfg; do
    if [ -f "${MMU_DIR}/${f}" ]; then
      echo -e "  ${GRN}${f}${RST}"
    else
      echo -e "  ${RED}${f} (missing)${RST}"
    fi
  done

  echo
  echo -e "${GRN}Diagnostics complete.${RST}"
  pause
}

# ------------- Install FluxPath MMU -------------

install_fluxpath() {
  local mode="$1"  # "normal" or "dryrun"

  header
  echo -e "${CYN}Install ${FLUX_NAME}${RST}"
  echo

  echo -e "${CYN}Using Klipper config directory:${RST} ${CFG_ROOT}"
  mkdir -p "$CFG_ROOT"
  mkdir -p "$MMU_DIR"

  local NEW_INSTANCE
  echo
  echo -e "${MAG}Install ${FLUX_NAME} as a NEW Klipper instance? (y/N): ${RST}"
  read -r NEW_INSTANCE

  local INSTANCE_NAME INSTANCE_CFG INSTANCE_PORT
  if [[ "$NEW_INSTANCE" =~ ^[Yy]$ ]]; then
    echo
    read -rp "Instance name (default: klipper-mmu): " INSTANCE_NAME
    INSTANCE_NAME=${INSTANCE_NAME:-klipper-mmu}
    read -rp "Instance config dir (default: ${HOME}/printer_data/config_mmu): " INSTANCE_CFG
    INSTANCE_CFG=${INSTANCE_CFG:-"${HOME}/printer_data/config_mmu"}
    read -rp "Moonraker HTTP port (default: 7126): " INSTANCE_PORT
    INSTANCE_PORT=${INSTANCE_PORT:-7126}

    if [ "$mode" = "dryrun" ]; then
      echo -e "${YEL}[DRY-RUN] Would create MMU instance services and config at:${RST} ${INSTANCE_CFG}"
    else
      mkdir -p "$INSTANCE_CFG"
      local KLIPPER_SERVICE="/etc/systemd/system/${INSTANCE_NAME}.service"
      sudo bash -c "cat > $KLIPPER_SERVICE" <<EOF
[Unit]
Description=Klipper MMU Instance
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/home/$USER/klippy-env/bin/python /home/$USER/klipper/klippy/klippy.py $INSTANCE_CFG/printer.cfg -l $INSTANCE_CFG/klippy.log
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

      local MOONRAKER_SERVICE="/etc/systemd/system/moonraker-${INSTANCE_NAME}.service"
      sudo bash -c "cat > $MOONRAKER_SERVICE" <<EOF
[Unit]
Description=Moonraker MMU Instance
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/home/$USER/moonraker-env/bin/python /home/$USER/moonraker/moonraker/moonraker.py -c $INSTANCE_CFG/moonraker.conf
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

      cat > "$INSTANCE_CFG/moonraker.conf" <<EOF
[server]
host: 0.0.0.0
port: $INSTANCE_PORT

[authorization]
trusted_clients:
  127.0.0.1
EOF

      if [ ! -f "$INSTANCE_CFG/printer.cfg" ]; then
        echo "# MMU Instance printer.cfg" > "$INSTANCE_CFG/printer.cfg"
      fi

      CFG_ROOT="$INSTANCE_CFG"
      PRINTER_CFG="$CFG_ROOT/printer.cfg"
      MMU_DIR="$CFG_ROOT/mmu"
      mkdir -p "$MMU_DIR"
      echo -e "${GRN}MMU instance created at ${INSTANCE_CFG}.${RST}"
    fi
  fi

  echo
  read -rp "How many MMU lanes (2–4, default 2): " USER_MMU_LANES
  USER_MMU_LANES=${USER_MMU_LANES:-2}
  if ! [[ "$USER_MMU_LANES" =~ ^[0-9]+$ ]] || [ "$USER_MMU_LANES" -lt 2 ] || [ "$USER_MMU_LANES" -gt 4 ]; then
    echo -e "${RED}Invalid lane count. Must be 2–4.${RST}"
    pause
    return
  fi

  local MMU_EXTRUDER_CFG_CONTENT
  MMU_EXTRUDER_CFG_CONTENT="# ============================================
# File: mmu/mmu_extruders.cfg
# Purpose:
#   Auto-generated MMU extruder stepper definitions.
#   Only one MMU extruder is enabled at a time.
# ============================================ 
"

  for ((i=1; i<=USER_MMU_LANES; i++)); do
    echo
    echo -e "${BLU}MMU Extruder $i pins:${RST}"
    read -rp "  step_pin: " STEP_PIN
    read -rp "  dir_pin: " DIR_PIN
    read -rp "  enable_pin: " ENABLE_PIN
    if [[ -z "$STEP_PIN" || -z "$DIR_PIN" || -z "$ENABLE_PIN" ]]; then
      echo -e "${RED}Pins cannot be empty.${RST}"
      pause
      return
    fi
    MMU_EXTRUDER_CFG_CONTENT+="

[extruder_stepper mmu_extruder_${i}]
step_pin: ${STEP_PIN}
dir_pin: ${DIR_PIN}
enable_pin: ${ENABLE_PIN}
microsteps: 16
rotation_distance: 22.67895
gear_ratio: 3:1
extruder: extruder
"
  done

  local CUSTOM_MMU_VARS
  echo
  echo -e "${MAG}Customize MMU geometry variables now? (y/N): ${RST}"
  read -r CUSTOM_MMU_VARS

  local PARK_1=55 PARK_2=55 PARK_3=55 PARK_4=55
  local CUTTER_TO_SENSOR=40 SENSOR_TO_EXTRUDER=60 NOZZLE_PUSH=8.0
  local CUTTER_SERVO="mmu_cutter" CUTTER_OPEN=30 CUTTER_CUT=120

  if [[ "$CUSTOM_MMU_VARS" =~ ^[Yy]$ ]]; then
    echo
    echo -e "${BLU}Enter MMU geometry values (ENTER = default).${RST}"
    read -rp "  Lane 1 PARK→CUTTER (default 55): " TMP; PARK_1=${TMP:-55}
    read -rp "  Lane 2 PARK→CUTTER (default 55): " TMP; PARK_2=${TMP:-55}
    if [ "$USER_MMU_LANES" -ge 3 ]; then
      read -rp "  Lane 3 PARK→CUTTER (default 55): " TMP; PARK_3=${TMP:-55}
    fi
    if [ "$USER_MMU_LANES" -ge 4 ]; then
      read -rp "  Lane 4 PARK→CUTTER (default 55): " TMP; PARK_4=${TMP:-55}
    fi
    read -rp "  Cutter → Sensor (default 40): " TMP; CUTTER_TO_SENSOR=${TMP:-40}
    read -rp "  Sensor → Extruder (default 60): " TMP; SENSOR_TO_EXTRUDER=${TMP:-60}
    read -rp "  Nozzle push (default 8.0): " TMP; NOZZLE_PUSH=${TMP:-8.0}
    read -rp "  Cutter servo name (default mmu_cutter): " TMP; CUTTER_SERVO=${TMP:-mmu_cutter}
    read -rp "  Cutter servo OPEN angle (default 30): " TMP; CUTTER_OPEN=${TMP:-30}
    read -rp "  Cutter servo CUT angle (default 120): " TMP; CUTTER_CUT=${TMP:-120}
  fi

  if [ "$mode" = "dryrun" ]; then
    echo
    echo -e "${YEL}[DRY-RUN] Would write mmu_extruders.cfg, mmu_vars.cfg, and all MMU config files to:${RST} ${MMU_DIR}"
    echo -e "${YEL}[DRY-RUN] Would append [include mmu/mmu_main.cfg] to printer.cfg if missing.${RST}"
    pause
    return
  fi

  printf "%s\n" "$MMU_EXTRUDER_CFG_CONTENT" > "${MMU_DIR}/mmu_extruders.cfg"

  cat > "${MMU_DIR}/mmu_vars.cfg" <<EOF
# ============================================
# File: mmu/mmu_vars.cfg
# Purpose:
#   Auto-generated MMU variable definitions.
# ============================================

[gcode_macro MMU_VARS]

variable_mmu_lanes: ${USER_MMU_LANES}
variable_active_lane: 1

variable_parking_to_cutter_1: ${PARK_1}
variable_parking_to_cutter_2: ${PARK_2}
variable_parking_to_cutter_3: ${PARK_3}
variable_parking_to_cutter_4: ${PARK_4}

variable_cutter_to_filament_sensor: ${CUTTER_TO_SENSOR}
variable_filament_sensor_to_extruder: ${SENSOR_TO_EXTRUDER}

variable_cutter_servo: "${CUTTER_SERVO}"
variable_cutter_angle_open: ${CUTTER_OPEN}
variable_cutter_angle_cut: ${CUTTER_CUT}

variable_nozzle_push: ${NOZZLE_PUSH}

gcode:
  RESPOND PREFIX=MMU MSG="MMU_VARS loaded: lanes={{ printer['gcode_macro MMU_VARS'].mmu_lanes }}, active_lane={{ printer['gcode_macro MMU_VARS'].active_lane }}"
EOF

  cat > "${MMU_DIR}/mmu_main.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_main.cfg
# Purpose:
#   Master include file for the MMU subsystem.
#   This is the ONLY file included from printer.cfg.
# ============================================

[include mmu_extruders.cfg]
[include mmu_vars.cfg]
[include mmu_primitives.cfg]
[include mmu_preload.cfg]
[include mmu_load.cfg]
[include mmu_unload.cfg]
[include mmu_toolchange.cfg]
[include mmu_sensors.cfg]
[include mmu_ui.cfg]
[include mmu_calibration.cfg]
[include mmu_diagnostics.cfg]
EOF

  cat > "${MMU_DIR}/mmu_primitives.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_primitives.cfg
# Purpose:
#   Low-level movement + lane selection.
#   MMU extruders are synced to [extruder].
#   Only the active lane's MMU stepper is enabled.
# ============================================

[gcode_macro MMU_SET_LANE]
description: Set active MMU lane (1–4)
gcode:
  {% set lane = params.LANE|int %}
  {% set v = printer["gcode_macro MMU_VARS"] %}
  {% if lane < 1 or lane > v.mmu_lanes %}
    RESPOND PREFIX=MMU MSG="ERROR: Invalid lane {{ lane }} (mmu_lanes={{ v.mmu_lanes }})"
  {% else %}
    SET_GCODE_VARIABLE MACRO=MMU_VARS VARIABLE=active_lane VALUE={lane}
    RESPOND PREFIX=MMU MSG="Active MMU lane set to {{ lane }}"
  {% endif %}

[gcode_macro MMU_GET_PARKING_TO_CUTTER]
description: Internal helper to get lane-specific parking_to_cutter
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  {% set lane = v.active_lane|int %}
  {% if lane == 1 %}
    SET_GCODE_VARIABLE MACRO=MMU_VARS VARIABLE=parking_to_cutter VALUE={v.parking_to_cutter_1}
  {% elif lane == 2 %}
    SET_GCODE_VARIABLE MACRO=MMU_VARS VARIABLE=parking_to_cutter VALUE={v.parking_to_cutter_2}
  {% elif lane == 3 %}
    SET_GCODE_VARIABLE MACRO=MMU_VARS VARIABLE=parking_to_cutter VALUE={v.parking_to_cutter_3}
  {% elif lane == 4 %}
    SET_GCODE_VARIABLE MACRO=MMU_VARS VARIABLE=parking_to_cutter VALUE={v.parking_to_cutter_4}
  {% else %}
    SET_GCODE_VARIABLE MACRO=MMU_VARS VARIABLE=parking_to_cutter VALUE={v.parking_to_cutter_1}
  {% endif %}

[gcode_macro MMU_DISABLE]
gcode:
  SET_STEPPER_ENABLE STEPPER=mmu_extruder_1 ENABLE=0
  SET_STEPPER_ENABLE STEPPER=mmu_extruder_2 ENABLE=0
  {% if printer["gcode_macro MMU_VARS"].mmu_lanes >= 3 %}
    SET_STEPPER_ENABLE STEPPER=mmu_extruder_3 ENABLE=0
  {% endif %}
  {% if printer["gcode_macro MMU_VARS"].mmu_lanes >= 4 %}
    SET_STEPPER_ENABLE STEPPER=mmu_extruder_4 ENABLE=0
  {% endif %}

[gcode_macro MMU_ENABLE]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  {% set lane = v.active_lane|int %}
  MMU_DISABLE
  {% if lane == 1 %}
    SET_STEPPER_ENABLE STEPPER=mmu_extruder_1 ENABLE=1
  {% elif lane == 2 %}
    SET_STEPPER_ENABLE STEPPER=mmu_extruder_2 ENABLE=1
  {% elif lane == 3 %}
    SET_STEPPER_ENABLE STEPPER=mmu_extruder_3 ENABLE=1
  {% elif lane == 4 %}
    SET_STEPPER_ENABLE STEPPER=mmu_extruder_4 ENABLE=1
  {% endif %}
  RESPOND PREFIX=MMU MSG="MMU_ENABLE: lane {{ lane }} stepper active"

[gcode_macro MMU_MOVE_E]
description: Move E, synced MMU + hotend extruder
gcode:
  {% set e = params.E|float %}
  {% set f = params.F|default(1200)|float %}
  MMU_ENABLE
  G91
  G1 E{e} F{f}
  G90

[gcode_macro MMU_PARK]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  MMU_GET_PARKING_TO_CUTTER
  {% set v = printer["gcode_macro MMU_VARS"] %}
  MMU_MOVE_E E={-v.parking_to_cutter} F=1800
  RESPOND PREFIX=MMU MSG="MMU lane {{ v.active_lane }} parked inside splitter"

[gcode_macro MMU_MOVE_TO_CUTTER_FROM_PARK]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  MMU_GET_PARKING_TO_CUTTER
  {% set v = printer["gcode_macro MMU_VARS"] %}
  MMU_MOVE_E E={v.parking_to_cutter} F=1800

[gcode_macro MMU_WAIT_FOR_FILAMENT_SENSOR]
description: Wait for post-cutter filament sensor to trigger
gcode:
  {% set timeout = params.TIMEOUT|default(2000)|int %}
  {% set start = printer.clock.realtime %}
  {% set sensor = printer["filament_switch_sensor filament_sensor"] %}

  RESPOND PREFIX=MMU MSG="Waiting for filament sensor..."

  {% while printer.clock.realtime - start < timeout %}
    {% if sensor.filament_detected %}
      RESPOND PREFIX=MMU MSG="Filament sensor triggered."
      {% break %}
    {% endif %}
    G4 P50
  {% endwhile %}

  {% if not sensor.filament_detected %}
    MMU_ERROR MSG="Expected filament sensor trigger, but it never occurred."
  {% endif %}

[gcode_macro MMU_MOVE_TO_FILAMENT_SENSOR_EXPECT]
description: Move forward until filament sensor should trigger
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  MMU_MOVE_E E={v.cutter_to_filament_sensor} F=1800
  MMU_WAIT_FOR_FILAMENT_SENSOR TIMEOUT=2000
EOF

  cat > "${MMU_DIR}/mmu_preload.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_preload.cfg
# Purpose:
#   Preload from pregate into PARK for active lane.
# ============================================

[gcode_macro MMU_PRELOAD_FROM_PREGATE]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  RESPOND PREFIX=MMU MSG="PRELOAD: filament detected at pregate, staging for lane {{ v.active_lane }}"

  MMU_MOVE_TO_CUTTER_FROM_PARK
  MMU_MOVE_TO_FILAMENT_SENSOR_EXPECT

  RESPOND PREFIX=MMU MSG="PRELOAD: filament at post-cutter sensor, retracting to park"

  MMU_PARK

  RESPOND PREFIX=MMU MSG="PRELOAD complete, lane {{ v.active_lane }} parked"
EOF

  cat > "${MMU_DIR}/mmu_load.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_load.cfg
# Purpose:
#   Load filament for active lane from PARK → NOZZLE.
# ============================================

[gcode_macro MMU_LOAD]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  RESPOND PREFIX=MMU MSG="LOAD: lane {{ v.active_lane }} from park to nozzle"

  MMU_MOVE_TO_CUTTER_FROM_PARK
  MMU_MOVE_TO_FILAMENT_SENSOR_EXPECT

  MMU_MOVE_E E={v.filament_sensor_to_extruder} F=1500

  G91
  G1 E={v.nozzle_push} F600
  G90

  RESPOND PREFIX=MMU MSG="LOAD complete, lane {{ v.active_lane }} at nozzle"
EOF

  cat > "${MMU_DIR}/mmu_unload.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_unload.cfg
# Purpose:
#   Unload filament for active lane from NOZZLE → PARK.
# ============================================

[gcode_macro MMU_TIP_FORM]
gcode:
  G91
  G1 E-2.0 F1800
  G1 E1.0 F600
  G1 E-3.0 F1800
  G90

[gcode_macro MMU_CUT_SEQUENCE]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  SET_SERVO SERVO={v.cutter_servo} ANGLE={v.cutter_angle_open}
  G4 P200
  MMU_MOVE_E E=5 F600
  SET_SERVO SERVO={v.cutter_servo} ANGLE={v.cutter_angle_cut}
  G4 P200
  MMU_MOVE_E E=3 F600
  SET_SERVO SERVO={v.cutter_servo} ANGLE={v.cutter_angle_open}

[gcode_macro MMU_UNLOAD]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  RESPOND PREFIX=MMU MSG="UNLOAD: lane {{ v.active_lane }} from nozzle to park"

  MMU_TIP_FORM

  MMU_MOVE_E E={-(v.filament_sensor_to_extruder + 5)} F=1800

  {% if printer["filament_switch_sensor filament_sensor"].filament_detected %}
    MMU_ERROR MSG="Filament sensor still triggered after retract. Jam suspected."
  {% endif %}

  MMU_MOVE_E E={-v.cutter_to_filament_sensor} F=1800

  MMU_CUT_SEQUENCE

  MMU_PARK

  RESPOND PREFIX=MMU MSG="UNLOAD complete, lane {{ v.active_lane }} parked"
EOF

  cat > "${MMU_DIR}/mmu_toolchange.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_toolchange.cfg
# Purpose:
#   Lane-aware toolchange + T0–T3 for slicer.
# ============================================

[gcode_macro MMU_TOOL_CHANGE]
description: Unload current lane, switch lane, load new lane
gcode:
  {% set lane = params.LANE|int %}
  {% set v = printer["gcode_macro MMU_VARS"] %}

  {% if lane < 1 or lane > v.mmu_lanes %}
    MMU_ERROR MSG="Requested lane {{ lane }} but mmu_lanes={{ v.mmu_lanes }}"
  {% endif %}

  RESPOND PREFIX=MMU MSG="TOOL_CHANGE: from lane {{ v.active_lane }} to lane {{ lane }}"

  MMU_UNLOAD
  MMU_SET_LANE LANE={lane}
  MMU_LOAD

  RESPOND PREFIX=MMU MSG="TOOL_CHANGE complete, active lane {{ lane }}"

[gcode_macro T0]
gcode:
  MMU_TOOL_CHANGE LANE=1

[gcode_macro T1]
gcode:
  MMU_TOOL_CHANGE LANE=2

[gcode_macro T2]
gcode:
  MMU_TOOL_CHANGE LANE=3

[gcode_macro T3]
gcode:
  MMU_TOOL_CHANGE LANE=4
EOF

  cat > "${MMU_DIR}/mmu_sensors.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_sensors.cfg
# Purpose:
#   Sensor handlers + unified error macro.
# ============================================

[gcode_macro MMU_ERROR]
gcode:
  {% set msg = params.MSG|default("Unknown MMU error") %}
  RESPOND PREFIX=MMU MSG="ERROR: {msg}"
  CANCEL_PRINT

[gcode_macro MMU_PREGATE_HIT]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  RESPOND PREFIX=MMU MSG="PREGATE: filament detected for lane {{ v.active_lane }}"
  MMU_PRELOAD_FROM_PREGATE

[gcode_macro MMU_RUNOUT]
gcode:
  RESPOND PREFIX=MMU MSG="RUNOUT detected"
  PAUSE
EOF

  cat > "${MMU_DIR}/mmu_ui.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_ui.cfg
# Purpose:
#   Simple UI macros + lane helpers.
# ============================================

[gcode_macro MMU_UI_PRELOAD]
gcode:
  MMU_PRELOAD_FROM_PREGATE

[gcode_macro MMU_UI_LOAD]
gcode:
  MMU_LOAD

[gcode_macro MMU_UI_UNLOAD]
gcode:
  MMU_UNLOAD

[gcode_macro MMU_UI_PARK]
gcode:
  MMU_PARK

[gcode_macro MMU_UI_SET_LANE]
gcode:
  {% set lane = params.LANE|int %}
  MMU_SET_LANE LANE={lane}

[gcode_macro MMU_UI_PRINT_VARS]
gcode:
  {% set v = printer["gcode_macro MMU_VARS"] %}
  RESPOND PREFIX=MMU MSG="mmu_lanes={{ v.mmu_lanes }}"
  RESPOND PREFIX=MMU MSG="active_lane={{ v.active_lane }}"
  RESPOND PREFIX=MMU MSG="parking_to_cutter_1={{ v.parking_to_cutter_1 }}"
  RESPOND PREFIX=MMU MSG="parking_to_cutter_2={{ v.parking_to_cutter_2 }}"
  RESPOND PREFIX=MMU MSG="parking_to_cutter_3={{ v.parking_to_cutter_3 }}"
  RESPOND PREFIX=MMU MSG="parking_to_cutter_4={{ v.parking_to_cutter_4 }}"
  RESPOND PREFIX=MMU MSG="cutter_to_filament_sensor={{ v.cutter_to_filament_sensor }}"
  RESPOND PREFIX=MMU MSG="filament_sensor_to_extruder={{ v.filament_sensor_to_extruder }}"
  RESPOND PREFIX=MMU MSG="cutter_servo={{ v.cutter_servo }}"
  RESPOND PREFIX=MMU MSG="cutter_angle_open={{ v.cutter_angle_open }}"
  RESPOND PREFIX=MMU MSG="cutter_angle_cut={{ v.cutter_angle_cut }}"
  RESPOND PREFIX=MMU MSG="nozzle_push={{ v.nozzle_push }}"
EOF

  cat > "${MMU_DIR}/mmu_calibration.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_calibration.cfg
# Purpose:
#   Lane-aware calibration helpers.
# ============================================

[gcode_macro MMU_CAL_PARK_TO_CUTTER_LANE]
description: Calibrate PARK → CUTTER for a specific lane
gcode:
  {% set lane = params.LANE|int %}
  MMU_SET_LANE LANE={lane}
  RESPOND PREFIX=MMU MSG="CAL: Lane {{ lane }} PARK→CUTTER. Move filament to cutter, measure distance, then update parking_to_cutter_{{ lane }} in mmu_vars.cfg."

[gcode_macro MMU_CAL_CUTTER_TO_FILAMENT_SENSOR]
gcode:
  RESPOND PREFIX=MMU MSG="CAL: Move filament to cutter, then advance until sensor triggers."
  RESPOND PREFIX=MMU MSG="Measure distance and update variable_cutter_to_filament_sensor."

[gcode_macro MMU_CAL_FILAMENT_SENSOR_TO_EXTRUDER]
gcode:
  RESPOND PREFIX=MMU MSG="CAL: Start at filament sensor, advance until extruder grabs."
  RESPOND PREFIX=MMU MSG="Measure distance and update variable_filament_sensor_to_extruder."
EOF

  cat > "${MMU_DIR}/mmu_diagnostics.cfg" <<'EOF'
# ============================================
# File: mmu/mmu_diagnostics.cfg
# Purpose:
#   Diagnostics for sensors + lanes.
# ============================================

[gcode_macro MMU_DIAG_SENSOR_TEST]
gcode:
  {% set pregate = printer["filament_switch_sensor pregate"] %}
  {% set fs = printer["filament_switch_sensor filament_sensor"] %}
  RESPOND PREFIX=MMU MSG="Pregate: {{ 'TRIGGERED' if pregate.filament_detected else 'open' }}"
  RESPOND PREFIX=MMU MSG="Filament Sensor: {{ 'TRIGGERED' if fs.filament_detected else 'open' }}"

[gcode_macro MMU_DIAG_EXPECT_SENSOR]
gcode:
  RESPOND PREFIX=MMU MSG="DIAG: Moving to filament sensor..."
  MMU_MOVE_TO_CUTTER_FROM_PARK
  MMU_MOVE_TO_FILAMENT_SENSOR_EXPECT
  RESPOND PREFIX=MMU MSG="DIAG: Sensor triggered as expected."

[gcode_macro MMU_DIAG_LANE]
description: Test load/unload for a specific lane
gcode:
  {% set lane = params.LANE|int %}
  MMU_SET_LANE LANE={lane}
  RESPOND PREFIX=MMU MSG="DIAG: Testing lane {{ lane }} load/unload"
  MMU_LOAD
  MMU_UNLOAD
  RESPOND PREFIX=MMU MSG="DIAG: Lane {{ lane }} test complete"
EOF

  if ! grep -q "mmu/mmu_main.cfg" "$PRINTER_CFG" 2>/dev/null; then
    {
      echo ""
      echo "# ${FLUX_NAME} subsystem"
      echo "[include mmu/mmu_main.cfg]"
    } >> "$PRINTER_CFG"
  fi

  echo
  echo -e "${GRN}${FLUX_NAME} installation complete.${RST}"
  echo -e "${CYN}Calibrate with:${RST} MMU_CAL_PARK_TO_CUTTER_LANE LANE=1..${USER_MMU_LANES}"
  echo -e "${CYN}Configure slicer with ${USER_MMU_LANES} tools using T0–T$((USER_MMU_LANES-1)).${RST}"
  pause
}

# ------------- Main Menu -------------

main_menu() {
  while true; do
    header
    echo -e "${CYN}Main Menu:${RST}"
    echo -e "  ${MAG}1${RST}) Install ${FLUX_NAME}"
    echo -e "  ${MAG}2${RST}) Uninstall ${FLUX_NAME}"
    echo -e "  ${MAG}3${RST}) Backup System"
    echo -e "  ${MAG}4${RST}) Restore System"
    echo -e "  ${MAG}5${RST}) Show Current Configuration"
    echo -e "  ${MAG}6${RST}) Validate Configuration"
    echo -e "  ${MAG}7${RST}) Restart Klipper/Moonraker"
    echo -e "  ${MAG}8${RST}) Factory Reset ${FLUX_NAME}"
    echo -e "  ${MAG}9${RST}) Dry-Run Install"
    echo -e "  ${MAG}10${RST}) Generate Slicer Template"
    echo -e "  ${MAG}11${RST}) Deep Diagnostics"
    echo -e "  ${MAG}12${RST}) Quit"
    echo
    read -rp "Select an option: " choice

    case "$choice" in
      1) install_fluxpath "normal" ;;
      2) uninstall_mmu ;;
      3) backup_system ;;
      4) restore_system ;;
      5) show_current_config ;;
      6) validate_config ;;
      7) restart_services ;;
      8) factory_reset_mmu ;;
      9) install_fluxpath "dryrun" ;;
      10) generate_slicer_template ;;
      11) deep_diagnostics ;;
      12) echo -e "${GRN}Goodbye from ${FLUX_NAME}.${RST}"; exit 0 ;;
      *) echo -e "${RED}Invalid choice.${RST}"; pause ;;
    esac
  done
}

main_menu
