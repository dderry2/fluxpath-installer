#!/bin/bash
set -e

LOGO=$(cat << 'BEOF'
  __ _  _  ___   _____  __ _____ _  _  
| __| || || \ \_/ / _,\/  \_   _| || | 
| _|| || \/ |> , <| v_/ /\ || | | >< | 
|_| |___\__//_/ \_\_| |_||_||_| |_||_| 
BEOF
)

BASE_DIR="$HOME/FluxPath"
CONFIG_DIR="$BASE_DIR/config"
UI_DIR="$BASE_DIR/ui"
MAINSAIL_PANELS="$HOME/.local/share/mainsail/panels"
FLUIDD_PANELS="$HOME/.local/share/fluidd/panels"
CONFIG_FILE="$CONFIG_DIR/fluxpath_config.json"

MMU_CFG_DIR="/fluxpath_mmu"
MMU_PINS_CFG="$MMU_CFG_DIR/mmu_pins.cfg"

mkdir -p "$CONFIG_DIR" "$UI_DIR" "$MAINSAIL_PANELS" "$FLUIDD_PANELS"

# ---------- Defaults (fallbacks if mmu_pins.cfg missing) ----------
DEFAULT_MOTORS=4
DEFAULT_COLORS="Red,Green,Blue,Yellow"
DEFAULT_FEED_DISTANCE="120.0"
DEFAULT_RETRACT_DISTANCE="80.0"
DEFAULT_CUTTER_PRESENT="true"
DEFAULT_CUTTER_PIN="PA0"

DEFAULT_MOTOR_PINS=()
DEFAULT_SENSOR_PINS=()

W_MOTOR_COUNT="$DEFAULT_MOTORS"
W_MOTOR_PINS=()
W_SENSOR_PINS=()
W_COLORS="$DEFAULT_COLORS"
W_CUTTER_PRESENT="$DEFAULT_CUTTER_PRESENT"
W_CUTTER_PIN="$DEFAULT_CUTTER_PIN"
W_FEED_DISTANCE="$DEFAULT_FEED_DISTANCE"
W_RETRACT_DISTANCE="$DEFAULT_RETRACT_DISTANCE"

# ---------- Load defaults from existing Klipper MMU config ----------
load_defaults_from_klipper() {
  if [ ! -f "$MMU_PINS_CFG" ]; then
    return
  fi

  # Try to infer motor pins: lines like "mmu_motor_1_pin: PA0"
  mapfile -t DEFAULT_MOTOR_PINS < <(grep -Ei 'mmu_motor_[0-9]+_pin' "$MMU_PINS_CFG" | awk -F'[: ]+' '{print $NF}' | sed 's/#.*//g' | sed 's/^[ \t]*//;s/[ \t]*$//')

  # Try to infer sensor pins: lines like "mmu_sensor_1_pin: PB0"
  mapfile -t DEFAULT_SENSOR_PINS < <(grep -Ei 'mmu_sensor_[0-9]+_pin' "$MMU_PINS_CFG" | awk -F'[: ]+' '{print $NF}' | sed 's/#.*//g' | sed 's/^[ \t]*//;s/[ \t]*$//')

  # Try to infer cutter pin: line like "mmu_cutter_pin: PC0"
  local cutter_line
  cutter_line=$(grep -Ei 'mmu_cutter_pin' "$MMU_PINS_CFG" | head -n1 || true)
  if [ -n "$cutter_line" ]; then
    local cp
    cp=$(echo "$cutter_line" | awk -F'[: ]+' '{print $NF}' | sed 's/#.*//g' | sed 's/^[ \t]*//;s/[ \t]*$//')
    [ -n "$cp" ] && DEFAULT_CUTTER_PIN="$cp"
  fi

  # Motor count from number of motor pins found
  if [ "${#DEFAULT_MOTOR_PINS[@]}" -gt 0 ]; then
    DEFAULT_MOTORS="${#DEFAULT_MOTOR_PINS[@]}"
  fi

  # Initialize working values from defaults
  W_MOTOR_COUNT="$DEFAULT_MOTORS"
  W_MOTOR_PINS=("${DEFAULT_MOTOR_PINS[@]}")
  W_SENSOR_PINS=("${DEFAULT_SENSOR_PINS[@]}")
  W_CUTTER_PIN="$DEFAULT_CUTTER_PIN"
}

