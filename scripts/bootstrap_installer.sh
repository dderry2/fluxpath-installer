#!/bin/bash
set -e

BASE_DIR="$HOME/FluxPath"
CONFIG_DIR="$BASE_DIR/config"
UI_DIR="$BASE_DIR/ui"
SCRIPTS_DIR="$BASE_DIR/scripts"
MAINSAIL_PANELS="$HOME/.local/share/mainsail/panels"
FLUIDD_PANELS="$HOME/.local/share/fluidd/panels"

mkdir -p "$CONFIG_DIR" "$UI_DIR" "$SCRIPTS_DIR" "$MAINSAIL_PANELS" "$FLUIDD_PANELS"

BANNER='  __ _  _  ___   _____  __ _____ _  _  
| __| || || \ \_/ / _,\/  \_   _| || | 
| _|| || \/ |> , <| v_/ /\ || | | >< | 
|_| |___\__//_/ \_\_| |_||_||_| |_||_| '

# ------------------------ install.sh ------------------------
cat << 'EOF' > "$BASE_DIR/install.sh"
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

mkdir -p "$CONFIG_DIR" "$UI_DIR" "$MAINSAIL_PANELS" "$FLUIDD_PANELS"

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
  if [ -f "$CONFIG_DIR/fluxpath_config.json" ]; then
    summary=$(cat "$CONFIG_DIR/fluxpath_config.json")
  else
    summary="No config found at:
$CONFIG_DIR/fluxpath_config.json"
  fi
  whiptail --title "FluxPath – MMU Config Summary" --msgbox "$summary" 25 100
}

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

main_menu() {
  show_banner
  check_environment

  while true; do
    choice=$(whiptail --title "FluxPath Installer" --menu "Choose an action:" 20 80 8 \
      "1" "Live System Status Dashboard" \
      "2" "MMU Config Summary" \
      "3" "UI Integration Manager (Mainsail/Fluidd)" \
      "4" "Backend Service Tools" \
      "5" "One-shot System Status Snapshot" \
      "6" "About FluxPath" \
      "0" "Exit Installer" 3>&1 1>&2 2>&3) || exit 0

    case "$choice" in
      1) show_system_status_live ;;
      2) show_config_summary ;;
      3) ui_integration_menu ;;
      4) backend_controls_menu ;;
      5) show_system_status_once ;;
      6) show_about ;;
      0) exit 0 ;;
    esac
  done
}

main_menu
EOF

# ------------------------ config_editor.sh ------------------------
cat << 'EOF' > "$SCRIPTS_DIR/config_editor.sh"
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
CONFIG_FILE="$CONFIG_DIR/fluxpath_config.json"

mkdir -p "$CONFIG_DIR"

show_banner() {
  whiptail --title "FluxPath Config Editor" --msgbox "$LOGO" 15 70
}

edit_config() {
  local drives colors note
  drives=$(whiptail --inputbox "Number of drive motors:" 10 60 "4" 3>&1 1>&2 2>&3) || return
  colors=$(whiptail --inputbox "Comma-separated color names (for slots):" 10 60 "Red,Green,Blue,Yellow" 3>&1 1>&2 2>&3) || return
  note=$(whiptail --inputbox "Optional description / notes:" 10 60 "" 3>&1 1>&2 2>&3) || note=""

  cat <<CFG > "$CONFIG_FILE"
{
  "drive_motors": $drives,
  "colors": "$colors",
  "notes": "$note"
}
CFG

  whiptail --title "Config Editor" --msgbox "Config saved to: $CONFIG_FILE" 10 60
}

view_config() {
  if [ -f "$CONFIG_FILE" ]; then
    content=$(cat "$CONFIG_FILE")
  else
    content="No config found at:
$CONFIG_FILE"
  fi
  whiptail --title "Current FluxPath Config" --msgbox "$content" 20 80
}

