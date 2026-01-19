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
      "0" "Exit" 3>&1 1>&2 2>&3) || exit 0

    case "$choice" in
      1) view_config ;;
      0) exit 0 ;;
    esac
  done
}

main_menu
