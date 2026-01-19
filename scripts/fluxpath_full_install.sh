#!/bin/bash
set -e

echo "=== FluxPath Full Installer ==="

BASE_DIR="$HOME/FluxPath"
CONFIG_DIR="$BASE_DIR/config"
CONFIG_FILE="$CONFIG_DIR/fluxpath_config.json"

mkdir -p "$CONFIG_DIR"

# Load defaults if config exists
if [ -f "$CONFIG_FILE" ]; then
  echo "→ Loading existing config defaults..."
  DEFAULTS=$(cat "$CONFIG_FILE")
else
  DEFAULTS="{}"
fi

# Helper to extract default values
get_default() {
  echo "$DEFAULTS" | jq -r "$1" 2>/dev/null || echo ""
}

# === Git conflict handling ===
cd "$BASE_DIR" 2>/dev/null || true

if [ -d "$BASE_DIR/.git" ]; then
  echo "→ Checking for local Git changes..."
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo ""
    echo "⚠ You have uncommitted changes."
    echo "Choose how to proceed:"
    echo "  1) Commit changes"
    echo "  2) Stash changes"
    echo "  3) Discard changes"
    echo ""
    read -p "Enter choice [1/2/3]: " choice

    case "$choice" in
      1)
        git add -A
        git commit -m "Auto-commit before installer update"
        ;;
      2)
        git stash push -m "FluxPath installer auto-stash"
        ;;
      3)
        git reset --hard HEAD
        ;;
      *)
        echo "Invalid choice."
        exit 1
        ;;
    esac
  fi

  # === Upstream auto-fix ===
  echo "→ Checking Git upstream tracking..."

  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  UPSTREAM=$(git rev-parse --abbrev-ref "$CURRENT_BRANCH"@{upstream} 2>/dev/null || true)

  if [ -z "$UPSTREAM" ]; then
    echo "⚠ No upstream branch is set for '$CURRENT_BRANCH'."
    echo "Choose how to fix it:"
    echo "  1) Set upstream to origin/main"
    echo "  2) Set upstream to origin/master"
    echo "  3) Enter a custom remote/branch"
    echo ""

    read -p "Enter choice [1/2/3]: " upstream_choice

    case "$upstream_choice" in
      1)
        git branch --set-upstream-to=origin/main "$CURRENT_BRANCH"
        ;;
      2)
        git branch --set-upstream-to=origin/master "$CURRENT_BRANCH"
        ;;
      3)
        read -p "Enter remote name (default: origin): " REMOTE
        read -p "Enter branch name: " BRANCH
        REMOTE=${REMOTE:-origin}
        git branch --set-upstream-to="$REMOTE/$BRANCH" "$CURRENT_BRANCH"
        ;;
      *)
        echo "Invalid choice. Aborting."
        exit 1
        ;;
    esac
  fi

  echo "→ Pulling latest changes..."
  git pull --rebase
else
  echo "→ No Git repo found. Initializing..."
  mkdir -p "$BASE_DIR"
  cp -r . "$BASE_DIR"
  cd "$BASE_DIR"
  git init
  git remote add origin https://github.com/dderry2/fluxpath-installer
  git branch -M main
fi

# === Prompt for MCU settings ===
echo ""
echo "=== MCU Configuration ==="

read -p "MCU type [$(get_default '.mcu.type')]: " MCU_TYPE
read -p "MCU serial port [$(get_default '.mcu.serial_port')]: " MCU_PORT
read -p "MCU baud rate [$(get_default '.mcu.baud_rate')]: " MCU_BAUD
read -p "MCU pin scheme [$(get_default '.mcu.pin_scheme')]: " MCU_PINS
read -p "MCU frequency MHz [$(get_default '.mcu.frequency_mhz')]: " MCU_FREQ
read -p "Stepper driver type [$(get_default '.mcu.driver.type')]: " DRIVER_TYPE
read -p "Driver UART pin [$(get_default '.mcu.driver.uart_pin')]: " DRIVER_UART
read -p "Reset on connect (yes/no) [$(get_default '.mcu.reset_on_connect')]: " MCU_RESET
read -p "Firmware version [$(get_default '.mcu.firmware_version')]: " MCU_FW

# === Prompt for MMU settings ===
echo ""
echo "=== MMU Configuration ==="