main_menu() {
  show_banner
  while true; do
    choice=$(whiptail --title "FluxPath Config Editor" --menu "Choose an action:" 20 70 5 \
      "1" "View current config" \
      "2" "Edit/create config" \
      "0" "Exit" 3>&1 1>&2 2>&3) || exit 0

    case "$choice" in
      1) view_config ;;
      2) edit_config ;;
      0) exit 0 ;;
    esac
  done
}

main_menu
EOF

# ------------------------ status_monitor.sh ------------------------
cat << 'EOF' > "$SCRIPTS_DIR/status_monitor.sh"
#!/bin/bash
set -e

LOGO=$(cat << 'BEOF'
  __ _  _  ___   _____  __ _____ _  _  
| __| || || \ \_/ / _,\/  \_   _| || | 
| _|| || \/ |> , <| v_/ /\ || | | >< | 
|_| |___\__//_/ \_\_| |_||_||_| |_||_| 
BEOF
)

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

show_status_loop() {
  while true; do
    backend_state=$(backend_service_state)
    backend_health=$(get_backend_health_raw)
    printer=$(get_printer_info_raw)
    mmu_status=$(get_mmu_status_raw)
    mmu_sensors=$(get_mmu_sensors_raw)
    mmu_motors=$(get_mmu_motors_raw)
    webcam=$(get_webcam_status_raw)

    clear
    echo "$LOGO"
    echo
    echo "FluxPath Status Monitor"
    echo "------------------------"
    echo "$(fmt_status 'Backend service' "$backend_state")"
    echo "$(fmt_status 'Backend health' "$backend_health")"
    echo
    echo "$(fmt_status 'Printer API' "$printer")"
    echo
    echo "$(fmt_status 'MMU status' "$mmu_status")"
    echo "$(fmt_status 'MMU sensors' "$mmu_sensors")"
    echo "$(fmt_status 'MMU motors' "$mmu_motors")"
    echo
    echo "$(fmt_webcam "$webcam")"
    echo
    echo "Press Ctrl+C to exit."
    sleep 3
  done
}

show_status_loop
EOF

# ------------------------ hardware_test.sh (placeholder) ------------------------
cat << 'EOF' > "$SCRIPTS_DIR/hardware_test.sh"
#!/bin/bash
set -e

LOGO=$(cat << 'BEOF'
  __ _  _  ___   _____  __ _____ _  _  
| __| || || \ \_/ / _,\/  \_   _| || | 
| _|| || \/ |> , <| v_/ /\ || | | >< | 
|_| |___\__//_/ \_\_| |_||_||_| |_||_| 
BEOF
)

whiptail --title "FluxPath Hardware Tools" --msgbox "$LOGO

Hardware tools are not implemented yet.

This script is reserved for:
- MMU homing
- Self-tests
- Sensor checks
- Slot calibration

For now, all behavior is read-only and defined in other tools." 20 80
EOF

# ------------------------ printer_tools.sh (future placeholder) ------------------------
cat << 'EOF' > "$SCRIPTS_DIR/printer_tools.sh"
#!/bin/bash
set -e

LOGO=$(cat << 'BEOF'
  __ _  _  ___   _____  __ _____ _  _  
| __| || || \ \_/ / _,\/  \_   _| || | 
| _|| || \/ |> , <| v_/ /\ || | | >< | 
|_| |___\__//_/ \_\_| |_||_||_| |_||_| 
BEOF
)

whiptail --title "FluxPath Printer Tools" --msgbox "$LOGO

Printer tools will be added later.

This menu is reserved for:
- Printer-side MMU actions
- Klipper macro integration
- Advanced diagnostics." 20 80
EOF

chmod +x "$BASE_DIR/install.sh"
chmod +x "$SCRIPTS_DIR/"*.sh

echo "FluxPath bootstrap complete."
echo "Main installer: $BASE_DIR/install.sh"
echo "Other tools:    $SCRIPTS_DIR"
