#!/bin/bash
set -e

echo "=== FluxPath MMU Installer (Safe Matching Version) ==="

BASE_DIR="$HOME/FluxPath"
CONFIG_DIR="$BASE_DIR/config"
CONFIG_FILE="$CONFIG_DIR/fluxpath_config.json"

# Correct path to your mmu_pins.cfg
MMU_CFG="$HOME/printer_data/config/fluxpath_mmu/mmu_pins.cfg"

mkdir -p "$CONFIG_DIR"

# Normalize pin names
normalize_pin() {
  local raw="$1"
  raw="${raw#mmu:}"
  raw="${raw#^}"
  raw="${raw#!}"
  echo "$raw"
}

# Load existing JSON defaults if present
if [ -f "$CONFIG_FILE" ]; then
  echo "→ Loading existing JSON config defaults..."
  DEFAULTS_JSON=$(cat "$CONFIG_FILE")
else
  DEFAULTS_JSON="{}"
fi

get_default_json() {
  echo "$DEFAULTS_JSON" | jq -r "$1" 2>/dev/null || echo ""
}

# --- Parse mmu_pins.cfg using SAFE MATCHING ---
MOTOR_COUNT_DETECTED=0
declare -A MOTOR_STEP MOTOR_DIR MOTOR_EN MOTOR_MICRO MOTOR_ROT MOTOR_GEAR

SENSOR_PRE0=""
SENSOR_PRE1=""
SENSOR_MAIN=""

CUTTER_PIN=""
CUTTER_MIN=""
CUTTER_MAX=""
CUTTER_ANGLE=""

if [ -f "$MMU_CFG" ]; then
  echo "→ Parsing $MMU_CFG for defaults..."

  current_section=""

  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$line" ] && continue

    # Detect section headers safely
    case "$line" in
      "[extruder_stepper mmu_extruder_0]")
        current_section="motor0"
        MOTOR_COUNT_DETECTED=1
        ;;
      "[extruder_stepper mmu_extruder_1]")
        current_section="motor1"
        MOTOR_COUNT_DETECTED=2
        ;;
      "[extruder_stepper mmu_extruder_2]")
        current_section="motor2"
        MOTOR_COUNT_DETECTED=3
        ;;
      "[extruder_stepper mmu_extruder_3]")
        current_section="motor3"
        MOTOR_COUNT_DETECTED=4
        ;;
      "[filament_switch_sensor mmu_pre_gate_0]")
        current_section="sensor_pre0"
        ;;
      "[filament_switch_sensor mmu_pre_gate_1]")
        current_section="sensor_pre1"
        ;;
      "[filament_switch_sensor mmu_sensor]")
        current_section="sensor_main"
        ;;
      "[servo cutter]")
        current_section="cutter"
        ;;
    esac

    # Parse key/value
    key="${line%%:*}"
    val="${line#*:}"
    key="$(echo "$key" | xargs)"
    val="$(echo "$val" | xargs)"

    case "$current_section" in
      motor0)
        case "$key" in
          step_pin) MOTOR_STEP[0]="$(normalize_pin "$val")" ;;
          dir_pin) MOTOR_DIR[0]="$(normalize_pin "$val")" ;;
          enable_pin) MOTOR_EN[0]="$(normalize_pin "$val")" ;;
          microsteps) MOTOR_MICRO[0]="$val" ;;
          rotation_distance) MOTOR_ROT[0]="$val" ;;
          gear_ratio) MOTOR_GEAR[0]="$val" ;;
        esac
        ;;
      motor1)
        case "$key" in
          step_pin) MOTOR_STEP[1]="$(normalize_pin "$val")" ;;
          dir_pin) MOTOR_DIR[1]="$(normalize_pin "$val")" ;;
          enable_pin) MOTOR_EN[1]="$(normalize_pin "$val")" ;;
          microsteps) MOTOR_MICRO[1]="$val" ;;
          rotation_distance) MOTOR_ROT[1]="$val" ;;
          gear_ratio) MOTOR_GEAR[1]="$val" ;;
        esac
        ;;
      motor2)
        case "$key" in
          step_pin) MOTOR_STEP[2]="$(normalize_pin "$val")" ;;
          dir_pin) MOTOR_DIR[2]="$(normalize_pin "$val")" ;;
          enable_pin) MOTOR_EN[2]="$(normalize_pin "$val")" ;;
          microsteps) MOTOR_MICRO[2]="$val" ;;
          rotation_distance) MOTOR_ROT[2]="$val" ;;
          gear_ratio) MOTOR_GEAR[2]="$val" ;;
        esac
        ;;
      motor3)
        case "$key" in
          step_pin) MOTOR_STEP[3]="$(normalize_pin "$val")" ;;
          dir_pin) MOTOR_DIR[3]="$(normalize_pin "$val")" ;;
          enable_pin) MOTOR_EN[3]="$(normalize_pin "$val")" ;;
          microsteps) MOTOR_MICRO[3]="$val" ;;
          rotation_distance) MOTOR_ROT[3]="$val" ;;
          gear_ratio) MOTOR_GEAR[3]="$val" ;;
        esac
        ;;
      sensor_pre0)
        [ "$key" = "switch_pin" ] && SENSOR_PRE0="$(normalize_pin "$val")"
        ;;
      sensor_pre1)
        [ "$key" = "switch_pin" ] && SENSOR_PRE1="$(normalize_pin "$val")"
        ;;
      sensor_main)
        [ "$key" = "switch_pin" ] && SENSOR_MAIN="$(normalize_pin "$val")"
        ;;
      cutter)
        case "$key" in
          pin) CUTTER_PIN="$(normalize_pin "$val")" ;;
          minimum_pulse_width) CUTTER_MIN="$val" ;;
          maximum_pulse_width) CUTTER_MAX="$val" ;;
          maximum_servo_angle) CUTTER_ANGLE="$val" ;;
        esac
        ;;
    esac

  done < "$MMU_CFG"