# ---------- Dependency checks ----------
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing"
  else
    echo "ok"
  fi
}

check_environment() {
  local msg="Environment Check
-----------------
whiptail:  $(need_cmd whiptail)
curl:      $(need_cmd curl)
systemctl: $(need_cmd systemctl)

Base dir:  $BASE_DIR
Config:    $CONFIG_DIR
UI dir:    $UI_DIR
Mainsail:  $MAINSAIL_PANELS
Fluidd:    $FLUIDD_PANELS

MMU cfg dir: $MMU_CFG_DIR
mmu_pins:    $MMU_PINS_CFG
"
  whiptail --title "FluxPath – Environment Check" --msgbox "$msg" 20 80
}

# ---------- Backend / API helpers ----------
get_backend_health_raw() { curl -s http://localhost:9876/health 2>/dev/null || echo "unreachable"; }
get_printer_info_raw()  { curl -s http://localhost:7125/printer/info 2>/dev/null || echo "unreachable"; }
get_mmu_status_raw()    { curl -s http://localhost:9876/mmu/status 2>/dev/null || echo "unreachable"; }
get_mmu_sensors_raw()   { curl -s http://localhost:9876/sensors 2>/dev/null || echo "unreachable"; }
get_mmu_motors_raw()    { curl -s http://localhost:9876/motors 2>/dev/null || echo "unreachable"; }
get_webcam_status_raw() { curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/?action=snapshot" 2>/dev/null || echo "unreachable"; }

backend_service_state() {
  if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet fluxpath.service; then
    echo "active"
  else
    echo "inactive"
  fi
}

fmt_status() {
  local label="$1"
  local raw="$2"
  if [[ "$raw" == "unreachable" ]]; then
    echo "✖ $label: unreachable"
  elif echo "$raw" | grep -q '"detail":"Not Found"'; then
    echo "⚠ $label: endpoint not found"
  else
    echo "✔ $label: $raw"
  fi
}

fmt_webcam() {
  local code="$1"
  if [[ "$code" == "unreachable" ]]; then
    echo "✖ Webcam: unreachable"
  elif [[ "$code" =~ ^[0-9]+$ ]] && [ "$code" -ge 200 ] && [ "$code" -lt 400 ]; then
    echo "✔ Webcam HTTP: $code"
  else
    echo "⚠ Webcam HTTP: $code"
  fi
}

# ---------- UI panels ----------
ensure_ui_panels() {
  cat << 'PEOF' > "$UI_DIR/mainsail_mmu_panel.json"
{
  "name": "FluxPath MMU",
  "type": "custom",
  "content": {
    "title": "FluxPath MMU Status",
    "widgets": [
      { "type": "webcam", "source": "/webcam/stream" },
      { "type": "status", "source": "/mmu/status" },
      { "type": "colors", "source": "/mmu/colors" },
      { "type": "sensors", "source": "/mmu/sensors" }
    ]
  }
}
PEOF
  cp "$UI_DIR/mainsail_mmu_panel.json" "$UI_DIR/fluidd_mmu_panel.json"
}

ui_panels_status() {
  local m="✖ Mainsail panel: not installed"
  local f="✖ Fluidd panel:   not installed"
  [ -f "$MAINSAIL_PANELS/mainsail_mmu_panel.json" ] && m="✔ Mainsail panel: installed"
  [ -f "$FLUIDD_PANELS/fluidd_mmu_panel.json" ] && f="✔ Fluidd panel:   installed"
  echo "$m
$f"
}

# ---------- Banner & About ----------
show_banner() {
  whiptail --title "FluxPath Installer" --msgbox "$LOGO" 15 70
}

show_about() {
  local panels
  panels=$(ui_panels_status)
  local msg="
FluxPath Installer
------------------
A smart, branded MMU control platform.

Paths:
  Base:    $BASE_DIR
  Config:  $CONFIG_DIR
  UI dir:  $UI_DIR

Panels:
$panels

Backend:
  Service: $(backend_service_state)
  Health:  $(get_backend_health_raw)

MMU config source:
  $MMU_PINS_CFG
"
  whiptail --title "About FluxPath" --msgbox "$msg" 25 90
}

# ---------- Status screens ----------
show_system_status_once() {
  local backend_state backend_health printer mmu_status mmu_sensors mmu_motors webcam panels

  backend_state=$(backend_service_state)
  backend_health=$(get_backend_health_raw)
  printer=$(get_printer_info_raw)
  mmu_status=$(get_mmu_status_raw)
  mmu_sensors=$(get_mmu_sensors_raw)
  mmu_motors=$(get_mmu_motors_raw)
  webcam=$(get_webcam_status_raw)
  panels=$(ui_panels_status)

  local msg="
FluxPath System Snapshot
------------------------
$(fmt_status 'Backend service' "$backend_state")
$(fmt_status 'Backend health' "$backend_health")

$(fmt_status 'Printer API' "$printer")

$(fmt_status 'MMU status' "$mmu_status")
$(fmt_status 'MMU sensors' "$mmu_sensors")
$(fmt_status 'MMU motors' "$mmu_motors")

$(fmt_webcam "$webcam")

UI Panels:
$panels
"
  whiptail --title "FluxPath – System Status" --msgbox "$msg" 25 100
}

show_system_status_live() {
  while true; do
    backend_state=$(backend_service_state)
    backend_health=$(get_backend_health_raw)
    printer=$(get_printer_info_raw)
    mmu_status=$(get_mmu_status_raw)
    mmu_sensors=$(get_mmu_sensors_raw)
    mmu_motors=$(get_mmu_motors_raw)
    webcam=$(get_webcam_status_raw)
    panels=$(ui_panels_status)

    msg="
FluxPath Live Status (auto-refresh)
-----------------------------------
$(fmt_status 'Backend service' "$backend_state")
$(fmt_status 'Backend health' "$backend_health")

$(fmt_status 'Printer API' "$printer")

$(fmt_status 'MMU status' "$mmu_status")
$(fmt_status 'MMU sensors' "$mmu_sensors")
$(fmt_status 'MMU motors' "$mmu_motors")

$(fmt_webcam "$webcam")

UI Panels:
$panels

Press <Yes> to refresh, <No> to return.
"
    if ! whiptail --title "FluxPath – Live Status" --yesno "$msg" 25 100; then
      break
    fi
  done
}

show_config_summary() {
  if [ -f "$CONFIG_FILE" ]; then
    summary=$(cat "$CONFIG_FILE")
  else
    summary="No config found at:
$CONFIG_FILE"
  fi
  whiptail --title "FluxPath – MMU Config Summary" --msgbox "$summary" 25 100
}

# ============================================================
# Advanced MMU Configuration Wizard
# ============================================================

build_json_array() {
  local -n arr_ref=$1
  local out="["
  local i
  for ((i=0; i<${#arr_ref[@]}; i++)); do
    out+="\"${arr_ref[$i]}\""
    if [ $i -lt $(( ${#arr_ref[@]} - 1 )) ]; then
      out+=", "
    fi
  done
  out+="]"
  echo "$out"
}

step_motor_count() {
  local choice
  choice=$(whiptail --title "FluxPath – MMU Config (1/6)" \
    --radiolist "Number of drive motors:" 15 60 3 \
    "2" "Two-slot MMU" $([ "$W_MOTOR_COUNT" = "2" ] && echo ON || echo OFF) \
    "3" "Three-slot MMU" $([ "$W_MOTOR_COUNT" = "3" ] && echo ON || echo OFF) \
    "4" "Four-slot MMU (default)" $([ "$W_MOTOR_COUNT" = "4" ] && echo ON || echo OFF) \
    3>&1 1>&2 2>&3)
  local status=$?
  if [ $status -ne 0 ]; then
    echo "cancel"; return
  fi
  W_MOTOR_COUNT="$choice"
  echo "next"
}

step_motor_pins() {
  local new_motor_pins=()
  local i
  for ((i=1; i<=W_MOTOR_COUNT; i++)); do
    local default_val=""
    if [ ${#W_MOTOR_PINS[@]} -ge $i ]; then
      default_val="${W_MOTOR_PINS[$((i-1))]}"
    fi
    local mp
    mp=$(whiptail --title "FluxPath – MMU Config (2/6)" \
      --inputbox "Motor $i pin (MCU pin name):" 10 60 "$default_val" \
      3>&1 1>&2 2>&3)
    local status=$?
    if [ $status -ne 0 ]; then
      echo "cancel"; return
    fi
    new_motor_pins+=("$mp")
  done
  W_MOTOR_PINS=("${new_motor_pins[@]}")
  echo "next"
}

step_sensor_pins() {
  local new_sensor_pins=()
  local i
  for ((i=1; i<=W_MOTOR_COUNT; i++)); do
    local default_val=""
    if [ ${#W_SENSOR_PINS[@]} -ge $i ]; then
      default_val="${W_SENSOR_PINS[$((i-1))]}"
    fi
    local sp
    sp=$(whiptail --title "FluxPath – MMU Config (3/6)" \
      --inputbox "Sensor $i pin (MCU pin name):" 10 60 "$default_val" \
      3>&1 1>&2 2>&3)
    local status=$?
    if [ $status -ne 0 ]; then
      echo "cancel"; return
    fi
    new_sensor_pins+=("$sp")
  done
  W_SENSOR_PINS=("${new_sensor_pins[@]}")
  echo "next"
}

step_cutter() {
  local cutter_choice
  whiptail --title "FluxPath – MMU Config (4/6)" --yesno "Is a cutter installed?" 10 60
  local status=$?
  if [ $status -eq 0 ]; then
    cutter_choice="true"
  else
    cutter_choice="false"
  fi
  W_CUTTER_PRESENT="$cutter_choice"

  if [ "$W_CUTTER_PRESENT" = "true" ]; then
    local cp
    cp=$(whiptail --title "FluxPath – MMU Config (4/6)" \
      --inputbox "Cutter pin (MCU pin name):" 10 60 "$W_CUTTER_PIN" \
      3>&1 1>&2 2>&3)
    status=$?
    if [ $status -ne 0 ]; then
      echo "cancel"; return
    fi
    W_CUTTER_PIN="$cp"
  fi

  echo "next"
}

step_distances() {
  local fd rd
  fd=$(whiptail --title "FluxPath – MMU Config (5/6)" \
    --inputbox "Feed distance (mm):" 10 60 "$W_FEED_DISTANCE" \
    3>&1 1>&2 2>&3)
  local status=$?
  if [ $status -ne 0 ]; then
    echo "cancel"; return
  fi
  rd=$(whiptail --title "FluxPath – MMU Config (5/6)" \
    --inputbox "Retract distance (mm):" 10 60 "$W_RETRACT_DISTANCE" \
    3>&1 1>&2 2>&3)
  status=$?
  if [ $status -ne 0 ]; then
    echo "cancel"; return
  fi
  W_FEED_DISTANCE="$fd"
  W_RETRACT_DISTANCE="$rd"
  echo "next"
}

step_colors() {
  local colors
  colors=$(whiptail --title "FluxPath – MMU Config (6/6)" \
    --inputbox "Comma-separated color names (for slots):" 10 70 "$W_COLORS" \
    3>&1 1>&2 2>&3)
  local status=$?
  if [ $status -ne 0 ]; then
    echo "cancel"; return
  fi
  W_COLORS="$colors"
  echo "next"
}

step_review() {
  local cutter_text="No"
  [ "$W_CUTTER_PRESENT" = "true" ] && cutter_text="Yes"

  local review="
FluxPath Configuration Review
-----------------------------

Drive motors: $W_MOTOR_COUNT

Motor pins:
"
  local i
  for ((i=0; i<${#W_MOTOR_PINS[@]}; i++)); do
    review+="  $((i+1)): ${W_MOTOR_PINS[$i]}
"
  done

  review+="
Sensor pins:
"
  for ((i=0; i<${#W_SENSOR_PINS[@]}; i++)); do
    review+="  $((i+1)): ${W_SENSOR_PINS[$i]}
"
  done

  review+="
Cutter installed: $cutter_text
Cutter pin: $W_CUTTER_PIN

Feed distance:    $W_FEED_DISTANCE mm
Retract distance: $W_RETRACT_DISTANCE mm

Slot colors:
  $W_COLORS
"

  local choice
  choice=$(whiptail --title "FluxPath – Review Configuration" --menu "$review

What would you like to do?" 25 80 4 \
    "confirm" "Confirm and save configuration" \
    "edit"    "Edit specific section" \
    "restart" "Start wizard over" \
    "cancel"  "Cancel without saving" \
    3>&1 1>&2 2>&3)
  local status=$?
  if [ $status -ne 0 ]; then
    echo "cancel"; return
  fi

  case "$choice" in
    confirm)
      local motor_pins_json sensor_pins_json
      motor_pins_json=$(build_json_array W_MOTOR_PINS)
      sensor_pins_json=$(build_json_array W_SENSOR_PINS)
      mkdir -p "$CONFIG_DIR"
      cat <<CFG > "$CONFIG_FILE"
{
  "config_version": 1,
  "drive_motors": $W_MOTOR_COUNT,
  "motor_pins": $motor_pins_json,
  "sensor_pins": $sensor_pins_json,
  "colors": "$W_COLORS",
  "cutter_present": $W_CUTTER_PRESENT,
  "cutter_pin": "$W_CUTTER_PIN",
  "feed_distance_mm": $W_FEED_DISTANCE,
  "retract_distance_mm": $W_RETRACT_DISTANCE
}
CFG
      whiptail --title "FluxPath – MMU Config" --msgbox "Configuration saved to:

$CONFIG_FILE" 12 70
      echo "done"
      ;;
    edit)    echo "edit" ;;
    restart) echo "restart" ;;
    cancel)  echo "cancel" ;;
  esac
}

step_edit_menu() {
  local choice
  choice=$(whiptail --title "FluxPath – Edit Configuration" --menu "Select section to edit:" 20 70 8 \
    "motors"   "Motor count" \
    "mpins"    "Motor pins" \
    "spins"    "Sensor pins" \
    "cutter"   "Cutter settings" \
    "dist"     "Distances" \
    "colors"   "Colors" \
    "restart"  "Restart entire wizard" \
    "cancel"   "Cancel editing and return to review" \
    3>&1 1>&2 2>&3)
  local status=$?
  if [ $status -ne 0 ]; then
    echo "review"; return
  fi
  case "$choice" in
    motors)  echo "motors" ;;
    mpins)   echo "mpins" ;;
    spins)   echo "spins" ;;
    cutter)  echo "cutter" ;;
    dist)    echo "dist" ;;
    colors)  echo "colors" ;;
    restart) echo "restart" ;;
    cancel)  echo "review" ;;
  esac
}

mmu_config_wizard() {
  mkdir -p "$CONFIG_DIR"

  # Load defaults from Klipper MMU config if present
  load_defaults_from_klipper

  W_MOTOR_COUNT=${W_MOTOR_COUNT:-$DEFAULT_MOTORS}
  W_COLORS=${W_COLORS:-$DEFAULT_COLORS}
  W_FEED_DISTANCE=${W_FEED_DISTANCE:-$DEFAULT_FEED_DISTANCE}
  W_RETRACT_DISTANCE=${W_RETRACT_DISTANCE:-$DEFAULT_RETRACT_DISTANCE}
  W_CUTTER_PRESENT=${W_CUTTER_PRESENT:-$DEFAULT_CUTTER_PRESENT}
  W_CUTTER_PIN=${W_CUTTER_PIN:-$DEFAULT_CUTTER_PIN}

  local step="motors"
  while true; do
    case "$step" in
      motors)
        res=$(step_motor_count)
        case "$res" in
          next) step="mpins" ;;
          cancel) return ;;
        esac
        ;;
      mpins)
        res=$(step_motor_pins)
        case "$res" in
          next) step="spins" ;;
          cancel) step="motors" ;;
        esac
        ;;
      spins)
        res=$(step_sensor_pins)
        case "$res" in
          next) step="cutter" ;;
          cancel) step="mpins" ;;
        esac
        ;;
      cutter)
        res=$(step_cutter)
        case "$res" in
          next) step="dist" ;;
          cancel) step="spins" ;;
        esac
        ;;
      dist)
        res=$(step_distances)
        case "$res" in
          next) step="colors" ;;
          cancel) step="cutter" ;;
        esac
        ;;
      colors)
        res=$(step_colors)
        case "$res" in
          next) step="review" ;;
          cancel) step="dist" ;;
        esac
        ;;
      review)
        res=$(step_review)
        case "$res" in
          done) return ;;
          edit) step="edit" ;;
          restart) step="motors" ;;
          cancel) return ;;
        esac
        ;;
      edit)
        res=$(step_edit_menu)
        case "$res" in
          motors) step="motors" ;;
          mpins)  step="mpins" ;;
          spins)  step="spins" ;;
          cutter) step="cutter" ;;
          dist)   step="dist" ;;
          colors) step="colors" ;;
          restart) step="motors" ;;
          review) step="review" ;;
        esac
        ;;
    esac
  done
}

