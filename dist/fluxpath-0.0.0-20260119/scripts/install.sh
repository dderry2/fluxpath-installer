#!/bin/bash
set -e

# ------------------------ FluxPath Banner ------------------------
LOGO=$(cat << 'BEOF'
  __ _  _  ___   _____  __ _____ _  _  
| __| || || \ \_/ / _,\/  \_   _| || | 
| _|| || \/ |> , <| v_/ /\ || | | >< | 
|_| |___\__//_/ \_\_| |_||_||_| |_||_| 
BEOF
)

# ------------------------ Paths ------------------------
BASE_DIR="$HOME/FluxPath"
CONFIG_DIR="$BASE_DIR/config"
UI_DIR="$BASE_DIR/ui"
MAINSAIL_PANELS="$HOME/.local/share/mainsail/panels"
FLUIDD_PANELS="$HOME/.local/share/fluidd/panels"
CONFIG_FILE="$CONFIG_DIR/fluxpath_config.json"

mkdir -p "$CONFIG_DIR" "$UI_DIR" "$MAINSAIL_PANELS" "$FLUIDD_PANELS"

# ------------------------ Dependency checks ------------------------
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
"
  whiptail --title "FluxPath – Environment Check" --msgbox "$msg" 20 80
}

# ------------------------ Backend / API helpers ------------------------
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

# ------------------------ Friendly wrappers ------------------------
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

# ------------------------ UI panels ------------------------
ensure_ui_panels() {
  cat <<PEOF > "$UI_DIR/mainsail_mmu_panel.json"
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

# ------------------------ Banner & About ------------------------
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

(Printer tools will be added later.)
"
  whiptail --title "About FluxPath" --msgbox "$msg" 25 90
}

# ------------------------ Status Screens ------------------------
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

# ------------------------ MMU Configuration Wizard ------------------------
mmu_config_wizard() {
  mkdir -p "$CONFIG_DIR"

  # Defaults
  local default_motors=4
  local default_colors="Red,Green,Blue,Yellow"
  local default_feed_distance="120.0"
  local default_retract_distance="80.0"
  local default_cutter_present="ON"
  local default_cutter_pin="PA0"

  # Motor count
  local motor_choice
  motor_choice=$(whiptail --title "FluxPath – MMU Config" --radiolist "Number of drive motors:" 15 60 3 \
    "2" "Two-slot MMU" OFF \
    "3" "Three-slot MMU" OFF \
    "4" "Four-slot MMU (default)" ON 3>&1 1>&2 2>&3) || return
  local motor_count="$motor_choice"

  # Colors
  local colors
  colors=$(whiptail --inputbox "Comma-separated color names (for slots):" 10 70 "$default_colors" 3>&1 1>&2 2>&3) || return

  # Cutter present
  local cutter_present
  if whiptail --title "FluxPath – Cutter" --yesno "Is a cutter installed?" 10 60; then
    cutter_present="true"
  else
    cutter_present="false"
  fi

  # Cutter pin (only if present)
  local cutter_pin="$default_cutter_pin"
  if [ "$cutter_present" = "true" ]; then
    cutter_pin=$(whiptail --inputbox "Cutter pin (MCU pin name):" 10 60 "$default_cutter_pin" 3>&1 1>&2 2>&3) || return
  fi

  # Distances
  local feed_distance retract_distance
  feed_distance=$(whiptail --inputbox "Feed distance (mm):" 10 60 "$default_feed_distance" 3>&1 1>&2 2>&3) || return
  retract_distance=$(whiptail --inputbox "Retract distance (mm):" 10 60 "$default_retract_distance" 3>&1 1>&2 2>&3) || return

  # Per-motor pins and sensors
  local motor_pins=()
  local sensor_pins=()

  for ((i=1; i<=motor_count; i++)); do
    local mp sp
    mp=$(whiptail --inputbox "Motor $i pin (MCU pin name):" 10 60 "" 3>&1 1>&2 2>&3) || return
    sp=$(whiptail --inputbox "Sensor $i pin (MCU pin name):" 10 60 "" 3>&1 1>&2 2>&3) || return
    motor_pins+=("$mp")
    sensor_pins+=("$sp")
  done

  # Build JSON arrays
  local motor_pins_json="["
  local sensor_pins_json="["
  for ((i=0; i<${#motor_pins[@]}; i++)); do
    motor_pins_json+="\"${motor_pins[$i]}\""
    sensor_pins_json+="\"${sensor_pins[$i]}\""
    if [ $i -lt $(( ${#motor_pins[@]} - 1 )) ]; then
      motor_pins_json+=", "
      sensor_pins_json+=", "
    fi
  done
  motor_pins_json+="]"
  sensor_pins_json+="]"

  cat <<CFG > "$CONFIG_FILE"
{
  "config_version": 1,
  "drive_motors": $motor_count,
  "motor_pins": $motor_pins_json,
  "sensor_pins": $sensor_pins_json,
  "colors": "$colors",
  "cutter_present": $cutter_present,
  "cutter_pin": "$cutter_pin",
  "feed_distance_mm": $feed_distance,
  "retract_distance_mm": $retract_distance
}
CFG

  whiptail --title "FluxPath – MMU Config" --msgbox "Configuration saved to:

$CONFIG_FILE" 12 70
}

# ------------------------ UI Integration ------------------------
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

# ------------------------ Backend Controls ------------------------
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
      start)
        sudo systemctl start fluxpath.service || true
        ;;
      stop)
        sudo systemctl stop fluxpath.service || true
        ;;
      restart)
        sudo systemctl restart fluxpath.service || true
        ;;
      status)
        status_out=$(systemctl status fluxpath.service 2>&1 | sed 's/\\/\\\\/g')
        whiptail --title "fluxpath.service status" --msgbox "$status_out" 25 100
        ;;
      back)
        break
        ;;
    esac
  done
}

# ------------------------ Main Menu ------------------------
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