else
  echo "⚠ $MMU_CFG not found."
fi

[ "$MOTOR_COUNT_DETECTED" -eq 0 ] && MOTOR_COUNT_DETECTED=2
echo "→ Detected $MOTOR_COUNT_DETECTED motor(s)."

read -p "Install with how many motors? [2/3/4] (default: $MOTOR_COUNT_DETECTED): " MOTOR_COUNT
MOTOR_COUNT="${MOTOR_COUNT:-$MOTOR_COUNT_DETECTED}"

case "$MOTOR_COUNT" in 2|3|4) ;; *) echo "Invalid motor count"; exit 1 ;; esac

echo ""
echo "=== Drive Motor Configuration ==="

declare -a OUT_MOTOR_STEP OUT_MOTOR_DIR OUT_MOTOR_EN OUT_MOTOR_MICRO OUT_MOTOR_ROT OUT_MOTOR_GEAR

for ((i=0; i<MOTOR_COUNT; i++)); do
  echo ""
  echo "— Motor $i —"

  read -p "STEP pin [${MOTOR_STEP[$i]}]: " val
  OUT_MOTOR_STEP[$i]="${val:-${MOTOR_STEP[$i]}}"

  read -p "DIR pin [${MOTOR_DIR[$i]}]: " val
  OUT_MOTOR_DIR[$i]="${val:-${MOTOR_DIR[$i]}}"

  read -p "ENABLE pin [${MOTOR_EN[$i]}]: " val
  OUT_MOTOR_EN[$i]="${val:-${MOTOR_EN[$i]}}"

  read -p "microsteps [${MOTOR_MICRO[$i]:-16}]: " val
  OUT_MOTOR_MICRO[$i]="${val:-${MOTOR_MICRO[$i]:-16}}"

  read -p "rotation_distance [${MOTOR_ROT[$i]:-22.67895}]: " val
  OUT_MOTOR_ROT[$i]="${val:-${MOTOR_ROT[$i]:-22.67895}}"

  read -p "gear_ratio [${MOTOR_GEAR[$i]:-3:1}]: " val
  OUT_MOTOR_GEAR[$i]="${val:-${MOTOR_GEAR[$i]:-3:1}}"
