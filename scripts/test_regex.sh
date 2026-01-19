#!/bin/bash
set -e

MMU_CFG="$HOME/printer_data/config/fluxpath_mmu/mmu_pins.cfg"
MOTOR_COUNT=0

echo "=== Regex Test (No Regex Version) ==="
echo "Reading: $MMU_CFG"

if [ ! -f "$MMU_CFG" ]; then
  echo "⚠ File not found: $MMU_CFG"
  exit 1
fi

while IFS= read -r line; do
  # Strip comments
  line="${line%%#*}"
  # Trim whitespace
  line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$line" ] && continue

  # Match section header EXACTLY using string comparison
  case "$line" in
    "[extruder_stepper mmu_extruder_0]")
      echo "→ Found motor block: mmu_extruder_0"
      MOTOR_COUNT=1
      ;;
    "[extruder_stepper mmu_extruder_1]")
      echo "→ Found motor block: mmu_extruder_1"
      MOTOR_COUNT=2
      ;;
    "[extruder_stepper mmu_extruder_2]")
      echo "→ Found motor block: mmu_extruder_2"
      MOTOR_COUNT=3
      ;;
    "[extruder_stepper mmu_extruder_3]")
      echo "→ Found motor block: mmu_extruder_3"
      MOTOR_COUNT=4
      ;;
  esac

done < "$MMU_CFG"

echo "✔ Total motors detected: $MOTOR_COUNT"