read -p "Number of slots [$(get_default '.mmu.slots')]: " MMU_SLOTS
read -p "Stepper STEP pin [$(get_default '.mmu.pins.stepper.step')]: " STEP_PIN
read -p "Stepper DIR pin [$(get_default '.mmu.pins.stepper.dir')]: " DIR_PIN
read -p "Stepper ENABLE pin [$(get_default '.mmu.pins.stepper.enable')]: " ENABLE_PIN

read -p "Filament sensor pin [$(get_default '.mmu.pins.sensors.filament')]: " SENSOR_PIN
read -p "Selector home pin [$(get_default '.mmu.pins.sensors.selector_home')]: " HOME_PIN

read -p "Enable cutter (yes/no) [$(get_default '.mmu.pins.cutter.enabled')]: " CUTTER_ENABLED
if [ "$CUTTER_ENABLED" == "yes" ]; then
  read -p "Cutter pin [$(get_default '.mmu.pins.cutter.pin')]: " CUTTER_PIN
fi

read -p "Selector type (servo/stepper) [$(get_default '.mmu.pins.selector.type')]: " SELECTOR_TYPE

if [ "$SELECTOR_TYPE" == "servo" ]; then
  read -p "Servo pin [$(get_default '.mmu.pins.selector.pin')]: " SERVO_PIN
  read -p "Servo min pulse [$(get_default '.mmu.pins.selector.min_pulse')]: " SERVO_MIN
  read -p "Servo max pulse [$(get_default '.mmu.pins.selector.max_pulse')]: " SERVO_MAX
else
  read -p "Selector STEP pin [$(get_default '.mmu.pins.selector.step')]: " SEL_STEP
  read -p "Selector DIR pin [$(get_default '.mmu.pins.selector.dir')]: " SEL_DIR
  read -p "Selector ENABLE pin [$(get_default '.mmu.pins.selector.enable')]: " SEL_ENABLE
fi

read -p "Motor current (mA) [$(get_default '.mmu.motor_current')]: " MOTOR_CURRENT
read -p "Load speed (mm/s) [$(get_default '.mmu.load_speed')]: " LOAD_SPEED
read -p "Unload speed (mm/s) [$(get_default '.mmu.unload_speed')]: " UNLOAD_SPEED
read -p "Retract length (mm) [$(get_default '.mmu.retract_length')]: " RETRACT_LEN

# === Write config ===
echo "→ Writing config to $CONFIG_FILE..."

cat > "$CONFIG_FILE" <<EOF
{
  "mcu": {
    "type": "$MCU_TYPE",
    "serial_port": "$MCU_PORT",
    "baud_rate": $MCU_BAUD,
    "pin_scheme": "$MCU_PINS",
    "frequency_mhz": $MCU_FREQ,
    "driver": {
      "type": "$DRIVER_TYPE",
      "uart_pin": "$DRIVER_UART"
    },
    "reset_on_connect": $( [ "$MCU_RESET" == "yes" ] && echo true || echo false ),
    "firmware_version": "$MCU_FW"
  },
  "mmu": {
    "slots": $MMU_SLOTS,
    "motor_current": $MOTOR_CURRENT,
    "load_speed": $LOAD_SPEED,
    "unload_speed": $UNLOAD_SPEED,
    "retract_length": $RETRACT_LEN,
    "pins": {
      "stepper": {
        "step": "$STEP_PIN",
        "dir": "$DIR_PIN",
        "enable": "$ENABLE_PIN"
      },
      "sensors": {
        "filament": "$SENSOR_PIN",
        "selector_home": "$HOME_PIN"
      },
      "cutter": {
        "enabled": $( [ "$CUTTER_ENABLED" == "yes" ] && echo true || echo false ),
        "pin": "$CUTTER_PIN"
      },
      "selector": {
        "type": "$SELECTOR_TYPE",
        "pin": "$SERVO_PIN",
        "min_pulse": $SERVO_MIN,
        "max_pulse": $SERVO_MAX,
        "step": "$SEL_STEP",
        "dir": "$SEL_DIR",
        "enable": "$SEL_ENABLE"
      }
    }
  }
}
EOF

# === Restart backend ===
echo "→ Restarting backend..."
sudo systemctl daemon-reload
sudo systemctl enable fluxpath.service
sudo systemctl restart fluxpath.service

sleep 3

echo "→ Checking backend health..."
curl -s http://localhost:9876/health && echo "✔ Backend OK" || echo "✖ Backend failed"

echo "=== FluxPath installation complete ==="