# ---------- UI Integration ----------
ui_integration_menu() {
  ensure_ui_panels
  choice=$(whiptail --title "FluxPath – UI Integration" --radiolist "Choose UI integration:" 20 70 3 \
    "mainsail" "Install Mainsail panel" ON \
    "fluidd"   "Install Fluidd panel"   OFF \
    "both"     "Install both panels"    OFF 3>&1 1>&2 2>&3) || return
  case "$choice" in
    mainsail)
      cp "$UI_DIR/mainsail_mmu_panel.json" "$MAINSAIL_PANELS/"
      whiptail --title "UI Integration" --msgbox "Installed Mainsail panel." 10 60
      ;;
    fluidd)
      cp "$UI_DIR/fluidd_mmu_panel.json" "$FLUIDD_PANELS/"
      whiptail --title "UI Integration" --msgbox "Installed Fluidd panel." 10 60
      ;;
    both)
      cp "$UI_DIR/mainsail_mmu_panel.json" "$MAINSAIL_PANELS/"
      cp "$UI_DIR/fluidd_mmu_panel.json" "$FLUIDD_PANELS/"
      whiptail --title "UI Integration" --msgbox "Installed both Mainsail and Fluidd panels." 10 60
      ;;
  esac
}

# ---------- Backend Controls ----------
backend_controls_menu() {
  if ! command -v systemctl >/dev/null 2>&1; then
    whiptail --title "Backend Controls" --msgbox "systemctl not available on this system." 10 60
    return
  fi
  while true; do
    state=$(backend_service_state)
    choice=$(whiptail --title "FluxPath – Backend Controls" --menu "fluxpath.service is currently: $state" 20 70 6 \
      "start"   "Start backend service" \
      "stop"    "Stop backend service" \
      "restart" "Restart backend service" \
      "status"  "Show systemctl status" \
      "back"    "Return to main menu" 3>&1 1>&2 2>&3) || break
    case "$choice" in
      start)   sudo systemctl start fluxpath.service || true ;;
      stop)    sudo systemctl stop fluxpath.service || true ;;
      restart) sudo systemctl restart fluxpath.service || true ;;
      status)
        status_out=$(systemctl status fluxpath.service 2>&1 | sed 's/\\/\\\\/g')
        whiptail --title "fluxpath.service status" --msgbox "$status_out" 25 100
        ;;
      back) break ;;
    esac
  done
}

# ---------- Main Menu ----------
main_menu() {
  show_banner
  check_environment
  while true; do
    choice=$(whiptail --title "FluxPath Installer" --menu "Choose an action:" 20 80 9 \
      "1" "Live System Status Dashboard" \
      "2" "MMU Config Summary" \
      "3" "MMU Configuration Wizard" \
      "4" "UI Integration Manager (Mainsail/Fluidd)" \
      "5" "Backend Service Tools" \
      "6" "One-shot System Status Snapshot" \
      "7" "About FluxPath" \
      "0" "Exit Installer" 3>&1 1>&2 2>&3) || exit 0
    case "$choice" in
      1) show_system_status_live ;;
      2) show_config_summary ;;
      3) mmu_config_wizard ;;
      4) ui_integration_menu ;;
      5) backend_controls_menu ;;
      6) show_system_status_once ;;
      7) show_about ;;
      0) exit 0 ;;
    esac
  done
}

main_menu