done

echo ""
echo "=== Sensor Configuration ==="

read -p "Pre-gate sensor 0 pin [${SENSOR_PRE0}]: " val
OUT_PRE0="${val:-$SENSOR_PRE0}"

read -p "Pre-gate sensor 1 pin [${SENSOR_PRE1}]: " val
OUT_PRE1="${val:-$SENSOR_PRE1}"

read -p "Main filament sensor pin [${SENSOR_MAIN}]: " val
OUT_MAIN="${val:-$SENSOR_MAIN}"

echo ""
echo "=== Cutter Servo Configuration ==="

read -p "Cutter servo pin [${CUTTER_PIN}]: " val
OUT_CUT_PIN="${val:-$CUTTER_PIN}"

read -p "Cutter min pulse [${CUTTER_MIN:-0.0005}]: " val
OUT_CUT_MIN="${val:-${CUTTER_MIN:-0.0005}}"

read -p "Cutter max pulse [${CUTTER_MAX:-0.0025}]: " val
OUT_CUT_MAX="${val:-${CUTTER_MAX:-0.0025}}"

read -p "Cutter max angle [${CUTTER_ANGLE:-180}]: " val
OUT_CUT_ANG="${val:-${CUTTER_ANGLE:-180}}"

echo "→ Writing JSON config to $CONFIG_FILE..."

# Build motors array JSON
MOTORS_JSON="[]"
for ((i=0; i<MOTOR_COUNT; i++)); do
  MOTOR_OBJ=$(jq -n \
    --arg step "${OUT_MOTOR_STEP[$i]}" \
    --arg dir "${OUT_MOTOR_DIR[$i]}" \
    --arg en "${OUT_MOTOR_EN[$i]}" \
    --argjson micro "${OUT_MOTOR_MICRO[$i]}" \
    --arg rot "${OUT_MOTOR_ROT[$i]}" \
    --arg gear "${OUT_MOTOR_GEAR[$i]}" \
    '{
      step: $step,
      dir: $dir,
      enable: $en,
      microsteps: $micro,
      rotation_distance: ($rot | tonumber? // $rot),
      gear_ratio: $gear
    }')

  MOTORS_JSON=$(echo "$MOTORS_JSON" | jq --argjson obj "$MOTOR_OBJ" '. + [$obj]')
done

FINAL_JSON=$(jq -n \
  --argjson motors "$MOTORS_JSON" \
  --arg pre0 "$OUT_PRE0" \
  --arg pre1 "$OUT_PRE1" \
  --arg main "$OUT_MAIN" \
  --arg cut_pin "$OUT_CUT_PIN" \
  --arg cut_min "$OUT_CUT_MIN" \
  --arg cut_max "$OUT_CUT_MAX" \
  --arg cut_ang "$OUT_CUT_ANG" \
  '{
    mmu: {
      motors: $motors,
      sensors: {
        pre_gate_0: $pre0,
        pre_gate_1: $pre1,
        main: $main
      },
      cutter: {
        pin: $cut_pin,
        min_pulse: ($cut_min | tonumber? // $cut_min),
        max_pulse: ($cut_max | tonumber? // $cut_max),
        max_angle: ($cut_ang | tonumber? // $cut_ang)
      }
    }
  }')

echo "$FINAL_JSON" > "$CONFIG_FILE"

echo "→ Restarting backend..."
sudo systemctl daemon-reload
sudo systemctl enable fluxpath.service
sudo systemctl restart fluxpath.service

sleep 2
echo "→ Checking backend health..."

if curl -s http://localhost:9876/health >/dev/null 2>&1; then
  echo "✔ Backend OK"
else
  echo "✖ Backend failed to start"
fi

echo "=== FluxPath MMU installation complete ==="
